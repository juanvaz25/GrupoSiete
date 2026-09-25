## Player character controller.
##
## Handles movement input (WASD) and exposes state for child ability nodes.
## Abilities (Dash, Shoot, Rifle) are attached as child nodes and read
## `input_direction` and `last_direction` to function.
## Manages health (3 points, 1/2 and 1 dmg/heal), collision, i-frames, and boss-room expulsion.
extends CharacterBody2D

# --- Configuración ---
## Velocidad base de movimiento (px/s).
const SPEED := 500.0

## Salud máxima del personaje.
@export var max_health: float = 3.0
## Duración de invulnerabilidad temporal al recibir un golpe (segundos).
@export var hit_i_frames: float = 0.8
## Escena a la que se regresa si la vida llega a 0 ("echado de la sala").
@export var initial_room_scene: String = "res://scenes/nivel_inicial.tscn"

# --- Señales ---
signal health_changed(current_health: float, max_health: float)
signal expelled_from_room
signal invulnerability_changed(is_invulnerable: bool)

# --- Estado público (leído por habilidades y HUD) ---
## Dirección de input actual (normalizada). Vector2.ZERO si no hay input.
var input_direction: Vector2 = Vector2.ZERO
## Última dirección de movimiento válida. Útil para el dash sin input activo.
var last_direction: Vector2 = Vector2.RIGHT
var is_shooting: bool = false

## Puntos de vida actuales.
var current_health: float = 3.0
## Si el personaje es invulnerable en este momento.
var is_invulnerable: bool = false

# --- Nodos internos ---
@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _dash_ability = get_node_or_null("DashAbility")
@onready var _hurtbox: Area2D = get_node_or_null("Hurtbox")

var _i_frame_timer: Timer = Timer.new()
var _flash_tween: Tween


func _ready() -> void:
	add_to_group("player")
	current_health = max_health

	# Configuración de timer de invulnerabilidad tras recibir golpe
	_i_frame_timer.one_shot = true
	_i_frame_timer.wait_time = hit_i_frames
	_i_frame_timer.timeout.connect(_on_i_frame_timeout)
	add_child(_i_frame_timer)

	# Conectar señales del Dash para invulnerabilidad durante esquiva
	if _dash_ability:
		if _dash_ability.has_signal("dash_started"):
			_dash_ability.dash_started.connect(_on_dash_started)
		if _dash_ability.has_signal("dash_finished"):
			_dash_ability.dash_finished.connect(_on_dash_finished)

	# Conectar Hurtbox si existe
	if _hurtbox:
		_hurtbox.area_entered.connect(_on_hurtbox_area_entered)
		_hurtbox.body_entered.connect(_on_hurtbox_body_entered)


func _physics_process(_delta: float) -> void:
	# Leer input
	input_direction = Input.get_vector(
		"move_left",
		"move_right",
		"move_up",
		"move_down"
	)

	# Guardar última dirección válida
	if input_direction != Vector2.ZERO:
		last_direction = input_direction.normalized()

	# =========================
	# DASH
	# =========================

	if _dash_ability and _dash_ability.is_dashing:
		move_and_slide()
		return

	# =========================
	# DISPARO
	# =========================

	if Input.is_action_just_pressed("shoot"):
		play_shoot_animation()

	# =========================
	# MOVIMIENTO
	# =========================

	if input_direction != Vector2.ZERO:
		velocity = input_direction * SPEED

		if not is_shooting:
			var animation_name := get_walk_animation(input_direction)
			_sprite.play(animation_name)

	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

		if not is_shooting:
			_sprite.play("idle"+get_direction(last_direction))

	move_and_slide()


# --- Sistema de Vida y Daño ---

## Aplica daño al personaje (ej: 0.5 o 1.0).
## Ignora el daño si está en dash o en período de invulnerabilidad.
func take_damage(amount: float) -> void:
	if is_invulnerable:
		return
	if _dash_ability and _dash_ability.is_dashing:
		return

	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	print("Jugador recibió ", amount, " de daño. Vida restante: ", current_health, "/", max_health)

	if current_health <= 0.0:
		call_deferred("_expel_from_room")
	else:
		_start_invulnerability(hit_i_frames)


## Cura al personaje (ej: 0.5 o 1.0).
func heal(amount: float) -> void:
	if current_health >= max_health:
		return
	current_health = clampf(current_health + amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)
	print("Jugador se curó ", amount, " de vida. Vida actual: ", current_health, "/", max_health)


