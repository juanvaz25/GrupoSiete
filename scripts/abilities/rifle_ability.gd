## Rifle ability script for the player character.
## Disparo de rifle de alta potencia con cooldown y aturdimiento.
extends Node

# --- Configuración ---
@export var rifle_bullet_scene: PackedScene = preload("res://scenes/projectiles/RifleBullet.tscn")
@export var cooldown: float = 2.5
@export var recoil_strength: float = 120.0

# --- Señales ---
signal rifle_shot_fired
signal rifle_cooldown_started(duration: float)
signal rifle_ready

# --- Estado interno ---
var _can_shoot: bool = true

@onready var _cooldown_timer: Timer = Timer.new()
@onready var _player: CharacterBody2D = get_parent()
@onready var _shoot_origin: Marker2D = _player.get_node("ShootOrigin")


func _ready() -> void:
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot_rifle"):
		_shoot()


func _shoot() -> void:
	if rifle_bullet_scene == null:
		push_warning("RifleAbility: No se asignó rifle_bullet_scene.")
		return

	if not _can_shoot:
		return

	_can_shoot = false
	_cooldown_timer.start()
	rifle_cooldown_started.emit(cooldown)

	# Dirección hacia el mouse
	var mouse_pos: Vector2 = _player.get_global_mouse_position()
	var direction: Vector2 = (
		mouse_pos - _shoot_origin.global_position
	).normalized()

	# Instanciar bala de rifle
	var bullet: Node2D = rifle_bullet_scene.instantiate()
	bullet.global_position = _shoot_origin.global_position
	bullet.direction = direction

	# Agregar al árbol
	_player.get_tree().current_scene.add_child(bullet)

	# Retroceso leve sobre el jugador
	if _player is CharacterBody2D:
		_player.velocity -= direction * recoil_strength

	rifle_shot_fired.emit()
	print("Disparo de Rifle efectuado (10 DMG + Stun). Cooldown de ", cooldown, "s iniciado.")


func _on_cooldown_timeout() -> void:
	_can_shoot = true
	rifle_ready.emit()
	print("Rifle listo para disparar.")
