extends Area2D

## Tiempo de vida máximo antes de auto-destruirse.
@export var lifetime: float = 8.0


var active: bool = true
var _players_inside: Array[Node2D] = []


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	get_tree().create_timer(lifetime).timeout.connect(extinguish)


func _on_body_entered(body: Node2D) -> void:
	if not active or not body.is_in_group("player"):
		return

	if not body.has_method("enter_fire"):
		return

	if not _players_inside.has(body):
		_players_inside.append(body)
		body.enter_fire(self)


func _on_body_exited(body: Node2D) -> void:
	if not _players_inside.has(body):
		return

	_players_inside.erase(body)

	if is_instance_valid(body):
		body.exit_fire(self)


func extinguish() -> void:
	if not active:
		return

	active = false
	_release_players()
	set_deferred("monitoring", false)

	# Si renombraste tus partículas a FireParticles:
	var particles := get_node_or_null("FireParticles") as CPUParticles2D
	if particles:
		particles.emitting = false



func _release_players() -> void:
	for player in _players_inside:
		if is_instance_valid(player):
			player.exit_fire(self)
	_players_inside.clear()


func _exit_tree() -> void:
	_release_players()
	
	
