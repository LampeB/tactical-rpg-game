extends Node2D
## Displays a sprite for a combat entity on the battlefield.
## Supports awaitable animations for sequenced combat flow.

signal animation_finished
signal clicked(entity: CombatEntity)
signal mouse_entered_sprite(entity: CombatEntity)
signal mouse_exited_sprite(entity: CombatEntity)

var _entity: CombatEntity

@onready var _sprite: Sprite2D = $Sprite
@onready var _click_area: Area2D = $ClickArea


func setup(entity: CombatEntity) -> void:
	_entity = entity

	# Load sprite texture
	if entity.is_player and entity.character_data:
		_sprite.texture = entity.character_data.portrait
		_sprite.flip_h = false
	elif not entity.is_player and entity.enemy_data:
		_sprite.texture = entity.enemy_data.sprite
		_sprite.flip_h = true

	# Scale sprite to fit
	if _sprite.texture:
		var tex_size: Vector2 = _sprite.texture.get_size()
		var target_size: float = 96.0
		var scale_factor: float = target_size / max(tex_size.x, tex_size.y)
		_sprite.scale = Vector2(scale_factor, scale_factor)

	# Set up collision shape to match sprite size
	var shape: RectangleShape2D = RectangleShape2D.new()
	shape.size = Vector2(96, 96)
	$ClickArea/CollisionShape2D.shape = shape


func _ready() -> void:
	_click_area.input_event.connect(_on_area_input_event)
	_click_area.mouse_entered.connect(_on_area_mouse_entered)
	_click_area.mouse_exited.connect(_on_area_mouse_exited)


func _on_area_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if _entity and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_entity)


func _on_area_mouse_entered() -> void:
	if _entity:
		mouse_entered_sprite.emit(_entity)


func _on_area_mouse_exited() -> void:
	if _entity:
		mouse_exited_sprite.emit(_entity)


# === Awaitable Animations ===

func play_attack_animation() -> void:
	## Quick forward lunge. Await this to wait for completion.
	var tween := create_tween()
	var offset: float = 20.0 if _entity.is_player else -20.0
	tween.tween_property(_sprite, "position:x", _sprite.position.x + offset, 0.15)
	tween.tween_property(_sprite, "position:x", _sprite.position.x, 0.15)
	tween.tween_callback(func(): animation_finished.emit())


func play_hurt_animation() -> void:
	## Flash red and shake. Await this to wait for completion.
	var tween := create_tween()
	tween.tween_property(_sprite, "modulate", Color(1.5, 0.5, 0.5, 1.0), 0.1)
	tween.tween_property(_sprite, "modulate", Color.WHITE, 0.1)

	var shake_tween := create_tween()
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x + 5, 0.05)
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x - 5, 0.05)
	shake_tween.tween_property(_sprite, "position:x", _sprite.position.x, 0.05)

	# Wait for the longer tween (color flash = 0.2s)
	tween.tween_callback(func(): animation_finished.emit())


func play_death_animation() -> void:
	## Fade out and fall. Await this to wait for completion.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(_sprite, "modulate:a", 0.0, 0.5)
	tween.tween_property(_sprite, "position:y", _sprite.position.y + 20, 0.5)
	tween.chain().tween_callback(func(): animation_finished.emit())


func play_cast_animation() -> void:
	## Stub for future spell casting animation.
	animation_finished.emit()


func play_idle_animation() -> void:
	## Stub for future idle/breathing animation.
	animation_finished.emit()


func set_highlight(active: bool) -> void:
	if active:
		_sprite.modulate = Color(1.3, 1.3, 1.3, 1.0)
	else:
		_sprite.modulate = Color.WHITE


func get_global_center() -> Vector2:
	return _sprite.global_position
