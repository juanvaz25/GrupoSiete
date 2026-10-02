## Controlador del Jefe Basilisco con animaciones direccionales en 8 direcciones.
##
## Características principales:
## - Nombre: Basilisco.
## - Vida: 50 HP (Recibe 1 de daño del revólver y 10 de daño + aturdimiento del rifle).
## - Animaciones direccionales completas de 8 direcciones (walk, idle, charge).
## - Esquiva de Balas: Intenta esquivar proyectiles entrantes en combate activo con un dash evasivo lateral.
## - Escupir Fuego: Cooldown de 10s, inflige 1.0 de daño.
## - Placaje / Embestida: Cooldown de 5s, inflige 0.5 de daño.
## - Daño por Contacto: Si el jugador lo toca, inflige 0.5 de daño.
## - Portal de retorno a la biblioteca al ser derrotado.
## - Efectos de sonido integrados para fuego, placaje, daño, muerte y portal.
extends CharacterBody2D

# =========================
# SEÑALES Y ENUMS
# =========================
signal health_changed(current: float, max_val: float)
signal died
signal attack_performed(attack_name: String)

enum State {
	IDLE_CHASE,
	DODGING,
	FIRE_PREPARE,
	FIRE_ATTACK,
	CHARGE_PREPARE,
	CHARGING,
	CHARGE_RECOVER,
	STUNNED,
	DEAD
}

# =========================
# CONFIGURACIÓN
# =========================
@export_group("Estadísticas")
## Salud máxima del Basilisco (50 según especificación).
@export var max_health: float = 50.0
## Velocidad normal de movimiento (px/s).
@export var normal_speed: float = 230.0
## Distancia preferida de combate con el jugador.
@export var preferred_distance: float = 300.0

@export_group("Habilidad: Esquiva de Balas")
## Probabilidad de que el Basilisco intente esquivar una bala que va directo a él (0.0 a 1.0).
@export var dodge_chance: float = 0.65
## Cooldown entre esquivas (segundos).
@export var dodge_cooldown: float = 2.5
## Velocidad del desplazamiento evasivo (px/s).
@export var dodge_speed: float = 800.0
## Duración del desplazamiento rápido de esquiva (segundos).
@export var dodge_duration: float = 0.22
## Distancia máxima a la que detecta balas entrantes.
@export var bullet_detection_radius: float = 420.0

@export_group("Poder: Escupir Fuego")
## Daño de la bola de fuego (1.0 según especificación).
@export var fire_damage: float = 1.0
## Tiempo de reutilización de escupir fuego (10s según especificación).
@export var fire_cooldown: float = 10.0
## Tiempo de preparación/telegrafiado antes de disparar.
@export var fire_prepare_time: float = 0.6
## Escena del proyectil de fuego.
@export var fireball_scene: PackedScene = preload("res://scenes/projectiles/basilisk_fireball.tscn")

@export_group("Portal de Retorno")
## Escena del portal de retorno a la biblioteca tras vencer al jefe.
@export var portal_scene: PackedScene = preload("res://scenes/portal_retorno.tscn")

@export_group("Poder: Placaje / Embestida")
## Daño del placaje (0.5 según especificación).
@export var charge_damage: float = 0.5
## Tiempo de reutilización del placaje (5s según especificación).
@export var charge_cooldown: float = 5.0
## Velocidad del placaje (px/s).
@export var charge_speed: float = 950.0
## Duración del desplazamiento en placaje (segundos).
@export var charge_duration: float = 0.65
## Tiempo de preparación/telegrafiado del placaje.
@export var charge_prepare_time: float = 0.5

@export_group("Daño por Contacto")
## Daño al tocar al personaje (0.5 según especificación).
@export var contact_damage: float = 0.5
## Cooldown interno para aplicar daño por contacto continuo.
@export var contact_damage_interval: float = 0.8

# =========================
# ESTADO INTERNO
# =========================
var current_health: float = 50.0
var current_state: State = State.IDLE_CHASE
var player: CharacterBody2D = null

var can_fire: bool = true
var can_charge: bool = true
var can_dodge: bool = true
var is_stunned: bool = false
var _stun_timer: float = 0.0

var _dodge_timer: float = 0.0
var _dodge_target_dir: Vector2 = Vector2.ZERO
var _charge_target_dir: Vector2 = Vector2.ZERO
var _facing_direction: Vector2 = Vector2.DOWN
var _contact_timer: float = 0.0
var _slither_time: float = 0.0
var _flash_tween: Tween

