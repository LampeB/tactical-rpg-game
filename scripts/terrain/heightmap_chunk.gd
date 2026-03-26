class_name HeightmapChunk
extends StaticBody3D
## Generates an ArrayMesh terrain chunk from HeightmapData and adds collision.
## Each chunk covers CHUNK_SIZE × CHUNK_SIZE vertices (CHUNK_SIZE-1 quads per edge).
## Supports LOD levels: 0 = full detail, 1 = half, 2 = quarter vertices.

const SHADER_PATH := "res://shaders/terrain_splatmap.gdshader"

var chunk_x: int = 0  ## Chunk index in X
var chunk_z: int = 0  ## Chunk index in Z
var lod_level: int = 0  ## Current LOD level
var _mesh_instance: MeshInstance3D
var _collision_shape: CollisionShape3D


func _init() -> void:
	collision_layer = 1
	collision_mask = 0


func build(data: HeightmapData, cx: int, cz: int, lod: int = 0) -> void:
	## Generates mesh + collision for chunk (cx, cz) from the heightmap data.
	## lod: 0 = full detail, 1 = every 2nd vertex, 2 = every 4th vertex.
	chunk_x = cx
	chunk_z = cz
	lod_level = lod
	name = "Chunk_%d_%d" % [cx, cz]

	var chunk_size: int = HeightmapData.CHUNK_SIZE
	var tscale: Vector3 = data.terrain_scale
	var step: int = 1 << clampi(lod, 0, 2)  # 1, 2, or 4

	# Vertex origin in heightmap space
	var origin_x: int = cx * (chunk_size - 1)
	var origin_z: int = cz * (chunk_size - 1)

	# Full vertex range for this chunk
	var full_verts_x: int = mini(chunk_size, data.width - origin_x)
	var full_verts_z: int = mini(chunk_size, data.height - origin_z)
	if full_verts_x < 2 or full_verts_z < 2:
		return  # Chunk has no quads

	# LOD-reduced vertex grid (always include first and last vertex)
	var lod_xs: PackedInt32Array = _build_lod_indices(full_verts_x, step)
	var lod_zs: PackedInt32Array = _build_lod_indices(full_verts_z, step)
	var verts_x: int = lod_xs.size()
	var verts_z: int = lod_zs.size()
	if verts_x < 2 or verts_z < 2:
		return

	var quads_x: int = verts_x - 1
	var quads_z: int = verts_z - 1

	# --- Build arrays ---
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var splatmap2_img := Image.create(verts_x, verts_z, false, Image.FORMAT_RGBA8)
	var splatmap3_img := Image.create(verts_x, verts_z, false, Image.FORMAT_RGBA8)

	var vert_count: int = verts_x * verts_z
	vertices.resize(vert_count)
	normals.resize(vert_count)
	uvs.resize(vert_count)
	colors.resize(vert_count)

	var full_quads_x: int = full_verts_x - 1
	var full_quads_z: int = full_verts_z - 1

	# Fill vertex data
	for iz in range(verts_z):
		var lz: int = lod_zs[iz]
		for ix in range(verts_x):
			var lx: int = lod_xs[ix]
			var gx: int = origin_x + lx
			var gz: int = origin_z + lz
			var h: float = data.get_height_at(gx, gz)
			var idx: int = iz * verts_x + ix

			vertices[idx] = Vector3(
				float(lx) * tscale.x,
				h * tscale.y,
				float(lz) * tscale.z
			)

			# UV spans [0,1] across the chunk for texture tiling
			uvs[idx] = Vector2(
				float(lx) / float(full_quads_x) if full_quads_x > 0 else 0.0,
				float(lz) / float(full_quads_z) if full_quads_z > 0 else 0.0
			)

			# Vertex color = splatmap weights (channels 0-3)
			colors[idx] = data.get_splatmap_weights(gx, gz)
			# Splatmap2 image pixel (channels 4-7)
			splatmap2_img.set_pixel(ix, iz, data.get_splatmap2_weights(gx, gz))
			splatmap3_img.set_pixel(ix, iz, data.get_splatmap3_weights(gx, gz))

	# Calculate normals from height differences (central differencing)
	for iz in range(verts_z):
		var lz: int = lod_zs[iz]
		for ix in range(verts_x):
			var lx: int = lod_xs[ix]
			var gx: int = origin_x + lx
			var gz: int = origin_z + lz
			var idx: int = iz * verts_x + ix

			var h_left: float = data.get_height_at(gx - 1, gz) * tscale.y
			var h_right: float = data.get_height_at(gx + 1, gz) * tscale.y
			var h_down: float = data.get_height_at(gx, gz - 1) * tscale.y
			var h_up: float = data.get_height_at(gx, gz + 1) * tscale.y

			var normal := Vector3(
				h_left - h_right,
				2.0 * tscale.x,
				h_down - h_up
			).normalized()
			normals[idx] = normal

	# Build triangle indices (two triangles per quad)
	indices.resize(quads_x * quads_z * 6)
	var tri_idx: int = 0
	for iz in range(quads_z):
		for ix in range(quads_x):
			var top_left: int = iz * verts_x + ix
			var top_right: int = top_left + 1
			var bot_left: int = (iz + 1) * verts_x + ix
			var bot_right: int = bot_left + 1

			# Triangle 1 (CCW when viewed from above = normal points up)
			indices[tri_idx] = top_left
			indices[tri_idx + 1] = top_right
			indices[tri_idx + 2] = bot_left
			# Triangle 2
			indices[tri_idx + 3] = top_right
			indices[tri_idx + 4] = bot_right
			indices[tri_idx + 5] = bot_left
			tri_idx += 6

	# --- Create ArrayMesh ---
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Apply splatmap material
	var material := _create_material(data, splatmap2_img, splatmap3_img)
	mesh.surface_set_material(0, material)

	# --- MeshInstance3D ---
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = mesh
	_mesh_instance.name = "MeshInstance"
	# Expand cull margin so chunks aren't frustum-culled prematurely at steep camera angles
	_mesh_instance.extra_cull_margin = data.terrain_scale.y * 2.0
	add_child(_mesh_instance)

	# --- Collision (full detail only — distant chunks don't need precise collision) ---
	if lod == 0:
		_collision_shape = CollisionShape3D.new()
		_collision_shape.shape = mesh.create_trimesh_shape()
		_collision_shape.name = "CollisionShape"
		add_child(_collision_shape)

	# Position the chunk in world space
	position = Vector3(
		float(origin_x) * tscale.x,
		0.0,
		float(origin_z) * tscale.z
	)


