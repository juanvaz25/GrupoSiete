## HUD de salud del personaje.
##
## Muestra 3 corazones (soportando medios corazones para daño/cura de 0.5 y 1.0).
## Solo es visible mientras el personaje está en una sala de jefe.
extends CanvasLayer

@export var always_show: bool = false

@onready var _player: CharacterBody2D = get_parent()
var _container: Control

# 3 corazones
var _current_health: float = 3.0
var _max_health: float = 3.0


func _ready() -> void:
	_setup_ui()
	
	if _player and _player.has_signal("health_changed"):
		_player.health_changed.connect(_on_health_changed)
		_current_health = _player.current_health
		_max_health = _player.max_health
	
	_update_visibility()
	_update_display()


## Determina si la escena actual corresponde a una sala de jefe.
func _is_boss_room() -> bool:
	if always_show:
		return true
	var current_scene := get_tree().current_scene
	if current_scene == null:
		return false
	
	if current_scene.is_in_group("boss_room"):
		return true
	
	var file_path := current_scene.scene_file_path.to_lower()
	return "nivel_cabra" in file_path or "nivel_lobison" in file_path or "nivel_basilisco" in file_path


func _update_visibility() -> void:
	visible = _is_boss_room()


func _on_health_changed(new_health: float, max_h: float) -> void:
	_current_health = new_health
	_max_health = max_h
	_update_display()


func _setup_ui() -> void:
	_container = Control.new()
	_container.name = "HeartsContainer"
	_container.position = Vector2(30, 30)
	_container.custom_minimum_size = Vector2(160, 50)
	add_child(_container)


func _update_display() -> void:
	if _container == null:
		return
	
	# Limpiar hijos previos
	for child in _container.get_children():
		child.queue_free()

	var total_hearts := int(ceil(_max_health))
	var heart_size := 36.0
	var spacing := 10.0

	for i in range(total_hearts):
		var heart_val := _current_health - float(i)
		var heart_state: float = clampf(heart_val, 0.0, 1.0) # 1.0 = lleno, 0.5 = medio, 0.0 = vacio
		
		var heart_view := HeartView.new(heart_state, heart_size)
		heart_view.position = Vector2(i * (heart_size + spacing), 0)
		_container.add_child(heart_view)


## Nodo interno para dibujar un corazón vectorial dinámico (lleno, medio, vacío)
class HeartView extends Control:
	var state: float # 0.0, 0.5, 1.0
	var h_size: float

	func _init(p_state: float, p_size: float) -> void:
		state = p_state
		h_size = p_size
		custom_minimum_size = Vector2(p_size, p_size)

	func _draw() -> void:
		var center := Vector2(h_size * 0.5, h_size * 0.4)
		var scale_factor := h_size / 32.0

		# Color del corazón
		var heart_color := Color(0.92, 0.2, 0.25, 1.0) # Rojo intenso
		var bg_color := Color(0.18, 0.18, 0.22, 0.7) # Fondo gris oscuro / vacío
		var border_color := Color(0.08, 0.08, 0.1, 0.9) # Borde

		# Dibujar corazón base (fondo/vacío)
		_draw_heart_shape(Vector2.ZERO, scale_factor, bg_color, border_color)

		# Si tiene vida (1.0 o 0.5), dibujar relleno
		if state >= 0.99:
			_draw_heart_shape(Vector2.ZERO, scale_factor, heart_color, border_color)
		elif state >= 0.49:
			# Medio corazón: dibujar mitad izquierda
			_draw_half_heart(Vector2.ZERO, scale_factor, heart_color, border_color)


	func _draw_heart_shape(offset: Vector2, s: float, fill: Color, border: Color) -> void:
		var pts := _get_heart_polygon(offset, s)
		draw_colored_polygon(pts, fill)
		draw_polyline(pts, border, 2.0 * s, true)

	func _draw_half_heart(offset: Vector2, s: float, fill: Color, border: Color) -> void:
		var full_pts := _get_heart_polygon(offset, s)
		# Recortar polígono a la mitad izquierda (x <= offset.x + 16 * s)
		var mid_x := offset.x + 16.0 * s
		var left_pts: PackedVector2Array = []
		
		# Generamos mitad izquierda
		for pt in full_pts:
			if pt.x <= mid_x + 0.5:
				left_pts.append(pt)
			else:
				left_pts.append(Vector2(mid_x, pt.y))
				
		draw_colored_polygon(left_pts, fill)
		draw_polyline(full_pts, border, 2.0 * s, true)

	func _get_heart_polygon(offset: Vector2, s: float) -> PackedVector2Array:
		var raw_pts: Array[Vector2] = [
			Vector2(16, 28),
			Vector2(5, 17),
			Vector2(2, 11),
			Vector2(3, 5),
			Vector2(8, 2),
			Vector2(14, 4),
			Vector2(16, 8),
			Vector2(18, 4),
			Vector2(24, 2),
			Vector2(29, 5),
			Vector2(30, 11),
			Vector2(27, 17),
		]
		var scaled: PackedVector2Array = []
		for p in raw_pts:
			scaled.append(offset + p * s)
		return scaled
