extends CharacterBody2D

@export var speed: float = 120.0
@export var min_wander_time: float = 1.0
@export var max_wander_time: float = 3.0
@export var min_idle_time: float = 0.5
@export var max_idle_time: float = 2.0

var move_direction: Vector2 = Vector2.ZERO
var state_timer: float = 0.0
var is_moving: bool = false

func _ready() -> void:
	pick_new_state()

func _physics_process(delta: float) -> void:
	state_timer -= delta
	if state_timer <= 0:
		pick_new_state()

	if is_moving:
		velocity = move_direction * speed
	else:
		velocity = Vector2.ZERO

	move_and_slide()

func pick_new_state() -> void:
	# Alterna entre caminar y quedarse quieta
	is_moving = !is_moving
	
	if is_moving:
		# Elige una dirección aleatoria normalizada en el plano 2D
		move_direction = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		state_timer = randf_range(min_wander_time, max_wander_time)
		
		# Opcional: voltear el sprite según la dirección horizontal
		# if has_node("Sprite2D"):
		#     $Sprite2D.flip_h = move_direction.x < 0
	else:
		move_direction = Vector2.ZERO
		state_timer = randf_range(min_idle_time, max_idle_time)
