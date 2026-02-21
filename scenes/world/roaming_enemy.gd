extends CharacterBody2D
## Visible enemy on the overworld that triggers battle when touched.

@export var encounter_data: EncounterData
@export var enemy_sprite: Texture2D  # Override default sprite per enemy instance
@export var enemy_color: Color = Color(1, 0.3, 0.3)  # Red for enemies (legacy ColorRect)
@export var move_speed: float = 50.0
@export var patrol_distance: float = 100.0

var _start_position: Vector2
var _move_direction: Vector2
var _move_timer: float = 0.0
var _direction_change_interval: float = 2.0
var _can_trigger_battle: bool = false  # Start disabled, enabled by overworld after safe positioning
var _detection_enabled: bool = false

@onready var _visual: CanvasItem = $Sprite2D if has_node("Sprite2D") else $ColorRect if has_node("ColorRect") else null
@onready var _label: Label = $Label
@onready var _collision_area: Area2D = $DetectionArea


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

	# Setup visual (Sprite2D or ColorRect)
	if _visual is Sprite2D:
		if enemy_sprite:
			_visual.texture = enemy_sprite
		# Sprite2D uses modulate for tinting
		_visual.modulate = Color.WHITE
	elif _visual is ColorRect:
		_visual.color = enemy_color

	if encounter_data:
		_label.text = encounter_data.display_name.substr(0, 1)  # First letter

	collision_layer = 0
	collision_mask = 1  # Collide with world

	_collision_area.body_entered.connect(_on_player_detected)

	# Random initial direction
	_choose_random_direction()


func _physics_process(delta: float) -> void:
	_move_timer += delta

	# Change direction periodically
	if _move_timer >= _direction_change_interval:
		_move_timer = 0.0
		_choose_random_direction()

	# Move in current direction
	velocity = _move_direction * move_speed
	move_and_slide()

	# Don't wander too far from start position
	var distance_from_start := global_position.distance_to(_start_position)
	if distance_from_start > patrol_distance:
		# Head back toward start
		_move_direction = (_start_position - global_position).normalized()


func _choose_random_direction() -> void:
	# Random direction or stop
	var rand := randf()
	if rand < 0.2:  # 20% chance to stop
		_move_direction = Vector2.ZERO
	else:
		var angle := randf() * TAU
		_move_direction = Vector2(cos(angle), sin(angle))


func _on_player_detected(body: Node2D) -> void:
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
	## This allows us to track which enemies have been defeated permanently.
	if not encounter_data:
		return name  # Fallback to node name

	# Use encounter ID + rounded position to create unique but deterministic ID
	var pos_x := int(_start_position.x / 10) * 10  # Round to nearest 10
	var pos_y := int(_start_position.y / 10) * 10
	return "%s_x%d_y%d" % [encounter_data.id, pos_x, pos_y]


func _trigger_battle() -> void:
	## Triggers the battle and removes this enemy from the map.
	DebugLogger.log_info("Enemy encountered: %s" % encounter_data.display_name, "RoamingEnemy")

	# Save player position
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)

	# Mark this enemy as defeated permanently
	var enemy_id := _get_enemy_id()
	GameManager.set_flag("defeated_enemy_" + enemy_id, true)
	DebugLogger.log_info("Marking enemy as defeated: %s" % enemy_id, "RoamingEnemy")

	# Trigger battle
	SceneManager.push_scene("res://scenes/battle/battle.tscn", {
		"encounter": encounter_data,
		"grid_inventories": GameManager.party.grid_inventories if GameManager.party else {},
	})

	# Remove enemy from map (despawn after battle)
	queue_free()
