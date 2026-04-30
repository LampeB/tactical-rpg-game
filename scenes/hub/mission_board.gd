extends Control
## Mission Board — lists available missions; click one to launch a battle
## with a randomly-generated encounter scaled by the mission's parameters.
## MVP: no filtering by chapter / unlock conditions yet, all missions shown.

const MISSIONS_DIR := "res://data/missions/"
## Path to the rich generator scene used as the battle background.
## (Map id + arena center live in MissionLauncher so they stay testable.)
const BATTLE_SCENE_PATH := "res://scenes/maps/forest_clearing.tscn"

@onready var _mission_list: VBoxContainer = $VBox/Scroll/MissionList
@onready var _back_button: Button = $VBox/BackButton


func _ready() -> void:
	_back_button.pressed.connect(_on_back_pressed)
	_populate_missions()


func _populate_missions() -> void:
	for child in _mission_list.get_children():
		child.queue_free()

	var missions: Array[MissionData] = _load_all_missions()
	missions.sort_custom(func(a: MissionData, b: MissionData) -> bool: return a.recommended_level < b.recommended_level)

	if missions.is_empty():
		var label := Label.new()
		label.text = "No missions available."
		_mission_list.add_child(label)
		return

	for mission in missions:
		_mission_list.add_child(_build_mission_button(mission))


func _build_mission_button(mission: MissionData) -> Button:
	var button := Button.new()
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.custom_minimum_size = Vector2(0, 96)
	button.add_theme_font_size_override("font_size", 16)
	button.text = "%s    [Lv %d  %d-%d enemies]\n  Reward: %d gold, %d xp\n  %s" % [
		mission.display_name,
		mission.recommended_level,
		mission.enemy_count_min,
		mission.enemy_count_max,
		mission.gold_reward,
		mission.xp_reward,
		mission.summary,
	]
	button.pressed.connect(_on_mission_selected.bind(mission))
	return button


func _on_mission_selected(mission: MissionData) -> void:
	var encounter: EncounterData = RandomEncounterGenerator.generate(
		mission.enemy_count_min,
		mission.enemy_count_max,
		mission.display_name,
		mission.gold_reward,
	)
	if not encounter:
		push_error("[MissionBoard] Failed to generate random encounter for mission %s" % mission.id)
		return

	# Load the rich forest_clearing.tscn and run its @tool generator at runtime
	# so trees/water/props are built fresh each battle (no need to save baked).
	if ResourceLoader.exists(BATTLE_SCENE_PATH):
		var scene: PackedScene = load(BATTLE_SCENE_PATH) as PackedScene
		if scene:
			var bg: Node3D = scene.instantiate() as Node3D
			# Generator's _generate_all() needs the node in tree (to add_child for
			# spawned props). Battle adds the bg to its viewport, then we run gen.
			bg.tree_entered.connect(_run_forest_generator.bind(bg), CONNECT_ONE_SHOT)
			GameManager.preloaded_battle_bg = bg
			GameManager.preloaded_battle_arena_center = MissionLauncher.BATTLE_ARENA_CENTER
			GameManager.preloaded_battle_arena_rotation = 0.0
		else:
			push_warning("[MissionBoard] Failed to load %s as PackedScene" % BATTLE_SCENE_PATH)
	else:
		push_warning("[MissionBoard] Battle scene not found at %s" % BATTLE_SCENE_PATH)

	# Build the data dict via the helper so the structure is unit-testable.
	# Battle reads grid_inventories from the scene data, NOT from GameManager.party
	# directly. Without this, equipped weapons are missing during the fight.
	var party_inv: Dictionary = GameManager.party.grid_inventories if GameManager.party else {}
	var data: Dictionary = MissionLauncher.build_battle_data(mission, encounter, party_inv)
	SceneManager.push_scene("res://scenes/battle/battle.tscn", data)


func _on_back_pressed() -> void:
	SceneManager.pop_scene()


func _run_forest_generator(bg: Node3D) -> void:
	## Run the ForestClearingGenerator's full generation pass once the scene
	## is in tree. The function is conventionally private (`_` prefix) but
	## GDScript doesn't enforce that and it's the canonical entry point.
	if bg and bg.has_method("_generate_all"):
		bg._generate_all()
	# Disable mouse picking on every collider in the battle background.
	# Otherwise terrain chunks and prop colliders intercept clicks before they
	# reach the enemy sprite Area3Ds inside the battle SubViewport.
	_disable_picking_recursive(bg)


func _disable_picking_recursive(node: Node) -> void:
	if node is CollisionObject3D:
		var co: CollisionObject3D = node
		co.input_ray_pickable = false
		co.collision_layer = 0
	for child in node.get_children():
		_disable_picking_recursive(child)


func _load_all_missions() -> Array[MissionData]:
	var result: Array[MissionData] = []
	var dir := DirAccess.open(MISSIONS_DIR)
	if not dir:
		push_error("[MissionBoard] Cannot open %s" % MISSIONS_DIR)
		return result
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var resource: Resource = load(MISSIONS_DIR + file_name)
			if resource is MissionData:
				result.append(resource)
		file_name = dir.get_next()
	dir.list_dir_end()
	return result
