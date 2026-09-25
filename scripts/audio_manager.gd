extends Node

## Gestor global de audio y configuración de volumen.
## Maneja los buses "Musica" y "SFX", guardando las preferencias del usuario.

const SETTINGS_FILE: String = "user://audio_settings.cfg"
const BUS_MUSICA: StringName = &"Musica"
const BUS_SFX: StringName = &"SFX"

func _ready() -> void:
	# Asegurar que existan los buses
	_ensure_bus(BUS_MUSICA)
	_ensure_bus(BUS_SFX)
	# Cargar configuración guardada
	load_audio_settings()

func _ensure_bus(bus_name: StringName) -> int:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, bus_name)
		AudioServer.set_bus_send(idx, &"Master")
	return idx

func set_bus_volume(bus_name: StringName, linear_val: float) -> void:
	var idx := _ensure_bus(bus_name)
	linear_val = clampf(linear_val, 0.0, 1.0)
	if linear_val <= 0.001:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear_val))

func get_bus_volume(bus_name: StringName) -> float:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return 1.0
	if AudioServer.is_bus_mute(idx):
		return 0.0
	return clampf(db_to_linear(AudioServer.get_bus_volume_db(idx)), 0.0, 1.0)

func set_music_volume(linear_val: float) -> void:
	set_bus_volume(BUS_MUSICA, linear_val)

func get_music_volume() -> float:
	return get_bus_volume(BUS_MUSICA)

func set_sfx_volume(linear_val: float) -> void:
	set_bus_volume(BUS_SFX, linear_val)

func get_sfx_volume() -> float:
	return get_bus_volume(BUS_SFX)

func save_audio_settings() -> void:
	var config := ConfigFile.new()
	config.set_value("audio", "musica_volume", get_music_volume())
	config.set_value("audio", "sfx_volume", get_sfx_volume())
	config.save(SETTINGS_FILE)

func load_audio_settings() -> void:
	var config := ConfigFile.new()
	var err := config.load(SETTINGS_FILE)
	if err == OK:
		var mus: float = config.get_value("audio", "musica_volume", 1.0)
		var sfx: float = config.get_value("audio", "sfx_volume", 1.0)
		set_music_volume(mus)
		set_sfx_volume(sfx)
	else:
		set_music_volume(1.0)
		set_sfx_volume(1.0)
