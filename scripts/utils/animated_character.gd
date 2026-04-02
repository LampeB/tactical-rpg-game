extends Node3D
## Animated 3D character — loads a rigged model and plays animations from a library.
## Used for player, NPCs, and enemies that have real 3D models with skeletal animation.

const UAL1_PATH := AssetPaths.UAL1
const UAL2_PATH := AssetPaths.UAL2

var _model: Node3D = null
var _anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _current_anim: String = ""
var _pending_model_path: String = ""
var _pending_scale: float = 1.0
var _pending_head_path: String = ""

## Map of logical animation names to UAL animation names
## Godot strips "_Loop" suffix from glTF animations and sets them to loop automatically.
const ANIM_MAP: Dictionary = {
	# --- Movement ---
	"idle": "Idle",
	"idle_tired": "Idle_Tired",
	"idle_look": "Idle_LookAround",
	"walk": "Walk",
	"walk_back": "Walk_Bwd",
	"walk_carry": "Walk_Carry",
	"walk_formal": "Walk_Formal",
	"run": "Jog_Fwd",
	"sprint": "Sprint",
	"sprint_enter": "Sprint_Enter",
	"sprint_exit": "Sprint_Exit",
	"crouch_idle": "Crouch_Idle",
	"crouch_walk": "Crouch_Fwd",
	"crouch_enter": "Crouch_Enter",
	"crouch_exit": "Crouch_Exit",
	"crawl": "Crawl_Fwd",
	"crawl_idle": "Crawl_Idle",
	"swim": "Swim_Fwd",
	"swim_idle": "Swim_Idle",
	# --- Jumping ---
	"jump_start": "Jump_Start",
	"jump_loop": "Jump",
	"jump_land": "Jump_Land",
	"double_jump": "DoubleJump",
	"backflip": "BackFlip",
	"roll": "Roll",
	"dodge_left": "Dodge_Left",
	"dodge_right": "Dodge_Right",
	"slide": "Slide",
	"slide_start": "Slide_Start",
	"slide_exit": "Slide_Exit",
	# --- Climbing ---
	"climb_up": "Climb_Up",
	"climb_down": "Climb_Down",
	"climb_idle": "Climb_Idle",
	"climb_enter": "Climb_Enter",
	"climb_exit": "Climb_Exit",
	"climb_ledge": "ClimbLedge",
	# --- Sword combat ---
	"attack_sword": "Sword_Attack",
	"attack_sword_standing": "Sword_Attack_Standing",
	"sword_enter": "Sword_Enter",
	"sword_exit": "Sword_Exit",
	"sword_idle": "Sword_Idle",
	"sword_light_a": "Sword_Light_A",
	"sword_light_b": "Sword_Light_B",
	"sword_light_c": "Sword_Light_C",
	"sword_light_combo": "Sword_Light_Combo",
	"sword_heavy_a": "Sword_Heavy_A",
	"sword_heavy_b": "Sword_Heavy_B",
	"sword_heavy_c": "Sword_Heavy_C",
	"sword_heavy_combo": "Sword_Heavy_Combo",
	"sword_regular_a": "Sword_Regular_A",
	"sword_regular_b": "Sword_Regular_B",
	"sword_regular_c": "Sword_Regular_C",
	"sword_regular_combo": "Sword_Regular_Combo",
	"sword_block": "Sword_Block",
	"sword_aerial_a": "Sword_Aerial_A",
	"sword_aerial_b": "Sword_Aerial_B",
	"sword_ground_pound": "Sword_GroundPound_RM",
	"sword_uppercut": "Sword_UpperCut_RM",
	# --- Bow combat ---
	"bow_aim": "Bow_Aim_Neutral",
	"bow_aim_up": "Bow_Aim_Up",
	"bow_aim_down": "Bow_Aim_Down",
	"bow_shoot": "Bow_Shoot",
	"bow_notch": "Bow_Notch",
	"bow_rapid": "Bow_RapidShoot",
	# --- Shield ---
	"shield_idle": "Idle_Shield",
	"shield_break": "Idle_Shield_Break",
	"shield_dash": "Shield_Dash_RM",
	"shield_block": "Shield_OneShot",
	"sprint_shield": "Sprint_Shield",
	# --- Melee (unarmed) ---
	"punch_jab": "Punch_Jab",
	"punch_cross": "Punch_Cross",
	"kick": "Kick",
	"melee_combo": "Melee_Combo",
	"melee_hook": "Melee_Hook",
	"melee_knee": "Melee_Knee",
	"melee_uppercut": "Melee_Uppercut",
	# --- Magic ---
	"spell_cast": "Spell_Simple_Shoot",
	"spell_idle": "Spell_Simple_Idle",
	"spell_enter": "Spell_Simple_Enter",
	"spell_exit": "Spell_Simple_Exit",
	"spell_double": "Spell_Double_Shoot",
	"spell_double_idle": "Spell_Double_Idle",
	# --- Hit/Death ---
	"hit": "Hit_Chest",
	"hit_head": "Hit_Head",
	"hit_stomach": "Hit_Stomach",
	"hit_shoulder_l": "Hit_Shoulder_L",
	"hit_shoulder_r": "Hit_Shoulder_R",
	"hit_knockback": "Hit_Knockback",
	"death": "Death01",
	"death2": "Death02",
	# --- Social/NPC ---
	"interact": "Interact",
	"dance": "Dance",
	"talk": "Idle_Talking",
	"sit_idle": "Sitting_Idle",
	"sit_enter": "Sitting_Enter",
	"sit_exit": "Sitting_Exit",
	"sit_talk": "Sitting_Talking",
	"sit_nod": "Sitting_Nodding",
	"ground_sit": "GroundSit_Idle",
	"crying": "Crying",
	"celebrate": "Celebration",
	"surprise": "Surprise",
	"yes": "Yes",
	"idle_no": "Idle_No",
	"fold_arms": "Idle_FoldArms",
	"torch": "Idle_Torch",
	"lantern": "Idle_Lantern",
	"drink": "Drink",
	# --- Utility ---
	"chest_open": "Chest_Open",
	"consume": "Consume",
	"pickup": "PickUp_Kneeling",
	"pickup_table": "PickUp_Table",
	"push": "Push",
	"throw": "OverhandThrow",
	# --- Work ---
	"mining": "Mining",
	"chopping": "TreeChopping",
	"farm_harvest": "Farm_Harvest",
	"farm_plant": "Farm_PlantSeed",
	"farm_water": "Farm_Watering",
	"farm_scatter": "Farm_ScatteringSeeds",
	"farm_picking": "Farm_PickingTree",
	"fishing_cast": "Fish_Cast",
	"fishing_idle": "Fish_Cast_Idle",
	"fishing_reel": "Fish_Reel",
	"bandage": "Bandage",
	"fixing": "Fixing_Kneeling",
	# --- Counter/Shop ---
	"counter_idle": "Counter_Idle",
	"counter_enter": "Counter_Enter",
	"counter_exit": "Counter_Exit",
	"counter_give": "Counter_Give",
	"counter_show": "Counter_Show",
}

