extends CanvasLayer

@onready var panel: Panel = $Panel
@onready var portrait: TextureRect = $Panel/Portrait
@onready var nombre: Label = $Panel/Nombre
@onready var texto: Label = $Panel/Texto
@onready var continuar: Label = $Panel/Continuar

var conversaciones: Array = []
var dialogo_actual: int = 0

var escribiendo: bool = false
var texto_completo: String = ""

@export var velocidad_texto: float = 0.03


func _ready() -> void:
	visible = false
	continuar.visible = false


# ============================================================
# INICIAR UNA CONVERSACIÓN
# ============================================================

func iniciar_conversacion(lista_dialogos: Array) -> void:
	conversaciones = lista_dialogos
	dialogo_actual = 0

	if conversaciones.is_empty():
		return

	visible = true
	_mostrar_dialogo_actual()


# ============================================================
# MOSTRAR EL DIÁLOGO ACTUAL
# ============================================================

func _mostrar_dialogo_actual() -> void:

	var dialogo = conversaciones[dialogo_actual]

	nombre.text = dialogo["nombre"]
	portrait.texture = dialogo["retrato"]

	texto_completo = dialogo["texto"]
	texto.text = ""

	continuar.visible = false
	escribiendo = true

	for letra in texto_completo:
		if not escribiendo:
			break

		texto.text += letra
		await get_tree().create_timer(velocidad_texto).timeout

	escribiendo = false
	continuar.visible = true


# ============================================================
# INPUT
# ============================================================

func _unhandled_input(event: InputEvent) -> void:

	if not visible:
		return

	if event.is_action_pressed("ui_accept"):

		# Si todavía se está escribiendo,
		# mostramos todo inmediatamente.
		if escribiendo:

			escribiendo = false
			texto.text = texto_completo
			continuar.visible = true

			return

		# Si terminó de escribir,
		# pasamos al siguiente diálogo.
		dialogo_actual += 1

		if dialogo_actual < conversaciones.size():

			_mostrar_dialogo_actual()

		else:

			# Terminó toda la conversación
			visible = false
