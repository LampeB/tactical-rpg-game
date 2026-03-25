extends CharacterBody3D
## Handles player movement, collision, and step counting on the overworld.

signal step_taken(step_count: int)

const UNITS_PER_STEP := Constants.UNITS_PER_STEP
const GRAVITY := 18.0
const JUMP_VELOCITY := 6.0
const MAX_SLOPE_DEG := 45.0

var _step_accumulator: float = 0.0
var _total_steps: int = 0
var _is_input_enabled: bool = true
var _current_location_area: Area3D = null
var _model: Node3D = null
var _animator: ModelAnimator = null

@onready var _interaction_area: Area3D = $InteractionArea


func _ready() -> void:
	add_to_group("player")

	# Setup collision layers
	collision_layer = 2  # player layer
	collision_mask = 1   # collides with world
	floor_max_angle = deg_to_rad(MAX_SLOPE_DEG)

	# Setup interaction area
	_interaction_area.collision_layer = 0
	_interaction_area.collision_mask = 4  # detects interactables
	_interaction_area.area_entered.connect(_on_location_entered)
	_interaction_area.area_exited.connect(_on_location_exited)

	# Build CSG character model
	_build_player_model()

	# Attach procedural walk/idle animator
	_animator = ModelAnimator.new()
	add_child(_animator)
	_animator.setup(_model)


func _physics_process(delta: float) -> void:
	if not _is_input_enabled:
		return

	var input_x := Input.get_axis("move_left", "move_right")
	var input_z := Input.get_axis("move_up", "move_down")
	var raw_input := Vector3(input_x, 0.0, input_z)
	var is_sprinting := Input.is_action_pressed("sprint")

	if raw_input.length() > 0:
		raw_input = raw_input.normalized()
		# Transform input relative to camera orientation so "forward" follows the camera
		var cam := get_viewport().get_camera_3d()
		var input_vector: Vector3
		if cam:
			var cam_forward := -cam.global_transform.basis.z
			cam_forward.y = 0.0
			cam_forward = cam_forward.normalized()
			var cam_right := cam.global_transform.basis.x
			cam_right.y = 0.0
			cam_right = cam_right.normalized()
			input_vector = cam_right * raw_input.x - cam_forward * raw_input.z
		else:
			input_vector = raw_input
		input_vector.y = 0.0
		var base_speed: float = LiveTweaks.get_float("player_speed")
		var sprint_mult: float = LiveTweaks.get_float("sprint_multiplier")
		var current_speed := base_speed * sprint_mult if is_sprinting else base_speed
		velocity = input_vector.normalized() * current_speed
		_update_model_direction(input_vector)
	else:
		velocity = Vector3.ZERO

	if _animator:
		_animator.set_walking(velocity.length() > 0.1)
		var anim_sprint: float = LiveTweaks.get_float("sprint_multiplier")
		_animator.speed_scale = anim_sprint if is_sprinting else 1.0

	# Jump
	if is_on_floor() and Input.is_action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY

	# Apply gravity if not on floor
	if not is_on_floor():
		velocity.y -= GRAVITY * delta

	var previous_pos := global_position
	move_and_slide()

	# Wall crossing check — only check walls within 50m of the player
	var prev_xz := Vector2(previous_pos.x, previous_pos.z)
	var cur_xz := Vector2(global_position.x, global_position.z)
	if prev_xz.distance_squared_to(cur_xz) > 0.0001:
		# Refresh wall list every 60 frames (not every frame)
		if _wall_cache.is_empty() or Engine.get_frames_drawn() % 60 == 0:
			_wall_cache = get_tree().get_nodes_in_group("wall_paths")
		var check_radius_sq: float = 2500.0  # 50m squared
		var player_xz := Vector2(global_position.x, global_position.z)
		var was_blocked: bool = false
		for wi in range(_wall_cache.size()):
			if was_blocked:
				break
			var wall = _wall_cache[wi]
			if not wall.has_method("is_locked") or not wall.is_locked():
				continue
			# Quick distance check: skip walls far from player
			var wall_pos: Vector3 = wall.global_position
			var wall_xz := Vector2(wall_pos.x, wall_pos.z)
			if player_xz.distance_squared_to(wall_xz) > check_radius_sq:
				continue
			var pts: PackedVector3Array = wall.get_baked_points_global()
			for si in range(pts.size() - 1):
				var a_xz := Vector2(pts[si].x, pts[si].z)
				var b_xz := Vector2(pts[si + 1].x, pts[si + 1].z)
				if _segments_intersect(prev_xz, cur_xz, a_xz, b_xz):
					global_position = previous_pos
					was_blocked = true
					break

	# Step counting for random encounters
	if velocity.length() > 0:
		# Only count horizontal distance
		var horizontal_move := Vector3(global_position.x - previous_pos.x, 0, global_position.z - previous_pos.z)
		var distance := horizontal_move.length()
		_step_accumulator += distance

		while _step_accumulator >= UNITS_PER_STEP:
			_step_accumulator -= UNITS_PER_STEP
			_total_steps += 1
			step_taken.emit(_total_steps)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and _current_location_area:
		_interact_with_location()
		get_viewport().set_input_as_handled()


