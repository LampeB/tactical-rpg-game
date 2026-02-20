extends CharacterBody2D
## Handles player movement, collision, and step counting on the overworld.

signal step_taken(step_count: int)

const SPEED := Constants.PLAYER_SPEED  # 200.0 pixels/sec
const PIXELS_PER_STEP := 16.0

var _step_accumulator: float = 0.0
var _total_steps: int = 0
var _is_input_enabled: bool = true
var _current_location_area: Area2D = null

@onready var _visual: CanvasItem = $ColorRect if has_node("ColorRect") else $Sprite2D if has_node("Sprite2D") else null
@onready var _interaction_area: Area2D = $InteractionArea


func _ready() -> void:
	# Add to player group for enemy detection
	add_to_group("player")

	# Setup collision layers
	collision_layer = 2  # player layer
	collision_mask = 1   # collides with world

	# Setup interaction area
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 4  # detects interactables
	_interaction_area.area_entered.connect(_on_location_entered)
	_interaction_area.area_exited.connect(_on_location_exited)


func _physics_process(delta: float) -> void:
	if not _is_input_enabled:
		return

	var input_vector := Vector2.ZERO
	input_vector.x = Input.get_axis("move_left", "move_right")
	input_vector.y = Input.get_axis("move_up", "move_down")

	# Debug: print first movement
	if input_vector.length() > 0 and _total_steps == 0:
		DebugLogger.log_info("Movement detected: %s" % input_vector, "Player")

	if input_vector.length() > 0:
		input_vector = input_vector.normalized()
		velocity = input_vector * SPEED
		_update_sprite_direction(input_vector)
	else:
		velocity = Vector2.ZERO

	var previous_pos := global_position
	move_and_slide()

	# Debug: log position changes
	if global_position.distance_to(previous_pos) > 0.1:
		DebugLogger.log_info("Moved from %s to %s (delta: %s)" % [previous_pos, global_position, global_position - previous_pos], "Player")

	# Step counting for random encounters
	if velocity.length() > 0:
		var distance := global_position.distance_to(previous_pos)
		_step_accumulator += distance

		while _step_accumulator >= PIXELS_PER_STEP:
			_step_accumulator -= PIXELS_PER_STEP
			_total_steps += 1
			step_taken.emit(_total_steps)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current_location_area:
		_interact_with_location()
		get_viewport().set_input_as_handled()


func _update_sprite_direction(direction: Vector2) -> void:
	# Flip sprite based on horizontal movement (only works with Sprite2D)
	if _visual and _visual is Sprite2D:
		if direction.x < 0:
			_visual.flip_h = true
		elif direction.x > 0:
			_visual.flip_h = false
	# Could add AnimationPlayer here for walking animations


func _on_location_entered(area: Area2D) -> void:
	if area.has_method("get_location_data"):
		_current_location_area = area
		var loc_data: LocationData = area.get_location_data()
		EventBus.location_prompt_visible.emit(true, loc_data.display_name)


func _on_location_exited(area: Area2D) -> void:
	if area == _current_location_area:
		_current_location_area = null
		EventBus.location_prompt_visible.emit(false, "")


func _interact_with_location() -> void:
	if _current_location_area and _current_location_area.has_method("try_enter"):
		_current_location_area.try_enter()


func enable_input(enabled: bool) -> void:
	_is_input_enabled = enabled


func get_step_count() -> int:
	return _total_steps


func reset_step_counter() -> void:
	_total_steps = 0
	_step_accumulator = 0.0