# =========================
# REFERENCIAS A NODOS
# =========================
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var boss_title: Label = $BossTitle
@onready var stun_label: Label = $StunLabel
@onready var mouth_marker: Marker2D = $MouthMarker
@onready var contact_area: Area2D = $ContactArea
@onready var charge_hitbox: Area2D = $ChargeHitbox
@onready var fire_charge_particles: CPUParticles2D = get_node_or_null("FireChargeParticles")
@onready var dust_particles: CPUParticles2D = get_node_or_null("DustParticles")
@onready var audio_fire: AudioStreamPlayer2D = get_node_or_null("AudioFire")
@onready var audio_charge: AudioStreamPlayer2D = get_node_or_null("AudioCharge")
@onready var audio_hit: AudioStreamPlayer2D = get_node_or_null("AudioHit")
@onready var audio_death: AudioStreamPlayer2D = get_node_or_null("AudioDeath")


func _ready() -> void:
	add_to_group("enemy")
	add_to_group("basilisco")
	add_to_group("boss")

	current_health = max_health

	# Inicializar barra de vida
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health

	if stun_label:
		stun_label.visible = false

	if charge_hitbox:
		charge_hitbox.monitoring = false
		charge_hitbox.set("damage", charge_damage)

	if contact_area:
		contact_area.set("damage", contact_damage)
		contact_area.body_entered.connect(_on_contact_area_body_entered)
		contact_area.area_entered.connect(_on_contact_area_area_entered)

	if charge_hitbox:
		charge_hitbox.body_entered.connect(_on_charge_hitbox_body_entered)
		charge_hitbox.area_entered.connect(_on_charge_hitbox_area_entered)

	# Iniciar animación por defecto
	if sprite:
		sprite.play("default")

	# Buscar al jugador en la escena
	var tree := get_tree()
	if tree:
		await tree.process_frame
	_find_player()

	print("🐍 Basilisco iniciado | Vida: ", current_health, "/", max_health)


func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	# Manejo del aturdimiento (del rifle)
	if is_stunned:
		_process_stun(delta)
		return

	# Actualizar cooldown de daño por contacto
	if _contact_timer > 0.0:
		_contact_timer -= delta

	if player == null or not is_instance_valid(player):
		_find_player()
		return

	# Máquina de estados
	match current_state:
		State.IDLE_CHASE:
			_process_idle_chase(delta)
		State.DODGING:
			_process_dodge(delta)
		State.CHARGING:
			velocity = _charge_target_dir * charge_speed
			if sprite:
				sprite.play(get_charge_animation(_charge_target_dir))
			move_and_slide()

			for i in range(get_slide_collision_count()):
				var collision := get_slide_collision(i)
				var collider := collision.get_collider()
				if collider and (collider.is_in_group("player") or collider.name == "Player"):
					if collider.has_method("take_damage"):
						collider.take_damage(charge_damage)
						print("💥 ¡Placaje impactó al jugador por colisión física! Daño: ", charge_damage)
		State.FIRE_PREPARE, State.FIRE_ATTACK, State.CHARGE_PREPARE, State.CHARGE_RECOVER:
			velocity = velocity.move_toward(Vector2.ZERO, normal_speed * 4.0 * delta)
			move_and_slide()


# ==============================================================================
# ANIMACIONES EN 8 DIRECCIONES
# ==============================================================================

func get_walk_animation(dir: Vector2) -> String:
	var angle := dir.angle()
	if angle >= -PI / 8 and angle < PI / 8:
		return "walk_right"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "walk_down_right"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "walk_down"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "walk_down_left"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "walk_left"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "walk_up_left"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "walk_up"
	else:
		return "walk_up_right"


func get_charge_animation(dir: Vector2) -> String:
	var angle := dir.angle()
	if angle >= -PI / 8 and angle < PI / 8:
		return "charge_right"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "charge_down_right"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "charge_down"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "charge_down_left"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "charge_left"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "charge_up_left"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "charge_up"
	else:
		return "charge_up_right"


func get_idle_animation(dir: Vector2) -> String:
	var angle := dir.angle()
	if angle >= -PI / 8 and angle < PI / 8:
		return "idle_right"
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "idle_down_right"
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "idle_down"
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "idle_down_left"
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "idle_left"
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "idle_up_left"
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "idle_up"
	else:
		return "idle_up_right"


