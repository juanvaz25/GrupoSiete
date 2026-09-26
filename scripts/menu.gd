extends Control

## Control del Menú Principal
## - JUGAR: Lleva a la biblioteca (res://scenes/hisotria_inicial.tscn)
## - CONFIGURACIÓN: Permite editar el volumen de Música y SFX
## - SALIR: Cierra el juego

@export_file("*.tscn") var biblioteca_scene: String = "res://scenes/hisotria_inicial.tscn"

# Botones principales
@onready var button_jugar: Button = $VBoxContainer/ButtonJugar
@onready var button_configuracion: Button = $VBoxContainer/ButtonConfiguracion
@onready var button_salir: Button = $VBoxContainer/ButtonSalir

# Panel de configuración
@onready var panel_configuracion: Control = $PanelConfiguracion
@onready var fondo_oscuro: ColorRect = $PanelConfiguracion/FondoOscuro
@onready var slider_musica: HSlider = $PanelConfiguracion/VentanaConfig/MarginContainer/VBoxContainer/SeccionMusica/SliderMusica
@onready var label_musica_valor: Label = $PanelConfiguracion/VentanaConfig/MarginContainer/VBoxContainer/SeccionMusica/HBoxContainer/LabelMusicaValor
@onready var slider_sfx: HSlider = $PanelConfiguracion/VentanaConfig/MarginContainer/VBoxContainer/SeccionSFX/SliderSFX
@onready var label_sfx_valor: Label = $PanelConfiguracion/VentanaConfig/MarginContainer/VBoxContainer/SeccionSFX/HBoxContainer/LabelSFXValor
@onready var button_cerrar_config: Button = $PanelConfiguracion/VentanaConfig/MarginContainer/VBoxContainer/ButtonCerrarConfig

# Audio
@onready var musica_menu: AudioStreamPlayer = get_node_or_null("MusicaMenu")
@onready var audio_sfx_test: AudioStreamPlayer = get_node_or_null("AudioSFXTest")


func _ready() -> void:
	# Asegurar puntero estándar del sistema en el menú
	Input.set_custom_mouse_cursor(null)

	# Conexión de botones principales
	button_jugar.pressed.connect(_on_jugar_pressed)
	button_configuracion.pressed.connect(_on_configuracion_pressed)
	button_salir.pressed.connect(_on_salir_pressed)

	# Conexión de panel de configuración
	button_cerrar_config.pressed.connect(_on_cerrar_config_pressed)
	slider_musica.value_changed.connect(_on_musica_value_changed)
	slider_sfx.value_changed.connect(_on_sfx_value_changed)
	slider_sfx.drag_ended.connect(_on_sfx_drag_ended)
	fondo_oscuro.gui_input.connect(_on_fondo_oscuro_gui_input)

	# Inicializar valores de volumen actuales
	_actualizar_sliders_desde_audio_manager()

	# Asegurar que el panel de configuración inicie oculto
	panel_configuracion.visible = false

	# Focus inicial en Jugar
	button_jugar.grab_focus()


func _actualizar_sliders_desde_audio_manager() -> void:
	var vol_musica: float = 1.0
	var vol_sfx: float = 1.0

	if get_node_or_null("/root/AudioManager"):
		var am = get_node("/root/AudioManager")
		vol_musica = am.get_music_volume()
		vol_sfx = am.get_sfx_volume()
	else:
		var idx_m = AudioServer.get_bus_index(&"Musica")
		if idx_m != -1 and not AudioServer.is_bus_mute(idx_m):
			vol_musica = db_to_linear(AudioServer.get_bus_volume_db(idx_m))
		var idx_s = AudioServer.get_bus_index(&"SFX")
		if idx_s != -1 and not AudioServer.is_bus_mute(idx_s):
			vol_sfx = db_to_linear(AudioServer.get_bus_volume_db(idx_s))

	slider_musica.value = vol_musica
	label_musica_valor.text = str(roundi(vol_musica * 100.0)) + "%"

	slider_sfx.value = vol_sfx
	label_sfx_valor.text = str(roundi(vol_sfx * 100.0)) + "%"


# --- ACCIONES DE BOTONES PRINCIPALES ---

func _on_jugar_pressed() -> void:
	print("🎮 Iniciando juego -> Yendo a la biblioteca: ", biblioteca_scene)
	get_tree().change_scene_to_file(biblioteca_scene)


func _on_configuracion_pressed() -> void:
	_actualizar_sliders_desde_audio_manager()
	panel_configuracion.visible = true
	slider_musica.grab_focus()


func _on_salir_pressed() -> void:
	print("🚪 Saliendo del juego...")
	get_tree().quit()


# --- PANEL DE CONFIGURACIÓN ---

func _on_cerrar_config_pressed() -> void:
	_guardar_configuracion()
	panel_configuracion.visible = false
	button_configuracion.grab_focus()


func _on_fondo_oscuro_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_cerrar_config_pressed()


func _on_musica_value_changed(value: float) -> void:
	label_musica_valor.text = str(roundi(value * 100.0)) + "%"
	if get_node_or_null("/root/AudioManager"):
		get_node("/root/AudioManager").set_music_volume(value)
	else:
		_set_bus_linear(&"Musica", value)


func _on_sfx_value_changed(value: float) -> void:
	label_sfx_valor.text = str(roundi(value * 100.0)) + "%"
	if get_node_or_null("/root/AudioManager"):
		get_node("/root/AudioManager").set_sfx_volume(value)
	else:
		_set_bus_linear(&"SFX", value)


func _on_sfx_drag_ended(value_changed: bool) -> void:
	if value_changed and audio_sfx_test:
		audio_sfx_test.play()


func _guardar_configuracion() -> void:
	if get_node_or_null("/root/AudioManager"):
		get_node("/root/AudioManager").save_audio_settings()


func _set_bus_linear(bus_name: StringName, linear_val: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))


func _unhandled_input(event: InputEvent) -> void:
	if panel_configuracion and panel_configuracion.visible:
		if event.is_action_pressed("ui_cancel"):
			_on_cerrar_config_pressed()
			get_viewport().set_input_as_handled()