## Cached animation libraries (shared across all instances)
static var _cached_libs: Dictionary = {}  # lib_name → AnimationLibrary


static func create(model_path: String, scale_factor: float = 1.0, head_path: String = "") -> Node3D:
	var instance: Node3D = Node3D.new()
	instance.set_script(load("res://scripts/utils/animated_character.gd"))
	instance.set("_pending_model_path", model_path)
	instance.set("_pending_scale", scale_factor)
	instance.set("_pending_head_path", head_path)
	return instance


func _ready() -> void:
	# Setup can be called either from _ready (via create()) or directly by the caller
	if not _pending_model_path.is_empty() and _model == null:
		_setup(_pending_model_path, _pending_scale)


func _setup(model_path: String, scale_factor: float) -> void:
	if not ResourceLoader.exists(model_path):
		push_error("[AnimatedCharacter] Model not found: %s" % model_path)
		return

	var scene: PackedScene = load(model_path) as PackedScene
	if not scene:
		push_error("[AnimatedCharacter] Failed to load: %s" % model_path)
		return

	_model = scene.instantiate() as Node3D
	if not _model:
		push_error("[AnimatedCharacter] Not a Node3D: %s" % model_path)
		return

	_model.scale = Vector3.ONE * scale_factor
	add_child(_model)

	# Find the skeleton
	_skeleton = _find_node_of_type(_model, "Skeleton3D") as Skeleton3D
	if _skeleton:
		print("[AnimatedCharacter] Skeleton found: %d bones" % _skeleton.get_bone_count())

	# Find existing AnimationPlayer or create one
	_anim_player = _find_node_of_type(_model, "AnimationPlayer") as AnimationPlayer
	if not _anim_player:
		_anim_player = AnimationPlayer.new()
		_anim_player.name = "AnimationPlayer"
		_model.add_child(_anim_player)
	# Set root_node to the model root so UAL track paths like
	# "Armature/Skeleton3D:bone" resolve correctly
	_anim_player.root_node = _anim_player.get_path_to(_model)

	# Load UAL animation libraries (cached across instances)
	_load_animation_library(UAL1_PATH, "ual1")
	_load_animation_library(UAL2_PATH, "ual2")

	# List available animations for debugging
	var libs: Array = _anim_player.get_animation_library_list()
	var total: int = 0
	for i in range(libs.size()):
		var lib: AnimationLibrary = _anim_player.get_animation_library(libs[i])
		total += lib.get_animation_list().size()
	print("[AnimatedCharacter] %d animations loaded across %d libraries" % [total, libs.size()])

	# Debug: check animation player setup
	print("[AnimatedCharacter] AnimationPlayer root_node: '%s'" % _anim_player.root_node)
	print("[AnimatedCharacter] AnimationPlayer is inside tree: %s" % _anim_player.is_inside_tree())
	var test_full: String = _find_animation("Idle")
	print("[AnimatedCharacter] _find_animation('Idle') = '%s'" % test_full)
	if not test_full.is_empty():
		var test_anim: Animation = _anim_player.get_animation(test_full)
		if test_anim:
			print("[AnimatedCharacter] Idle: %d tracks" % test_anim.get_track_count())
			for ti in range(mini(test_anim.get_track_count(), 5)):
				print("[AnimatedCharacter]   Track %d: path='%s'" % [ti, test_anim.track_get_path(ti)])
	else:
		# List what animations ARE available
		var dbg_libs: Array = _anim_player.get_animation_library_list()
		for di in range(dbg_libs.size()):
			var dbg_lib: AnimationLibrary = _anim_player.get_animation_library(dbg_libs[di])
			var names: PackedStringArray = dbg_lib.get_animation_list()
			print("[AnimatedCharacter] Library '%s': %s" % [dbg_libs[di], ", ".join(names.slice(0, 5))])
	print("[AnimatedCharacter] Model tree:")
	_print_tree_debug(_model, 0, 3)

	# Attach base character head if outfit model has no head mesh
	if _skeleton and _pending_head_path and not _pending_head_path.is_empty():
		_attach_head(_pending_head_path)

	# Start idle
	play("idle")