# ==============================================================================
# COMPORTAMIENTO Y TOMA DE DECISIONES (IA)
# ==============================================================================

func _process_idle_chase(delta: float) -> void:
	# 0. Intento de esquivar balas entrantes en curso de colisión
	if can_dodge and _check_bullet_dodge():
		return

	var dist_to_player := global_position.distance_to(player.global_position)
	var dir_to_player := global_position.direction_to(player.global_position)
	_facing_direction = dir_to_player

	# Efecto de ondulación / deslizamiento de serpiente (slither)
	_slither_time += delta * 6.0
	var perp_dir := Vector2(-dir_to_player.y, dir_to_player.x)
	var slither_offset := perp_dir * sin(_slither_time) * 0.4

	# Comprobación de habilidades disponibles
	# 1. Prioridad: Escupir fuego si está listo (CD 10s)
	if can_fire and dist_to_player <= 850.0:
		start_fire_attack()
		return

	# 2. Placaje si está listo (CD 5s) y a distancia adecuada
	if can_charge and dist_to_player <= 600.0:
		start_charge_attack()
		return

	# Movimiento de aproximación / posicionamiento
	if dist_to_player > preferred_distance + 40.0:
		velocity = (dir_to_player + slither_offset).normalized() * normal_speed
	elif dist_to_player < preferred_distance - 40.0:
		velocity = (-dir_to_player + slither_offset).normalized() * (normal_speed * 0.8)
	else:
		velocity = (perp_dir + slither_offset * 0.5).normalized() * (normal_speed * 0.9)

	# Reproducir animación direccional según el movimiento
	if sprite:
		if velocity.length() > 20.0:
			sprite.play(get_walk_animation(velocity))
		else:
			sprite.play(get_idle_animation(dir_to_player))

	move_and_slide()

	# Solo aplicar daño por contacto si hubo una colisión física real
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and (collider.is_in_group("player") or collider.name == "Player"):
			_apply_contact_damage_to_player(collider)


# ==============================================================================
# HABILIDAD: ESQUIVA DE BALAS
# ==============================================================================

## Detecta si hay una bala del jugador dirigiéndose hacia el Basilisco y ejecuta una evasión.
func _check_bullet_dodge() -> bool:
	if not can_dodge or current_state != State.IDLE_CHASE or is_stunned:
		return false

	var tree := get_tree()
	if tree == null:
		return false

	var bullets := tree.get_nodes_in_group("player_projectile")
	for b in bullets:
		if not is_instance_valid(b) or not (b is Node2D):
			continue

		var bullet: Node2D = b
		var dist_to_bullet := global_position.distance_to(bullet.global_position)
		if dist_to_bullet > bullet_detection_radius or dist_to_bullet < 20.0:
			continue

		# Obtener vector de velocidad o dirección de la bala
		var bullet_dir: Vector2 = Vector2.ZERO
		if "direction" in bullet and bullet.direction is Vector2:
			bullet_dir = bullet.direction.normalized()
		elif "velocity" in bullet and bullet.velocity is Vector2:
			bullet_dir = bullet.velocity.normalized()

		if bullet_dir == Vector2.ZERO:
			continue

		# Comprobar si la bala se dirige hacia el Basilisco
		var to_basil := global_position - bullet.global_position
		var proj := to_basil.dot(bullet_dir)
		if proj > 0.0 and proj <= bullet_detection_radius:
			var closest_point := bullet.global_position + bullet_dir * proj
			var perp_distance := global_position.distance_to(closest_point)

			# Si está en rumbo directo hacia el basilisco (a menos de 80px)
			if perp_distance < 80.0:
				if randf() <= dodge_chance:
					# Esquivar perpendicularmente a la trayectoria de la bala
					var dodge_perp := Vector2(-bullet_dir.y, bullet_dir.x)
					if randf() > 0.5:
						dodge_perp = -dodge_perp
					_start_dodge(dodge_perp)
					return true
	return false


