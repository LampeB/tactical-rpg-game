extends CharacterBody3D
## Visible enemy on the overworld that triggers battle when touched. (3D version)

@export var encounter_data: EncounterData
@export var enemy_color: Color = Color(1, 0.3, 0.3)
@export var move_speed: float = Constants.ENEMY_MOVE_SPEED
@export var patrol_distance: float = Constants.ENEMY_PATROL_DISTANCE

var _start_position: Vector3
var _move_direction: Vector3
var _move_timer: float = 0.0
var _direction_change_interval: float = 2.0
var _can_trigger_battle: bool = false  # Start disabled, enabled by overworld after safe positioning
var _detection_enabled: bool = false
var _model: Node3D = null
var _animator: ModelAnimator = null

@onready var _detection_area: Area3D = $DetectionArea


func _ready() -> void:
	# Set start position FIRST so we can generate unique enemy ID
	_start_position = global_position

	# Check if this enemy was already defeated
	var enemy_id := _get_enemy_id()
	if GameManager.get_flag("defeated_enemy_" + enemy_id, false):
		DebugLogger.log_info("Enemy already defeated, removing: %s" % enemy_id, "RoamingEnemy")
		queue_free()
		return

	# Add to roaming_enemies group for cooldown management
	add_to_group("roaming_enemies")

	# Build CSG enemy model
	_build_enemy_model()

	collision_layer = 0
	collision_mask = 1  # Collide with world

	_detection_area.body_entered.connect(_on_player_detected)

	# Random initial direction
	_choose_random_direction()


func _build_enemy_model() -> void:
	## Creates a CSG model for this enemy using encounter data or fallback color.
	if encounter_data and not encounter_data.enemies.is_empty():
		var first_enemy: EnemyData = encounter_data.enemies[0]
		_model = CSGCharacterFactory.create_from_enemy(first_enemy)
		add_child(_model)
	else:
		# Fallback: simple colored box wrapped in Node3D
		var root := Node3D.new()
		root.name = "EnemyModel"
		var body := CSGBox3D.new()
		body.size = Vector3(0.6, 1.2, 0.6)
		body.position.y = 0.6
		var mat := StandardMaterial3D.new()
		mat.albedo_color = enemy_color
		body.material = mat
		root.add_child(body)
		_model = root
		add_child(_model)

	# Attach procedural walk/idle animator
	_animator = ModelAnimator.new()
	add_child(_animator)
	_animator.setup(_model)


func _physics_process(delta: float) -> void:
	_move_timer += delta

	# Change direction periodically
	if _move_timer >= _direction_change_interval:
		_move_timer = 0.0
		_choose_random_direction()

	# Move in current direction (horizontal only)
	velocity = _move_direction * move_speed

	# Don't enter safe zones (town, NPC areas)
	if _move_direction.length() > 0.01:
		var predicted_pos := global_position + _move_direction * move_speed * delta
		if _is_in_safe_zone(predicted_pos):
			_move_direction = -_move_direction
			velocity = _move_direction * move_speed

	if not is_on_floor():
		velocity.y -= 9.8 * delta
	move_and_slide()

	# Update walk animation and facing direction
	if _animator:
		_animator.set_walking(_move_direction.length() > 0.1)
	if _model and _move_direction.length() > 0.1:
		_model.rotation.y = atan2(-_move_direction.x, -_move_direction.z)

	# Don't wander too far from start position
	var horizontal_pos := Vector3(global_position.x, 0, global_position.z)
	var horizontal_start := Vector3(_start_position.x, 0, _start_position.z)
	var distance_from_start := horizontal_pos.distance_to(horizontal_start)
	if distance_from_start > patrol_distance:
		# Head back toward start
		var dir := (horizontal_start - horizontal_pos).normalized()
		_move_direction = Vector3(dir.x, 0, dir.z)


func _is_in_safe_zone(pos: Vector3) -> bool:
	var pos_2d := Vector2(pos.x, pos.z)
	var zones: Array = _get_safe_zones()
	for zone_idx in range(zones.size()):
		var zone: Rect2 = zones[zone_idx]
		if zone.has_point(pos_2d):
			return true
	return false


func _get_safe_zones() -> Array:
	## Returns safe zones from the current map data, falling back to Constants.
	# Enemies live under Enemies node -> parent is Overworld
	var parent_node: Node = get_parent()
	if parent_node:
		parent_node = parent_node.get_parent()
	if parent_node and parent_node.get("_map_data") != null:
		var map: MapData = parent_node.get("_map_data") as MapData
		if map:
			return map.enemy_safe_zones
	return Constants.ENEMY_SAFE_ZONES


func _choose_random_direction() -> void:
	# Random direction or stop
	var rand := randf()
	if rand < 0.2:  # 20% chance to stop
		_move_direction = Vector3.ZERO
	else:
		var angle := randf() * TAU
		_move_direction = Vector3(cos(angle), 0, sin(angle))


func _on_player_detected(body: Node3D) -> void:
	if body.name == "Player" and encounter_data and _can_trigger_battle and _detection_enabled:
		_trigger_battle()


func enable_detection() -> void:
	## Enables battle detection. Called by overworld after player is safely positioned.
	_detection_enabled = true
	_can_trigger_battle = true


func disable_battles_temporarily() -> void:
	## Prevents this enemy from triggering battles for a short time.
	_can_trigger_battle = false


func _get_enemy_id() -> String:
	## Returns a unique identifier for this enemy based on encounter data and spawn position.
	if not encounter_data:
		return name  # Fallback to node name

	# Use encounter ID + rounded position to create unique but deterministic ID
	var pos_x := int(_start_position.x * 10) / 10  # Round to nearest 0.1
	var pos_z := int(_start_position.z * 10) / 10
	return "%s_x%d_z%d" % [encounter_data.id, pos_x, pos_z]


func _trigger_battle() -> void:
	## Triggers the battle and removes this enemy from the map.
	DebugLogger.log_info("Enemy encountered: %s" % encounter_data.display_name, "RoamingEnemy")

	# Save player position
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)

	# Mark this enemy as defeated permanently
	var enemy_id := _get_enemy_id()
	GameManager.set_flag("defeated_enemy_" + enemy_id, true)
	DebugLogger.log_info("Marking enemy as defeated: %s" % enemy_id, "RoamingEnemy")

	# Trigger battle with map context for background
	var fight_pos: Vector3 = player.global_position if player else global_position
	SceneManager.push_scene("res://scenes/battle/battle.tscn", {
		"encounter": encounter_data,
		"grid_inventories": GameManager.party.grid_inventories if GameManager.party else {},
		"fight_position": fight_pos,
		"map_id": GameManager.current_map_id,
	})

	# Remove enemy from map (despawn after battle)
	queue_free()
