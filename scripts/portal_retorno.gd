## Portal de retorno a la Biblioteca tras derrotar a un jefe.
extends Area2D

@export var target_scene: String = "res://scenes/nivel_inicial.tscn"
@export var auto_teleport_on_touch: bool = true

var _player_inside: bool = false
var _teleporting: bool = false

@onready var label: Label = get_node_or_null("Label")
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	if label:
		label.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)

	# Sonido de aparición del portal
	if audio_player and audio_player.stream:
		audio_player.play()

	# Animación de aparición con escala suave
	scale = Vector2.ZERO
	var tween := create_tween()
	if tween:
		tween.tween_property(self, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# Rotación sutil o pulso visual
	if sprite:
		sprite.rotation += delta * 1.5

	if _player_inside and Input.is_key_pressed(KEY_E):
		_teleport_player()


func _on_body_entered(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = true
		if label:
			label.visible = true
		
		if auto_teleport_on_touch:
			_teleport_player()


func _on_body_exited(body: Node2D) -> void:
	if _is_player(body):
		_player_inside = false
		if label:
			label.visible = false


func _on_area_entered(area: Area2D) -> void:
	if _is_player(area):
		_player_inside = true
		if label:
			label.visible = true
		
		if auto_teleport_on_touch:
			_teleport_player()


func _on_area_exited(area: Area2D) -> void:
	if _is_player(area):
		_player_inside = false
		if label:
			label.visible = false


func _teleport_player() -> void:
	if _teleporting:
		return
	_teleporting = true
	print("🌀 Jugador entrando al portal -> Regresando a la Biblioteca...")
	SceneLoader.cambiar_escena(target_scene)


func _is_player(node: Node) -> bool:
	if node == null:
		return false
	if node.is_in_group("player") or node.name == "Player":
		return true
	if node.get_parent() and (node.get_parent().is_in_group("player") or node.get_parent().name == "Player"):
		return true
	return false
