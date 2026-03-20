class_name RoadGenerator
extends RefCounted
## Generates roads connecting the procedural town to the ocean-facing map edges.
## Uses A* on a coarse grid (every STEP vertices) to find terrain-aware paths,
## then paints soil splatmap along the road and gently smooths the surface.
## River crossings are detected and painted with rock texture (bridge).

## Coarse grid step — every 4th vertex is sampled during pathfinding.
## A 512×512 map becomes a 128×128 A* graph: manageable and fast.
const _STEP: int = 4

## Road painting
const _ROAD_HALF_WIDTH: int = 3  ## Vertex radius painted each side of centerline
const _ROAD_SOIL_WEIGHT: float = 0.75  ## Soil blend weight at centerline (fades to edges)

## A* cost weights
const _SLOPE_COST: float = 120.0  ## Quadratic penalty per unit of height diff (prefers flat)
const _RIVER_COST: float = 50.0   ## Extra cost to cross a river (bridges form at cheapest crossings)
const _OCEAN_COST: float = 800.0  ## Heavy penalty for stepping onto ocean floor


static func generate(data: HeightmapData, _map_seed: int) -> void:
	## Entry point. Generates roads from the town center to the south and east exits.
	if data.town_center == Vector3.ZERO:
		return

	var tscale: Vector3 = data.terrain_scale
	var town_gx: int = clampi(roundi(data.town_center.x / tscale.x), 0, data.width - 1)
	var town_gz: int = clampi(roundi(data.town_center.z / tscale.z), 0, data.height - 1)
	var town: Vector2i = Vector2i(town_gx, town_gz)

	var w: int = data.width
	var h: int = data.height

	# Destinations: map exits + all placed POIs
	var destinations: Array[Vector2i] = []

	# Ocean-facing exits (south and east edges, aligned with town)
	destinations.append(Vector2i(town_gx, h - _STEP - 1))
	destinations.append(Vector2i(w - _STEP - 1, town_gz))

	# One road to every POI
	for i in range(data.points_of_interest.size()):
		var poi: PointOfInterest = data.points_of_interest[i]
		var px: int = clampi(roundi(poi.position.x / tscale.x), 0, w - 1)
		var pz: int = clampi(roundi(poi.position.z / tscale.z), 0, h - 1)
		destinations.append(Vector2i(px, pz))

	for di in range(destinations.size()):
		var dest: Vector2i = destinations[di]
		var path: PackedVector2Array = _astar(data, town, dest)
		if path.size() >= 2:
			_smooth_path(path)
			_flatten_road(data, path)
			_paint_road(data, path)


# ---------------------------------------------------------------------------
# A* pathfinding on coarse grid
# ---------------------------------------------------------------------------

