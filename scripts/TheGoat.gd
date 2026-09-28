extends CharacterBody2D

# =========================
# VIDA DEL BOSS
# =========================

# Variables generales
@export_group("Estadísticas")
## Indica si este enemigo es el jefe principal de la sala.
@export var is_boss: bool = true
## Nombre del enemigo
@export var title: String = "The Goat"
## Nombre y vida visible
@export var title_and_health_visible: bool = true
## Vida del enemigo
@export var max_health: float = 100.0
## Velocidad de movimiento base
@export var speed: float = 700.0
## Distancia a la que detecta al player
@export var chase_distance: float = 280.0
## Daño al tocar al personaje (0.5 según especificación).
@export var contact_damage: float = 0.5

@export_group("Portal de Retorno")
## Escena del portal de retorno a la biblioteca tras vencer al jefe.
@export var portal_scene: PackedScene = preload("res://scenes/portal_retorno.tscn")

var current_health: float
var player: CharacterBody2D = null
var is_dying: bool = false


@export_group("Habilidad: Embestida")
## Velocidad cuando ejecuta Embestida
@export var charge_speed: float = 1100.0
## Cuanto tiempo dura la Embestida
@export var charge_duration: float = 0.8
## Cuanto tarda en prepararse para Embestir
@export var charge_prepare_time: float = 0.5
## Cooldown antes de poder volver a Embestir
@export var charge_cooldown: float = 2.0
## Embestida predictiva (utilizar en velocidad baja)
@export var advanced_charge: bool = false


@export_group("Rastro de fuego")
@export var fire_trail_enabled: bool = false
@export var burn_manager: Node2D
@export var fire_radius: float = 40.0
@export var fire_spacing: float = 24.0

var _fire_distance_left: float = 0.0



var is_charging: bool = false
var can_attack: bool = true
var charge_direction: Vector2 = Vector2.ZERO
var player_hit_this_charge := false


@onready var hitbox: Area2D = $Hitbox
@onready var health_bar: ProgressBar = $HealthBar
@onready var boss_title: Label = $BossTitle
@onready var sprite: AnimatedSprite2D = $AnimatedSprite2D

func _ready() -> void:
	add_to_group("enemy")
	add_to_group("goat")
	if is_boss and title_and_health_visible:
		add_to_group("boss")

	sprite.play("default")
	boss_title.text = title
	current_health = max_health
	boss_title.visible = title_and_health_visible
	health_bar.visible = title_and_health_visible

	health_bar.max_value = max_health
	health_bar.value = current_health

	print("🐐 CABRA INICIADA: ", title, " (Boss: ", is_boss, ")")
	print("Vida: ", current_health, "/", max_health)

	# Esperamos a que todos los nodos terminen su _ready()
	await get_tree().process_frame

	var players := get_tree().get_nodes_in_group("player")

	if hitbox:
		hitbox.set("damage", contact_damage)
		hitbox.body_entered.connect(_on_hitbox_body_entered)
		hitbox.area_entered.connect(_on_hitbox_body_entered)

	if players.size() > 0:
		player = players[0] as CharacterBody2D
		print("🎯 Player encontrado: ", player.name)
	else:
		print("❌ NO SE ENCONTRÓ AL PLAYER")


# Seguir al jugador
func _physics_process(_delta: float) -> void:
	if is_dying or player == null or is_charging:
		return

	var distance := global_position.distance_to(player.global_position)

	if distance > chase_distance:
		var direction := global_position.direction_to(player.global_position)

		velocity = direction * speed

		sprite.play(Utility.get_direction("walk", direction))
		move_and_slide()

	else:
		velocity = Vector2.ZERO
		if can_attack:
			print("🎯 DISTANCIA DE ATAQUE: ", distance)
			start_charge()


# RECIBIR DAÑO
func take_damage(amount: float) -> void:
	if is_dying:
		return

	current_health -= amount
	current_health = max(current_health, 0.0)

	if health_bar:
		health_bar.value = current_health

	print("🐐 ", title, " recibió ", amount, " de daño")
	print("❤️ Vida: ", current_health, "/", max_health)

	if current_health <= 0:
		die()


func start_charge() -> void:
	if is_dying or not can_attack or is_charging:
		return

	can_attack = false

	print("🐐 ¡LA CABRA SE PREPARA PARA EMBESTIR!")

	charge_direction = global_position.direction_to(player.global_position)

	sprite.play(Utility.get_direction("charge", charge_direction))

	# Efecto visual de preparación
	sprite.modulate = Color(1.0, 0.3, 0.3)
	sprite.scale = Vector2(1.15, 1.15)

	await get_tree().create_timer(charge_prepare_time).timeout

	if is_dying:
		return

	# Restaurar apariencia
	sprite.modulate = Color.WHITE
	sprite.scale = Vector2.ONE

	start_charging()


