extends Control

@onready var video: VideoStreamPlayer = $VideoStreamPlayer2
@onready var boton: Button = $BotonSiguiente2


func _ready() -> void:
	
	# Reproducimos el video al entrar en la escena
	video.play()

	# Conectamos el botón
	boton.pressed.connect(_siguiente)

	# Cuando termina el video, pasamos automáticamente a la siguiente escena
	video.finished.connect(_video_terminado)
	

func _on_video_finished() -> void:
	get_tree().change_scene_to_file("res://scenes/nivel_cabra.tscn")
	


func _siguiente() -> void:
	# Si el jugador presiona el botón, salta la cinemática
	video.stop()
	get_tree().change_scene_to_file("res://scenes/nivel_cabra.tscn")


func _video_terminado() -> void:
	# Cuando termina el video automáticamente
	get_tree().change_scene_to_file("res://scenes/nivel_cabra.tscn")
