extends Node2D

@export var reload_time: float = 2
@export var fire_cooldown: float = 0.4

var _can_shoot: bool = true
var _ammo: int = 6
var _is_reloading: bool = false
var magazine_size: int = 6

var _cargando: bool = false
var _tiempo_visible: float = 0.0

@export var tiempo_minimo: float = 1.0


signal ammo_changed(current_ammo: int, max_ammo: int)
signal reload_started(duration: float)
@onready var _cooldown_timer: Timer = Timer.new()
@onready var _reload_timer: Timer = Timer.new()
@onready var _ammo_hud: CanvasLayer = $AmmoHUD
	
	
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = fire_cooldown
	_cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(_cooldown_timer)

	_reload_timer.one_shot = true
	_reload_timer.wait_time = reload_time
	_reload_timer.timeout.connect(_on_reload_timeout)
	add_child(_reload_timer)

	_ammo = magazine_size
	_ammo_hud.update_ammo(_ammo)
	ammo_changed.emit(_ammo, magazine_size)
	# Si ejecutás Loading sola con F6, solo muestra la animación.
	if SceneLoader.destino.is_empty():
		return

	var error := ResourceLoader.load_threaded_request(
		SceneLoader.destino
	)

	if error != OK:
		SceneLoader.cambiando = false
		push_error("No se pudo iniciar la carga del destino.")
		return

	_cargando = true


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_shoot()

	if not _cargando:
		return

	_tiempo_visible += delta

	var estado := ResourceLoader.load_threaded_get_status(
		SceneLoader.destino
	)

	if estado == ResourceLoader.THREAD_LOAD_LOADED:
		if _tiempo_visible < tiempo_minimo:
			return

		_cargando = false

		var escena := ResourceLoader.load_threaded_get(
			SceneLoader.destino
		) as PackedScene

		if escena == null:
			SceneLoader.cambiando = false
			push_error("El destino no es una escena válida.")
			return

		var error := get_tree().change_scene_to_packed(escena)
		SceneLoader.cambiando = false

		if error != OK:
			push_error("No se pudo abrir la escena destino.")
		else:
			SceneLoader.destino = ""

	elif estado == ResourceLoader.THREAD_LOAD_FAILED \
	or estado == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
		_cargando = false
		SceneLoader.cambiando = false
		push_error("Falló la carga de la escena destino.")
	

func _shoot() -> void:

	# Si está recargando, no dispara.
	# Solo reproduce el sonido de arma vacía.
	if _is_reloading:
		return

	# Cooldown entre disparos
	if not _can_shoot:
		return

	# Si no hay balas
	if _ammo <= 0:
		_start_reload()
		return

	# -----------------------------------------
	# CONSUMIR BALA
	# -----------------------------------------
	_ammo -= 1

	if _ammo_hud:
		_ammo_hud.update_ammo(_ammo)

	ammo_changed.emit(_ammo, magazine_size)

	_can_shoot = false
	_cooldown_timer.start()


	if _ammo == 0:

		print("🔫 Última bala disparada")

		_start_reload()


func _start_reload() -> void:

	# Evitar iniciar dos recargas simultáneamente
	if _is_reloading:
		return


	_is_reloading = true
	_can_shoot = false
	_cooldown_timer.stop()
	if _ammo_hud:
		_ammo_hud.reload_ammo(reload_time)


	# Iniciar timer real de recarga
	_reload_timer.wait_time = reload_time
	_reload_timer.start()


	# Avisar que comenzó la recarga
	reload_started.emit(reload_time)


	print("⏳ Recarga iniciada. Duración: ", reload_time, " segundos")


func _on_cooldown_timeout() -> void:

	_can_shoot = not _is_reloading


func _on_reload_timeout() -> void:
	# Esperar los tweens del HUD antes de comenzar otro ciclo.
	while _ammo_hud and _ammo_hud.is_reloading:
		await get_tree().process_frame

	# =================================================
	# RECARGA TERMINADA
	# =================================================

	_ammo = magazine_size

	_is_reloading = false
	_can_shoot = true


	# Actualizar HUD por seguridad
	if _ammo_hud:
		_ammo_hud.update_ammo(_ammo)


	# Avisar que terminó
	ammo_changed.emit(_ammo, magazine_size)
