extends Node2D


var burn_manager: Node2D
var fire_radius: float = 40.0
var fire_spacing: float = 24.0
var _fire_distance_left: float = 0.0

func can_burn() -> bool:
	return (
		is_instance_valid(burn_manager)
		and burn_manager.has_method("burn_at")
	)
	
func start_fire_trail(fire_spacing) -> void:
	_fire_distance_left = maxf(fire_spacing, 1.0)
	if can_burn():
		burn_manager.burn_at(global_position, fire_radius)

func burn_movement(from: Vector2, to: Vector2, fire_radius) -> void:
	if not can_burn():
		return

	var distance := from.distance_to(to)

	if distance <= 0.001:
		return

	var direction := from.direction_to(to)
	var spacing := maxf(fire_spacing, 1.0)
	var travelled := 0.0

	# Completa puntos intermedios si recorrió mucha distancia
	# durante una sola actualización.
	while distance - travelled >= _fire_distance_left:
		travelled += _fire_distance_left

		var point := from + direction * travelled
		burn_manager.burn_at(point, fire_radius)

		_fire_distance_left = spacing

	_fire_distance_left -= distance - travelled
