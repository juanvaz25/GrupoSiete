extends TileMapLayer


var dialogo_scene = preload("res://scenes/dialogo.tscn")
var dialogo


func _ready() -> void:

	# Cargar las caras de Bairoleto
	var bairoleto_cara1 = preload(
		"res://assets/AssetsBairoleto/cara1.png"
	)

	var bairoleto_cara2 = preload(
		"res://assets/AssetsBairoleto/cara2.png"
	)

	var bairoleto_cara3 = preload(
		"res://assets/AssetsBairoleto/cara3.png"
	)


	# Crear el sistema de diálogo
	dialogo = dialogo_scene.instantiate()
	add_child(dialogo)


	# Iniciar conversación
	dialogo.iniciar_conversacion([
		
		{
			"nombre": "Bairoleto",
			"texto": "¿Qué...? ¿Dónde estoy?",
			"retrato": bairoleto_cara1
		},

		{
			"nombre": "Bairoleto",
			"texto": "Soy Bairoleto... ¿qué está pasando...?",
			"retrato": bairoleto_cara2
		},

		{
			"nombre": "Bairoleto",
			"texto": "¿Qué es ese libro en el centro de la biblioteca?",
			"retrato": bairoleto_cara3
		}
	])

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass
