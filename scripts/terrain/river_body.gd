class_name RiverBody
extends MeshInstance3D
## Builds a quad-strip water mesh along a RiverPath polyline.
## UV.y scrolls downstream (for directional flow shader), UV.x spans bank-to-bank.

const _RiverPath := preload("res://scripts/terrain/river_path.gd")
const RIVER_SHADER_PATH: String = "res://shaders/river.gdshader"
const _WATER_NORMAL: String = "res://assets/3D/Material-LIB/Material-LIB/Nature/Water/Water-N.png"
## Y offset above carved riverbed.
## Channel depth = CARVE_DEPTH(0.14) * terrain_scale.y(8) = 1.12 world units.
const SURFACE_OFFSET: float = 1.10

var river_path: Resource = null  # RiverPath (preloaded, can't use class_name directly)
var shallow_color: Color = Color(0.18, 0.48, 0.68, 0.55)
var deep_color: Color = Color(0.06, 0.16, 0.32, 0.8)
var flow_speed: float = 0.4

## Debug colors for distinguishing rivers (shallow, deep pairs)
const DEBUG_COLORS: Array = [
	[Color(0.18, 0.48, 0.68, 0.55), Color(0.06, 0.16, 0.32, 0.8)],  # Blue (default)
	[Color(0.85, 0.25, 0.55, 0.55), Color(0.55, 0.08, 0.30, 0.8)],  # Pink
	[Color(0.15, 0.15, 0.15, 0.55), Color(0.02, 0.02, 0.02, 0.8)],  # Black
	[Color(0.85, 0.20, 0.15, 0.55), Color(0.55, 0.06, 0.04, 0.8)],  # Red
	[Color(0.90, 0.55, 0.10, 0.55), Color(0.60, 0.30, 0.02, 0.8)],  # Orange
]


func _ready() -> void:
	if river_path and river_path.get_point_count() >= 2:
		_build_mesh()


func setup(path: Resource) -> void:
	river_path = path
	# All rivers use default blue — debug colors available if needed
	if is_inside_tree():
		_build_mesh()


func _build_mesh() -> void:
	var points: PackedVector3Array = river_path.points
	var widths: PackedFloat32Array = river_path.widths
	var count: int = points.size()
	if count < 2:
		return

	# Pre-compute per-point curvature (0 = straight, 1 = sharp bend)
	var curvatures: PackedFloat32Array = _compute_curvatures(points, count)

	var vertices: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()

	# Accumulated distance for UV.y (downstream direction)
	var accum_dist: float = 0.0
	var prev_perp: Vector3 = Vector3.ZERO  # Track previous perpendicular to prevent flipping

	for i in range(count):
		var p: Vector3 = points[i]
		var half_w: float = widths[i] if i < widths.size() else 2.0

		# Calculate forward direction (in XZ plane)
		var forward: Vector3 = Vector3.ZERO
		if i < count - 1:
			forward += points[i + 1] - p
		if i > 0:
			forward += p - points[i - 1]
		forward.y = 0.0
		if forward.length_squared() < 0.0001:
			forward = Vector3(1, 0, 0)
		forward = forward.normalized()

		# Perpendicular (rotate 90 degrees in XZ)
		var perp: Vector3 = Vector3(-forward.z, 0.0, forward.x)

		# Ensure consistent side — if perpendicular flipped relative to previous, negate it
		if i > 0 and perp.dot(prev_perp) < 0.0:
			perp = -perp
		prev_perp = perp

		# Left and right bank vertices
		var left: Vector3 = p + perp * half_w
		var right: Vector3 = p - perp * half_w
		left.y = p.y + SURFACE_OFFSET
		right.y = p.y + SURFACE_OFFSET

		vertices.append(left)
		vertices.append(right)
		normals.append(Vector3.UP)
		normals.append(Vector3.UP)

		# UV: x = 0 (left bank) to 1 (right bank), y = accumulated distance
		if i > 0:
			accum_dist += points[i - 1].distance_to(p)
		var uv_y: float = accum_dist * 0.1  # Scale for tiling
		uvs.append(Vector2(0.0, uv_y))
		uvs.append(Vector2(1.0, uv_y))

		# Vertex color: R = curvature (used by shader for turbulence foam)
		var curv: float = curvatures[i]
		colors.append(Color(curv, 0.0, 0.0, 1.0))
		colors.append(Color(curv, 0.0, 0.0, 1.0))

		# Quad indices (two triangles per segment)
		if i > 0:
			var base: int = (i - 1) * 2
			indices.append(base)
			indices.append(base + 2)
			indices.append(base + 1)
			indices.append(base + 1)
			indices.append(base + 2)
			indices.append(base + 3)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh: ArrayMesh = ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh = arr_mesh

	# Apply river shader material
	var shader: Shader = null
	if ResourceLoader.exists(RIVER_SHADER_PATH):
		shader = load(RIVER_SHADER_PATH) as Shader
	if not shader:
		return

	var mat: ShaderMaterial = ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("shallow_color", shallow_color)
	mat.set_shader_parameter("deep_color", deep_color)
	mat.set_shader_parameter("flow_speed", flow_speed)

	if ResourceLoader.exists(_WATER_NORMAL):
		var normal_tex: Texture2D = load(_WATER_NORMAL)
		mat.set_shader_parameter("normal_map_a", normal_tex)
		mat.set_shader_parameter("normal_map_b", normal_tex)

	material_override = mat
	extra_cull_margin = 5.0


static func _compute_curvatures(points: PackedVector3Array, count: int) -> PackedFloat32Array:
	## Computes per-point curvature (0 = straight, 1 = sharp bend).
	## Uses cross product magnitude of consecutive segment directions.
	var result: PackedFloat32Array = PackedFloat32Array()
	result.resize(count)
	result[0] = 0.0
	result[count - 1] = 0.0

	for i in range(1, count - 1):
		var d0: Vector3 = points[i] - points[i - 1]
		var d1: Vector3 = points[i + 1] - points[i]
		d0.y = 0.0
		d1.y = 0.0
		var len0: float = d0.length()
		var len1: float = d1.length()
		if len0 < 0.001 or len1 < 0.001:
			result[i] = 0.0
			continue
		d0 /= len0
		d1 /= len1
		# Cross product magnitude = sin(angle between segments)
		var cross_mag: float = absf(d0.x * d1.z - d0.z * d1.x)
		result[i] = clampf(cross_mag, 0.0, 1.0)

	return result
