class_name VoxImporter
## Parses MagicaVoxel .vox files and converts them to Godot ArrayMesh.
##
## Usage:
##   var mesh: ArrayMesh = VoxImporter.load_vox("res://assets/voxels/model.vox")
##   var inst := MeshInstance3D.new()
##   inst.mesh = mesh


## Loads a .vox file and returns an ArrayMesh centered on X/Z with bottom at Y=0.
## [param voxel_size]: world units per voxel (default 0.1 → 16-voxel model ≈ 1.6 units).
## Returns null on failure.
static func load_vox(path: String, voxel_size: float = 0.1) -> ArrayMesh:
	if not FileAccess.file_exists(path):
		push_error("VoxImporter: File not found: %s" % path)
		return null
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		push_error("VoxImporter: Cannot open: %s" % path)
		return null
	var bytes := file.get_buffer(file.get_length())
	file.close()

	var data: Dictionary = _parse_vox(bytes)
	if data.is_empty():
		return null
	return _build_mesh(data.voxels, data.palette, data.model_size, voxel_size)


# === Binary Parser ===

static func _parse_vox(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 8:
		push_error("VoxImporter: File too small")
		return {}
	if bytes.slice(0, 4).get_string_from_ascii() != "VOX ":
		push_error("VoxImporter: Invalid magic")
		return {}

	var pos: int = 8  # skip magic (4) + version (4)
	var model_size := Vector3i.ZERO
	var voxels: Dictionary = {}
	var palette := PackedColorArray()
	palette.resize(256)
	_fill_default_palette(palette)
	var found_xyzi := false

	while pos + 12 <= bytes.size():
		var chunk_id := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var content_size: int = bytes.decode_s32(pos + 4)
		var children_size: int = bytes.decode_s32(pos + 8)
		var cs: int = pos + 12  # content start

		if chunk_id == "MAIN":
			# MAIN has no content, only children — step into them
			pos = cs
			continue
		elif chunk_id == "SIZE" and not found_xyzi:
			if content_size >= 12:
				model_size.x = bytes.decode_s32(cs)
				model_size.y = bytes.decode_s32(cs + 4)
				model_size.z = bytes.decode_s32(cs + 8)
		elif chunk_id == "XYZI" and not found_xyzi:
			found_xyzi = true
			if content_size >= 4:
				var num_voxels: int = bytes.decode_s32(cs)
				for vi in range(num_voxels):
					var o: int = cs + 4 + vi * 4
					if o + 4 > bytes.size():
						break
					# Axis remap: MV(x=right, y=depth, z=up) → Godot(x=right, y=up, z=depth)
					var gx: int = bytes[o]
					var gy: int = bytes[o + 2]  # MV.z (up) → Godot.y
					var gz: int = bytes[o + 1]  # MV.y (depth) → Godot.z
					voxels[Vector3i(gx, gy, gz)] = bytes[o + 3]
		elif chunk_id == "RGBA":
			# Palette: 256 entries, index 0 in RGBA maps to color_index 1 in XYZI
			for pi in range(256):
				var o: int = cs + pi * 4
				if o + 4 > bytes.size():
					break
				palette[pi] = Color(
					bytes[o] / 255.0,
					bytes[o + 1] / 255.0,
					bytes[o + 2] / 255.0,
					bytes[o + 3] / 255.0
				)

		pos = cs + content_size + children_size

	if voxels.is_empty():
		push_error("VoxImporter: No voxels found in file")
		return {}

	return {"voxels": voxels, "palette": palette, "model_size": model_size}


static func _fill_default_palette(palette: PackedColorArray) -> void:
	## Simple fallback palette. Real .vox files include an RGBA chunk.
	for pi in range(256):
		palette[pi] = Color.from_hsv(float(pi) / 256.0, 0.7, 0.9)


# === Mesh Builder ===

static func _build_mesh(
	voxels: Dictionary,
	palette: PackedColorArray,
	model_size: Vector3i,
	voxel_size: float,
) -> ArrayMesh:
	var vertices := PackedVector3Array()
	var mesh_normals := PackedVector3Array()
	var mesh_colors := PackedColorArray()
	var mesh_indices := PackedInt32Array()

	# Center X/Z at origin, bottom at Y=0.
	# model_size is in MV coords: (x, y_depth, z_up). After axis swap the Godot
	# extents are (model_size.x, model_size.z, model_size.y).
	var center_x: float = model_size.x * 0.5
	var center_z: float = model_size.y * 0.5  # MV.y → Godot.z

	# 6 neighbor directions
	var dirs: Array[Vector3i] = [
		Vector3i(1, 0, 0), Vector3i(-1, 0, 0),
		Vector3i(0, 1, 0), Vector3i(0, -1, 0),
		Vector3i(0, 0, 1), Vector3i(0, 0, -1),
	]

	# Face normals matching dirs
	var norms: Array[Vector3] = [
		Vector3.RIGHT, Vector3.LEFT,
		Vector3.UP, Vector3.DOWN,
		Vector3.BACK, Vector3.FORWARD,
	]

	# 4 quad vertices per face (CCW winding viewed from outside)
	var fv0: Array[Vector3] = [
		Vector3(1, 0, 0), Vector3(0, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 0), Vector3(0, 0, 1), Vector3(1, 0, 0),
	]
	var fv1: Array[Vector3] = [
		Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(0, 0, 0),
	]
	var fv2: Array[Vector3] = [
		Vector3(1, 1, 1), Vector3(0, 1, 1), Vector3(1, 1, 1), Vector3(1, 0, 1), Vector3(1, 1, 1), Vector3(0, 1, 0),
	]
	var fv3: Array[Vector3] = [
		Vector3(1, 0, 1), Vector3(0, 1, 0), Vector3(1, 1, 0), Vector3(0, 0, 1), Vector3(0, 1, 1), Vector3(1, 1, 0),
	]

	for vpos in voxels:
		var ci: int = voxels[vpos]
		# XYZI color indices are 1-based; palette is 0-indexed (palette[0] = color 1)
		var color: Color = palette[ci - 1] if ci >= 1 else Color.MAGENTA
		var px: float = float(vpos.x) - center_x
		var py: float = float(vpos.y)  # bottom at Y=0
		var pz: float = float(vpos.z) - center_z
		var base := Vector3(px, py, pz) * voxel_size

		for fi in range(6):
			# Skip faces hidden by adjacent voxels
			var neighbor := Vector3i(
				int(vpos.x) + dirs[fi].x,
				int(vpos.y) + dirs[fi].y,
				int(vpos.z) + dirs[fi].z,
			)
			if voxels.has(neighbor):
				continue

			var vi_start: int = vertices.size()

			# Append 4 quad vertices
			vertices.append(base + fv0[fi] * voxel_size)
			vertices.append(base + fv1[fi] * voxel_size)
			vertices.append(base + fv2[fi] * voxel_size)
			vertices.append(base + fv3[fi] * voxel_size)

			var normal: Vector3 = norms[fi]
			for _vi in range(4):
				mesh_normals.append(normal)
				mesh_colors.append(color)

			# Two triangles: 0-1-2, 0-2-3
			mesh_indices.append(vi_start)
			mesh_indices.append(vi_start + 1)
			mesh_indices.append(vi_start + 2)
			mesh_indices.append(vi_start)
			mesh_indices.append(vi_start + 2)
			mesh_indices.append(vi_start + 3)

	if vertices.is_empty():
		push_error("VoxImporter: No visible faces generated")
		return null

	# Assemble ArrayMesh
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = mesh_normals
	arrays[Mesh.ARRAY_COLOR] = mesh_colors
	arrays[Mesh.ARRAY_INDEX] = mesh_indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	# Vertex-color material
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)

	return mesh
