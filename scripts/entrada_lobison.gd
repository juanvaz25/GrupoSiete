extends Area2D

var jugador_cerca := false

@onready var label = $LabelLobito


func _ready() -> void:
	label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	if body.name == "Player":
		jugador_cerca = true
		label.show()


func _on_body_exited(body: Node2D) -> void:
	if body.name == "Player":
		jugador_cerca = false
		label.hide()


func _process(_delta: float) -> void:
	if jugador_cerca and Input.is_key_pressed(KEY_E):
		get_tree().change_scene_to_file("res://scenes/nivel_lobison.tscn")