## Al llegar a 0 de vida, el personaje es "echado de la sala" de vuelta a la sala inicial.
func _expel_from_room() -> void:
	print("¡Vida reducida a 0! El personaje ha sido echado de la sala.")
	current_health = max_health
	expelled_from_room.emit()
	
	# Cambiar escena al nivel inicial si no estamos ya en él
	var current_scene_path := ""
	if get_tree().current_scene:
		current_scene_path = get_tree().current_scene.scene_file_path
	
	if current_scene_path != initial_room_scene:
		get_tree().change_scene_to_file("res://scenes/nivel_inicial.tscn")
	else:
		# Si ya está en la sala inicial, reaparecer en el origen o posición inicial
		global_position = Vector2.ZERO


# --- Invulnerabilidad y Efectos de Daño ---

func _start_invulnerability(duration: float) -> void:
	is_invulnerable = true
	invulnerability_changed.emit(true)
	_i_frame_timer.start(duration)
	_start_blink_effect(duration)


func _on_i_frame_timeout() -> void:
	# No retirar invulnerabilidad si sigue haciendo dash
	if _dash_ability and _dash_ability.is_dashing:
		return
	is_invulnerable = false
	invulnerability_changed.emit(false)
	_stop_blink_effect()


func _on_dash_started() -> void:
	is_invulnerable = true
	invulnerability_changed.emit(true)

	if _sprite:
		_sprite.modulate.a = 0.6

		var dash_direction: Vector2 = _dash_ability.dash_direction
		var dash_animation: String = get_dash_animation(dash_direction)

		print("💨 DASH: ", dash_animation)
		_sprite.play(dash_animation)


func _on_dash_finished() -> void:
	if _sprite:
		_sprite.modulate.a = 1.0

		# Volver a la animación normal
		if input_direction != Vector2.ZERO:
			_sprite.play(get_walk_animation(input_direction))
		else:
			_sprite.play("default")

	if _i_frame_timer.is_stopped():
		is_invulnerable = false
		invulnerability_changed.emit(false)


func _start_blink_effect(duration: float) -> void:
	if _sprite == null:
		return
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()

	_flash_tween = create_tween()
	var loops := int(duration / 0.1)
	for i in range(loops):
		_flash_tween.tween_property(_sprite, "modulate:a", 0.3, 0.05)
		_flash_tween.tween_property(_sprite, "modulate:a", 1.0, 0.05)


func _stop_blink_effect() -> void:
	if _flash_tween and _flash_tween.is_valid():
		_flash_tween.kill()
	if _sprite:
		_sprite.modulate = Color.WHITE


# --- Detección de Ataques Enemigos (Hurtbox) ---

func _on_hurtbox_area_entered(area: Area2D) -> void:
	_process_incoming_attack(area)


func _on_hurtbox_body_entered(body: Node2D) -> void:
	_process_incoming_attack(body)


func _process_incoming_attack(source: Node2D) -> void:
	if source == null or is_invulnerable:
		return
	# Ignorar si es el propio jugador o sus proyectiles
	if source == self or source.is_in_group("player") or source.get_parent() == self:
		return
	if source.name.begins_with("Bullet") or source.name.begins_with("RifleBullet"):
		return
	#print("Daño recibido de fuente: " + source.name)
	var incoming_dmg: float = 1.0
	if source.get("damage") != null:
		incoming_dmg = float(source.get("damage"))
	elif source.get_parent() and source.get_parent().get("damage") != null:
		incoming_dmg = float(source.get_parent().get("damage"))

	take_damage(incoming_dmg)



#
# ANIMACIONES
#

func get_walk_animation(direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	if angle >= -PI / 8 and angle < PI / 8:
		return "walk_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "walk_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "walk_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "walk_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "walk_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "walk_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "walk_up"

	# ARRIBA-DERECHA
	else:
		return "walk_up_right"
		

func get_shoot_animation(direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	if angle >= -PI / 8 and angle < PI / 8:
		return "shoot_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "shoot_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "shoot_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "shoot_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "shoot_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "shoot_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "shoot_up"

	# ARRIBA-DERECHA
	else:
		return "shoot_up_right"


func get_direction(direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	
	if angle >= -PI / 8 and angle < PI / 8:
		return "_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "_up"

	# ARRIBA-DERECHA
	else:
		return "_up_right"

func play_shoot_animation() -> void:
	if is_shooting:
		return

	is_shooting = true

	var animation_name := get_shoot_animation(last_direction)

	print("🔫 Dirección: ", last_direction)
	print("🎬 Animación solicitada: ", animation_name)

	if not _sprite.sprite_frames.has_animation(animation_name):
		print("❌ NO EXISTE: ", animation_name)
		is_shooting = false
		return

	print("✅ EXISTE: ", animation_name)

	_sprite.play(animation_name)

	await _sprite.animation_finished

	is_shooting = false


func get_dash_animation(direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	if angle >= -PI / 8 and angle < PI / 8:
		return "dash_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "dash_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "dash_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "dash_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "dash_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "dash_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "dash_up"

	# ARRIBA-DERECHA
	else:
		return "dash_up_right"
