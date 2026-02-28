class_name OrbitCamera
extends Node3D
## Free-rotating orbit camera with smooth follow, zoom, and pan.
## Hierarchy: OrbitCamera (pivot, yaw) -> PitchNode (pitch) -> Camera3D (distance offset)

@export var follow_target: Node3D
@export var initial_yaw: float = Constants.CAMERA_DEFAULT_YAW
@export var initial_pitch: float = Constants.CAMERA_DEFAULT_PITCH
@export var initial_distance: float = Constants.CAMERA_DEFAULT_DISTANCE

var _yaw: float
var _pitch: float
var _distance: float
var _target_yaw: float
var _target_pitch: float
var _target_distance: float
var _is_orbiting: bool = false
var _is_panning: bool = false

@onready var _pitch_node: Node3D = $PitchNode
@onready var _camera: Camera3D = $PitchNode/Camera3D


func _ready() -> void:
	_yaw = initial_yaw
	_pitch = initial_pitch
	_distance = initial_distance
	_target_yaw = _yaw
	_target_pitch = _pitch
	_target_distance = _distance
	_apply_transform()


func _unhandled_input(event: InputEvent) -> void:
	# Orbit (right-click drag)
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_is_orbiting = event.pressed
		elif event.button_index == MOUSE_BUTTON_MIDDLE:
			_is_panning = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_distance = clampf(
				_target_distance - Constants.CAMERA_ZOOM_SPEED,
				Constants.CAMERA_MIN_DISTANCE,
				Constants.CAMERA_MAX_DISTANCE
			)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_distance = clampf(
				_target_distance + Constants.CAMERA_ZOOM_SPEED,
				Constants.CAMERA_MIN_DISTANCE,
				Constants.CAMERA_MAX_DISTANCE
			)

	if event is InputEventMouseMotion:
		if _is_orbiting:
			_target_yaw -= event.relative.x * Constants.CAMERA_ORBIT_SPEED
			_target_pitch -= event.relative.y * Constants.CAMERA_ORBIT_SPEED
			_target_pitch = clampf(
				_target_pitch,
				Constants.CAMERA_PITCH_MIN,
				Constants.CAMERA_PITCH_MAX
			)
		elif _is_panning:
			var cam_right := _camera.global_transform.basis.x
			var cam_forward := _camera.global_transform.basis.z
			# Project to XZ plane for panning
			cam_right.y = 0.0
			cam_forward.y = 0.0
			cam_right = cam_right.normalized()
			cam_forward = cam_forward.normalized()
			var pan_speed := _distance * 0.002
			global_position += cam_right * -event.relative.x * pan_speed
			global_position += cam_forward * event.relative.y * pan_speed


func _physics_process(delta: float) -> void:
	var weight := Constants.CAMERA_SMOOTH_WEIGHT * delta

	# Smooth follow target
	if follow_target and is_instance_valid(follow_target):
		global_position = global_position.lerp(follow_target.global_position, weight)

	# Smooth orbit values
	_yaw = lerp(_yaw, _target_yaw, weight)
	_pitch = lerp(_pitch, _target_pitch, weight)
	_distance = lerp(_distance, _target_distance, weight)

	_apply_transform()


func _apply_transform() -> void:
	rotation_degrees.y = _yaw
	if _pitch_node:
		_pitch_node.rotation_degrees.x = _pitch
	if _camera:
		_camera.position.z = _distance


## Set the follow target (e.g., the player character).
func set_follow_target(target: Node3D) -> void:
	follow_target = target
	if target:
		global_position = target.global_position


## Snap to a specific orientation without smoothing.
func reset_orientation() -> void:
	_yaw = initial_yaw
	_pitch = initial_pitch
	_distance = initial_distance
	_target_yaw = _yaw
	_target_pitch = _pitch
	_target_distance = _distance
	_apply_transform()


## Set a fixed camera angle (useful for battle scenes).
func set_fixed_mode(yaw: float, pitch: float, distance: float) -> void:
	_target_yaw = yaw
	_target_pitch = pitch
	_target_distance = distance
