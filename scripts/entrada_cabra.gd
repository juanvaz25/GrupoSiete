extends Area2D

var jugador_cerca := false

@onready var label: Label = $LabelCabra


func _ready() -> void:
	print("ENTRADA CABRA INICIADA")

	label.hide()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _on_body_entered(body: Node2D) -> void:
	print("🔥 BODY ENTERED: ", body.name)
	print("Clase: ", body.get_class())
	print("¿Es player?: ", body.is_in_group("player"))

	if body.is_in_group("player"):
		print("🟢 JUGADOR DETECTADO")
		jugador_cerca = true
		label.show()


func _on_body_exited(body: Node2D) -> void:
	print("❌ BODY EXITED: ", body.name)

	if body.is_in_group("player"):
		jugador_cerca = false
		label.hide()


func _process(_delta: float) -> void:
	if jugador_cerca and Input.is_key_pressed(KEY_E):
		print("🟡 PRESIONASTE E")
		print("Cambiando a nivel_cabra...")

		var resultado := get_tree().change_scene_to_file(
			"res://scenes/entrada_thegoat.tscn")

		print("Resultado cambio de escena: ", resultado)
