class_name ModelAnimator
extends Node
## Procedural walk/idle animator for 3D character models.
## Attach as a child of the model's owner, then call setup(model).
## Auto-detects CSG humanoid vs voxel model and animates accordingly.

enum ModelType { CSG_HUMANOID, VOXEL, SLIME, UNKNOWN }

# --- Animation constants (inline — class_name scripts cannot use autoloads) ---
const WALK_CYCLE_SPEED: float = 8.0        ## Radians per second for leg swing
const LEG_SWING_ANGLE: float = 0.4         ## ~23 degrees max leg rotation
const ARM_SWING_ANGLE: float = 0.3         ## ~17 degrees max arm rotation
const IDLE_BOB_AMPLITUDE: float = 0.02     ## Subtle Y bob in world units
const IDLE_BOB_SPEED: float = 2.0          ## Radians per second for idle breathing
const IDLE_SWAY_ANGLE: float = 0.015       ## Very subtle Z-axis rotation
const VOX_BOB_AMPLITUDE: float = 0.04      ## Larger bob for voxel whole-body
const VOX_TILT_ANGLE: float = 0.05         ## Side-to-side tilt for voxel walking
const SLIME_SQUASH_AMOUNT: float = 0.15    ## Squash/stretch for slime
const SLIME_HOP_HEIGHT: float = 0.08       ## Slime hop amplitude
const BLEND_SPEED: float = 6.0             ## How fast to blend between walk/idle

var _model: Node3D = null
var _model_type: ModelType = ModelType.UNKNOWN
var _is_walking: bool = false
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _blend: float = 0.0  ## 0.0 = idle, 1.0 = walking

# CSG limb references (null for non-CSG models)
var _left_leg: Node3D = null
var _right_leg: Node3D = null
var _left_arm: Node3D = null
var _right_arm: Node3D = null

# Original transforms for reset
var _original_model_y: float = 0.0
var _original_model_rotation_z: float = 0.0
var _original_scale: Vector3 = Vector3.ONE


func setup(model: Node3D) -> void:
	## Call after model is added to scene tree. Detects model type and caches refs.
	_model = model
	_model_type = _detect_model_type()

	if _model_type == ModelType.CSG_HUMANOID:
		_left_leg = _model.get_node_or_null("LeftLeg")
		_right_leg = _model.get_node_or_null("RightLeg")
		_left_arm = _model.get_node_or_null("LeftArm")
		_right_arm = _model.get_node_or_null("RightArm")

	_original_model_y = _model.position.y
	_original_model_rotation_z = _model.rotation.z
	_original_scale = _model.scale


func set_walking(walking: bool) -> void:
	## Call each frame to indicate whether the character is moving.
	_is_walking = walking


func _process(delta: float) -> void:
	if not _model or not is_instance_valid(_model):
		return

	# Smooth blend between idle (0) and walk (1)
	var target_blend: float = 1.0 if _is_walking else 0.0
	_blend = move_toward(_blend, target_blend, BLEND_SPEED * delta)

	# Advance phases
	if _blend > 0.01:
		_walk_phase += WALK_CYCLE_SPEED * delta
	_idle_phase += IDLE_BOB_SPEED * delta

	match _model_type:
		ModelType.CSG_HUMANOID:
			_animate_csg()
		ModelType.VOXEL:
			_animate_voxel()
		ModelType.SLIME:
			_animate_slime()


func _animate_csg() -> void:
	var walk_sin: float = sin(_walk_phase)
	var idle_sin: float = sin(_idle_phase)

	# Leg swing (rotate around X = forward/back)
	if _left_leg:
		_left_leg.rotation.x = walk_sin * LEG_SWING_ANGLE * _blend
	if _right_leg:
		_right_leg.rotation.x = -walk_sin * LEG_SWING_ANGLE * _blend

	# Arm swing (opposite to same-side leg)
	if _left_arm:
		_left_arm.rotation.x = -walk_sin * ARM_SWING_ANGLE * _blend
	if _right_arm:
		_right_arm.rotation.x = walk_sin * ARM_SWING_ANGLE * _blend

	# Body bob: walk bounce at 2x freq + idle breathing
	var walk_bob: float = abs(sin(_walk_phase * 2.0)) * 0.03 * _blend
	var idle_bob: float = idle_sin * IDLE_BOB_AMPLITUDE * (1.0 - _blend)
	_model.position.y = _original_model_y + walk_bob + idle_bob

	# Body sway (idle only)
	_model.rotation.z = _original_model_rotation_z + idle_sin * IDLE_SWAY_ANGLE * (1.0 - _blend)


func _animate_voxel() -> void:
	var walk_sin: float = sin(_walk_phase)
	var idle_sin: float = sin(_idle_phase)

	# Walk: bounce + side tilt (waddle)
	var walk_bob: float = abs(sin(_walk_phase * 2.0)) * VOX_BOB_AMPLITUDE * _blend
	var walk_tilt: float = walk_sin * VOX_TILT_ANGLE * _blend

	# Idle: gentle breathing bob + sway
	var idle_bob: float = idle_sin * IDLE_BOB_AMPLITUDE * (1.0 - _blend)
	var idle_sway: float = idle_sin * IDLE_SWAY_ANGLE * (1.0 - _blend)

	_model.position.y = _original_model_y + walk_bob + idle_bob
	_model.rotation.z = _original_model_rotation_z + walk_tilt + idle_sway


func _animate_slime() -> void:
	var idle_sin: float = sin(_idle_phase)

	# Idle: gentle squash/stretch breathing
	var idle_squash: float = idle_sin * SLIME_SQUASH_AMOUNT * 0.3 * (1.0 - _blend)

	# Walk: hopping + squash/stretch
	var hop: float = maxf(0.0, sin(_walk_phase * 2.0)) * SLIME_HOP_HEIGHT * _blend
	var walk_squash: float = sin(_walk_phase * 2.0) * SLIME_SQUASH_AMOUNT * _blend

	_model.position.y = _original_model_y + hop
	_model.scale.y = _original_scale.y * (1.0 - walk_squash - idle_squash)
	_model.scale.x = _original_scale.x * (1.0 + (walk_squash + idle_squash) * 0.5)
	_model.scale.z = _original_scale.z * (1.0 + (walk_squash + idle_squash) * 0.5)


func _detect_model_type() -> ModelType:
	if not _model:
		return ModelType.UNKNOWN

	# Check for slime
	if _model.name == "CSGSlime":
		return ModelType.SLIME

	# Check for CSG humanoid (has LeftLeg and RightLeg)
	if _model.get_node_or_null("LeftLeg") and _model.get_node_or_null("RightLeg"):
		return ModelType.CSG_HUMANOID

	# Check for voxel model
	if _model.name == "VoxModel":
		return ModelType.VOXEL
	var mesh_child: Node = _model.get_node_or_null("Mesh")
	if mesh_child and mesh_child is MeshInstance3D:
		return ModelType.VOXEL

	# Fallback: whole-body animation
	return ModelType.VOXEL


func reset_pose() -> void:
	## Resets the model to its neutral pose.
	if not _model or not is_instance_valid(_model):
		return

	_model.position.y = _original_model_y
	_model.rotation.z = _original_model_rotation_z
	_model.scale = _original_scale

	if _left_leg:
		_left_leg.rotation.x = 0.0
	if _right_leg:
		_right_leg.rotation.x = 0.0
	if _left_arm:
		_left_arm.rotation.x = 0.0
	if _right_arm:
		_right_arm.rotation.x = 0.0

	_blend = 0.0
	_walk_phase = 0.0
	_idle_phase = 0.0
