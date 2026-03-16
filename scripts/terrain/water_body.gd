class_name WaterBody
extends MeshInstance3D
## A flat water surface with animated shader. Supports rectangular and elliptical shapes.

const WATER_SHADER_PATH := "res://shaders/water.gdshader"
const _WATER_NORMAL := "res://assets/3D/Material-LIB/Material-LIB/Nature/Water/Water-N.png"
const _ELLIPSE_SEGMENTS := 48  ## Radial segments for ellipse mesh

@export var water_size: Vector2 = Vector2(100, 100)  ## Width × depth in world units
@export var water_level: float = 0.0  ## Y position of the water surface
@export var water_shape: int = 0  ## 0 = rectangle, 1 = ellipse (matches WaterZone.Shape)
@export var shallow_color: Color = Color(0.2, 0.5, 0.7, 0.6)
@export var deep_color: Color = Color(0.05, 0.15, 0.3, 0.85)
@export var wave_speed: float = 0.3
@export var wave_strength: float = 0.05
@export var subdivisions: int = 32  ## Mesh subdivisions for vertex waves (rectangle only)


func _ready() -> void:
	_build_water()


func _build_water() -> void:
	if water_shape == 1:
		mesh = _create_ellipse_mesh()
	else:
		var plane := PlaneMesh.new()
		plane.size = water_size
		plane.subdivide_width = subdivisions
		plane.subdivide_depth = subdivisions
		mesh = plane

	position.y = water_level

	# Create shader material
	var shader: Shader = load(WATER_SHADER_PATH) as Shader
	if not shader:
		return
	var mat := ShaderMaterial.new()
	mat.shader = shader
	mat.set_shader_parameter("shallow_color", shallow_color)
	mat.set_shader_parameter("deep_color", deep_color)
	mat.set_shader_parameter("wave_speed", wave_speed)
	mat.set_shader_parameter("wave_strength", wave_strength)

	if ResourceLoader.exists(_WATER_NORMAL):
		var normal_tex: Texture2D = load(_WATER_NORMAL)
		mat.set_shader_parameter("normal_map_a", normal_tex)
		mat.set_shader_parameter("normal_map_b", normal_tex)

	material_override = mat
	extra_cull_margin = 2.0


func _create_ellipse_mesh() -> ArrayMesh:
	## Builds a flat elliptical disc mesh with concentric rings for wave subdivision.
	var rx: float = water_size.x * 0.5
	var rz: float = water_size.y * 0.5
	var rings: int = maxi(subdivisions / 4, 4)  ## Concentric rings from center to edge
	var segs: int = _ELLIPSE_SEGMENTS

	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()

	# Center vertex
	vertices.append(Vector3.ZERO)
	normals.append(Vector3.UP)
	uvs.append(Vector2(0.5, 0.5))
	colors.append(Color.WHITE)

	# Ring vertices
	for ring in range(1, rings + 1):
		var t: float = float(ring) / float(rings)
		for seg in range(segs):
			var angle: float = float(seg) / float(segs) * TAU
			var x: float = cos(angle) * rx * t
			var z: float = sin(angle) * rz * t
			vertices.append(Vector3(x, 0.0, z))
			normals.append(Vector3.UP)
			uvs.append(Vector2(0.5 + cos(angle) * t * 0.5, 0.5 + sin(angle) * t * 0.5))
			colors.append(Color.WHITE)

	# Triangles: center fan (ring 0 → ring 1)
	for seg in range(segs):
		var next_seg: int = (seg + 1) % segs
		indices.append(0)  # center
		indices.append(1 + seg)
		indices.append(1 + next_seg)

	# Triangles: ring strips (ring n → ring n+1)
	for ring in range(1, rings):
		var base_curr: int = 1 + (ring - 1) * segs
		var base_next: int = 1 + ring * segs
		for seg in range(segs):
			var next_seg: int = (seg + 1) % segs
			var c0: int = base_curr + seg
			var c1: int = base_curr + next_seg
			var n0: int = base_next + seg
			var n1: int = base_next + next_seg
			# Two triangles per quad
			indices.append(c0)
			indices.append(n0)
			indices.append(c1)
			indices.append(c1)
			indices.append(n0)
			indices.append(n1)

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return arr_mesh
