extends Area2D
## Interactable location marker on the overworld map.

@export var location_data: LocationData

@onready var _sprite: Sprite2D = $Sprite2D
@onready var _label: Label = $Label


func _ready() -> void:
	collision_layer = 4  # interactables layer
	collision_mask = 0

	if location_data:
		_sprite.texture = location_data.icon
		_label.text = location_data.display_name
		_label.visible = false
		_update_visual_state()

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _update_visual_state() -> void:
	## Updates marker appearance based on unlock status.
	var is_unlocked := _check_unlocked()

	if not is_unlocked and not location_data.is_visible_when_locked:
		visible = false
	elif not is_unlocked:
		modulate = Color(0.5, 0.5, 0.5, 0.6)  # Greyed out
	else:
		modulate = Color.WHITE


func _check_unlocked() -> bool:
	## Returns true if this location is accessible.
	if location_data.unlock_flag.is_empty():
		return true
	return GameManager.has_flag(location_data.unlock_flag)


func get_location_data() -> LocationData:
	return location_data


func try_enter() -> void:
	## Attempts to enter this location. Shows message if locked, otherwise transitions to location scene.
	if not _check_unlocked():
		EventBus.show_message.emit("This location is locked.")
		return

	# Transition to location scene
	SceneManager.push_scene(location_data.scene_path, {
		"from_overworld": true,
		"entrance": location_data.entrance_position
	})

	# Mark as visited for fast travel
	if location_data.must_visit_first:
		GameManager.set_flag("visited_" + location_data.id)


func _on_mouse_entered() -> void:
	_label.visible = true


func _on_mouse_exited() -> void:
	_label.visible = false