static func _build_lod_indices(full_count: int, step: int) -> PackedInt32Array:
	## Returns the local vertex indices to use for a given LOD step.
	## Always includes index 0 and the last index for seamless edges.
	var result := PackedInt32Array()
	var last: int = full_count - 1
	var i: int = 0
	while i < last:
		result.append(i)
		i += step
	# Always include the last vertex for chunk-edge continuity
	if result[result.size() - 1] != last:
		result.append(last)
	return result


func _create_material(data: HeightmapData, splatmap2_img: Image, splatmap3_img: Image) -> ShaderMaterial:
	var shader: Shader = load(SHADER_PATH) as Shader
	var mat := ShaderMaterial.new()
	mat.shader = shader

	# Assign textures from layers (up to 12)
	for i in range(mini(data.texture_layers.size(), 12)):
		var layer: TerrainTextureLayer = data.texture_layers[i]
		var suffix: String = str(i)
		if layer.albedo_texture:
			mat.set_shader_parameter("albedo_" + suffix, layer.albedo_texture)
		if layer.normal_texture:
			mat.set_shader_parameter("normal_" + suffix, layer.normal_texture)
		if layer.roughness_texture:
			mat.set_shader_parameter("roughness_" + suffix, layer.roughness_texture)
		if layer.metallic_texture:
			mat.set_shader_parameter("metallic_" + suffix, layer.metallic_texture)
		mat.set_shader_parameter("uv_scale_" + suffix, layer.uv_scale)

	# Splatmap2 texture (channels 4-7)
	var splatmap2_tex := ImageTexture.create_from_image(splatmap2_img)
	mat.set_shader_parameter("splatmap2_tex", splatmap2_tex)

	# Splatmap3 texture (channels 8-11)
	var splatmap3_tex := ImageTexture.create_from_image(splatmap3_img)
	mat.set_shader_parameter("splatmap3_tex", splatmap3_tex)

	return mat
