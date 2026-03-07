class_name ModelAnimator
extends Node
## Procedural walk/idle animator for 3D character models.
## Attach as a child of the model's owner, then call setup(model).
## Auto-detects CSG humanoid vs voxel model and animates accordingly.
## Supports both 10-part (legacy) and 16-part (full skeleton) formats.

enum ModelType { CSG_HUMANOID, VOXEL, SLIME, UNKNOWN }

# --- Animation constants (inline — class_name scripts cannot use autoloads) ---
const WALK_CYCLE_SPEED: float = 8.0        ## Radians per second for leg swing
const LEG_SWING_ANGLE: float = 0.4         ## ~23 degrees max thigh/leg rotation
const ARM_SWING_ANGLE: float = 0.3         ## ~17 degrees max arm rotation
const IDLE_BOB_AMPLITUDE: float = 0.02     ## Subtle Y bob in world units
const IDLE_BOB_SPEED: float = 2.0          ## Radians per second for idle breathing
const IDLE_SWAY_ANGLE: float = 0.015       ## Very subtle Z-axis rotation
const VOX_BOB_AMPLITUDE: float = 0.04      ## Larger bob for voxel whole-body
const VOX_TILT_ANGLE: float = 0.05         ## Side-to-side tilt for voxel walking
const SLIME_SQUASH_AMOUNT: float = 0.15    ## Squash/stretch for slime
const SLIME_HOP_HEIGHT: float = 0.08       ## Slime hop amplitude
const BLEND_SPEED: float = 6.0             ## How fast to blend between walk/idle
const FOOT_TILT_ANGLE: float = 0.25        ## Foot tilt during walk cycle (stepping)
const KNEE_BEND_RATIO: float = 0.8         ## Calf swing as fraction of thigh swing
const ELBOW_BEND_RATIO: float = 0.7        ## Forearm swing as fraction of arm swing
const TORSO_TWIST_ANGLE: float = 0.05      ## Chest/belly twist during walk

var _model: Node3D = null
var _model_type: ModelType = ModelType.UNKNOWN
var _is_walking: bool = false
var _walk_phase: float = 0.0
var _idle_phase: float = 0.0
var _blend: float = 0.0  ## 0.0 = idle, 1.0 = walking

# Core limb references (10-part legacy or mapped from 16-part)
var _left_leg: Node3D = null   ## LeftLeg (10-part) or LeftThigh (16-part primary swing)
var _right_leg: Node3D = null  ## RightLeg (10-part) or RightThigh (16-part primary swing)
var _left_arm: Node3D = null
var _right_arm: Node3D = null

# Extended part references (16-part skeleton, null for 10-part models)
var _hip: Node3D = null
var _belly: Node3D = null
var _chest: Node3D = null
var _head: Node3D = null
var _left_thigh: Node3D = null
var _right_thigh: Node3D = null
var _left_calf: Node3D = null    ## LeftLeg node in 16-part (calf, below knee)
var _right_calf: Node3D = null   ## RightLeg node in 16-part (calf, below knee)
var _left_forearm: Node3D = null
var _right_forearm: Node3D = null

# Hands and feet (both formats)
var _left_hand: Node3D = null
var _right_hand: Node3D = null
var _left_foot: Node3D = null
var _right_foot: Node3D = null

# Original transforms for reset
var _original_model_y: float = 0.0
var _original_model_rotation_z: float = 0.0
var _original_scale: Vector3 = Vector3.ONE


func setup(model: Node3D) -> void:
	## Call after model is added to scene tree. Detects model type and caches refs.
	_model = model
	_model_type = _detect_model_type()

	if _model_type == ModelType.CSG_HUMANOID:
		# Try 16-part skeleton first (has Hip node)
		_hip = _find_part(_model, "Hip")
		if _hip:
			_setup_16_part()
		else:
			_setup_10_part()

	_original_model_y = _model.position.y
	_original_model_rotation_z = _model.rotation.z
	_original_scale = _model.scale


func _setup_16_part() -> void:
	## Cache all 16 part references for full skeleton.
	_belly = _find_part(_hip, "Belly")
	_chest = _find_part(_belly, "Chest") if _belly else _find_part(_hip, "Chest")
	var chest_or_model: Node3D = _chest if _chest else _model
	_head = _find_part(chest_or_model, "Head")

	# Arms → Forearms → Hands (attached to Chest)
	_left_arm = _find_part(chest_or_model, "LeftArm")
	_right_arm = _find_part(chest_or_model, "RightArm")
	if _left_arm:
		_left_forearm = _find_part(_left_arm, "LeftForearm")
		_left_hand = _find_part(_left_arm, "LeftHand")
	if _right_arm:
		_right_forearm = _find_part(_right_arm, "RightForearm")
		_right_hand = _find_part(_right_arm, "RightHand")

	# Thighs → Calves → Feet (attached to Hip)
	_left_thigh = _find_part(_hip, "LeftThigh")
	_right_thigh = _find_part(_hip, "RightThigh")
	if _left_thigh:
		_left_calf = _find_part(_left_thigh, "LeftLeg")
		_left_foot = _find_part(_left_thigh, "LeftFoot")
	if _right_thigh:
		_right_calf = _find_part(_right_thigh, "RightLeg")
		_right_foot = _find_part(_right_thigh, "RightFoot")

	# Map thighs as the primary leg swing targets
	_left_leg = _left_thigh
	_right_leg = _right_thigh


