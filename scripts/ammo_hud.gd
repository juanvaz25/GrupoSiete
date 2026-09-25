extends CanvasLayer

@onready var revolver_cylinder: TextureRect = $Cylinder/RevolverCylinder

@export var tambor_1: Texture2D
@export var tambor_2: Texture2D
@export var tambor_3: Texture2D
@export var tambor_4: Texture2D
@export var tambor_5: Texture2D
@export var tambor_6: Texture2D
@export var tambor_7: Texture2D

var ammo: int = 6


func _ready() -> void:
	print("🔫 AmmoHUD iniciado")

	# Mostrar el tambor lleno al comenzar
	update_ammo(6)

func reload_ammo() -> void:
	if ammo > 0:
		return

	print("🔄 Recargando tambor...")

	await get_tree().create_timer(0.2).timeout

	for nueva_municion in range(1, 7):
		update_ammo(nueva_municion)
		await get_tree().create_timer(0.12).timeout

	print("🔫 Tambor recargado")

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
