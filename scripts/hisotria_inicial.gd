extends Control

@onready var viñetas: AnimatedSprite2D = $Container/AnimatedSprite2D
@onready var boton: Button = $Container/BotonSiguiente

var frame_actual: int = 0


func _ready() -> void:
	viñetas.stop()
	viñetas.frame = frame_actual

	boton.pressed.connect(_siguiente)


func _siguiente() -> void:
	# Si todavía hay viñetas para mostrar
	if frame_actual < 2:
		frame_actual += 1
		viñetas.frame = frame_actual

	# Si llegamos a la última, cambiamos de escena
	else:
		get_tree().change_scene_to_file("res://scenes/nivel_inicial.tscn")
