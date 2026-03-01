class_name VoxWriter
## Writes MagicaVoxel .vox files from voxel data.
##
## Usage:
##   var voxels: Dictionary = {}  # {Vector3i: int} — Godot coords, 0-based palette index
##   voxels[Vector3i(0, 0, 0)] = 0
##   var palette: Array[Color] = [Color.RED]
##   VoxWriter.write_vox("res://assets/voxels/test.vox", voxels, palette)


## Writes a .vox file from voxel data defined in Godot coordinates.
## [param path]: file path to write (res:// or user://).
## [param voxels]: Dictionary of {Vector3i: int} where int is 0-based palette index.
## [param palette]: Array[Color] of up to 255 entries.
## Returns OK on success or an error code.
static func write_vox(path: String, voxels: Dictionary, palette: Array[Color]) -> Error:
	if voxels.is_empty():
		push_error("VoxWriter: No voxels to write")
		return ERR_INVALID_DATA

	# Compute bounding box in Godot coords and offset to zero-origin
	var min_pos := Vector3i(999999, 999999, 999999)
	var max_pos := Vector3i(-999999, -999999, -999999)
	for pos in voxels:
		var v: Vector3i = pos
		min_pos.x = mini(min_pos.x, v.x)
		min_pos.y = mini(min_pos.y, v.y)
		min_pos.z = mini(min_pos.z, v.z)
		max_pos.x = maxi(max_pos.x, v.x)
		max_pos.y = maxi(max_pos.y, v.y)
		max_pos.z = maxi(max_pos.z, v.z)

	var godot_size := max_pos - min_pos + Vector3i.ONE

	# MagicaVoxel SIZE: MV(x, y_depth, z_up) = Godot(x, z, y)
	var mv_size_x: int = godot_size.x
	var mv_size_y: int = godot_size.z  # Godot.z (depth) → MV.y
	var mv_size_z: int = godot_size.y  # Godot.y (up) → MV.z

	# Build SIZE chunk content
	var size_content := PackedByteArray()
	size_content.resize(12)
	size_content.encode_s32(0, mv_size_x)
	size_content.encode_s32(4, mv_size_y)
	size_content.encode_s32(8, mv_size_z)

	# Build XYZI chunk content
	var num_voxels: int = voxels.size()
	var xyzi_content := PackedByteArray()
	xyzi_content.resize(4 + num_voxels * 4)
	xyzi_content.encode_s32(0, num_voxels)

	var vi: int = 0
	for pos in voxels:
		var v: Vector3i = pos
		var color_idx: int = voxels[pos]
		var offset: int = 4 + vi * 4
		# Remap Godot(gx, gy, gz) → MV(gx, gz, gy), offset to zero-origin
		xyzi_content[offset] = (v.x - min_pos.x) & 0xFF
		xyzi_content[offset + 1] = (v.z - min_pos.z) & 0xFF  # Godot.z → MV.y
		xyzi_content[offset + 2] = (v.y - min_pos.y) & 0xFF  # Godot.y → MV.z
		xyzi_content[offset + 3] = (color_idx + 1) & 0xFF     # 0-based → 1-based
		vi += 1

	# Build RGBA chunk content (256 entries × 4 bytes)
	var rgba_content := PackedByteArray()
	rgba_content.resize(1024)
	for pi in range(256):
		var o: int = pi * 4
		if pi < palette.size():
			var c: Color = palette[pi]
			rgba_content[o] = int(c.r * 255.0) & 0xFF
			rgba_content[o + 1] = int(c.g * 255.0) & 0xFF
			rgba_content[o + 2] = int(c.b * 255.0) & 0xFF
			rgba_content[o + 3] = int(c.a * 255.0) & 0xFF
		else:
			rgba_content[o] = 0
			rgba_content[o + 1] = 0
			rgba_content[o + 2] = 0
			rgba_content[o + 3] = 255

	# Wrap chunks
	var size_chunk := _make_chunk("SIZE", size_content)
	var xyzi_chunk := _make_chunk("XYZI", xyzi_content)
	var rgba_chunk := _make_chunk("RGBA", rgba_content)

	# Children = SIZE + XYZI + RGBA
	var children := PackedByteArray()
	children.append_array(size_chunk)
	children.append_array(xyzi_chunk)
	children.append_array(rgba_chunk)

	var main_chunk := _make_chunk("MAIN", PackedByteArray(), children)

	# Write file: header + MAIN
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		push_error("VoxWriter: Cannot open for writing: %s" % path)
		return ERR_FILE_CANT_WRITE

	# Header: "VOX " + version 150
	var header := PackedByteArray()
	header.append_array("VOX ".to_ascii_buffer())
	header.resize(8)
	header.encode_s32(4, 150)

	file.store_buffer(header)
	file.store_buffer(main_chunk)
	file.close()
	return OK


static func _make_chunk(
	chunk_id: String,
	content: PackedByteArray,
	children: PackedByteArray = PackedByteArray(),
) -> PackedByteArray:
	var chunk := PackedByteArray()
	chunk.append_array(chunk_id.to_ascii_buffer())
	# Reserve space for content_size + children_size
	var size_offset: int = chunk.size()
	chunk.resize(size_offset + 8)
	chunk.encode_s32(size_offset, content.size())
	chunk.encode_s32(size_offset + 4, children.size())
	chunk.append_array(content)
	chunk.append_array(children)
	return chunk