func _start_dodge(dodge_dir: Vector2) -> void:
	can_dodge = false
	current_state = State.DODGING
	_dodge_timer = dodge_duration
	_dodge_target_dir = dodge_dir.normalized()

	print("🐍💨 ¡El Basilisco intenta esquivar una bala con un movimiento rápido!")

	if dust_particles:
		dust_particles.restart()
		dust_particles.emitting = true

	if sprite:
		sprite.play(get_walk_animation(_dodge_target_dir))
		var ghost_tween := create_tween()
		ghost_tween.tween_property(sprite, "modulate:a", 0.4, dodge_duration * 0.4)
		ghost_tween.tween_property(sprite, "modulate:a", 1.0, dodge_duration * 0.6)


func _process_dodge(delta: float) -> void:
	_dodge_timer -= delta
	velocity = _dodge_target_dir * dodge_speed

	if sprite:
		sprite.play(get_walk_animation(_dodge_target_dir))

	move_and_slide()

	# Daño por contacto si colisiona durante la esquiva
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		var collider := collision.get_collider()
		if collider and (collider.is_in_group("player") or collider.name == "Player"):
			_apply_contact_damage_to_player(collider)

	if _dodge_timer <= 0.0:
		if dust_particles:
			dust_particles.emitting = false
		if current_state != State.DEAD and not is_stunned:
			current_state = State.IDLE_CHASE
		_start_dodge_cooldown()


func _start_dodge_cooldown() -> void:
	var tree := get_tree()
	if tree == null:
		return
	await tree.create_timer(dodge_cooldown).timeout
	can_dodge = true


# ==============================================================================
# PODER 1: ESCUPIR FUEGO (Cooldown 10s, Daño 1.0)
# ==============================================================================

func start_fire_attack() -> void:
	if not can_fire or current_state != State.IDLE_CHASE:
		return

	can_fire = false
	current_state = State.FIRE_PREPARE
	velocity = Vector2.ZERO
	attack_performed.emit("spit_fire")

	print("🐍🔥 ¡El Basilisco prepara su aliento de fuego!")

	if audio_fire:
		audio_fire.play()

	# Reproducir animación de idle hacia el jugador
	if sprite and player:
		var dir := global_position.direction_to(player.global_position)
		sprite.play(get_idle_animation(dir))
		_flash_tween = create_tween()
		_flash_tween.tween_property(sprite, "modulate", Color(1.8, 0.7, 0.2), fire_prepare_time * 0.8)

	if fire_charge_particles:
		fire_charge_particles.emitting = true

	# Esperar tiempo de preparación
	var tree := get_tree()
	if tree:
		await tree.create_timer(fire_prepare_time).timeout

	if current_state == State.DEAD or is_stunned:
		return

	current_state = State.FIRE_ATTACK

	# Disparar proyectil
	_shoot_fireball()

	# Restaurar color del sprite
	if sprite:
		sprite.modulate = Color.WHITE
	if fire_charge_particles:
		fire_charge_particles.emitting = false

	# Pequeña pausa tras disparar
	var tree2 := get_tree()
	if tree2:
		await tree2.create_timer(0.3).timeout

	if current_state != State.DEAD and not is_stunned:
		current_state = State.IDLE_CHASE

	# Iniciar cooldown de 10s
	_start_fire_cooldown()


func _shoot_fireball() -> void:
	if fireball_scene == null or player == null:
		return

	var spawn_pos: Vector2 = mouth_marker.global_position if mouth_marker else global_position
	var target_dir: Vector2 = spawn_pos.direction_to(player.global_position).normalized()

	var fireball = fireball_scene.instantiate()
	fireball.global_position = spawn_pos
	fireball.direction = target_dir
	fireball.damage = fire_damage # 1.0 DMG

	# Añadir al nivel / árbol de nodos principal
	var tree := get_tree()
	if tree and tree.current_scene:
		tree.current_scene.add_child(fireball)
	elif get_parent():
		get_parent().add_child(fireball)

	print("🔥 ¡Fuego escupido! Dirección: ", target_dir, " | Daño: ", fire_damage)


func _start_fire_cooldown() -> void:
	var tree := get_tree()
	if tree:
		await tree.create_timer(fire_cooldown).timeout
	can_fire = true
	print("⚡ Escupir Fuego listo (CD 10s completado)")


# ==============================================================================
# PODER 2: PLACAJE / EMBESTIDA (Cooldown 5s, Daño 0.5)
# ==============================================================================