func _load_animation_library(glb_path: String, lib_name: String) -> void:
	if not ResourceLoader.exists(glb_path):
		push_warning("[AnimatedCharacter] Animation library not found: %s" % glb_path)
		return

	# Use cached library if available
	if _cached_libs.has(lib_name):
		_anim_player.add_animation_library(lib_name, _cached_libs[lib_name])
		return

	var anim_scene: PackedScene = load(glb_path) as PackedScene
	if not anim_scene:
		return

	# Instantiate temporarily to extract animations
	var temp: Node = anim_scene.instantiate()
	var temp_anim: AnimationPlayer = _find_node_of_type(temp, "AnimationPlayer") as AnimationPlayer
	if not temp_anim:
		temp.free()
		return

	var lib := AnimationLibrary.new()
	var anim_list: PackedStringArray = temp_anim.get_animation_list()
	for i in range(anim_list.size()):
		var anim_name: String = anim_list[i]
		var anim: Animation = temp_anim.get_animation(anim_name)
		if anim:
			# Duplicate and fix bone track paths to match our model's skeleton
			var duped: Animation = anim.duplicate()
			lib.add_animation(anim_name, duped)

	temp.free()

	# Cache for future instances
	_cached_libs[lib_name] = lib
	_anim_player.add_animation_library(lib_name, lib)
	print("[AnimatedCharacter] Loaded %d animations from %s" % [anim_list.size(), lib_name])


