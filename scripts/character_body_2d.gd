extends CharacterBody2D

# =========================
# VIDA DEL BOSS
# =========================


#Variables generales
@export var max_health: float = 100.0
@export var speed: float = 700.0
@export var chase_distance: float = 280.0

var current_health: float
var player: CharacterBody2D = null

#Variables de enbestida
@export var charge_speed: float = 1100.0
@export var charge_duration: float = 0.8
@export var charge_prepare_time: float = 0.5
@export var charge_cooldown: float = 2.0



var is_charging: bool = false
var can_attack: bool = true
var charge_direction: Vector2 = Vector2.ZERO
var player_hit_this_charge := false


@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealBarr
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
		
	sprite.play("default")
	
	current_health = max_health
	
	hitbox.monitoring = false
	
	health_bar.max_value = max_health
	health_bar.value = current_health

	print("🐐 CABRA INICIADA")
	print("Vida: ", current_health, "/", max_health)

	# Esperamos a que todos los nodos terminen su _ready()
	await get_tree().process_frame

	var players := get_tree().get_nodes_in_group("player")

	if players.size() > 0:
		player = players[0] as CharacterBody2D
		print("🎯 Player encontrado: ", player.name)
	else:
		print("❌ NO SE ENCONTRÓ AL PLAYER")


#seguir al jugador
func _physics_process(_delta: float) -> void:
	if player == null:
		return

	if is_charging:
		return
	
	var distance := global_position.distance_to(player.global_position)

	if distance > chase_distance:
		var direction := global_position.direction_to(player.global_position)

		velocity = direction * speed

		# Animación de caminar según la dirección
		var animation_name := get_walk_animation(direction)
		sprite.play(animation_name)

		move_and_slide()

	else:
		velocity = Vector2.ZERO

		# Cuando está quieta, vuelve al idle
		#sprite.play("default")

		if can_attack:
			print("🎯 DISTANCIA DE ATAQUE: ", distance)
			start_charge()

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

func get_charge_animation(direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	if angle >= -PI / 8 and angle < PI / 8:
		return "charge_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return "charge_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return "charge_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return "charge_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return "charge_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return "charge_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return "charge_up"

	# ARRIBA-DERECHA
	else:
		return "charge_up_right"

# =========================
# RECIBIR DAÑO
# =========================

func start_charge() -> void:
	if not can_attack or is_charging:
		return

	can_attack = false

	print("🐐 ¡LA CABRA SE PREPARA PARA EMBESTIR!")
	
	

	# Elegir animación según la dirección del ataque
	var animation_name := get_charge_animation(charge_direction)

	print("🎬 Animación de embestida: ", animation_name)

	sprite.play(animation_name)

	# Efecto visual de preparación
	sprite.modulate = Color(1.0, 0.3, 0.3)
	sprite.scale = Vector2(1.15, 1.15)

	await get_tree().create_timer(charge_prepare_time).timeout

	# Restaurar apariencia
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE

	start_charging()
	
func start_charging() -> void:
	is_charging = true
	player_hit_this_charge = false
	
	print("🐐💨 ¡EMBESTIDA!")

	# Activar hitbox
	hitbox.monitoring = true

	var elapsed := 0.0
	var distance := global_position.distance_to(player.global_position)
	var travel_time := distance / charge_speed
	var prediction_time := charge_prepare_time + travel_time
	var predicted_position := player.global_position + player.velocity * prediction_time

	charge_direction = global_position.direction_to(predicted_position)
	
	while elapsed < charge_duration:
		velocity = charge_direction * charge_speed
		move_and_slide()

		await get_tree().physics_frame

		elapsed += get_physics_process_delta_time()

	# Termina la embestida
	velocity = Vector2.ZERO

	# Desactivar hitbox
	hitbox.monitoring = false

	is_charging = false
	
	sprite.play("default")

	print("🐐 La Cabra terminó la embestida")

	await get_tree().create_timer(charge_cooldown).timeout

	can_attack = true

func _on_hitbox_body_entered(body: Node2D) -> void:
	if not is_charging:
		return

	if player_hit_this_charge:
		return

	if body.is_in_group("player"):
		player_hit_this_charge = true

		print("💥 ¡LA CABRA GOLPEÓ AL PLAYER!")

		if body.has_method("take_damage"):
			body.take_damage(1.0)

func take_damage(amount: float) -> void:
	current_health -= amount
	current_health = max(current_health, 0.0)

	health_bar.value = current_health

	print("🐐 La Cabra recibió ", amount, " de daño")
	print("❤️ Vida: ", current_health, "/", max_health)

	if current_health <= 0:
		die()
		
		
# =========================
# MUERTE
# =========================

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("💥 HITBOX DETECTÓ AREA: ", area.name)
	print("   Padre: ", area.get_parent().name)
	

func die() -> void:
	print("💀 LA CABRA MURIÓ")

	queue_free()
