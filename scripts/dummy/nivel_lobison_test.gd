extends TileMapLayer

@onready var burn_manager = $BurnManager
@onready var player: Node2D = $TileMapsLayers/Player


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.pressed and not event.echo:
			if event.keycode == KEY_F6:
				burn_manager.burn_at(
					player.global_position,
					40.0
				)
