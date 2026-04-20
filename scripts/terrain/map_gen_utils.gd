class_name MapGenUtils
extends RefCounted
## Static utility functions shared across all map generators.
## Paths, terrain sampling, weighted selection, node ownership.


static func build_curved_path(from: Vector2, to: Vector2, rng: RandomNumberGenerator) -> PackedVector2Array:
	## Builds a curved polyline from `from` to `to` with natural-looking bends.
	var points := PackedVector2Array()
	var total_dist: float = from.distance_to(to)
	var segment_length: float = 4.0
	var num_segments: int = maxi(3, int(total_dist / segment_length))
	var direction: Vector2 = (to - from).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var amplitude: float = minf(total_dist * 0.15, 12.0)

	points.append(from)
	for i in range(1, num_segments):
		var t: float = float(i) / num_segments
		var base: Vector2 = from.lerp(to, t)
		var envelope: float = sin(t * PI)
		var offset: float = rng.randf_range(-amplitude, amplitude) * envelope
		var point: Vector2 = base + perpendicular * offset
		points.append(point)
	points.append(to)

	# Smooth pass
	for _pass in range(2):
		for i in range(1, points.size() - 1):
			points[i] = (points[i - 1] + points[i] * 2.0 + points[i + 1]) * 0.25

	return points


static func closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq < 0.001:
		return a
	var t: float = clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return a + ab * t


static func segment_intersection(a: Vector2, b: Vector2, c: Vector2, d: Vector2) -> Variant:
	## Returns intersection point of segments AB and CD, or null if they don't cross.
	var ab: Vector2 = b - a
	var cd: Vector2 = d - c
	var denom: float = ab.x * cd.y - ab.y * cd.x
	if absf(denom) < 0.0001:
		return null
	var ac: Vector2 = c - a
	var t: float = (ac.x * cd.y - ac.y * cd.x) / denom
	var u: float = (ac.x * ab.y - ac.y * ab.x) / denom
	if t >= 0.0 and t <= 1.0 and u >= 0.0 and u <= 1.0:
		return a + ab * t
	return null


static func sample_terrain_height(heightmap: Resource, world_x: float, world_z: float, terrain_scale: Vector3) -> float:
	## Sample height from heightmap data in vertex space with bilinear interpolation.
	if not heightmap:
		return 0.0
	var vx: float = world_x / terrain_scale.x
	var vz: float = world_z / terrain_scale.z
	var ix: int = int(vx)
	var iz: int = int(vz)
	var fx: float = vx - ix
	var fz: float = vz - iz
	var h00: float = heightmap.get_height_at(ix, iz)
	var h10: float = heightmap.get_height_at(ix + 1, iz)
	var h01: float = heightmap.get_height_at(ix, iz + 1)
	var h11: float = heightmap.get_height_at(ix + 1, iz + 1)
	var h0: float = lerpf(h00, h10, fx)
	var h1: float = lerpf(h01, h11, fx)
	return lerpf(h0, h1, fz)


static func pick_weighted(rng: RandomNumberGenerator, pool: Array[Dictionary], total_weight: int) -> Dictionary:
	var roll: int = rng.randi_range(0, total_weight - 1)
	var cumulative: int = 0
	for i in range(pool.size()):
		var entry: Dictionary = pool[i]
		cumulative += entry["weight"] as int
		if roll < cumulative:
			return entry
	return pool[pool.size() - 1]


static func add_owned(node: Node, parent_node: Node, scene_root: Node) -> void:
	## Adds a node as a child and sets owner recursively for .tscn saving.
	parent_node.add_child(node)
	node.owner = scene_root
	_set_owner_recursive(node, scene_root)


static func _set_owner_recursive(node: Node, scene_root: Node) -> void:
	for child in node.get_children():
		child.owner = scene_root
		_set_owner_recursive(child, scene_root)
