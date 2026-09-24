## Portal de retorno a la Biblioteca tras derrotar a un jefe.
extends Area2D

@export var target_scene: String = "res://scenes/nivel_inicial.tscn"
@export var auto_teleport_on_touch: bool = true

var _player_inside: bool = false

@onready var label: Label = $Label
@onready var particles: CPUParticles2D = get_node_or_null("CPUParticles2D")
@onready var audio_player: AudioStreamPlayer2D = get_node_or_null("AudioStreamPlayer2D")
@onready var sprite: Sprite2D = get_node_or_null("Sprite2D")


func _ready() -> void:
	if label:
		label.visible = false

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# Sonido de aparición del portal
	if audio_player and audio_player.stream:
		audio_player.play()

	# Animación de aparición con escala suave
	scale = Vector2.ZERO
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _process(delta: float) -> void:
	# Rotación sutil o pulso visual
	if sprite:
		sprite.rotation += delta * 1.5

	if _player_inside and Input.is_key_pressed(KEY_E):
		_teleport_player()


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_inside = true
		if label:
			label.visible = true
		
		if auto_teleport_on_touch:
			_teleport_player()


func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player") or body.name == "Player":
		_player_inside = false
		if label:
			label.visible = false


func _teleport_player() -> void:
	print("🌀 Jugador entrando al portal -> Regresando a la Biblioteca...")
	get_tree().change_scene_to_file(target_scene)
