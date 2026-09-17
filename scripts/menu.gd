extends Control

@onready var button_jugar: Button = $VBoxContainer/ButtonJugar

func _ready() -> void:
	button_jugar.pressed.connect(_jugar)

func _jugar() -> void:
	get_tree().change_scene_to_file("res://scenes/hisotria_inicial.tscn")
