extends Camera2D

## Si está activado, la cámara se desplaza hacia el cursor del mouse.
@export var follow_mouse: bool = true

## Distancia máxima (en unidades de mundo) que la cámara puede alejarse del personaje.
## El personaje es el ancla y límite del movimiento.
@export_range(0.0, 1000.0, 5.0) var max_cursor_offset: float = 250.0

## Fracción de la distancia al cursor que influye en el movimiento de la cámara.
## Un valor de 0.3 a 0.4 suele dar una sensación agradable y natural.
@export_range(0.0, 1.0, 0.01) var cursor_influence: float = 0.35

## Margen mínimo de seguridad (en píxeles de pantalla) respecto al borde.
## Garantiza que el personaje NUNCA quede fuera de la pantalla.
@export_range(20.0, 400.0, 5.0) var screen_margin: float = 120.0

## Zona muerta alrededor del centro (en píxeles de pantalla) donde pequeños
## movimientos del mouse no mueven la cámara, evitando temblores indeseados.
@export_range(0.0, 100.0, 1.0) var deadzone_radius: float = 20.0

## Rapidez de la transición hacia el cursor (suavizado del mouse).
@export_range(0.1, 30.0, 0.1) var follow_speed: float = 8.0

## Suavizado de seguimiento de posición del personaje (Godot built-in).
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
	# Si no se debe seguir al mouse o no hay influencia, regresar suavemente al centro
	if not follow_mouse or cursor_influence <= 0.0:
		if _cursor_offset != Vector2.ZERO:
			_cursor_offset = _cursor_offset.lerp(Vector2.ZERO, 1.0 - exp(-follow_speed * delta))
			if _cursor_offset.length_squared() < 0.01:
				_cursor_offset = Vector2.ZERO
			offset = _base_offset + _cursor_offset
		return

	var viewport := get_viewport()
	if not viewport:
		return

	var viewport_rect := viewport.get_visible_rect()
	var viewport_size := viewport_rect.size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		return

	# Si la ventana perdió el foco (ej. alt-tab), regresar suavemente la vista al personaje
	if not get_window().has_focus():
		_cursor_offset = _cursor_offset.lerp(Vector2.ZERO, 1.0 - exp(-follow_speed * delta))
		offset = _base_offset + _cursor_offset
		return

	# Limitar la posición del mouse dentro de los bordes del viewport para evitar saltos bruscos
	var raw_mouse_pos := viewport.get_mouse_position()
	var clamped_mouse := Vector2(
		clampf(raw_mouse_pos.x, 0.0, viewport_size.x),
		clampf(raw_mouse_pos.y, 0.0, viewport_size.y)
	)

	var screen_center := viewport_size * 0.5
	var mouse_from_center := clamped_mouse - screen_center
	var mouse_dist_screen := mouse_from_center.length()

	var target_offset := Vector2.ZERO
	var current_zoom := Vector2(maxf(absf(zoom.x), 0.001), maxf(absf(zoom.y), 0.001))

	if mouse_dist_screen > deadzone_radius:
		var dir := mouse_from_center / mouse_dist_screen
		var effective_dist_screen := mouse_dist_screen - deadzone_radius
		# Convertir distancia de pantalla a distancia de mundo dividiendo por el zoom
		var effective_dist_world := effective_dist_screen / current_zoom.x
		target_offset = dir * (effective_dist_world * cursor_influence)

	# --- CÁLCULO DE LÍMITES PARA QUE EL PERSONAJE NUNCA SALGA DE PANTALLA ---
	# En coordenadas de pantalla, la mitad del viewport menos el margen de seguridad
	var max_screen_offset_x := maxf(0.0, screen_center.x - screen_margin)
	var max_screen_offset_y := maxf(0.0, screen_center.y - screen_margin)

	# Convertir a unidades de mundo según el zoom
	var limit_world_x := max_screen_offset_x / current_zoom.x
	var limit_world_y := max_screen_offset_y / current_zoom.y

	# El límite radial es el menor entre el offset máximo deseado y el margen seguro de pantalla
	var max_safe_radius := minf(limit_world_x, limit_world_y)
	var allowed_distance := minf(max_cursor_offset, max_safe_radius)

	# Aplicar el límite radial
	target_offset = target_offset.limit_length(allowed_distance)

	# Clampear por cada eje para asegurar que en ninguna proporción de pantalla el personaje quede fuera
	target_offset.x = clampf(target_offset.x, -limit_world_x, limit_world_x)
	target_offset.y = clampf(target_offset.y, -limit_world_y, limit_world_y)

	# Suavizar la transición hacia el offset deseado
	_cursor_offset = _cursor_offset.lerp(target_offset, 1.0 - exp(-follow_speed * delta))
	offset = _base_offset + _cursor_offset
