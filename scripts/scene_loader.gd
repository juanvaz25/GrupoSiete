extends Node

var destino: String = ""
var cambiando: bool = false

func cambiar_escena(ruta: String) -> void:
	if cambiando:
		return

	destino = ruta
	cambiando = true

	var error := get_tree().change_scene_to_file(
		"res://scenes/Loading.tscn"
	)

	if error != OK:
		cambiando = false
		push_error("No se pudo abrir Loading.")