func _build_player_model() -> void:
	## Builds a CSG character model for the player using the first squad member.
	if GameManager.party and not GameManager.party.squad.is_empty():
		var char_id: String = GameManager.party.squad[0]
		var char_data: CharacterData = GameManager.party.roster.get(char_id)
		if char_data:
			_model = CSGCharacterFactory.create_from_character(char_data)
			add_child(_model)
			return
	# Fallback: default warrior model
	var fallback := CharacterData.new()
	fallback.display_name = "Player"
	fallback.character_class = "Warrior"
	_model = CSGCharacterFactory.create_from_character(fallback)
	add_child(_model)


func _update_model_direction(direction: Vector3) -> void:
	## Rotates the model to face movement direction.
	if _model and direction.length() > 0.1:
		_model.rotation.y = atan2(-direction.x, -direction.z)



func _on_location_entered(area: Area3D) -> void:
	if area.has_method("get_location_data"):
		_current_location_area = area
		var loc_data: LocationData = area.get_location_data()
		EventBus.location_prompt_visible.emit(true, loc_data.display_name)
	elif area.has_method("get_display_name"):
		# ConnectionMarker — map transition point
		_current_location_area = area
		EventBus.location_prompt_visible.emit(true, area.get_display_name())


func _on_location_exited(area: Area3D) -> void:
	if area == _current_location_area:
		_current_location_area = null
		EventBus.location_prompt_visible.emit(false, "")


func _interact_with_location() -> void:
	if _current_location_area and _current_location_area.has_method("try_enter"):
		_current_location_area.try_enter()


func enable_input(enabled: bool) -> void:
	_is_input_enabled = enabled


var _terrain_cache: HeightmapTerrain3D = null
var _wall_cache: Array = []


func _segments_intersect(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2) -> bool:
	## Returns true if line segment (p1→p2) crosses (p3→p4). 2D cross product method.
	var d1: Vector2 = p2 - p1
	var d2: Vector2 = p4 - p3
	var denom: float = d1.x * d2.y - d1.y * d2.x
	if absf(denom) < 0.0001:
		return false  # parallel
	var t: float = ((p3.x - p1.x) * d2.y - (p3.y - p1.y) * d2.x) / denom
	var u: float = ((p3.x - p1.x) * d1.y - (p3.y - p1.y) * d1.x) / denom
	return t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0


func _get_terrain() -> HeightmapTerrain3D:
	if _terrain_cache and is_instance_valid(_terrain_cache):
		return _terrain_cache
	var nodes: Array = get_tree().get_nodes_in_group("terrain")
	if not nodes.is_empty():
		_terrain_cache = nodes[0] as HeightmapTerrain3D
		return _terrain_cache
	# Fallback: search parent for HeightmapTerrain3D
	var parent: Node = get_parent()
	while parent:
		if parent is HeightmapTerrain3D:
			_terrain_cache = parent as HeightmapTerrain3D
			return _terrain_cache
		for i in range(parent.get_child_count()):
			var child: Node = parent.get_child(i)
			if child is HeightmapTerrain3D:
				_terrain_cache = child as HeightmapTerrain3D
				return _terrain_cache
		parent = parent.get_parent()
	return null


func get_step_count() -> int:
	return _total_steps


func reset_step_counter() -> void:
	_total_steps = 0
	_step_accumulator = 0.0
