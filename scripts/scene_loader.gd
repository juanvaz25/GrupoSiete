extends Node

var destino: String = ""
var cambiando: bool = false

func cambiar_escena_deferred(ruta: String) -> void:
	cambiar_escena(ruta)

func cambiar_escena(ruta: String) -> void:
	if cambiando:
		return

	destino = ruta
	cambiando = true

	# Esperar a que termine el callback de fisica antes de retirar la escena.
	call_deferred("_abrir_loading")


func _abrir_loading() -> void:
	var error := get_tree().change_scene_to_file(
		"res://scenes/Loading.tscn"
	)

	if error != OK:
		cambiando = false
		push_error("No se pudo abrir Loading.")