func _setup_10_part() -> void:
	## Cache 10-part references (legacy format).
	_left_leg = _find_part(_model, "LeftLeg")
	_right_leg = _find_part(_model, "RightLeg")
	_left_arm = _find_part(_model, "LeftArm")
	_right_arm = _find_part(_model, "RightArm")
	if _left_arm:
		_left_hand = _find_part(_left_arm, "LeftHand")
	if _right_arm:
		_right_hand = _find_part(_right_arm, "RightHand")
	if _left_leg:
		_left_foot = _find_part(_left_leg, "LeftFoot")
	if _right_leg:
		_right_foot = _find_part(_right_leg, "RightFoot")


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

	# Thigh/leg swing (rotate around X = forward/back)
	if _left_leg:
		_left_leg.rotation.x = walk_sin * LEG_SWING_ANGLE * _blend
	if _right_leg:
		_right_leg.rotation.x = -walk_sin * LEG_SWING_ANGLE * _blend

	# Calf bend at knee (lagging phase — 16-part only)
	# Negative rotation.x = calf swings backward behind thigh
	var knee_sin: float = sin(_walk_phase - 0.5)
	if _left_calf:
		_left_calf.rotation.x = -(0.15 + maxf(0.0, knee_sin) * KNEE_BEND_RATIO) * LEG_SWING_ANGLE * _blend
	if _right_calf:
		_right_calf.rotation.x = -(0.15 + maxf(0.0, -knee_sin) * KNEE_BEND_RATIO) * LEG_SWING_ANGLE * _blend

	# Arm swing (opposite to same-side leg)
	if _left_arm:
		_left_arm.rotation.x = -walk_sin * ARM_SWING_ANGLE * _blend
	if _right_arm:
		_right_arm.rotation.x = walk_sin * ARM_SWING_ANGLE * _blend

	# Forearm bend at elbow (16-part only)
	# Positive rotation.x = forearm curls forward toward chest
	var elbow_sin: float = sin(_walk_phase + 0.3)
	if _left_forearm:
		_left_forearm.rotation.x = (0.2 + maxf(0.0, -elbow_sin) * ELBOW_BEND_RATIO) * ARM_SWING_ANGLE * _blend
	if _right_forearm:
		_right_forearm.rotation.x = (0.2 + maxf(0.0, elbow_sin) * ELBOW_BEND_RATIO) * ARM_SWING_ANGLE * _blend

	# Foot tilt: natural stepping motion (phase-offset from legs)
	var foot_sin: float = sin(_walk_phase + 0.3)
	if _left_foot:
		_left_foot.rotation.x = foot_sin * FOOT_TILT_ANGLE * _blend
	if _right_foot:
		_right_foot.rotation.x = -foot_sin * FOOT_TILT_ANGLE * _blend

	# Torso twist during walk (16-part only — belly/chest counter-rotate)
	if _belly:
		_belly.rotation.y = walk_sin * TORSO_TWIST_ANGLE * _blend
	if _chest:
		_chest.rotation.y = -walk_sin * TORSO_TWIST_ANGLE * 0.5 * _blend

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


func _find_part(parent: Node3D, part_name: String) -> Node3D:
	## Find a named part as direct child first, then search descendants.
	var node: Node = parent.get_node_or_null(part_name)
	if not node:
		node = parent.find_child(part_name, true, false)
	if node is Node3D:
		return node as Node3D
	return null


func _detect_model_type() -> ModelType:
	if not _model:
		return ModelType.UNKNOWN

	# Check for slime
	if _model.name == "CSGSlime":
		return ModelType.SLIME

	# Check for articulated humanoid (16-part: has Hip; 10-part: has LeftLeg+RightLeg)
	if _find_part(_model, "Hip"):
		return ModelType.CSG_HUMANOID
	if _find_part(_model, "LeftLeg") and _find_part(_model, "RightLeg"):
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

	# Core limbs
	if _left_leg:
		_left_leg.rotation.x = 0.0
	if _right_leg:
		_right_leg.rotation.x = 0.0
	if _left_arm:
		_left_arm.rotation.x = 0.0
	if _right_arm:
		_right_arm.rotation.x = 0.0

	# Extended skeleton (16-part)
	if _left_calf:
		_left_calf.rotation.x = 0.0
	if _right_calf:
		_right_calf.rotation.x = 0.0
	if _left_forearm:
		_left_forearm.rotation.x = 0.0
	if _right_forearm:
		_right_forearm.rotation.x = 0.0
	if _belly:
		_belly.rotation.y = 0.0
	if _chest:
		_chest.rotation.y = 0.0

	# Hands and feet
	if _left_hand:
		_left_hand.rotation = Vector3.ZERO
	if _right_hand:
		_right_hand.rotation = Vector3.ZERO
	if _left_foot:
		_left_foot.rotation = Vector3.ZERO
	if _right_foot:
		_right_foot.rotation = Vector3.ZERO

	_blend = 0.0
	_walk_phase = 0.0
	_idle_phase = 0.0
