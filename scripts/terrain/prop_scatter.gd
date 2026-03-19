class_name PropScatter
extends Node3D
## Scatters props within a terrain chunk using MultiMeshInstance3D for visual-only
## props and individual StaticBody3D instances for blocking props.
## Call scatter() after the chunk is positioned in the world.

const _COLLISION_CYLINDER_RADIUS := 0.5
const _COLLISION_CYLINDER_HEIGHT := 3.0
const _WIND_SHADER_PATH := "res://shaders/foliage_wind.gdshader"
static var _wind_shader: Shader = null


static func scatter_chunk(data: HeightmapData, cx: int, cz: int, seed_offset: int,
		visual_only: bool = false) -> Node3D:
	## Generates props for chunk (cx, cz). Returns a Node3D parent containing
	## MultiMeshInstance3D nodes (visual) and StaticBody3D nodes (blocking).
	var root := Node3D.new()
	root.name = "Props_%d_%d" % [cx, cz]

	var chunk_size: int = HeightmapData.CHUNK_SIZE
	var tscale: Vector3 = data.terrain_scale
	var origin_x: int = cx * (chunk_size - 1)
	var origin_z: int = cz * (chunk_size - 1)
	var verts_x: int = mini(chunk_size, data.width - origin_x)
	var verts_z: int = mini(chunk_size, data.height - origin_z)
	if verts_x < 2 or verts_z < 2:
		return root

	var chunk_world_w: float = float(verts_x - 1) * tscale.x
	var chunk_world_d: float = float(verts_z - 1) * tscale.z
	var chunk_area: float = chunk_world_w * chunk_world_d

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(cx, cz)) + seed_offset

	# Get all prop definitions
	var all_props: Array[PropDefinition] = PropRegistry.get_all()

	# For each prop type, decide how many to place and scatter them
	for pi in range(all_props.size()):
		var prop: PropDefinition = all_props[pi]
		# Check if the scene file exists
		# In visual_only mode, skip blocking props entirely
		if visual_only and prop.collision_type == PropDefinition.CollisionType.BLOCKING:
			continue

		if not ResourceLoader.exists(prop.scene_path):
			continue

		var expected: float = prop.density * chunk_area
		var count: int = int(expected)
		# Fractional remainder: probabilistic extra instance
		if rng.randf() < (expected - float(count)):
			count += 1
		if count <= 0:
			continue

		# Collect transforms for this prop type
		var transforms: Array[Transform3D] = []
		var blocking_transforms: Array[Transform3D] = []

		for _i in range(count):
			var local_x: float = rng.randf_range(0.0, chunk_world_w)
			var local_z: float = rng.randf_range(0.0, chunk_world_d)

			# Global heightmap coords (continuous)
			var gx: float = float(origin_x) + local_x / tscale.x
			var gz: float = float(origin_z) + local_z / tscale.z
			var ix: int = clampi(roundi(gx), 0, data.width - 1)
			var iz: int = clampi(roundi(gz), 0, data.height - 1)

			# Check splatmap layer compatibility
			var weights: Color = data.get_splatmap_weights(ix, iz)
			var dominant_layer: int = _get_dominant_layer(weights)
			if not (prop.allowed_layers & (1 << dominant_layer)):
				continue

			# Skip river channels — no trees/grass/rocks inside rivers
			if data.is_river_at(ix, iz):
				continue

			# Get terrain height using triangle interpolation (matches mesh topology)
			var h: float = _sample_height_tri(data, gx, gz)

			# Build transform
			var s: float = rng.randf_range(prop.min_scale, prop.max_scale)
			var rot_y: float = rng.randf_range(0.0, TAU) if prop.random_rotation_y else 0.0

			var xform := Transform3D.IDENTITY
			xform = xform.scaled(Vector3(s, s, s))
			xform = xform.rotated(Vector3.UP, rot_y)
			# Position relative to chunk origin
			xform.origin = Vector3(local_x, h, local_z)

			if prop.collision_type == PropDefinition.CollisionType.BLOCKING:
				blocking_transforms.append(xform)
			else:
				transforms.append(xform)

		# Create MultiMeshInstance3D for visual-only props
		if not transforms.is_empty():
			var mmi := _create_multimesh(prop.scene_path, transforms, prop.affected_by_wind)
			if mmi:
				root.add_child(mmi)

		# Create individual StaticBody3D for blocking props
		for bi in range(blocking_transforms.size()):
			var xform: Transform3D = blocking_transforms[bi]
			var body := _create_blocking_prop(prop.scene_path, xform, prop.affected_by_wind)
			if body:
				root.add_child(body)

	# Position the root at chunk world origin
	root.position = Vector3(
		float(origin_x) * tscale.x,
		0.0,
		float(origin_z) * tscale.z
	)

	return root


