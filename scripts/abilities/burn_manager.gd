extends Node2D

@export var grass_layers: Array[TileMapLayer] = []
@export var fire_scene: PackedScene

# Tamaño de los sectores usados para evitar duplicados.
@export_range(1.0, 256.0) var sector_size: float = 32.0

@export var burn_color: Color = Color(0.10, 0.07, 0.05, 1.0)
@export var burn_z_index: int = 0

@onready var active_fires: Node2D = $ActiveFires
@onready var burn_marks: Node2D = $BurnMarks

# Conservamos el registro aunque el fuego se apague.
var _burned_sectors: Dictionary = {}

# Independiente de sector_size, que evita duplicar fuegos.
const GRASS_INDEX_SIZE := 128.0

var _grass_index: Dictionary = {}
var _grass_entries: Array[Dictionary] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_build_grass_index()

func _build_grass_index() -> void:
	_grass_index.clear()
	_grass_entries.clear()

	for layer in grass_layers:
		if not is_instance_valid(layer) && layer.tile_set == null:
			continue

		for cell in layer.get_used_cells():
			var source_id := layer.get_cell_source_id(cell)
			var tile_data := layer.get_cell_tile_data(cell)

			if source_id < 0 or tile_data == null:
				continue

			var atlas := layer.tile_set.get_source(
				source_id
			) as TileSetAtlasSource

			if atlas == null:
				continue

			var atlas_coords := layer.get_cell_atlas_coords(cell)
			var region := atlas.get_tile_texture_region(atlas_coords)
			var tile_size := Vector2(region.size)

			var center := (
				layer.map_to_local(cell)
				- Vector2(tile_data.texture_origin)
			)

			var local_rect := Rect2(
				center - tile_size * 0.5,
				tile_size
			)

			var world_rect: Rect2 = (
				layer.global_transform * local_rect
			)

			var entry_id := _grass_entries.size()

			_grass_entries.append({
				"layer": layer,
				"cell": cell,
				"rect": world_rect,
				"removed": false
			})

			# Una mata grande puede ocupar varios sectores.
			var first := _index_key(world_rect.position)
			var last := _index_key(world_rect.end)

			for y in range(first.y, last.y + 1):
				for x in range(first.x, last.x + 1):
					var key := Vector2i(x, y)

					if not _grass_index.has(key):
						_grass_index[key] = []

					_grass_index[key].append(entry_id)

func _index_key(world_position: Vector2) -> Vector2i:
	return Vector2i(
		floori(world_position.x / GRASS_INDEX_SIZE),
		floori(world_position.y / GRASS_INDEX_SIZE)
	)


func burn_at(world_position: Vector2, radius: float) -> void:
	if radius <= 0.0:
		return

	if fire_scene == null:
		push_warning("BurnManager: falta asignar Fire Scene.")
		return

	var size := maxf(sector_size, 1.0)
	var sector := Vector2i(
		floori(world_position.x / size),
		floori(world_position.y / size)
	)

	# Ya procesamos este sector: no duplicar fuego ni marcas.
	if _burned_sectors.has(sector):
		return

	# Validar la escena antes de modificar el escenario.
	var instance := fire_scene.instantiate()
	var fire := instance as Area2D

	if fire == null:
		instance.free()
		push_warning("BurnManager: Fire Scene debe tener raíz Area2D.")
		return

	_burned_sectors[sector] = true

	_remove_grass(world_position, radius)
	_create_burn_mark(world_position, radius)
	_place_fire(fire, world_position, radius)
	
	
# Busca las matas cuyo rectángulo visual toca el círculo.
func _remove_grass(
	world_position: Vector2,
	radius: float
) -> void:
	var extent := Vector2.ONE * radius
	var first := _index_key(world_position - extent)
	var last := _index_key(world_position + extent)

	# Evita revisar una misma mata varias veces.
	var checked: Dictionary = {}

	for y in range(first.y, last.y + 1):
		for x in range(first.x, last.x + 1):
			var key := Vector2i(x, y)

			if not _grass_index.has(key):
				continue

			var candidates: Array = _grass_index[key]

			for entry_id in candidates:
				if checked.has(entry_id):
					continue

				checked[entry_id] = true

				var entry: Dictionary = _grass_entries[entry_id]

				if entry["removed"]:
					continue

				var layer: TileMapLayer = entry["layer"]

				if not is_instance_valid(layer):
					continue

				var rect: Rect2 = entry["rect"]

				if not _circle_touches_rect(
					world_position, radius, rect
				):
					continue

				var cell: Vector2i = entry["cell"]
				layer.erase_cell(cell)
				entry["removed"] = true


func _circle_touches_rect(
	center: Vector2,
	radius: float,
	rect: Rect2
	) -> bool:
	# Punto del rectángulo más cercano al centro del círculo.
	var closest_point := Vector2(
		clampf(center.x, rect.position.x, rect.end.x),
		clampf(center.y, rect.position.y, rect.end.y)
	)

	return center.distance_squared_to(closest_point) <= radius * radius


# Crea una mancha sin necesitar una imagen.
func _create_burn_mark(
	world_position: Vector2,
	radius: float
) -> void:
	var mark := Polygon2D.new()
	mark.name = "BurnMark"
	mark.color = burn_color
	mark.z_as_relative = false
	mark.z_index = burn_z_index

	var points := PackedVector2Array()
	var point_count := 20

	for index in range(point_count):
		var angle := TAU * float(index) / float(point_count)
		var world_point := (
			world_position
			+ Vector2(cos(angle), sin(angle)) * radius
		)

		# Los puntos quedan expresados en el espacio de BurnMarks.
		points.append(burn_marks.to_local(world_point))

	mark.polygon = points
	burn_marks.add_child(mark)


func _place_fire(
	fire: Area2D,
	world_position: Vector2,
	radius: float
	) -> void:
		
	# Colocarlo antes de entrar al árbol, para que _ready()
	# encuentre la posición correcta.
	fire.transform = (
		active_fires.global_transform.affine_inverse()
		* Transform2D(0.0, world_position)
	)

	# Cada fuego necesita su propia forma de colisión.
	var collision := fire.get_node_or_null(
		"CollisionShape2D"
	) as CollisionShape2D

	if collision != null:
		var circle := CircleShape2D.new()
		circle.radius = radius
		collision.shape = circle
		collision.position = Vector2.ZERO

	var particles := fire.get_node_or_null(
		"FireParticles"
	) as CPUParticles2D

	if particles != null:
		particles.emission_shape = (
			CPUParticles2D.EMISSION_SHAPE_SPHERE
		)
		particles.emission_sphere_radius = radius * 0.8

	active_fires.add_child(fire)
