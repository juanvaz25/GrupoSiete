## Rifle bullet projectile script.
##
## Proyectil de alta potencia que inflige 10 de daño y aturde a los objetivos impactados.
extends Area2D

# --- Configuración ---
## Daño infligido por el disparo de rifle.
@export var damage: float = 10.0
## Duración del aturdimiento en segundos.
@export var stun_duration: float = 2.0
## Velocidad del proyectil (px/s).
@export var speed: float = 2000.0
## Distancia máxima antes de autodestruirse (px).
@export var max_range: float = 1400.0

# --- Estado ---
## Dirección de movimiento. Debe asignarse antes de agregar la bala al árbol.
var direction: Vector2 = Vector2.RIGHT

var _distance_traveled: float = 0.0


func _ready() -> void:
	rotation = direction.angle()
	body_entered.connect(_on_hit_target)
	area_entered.connect(_on_hit_target)


func _physics_process(delta: float) -> void:
	var movement: Vector2 = direction * speed * delta
	position += movement
	_distance_traveled += movement.length()

	if _distance_traveled >= max_range:
		queue_free()


## Manejar impacto con un enemigo o superficie.
func _on_hit_target(target: Node2D) -> void:
	if target == null:
		return
	if target.name == "Player" or target.is_in_group("player") or (target.get_parent() != null and target.get_parent().name == "Player"):
		return

	# Aplicar daño y aturdimiento al objetivo directo o a su nodo padre
	var entity: Node2D = target
	if not entity.has_method("take_damage") and entity.get_parent() and entity.get_parent().has_method("take_damage"):
		entity = entity.get_parent()

	if entity.has_method("take_damage"):
		entity.take_damage(damage)

	if entity.has_method("apply_stun"):
		entity.apply_stun(stun_duration)
	elif entity.get("is_stunned") != null:
		entity.set("is_stunned", true)
		# Crear un timer para retirar el aturdimiento si la entidad no maneja su propio timer
		var timer := entity.get_tree().create_timer(stun_duration)
		timer.timeout.connect(func(): if is_instance_valid(entity): entity.set("is_stunned", false))

	_spawn_stun_effect(global_position)
	queue_free()


## Crea un efecto visual de impacto y aturdimiento
func _spawn_stun_effect(pos: Vector2) -> void:
	var effect_node := Node2D.new()
	effect_node.global_position = pos
	
	# Efecto visual programático tipo flash y ondas de aturdimiento
	var circle := Line2D.new()
	circle.width = 3.0
	circle.default_color = Color(1.0, 0.85, 0.2, 0.9) # Amarillo electrizante
	
	var points: PackedVector2Array = []
	var segments := 16
	var radius := 18.0
	for i in range(segments + 1):
		var angle := i * (TAU / segments)
		points.append(Vector2(cos(angle), sin(angle)) * radius)
	circle.points = points
	effect_node.add_child(circle)

	get_tree().current_scene.add_child(effect_node)

	var tween := effect_node.create_tween()
	tween.set_parallel(true)
	tween.tween_property(effect_node, "scale", Vector2(2.5, 2.5), 0.35)
	tween.tween_property(circle, "modulate:a", 0.0, 0.35)
	tween.set_parallel(false)
	tween.tween_callback(effect_node.queue_free)
