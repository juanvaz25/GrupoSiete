extends Camera2D

## Si está activado, la cámara se desplaza hacia el cursor del mouse.
## Se deja en false por defecto para que la cámara siga estrictamente al personaje.
@export var follow_mouse: bool = false

## Distancia máxima del desplazamiento adicional si follow_mouse está activo.
@export_range(0.0, 1000.0, 1.0) var max_cursor_offset: float = 200.0

## Fracción de la distancia al cursor que sigue la cámara si follow_mouse está activo.
@export_range(0.0, 1.0, 0.01) var cursor_influence: float = 0.0

## Rapidez de la transición hacia el cursor si follow_mouse está activo.
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 6.0

## Suavizado de seguimiento de posición del personaje.
@export var smooth_follow: bool = true
@export var smooth_speed: float = 8.0

var _base_offset: Vector2 = Vector2.ZERO
var _cursor_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	_base_offset = offset
	if smooth_follow:
		position_smoothing_enabled = true
		position_smoothing_speed = smooth_speed


func _process(delta: float) -> void:
	# Si no se debe seguir al mouse, la cámara queda fija en el personaje
	if not follow_mouse or cursor_influence <= 0.0:
		if offset != _base_offset:
			offset = _base_offset
		return

	var viewport := get_viewport()
	var viewport_rect := viewport.get_visible_rect()
	var mouse_position := viewport.get_mouse_position()
	var target_offset := Vector2.ZERO
	if viewport_rect.has_point(mouse_position) and get_window().has_focus():
		var mouse_from_center := (mouse_position - viewport_rect.get_center()) / zoom
		target_offset = (mouse_from_center * cursor_influence).limit_length(max_cursor_offset)

	_cursor_offset = _cursor_offset.lerp(target_offset, 1.0 - exp(-follow_speed * delta))
	offset = _base_offset + _cursor_offset
