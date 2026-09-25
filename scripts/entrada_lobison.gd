## Trigger de entrada a la sala del Lobisón desde la Biblioteca.
extends Area2D

var jugador_cerca := false

@onready var label: Label = $LabelLobito


func _ready() -> void:
	if label:
		label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		jugador_cerca = true
		if label:
			label.show()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		jugador_cerca = false
		if label:
			label.hide()


func _on_area_entered(area: Area2D) -> void:
	if _is_player(area):
		jugador_cerca = true
		if label:
			label.show()


func _on_area_exited(area: Area2D) -> void:
	if _is_player(area):
		jugador_cerca = false
		if label:
			label.hide()


func _process(_delta: float) -> void:
	if jugador_cerca and Input.is_key_pressed(KEY_E):
		print("🐺 Entrando a la sala del Lobisón...")
		get_tree().change_scene_to_file("res://scenes/nivel_lobison.tscn")


func _is_player(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("player") or node.name == "Player":
		return true
	if node.get_parent() and (node.get_parent().is_in_group("player") or node.get_parent().name == "Player"):
		return true
	return false
