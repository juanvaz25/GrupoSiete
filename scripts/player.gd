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

@export_group("Estadisticas")
## Salud máxima del personaje.
@export var max_health: float = 3.0
## Duración de invulnerabilidad temporal al recibir un golpe (segundos).
@export var hit_i_frames: float = 0.8
## Escena a la que se regresa si la vida llega a 0 ("echado de la sala").
@export var initial_room_scene: String = "res://scenes/nivel_inicial.tscn"

@export_group("Daño por fuego")
@export var fire_grace_time: float = 3.0
@export var fire_damage_interval: float = 1.0
@export var fire_damage_amount: float = 0.5

var _active_fires: Array[Area2D] = []
var _fire_exposure: float = 0.0
var _next_fire_damage: float = 3.0

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
@onready var _ReveolverCylinder: TextureRect = get_node_or_null("RevolverCylinder")

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
	
	_next_fire_damage = fire_grace_time

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

	# Configurar puntero del mouse tipo 'X' (mira para apuntar) durante el juego
	_setup_custom_crosshair()


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
			_sprite.play(Utility.get_direction("walk", input_direction))

	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

		if not is_shooting:
			_sprite.play(Utility.get_direction("idle",last_direction))

	move_and_slide()
	
	# =========================
	# Daño por fuego
	# =========================
	_update_fire_damage(_delta)

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
		is_invulnerable = true
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
	is_invulnerable = false
	expelled_from_room.emit()
	
	var tree := get_tree()
	if tree == null:
		return
	
	# Cambiar escena al nivel inicial si no estamos ya en él
	var current_scene_path := ""
	if tree.current_scene != null:
		current_scene_path = tree.current_scene.scene_file_path
	
	if current_scene_path != initial_room_scene:
		tree.change_scene_to_file("res://scenes/nivel_inicial.tscn")
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
		_sprite.play(Utility.get_direction("dash",dash_direction))


func _on_dash_finished() -> void:
	if _sprite:
		_sprite.modulate.a = 1.0

		# Volver a la animación normal
		if input_direction != Vector2.ZERO:
			_sprite.play(Utility.get_direction("walk",input_direction))
		else:
			_sprite.play("idle")

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
	var has_damage := false
	if source == null or is_invulnerable:
		return
	# Ignorar si es el propio jugador, sus hijos o proyectiles del jugador
	if source == self or source.is_in_group("player") or source.is_in_group("player_projectile"):
		return
	if source.get_parent() != null and (source.get_parent() == self or source.get_parent().is_in_group("player") or source.get_parent().is_in_group("player_projectile")):
		return
	if "bullet" in source.name.to_lower() or "disparo" in source.name.to_lower() or "proyectil" in source.name.to_lower():
		return
	#print("Daño recibido de fuente: " + source.name)
	var incoming_dmg: float = 1.0
	if source.get("damage") != null:
		incoming_dmg = float(source.get("damage"))
		has_damage = true
	elif source.get_parent() and source.get_parent().get("damage") != null:
		incoming_dmg = float(source.get_parent().get("damage"))
		has_damage = true
	elif source.is_in_group("enemy_attack") or source.is_in_group("enemy") or source.is_in_group("hazard"):
		incoming_dmg = 0.5
		has_damage = true

	# Solo aplicar daño si realmente proviene de un ataque enemigo o colisión con daño válido
	if not has_damage or incoming_dmg <= 0.0:
		return

	take_damage(incoming_dmg)



#
# ANIMACIONES
#


func play_shoot_animation() -> void:
	if is_shooting:
		return
	
	#_ReveolverCylinder.texture = 
	
	is_shooting = true

	_sprite.play(Utility.get_direction("shoot",last_direction))

	await _sprite.animation_finished

	is_shooting = false


func _setup_custom_crosshair() -> void:
	var crosshair_texture: Texture2D = null
	if ResourceLoader.exists("res://assets/crosshair.png"):
		crosshair_texture = load("res://assets/crosshair.png")
	if not crosshair_texture and FileAccess.file_exists("res://assets/crosshair.png"):
		var img := Image.load_from_file("res://assets/crosshair.png")
		if img:
			crosshair_texture = ImageTexture.create_from_image(img)
	if crosshair_texture:
		Input.set_custom_mouse_cursor(crosshair_texture, Input.CURSOR_ARROW, Vector2(16, 16))

#region Nacion del fuego
func enter_fire(fire: Area2D) -> void:
	if not _active_fires.has(fire):
		_active_fires.append(fire)


func exit_fire(fire: Area2D) -> void:
	_active_fires.erase(fire)


func _update_fire_damage(delta: float) -> void:
	# Limpiar fuegos que fueron eliminados.
	for index in range(_active_fires.size() - 1, -1, -1):
		if not is_instance_valid(_active_fires[index]):
			_active_fires.remove_at(index)

	# Fuera del fuego: reiniciar el contador.
	if _active_fires.is_empty():
		_fire_exposure = 0.0
		_next_fire_damage = fire_grace_time
		return

	_fire_exposure += delta

	if _fire_exposure >= _next_fire_damage:
		_next_fire_damage = _fire_exposure + maxf(
			fire_damage_interval, 0.01
		)
		take_damage(fire_damage_amount)
#endregion


func _exit_tree() -> void:
	# Restaurar cursor estándar del sistema al salir del personaje
	Input.set_custom_mouse_cursor(null)
