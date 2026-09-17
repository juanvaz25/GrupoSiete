## Bullet projectile script.
##
## Attach to an Area2D node. Moves in a straight line at constant speed
## and destroys itself after traveling MAX_RANGE or on collision.
extends Area2D

# --- Configuración ---
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

	# Conectar señal de colisión
	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	var movement: Vector2 = direction * speed * delta
	position += movement
	_distance_traveled += movement.length()

	# Destruir si excede el rango máximo
	if _distance_traveled >= max_range:
		queue_free()


## Destruir la bala al colisionar con un cuerpo físico.
func _on_body_entered(_body: Node2D) -> void:
	# Ignorar al jugador que disparó
	if _body is CharacterBody2D and _body.name == "Player":
		return
	queue_free()
