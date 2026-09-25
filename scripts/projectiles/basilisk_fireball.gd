## Proyectil de Fuego del Basilisco.
##
## Inflige 1 de daño al jugador (como especificado en el diseño).
## Viaja en línea recta hacia la posición objetivo y explota al impactar con el jugador o paredes.
extends Area2D

# --- Configuración ---
## Daño infligido al jugador (1 de daño según especificaciones).
@export var damage: float = 1.0
## Velocidad del proyectil (px/s).
@export var speed: float = 650.0
## Tiempo de vida máximo antes de auto-destruirse.
@export var lifetime: float = 6.0

# --- Estado ---
var direction: Vector2 = Vector2.RIGHT
var _time_alive: float = 0.0
var _is_exploding: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var trail_particles: CPUParticles2D = get_node_or_null("TrailParticles")
@onready var explosion_particles: CPUParticles2D = get_node_or_null("ExplosionParticles")
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	add_to_group("enemy_attack")
	
	# Orientar el proyectil hacia su dirección
	rotation = direction.angle()
	
	# Conectar señales de impacto
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	if _is_exploding:
		return

	position += direction * speed * delta
	_time_alive += delta

	# Rotación sutil o pulso visual de fuego
	if sprite:
		sprite.scale = Vector2.ONE * (0.85 + 0.15 * sin(_time_alive * 20.0))

	if _time_alive >= lifetime:
		_explode()


func _on_body_entered(body: Node2D) -> void:
	if _is_exploding or body == null:
		return
		
	# Ignorar al propio jefe o enemigos
	if body.is_in_group("enemy") or body.is_in_group("basilisco"):
		return
		
	# Impactar al jugador
	if body.is_in_group("player") or body.name == "Player":
		if body.has_method("take_damage"):
			body.take_damage(damage)
		_explode()
		return

	# Impacto con obstáculos / paredes sólidas del mapa
	_explode()


func _on_area_entered(area: Area2D) -> void:
	if _is_exploding or area == null:
		return

	# Ignorar áreas del jefe
	if area.is_in_group("enemy") or area.get_parent().is_in_group("enemy"):
		return

	# Si es el Hurtbox del jugador
	if area.is_in_group("player") or area.name == "Hurtbox" or (area.get_parent() and area.get_parent().is_in_group("player")):
		var player_node = area if area.has_method("take_damage") else area.get_parent()
		if player_node and player_node.has_method("take_damage"):
			player_node.take_damage(damage)
		_explode()


func _explode() -> void:
	if _is_exploding:
		return
	_is_exploding = true

	# Desactivar colisión y ocultar sprite principal
	collision_shape.set_deferred("disabled", true)
	if sprite:
		sprite.visible = false
	if trail_particles:
		trail_particles.emitting = false

	# Emitir partículas de explosión ígnea
	if explosion_particles:
		explosion_particles.restart()
		explosion_particles.emitting = true
		var tree := get_tree()
		if tree:
			await tree.create_timer(explosion_particles.lifetime + 0.1).timeout

	queue_free()
