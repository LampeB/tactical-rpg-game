extends Control
## Displays a sprite for a combat entity on the battlefield.
## Can be animated during attacks, taking damage, etc.

var _entity: CombatEntity

@onready var _sprite: Sprite2D = $Sprite


func setup(entity: CombatEntity) -> void:
	_entity = entity

	# Load sprite texture
	if entity.is_player and entity.character_data:
		_sprite.texture = entity.character_data.portrait
		# Player sprites face right
		_sprite.flip_h = false
	elif not entity.is_player and entity.enemy_data:
		_sprite.texture = entity.enemy_data.sprite
		# Enemy sprites face left
		_sprite.flip_h = true

	# Scale sprite to fit
	if _sprite.texture:
		var tex_size: Vector2 = _sprite.texture.get_size()
		var target_size: float = 96.0
		var scale_factor: float = target_size / max(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(scale_factor, scale_factor)


func play_attack_animation() -> void:
	## Quick forward lunge animation
	var tween := create_tween()
	var offset: float = 20.0 if _entity.is_player else -20.0
	tween.tween_property(_sprite, "position:x", _sprite.position.x + offset, 0.15)
	tween.tween_property(_sprite, "position:x", _sprite.position.x, 0.15)


func play_hurt_animation() -> void:
	## Flash red and shake
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

	var shake_tween := create_tween()
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x + 5, 0.05)
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x - 5, 0.05)
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x, 0.05)


func play_death_animation() -> void:
	## Fade out and fall
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(_sprite, "position:y", _sprite.position.y + 20, 0.5)


func set_highlight(active: bool) -> void:
	if active:
		modulate = Color(1.3, 1.3, 1.3, 1.0)
	else:
		modulate = Color.WHITE


func get_global_center() -> Vector2:
	return _sprite.global_position