static func _astar(data: HeightmapData, start: Vector2i, goal: Vector2i) -> PackedVector2Array:
	## Returns a path in full-grid coordinates from start to (near) goal.
	## Pathfinds on a coarse grid of step STEP for performance.
	var w: int = data.width
	var h: int = data.height
	var tscale: Vector3 = data.terrain_scale
	var s: int = _STEP

	# Coarse grid dimensions
	@warning_ignore("integer_division")
	var cw: int = (w - 1) / s + 1
	@warning_ignore("integer_division")
	var ch: int = (h - 1) / s + 1

	# Convert to coarse coordinates
	@warning_ignore("integer_division")
	var cs_start: Vector2i = Vector2i(start.x / s, start.y / s)
	@warning_ignore("integer_division")
	var cs_goal: Vector2i = Vector2i(goal.x / s, goal.y / s)

	var start_key: int = cs_start.y * cw + cs_start.x
	var goal_key: int = cs_goal.y * cw + cs_goal.x

	# g_score[key] = best known cost from start
	# parent[key]  = which coarse key this node was reached from
	var g_score: Dictionary = {}
	var parent: Dictionary = {}
	var open_set: Dictionary = {}  # key → true (present in open set)

	g_score[start_key] = 0.0
	parent[start_key] = -1
	open_set[start_key] = true

	var closed_set: Dictionary = {}
	var max_iter: int = cw * ch + 1

	while not open_set.is_empty() and max_iter > 0:
		max_iter -= 1

		# Find open node with lowest f = g + h (O(n) scan — acceptable for coarse grid)
		var cur_key: int = -1
		var best_f: float = INF
		for k in open_set:
			var g = g_score.get(k, INF)  # Variant (float) from untyped Dict
			var kx = k % cw  # Variant (int) — k is Variant from Dict iteration
			@warning_ignore("integer_division")
			var kz = k / cw  # Variant (int)
			var h_val: float = absf(float(kx - cs_goal.x)) + absf(float(kz - cs_goal.y))
			var f: float = float(g) + h_val
			if f < best_f:
				best_f = f
				cur_key = int(k)

		if cur_key < 0 or cur_key == goal_key:
			break

		open_set.erase(cur_key)
		closed_set[cur_key] = true

		@warning_ignore("integer_division")
		var cur_cx: int = cur_key % cw
		@warning_ignore("integer_division")
		var cur_cz: int = cur_key / cw
		var fx: int = clampi(cur_cx * s, 0, w - 1)  # Full-grid x
		var fz: int = clampi(cur_cz * s, 0, h - 1)  # Full-grid z
		var cur_h: float = data.get_height_at(fx, fz)
		var cur_g = g_score[cur_key]  # Variant (float) from untyped Dict

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx_c: int = cur_cx + dx
				var nz_c: int = cur_cz + dz
				if nx_c < 0 or nx_c >= cw or nz_c < 0 or nz_c >= ch:
					continue
				var nkey: int = nz_c * cw + nx_c
				if closed_set.has(nkey):
					continue

				var nx: int = clampi(nx_c * s, 0, w - 1)
				var nz: int = clampi(nz_c * s, 0, h - 1)
				var nh: float = data.get_height_at(nx, nz)

				var step_dist: float = sqrt(float(dx * dx + dz * dz))
				var height_diff: float = absf(nh - cur_h) * tscale.y
				var slope_pen: float = height_diff * height_diff * _SLOPE_COST
				var river_pen: float = _RIVER_COST if data.is_river_at(nx, nz) else 0.0
				var ocean_pen: float = _OCEAN_COST if nh < -0.05 else 0.0

				var tentative_g = cur_g + step_dist + slope_pen + river_pen + ocean_pen  # Variant (float)

				if g_score.has(nkey) and g_score[nkey] <= tentative_g:
					continue

				g_score[nkey] = tentative_g
				parent[nkey] = cur_key
				open_set[nkey] = true

	# Reconstruct path — walk parent chain from goal back to start
	var raw: Array = []
	var key: int = goal_key

	# If goal unreachable, use the closed node closest to goal
	if not parent.has(goal_key):
		var best_dist: float = INF
		for k in closed_set:
			var kx = k % cw  # Variant (int) — k is Variant from Dict iteration
			@warning_ignore("integer_division")
			var kz = k / cw  # Variant (int)
			var d: float = absf(float(kx - cs_goal.x)) + absf(float(kz - cs_goal.y))
			if d < best_dist:
				best_dist = d
				key = int(k)

	var safety: int = cw * ch
	while key != start_key and safety > 0:
		safety -= 1
		@warning_ignore("integer_division")
		var kx: int = key % cw
		@warning_ignore("integer_division")
		var kz: int = key / cw
		raw.push_back(Vector2(float(kx * s), float(kz * s)))
		var p: int = int(parent.get(key, start_key))
		if p == key:
			break
		key = p
	raw.push_back(Vector2(float(start.x), float(start.y)))

	# Reverse to get start → goal order
	var path: PackedVector2Array = PackedVector2Array()
	for i in range(raw.size() - 1, -1, -1):
		path.append(raw[i])
	return path


# ---------------------------------------------------------------------------
# Path smoothing — Chaikin pass to round sharp corners
# ---------------------------------------------------------------------------

static func _smooth_path(path: PackedVector2Array) -> void:
	## In-place Chaikin smoothing (2 passes) to soften sharp road bends.
	for _iter in range(2):
		if path.size() < 3:
			break
		var smoothed: PackedVector2Array = PackedVector2Array()
		smoothed.append(path[0])
		for i in range(path.size() - 1):
			var p0: Vector2 = path[i]
			var p1: Vector2 = path[i + 1]
			smoothed.append(p0 * 0.75 + p1 * 0.25)
			smoothed.append(p0 * 0.25 + p1 * 0.75)
		smoothed.append(path[path.size() - 1])
		# Copy back into path
		path.resize(smoothed.size())
		for i in range(smoothed.size()):
			path[i] = smoothed[i]