func start_charging() -> void:
	if is_dying:
		return

	is_charging = true
	player_hit_this_charge = false

	print("🐐💨 ¡EMBESTIDA!")

	var elapsed := 0.0
	var distance := global_position.distance_to(player.global_position)
	var travel_time := distance / charge_speed
	var prediction_time := charge_prepare_time + travel_time
	var predicted_position := player.global_position + player.velocity * prediction_time
	if advanced_charge:
		charge_direction = global_position.direction_to(predicted_position)
	else:
		charge_direction = global_position.direction_to(player.global_position)
	
	#_start_fire_trail()
	
	while elapsed < charge_duration:
		if is_dying:
			return
		
		#var previous_position := global_position
		velocity = charge_direction * charge_speed
		move_and_slide()
		
		#_burn_movement(previous_position, global_position)
		
		await get_tree().physics_frame

		elapsed += get_physics_process_delta_time()

	if is_dying:
		return

	# Termina la embestida
	velocity = Vector2.ZERO

	is_charging = false

	sprite.play("default")

	print("🐐 La Cabra terminó la embestida")

	await get_tree().create_timer(charge_cooldown).timeout

	if is_dying:
		return

	can_attack = true


func _on_hitbox_body_entered(body: Node2D) -> void:
	if is_dying:
		return

	if body.is_in_group("player"):
		print("💥 ¡LA CABRA GOLPEÓ AL PLAYER!")
		if body.has_method("take_damage"):
			body.take_damage(1.0)


func _on_hitbox_area_entered(area: Area2D) -> void:
	if is_dying or not is_charging:
		return

	if player_hit_this_charge:
		return

	print("🐐 Hitbox detectó Area2D: ", area.name)

	# Comprobar si el Area2D pertenece al Player
	var target := area.get_parent()

	if target == null:
		return

	if target.is_in_group("player"):
		player_hit_this_charge = true
		print("💥 ¡LA CABRA GOLPEÓ AL PLAYER!")
		if target.has_method("take_damage"):
			target.take_damage(1.0)


# =========================
# MUERTE Y PORTAL DE RETORNO
# =========================
func die() -> void:
	if is_dying:
		return
	is_dying = true
	print("💀 Enemigo murió: ", name, " (", title, ")")

	set_physics_process(false)
	set_process(false)
	velocity = Vector2.ZERO

	if hitbox:
		hitbox.set_deferred("monitoring", false)
		hitbox.set_deferred("monitorable", false)
	var hurtbox := get_node_or_null("Hurtbox")
	if hurtbox:
		hurtbox.set_deferred("monitoring", false)
		hurtbox.set_deferred("monitorable", false)
	var col := get_node_or_null("CollisionShape2D")
	if col:
		col.set_deferred("disabled", true)

	if health_bar:
		health_bar.visible = false
	if boss_title:
		boss_title.visible = false

	# Si este enemigo es el boss principal (The Goat)
	if is_boss and title_and_health_visible:
		print("🏆 ¡EL BOSS THE GOAT FUE DERROTADO!")

		# 1. Matar a todos los otros enemigos/cabras en la sala
		var goats := get_tree().get_nodes_in_group("goat")
		for other in goats:
			if other != self and is_instance_valid(other) and not other.get("is_dying"):
				if other.has_method("die"):
					other.die()
				else:
					other.queue_free()

		var enemies := get_tree().get_nodes_in_group("enemy")
		for other in enemies:
			if other != self and is_instance_valid(other) and not other.is_in_group("player") and not other.get("is_dying"):
				if other.has_method("die"):
					other.die()
				else:
					other.queue_free()

		# 2. Instanciar el portal de retorno a la biblioteca en la posición del jefe
		if portal_scene:
			var portal = portal_scene.instantiate()
			portal.global_position = global_position
			var t := get_tree()
			if t and t.current_scene:
				t.current_scene.add_child(portal)
			elif get_parent():
				get_parent().add_child(portal)
			print("🌀 Portal de retorno creado en: ", portal.global_position)


func _can_burn() -> bool:
	return (
		fire_trail_enabled
		and is_instance_valid(burn_manager)
		and burn_manager.has_method("burn_at")
	)
	
func _start_fire_trail() -> void:
	_fire_distance_left = maxf(fire_spacing, 1.0)
	if _can_burn():
		burn_manager.burn_at(global_position, fire_radius)

func _burn_movement(from: Vector2, to: Vector2) -> void:
	if not _can_burn():
		return

	var distance := from.distance_to(to)

	if distance <= 0.001:
		return

	var direction := from.direction_to(to)
	var spacing := maxf(fire_spacing, 1.0)
	var travelled := 0.0

	# Completa puntos intermedios si recorrió mucha distancia
	# durante una sola actualización.
	while distance - travelled >= _fire_distance_left:
		travelled += _fire_distance_left

		var point := from + direction * travelled
		burn_manager.burn_at(point, fire_radius)

		_fire_distance_left = spacing

	_fire_distance_left -= distance - travelled




	# Animación de desvanecimiento suave
	if sprite and is_inside_tree():
		var tween := create_tween()
		if tween:
			tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
			await tween.finished

	queue_free()
