## Player character controller.
##
## Handles movement input (WASD) and exposes state for child ability nodes.
## Abilities (Dash, Shoot) are attached as child nodes and read
## `input_direction` and `last_direction` to function.
extends CharacterBody2D

# --- Configuración ---
## Velocidad base de movimiento (px/s).
const SPEED := 500.0

# --- Estado público (leído por habilidades) ---
## Dirección de input actual (normalizada). Vector2.ZERO si no hay input.
var input_direction: Vector2 = Vector2.ZERO
## Última dirección de movimiento válida. Útil para el dash sin input activo.
var last_direction: Vector2 = Vector2.RIGHT



func _physics_process(_delta: float) -> void:
	# Leer input usando el Input Map
	input_direction = Input.get_vector("move_left", "move_right", "move_up", "move_down")

	# Registrar última dirección válida para habilidades que la necesiten
	if input_direction != Vector2.ZERO:
		last_direction = input_direction.normalized()

	# Si alguna habilidad (ej: dash) controla la velocidad, no sobreescribir
	var dash_ability := get_node_or_null("DashAbility")
	if dash_ability and dash_ability.is_dashing:
		move_and_slide()
		return

	# Movimiento normal
	if input_direction != Vector2.ZERO:
		velocity = input_direction * SPEED
	else:
		velocity = velocity.move_toward(Vector2.ZERO, SPEED)

	move_and_slide()
