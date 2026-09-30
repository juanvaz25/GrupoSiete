
## Shoot ability script for the player character.
## Revolver con 6 balas y recarga automática.
extends Node

# --- Configuración ---
@export var bullet_scene: PackedScene = preload("res://scenes/projectiles/Bullet.tscn")
@export var fire_cooldown: float = 0.15
@export var magazine_size: int = 6
@export var reload_time: float = 1.5

# --- Señales ---
signal ammo_changed(current_ammo: int, max_ammo: int)
signal reload_started(duration: float)
signal reload_finished

# --- Estado interno ---
var _can_shoot: bool = true
var _ammo: int = 6
var _is_reloading: bool = false


# --- Referencias ---
@onready var _cooldown_timer: Timer = Timer.new()
@onready var _reload_timer: Timer = Timer.new()

@onready var _player: CharacterBody2D = get_parent()

@onready var _shoot_origin: Marker2D = \
	_player.get_node_or_null("ShootOrigin")

@onready var _reload_bar: ProgressBar = \
	_player.get_node_or_null("ReloadBar")

@onready var _ammo_hud = \
	_player.get_node_or_null("AmmoHUD")

@onready var _audio_disparo: AudioStreamPlayer2D = \
	_player.get_node_or_null("AudioDisparo")

@onready var _audio_sinbala: AudioStreamPlayer2D = \
	_player.get_node_or_null("AudioSinBalas")



func _ready() -> void:
	_ammo = magazine_size

	# Asegurar que el audio pertenezca al bus SFX de la configuración
	if _audio_disparo:
		_audio_disparo.bus = &"SFX"
	if _audio_sinbala:
		_audio_sinbala.bus = &"SFX"

	print("🔫 ShootAbility iniciado")
	print("Munición inicial: ", _ammo)

	# -------------------------------------------------
	# Barra de recarga
	# -------------------------------------------------
	if _reload_bar:
		_reload_bar.min_value = 0.0
		_reload_bar.max_value = 100.0
		_reload_bar.value = 0.0
		_reload_bar.visible = false

	# -------------------------------------------------
	# Timer entre disparos
	# -------------------------------------------------
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = fire_cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	# -------------------------------------------------
	# Timer de recarga
	# -------------------------------------------------
	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	_reload_timer.timeout.connect(_on_reload_timeout)
	add_child(_reload_timer)

	# Actualizar HUD inicialmente
	ammo_changed.emit(_ammo, magazine_size)


func _unhandled_input(event: InputEvent) -> void:

	# ---------------------------------------------
	# Disparo
	# ---------------------------------------------
	if event.is_action_pressed("shoot"):
		_shoot()

	# ---------------------------------------------
	# Recarga manual con R
	# ---------------------------------------------
	elif event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:

			if not _is_reloading and _ammo < magazine_size:
				_start_reload()


func _shoot() -> void:
	if bullet_scene == null:
		push_warning("ShootAbility: No se asignó bullet_scene.")
		return

	# Si está recargando, no dispara.
	# Solo reproduce el sonido de arma vacía.
	if _is_reloading:
		if _audio_sinbala:
			_audio_sinbala.stop()
			_audio_sinbala.play()
		return

	# Cooldown entre disparos
	if not _can_shoot:
		return

	# Si no hay balas
	if _ammo <= 0:
		if _audio_sinbala:
			_audio_sinbala.stop()
			_audio_sinbala.play()

		_start_reload()
		return

	# -----------------------------------------
	# CONSUMIR BALA
	# -----------------------------------------
	_ammo -= 1

	if _ammo_hud:
		_ammo_hud.update_ammo(_ammo)

	ammo_changed.emit(_ammo, magazine_size)

	# -----------------------------------------
	# COOLDOWN
	# -----------------------------------------
	_can_shoot = false
	_cooldown_timer.start()

	# -----------------------------------------
	# DIRECCIÓN HACIA EL MOUSE
	# -----------------------------------------
	var mouse_pos: Vector2 = _player.get_global_mouse_position()

	var origin_pos: Vector2 = (
		_shoot_origin.global_position
		if _shoot_origin
		else _player.global_position
	)

	var direction: Vector2 = (
		mouse_pos - origin_pos
	).normalized()

	# -----------------------------------------
	# CREAR BALA
	# -----------------------------------------
	var bullet: Node2D = bullet_scene.instantiate()

	bullet.global_position = origin_pos
	bullet.direction = direction

	# -----------------------------------------
	# AGREGAR BALA
	# -----------------------------------------
	var tree := _player.get_tree() if _player else null

	if tree and tree.current_scene:
		tree.current_scene.add_child(bullet)
	elif _player and _player.get_parent():
		_player.get_parent().add_child(bullet)

	# -----------------------------------------
	# SONIDO DEL DISPARO
	# -----------------------------------------
	if _audio_disparo:
		_audio_disparo.stop()
		_audio_disparo.play()
	else:
		print("⚠️ No se encontró AudioDisparo")

	# -----------------------------------------
	# ÚLTIMA BALA
	# -----------------------------------------
	if _ammo == 0:

		print("🔫 Última bala disparada")

		if _ammo_hud:
			_ammo_hud.reload_ammo(reload_time + 0.4)

		_start_reload()


func _start_reload() -> void:

	# Evitar iniciar dos recargas simultáneamente
	if _is_reloading:
		return


	_is_reloading = true
	_can_shoot = false


	# Iniciar timer real de recarga
	_reload_timer.wait_time = reload_time
	_reload_timer.start()


	# Reiniciar barra visual
	if _reload_bar:
		_reload_bar.value = 0
		_reload_bar.visible = true


	# Avisar que comenzó la recarga
	reload_started.emit(reload_time)


	print("⏳ Recarga iniciada. Duración: ", reload_time, " segundos")


func _on_cooldown_timeout() -> void:

	_can_shoot = true


func _on_reload_timeout() -> void:

	# =================================================
	# RECARGA TERMINADA
	# =================================================

	_ammo = magazine_size

	_is_reloading = false
	_can_shoot = true


	# Actualizar HUD por seguridad
	if _ammo_hud:
		_ammo_hud.update_ammo(_ammo)


	# Completar barra
	if _reload_bar:
		_reload_bar.value = 100
		_reload_bar.visible = false


	# Avisar que terminó
	ammo_changed.emit(_ammo, magazine_size)
	reload_finished.emit()


	print("🔫 RECARGA COMPLETA. Munición: ", _ammo)


func _process(_delta: float) -> void:

	if _is_reloading:

		# Progreso de 0 a 100 basado en el mismo
		# timer que controla la recarga real.
		var progress: float = (
			1.0 -
			(_reload_timer.time_left / reload_time)
		)


		if _reload_bar:
			_reload_bar.value = progress * 100.0
			_reload_bar.visible = true

	else:

		if _reload_bar and _reload_bar.visible:
			_reload_bar.visible = false
