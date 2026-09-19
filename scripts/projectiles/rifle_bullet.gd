## High-power rifle bullet projectile script.
##
## Deals 10 damage and applies stun effect to enemies.
## Flies until hitting a wall/enemy or when the 15-second safety lifetime expires.
## Ignores level triggers and boss room doors.
extends Area2D

# --- Configuración ---
## Daño infligido por el disparo de rifle.
@export var damage: float = 10.0
## Velocidad del proyectil (px/s).
@export var speed: float = 2000.0
## Duración del aturdimiento aplicado al enemigo (segundos).
@export var stun_duration: float = 2.0
## Tiempo de vida máximo en segundos antes de desaparecer si no colisionó.
@export var lifetime: float = 15.0

# --- Estado ---
## Dirección de movimiento.
var direction: Vector2 = Vector2.RIGHT

var _time_alive: float = 0.0


func _ready() -> void:
	# Rotar para apuntar en la dirección de movimiento
	rotation = direction.angle()

	# Reproducir animación si tiene AnimatedSprite2D
	if has_node("AnimatedSprite2D"):
		var anim: AnimatedSprite2D = get_node("AnimatedSprite2D")
		anim.play("default")

	# Conectar señales de colisión
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
	if _is_player_node(body):
		return

	# Aplicar daño y aturdimiento
	_apply_damage_and_stun(body)

	# Crear efecto visual de impacto y destruir la bala
	_spawn_impact_effect()
	queue_free()


## Impacto con áreas (Hurtboxes de enemigos o Dummies)
func _on_area_entered(area: Area2D) -> void:
	if area == null:
		return
	if _is_player_node(area):
		return

	# Solo reaccionar si el área o su padre es un objetivo de daño
	var target_hit := false
	if area.has_method("take_damage") or (area.get_parent() and area.get_parent().has_method("take_damage")):
		_apply_damage_and_stun(area)
		target_hit = true
	elif area.is_in_group("enemy") or area.is_in_group("dummy") or area.is_in_group("hurtbox"):
		_apply_damage_and_stun(area)
		target_hit = true

	# Si es una puerta o trigger de nivel, ignorar y atravesar sin destruirse
	if target_hit:
		_spawn_impact_effect()
		queue_free()


func _apply_damage_and_stun(target: Node) -> void:
	var damage_receiver: Node = target
	if not damage_receiver.has_method("take_damage") and target.get_parent() != null and target.get_parent().has_method("take_damage"):
		damage_receiver = target.get_parent()

	if damage_receiver.has_method("take_damage"):
		damage_receiver.take_damage(damage)

	# Aplicar aturdimiento si el objetivo lo soporta
	if damage_receiver.has_method("apply_stun"):
		damage_receiver.apply_stun(stun_duration)
	elif damage_receiver.has_method("stun"):
		damage_receiver.stun(stun_duration)


func _spawn_impact_effect() -> void:
	pass


func _is_player_node(node: Node) -> bool:
	if node == null:
		return false
	if node.name == "Player" or node.is_in_group("player"):
		return true
	if node.get_parent() != null and (node.get_parent().name == "Player" or node.get_parent().is_in_group("player")):
		return true
	return false