func start_charge_attack() -> void:
	if not can_charge or current_state != State.IDLE_CHASE:
		return

	can_charge = false
	current_state = State.CHARGE_PREPARE
	velocity = Vector2.ZERO
	attack_performed.emit("charge")

	print("🐍💨 ¡El Basilisco prepara un placaje!")

	if audio_charge:
		audio_charge.play()

	# Predicción de trayectoria hacia la posición del jugador
	var dist := global_position.distance_to(player.global_position)
	var travel_time := dist / charge_speed
	var predicted_pos := player.global_position + (player.velocity * (charge_prepare_time + travel_time))
	_charge_target_dir = global_position.direction_to(predicted_pos).normalized()

	# Efectos visuales de preparación: color rojizo + animación de carga
	if sprite:
		sprite.play(get_idle_animation(_charge_target_dir))
		_flash_tween = create_tween()
		_flash_tween.tween_property(sprite, "modulate", Color(2.2, 0.4, 0.4), charge_prepare_time * 0.7)

	if dust_particles:
		dust_particles.emitting = true

	var tree := get_tree()
	if tree:
		await tree.create_timer(charge_prepare_time).timeout

	if current_state == State.DEAD or is_stunned:
		return

	# Inicio de la embestida
	current_state = State.CHARGING

	if sprite:
		sprite.modulate = Color.WHITE
		sprite.play(get_charge_animation(_charge_target_dir))

	if charge_hitbox:
		charge_hitbox.monitoring = true

	# Duración de la embestida
	var tree2 := get_tree()
	if tree2:
		await tree2.create_timer(charge_duration).timeout

	# Fin de embestida
	if charge_hitbox:
		charge_hitbox.monitoring = false
	if dust_particles:
		dust_particles.emitting = false

	velocity = Vector2.ZERO
	current_state = State.CHARGE_RECOVER

	if sprite:
		sprite.play(get_idle_animation(_charge_target_dir))

	# Tiempo de recuperación breve
	var tree3 := get_tree()
	if tree3:
		await tree3.create_timer(0.35).timeout

	if current_state != State.DEAD and not is_stunned:
		current_state = State.IDLE_CHASE

	# Iniciar cooldown de 5s
	_start_charge_cooldown()


func _start_charge_cooldown() -> void:
	var tree := get_tree()
	if tree:
		await tree.create_timer(charge_cooldown).timeout
	can_charge = true
	print("⚡ Placaje listo (CD 5s completado)")


# ==============================================================================
# DAÑO POR CONTACTO Y COLISIONES
# ==============================================================================

func _on_contact_area_body_entered(body: Node2D) -> void:
	if body == self or body.is_in_group("enemy"):
		return
	if body.is_in_group("player") or body.name == "Player":
		_apply_contact_damage_to_player(body)


func _on_contact_area_area_entered(area: Area2D) -> void:
	if area.is_in_group("enemy") or area.get_parent() == self:
		return
	if area.is_in_group("player") or area.name == "Hurtbox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		var target = area if area.has_method("take_damage") else area.get_parent()
		if target:
			_apply_contact_damage_to_player(target)


func _on_charge_hitbox_body_entered(body: Node2D) -> void:
	if current_state != State.CHARGING or body == self or body.is_in_group("enemy"):
		return
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(charge_damage)
			print("💥 ¡Placaje impactó al jugador! Daño: ", charge_damage)


func _on_charge_hitbox_area_entered(area: Area2D) -> void:
	if current_state != State.CHARGING or area.is_in_group("enemy") or area.get_parent() == self:
		return
	if area.is_in_group("player") or area.name == "Hurtbox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		var target = area if area.has_method("take_damage") else area.get_parent()
		if target and target.has_method("take_damage"):
			target.take_damage(charge_damage)
			print("💥 ¡Placaje impactó al Hurtbox del jugador! Daño: ", charge_damage)


func _apply_contact_damage_to_player(target_node: Node) -> void:
	if _contact_timer > 0.0 or current_state == State.DEAD:
		return

	if target_node.has_method("take_damage"):
		_contact_timer = contact_damage_interval
		target_node.take_damage(contact_damage)
		print("🐍 Contacto con el jugador. Daño: ", contact_damage)


# ==============================================================================
# SISTEMA DE SALUD, DAÑO RECIBIDO Y ATURDIMIENTO
# ==============================================================================

