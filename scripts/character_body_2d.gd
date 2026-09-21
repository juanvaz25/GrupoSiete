extends CharacterBody2D

# =========================
# VIDA DEL BOSS
# =========================


#Variables generales
@export var max_health: float = 100.0
@export var speed: float = 500.0
@export var chase_distance: float = 280.0

var current_health: float
var player: Node2D = null

#Variables de enbestida
@export var charge_speed: float = 700.0
@export var charge_duration: float = 0.7
@export var charge_prepare_time: float = 0.8
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
		player = players[0]
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
		move_and_slide()
	else:
		velocity = Vector2.ZERO

		if can_attack:
			print("🎯 DISTANCIA DE ATAQUE: ", distance)
			start_charge()

# =========================
# RECIBIR DAÑO
# =========================

func start_charge() -> void:
	if not can_attack or is_charging:
		return

	can_attack = false

	print("🐐 ¡LA CABRA SE PREPARA PARA EMBESTIR!")

	charge_direction = global_position.direction_to(player.global_position)

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
		
func _process(_delta: float) -> void:
	if Input.is_key_pressed(KEY_SPACE):
		take_damage(1)


# =========================
# MUERTE
# =========================

func _on_hitbox_area_entered(area: Area2D) -> void:
	print("💥 HITBOX DETECTÓ AREA: ", area.name)
	print("   Padre: ", area.get_parent().name)
	

func die() -> void:
	print("💀 LA CABRA MURIÓ")

	queue_free()
