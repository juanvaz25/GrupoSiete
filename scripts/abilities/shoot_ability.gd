
## Shoot ability script for the player character.
## Revolver con 6 balas y recarga automática.
extends Node

# --- Configuración ---
@export var bullet_scene: PackedScene
@export var fire_cooldown: float = 0.1
@export var magazine_size: int = 6
@export var reload_time: float = 1.5


# --- Estado interno ---
var _can_shoot: bool = true
var _ammo: int = 6
var _is_reloading: bool = false

@onready var _cooldown_timer: Timer = Timer.new()
@onready var _reload_timer: Timer = Timer.new()
@onready var _player: CharacterBody2D = get_parent()
@onready var _shoot_origin: Marker2D = _player.get_node("ShootOrigin")
@onready var _reload_bar: ProgressBar = _player.get_node("ReloadBar")


func _ready() -> void:
	_ammo = magazine_size
	
	_reload_bar.value = 0
	_reload_bar.visible = false
	
	# Timer entre disparos
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = fire_cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	# Timer de recarga
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	_reload_timer.timeout.connect(_on_reload_timeout)
	add_child(_reload_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("shoot"):
		_shoot()


func _shoot() -> void:
	if bullet_scene == null:
		push_warning("ShootAbility: No se asignó bullet_scene.")
		return

	# No dispara durante la recarga
	if _is_reloading:
		return

	# No dispara si está esperando el cooldown
	if not _can_shoot:
		return

	# Si no quedan balas, comienza la recarga
	if _ammo <= 0:
		_start_reload()
		return

	# Consume una bala
	_ammo -= 1
	_can_shoot = false
	_cooldown_timer.start()

	# Dirección hacia el mouse
	var mouse_pos: Vector2 = _player.get_global_mouse_position()
	var direction: Vector2 = (
		mouse_pos - _shoot_origin.global_position
	).normalized()

	# Instanciar bala
	var bullet: Node2D = bullet_scene.instantiate()
	bullet.global_position = _shoot_origin.global_position
	bullet.direction = direction

	# Agregar la bala a la escena
	_player.get_tree().current_scene.add_child(bullet)

	print("Balas restantes: ", _ammo)

	# Si gastó la última bala, recarga automáticamente
	if _ammo == 0:
		_start_reload()


func _start_reload() -> void:
	if _is_reloading:
		return

	_is_reloading = true
	_can_shoot = false
	_reload_timer.start()

	_reload_bar.value = 0
	_reload_bar.visible = true

	print("Recargando revólver...")


func _on_cooldown_timeout() -> void:
	_can_shoot = true


func _on_reload_timeout() -> void:
	_ammo = magazine_size
	_is_reloading = false
	_can_shoot = true

	_reload_bar.value = 100
	_reload_bar.visible = false

	print("Revólver recargado. Balas: ", _ammo)
	
	
func _process(_delta: float) -> void:
	if _is_reloading:
		# Porcentaje de recarga completado
		var progress: float = 1.0 - (
			_reload_timer.time_left / reload_time
		)

		_reload_bar.value = progress * 100.0
		_reload_bar.visible = true
	else:
		_reload_bar.visible = false
