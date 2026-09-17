## Dash ability script for the player character.
##
## Attach as a child Node of CharacterBody2D.
## Provides a quick burst of speed in the current movement direction
## when the "dash" action is pressed.
extends Node

# --- Configuración ---
## Velocidad del dash (px/s).
@export var dash_speed: float = 900.0
## Duración del impulso en segundos.
@export var dash_duration: float = 0.15
## Tiempo de espera entre dashes en segundos.
@export var dash_cooldown: float = 0.8

# --- Señales ---
## Emitida al iniciar el dash.
signal dash_started
## Emitida al terminar el dash.
signal dash_finished

# --- Estado interno ---
var is_dashing: bool = false
var _can_dash: bool = true
var _dash_direction: Vector2 = Vector2.ZERO

@onready var _duration_timer: Timer = Timer.new()
@onready var _cooldown_timer: Timer = Timer.new()
@onready var _player: CharacterBody2D = get_parent()


func _ready() -> void:
	# Configurar timer de duración del dash
	_duration_timer.one_shot = true
	_duration_timer.wait_time = dash_duration
	_duration_timer.timeout.connect(_on_dash_duration_timeout)
	add_child(_duration_timer)

	# Configurar timer de cooldown
	_cooldown_timer.one_shot = true
	_cooldown_timer.wait_time = dash_cooldown
	_cooldown_timer.timeout.connect(_on_dash_cooldown_timeout)
	add_child(_cooldown_timer)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("dash") and _can_dash:
		_try_dash()


func _physics_process(_delta: float) -> void:
	if is_dashing:
		_player.velocity = _dash_direction * dash_speed


## Intenta ejecutar el dash si hay una dirección válida.
func _try_dash() -> void:
	# Usar la dirección de input actual; si no hay, usar la última dirección de movimiento
	var direction: Vector2 = _player.input_direction
	if direction == Vector2.ZERO:
		direction = _player.last_direction

	# No hacer dash si no hay dirección conocida
	if direction == Vector2.ZERO:
		return

	_dash_direction = direction.normalized()
	is_dashing = true
	_can_dash = false
	_duration_timer.start()
	dash_started.emit()


func _on_dash_duration_timeout() -> void:
	is_dashing = false
	_cooldown_timer.start()
	dash_finished.emit()


func _on_dash_cooldown_timeout() -> void:
	_can_dash = true
