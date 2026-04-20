class_name RiverGeneratorLocal
extends RefCounted
## Generates a river on a local map: carves terrain, creates water mesh,
## builds collision walls, detects path crossings, places bridge markers.


static func generate(config: Dictionary, heightmap: Resource, generator: Node3D) -> Dictionary:
	## Main entry point. Config keys:
	##   start: Vector3, end: Vector3, width: float, water_width: float,
	##   carve_depth: float, water_y_offset: float, terrain_scale: Vector3,
	##   map_width: int, map_depth: int, gen_seed: int, path_polylines: Array,
	##   path_width: float
	## Returns {"river_path": RiverPath, "crossings": PackedVector2Array}

	var river_rng := RandomNumberGenerator.new()
	river_rng.seed = config.get("gen_seed", 42) + 700
	var terrain_scale: Vector3 = config.get("terrain_scale", Vector3(1, 6, 1))
	var map_width: int = config.get("map_width", 65)
	var map_depth: int = config.get("map_depth", 65)
	var river_width: float = config.get("width", 2.5)
	var water_width_mult: float = config.get("water_width", 1.0)
	var carve_depth: float = config.get("carve_depth", 0.14)
	var water_y_offset: float = config.get("water_y_offset", 0.0)
	var start: Vector3 = config.get("start", Vector3.ZERO)
	var end: Vector3 = config.get("end", Vector3.ZERO)
	var path_polylines: Array = config.get("path_polylines", [])
	var path_width_val: float = config.get("path_width", 5.0)

	var w: float = (map_width - 1) * terrain_scale.x
	var d: float = (map_depth - 1) * terrain_scale.z

	# Auto-place if zero
	if start == Vector3.ZERO:
		start = Vector3(2.0, 0, river_rng.randf_range(d * 0.3, d * 0.7))
	if end == Vector3.ZERO:
		end = Vector3(w - 2.0, 0, river_rng.randf_range(d * 0.3, d * 0.7))

	# Build curved polyline + subdivide
	var raw_poly: PackedVector2Array = MapGenUtils.build_curved_path(
		Vector2(start.x, start.z), Vector2(end.x, end.z), river_rng)
	var polyline := PackedVector2Array()
	for i in range(raw_poly.size() - 1):
		var a: Vector2 = raw_poly[i]
		var b: Vector2 = raw_poly[i + 1]
		var seg_len: float = a.distance_to(b)
		var steps: int = maxi(1, ceili(seg_len))
		for s in range(steps):
			polyline.append(a.lerp(b, float(s) / steps))
	polyline.append(raw_poly[raw_poly.size() - 1])

	# Pre-sample heights before carving
	var original_heights := PackedFloat32Array()
	original_heights.resize(polyline.size())
	for i in range(polyline.size()):
		original_heights[i] = MapGenUtils.sample_terrain_height(
			heightmap, polyline[i].x, polyline[i].y, terrain_scale)

	# Build RiverPath
	var rp := RiverPath.new()
	rp.id = "local_river"
	var points := PackedVector3Array()
	var widths := PackedFloat32Array()
	points.resize(polyline.size())
	widths.resize(polyline.size())

	for i in range(polyline.size()):
		var px: float = polyline[i].x
		var pz: float = polyline[i].y
		var h: float = original_heights[i]

		var t: float = float(i) / maxf(polyline.size() - 1, 1)
		var taper: float = sin(t * PI)
		var half_w: float = river_width * (0.6 + 0.4 * taper)
		widths[i] = half_w * water_width_mult

		# Carve terrain
		var vx: int = clampi(roundi(px / terrain_scale.x), 0, map_width - 1)
		var vz: int = clampi(roundi(pz / terrain_scale.z), 0, map_depth - 1)
		var carve_radius: int = ceili(half_w * 1.1 / terrain_scale.x) + 1
		for dz in range(-carve_radius, carve_radius + 1):
			for dx in range(-carve_radius, carve_radius + 1):
				var nx: int = vx + dx
				var nz: int = vz + dz
				if nx < 0 or nx >= map_width or nz < 0 or nz >= map_depth:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz)) * terrain_scale.x
				if dist > half_w * 1.1:
					continue
				var old_h: float = heightmap.get_height_at(nx, nz)
				var blend: float = 1.0 - smoothstep(half_w * 0.7, half_w * 1.1, dist)
				var target_h: float = h - carve_depth
				var new_h: float = lerpf(old_h, target_h, blend)
				heightmap.set_height_at(nx, nz, maxf(new_h, target_h))
				# Mud on banks
				if dist > half_w * 0.5 and dist < half_w * 2.0:
					var mud_blend: float = 1.0 - smoothstep(half_w, half_w * 2.0, dist)
					var cur: Color = heightmap.get_splatmap_weights(nx, nz)
					cur.a = maxf(cur.a, mud_blend * 0.7)
					var total: float = cur.r + cur.g + cur.b + cur.a
					if total > 0.001:
						cur.r /= total; cur.g /= total; cur.b /= total; cur.a /= total
					heightmap.set_splatmap_weights(nx, nz, cur)

		points[i] = Vector3(px, (h - carve_depth) * terrain_scale.y + water_y_offset, pz)

	rp.points = points
	rp.widths = widths
	heightmap.rivers.clear()
	heightmap.rivers.append(rp)
	heightmap.build_river_mask(ceili(river_width / terrain_scale.x) + 2)

	# Detect crossings
	var crossings: PackedVector2Array = _detect_crossings(polyline, path_polylines)

	# Rebuild terrain
	var terrain: Node = null
	for i in range(generator.get_child_count()):
		if generator.get_child(i).name == "HeightmapTerrain3D":
			terrain = generator.get_child(i)
			break
	if terrain:
		terrain.call("_rebuild")

	# Create river parent node
	var scene_root: Node = generator.get_tree().edited_scene_root if Engine.is_editor_hint() else generator
	# Remove old river layer
	for i in range(generator.get_child_count()):
		if generator.get_child(i).name == "River":
			var old: Node = generator.get_child(i)
			generator.remove_child(old)
			old.queue_free()
			break
	var river_parent := Node3D.new()
	river_parent.name = "River"
	MapGenUtils.add_owned(river_parent, generator, scene_root)

	# Water mesh
	var river_body: MeshInstance3D = RiverBody.new()
	river_body.name = "RiverMesh"
	river_parent.add_child(river_body)
	river_body.setup(rp)
	if Engine.is_editor_hint():
		river_body.owner = scene_root

	# Collision walls
	_build_walls(points, widths, river_parent, scene_root, crossings)

	# Bridge markers
	_place_bridges(crossings, points, widths, river_width, path_width_val,
		path_polylines, heightmap, terrain_scale, river_parent, scene_root)

	return {"river_path": rp, "crossings": crossings, "polyline": polyline}