func play(logical_name: String, blend: float = 0.2) -> void:
	if not _anim_player:
		return
	var anim_name: String = ANIM_MAP.get(logical_name, logical_name)
	if _current_anim == anim_name:
		return

	var full_name: String = _find_animation(anim_name)
	if full_name.is_empty():
		return

	_anim_player.play(full_name, blend)
	_current_anim = anim_name


func _find_animation(anim_name: String) -> String:
	if _anim_player.has_animation(anim_name):
		return anim_name
	var libs: Array = _anim_player.get_animation_library_list()
	for i in range(libs.size()):
		var lib_name: String = libs[i]
		var lib: AnimationLibrary = _anim_player.get_animation_library(lib_name)
		if lib and lib.has_animation(anim_name):
			if lib_name.is_empty():
				return anim_name
			return lib_name + "/" + anim_name
	return ""


func is_playing() -> bool:
	return _anim_player and _anim_player.is_playing()


func get_skeleton() -> Skeleton3D:
	return _skeleton


func get_anim_player() -> AnimationPlayer:
	return _anim_player


func _print_tree_debug(node: Node, depth: int, max_depth: int) -> void:
	if depth >= max_depth:
		return
	var indent: String = "  ".repeat(depth + 1)
	print("[AnimatedCharacter] %s%s (%s)" % [indent, node.name, node.get_class()])
	for i in range(node.get_child_count()):
		_print_tree_debug(node.get_child(i), depth + 1, max_depth)


func _attach_head(head_path: String) -> void:
	## Loads a head-only model (.gltf) and merges its meshes onto this skeleton.
	## The head model must share the same skeleton structure (bone names/hierarchy).
	if not ResourceLoader.exists(head_path):
		push_warning("[AnimatedCharacter] Head model not found: %s" % head_path)
		return
	var head_scene: PackedScene = load(head_path) as PackedScene
	if not head_scene:
		return
	var head_instance: Node3D = head_scene.instantiate() as Node3D
	if not head_instance:
		return
	# Find all MeshInstance3D nodes in the head model and reparent them to our skeleton
	var meshes: Array = []
	_collect_meshes(head_instance, meshes)
	for i in range(meshes.size()):
		var mesh_inst: MeshInstance3D = meshes[i]
		mesh_inst.owner = null
		mesh_inst.get_parent().remove_child(mesh_inst)
		_skeleton.add_child(mesh_inst)
		mesh_inst.skeleton = mesh_inst.get_path_to(_skeleton)
	head_instance.free()
	print("[AnimatedCharacter] Attached head from %s (%d meshes)" % [head_path, meshes.size()])


func _collect_meshes(node: Node, result: Array) -> void:
	if node is MeshInstance3D:
		result.append(node)
	for i in range(node.get_child_count()):
		_collect_meshes(node.get_child(i), result)


func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for i in range(node.get_child_count()):
		var found: Node = _find_node_by_name(node.get_child(i), node_name)
		if found:
			return found
	return null


func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name:
		return node
	for i in range(node.get_child_count()):
		var found: Node = _find_node_of_type(node.get_child(i), type_name)
		if found:
			return found
	return null
