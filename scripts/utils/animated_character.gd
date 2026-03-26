extends Node3D
## Animated 3D character — loads a rigged model and plays animations from a library.
## Used for player, NPCs, and enemies that have real 3D models with skeletal animation.

const UAL1_PATH := "res://assets/animations/Universal Animation Library[Standard]/Universal Animation Library[Standard]/Unreal-Godot/UAL1_Standard.glb"
const UAL2_PATH := "res://assets/animations/Universal Animation Library 2[Standard]/Universal Animation Library 2[Standard]/Unreal-Godot/UAL2_Standard.glb"

var _model: Node3D = null
var _anim_player: AnimationPlayer = null
var _skeleton: Skeleton3D = null
var _current_anim: String = ""
var _pending_model_path: String = ""
var _pending_scale: float = 1.0

## Map of logical animation names to UAL animation names
## Godot strips "_Loop" suffix from glTF animations and sets them to loop automatically.
const ANIM_MAP: Dictionary = {
	"idle": "Idle",
	"walk": "Walk",
	"run": "Jog_Fwd",
	"sprint": "Sprint",
	"jump_start": "Jump_Start",
	"jump_loop": "Jump",
	"jump_land": "Jump_Land",
	"attack_sword": "Sword_Attack",
	"attack_combo": "Sword_Regular_Combo",
	"block": "Sword_Block",
	"hit": "Hit_Chest",
	"hit_head": "Hit_Head",
	"hit_knockback": "Hit_Knockback",
	"death": "Death01",
	"spell_cast": "Spell_Simple_Shoot",
	"spell_idle": "Spell_Simple_Idle",
	"interact": "Interact",
	"dance": "Dance",
	"sit_idle": "Sitting_Idle",
	"talk": "Idle_Talking",
	"roll": "Roll",
	"crouch_idle": "Crouch_Idle",
	"crouch_walk": "Crouch_Fwd",
	"swim": "Swim_Fwd",
	"chest_open": "Chest_Open",
	"consume": "Consume",
}

## Cached animation libraries (shared across all instances)
static var _cached_libs: Dictionary = {}  # lib_name → AnimationLibrary


static func create(model_path: String, scale_factor: float = 1.0) -> Node3D:
	var instance: Node3D = Node3D.new()
	instance.set_script(load("res://scripts/utils/animated_character.gd"))
	instance.set("_pending_model_path", model_path)
	instance.set("_pending_scale", scale_factor)
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

	# Add a simple head if the model has no Head mesh (outfit-only models)
	if _skeleton and not _find_node_by_name(_model, "Head_Mesh"):
		var head_bone_idx: int = _skeleton.find_bone("Head")
		if head_bone_idx >= 0:
			var head_attach := BoneAttachment3D.new()
			head_attach.name = "HeadAttach"
			head_attach.bone_idx = head_bone_idx
			_skeleton.add_child(head_attach)
			var head_mesh := MeshInstance3D.new()
			head_mesh.name = "Head_Mesh"
			var sphere := SphereMesh.new()
			sphere.radius = 0.12
			sphere.height = 0.24
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.85, 0.7, 0.6)  # skin tone
			sphere.material = mat
			head_mesh.mesh = sphere
			head_mesh.position = Vector3(0, 0.06, 0)
			head_attach.add_child(head_mesh)

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
