@tool
extends Node3D
## @tool preview for editing battle camera angles.
## Move the CameraGizmo cone in the viewport to set the camera position.
## Move the LookTarget sphere to set where the camera looks.
## Use the preset dropdown to switch angles, Save to Config to persist.

@export_group("Preset")
@export_enum("Home", "Player Turn", "Attack", "Skill", "Item", "Defend", "Flee", "Victory", "Defeat") var active_preset: int = 0:
	set(value):
		active_preset = value
		_load_preset_values()
@export_range(20.0, 80.0) var fov: float = 40.0:
	set(value):
		fov = value
		if _camera:
			_camera.fov = fov
		_update_cone_from_fov()
@export var arena_rotation_y: float = 0.0:
	set(value):
		arena_rotation_y = value

@export_group("Config")
@export var camera_config: Resource:  # BattleCameraConfig
	set(value):
		camera_config = value
		_load_preset_values()
@export var save_to_config: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_save_preset_values()
@export var load_from_config: bool = false:
	set(_value):
		if Engine.is_editor_hint():
			_load_preset_values()

var _camera: Camera3D = null
var _cam_gizmo: Node3D = null  # Movable cone — position = camera position
var _look_target: Node3D = null  # Movable sphere — position = look target
var _cone_mesh: MeshInstance3D = null
var _line_mesh: MeshInstance3D = null
var _built: bool = false


func _ready() -> void:
	if Engine.is_editor_hint():
		# Find existing saved nodes or create new ones
		_cam_gizmo = get_node_or_null("CameraGizmo")
		_look_target = get_node_or_null("LookTarget")
		_camera = get_node_or_null("PreviewCamera") as Camera3D
		_build_preview()
		_load_preset_values()


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() or not _built:
		return
	# Continuously sync camera and cone to gizmo positions
	if _camera and _cam_gizmo and _look_target:
		_camera.global_position = _cam_gizmo.global_position
		_camera.look_at(_look_target.global_position)
		# Point the cone at the look target
		_cam_gizmo.look_at(_look_target.global_position)
		_update_line()


func _build_preview() -> void:
	if _built:
		return
	_built = true

	var scene_root: Node = get_tree().edited_scene_root if Engine.is_editor_hint() else self

	# Arena floor (only if not already present)
	if not get_node_or_null("ArenaFloor"):
		var floor_mesh := MeshInstance3D.new()
		floor_mesh.name = "ArenaFloor"
		var disc := CylinderMesh.new()
		disc.top_radius = 7.0
		disc.bottom_radius = 7.0
		disc.height = 0.05
		disc.radial_segments = 32
		floor_mesh.mesh = disc
		var floor_mat := StandardMaterial3D.new()
		floor_mat.albedo_color = Color(0.3, 0.5, 0.2)
		floor_mesh.material_override = floor_mat
		add_child(floor_mesh)

	# Active player marker (green, at origin)
	_add_box_marker(Vector3.ZERO, Color(0.2, 0.8, 0.3), "ACTIVE")

	# Other party members (blue, for reference)
	var other_players: Array[Vector3] = [
		Vector3(-1.0, 0, 1.0), Vector3(-0.5, 0, -1.0), Vector3(-2.0, 0, 0.5),
	]
	for i in range(other_players.size()):
		_add_box_marker(other_players[i], Color(0.2, 0.3, 0.5), "P%d" % (i + 1))

	# Enemy markers (red)
	var enemy_pos: Array[Vector3] = [
		Vector3(6.0, 0, 0.0), Vector3(7.0, 0, 1.0),
		Vector3(6.5, 0, -1.0), Vector3(8.0, 0, 0.5),
	]
	for i in range(enemy_pos.size()):
		_add_box_marker(enemy_pos[i], Color(0.8, 0.2, 0.2), "E%d" % i)

	# === Camera Gizmo — add visuals to existing or new node ===
	if not _cam_gizmo:
		_cam_gizmo = Node3D.new()
		_cam_gizmo.name = "CameraGizmo"
		_cam_gizmo.position = Vector3(-7, 4, 2.2)
		add_child(_cam_gizmo)
		_cam_gizmo.owner = scene_root

	# Add cone + label if not already present
	if _cam_gizmo.get_child_count() == 0:
		_cone_mesh = MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 0.4
		cone.height = 0.8
		cone.radial_segments = 8
		_cone_mesh.mesh = cone
		_cone_mesh.rotation_degrees.x = 90
		var cone_mat := StandardMaterial3D.new()
		cone_mat.albedo_color = Color(0.1, 0.8, 1.0, 0.8)
		cone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_cone_mesh.material_override = cone_mat
		_cam_gizmo.add_child(_cone_mesh)

		var cam_label := Label3D.new()
		cam_label.text = "CAMERA"
		cam_label.position.y = 0.8
		cam_label.font_size = 36
		cam_label.modulate = Color(0.1, 0.8, 1.0)
		cam_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cam_label.no_depth_test = true
		_cam_gizmo.add_child(cam_label)
	else:
		# Find existing cone mesh
		for i in range(_cam_gizmo.get_child_count()):
			if _cam_gizmo.get_child(i) is MeshInstance3D:
				_cone_mesh = _cam_gizmo.get_child(i) as MeshInstance3D
				break

	# === Look Target — add visuals to existing or new node ===
	if not _look_target:
		_look_target = Node3D.new()
		_look_target.name = "LookTarget"
		_look_target.position = Vector3(2, 0.6, -0.3)
		add_child(_look_target)
		_look_target.owner = scene_root

	if _look_target.get_child_count() == 0:
		var target_sphere := MeshInstance3D.new()
		var ts := SphereMesh.new()
		ts.radius = 0.3
		ts.height = 0.6
		target_sphere.mesh = ts
		var target_mat := StandardMaterial3D.new()
		target_mat.albedo_color = Color(1.0, 0.3, 0.1, 0.8)
		target_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		target_sphere.material_override = target_mat
		_look_target.add_child(target_sphere)

		var look_label := Label3D.new()
		look_label.text = "LOOK"
		look_label.position.y = 0.6
		look_label.font_size = 36
		look_label.modulate = Color(1.0, 0.3, 0.1)
		look_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		look_label.no_depth_test = true
		_look_target.add_child(look_label)

	# === Line between camera and target ===
	_line_mesh = get_node_or_null("CameraLine") as MeshInstance3D
	if not _line_mesh:
		_line_mesh = MeshInstance3D.new()
		_line_mesh.name = "CameraLine"
		var line_mat := StandardMaterial3D.new()
		line_mat.albedo_color = Color(1, 1, 1, 0.4)
		line_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		line_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_line_mesh.material_override = line_mat
		add_child(_line_mesh)

	# Camera (for Preview checkbox)
	if not _camera:
		_camera = Camera3D.new()
		_camera.name = "PreviewCamera"
		_camera.fov = fov
		add_child(_camera)

	# Light
	if not get_node_or_null("PreviewLight"):
		var light := DirectionalLight3D.new()
		light.name = "PreviewLight"
		light.rotation_degrees = Vector3(-45, 30, 0)
		light.light_energy = 1.0
		add_child(light)


