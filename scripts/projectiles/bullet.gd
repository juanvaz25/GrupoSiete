## Bullet projectile script for the revolver.
##
## Moves in a straight line until it collides with a wall or enemy,
## or until a 15-second safety lifetime expires.
extends Area2D

# --- Configuración ---
## Daño infligido por el proyectil.
@export var damage: float = 1.0
## Velocidad del proyectil (px/s).
@export var speed: float = 1500.0
## Tiempo de vida máximo en segundos antes de desaparecer si no colisionó.
@export var lifetime: float = 15.0

# --- Estado ---
## Dirección de movimiento. Debe asignarse antes de agregar la bala al árbol.
var direction: Vector2 = Vector2.RIGHT

var _time_alive: float = 0.0


func _ready() -> void:
	# Rotar para apuntar en la dirección de movimiento
	rotation = direction.angle()

	# Reproducir animación si tiene AnimatedSprite2D
	if has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = get_node("AnimatedSprite2D")
		anim.play("default")

	# Conectar señales de colisión (cuerpos y áreas)
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)


func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	_time_alive += delta

	# Destruir tras 15 segundos si no impactó nada
	if _time_alive >= lifetime:
		queue_free()


## Impacto con cuerpos físicos (Paredes, TileMaps, Cuerpos de enemigos)
func _on_body_entered(body: Node2D) -> void:
	if body == null:
		return
	# Ignorar al jugador
	if _is_player_node(body):
		return

	# Si es un enemigo o dummy con take_damage, aplicar daño
	if body.has_method("take_damage"):
		body.take_damage(damage)
	elif body.get_parent() and body.get_parent().has_method("take_damage"):
		body.get_parent().take_damage(damage)

	# Se destruye al chocar con cualquier cuerpo sólido o enemigo
	queue_free()


## Impacto con áreas (Hurtboxes de enemigos o Dummies)
func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	# Ignorar al jugador
	if _is_player_node(area):
		return

	# Solo reaccionar si el área o su padre es un objetivo de daño
	var target_hit := false
	if area.has_method("take_damage"):
		area.take_damage(damage)
		target_hit = true
	elif area.get_parent() and area.get_parent().has_method("take_damage"):
		area.get_parent().take_damage(damage)
		target_hit = true
	elif area.is_in_group("enemy") or area.is_in_group("dummy") or area.is_in_group("hurtbox"):
		target_hit = true

	# Si no es un objetivo de daño (ej: puertas/entradas de salas), la bala lo atraviesa sin destruirse
	if target_hit:
		queue_free()


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if node.name == "Player" or node.is_in_group("player"):
		return true
	if node.get_parent() != null and (node.get_parent().name == "Player" or node.get_parent().is_in_group("player")):
		return true
	return false
