extends Control
## Mission briefing — shown after selecting a mission on the Mission Board.
## Displays full description, recommended level, enemy roster, and rewards.
## "Start Mission" launches the battle; "Back" returns to the Mission Board.
##
## The mission resource is passed in via SceneManager push data, key "mission".

const BATTLE_SCENE_PATH := "res://scenes/maps/forest_clearing.tscn"

@onready var _title: Label = $Panel/VBox/Title
@onready var _level_label: Label = $Panel/VBox/Header/LevelLabel
@onready var _summary_label: Label = $Panel/VBox/SummaryLabel
@onready var _enemies_label: Label = $Panel/VBox/EnemiesBox/EnemiesLabel
@onready var _rewards_label: Label = $Panel/VBox/RewardsBox/RewardsLabel
@onready var _start_button: Button = $Panel/VBox/Buttons/StartButton
@onready var _back_button: Button = $Panel/VBox/Buttons/BackButton

var _mission: MissionData = null


func _ready() -> void:
	_start_button.pressed.connect(_on_start_pressed)
	_back_button.pressed.connect(_on_back_pressed)


func receive_data(data: Dictionary) -> void:
	_mission = data.get("mission", null)
	_refresh()


func _refresh() -> void:
	if _mission == null:
		_title.text = "(No mission selected)"
		_start_button.disabled = true
		return

	_title.text = _mission.display_name
	_level_label.text = "Recommended level: %d" % _mission.recommended_level
	_summary_label.text = _mission.summary if _mission.summary != "" else "(No briefing text)"

	# Enemy roster preview — counts duplicates so "wolf, wolf" reads "Wolf x2"
	_enemies_label.text = _format_enemy_roster(_mission)

	var reward_lines: Array[String] = []
	if _mission.gold_reward > 0:
		reward_lines.append("• %d gold" % _mission.gold_reward)
	if _mission.xp_reward > 0:
		reward_lines.append("• %d xp" % _mission.xp_reward)
	if reward_lines.is_empty():
		reward_lines.append("• (no rewards)")
	_rewards_label.text = "\n".join(reward_lines)

	_start_button.disabled = false


func _format_enemy_roster(mission: MissionData) -> String:
	## Returns a multi-line "Enemy x N" preview of the mission's encounter.
	if mission.encounter_path == "" or not ResourceLoader.exists(mission.encounter_path):
		return "Random %d-%d enemies" % [mission.enemy_count_min, mission.enemy_count_max]
	var enc: Resource = load(mission.encounter_path)
	if not (enc is EncounterData):
		return "Unknown encounter"
	var encounter: EncounterData = enc
	var counts: Dictionary = {}
	var order: Array[String] = []  # preserve first-seen order
	for e in encounter.enemies:
		var name: String = e.display_name if e.display_name != "" else e.id
		if not counts.has(name):
			counts[name] = 0
			order.append(name)
		counts[name] = counts[name] + 1
	var lines: Array[String] = []
	for name in order:
		var count: int = counts[name]
		if count > 1:
			lines.append("• %s ×%d" % [name, count])
		else:
			lines.append("• %s" % name)
	return "\n".join(lines) if not lines.is_empty() else "(no enemies)"


func _on_start_pressed() -> void:
	if _mission == null:
		return
	var encounter: EncounterData = MissionLauncher.resolve_encounter(_mission)
	if encounter == null:
		push_error("[MissionBriefing] Failed to resolve encounter for mission %s" % _mission.id)
		return

	# Load the rich forest_clearing.tscn and run its @tool generator at runtime
	# so trees/water/props are built fresh each battle.
	if ResourceLoader.exists(BATTLE_SCENE_PATH):
		var scene: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
		if scene:
			var bg: Node3D = scene.instantiate() as Node3D
			bg.tree_entered.connect(_run_forest_generator.bind(bg), CONNECT_ONE_SHOT)
			GameManager.preloaded_battle_bg = bg
			GameManager.preloaded_battle_arena_center = MissionLauncher.BATTLE_ARENA_CENTER
			GameManager.preloaded_battle_arena_rotation = 0.0

	var party_inv: Dictionary = GameManager.party.grid_inventories if GameManager.party else {}
	var data: Dictionary = MissionLauncher.build_battle_data(_mission, encounter, party_inv)
	SceneManager.push_scene("res://scenes/battle/battle.tscn", data)


func _on_back_pressed() -> void:
	SceneManager.pop_scene()


func _run_forest_generator(bg: Node3D) -> void:
	if bg and bg.has_method("_generate_all"):
		bg._generate_all()
	_disable_picking_recursive(bg)


func _disable_picking_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		var co: CollisionObject3D = node
		co.input_ray_pickable = false
		co.collision_layer = 0
	for child in node.get_children():
		_disable_picking_recursive(child)
