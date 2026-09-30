extends CanvasLayer

@onready var revolver_cylinder: TextureRect = $Cylinder/RevolverCylinder

@export var tambor_1: Texture2D
@export var tambor_2: Texture2D
@export var tambor_3: Texture2D
@export var tambor_4: Texture2D
@export var tambor_5: Texture2D
@export var tambor_6: Texture2D
@export var tambor_7: Texture2D


var is_reloading: bool = false
var ammo: int = 6


func _ready() -> void:
	print("🔫 AmmoHUD iniciado")

	# Mostrar el tambor lleno al comenzar
	update_ammo(6)


func reload_ammo(duracion: float = 1.5) -> void:
	if is_reloading:
		return

	is_reloading = true

	print("🔄 RECARGANDO...")

	# Mostrar el tambor completamente vacío
	update_ammo(0)

	# Esperar un poquito para que se vea tambor_7
	await get_tree().create_timer(0.20).timeout

	# El tiempo restante se reparte entre las 6 balas
	var tiempo_restante := duracion - 0.20
	var tiempo_por_bala := tiempo_restante / 6.0

	for nueva_municion in range(1, 7):
		update_ammo(nueva_municion)

		await animate_cylinder_step(tiempo_por_bala)

	is_reloading = false

	print("🔫 RECARGA VISUAL COMPLETA")
	
func update_ammo(cantidad: int) -> void:
	ammo = clamp(cantidad, 0, 6)

	match ammo:
		6:
			revolver_cylinder.texture = tambor_1
		5:
			revolver_cylinder.texture = tambor_2
		4:
			revolver_cylinder.texture = tambor_3
		3:
			revolver_cylinder.texture = tambor_4
		2:
			revolver_cylinder.texture = tambor_5
		1:
			revolver_cylinder.texture = tambor_6
		0:
			revolver_cylinder.texture = tambor_7
			
func animate_cylinder_step(duracion: float) -> void:
	var tween := create_tween()

	var posicion_original := revolver_cylinder.position

	var tiempo_movimiento := duracion / 3.0

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original + Vector2(-3, 0),
		tiempo_movimiento
	)

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original + Vector2(3, 0),
		tiempo_movimiento
	)

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original,
		tiempo_movimiento
	)

	await tween.finished