static func _detect_crossings(river_poly: PackedVector2Array, path_polylines: Array) -> PackedVector2Array:
	var crossings := PackedVector2Array()
	if river_poly.is_empty() or path_polylines.is_empty():
		return crossings
	for pi in range(path_polylines.size()):
		var path: PackedVector2Array = path_polylines[pi]
		for si in range(path.size() - 1):
			for ri in range(river_poly.size() - 1):
				var crossing: Variant = MapGenUtils.segment_intersection(
					path[si], path[si + 1], river_poly[ri], river_poly[ri + 1])
				if crossing is Vector2:
					var is_dup: bool = false
					for existing in crossings:
						if existing.distance_to(crossing) < 5.0:
							is_dup = true
							break
					if not is_dup:
						crossings.append(crossing)
	return crossings


static func _build_walls(points: PackedVector3Array, widths: PackedFloat32Array,
		parent: Node3D, scene_root: Node, crossings: PackedVector2Array) -> void:
	var wall := StaticBody3D.new()
	wall.name = "RiverWalls"
	wall.collision_layer = 1
	wall.collision_mask = 0
	MapGenUtils.add_owned(wall, parent, scene_root)

	var step: int = maxi(1, points.size() / 60)
	for i in range(0, points.size(), step):
		var p: Vector3 = points[i]
		var half_w: float = widths[i] if i < widths.size() else 2.0

		var col := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = half_w + 0.3
		cyl.height = 4.0
		col.shape = cyl
		col.position = Vector3(p.x, p.y + 0.3, p.z)
		wall.add_child(col)
		col.owner = scene_root


static func _place_bridges(crossings: PackedVector2Array, points: PackedVector3Array,
		widths: PackedFloat32Array, river_width: float, path_width_val: float,
		path_polylines: Array, heightmap: Resource, terrain_scale: Vector3,
		parent: Node3D, scene_root: Node) -> void:
	for ci in range(crossings.size()):
		var crossing: Vector2 = crossings[ci]
		var h: float = MapGenUtils.sample_terrain_height(heightmap, crossing.x, crossing.y, terrain_scale)

		var bridge_width: float = river_width
		var min_dist: float = INF
		for i in range(points.size()):
			var d: float = Vector2(points[i].x, points[i].z).distance_to(crossing)
			if d < min_dist:
				min_dist = d
				bridge_width = widths[i] if i < widths.size() else river_width

		var bridge_rot: float = 0.0
		for pi in range(path_polylines.size()):
			var path: PackedVector2Array = path_polylines[pi]
			for si in range(path.size() - 1):
				var seg_mid: Vector2 = (path[si] + path[si + 1]) * 0.5
				if seg_mid.distance_to(crossing) < 5.0:
					var dir: Vector2 = (path[si + 1] - path[si]).normalized()
					bridge_rot = atan2(dir.x, dir.y)
					break

		var marker := Node3D.new()
		marker.name = "Bridge_%d" % ci
		marker.position = Vector3(crossing.x, h * terrain_scale.y, crossing.y)
		marker.rotation.y = bridge_rot
		marker.set_meta("bridge_width", bridge_width * 2.0 + 1.0)
		marker.set_meta("bridge_length", path_width_val + 1.0)

		if Engine.is_editor_hint():
			var mesh_inst := MeshInstance3D.new()
			var box := BoxMesh.new()
			box.size = Vector3(path_width_val + 1.0, 0.3, bridge_width * 2.0 + 1.0)
			mesh_inst.mesh = box
			mesh_inst.position.y = 0.2
			var mat := StandardMaterial3D.new()
			mat.albedo_color = Color(0.6, 0.4, 0.2, 0.7)
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			mesh_inst.material_override = mat
			marker.add_child(mesh_inst)

			var lbl := Label3D.new()
			lbl.text = "BRIDGE"
			lbl.position.y = 1.5
			lbl.font_size = 28
			lbl.modulate = Color(0.8, 0.6, 0.3)
			lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			lbl.no_depth_test = true
			marker.add_child(lbl)

		MapGenUtils.add_owned(marker, parent, scene_root)
