extends Area3D
## Interactable chest on the overworld. When the player enters range and presses
## [interact], the chest opens and pushes the loot screen. (3D version)

@export var chest_id: String = ""

var _chest_data: ChestData = null
var _player_nearby: bool = false
var _is_opened: bool = false
var _interact_prompt: Label3D = null
var _lid_node: CSGBox3D = null

## Visual type → body color mapping.
const VISUAL_COLORS: Dictionary = {
	"wooden": Color(0.55, 0.35, 0.17),
	"iron": Color(0.55, 0.55, 0.58),
	"gold": Color(0.85, 0.70, 0.20),
	"ornate": Color(0.55, 0.25, 0.65),
}

const LID_CLOSED_ROTATION := 0.0
const LID_OPEN_ROTATION := -110.0


func _ready() -> void:
	if chest_id.is_empty():
		DebugLogger.log_warn("ChestMarker has no chest_id set", "ChestMarker")
		return

	_chest_data = ChestDatabase.get_chest(chest_id)
	if not _chest_data:
		DebugLogger.log_warn("Chest not found: %s" % chest_id, "ChestMarker")
		return

	# Check persistence
	if _chest_data.one_time_only:
		_is_opened = GameManager.get_flag("chest_%s_opened" % chest_id, false)

	_build_visual()

	collision_layer = 4  # interactables
	collision_mask = 2   # detects player body
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)


func _build_visual() -> void:
	var base_color: Color = VISUAL_COLORS.get(_chest_data.visual_type, VISUAL_COLORS["wooden"])

	# Body (main box)
	var body := CSGBox3D.new()
	body.name = "Body"
	body.size = Vector3(0.8, 0.5, 0.5)
	body.position.y = 0.25
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = base_color
	body.material = body_mat
	add_child(body)

	# Lid (hinged at the back top edge)
	var lid_pivot := Node3D.new()
	lid_pivot.name = "LidPivot"
	lid_pivot.position = Vector3(0.0, 0.5, -0.25)
	add_child(lid_pivot)

	_lid_node = CSGBox3D.new()
	_lid_node.name = "Lid"
	_lid_node.size = Vector3(0.82, 0.1, 0.52)
	_lid_node.position = Vector3(0.0, 0.05, 0.25)
	var lid_mat := StandardMaterial3D.new()
	lid_mat.albedo_color = base_color.lightened(0.15)
	_lid_node.material = lid_mat
	lid_pivot.add_child(_lid_node)

	# Set initial lid state
	if _is_opened:
		lid_pivot.rotation_degrees.x = LID_OPEN_ROTATION
	else:
		lid_pivot.rotation_degrees.x = LID_CLOSED_ROTATION

	# Collision shape for interaction range
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = Constants.INTERACTION_RANGE
	collision.shape = sphere
	add_child(collision)

	# Interact prompt (hidden until player is nearby)
	_interact_prompt = Label3D.new()
	_interact_prompt.name = "InteractPrompt"
	_interact_prompt.font_size = 32
	_interact_prompt.position.y = 1.5
	_interact_prompt.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interact_prompt.outline_size = 6
	_interact_prompt.visible = false
	add_child(_interact_prompt)
	_update_prompt_text()


func _update_prompt_text() -> void:
	if not _interact_prompt:
		return
	if _is_opened and _chest_data.one_time_only:
		_interact_prompt.text = "Empty"
		_interact_prompt.modulate = Color(0.6, 0.6, 0.6)
	elif not _chest_data.unlock_flag.is_empty() and not GameManager.get_flag(_chest_data.unlock_flag, false):
		_interact_prompt.text = "Locked"
		_interact_prompt.modulate = Color(1.0, 0.4, 0.4)
	else:
		_interact_prompt.text = "[E] Open"
		_interact_prompt.modulate = Color(1.0, 0.9, 0.5)


func _unhandled_input(event: InputEvent) -> void:
	if _player_nearby and event.is_action_pressed("interact"):
		get_viewport().set_input_as_handled()
		_try_open()


func _on_body_entered(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = true
		_update_prompt_text()
		if _interact_prompt:
			_interact_prompt.visible = true


func _on_body_exited(body: Node3D) -> void:
	if body.name == "Player":
		_player_nearby = false
		if _interact_prompt:
			_interact_prompt.visible = false


func _try_open() -> void:
	if not _chest_data:
		return

	# Already opened (one-time chest)
	if _is_opened and _chest_data.one_time_only:
		EventBus.show_message.emit("This chest is already empty.")
		return

	# Check unlock flag
	if not _chest_data.unlock_flag.is_empty():
		if not GameManager.get_flag(_chest_data.unlock_flag, false):
			EventBus.show_message.emit(_chest_data.locked_message)
			return

	_give_loot()


func _give_loot() -> void:
	# Mark as opened
	GameManager.set_flag("chest_%s_opened" % chest_id, true)
	_is_opened = true
	_animate_open()
	_update_prompt_text()

	# Generate loot
	var items: Array = []
	if _chest_data.loot_table:
		items.append_array(LootGenerator.roll_table(_chest_data.loot_table))
	for i in range(_chest_data.guaranteed_items.size()):
		var item: ItemData = _chest_data.guaranteed_items[i]
		if item:
			items.append(item)

	# Award gold
	if _chest_data.gold_reward > 0:
		GameManager.add_gold(_chest_data.gold_reward)

	# Save player position for overworld return
	var player := get_tree().get_first_node_in_group("player")
	if player:
		GameManager.set_flag("overworld_position", player.global_position)

	# Push loot screen
	SceneManager.push_scene("res://scenes/loot/loot.tscn", {
		"loot": items,
		"gold": _chest_data.gold_reward,
		"source": "chest",
		"loot_grid_template": _chest_data.loot_grid_template,
	})


func _animate_open() -> void:
	var lid_pivot: Node3D = get_node_or_null("LidPivot")
	if not lid_pivot:
		return
	var tween := create_tween()
	tween.tween_property(lid_pivot, "rotation_degrees:x", LID_OPEN_ROTATION, 0.4).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
