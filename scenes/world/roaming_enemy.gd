extends CharacterBody2D
## Visible enemy on the overworld that triggers battle when touched.

@export var encounter_data: EncounterData
@export var enemy_color: Color = Color(1, 0.3, 0.3)  # Red for enemies
@export var move_speed: float = 50.0
@export var patrol_distance: float = 100.0

var _start_position: Vector2
var _move_direction: Vector2
var _move_timer: float = 0.0
var _direction_change_interval: float = 2.0

@onready var _visual: ColorRect = $ColorRect
@onready var _label: Label = $Label
@onready var _collision_area: Area2D = $DetectionArea


func _ready() -> void:
	_start_position = global_position
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
	if body.name == "Player" and encounter_data:
		_trigger_battle()


func _trigger_battle() -> void:
	## Triggers the battle and removes this enemy from the map.
	DebugLogger.log_info("Enemy encountered: %s" % encounter_data.display_name, "RoamingEnemy")

	# Save player position
	var player: CharacterBody2D = get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)

	# Trigger battle
	SceneManager.push_scene("res://scenes/battle/battle.tscn", {
		"encounter": encounter_data,
		"grid_inventories": GameManager.party.grid_inventories if GameManager.party else {},
	})

	# Remove enemy from map (despawn after battle)
	queue_free()
