extends Camera3D
## Orthographic top-down camera that follows a target with smooth interpolation.
## Pitch is locked (no orbit). Scroll wheel zooms by changing orthographic size.
##
## Test/prototype script for the ortho overworld camera direction. Once the
## feel is dialled in, this can absorb pan + clamp-to-bounds and replace
## OrbitCamera in overworld/local_map scenes.

@export var follow_target_path: NodePath  ## Resolved at _ready into follow_target
@export_range(-89.0, -1.0) var pitch_degrees: float = -45.0
@export var distance: float = 80.0          ## Distance from target along the view ray
@export var ortho_size: float = 40.0        ## Initial vertical world units visible
@export var min_size: float = 10.0
@export var max_size: float = 120.0
@export var zoom_step: float = 1.15         ## Multiplier per wheel notch
@export var follow_smoothing: float = 10.0  ## Higher = snappier follow

var follow_target: Node3D
var _target_size: float


func _ready() -> void:
	projection = PROJECTION_ORTHOGONAL
	size = ortho_size
	_target_size = ortho_size
	near = 0.1
	far = 1000.0
	rotation_degrees = Vector3(pitch_degrees, 0.0, 0.0)
	if not follow_target_path.is_empty():
		follow_target = get_node_or_null(follow_target_path) as Node3D
	if follow_target:
		global_position = _compute_position()
	else:
		push_warning("TopDownCamera: follow_target_path %s did not resolve to a Node3D" % str(follow_target_path))


func set_follow_target(target: Node3D) -> void:
	follow_target = target
	if follow_target:
		global_position = _compute_position()


func _process(delta: float) -> void:
	if not follow_target:
		return
	var t: float = clamp(follow_smoothing * delta, 0.0, 1.0)
	# Keep rotation in sync with pitch_degrees so changing it in the Inspector
	# rotates the camera around the target instead of pivoting in place.
	rotation_degrees.x = lerp(rotation_degrees.x, pitch_degrees, t)
	rotation_degrees.y = 0.0
	rotation_degrees.z = 0.0
	global_position = global_position.lerp(_compute_position(), t)
	size = lerp(size, _target_size, t)


func _compute_position() -> Vector3:
	# Camera looks along -Z after rotation. With pitch_degrees rotation around X,
	# look direction in world = (0, sin(pitch_rad), -cos(pitch_rad)).
	# Camera position = target - look_dir * distance, so the camera sits behind/above the target.
	var pitch_rad: float = deg_to_rad(pitch_degrees)
	var look_dir: Vector3 = Vector3(0.0, sin(pitch_rad), -cos(pitch_rad))
	return follow_target.global_position - look_dir * distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_target_size = clamp(_target_size / zoom_step, min_size, max_size)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_target_size = clamp(_target_size * zoom_step, min_size, max_size)
			get_viewport().set_input_as_handled()
