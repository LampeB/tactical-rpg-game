@tool
class_name WallPath3D
extends Path3D
## Invisible wall drawn as a Path3D curve in the editor.
## Place in the overworld scene, add control points along the desired barrier line.
## The player is blocked from crossing this line at runtime (unless unlocked).
## In the editor, colored vertical panels show where the wall is.

## Wall type — determines the unlock flag and editor color.
## 1=Mountain, 2=Water, 3=Gate, 4=Barrier, 5=Forest, 6=Deathblight
@export_range(1, 6) var wall_type: int = 1:
	set(value):
		wall_type = value
		_rebuild_visual()

## Story flag that unlocks this wall. If empty, uses the default for this wall_type.
@export var unlock_flag: String = ""

const _WALL_COLORS: Dictionary = {
	1: Color(1.0, 0.0, 0.0, 0.5),    # mountain — red
	2: Color(0.0, 0.3, 1.0, 0.5),    # water — blue
	3: Color(1.0, 1.0, 1.0, 0.5),    # gate — white
	4: Color(0.5, 0.0, 1.0, 0.5),    # barrier — purple
	5: Color(0.0, 0.8, 0.0, 0.5),    # forest — green
	6: Color(0.3, 0.3, 0.3, 0.5),    # deathblight — dark grey
}

const _DEFAULT_FLAGS: Dictionary = {
	1: "has_airship",
	2: "has_boat",
	3: "gate_opened",
	4: "barrier_broken",
	5: "forest_cleared",
	6: "blight_cured",
}

const _PANEL_HEIGHT: float = 6.0
const _PANEL_Y_OFFSET: float = -1.0

var _visual: MeshInstance3D = null


func _ready() -> void:
	add_to_group("wall_paths")
	if curve:
		curve.changed.connect(_rebuild_visual)
	_rebuild_visual()


func _rebuild_visual() -> void:
	## Builds vertical panels along the baked curve for editor visibility.
	if _visual and is_instance_valid(_visual):
		_visual.queue_free()
		_visual = null

	if not curve or curve.point_count < 2:
		return

	var pts: PackedVector3Array = curve.get_baked_points()
	if pts.size() < 2:
		return

	var col: Color = _WALL_COLORS.get(wall_type, Color(1, 0, 1, 0.5))

	# Count valid segments first
	var valid_count: int = 0
	for i in range(pts.size() - 1):
		if pts[i].distance_squared_to(pts[i + 1]) >= 0.001:
			valid_count += 1
	if valid_count == 0:
		return

	var im := ImmediateMesh.new()
	im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		if a.distance_squared_to(b) < 0.001:
			continue
		var a_bot := Vector3(a.x, a.y + _PANEL_Y_OFFSET, a.z)
		var a_top := Vector3(a.x, a.y + _PANEL_HEIGHT, a.z)
		var b_bot := Vector3(b.x, b.y + _PANEL_Y_OFFSET, b.z)
		var b_top := Vector3(b.x, b.y + _PANEL_HEIGHT, b.z)
		# Front face
		im.surface_add_vertex(a_bot)
		im.surface_add_vertex(b_bot)
		im.surface_add_vertex(b_top)
		im.surface_add_vertex(a_bot)
		im.surface_add_vertex(b_top)
		im.surface_add_vertex(a_top)
		# Back face
		im.surface_add_vertex(b_top)
		im.surface_add_vertex(b_bot)
		im.surface_add_vertex(a_bot)
		im.surface_add_vertex(a_top)
		im.surface_add_vertex(b_top)
		im.surface_add_vertex(a_bot)
	im.surface_end()

	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED

	_visual = MeshInstance3D.new()
	_visual.name = "WallVisual"
	_visual.mesh = im
	_visual.material_override = mat
	add_child(_visual)


func is_locked() -> bool:
	## Returns true if this wall is currently blocking the player.
	var flag: String = unlock_flag if not unlock_flag.is_empty() else _DEFAULT_FLAGS.get(wall_type, "")
	if flag.is_empty():
		return true
	return not GameManager.has_flag(flag)


func get_baked_points_global() -> PackedVector3Array:
	## Returns baked curve points in global space for collision checks.
	if not curve or curve.point_count < 2:
		return PackedVector3Array()
	var local_pts: PackedVector3Array = curve.get_baked_points()
	var result := PackedVector3Array()
	result.resize(local_pts.size())
	for i in range(local_pts.size()):
		result[i] = global_transform * local_pts[i]
	return result