# ---------------------------------------------------------------------------
# Terrain flattening along road
# ---------------------------------------------------------------------------

static func _flatten_road(data: HeightmapData, path: PackedVector2Array) -> void:
	## Gently smooths the road surface by averaging each centerline point with
	## its path neighbours. Only affects a narrow strip to preserve landscape shape.
	var w: int = data.width
	var h: int = data.height
	var half_w: int = maxi(_ROAD_HALF_WIDTH / 2, 1)

	for pi in range(1, path.size() - 1):
		var gx: int = clampi(roundi(path[pi].x), 0, w - 1)
		var gz: int = clampi(roundi(path[pi].y), 0, h - 1)

		var prev_gx: int = clampi(roundi(path[pi - 1].x), 0, w - 1)
		var prev_gz: int = clampi(roundi(path[pi - 1].y), 0, h - 1)
		var next_gx: int = clampi(roundi(path[pi + 1].x), 0, w - 1)
		var next_gz: int = clampi(roundi(path[pi + 1].y), 0, h - 1)

		var target_h: float = (
			data.get_height_at(prev_gx, prev_gz)
			+ data.get_height_at(gx, gz)
			+ data.get_height_at(next_gx, next_gz)
		) / 3.0

		for dz in range(-half_w, half_w + 1):
			for dx in range(-half_w, half_w + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 1 or nx >= w - 1 or nz < 1 or nz >= h - 1:
					continue
				if dx * dx + dz * dz > half_w * half_w:
					continue
				var cur_h: float = data.get_height_at(nx, nz)
				data.set_height_at(nx, nz, lerpf(cur_h, target_h, 0.35))


# ---------------------------------------------------------------------------
# Splatmap painting
# ---------------------------------------------------------------------------

static func _paint_road(data: HeightmapData, path: PackedVector2Array) -> void:
	## Paints road texture (Soil, splatmap2.r) along the path with smooth edges.
	## River crossings are painted Rock (layer 2) to suggest a bridge.
	var w: int = data.width
	var h: int = data.height

	for pi in range(path.size()):
		var gx: int = clampi(roundi(path[pi].x), 0, w - 1)
		var gz: int = clampi(roundi(path[pi].y), 0, h - 1)
		var is_bridge: bool = data.is_river_at(gx, gz)

		for dz in range(-_ROAD_HALF_WIDTH, _ROAD_HALF_WIDTH + 1):
			for dx in range(-_ROAD_HALF_WIDTH, _ROAD_HALF_WIDTH + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 1 or nx >= w - 1 or nz < 1 or nz >= h - 1:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist > float(_ROAD_HALF_WIDTH):
					continue

				# Blend weight: full at center, tapers smoothly to edge
				var t: float = dist / float(_ROAD_HALF_WIDTH)
				var blend: float = lerpf(_ROAD_SOIL_WEIGHT, 0.1, t * t)

				var splat: Color = data.get_splatmap_weights(nx, nz)
				var splat2: Color = data.get_splatmap2_weights(nx, nz)

				if is_bridge:
					# Bridge: rock (splatmap1.b = layer 2)
					splat = splat.lerp(Color(0.0, 0.0, 1.0, 0.0), blend)
					splat2 = splat2.lerp(Color(0.0, 0.0, 0.0, 0.0), blend)
				else:
					# Road: soil (splatmap2.r = layer 4), small grass tinge
					splat = splat.lerp(Color(0.1, 0.0, 0.0, 0.0), blend)
					splat2 = splat2.lerp(Color(1.0, 0.0, 0.0, 0.0), blend)

				_normalize_and_set(data, nx, nz, splat, splat2)


static func _normalize_and_set(data: HeightmapData, x: int, z: int,
		splat: Color, splat2: Color) -> void:
	var total: float = (splat.r + splat.g + splat.b + splat.a
		+ splat2.r + splat2.g + splat2.b + splat2.a)
	if total > 0.001:
		splat.r /= total; splat.g /= total; splat.b /= total; splat.a /= total
		splat2.r /= total; splat2.g /= total; splat2.b /= total; splat2.a /= total
	else:
		splat = Color(1, 0, 0, 0)
		splat2 = Color(0, 0, 0, 0)
	data.set_splatmap_weights(x, z, splat)
	data.set_splatmap2_weights(x, z, splat2)
