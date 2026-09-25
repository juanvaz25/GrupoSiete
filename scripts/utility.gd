
class_name Utility

static func get_direction(action: String, direction: Vector2) -> String:
	var angle := direction.angle()

	# DERECHA
	
	if angle >= -PI / 8 and angle < PI / 8:
		return action+"_right"

	# ABAJO-DERECHA
	elif angle >= PI / 8 and angle < 3 * PI / 8:
		return action+"_down_right"

	# ABAJO
	elif angle >= 3 * PI / 8 and angle < 5 * PI / 8:
		return action+"_down"

	# ABAJO-IZQUIERDA
	elif angle >= 5 * PI / 8 and angle < 7 * PI / 8:
		return action+"_down_left"

	# IZQUIERDA
	elif angle >= 7 * PI / 8 or angle < -7 * PI / 8:
		return action+"_left"

	# ARRIBA-IZQUIERDA
	elif angle >= -7 * PI / 8 and angle < -5 * PI / 8:
		return action+"_up_left"

	# ARRIBA
	elif angle >= -5 * PI / 8 and angle < -3 * PI / 8:
		return action+"_up"

	# ARRIBA-DERECHA
	else:
		return action+"_up_right"