## Recibe daño de proyectiles (Revólver: 1.0, Rifle: 10.0).
func take_damage(amount: float) -> void:
	if current_state == State.DEAD:
		return

	current_health = clampf(current_health - amount, 0.0, max_health)
	health_changed.emit(current_health, max_health)

	if health_bar:
		health_bar.value = current_health

	print("🐍 Basilisco recibió ", amount, " de daño. Vida: ", current_health, "/", max_health)

	# Efecto visual de impacto
	_play_hit_flash(amount)

	if audio_hit:
		audio_hit.play()

	if current_health <= 0.0:
		die()


## Aturdimiento aplicado por el disparo de rifle.
func apply_stun(duration: float) -> void:
	if current_state == State.DEAD:
		return

	is_stunned = true
	_stun_timer = duration
	current_state = State.STUNNED
	velocity = Vector2.ZERO

	if charge_hitbox:
		charge_hitbox.monitoring = false
	if dust_particles:
		dust_particles.emitting = false
	if fire_charge_particles:
		fire_charge_particles.emitting = false

	if sprite:
		sprite.modulate = Color(0.6, 0.8, 1.4, 1.0) # Tinte azulado/eléctrico de aturdimiento

	if stun_label:
		stun_label.visible = true
		stun_label.text = "¡ATURDIDO! (%.1fs)" % duration

	print("💫 ¡El Basilisco ha sido aturdido por el rifle durante ", duration, "s!")


func stun(duration: float) -> void:
	apply_stun(duration)


func _process_stun(delta: float) -> void:
	_stun_timer -= delta
	if stun_label:
		stun_label.text = "¡ATURDIDO! (%.1fs)" % max(_stun_timer, 0.0)

	if _stun_timer <= 0.0:
		is_stunned = false
		if stun_label:
			stun_label.visible = false
		if sprite:
			sprite.modulate = Color.WHITE
		current_state = State.IDLE_CHASE
		print("🐍 El Basilisco se recuperó del aturdimiento.")


func _play_hit_flash(amount: float) -> void:
	if sprite == null:
		return

	var flash_color := Color(2.5, 2.5, 2.5) if amount >= 5.0 else Color(1.8, 0.6, 0.6)
	sprite.modulate = flash_color

	var tween := create_tween()
	var normal_color := Color(0.6, 0.8, 1.4) if is_stunned else Color.WHITE
	tween.tween_property(sprite, "modulate", normal_color, 0.15)

	# Sacudida
	var shake_val := 8.0 if amount >= 5.0 else 4.0
	var shake_tween := create_tween()
	shake_tween.tween_property(sprite, "position:x", shake_val, 0.03)
	shake_tween.tween_property(sprite, "position:x", -shake_val, 0.03)
	shake_tween.tween_property(sprite, "position:x", 0.0, 0.03)


# ==============================================================================
# MUERTE Y VICTORIA
# ==============================================================================

func die() -> void:
	if current_state == State.DEAD:
		return

	current_state = State.DEAD
	velocity = Vector2.ZERO
	died.emit()

	print("💀 ¡El Basilisco ha sido derrotado!")

	if audio_death:
		audio_death.play()

	if charge_hitbox:
		charge_hitbox.monitoring = false
	if contact_area:
		contact_area.monitoring = false
	if dust_particles:
		dust_particles.emitting = false
	if fire_charge_particles:
		fire_charge_particles.emitting = false

	# Animación de desvanecimiento / derrota
	if sprite:
		var death_tween := create_tween()
		death_tween.tween_property(sprite, "modulate", Color(1.5, 0.2, 0.2, 0.0), 1.5)
		death_tween.parallel().tween_property(sprite, "scale", Vector2(0.8, 0.05), 1.5)

	if stun_label:
		stun_label.visible = false

	# Esperar final de animación de muerte
	var tree := get_tree()
	if tree:
		await tree.create_timer(1.6).timeout

	# Crear portal de retorno a la biblioteca en la posición del jefe
	if portal_scene:
		var portal = portal_scene.instantiate()
		portal.global_position = global_position
		var t := get_tree()
		if t and t.current_scene:
			t.current_scene.add_child(portal)
		elif get_parent():
			get_parent().add_child(portal)
		print("🌀 Portal de retorno creado en: ", portal.global_position)

	queue_free()


func _find_player() -> void:
	var tree := get_tree()
	if tree == null:
		return
	var players := tree.get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0] as CharacterBody2D
