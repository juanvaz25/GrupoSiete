## Target Dummy (Muñeco de Paja de entrenamiento).
## Permite al jugador probar el revólver (1 DMG) y el disparo de rifle (10 DMG + aturdimiento).
extends CharacterBody2D

# --- Configuración ---
@export var max_health: float = 50.0
@export var reset_delay: float = 3.0

# --- Estado ---
var current_health: float = 50.0
var is_stunned: bool = false
var _stun_timer: float = 0.0
var _reset_timer: float = 0.0
var _initial_pos: Vector2

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar
@onready var status_label: Label = $StatusLabel
@onready var stun_label: Label = $StunLabel


func _ready() -> void:
	_initial_pos = position
	current_health = max_health
	
	add_to_group("enemy")
	add_to_group("dummy")
	
	if health_bar:
		health_bar.max_value = max_health
		health_bar.value = current_health
	
	if status_label:
		status_label.text = "Muñeco de Paja"
	
	if stun_label:
		stun_label.visible = false


func _process(delta: float) -> void:
	# Manejar aturdimiento
	if is_stunned:
		_stun_timer -= delta
		if stun_label:
			stun_label.visible = true
			stun_label.text = "¡ATURDIDO! (%.1fs)" % max(_stun_timer, 0.0)
		if _stun_timer <= 0.0:
			is_stunned = false
			if stun_label:
				stun_label.visible = false
			modulate = Color(1, 1, 1, 1)

	# Manejar reseteo automático de vida si no está a tope
	if current_health < max_health:
		_reset_timer += delta
		if _reset_timer >= reset_delay:
			current_health = max_health
			_reset_timer = 0.0
			_update_health_bar()


## Recibir daño de proyectiles (revólver: 1, rifle: 10)
func take_damage(amount: float) -> void:
	current_health = max(current_health - amount, 0.0)
	_reset_timer = 0.0
	_update_health_bar()
	
	# Efecto visual de impacto (sacudida y destello)
	_play_hit_effect(amount)
	
	if current_health <= 0.0:
		# Reinicio inmediato tras ser derrotado
		_play_defeated_effect()
		current_health = max_health
		_update_health_bar()


## Recibir aturdimiento (del rifle)
func apply_stun(duration: float) -> void:
	is_stunned = true
	_stun_timer = duration
	modulate = Color(0.6, 0.8, 1.2, 1.0)
	if stun_label:
		stun_label.visible = true
		stun_label.text = "¡ATURDIDO!"


func stun(duration: float) -> void:
	apply_stun(duration)


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = current_health


func _play_hit_effect(damage_amount: float) -> void:
	# Destello blanco/rojo
	var flash_color = Color(1.8, 1.8, 1.8) if damage_amount >= 5.0 else Color(1.5, 0.8, 0.8)
	sprite.modulate = flash_color
	
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(1, 1, 1), 0.15)
	
	# Sacudida horizontal
	var shake_offset: float = 6.0 if damage_amount >= 5.0 else 3.0
	var shake_tween: Tween = create_tween()
	shake_tween.tween_property(sprite, "position:x", shake_offset, 0.04)
	shake_tween.tween_property(sprite, "position:x", -shake_offset, 0.04)
	shake_tween.tween_property(sprite, "position:x", 0.0, 0.04)


func _play_defeated_effect() -> void:
	var tween: Tween = create_tween()
	tween.tween_property(sprite, "scale", Vector2(1.3, 0.7), 0.1)
	tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.2)