static func _get_dominant_layer(weights: Color) -> int:
	## Returns the splatmap layer index with the highest weight.
	var max_w: float = weights.r
	var layer: int = 0
	if weights.g > max_w:
		max_w = weights.g
		layer = 1
	if weights.b > max_w:
		max_w = weights.b
		layer = 2
	if weights.a > max_w:
		layer = 3
	return layer


static func _sample_height_tri(data: HeightmapData, gx: float, gz: float) -> float:
	## Triangle interpolation matching HeightmapChunk mesh topology.
	## gx/gz are continuous heightmap grid coordinates (not world coords).
	var tscale_y: float = data.terrain_scale.y
	var ix: int = clampi(floori(gx), 0, data.width - 2)
	var iz: int = clampi(floori(gz), 0, data.height - 2)
	var fx: float = clampf(gx - float(ix), 0.0, 1.0)
	var fz: float = clampf(gz - float(iz), 0.0, 1.0)
	var h00: float = data.get_height_at(ix, iz) * tscale_y
	var h10: float = data.get_height_at(ix + 1, iz) * tscale_y
	var h01: float = data.get_height_at(ix, iz + 1) * tscale_y
	var h11: float = data.get_height_at(ix + 1, iz + 1) * tscale_y
	# Diagonal from (ix+1,iz) to (ix,iz+1) — same split as HeightmapChunk
	if fx + fz <= 1.0:
		return h00 + fx * (h10 - h00) + fz * (h01 - h00)
	else:
		return h10 + (fx + fz - 1.0) * (h11 - h10) + (1.0 - fx) * (h01 - h10)


static func _create_multimesh(scene_path: String, transforms: Array[Transform3D],
		use_wind: bool = false) -> MultiMeshInstance3D:
	## Creates a MultiMeshInstance3D from a glTF scene and an array of transforms.
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return null

	# Extract mesh and its material from the scene
	var temp: Node3D = scene.instantiate()
	var source_mesh: Mesh = _find_mesh_in_node(temp)
	if not source_mesh:
		temp.queue_free()
		return null

	# Duplicate the mesh so we don't hold the scene's reference
	var mesh_copy: Mesh = source_mesh.duplicate()
	temp.queue_free()

	# Apply wind shader material if requested
	if use_wind:
		_apply_wind_material(mesh_copy)

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = transforms.size()
	mm.mesh = mesh_copy

	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.extra_cull_margin = 16.0  # Prevent popping
	return mmi


static func _create_blocking_prop(scene_path: String, xform: Transform3D,
		use_wind: bool = false) -> StaticBody3D:
	## Creates a StaticBody3D with visual mesh + simple collision at the given transform.
	var scene: PackedScene = load(scene_path) as PackedScene
	if not scene:
		return null

	var body := StaticBody3D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.transform = xform

	# Add visual
	var visual: Node3D = scene.instantiate()
	if use_wind:
		_apply_wind_to_tree(visual)
	body.add_child(visual)

	# Add simple cylinder collision
	var shape := CylinderShape3D.new()
	shape.radius = _COLLISION_CYLINDER_RADIUS
	shape.height = _COLLISION_CYLINDER_HEIGHT
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = _COLLISION_CYLINDER_HEIGHT * 0.5
	body.add_child(col)

	return body


static func _find_mesh_in_node(node: Node) -> Mesh:
	## Recursively finds the first MeshInstance3D mesh in a node tree.
	if node is MeshInstance3D:
		return node.mesh
	for i in range(node.get_child_count()):
		var result: Mesh = _find_mesh_in_node(node.get_child(i))
		if result:
			return result
	return null


static func _get_wind_shader() -> Shader:
	if not _wind_shader:
		_wind_shader = load(_WIND_SHADER_PATH) as Shader
	return _wind_shader


static func _apply_wind_material(mesh: Mesh) -> void:
	## Replaces surface materials on a mesh with wind shader versions that
	## preserve the original albedo texture.
	var shader: Shader = _get_wind_shader()
	if not shader:
		return
	for si in range(mesh.get_surface_count()):
		var orig_mat: Material = mesh.surface_get_material(si)
		var wind_mat := ShaderMaterial.new()
		wind_mat.shader = shader
		# Copy albedo texture from original material
		if orig_mat is StandardMaterial3D:
			var std: StandardMaterial3D = orig_mat as StandardMaterial3D
			if std.albedo_texture:
				wind_mat.set_shader_parameter("base_texture", std.albedo_texture)
			# Foliage usually needs alpha scissor
			if std.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR:
				wind_mat.set_shader_parameter("alpha_scissor", std.alpha_scissor_threshold)
		mesh.surface_set_material(si, wind_mat)


static func _apply_wind_to_tree(node: Node) -> void:
	## Applies wind shader to MeshInstance3D nodes in a scene tree (for blocking props).
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh:
			var mesh_copy: Mesh = mi.mesh.duplicate()
			_apply_wind_material(mesh_copy)
			mi.mesh = mesh_copy
	for i in range(node.get_child_count()):
		_apply_wind_to_tree(node.get_child(i))
