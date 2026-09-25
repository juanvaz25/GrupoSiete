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


func reload_ammo() -> void:
	if is_reloading:
		return

	is_reloading = true

	print("🔄 RECARGANDO...")

	# Pequeña pausa antes de comenzar
	await get_tree().create_timer(0.15).timeout

	for nueva_municion in range(1, 7):
		update_ammo(nueva_municion)

		# Pequeño movimiento para simular el giro
		await animate_cylinder_step()

	is_reloading = false

	print("🔫 RECARGA COMPLETA")

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
			
func animate_cylinder_step() -> void:
	var tween := create_tween()

	var posicion_original := revolver_cylinder.position

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original + Vector2(-3, 0),
		0.05
	)

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original + Vector2(3, 0),
		0.05
	)

	tween.tween_property(
		revolver_cylinder,
		"position",
		posicion_original,
		0.05
	)

	await tween.finished