func _add_box_marker(pos: Vector3, color: Color, label_text: String) -> void:
	var marker := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.4, 1.6, 0.4)
	marker.mesh = box
	marker.position = pos + Vector3(0, 0.8, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	marker.material_override = mat
	add_child(marker)

	var label := Label3D.new()
	label.text = label_text
	label.position = pos + Vector3(0, 2.0, 0)
	label.font_size = 28
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.modulate = color
	add_child(label)


func _update_line() -> void:
	if not _line_mesh or not _cam_gizmo or not _look_target:
		return
	var from: Vector3 = _cam_gizmo.position
	var to: Vector3 = _look_target.position
	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_LINES)
	im.surface_add_vertex(from)
	im.surface_add_vertex(to)
	im.surface_end()
	_line_mesh.mesh = im


func _update_cone_from_fov() -> void:
	if _cone_mesh and _cone_mesh.mesh is CylinderMesh:
		var cone: CylinderMesh = _cone_mesh.mesh as CylinderMesh
		cone.bottom_radius = tan(deg_to_rad(fov * 0.5)) * 0.8


func _get_preset_name() -> String:
	var names: Array[String] = ["home", "player_turn", "attack", "skill", "item", "defend", "flee", "victory", "defeat"]
	if active_preset >= 0 and active_preset < names.size():
		return names[active_preset]
	return "home"


func _load_preset_values() -> void:
	if not camera_config:
		return
	var preset_name: String = _get_preset_name()
	var preset: Resource = camera_config.get(preset_name)
	if not preset:
		return
	if _cam_gizmo:
		_cam_gizmo.position = preset.position_offset
	if _look_target:
		_look_target.position = preset.look_offset
	fov = preset.fov
	print("[CameraPreview] Loaded preset '%s'" % preset_name)


func _save_preset_values() -> void:
	if not camera_config:
		print("[CameraPreview] No config assigned!")
		return
	var preset_name: String = _get_preset_name()
	var preset: Resource = camera_config.get(preset_name)
	if not preset:
		print("[CameraPreview] Preset '%s' not found!" % preset_name)
		return
	if _cam_gizmo:
		preset.position_offset = _cam_gizmo.position
	if _look_target:
		preset.look_offset = _look_target.position
	preset.fov = fov
	if not camera_config.resource_path.is_empty():
		ResourceSaver.save(camera_config, camera_config.resource_path)
	print("[CameraPreview] Saved preset '%s'" % preset_name)
