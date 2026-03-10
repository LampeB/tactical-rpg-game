extends Area3D
## Interactable NPC on the overworld. When the player enters range and presses
## [interact], the dialogue UI is pushed as a new scene. (3D version)
## Supports optional wandering patrol within a radius of the spawn point.

@export var npc_id: String = ""
## Distance the NPC wanders from its spawn point. 0 = stationary.
@export var patrol_distance: float = 0.0
## Walking speed when wandering.
@export var patrol_speed: float = 1.2

var _npc_data: NpcData = null
var _player_nearby: bool = false
var _interact_prompt: Label3D = null
var _quest_marker: Label3D = null
var _start_position: Vector3
var _move_direction: Vector3 = Vector3.ZERO
var _move_timer: float = 0.0
var _direction_change_interval: float = 3.0
var _model: Node3D = null
var _animator: ModelAnimator = null


func _ready() -> void:
	_start_position = position

	if npc_id.is_empty():
		DebugLogger.log_warn("NpcMarker has no npc_id set", "NpcMarker")
		return

	_npc_data = NpcDatabase.get_npc(npc_id)
	if not _npc_data:
		DebugLogger.log_warn("NPC not found: %s" % npc_id, "NpcMarker")
		return

	_build_visual()
	_build_quest_marker()

	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	EventBus.quest_accepted.connect(_on_quest_state_changed)
	EventBus.quest_completed.connect(_on_quest_state_changed)
	EventBus.quest_progressed.connect(_on_quest_progressed)
	EventBus.quest_available.connect(_on_quest_state_changed)


func _build_visual() -> void:
	## Creates a 3D NPC model with name label and interact prompt.
	# CSG character model
	_model = CSGCharacterFactory.create_from_npc(_npc_data)
	add_child(_model)

	# Attach idle breathing animator
	_animator = ModelAnimator.new()
	add_child(_animator)
	_animator.setup(_model)

	# Collision shape for body detection
	collision_layer = 4  # interactables
	collision_mask = 2   # detects player body
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Constants.INTERACTION_RANGE
	collision.shape = sphere
	add_child(collision)

	# Interact prompt (hidden until player is nearby)
	_interact_prompt = Label3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.text = "[E] Talk"
	_interact_prompt.font_size = 32
	_interact_prompt.position.y = 2.8
	_interact_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_prompt.modulate = Color(0.8, 1.0, 0.8)
	_interact_prompt.outline_size = 6
	_interact_prompt.visible = false
	add_child(_interact_prompt)


func _process(delta: float) -> void:
	if patrol_distance <= 0.0:
		return

	_move_timer += delta
	if _move_timer >= _direction_change_interval:
		_move_timer = 0.0
		_choose_random_direction()

	# Move in current direction
	if _move_direction.length() > 0.01:
		position += _move_direction * patrol_speed * delta

		# Don't wander too far from start
		var horizontal_pos := Vector3(position.x, 0, position.z)
		var horizontal_start := Vector3(_start_position.x, 0, _start_position.z)
		if horizontal_pos.distance_to(horizontal_start) > patrol_distance:
			var dir := (horizontal_start - horizontal_pos).normalized()
			_move_direction = Vector3(dir.x, 0, dir.z)

		# Face movement direction
		if _model:
			_model.rotation.y = atan2(-_move_direction.x, -_move_direction.z)

	# Update walk animation
	if _animator:
		_animator.set_walking(_move_direction.length() > 0.1)


func _choose_random_direction() -> void:
	var rand := randf()
	if rand < 0.3:  # 30% chance to stop (NPCs idle more than enemies)
		_move_direction = Vector3.ZERO
	else:
		var angle := randf() * TAU
		_move_direction = Vector3(cos(angle), 0, sin(angle))


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_start_dialogue()


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = true
		if _interact_prompt:
			_interact_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = false
		if _interact_prompt:
			_interact_prompt.visible = false


func _start_dialogue() -> void:
	if not _npc_data:
		return
	# Save player position so the overworld can restore it when we pop back.
	var player := get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)
	EventBus.dialogue_started.emit(npc_id)
	SceneManager.push_scene("res://scenes/dialogue/dialogue_ui.tscn", {"npc_id": npc_id})


# === Quest Marker ===

func _build_quest_marker() -> void:
	_quest_marker = Label3D.new()
	_quest_marker.name = "QuestMarker"
	_quest_marker.font_size = 48
	_quest_marker.position.y = 3.2
	_quest_marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_quest_marker.outline_size = 8
	_quest_marker.visible = false
	add_child(_quest_marker)
	_update_quest_marker()


func _update_quest_marker() -> void:
	if not _quest_marker:
		return

	if QuestManager.npc_has_turn_in_quest(npc_id):
		# Ready to turn in — yellow "?"
		_quest_marker.text = "?"
		_quest_marker.modulate = Color(1.0, 0.85, 0.0)
		_quest_marker.visible = true
	elif QuestManager.npc_has_available_quest(npc_id):
		# Has new quest to offer — yellow "!"
		_quest_marker.text = "!"
		_quest_marker.modulate = Color(1.0, 0.85, 0.0)
		_quest_marker.visible = true
	elif QuestManager.npc_has_active_quest(npc_id):
		# Has active quest in progress — grey "?"
		_quest_marker.text = "?"
		_quest_marker.modulate = Color(0.5, 0.5, 0.5)
		_quest_marker.visible = true
	else:
		_quest_marker.visible = false


func _on_quest_state_changed(_quest_id: String) -> void:
	_update_quest_marker()


func _on_quest_progressed(_quest_id: String, _obj_index: int, _current: int, _target: int) -> void:
	_update_quest_marker()
