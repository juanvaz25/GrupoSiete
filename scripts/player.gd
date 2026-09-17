extends CharacterBody2D

const SPEED := 300.0


func _physics_process(_delta: float) -> void:
	var direction := 0.0
	var directiony := 0.0

	# A - Izquierda
	if Input.is_key_pressed(KEY_A):
		direction -= 1.0

	# D - Derecha
	if Input.is_key_pressed(KEY_D):
		direction += 1.0

	# W - Arriba
	if Input.is_key_pressed(KEY_W):
		directiony -= 1.0

	# S - Abajo
	if Input.is_key_pressed(KEY_S):
		directiony += 1.0

	# Movimiento vertical
	if directiony != 0:
		velocity.y = directiony * SPEED
	else:
		velocity.y = move_toward(velocity.y, 0, SPEED)

	# Movimiento horizontal
	if direction != 0:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()
