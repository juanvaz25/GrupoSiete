extends Camera2D

## Distancia maxima del desplazamiento adicional, en unidades del mundo.
@export_range(0.0, 1000.0, 1.0) var max_cursor_offset: float = 200.0

## Distancia minima necesiaroa para obtener desplazamiento adicional, en unidades del mundo.


## Fraccion de la distancia al cursor que sigue la camara.
@export_range(0.0, 1.0, 0.01) var cursor_influence: float = 0.35
## Rapidez de la transicion: un valor mayor responde mas rapido.
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 6.0

var _base_offset: Vector2
var _cursor_offset := Vector2.ZERO
var _min_cursor_offset := Vector2(200,100)

func _ready() -> void:
	_base_offset = offset


func _process(delta: float) -> void:
	var viewport := get_viewport()
	var viewport_rect := viewport.get_visible_rect()
	var mouse_position := viewport.get_mouse_position()
	var target_offset := Vector2.ZERO
	if viewport_rect.has_point(mouse_position) and get_window().has_focus():
		# Medir desde el centro de pantalla evita realimentar el movimiento
		# de la camara al calcular la posicion del cursor en el mundo.
		var mouse_from_center := (mouse_position - viewport_rect.get_center()) / zoom
		print("Posicion: "+str(mouse_from_center))
		if Vector2(mouse_from_center.x, mouse_from_center.y + 100).distance_to(Vector2.ZERO) > _min_cursor_offset.distance_to(Vector2.ZERO):
			target_offset = (mouse_from_center * cursor_influence).limit_length(max_cursor_offset)

	_cursor_offset = _cursor_offset.lerp(target_offset, 1.0 - exp(-follow_speed * delta))
	offset = _base_offset + _cursor_offset
