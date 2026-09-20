## Bullet projectile script.
##
## Attach to an Area2D node. Moves in a straight line at constant speed
## and destroys itself after traveling MAX_RANGE or on collision.
extends Area2D

# --- Configuración ---
## Daño infligido por el proyectil.
@export var damage: float = 1.0
## Velocidad del proyectil (px/s).
@export var speed: float = 600.0
## Distancia máxima antes de autodestruirse (px).
@export var max_range: float = 800.0

# --- Estado ---
## Dirección de movimiento. Debe asignarse antes de agregar la bala al árbol.
var direction: Vector2 = Vector2.RIGHT

var _distance_traveled: float = 0.0


func _ready() -> void:
	# Rotar el sprite para que apunte en la dirección de movimiento
	rotation = direction.angle()

	# Conectar señales de colisión (cuerpos y áreas)
	body_entered.connect(_on_hit_target)
	area_entered.connect(_on_hit_target)


func _physics_process(delta: float) -> void:
	var movement: Vector2 = direction * speed * delta
	position += movement
	_distance_traveled += movement.length()

	# Destruir si excede el rango máximo
	if _distance_traveled >= max_range:
		queue_free()


## Manejar impacto con un cuerpo o área enemiga / obstáculo.
func _on_hit_target(target: Node2D) -> void:
	# Ignorar al jugador que disparó o a su hurtbox
	if target == null:
		return
	if target.name == "Player" or target.is_in_group("player") or (target.get_parent() != null and target.get_parent().name == "Player"):
		return

	# Aplicar daño si el objetivo puede recibirlo
	if target.has_method("take_damage"):
		target.take_damage(damage)
	elif target.get_parent() and target.get_parent().has_method("take_damage"):
		target.get_parent().take_damage(damage)

	queue_free()

