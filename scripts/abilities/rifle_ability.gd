## Rifle ability script for the player character.
## Disparo de rifle de alta potencia (10 DMG + Aturdimiento) con cooldown e indicador visual.
extends Node

# --- Configuración ---
@export var rifle_bullet_scene: PackedScene = preload("res://scenes/projectiles/RifleBullet.tscn")
@export var cooldown: float = 2.5
@export var recoil_strength: float = 120.0

# --- Señales ---
signal rifle_shot_fired
signal rifle_cooldown_started(duration: float)
signal rifle_cooldown_progress(progress: float)
signal rifle_ready

# --- Estado interno ---
var _can_shoot: bool = true

@onready var _cooldown_timer: Timer = Timer.new()
@onready var _player: CharacterBody2D = get_parent()
@onready var _shoot_origin: Marker2D = _player.get_node_or_null("ShootOrigin")
@onready var _rifle_bar: ProgressBar = _player.get_node_or_null("RifleBar")
@onready var _audio_audiorifle: AudioStreamPlayer2D = \
	_player.get_node_or_null("AudioRifle")

@onready var _audio_audioriflevacio: AudioStreamPlayer2D = \
	_player.get_node_or_null("AudioRifleVacio")

func _ready() -> void:
	if _rifle_bar:
		_rifle_bar.min_value = 0.0
		_rifle_bar.max_value = 100.0
		_rifle_bar.value = 100.0
		_rifle_bar.visible = false

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
		if _audio_audioriflevacio:
			_audio_audioriflevacio.stop()
			_audio_audioriflevacio.play()
		else:
			print("⚠️ No se encontró AudioRifleVacio")

		return

	_can_shoot = false
	_cooldown_timer.start()
	rifle_cooldown_started.emit(cooldown)

	if _rifle_bar:
		_rifle_bar.value = 0.0
		_rifle_bar.visible = true

	# Dirección hacia el mouse
	var mouse_pos: Vector2 = _player.get_global_mouse_position()
	var origin_pos: Vector2 = _shoot_origin.global_position if _shoot_origin else _player.global_position
	var direction: Vector2 = (mouse_pos - origin_pos).normalized()

	# Instanciar bala de rifle
	var bullet: Node2D = rifle_bullet_scene.instantiate()
	bullet.global_position = origin_pos
	bullet.direction = direction

	# Agregar al árbol
	var tree := _player.get_tree() if _player else null
	if tree and tree.current_scene:
		tree.current_scene.add_child(bullet)
	elif _player and _player.get_parent():
		_player.get_parent().add_child(bullet)

	# Sonido del disparo del rifle
	if _audio_audiorifle:
		_audio_audiorifle.stop()
		_audio_audiorifle.play()
	else:
		print("⚠️ No se encontró AudioRifle")

	# Retroceso leve sobre el jugador
	if _player is CharacterBody2D:
		_player.velocity -= direction * recoil_strength


func _on_cooldown_timeout() -> void:
	_can_shoot = true
	if _rifle_bar:
		_rifle_bar.value = 100.0
		_rifle_bar.visible = false
	rifle_ready.emit()


func _process(_delta: float) -> void:
	if not _can_shoot:
		var progress: float = 1.0 - (_cooldown_timer.time_left / cooldown)
		rifle_cooldown_progress.emit(progress)
		if _rifle_bar:
			_rifle_bar.value = progress * 100.0
			_rifle_bar.visible = true
	else:
		if _rifle_bar and _rifle_bar.visible:
			_rifle_bar.visible = false
