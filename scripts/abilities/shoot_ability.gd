## Shoot ability script for the player character.
##
## Attach as a child Node of CharacterBody2D.
## Spawns bullet projectiles toward the mouse cursor position
## when the "shoot" action is pressed.
extends Node

# --- Configuración ---
## Escena de la bala a instanciar.
@export var bullet_scene: PackedScene
## Tiempo mínimo entre disparos en segundos.
@export var fire_cooldown: float = 0.25

# --- Estado interno ---
var _can_shoot: bool = true

@onready var _cooldown_timer: Timer = Timer.new()
@onready var _player: CharacterBody2D = get_parent()
@onready var _shoot_origin: Marker2D = _player.get_node("ShootOrigin")


func _ready() -> void:
	# Configurar timer de cooldown
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = fire_cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot") and _can_shoot:
		_shoot()


## Instancia y dispara una bala hacia la posición del mouse.
func _shoot() -> void:
	if bullet_scene == null:
		push_warning("ShootAbility: No se asignó bullet_scene.")
		return

	_can_shoot = false
	_cooldown_timer.start()

	# Calcular dirección hacia el mouse
	var mouse_pos: Vector2 = _player.get_global_mouse_position()
	var direction: Vector2 = (mouse_pos - _shoot_origin.global_position).normalized()

	# Instanciar bala
	var bullet: Node2D = bullet_scene.instantiate()
	bullet.global_position = _shoot_origin.global_position
	bullet.direction = direction

	# Agregar la bala al árbol de escena (fuera del jugador para que no se mueva con él)
	_player.get_tree().current_scene.add_child(bullet)


func _on_cooldown_timeout() -> void:
	_can_shoot = true
