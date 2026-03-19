class_name RiverGenerator
extends RefCounted
## Generates river paths on a heightmap. Simplified approach:
## 1. Pick high points on mountain edges
## 2. March toward ocean, preferring downhill
## 3. Smooth the path
## 4. Build mesh data

const MIN_RIVERS: int = 1
const MAX_RIVERS: int = 5
const CARVE_DEPTH: float = 0.14
const CARVE_RADIUS: int = 6
const BANK_SHELF: float = 0.55  # Fraction of radius that is flat riverbed (rest is bank slope)
const BANK_RADIUS: int = 8
const FLOOD_PLAIN_RADIUS: int = 14
const FLOOD_PLAIN_DEPTH: float = 0.006
const CURVE_ERODE_EXTRA: float = 0.018
const WIDTH_MIN: float = 5.0
const WIDTH_MAX: float = 10.0


static func generate(data: HeightmapData, map_seed: int) -> Array[RiverPath]:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed + 7500
	var w: int = data.width
	var h: int = data.height
	var rivers: Array[RiverPath] = []

	# Find sources: high points near north/west edges
	var sources: Array[Vector2i] = _find_sources(data, rng, w, h)
	print("[RiverGenerator] Found %d sources" % sources.size())

	var river_count: int = rng.randi_range(MIN_RIVERS, mini(sources.size(), MAX_RIVERS))
	print("[RiverGenerator] Generating %d rivers" % river_count)
	for si in range(river_count):
		var src: Vector2i = sources[si]
		print("[RiverGenerator] River %d source: (%d, %d) h=%.3f" % [si, src.x, src.y, data.get_height_at(src.x, src.y)])
		var path: PackedVector2Array = _trace(data, rng, src, w, h)
		var end_pt: Vector2 = path[path.size() - 1] if path.size() > 0 else Vector2.ZERO
		print("[RiverGenerator] River %d: %d raw points, end (%d, %d) h=%.3f" % [si, path.size(), int(end_pt.x), int(end_pt.y), data.get_height_at(int(end_pt.x), int(end_pt.y))])
		if path.size() < 10:
			continue
		path = _smooth(path)
		var river: RiverPath = _build_path(data, path, si)
		rivers.append(river)
		_carve(data, river)
		_naturalize(data, river)

	print("[RiverGenerator] Generated %d rivers" % rivers.size())
	return rivers


static func paint_all_banks(data: HeightmapData) -> void:
	for ri in range(data.rivers.size()):
		_paint_banks(data, data.rivers[ri])


static func recarve_and_update(data: HeightmapData) -> void:
	## Re-carve riverbeds and update mesh Y coords after terrain modifications (e.g. town flattening).
	var tscale: Vector3 = data.terrain_scale
	for ri in range(data.rivers.size()):
		var river: RiverPath = data.rivers[ri]
		_carve(data, river)
		_naturalize(data, river)
		# Update point Y values from the (now re-carved) heightmap
		var pts: PackedVector3Array = river.points
		for pi in range(pts.size()):
			var gx: int = clampi(roundi(pts[pi].x / tscale.x), 0, data.width - 1)
			var gz: int = clampi(roundi(pts[pi].z / tscale.z), 0, data.height - 1)
			pts[pi].y = data.get_height_at(gx, gz) * tscale.y
		river.points = pts


# ---------------------------------------------------------------------------
# Source finding — sample mountain edges, pick highest spaced points
# ---------------------------------------------------------------------------

static func _find_sources(data: HeightmapData, rng: RandomNumberGenerator,
		w: int, h: int) -> Array[Vector2i]:
	var candidates: Array[Dictionary] = []
	# Mountain zone: roughly 5-15% from north/west edges (where the wall + foothills are)
	@warning_ignore("integer_division")
	var zone_start: int = maxi(w / 20, 5)  # Skip the very edge (steep wall)
	@warning_ignore("integer_division")
	var zone_end: int = maxi(w / 7, 20)    # End of foothills region

	# Sample along north edge (mountains)
	for _i in range(30):
		var x: int = rng.randi_range(zone_start, w - zone_start - 1)
		var z: int = rng.randi_range(zone_start, zone_end)
		var elev: float = data.get_height_at(x, z)
		if elev > 0.3:
			candidates.append({"pos": Vector2i(x, z), "h": elev})

	# Sample along west edge (mountains)
	for _i in range(30):
		var x: int = rng.randi_range(zone_start, zone_end)
		var z: int = rng.randi_range(zone_start, h - zone_start - 1)
		var elev: float = data.get_height_at(x, z)
		if elev > 0.3:
			candidates.append({"pos": Vector2i(x, z), "h": elev})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var ah: float = a["h"]
		var bh: float = b["h"]
		return ah > bh
	)

	# Pick well-spaced sources (min distance scales with map size)
	@warning_ignore("integer_division")
	var min_spacing_sq: int = (w / 5) * (w / 5)
	var result: Array[Vector2i] = []
	for ci in range(candidates.size()):
		var pos: Vector2i = candidates[ci]["pos"]
		var ok: bool = true
		for ri in range(result.size()):
			var ddx: int = pos.x - result[ri].x
			var ddz: int = pos.y - result[ri].y
			if ddx * ddx + ddz * ddz < min_spacing_sq:
				ok = false
				break
		if ok:
			result.append(pos)
		if result.size() >= MAX_RIVERS:
			break
	return result


# ---------------------------------------------------------------------------
# Tracing — simple march toward ocean, prefer downhill when possible
# ---------------------------------------------------------------------------

static func _trace(data: HeightmapData, rng: RandomNumberGenerator, start: Vector2i,
		w: int, h: int) -> PackedVector2Array:

	# --- Phase 1: Route finding — collect waypoints from source to ocean ---
	var waypoints: Array[Vector2i] = [start]
	var cx: int = start.x
	var cz: int = start.y
	var route_visited: Dictionary = {}

	for _escape in range(50):
		# Quick downhill walk to find where we get stuck
		var walk_end: Vector2i = _walk_downhill(data, cx, cz, route_visited, w, h)
		cx = walk_end.x
		cz = walk_end.y

		# Check if we've reached the ocean or map edge
		if cx <= 2 or cx >= w - 3 or cz <= 2 or cz >= h - 3:
			waypoints.append(Vector2i(cx, cz))
			break
		if data.get_height_at(cx, cz) < -0.7:
			waypoints.append(Vector2i(cx, cz))
			break

		# Compute heading from source to current position (overall river direction)
		var head_x: float = float(cx - start.x)
		var head_z: float = float(cz - start.y)
		var hlen: float = sqrt(head_x * head_x + head_z * head_z)
		if hlen > 0.0:
			head_x /= hlen
			head_z /= hlen

		# Find next lower ground via BFS, biased forward
		var cur_h: float = data.get_height_at(cx, cz)
		var target: Vector2i = _find_escape_target(data, cx, cz, cur_h, head_x, head_z, w, h)
		if target.x < 0:
			waypoints.append(Vector2i(cx, cz))
			print("[River] Route: no escape from (%d, %d) h=%.3f" % [cx, cz, cur_h])
			break

		waypoints.append(target)
		cx = target.x
		cz = target.y
		print("[River] Route waypoint: (%d, %d) h=%.3f" % [cx, cz, data.get_height_at(cx, cz)])

	print("[River] Route: %d waypoints" % waypoints.size())

	# --- Phase 2: Draw river by connecting waypoints with smooth paths ---
	var path: PackedVector2Array = PackedVector2Array()
	var draw_visited: Dictionary = {}

	for wi in range(waypoints.size() - 1):
		var from: Vector2i = waypoints[wi]
		var to: Vector2i = waypoints[wi + 1]
		var sub: PackedVector2Array = _trace_toward(
			data, rng, from.x, from.y, to.x, to.y, draw_visited, w, h)
		for si in range(sub.size()):
			path.append(sub[si])
			draw_visited[int(sub[si].y) * w + int(sub[si].x)] = true

	return path


static func _walk_downhill(data: HeightmapData, sx: int, sz: int,
		visited: Dictionary, w: int, h: int) -> Vector2i:
	## Walk downhill from (sx, sz) until stuck. Returns final position.
	## Marks cells in visited so future escapes don't revisit.
	var cx: int = sx
	var cz: int = sz

	for _step in range(maxi(w, h) * 2):
		visited[cz * w + cx] = true

		if cx <= 2 or cx >= w - 3 or cz <= 2 or cz >= h - 3:
			break
		if data.get_height_at(cx, cz) < -0.7:
			break

		var cur_h: float = data.get_height_at(cx, cz)
		var best_x: int = -1
		var best_z: int = -1
		var best_h: float = cur_h + 0.005

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cx + dx
				var nz: int = cz + dz
				if nx < 1 or nx >= w - 1 or nz < 1 or nz >= h - 1:
					continue
				if visited.has(nz * w + nx):
					continue
				var nh: float = data.get_height_at(nx, nz)
				if nh <= best_h:
					best_h = nh
					best_x = nx
					best_z = nz

		if best_x < 0:
			break
		cx = best_x
		cz = best_z

	return Vector2i(cx, cz)


static func _find_escape_target(data: HeightmapData, start_x: int, start_z: int,
		start_h: float, head_x: float, head_z: float, w: int, h: int) -> Vector2i:
	## BFS to find nearest cell that is significantly lower or ocean.
	## Only accepts targets in the forward half-plane (dot with heading >= 0).
	var target_h: float = start_h - 0.02
	var has_heading: bool = absf(head_x) + absf(head_z) > 0.01
	var searched: Dictionary = {}
	searched[start_z * w + start_x] = true
	var queue: Array[Vector2i] = [Vector2i(start_x, start_z)]

	while queue.size() > 0:
		var pos: Vector2i = queue[0]
		queue.remove_at(0)
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = pos.x + dx
				var nz: int = pos.y + dz
				if nx < 1 or nx >= w - 1 or nz < 1 or nz >= h - 1:
					continue
				var nkey: int = nz * w + nx
				if searched.has(nkey):
					continue
				searched[nkey] = true
				var nh: float = data.get_height_at(nx, nz)
				if nh <= target_h or nh < -0.7:
					# Check direction: target must be in forward half-plane
					if has_heading:
						var tdx: float = float(nx - start_x)
						var tdz: float = float(nz - start_z)
						var dot: float = tdx * head_x + tdz * head_z
						if dot < 0.0:
							queue.append(Vector2i(nx, nz))
							continue  # Skip backward targets, keep searching
					return Vector2i(nx, nz)
				queue.append(Vector2i(nx, nz))

	return Vector2i(-1, -1)


static func _trace_toward(data: HeightmapData, rng: RandomNumberGenerator,
		sx: int, sz: int, tx: int, tz: int,
		visited: Dictionary, w: int, h: int) -> PackedVector2Array:
	## Trace from (sx, sz) toward (tx, tz), allowing uphill, with RNG jitter.
	## Produces a natural-looking path instead of a teleport.
	## Enforces max 90° turn per step for smooth curves.
	var result: PackedVector2Array = PackedVector2Array()
	var cx: int = sx
	var cz: int = sz
	var prev_dx: float = float(tx - sx)
	var prev_dz: float = float(tz - sz)
	var prev_len: float = sqrt(prev_dx * prev_dx + prev_dz * prev_dz)
	if prev_len > 0.0:
		prev_dx /= prev_len
		prev_dz /= prev_len
	var max_steps: int = absi(tx - sx) + absi(tz - sz) + 20  # Budget with slack

	for _i in range(max_steps):
		# Direction to target
		var dir_x: float = float(tx - cx)
		var dir_z: float = float(tz - cz)
		var dist: float = sqrt(dir_x * dir_x + dir_z * dir_z)
		if dist < 1.5:
			break  # Close enough to target

		dir_x /= dist
		dir_z /= dist

		# Score all 8 neighbors: direction + height + jitter, reject >90° turns
		var best_score: float = -999999.0
		var best_nx: int = -1
		var best_nz: int = -1

		for dz in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dz == 0:
					continue
				var nx: int = cx + dx
				var nz: int = cz + dz
				if nx < 1 or nx >= w - 1 or nz < 1 or nz >= h - 1:
					continue
				if visited.has(nz * w + nx):
					continue

				var step_len: float = sqrt(float(dx * dx + dz * dz))
				var sdx: float = float(dx) / step_len
				var sdz: float = float(dz) / step_len

				# Reject turns > 90° from previous heading
				var momentum_dot: float = sdx * prev_dx + sdz * prev_dz
				if momentum_dot < 0.0:
					continue

				# Direction alignment with target — gentle pull, not a beeline
				var target_dot: float = sdx * dir_x + sdz * dir_z

				# Height preference — follow terrain contours
				var nh: float = data.get_height_at(nx, nz)
				var cur_h: float = data.get_height_at(cx, cz)
				var height_bonus: float = (cur_h - nh) * 5.0

				# Random jitter for meandering — strong enough to create curves
				var jitter: float = rng.randf_range(-0.8, 0.8)

				# Momentum bonus — prefer continuing in the same direction
				var momentum_bonus: float = momentum_dot * 0.6

				var score: float = target_dot * 0.8 + height_bonus + jitter + momentum_bonus
				if score > best_score:
					best_score = score
					best_nx = nx
					best_nz = nz

		if best_nx < 0:
			break  # No valid neighbors (all visited or >90° turn)

		# Update momentum direction
		var new_len: float = sqrt(float((best_nx - cx) * (best_nx - cx) + (best_nz - cz) * (best_nz - cz)))
		prev_dx = float(best_nx - cx) / new_len
		prev_dz = float(best_nz - cz) / new_len

		cx = best_nx
		cz = best_nz
		result.append(Vector2(float(cx), float(cz)))
		visited[cz * w + cx] = true

	return result


# ---------------------------------------------------------------------------
# Smoothing — simple Chaikin
# ---------------------------------------------------------------------------

static func _smooth(path: PackedVector2Array) -> PackedVector2Array:
	# Pre-pass: subsample to remove single-cell jitter (keep every 3rd point)
	var subsampled: PackedVector2Array = PackedVector2Array()
	subsampled.append(path[0])
	for i in range(3, path.size() - 1, 3):
		subsampled.append(path[i])
	subsampled.append(path[path.size() - 1])

	# Chaikin subdivision — 3 passes for smooth gentle curves
	var result: PackedVector2Array = subsampled
	for _iter in range(3):
		if result.size() < 3:
			break
		var smoothed: PackedVector2Array = PackedVector2Array()
		smoothed.append(result[0])
		for i in range(result.size() - 1):
			var p0: Vector2 = result[i]
			var p1: Vector2 = result[i + 1]
			smoothed.append(p0 * 0.75 + p1 * 0.25)
			smoothed.append(p0 * 0.25 + p1 * 0.75)
		smoothed.append(result[result.size() - 1])
		result = smoothed
	return result


# ---------------------------------------------------------------------------
# Build RiverPath from grid coords
# ---------------------------------------------------------------------------

static func _build_path(data: HeightmapData, path: PackedVector2Array,
		index: int) -> RiverPath:
	var river: RiverPath = RiverPath.new()
	river.id = "river_%d" % index
	river.color_index = index
	var tscale: Vector3 = data.terrain_scale
	var count: int = path.size()

	# Subsample to ~150 mesh points max
	@warning_ignore("integer_division")
	var step: int = maxi(1, count / 150)

	var points: PackedVector3Array = PackedVector3Array()
	var widths: PackedFloat32Array = PackedFloat32Array()

	var pi: int = 0
	while pi < count:
		var gx: float = path[pi].x
		var gz: float = path[pi].y
		var ix: int = clampi(roundi(gx), 0, data.width - 1)
		var iz: int = clampi(roundi(gz), 0, data.height - 1)
		var cur_h: float = data.get_height_at(ix, iz)
		points.append(Vector3(gx * tscale.x, cur_h * tscale.y, gz * tscale.z))

		var t: float = float(pi) / float(maxi(count - 1, 1))
		widths.append(lerpf(WIDTH_MIN, WIDTH_MAX, sqrt(t)))
		pi += step

	# Always include last point
	if pi - step != count - 1 and count > 0:
		var gx: float = path[count - 1].x
		var gz: float = path[count - 1].y
		var ix: int = clampi(roundi(gx), 0, data.width - 1)
		var iz: int = clampi(roundi(gz), 0, data.height - 1)
		points.append(Vector3(gx * tscale.x, data.get_height_at(ix, iz) * tscale.y, gz * tscale.z))
		widths.append(WIDTH_MAX)

	river.points = points
	river.widths = widths
	return river


# ---------------------------------------------------------------------------
# Carve riverbed into heightmap
# ---------------------------------------------------------------------------

static func _carve(data: HeightmapData, river: RiverPath) -> void:
	## Carves a channel with a clear bank profile:
	##   Center (0 to BANK_SHELF): flat riverbed at full depth
	##   Bank wall (BANK_SHELF to 1.0): steep cubic ramp from riverbed up to terrain
	##   Lip (just outside radius): slight extra cut for a defined bank edge
	## Enforces monotonically decreasing bed height along the river (no uphill flow).
	var inv_sx: float = 1.0 / data.terrain_scale.x
	var inv_sz: float = 1.0 / data.terrain_scale.z
	var lip_radius: int = CARVE_RADIUS + 2
	var point_count: int = river.points.size()

	# --- Pre-pass: compute monotonically decreasing bed heights ---
	# Each point's bed = terrain_height - CARVE_DEPTH, but never higher than the previous.
	var bed_heights: PackedFloat32Array = PackedFloat32Array()
	bed_heights.resize(point_count)
	var max_bed: float = INF  # Tracks the lowest bed so far (monotonic ceiling)

	for pi in range(point_count):
		var wp: Vector3 = river.points[pi]
		var gx: int = clampi(roundi(wp.x * inv_sx), 0, data.width - 1)
		var gz: int = clampi(roundi(wp.z * inv_sz), 0, data.height - 1)
		var terrain_h: float = data.get_height_at(gx, gz)
		var desired_bed: float = terrain_h - CARVE_DEPTH
		# Enforce: this bed can't be higher than the previous point's bed
		if desired_bed > max_bed:
			desired_bed = max_bed
		max_bed = desired_bed
		bed_heights[pi] = desired_bed

	# --- Main carve pass: use bed_heights for consistent downhill flow ---
	for pi in range(point_count):
		var wp: Vector3 = river.points[pi]
		var gx: int = roundi(wp.x * inv_sx)
		var gz: int = roundi(wp.z * inv_sz)
		var bed_h: float = bed_heights[pi]

		for dz in range(-lip_radius, lip_radius + 1):
			for dx in range(-lip_radius, lip_radius + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 0 or nx >= data.width or nz < 0 or nz >= data.height:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist > float(lip_radius):
					continue

				var cur_h: float = data.get_height_at(nx, nz)
				var target_h: float = cur_h
				var t: float = dist / float(CARVE_RADIUS)

				if t <= BANK_SHELF:
					# Flat riverbed — set to bed height
					target_h = bed_h
				elif t <= 1.0:
					# Bank wall — cubic ramp from bed height up to terrain
					var bank_t: float = (t - BANK_SHELF) / (1.0 - BANK_SHELF)
					var ramp: float = bank_t * bank_t * bank_t
					target_h = lerpf(bed_h, cur_h, ramp)
				else:
					# Lip zone — small cut for visible bank edge
					var lip_t: float = (dist - float(CARVE_RADIUS)) / float(lip_radius - CARVE_RADIUS)
					var lip_depth: float = CARVE_DEPTH * 0.15 * (1.0 - lip_t)
					target_h = cur_h - lip_depth

				# Only carve down, never raise terrain
				if target_h < cur_h:
					data.set_height_at(nx, nz, target_h)


# ---------------------------------------------------------------------------
# Naturalize — curve erosion, flood plain, bank smoothing
# ---------------------------------------------------------------------------

static func _naturalize(data: HeightmapData, river: RiverPath) -> void:
	## Post-carve pass that makes the river valley look naturally formed:
	## 1) Curve erosion: outer banks of bends get deeper cuts (cut-banks)
	## 2) Flood plain: wide, subtle depression sloping toward the river
	## 3) Bank smoothing: average heights near channel edges for soft transitions
	var inv_sx: float = 1.0 / data.terrain_scale.x
	var inv_sz: float = 1.0 / data.terrain_scale.z
	var pts: PackedVector3Array = river.points
	var count: int = pts.size()
	if count < 3:
		return

	# --- Pass 1: Curve erosion (cut-banks and point bars) ---
	for pi in range(1, count - 1):
		# Compute curvature from three consecutive points
		var prev_p: Vector3 = pts[pi - 1]
		var cur_p: Vector3 = pts[pi]
		var next_p: Vector3 = pts[pi + 1]

		var d0x: float = cur_p.x - prev_p.x
		var d0z: float = cur_p.z - prev_p.z
		var d1x: float = next_p.x - cur_p.x
		var d1z: float = next_p.z - cur_p.z

		# Turn direction: cross product sign (positive = left turn, negative = right)
		var cross: float = d0x * d1z - d0z * d1x
		var seg_len: float = sqrt(d0x * d0x + d0z * d0z)
		if seg_len < 0.001:
			continue
		# Curvature magnitude (0 = straight, higher = sharper bend)
		var curvature: float = absf(cross) / (seg_len * seg_len)
		curvature = minf(curvature, 1.0)  # Cap for stability
		if curvature < 0.01:
			continue

		# Forward direction at this point
		var fwd_x: float = (d0x + d1x) * 0.5
		var fwd_z: float = (d0z + d1z) * 0.5
		var fwd_len: float = sqrt(fwd_x * fwd_x + fwd_z * fwd_z)
		if fwd_len < 0.001:
			continue
		fwd_x /= fwd_len
		fwd_z /= fwd_len

		# Perpendicular pointing toward outer bank (sign of cross determines side)
		var sign_val: float = 1.0 if cross > 0.0 else -1.0
		var outer_x: float = -fwd_z * sign_val
		var outer_z: float = fwd_x * sign_val

		var gx: int = roundi(cur_p.x * inv_sx)
		var gz: int = roundi(cur_p.z * inv_sz)
		var erode_r: int = CARVE_RADIUS + 2

		for dz in range(-erode_r, erode_r + 1):
			for dx in range(-erode_r, erode_r + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 0 or nx >= data.width or nz < 0 or nz >= data.height:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist > float(erode_r) or dist < 0.5:
					continue

				# How much this cell is on the outer vs inner bank
				var norm_dx: float = float(dx) / dist
				var norm_dz: float = float(dz) / dist
				var outer_dot: float = norm_dx * outer_x + norm_dz * outer_z

				if outer_dot > 0.1:
					# Outer bank: erode extra (cut-bank)
					var falloff: float = 1.0 - dist / float(erode_r)
					var extra: float = CURVE_ERODE_EXTRA * curvature * outer_dot * falloff
					data.set_height_at(nx, nz, data.get_height_at(nx, nz) - extra)
				elif outer_dot < -0.1:
					# Inner bank: deposit slightly (point bar) — only within carve radius
					if dist <= float(CARVE_RADIUS):
						var falloff: float = 1.0 - dist / float(CARVE_RADIUS)
						var deposit: float = CURVE_ERODE_EXTRA * 0.3 * curvature * absf(outer_dot) * falloff
						data.set_height_at(nx, nz, data.get_height_at(nx, nz) + deposit)

	# --- Pass 2: Flood plain — subtle wide depression toward river ---
	for pi in range(0, count, 3):  # Every 3rd point to save performance
		var wp: Vector3 = pts[pi]
		var gx: int = roundi(wp.x * inv_sx)
		var gz: int = roundi(wp.z * inv_sz)
		var river_h: float = data.get_height_at(
			clampi(gx, 0, data.width - 1),
			clampi(gz, 0, data.height - 1))

		for dz in range(-FLOOD_PLAIN_RADIUS, FLOOD_PLAIN_RADIUS + 1):
			for dx in range(-FLOOD_PLAIN_RADIUS, FLOOD_PLAIN_RADIUS + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 0 or nx >= data.width or nz < 0 or nz >= data.height:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist <= float(CARVE_RADIUS) or dist > float(FLOOD_PLAIN_RADIUS):
					continue  # Skip already-carved channel
				# Gentle slope: strongest near channel, fading outward
				var t: float = (dist - float(CARVE_RADIUS)) / float(FLOOD_PLAIN_RADIUS - CARVE_RADIUS)
				var depression: float = FLOOD_PLAIN_DEPTH * (1.0 - t * t)
				var cur_h: float = data.get_height_at(nx, nz)
				# Only depress if terrain is above river level (don't dig below the river)
				if cur_h > river_h:
					data.set_height_at(nx, nz, cur_h - depression)

	# --- Pass 3: Bank smoothing — flatten small cliffs, preserve big ones (>2m) ---
	# Measures height difference between each bank cell and the nearest river bed.
	# If the drop is < 2m world units, smooth aggressively to create a gentle slope.
	# Big cliffs (>2m) are left alone so gorges and valleys stay dramatic.
	var smooth_ring_inner: int = CARVE_RADIUS - 1
	var smooth_ring_outer: int = CARVE_RADIUS + 6  # Wide ring for gradual slopes
	var tscale_y: float = data.terrain_scale.y
	var cliff_threshold: float = 2.0  # World units — only preserve cliffs taller than this

	for _smooth_pass in range(3):  # 3 passes for very smooth results
		var smooth_edits: Dictionary = {}

		for pi in range(0, count, 2):  # Every 2nd point
			var wp: Vector3 = pts[pi]
			var gx: int = roundi(wp.x * inv_sx)
			var gz: int = roundi(wp.z * inv_sz)
			# River bed height at this point
			var river_h: float = data.get_height_at(
				clampi(gx, 0, data.width - 1),
				clampi(gz, 0, data.height - 1)) * tscale_y

			for dz in range(-smooth_ring_outer, smooth_ring_outer + 1):
				for dx in range(-smooth_ring_outer, smooth_ring_outer + 1):
					var nx: int = gx + dx
					var nz: int = gz + dz
					if nx < 2 or nx >= data.width - 2 or nz < 2 or nz >= data.height - 2:
						continue
					var dist: float = sqrt(float(dx * dx + dz * dz))
					if dist < float(smooth_ring_inner) or dist > float(smooth_ring_outer):
						continue

					# Height difference between this cell and the river bed
					var cell_h: float = data.get_height_at(nx, nz) * tscale_y
					var drop: float = absf(cell_h - river_h)

					# Skip big cliffs — they stay as dramatic gorge walls
					if drop > cliff_threshold:
						continue

					# Smoothing strength: stronger for small drops, fades near threshold
					var drop_factor: float = 1.0 - clampf(drop / cliff_threshold, 0.0, 1.0)

					# Distance falloff: stronger near channel edge
					var dist_t: float = (dist - float(smooth_ring_inner)) / float(smooth_ring_outer - smooth_ring_inner)
					var dist_factor: float = 1.0 - dist_t

					# 5×5 average for stronger smoothing
					var avg: float = 0.0
					var avg_count: int = 0
					for sz in range(-2, 3):
						for sx in range(-2, 3):
							var ax: int = nx + sx
							var az: int = nz + sz
							if ax >= 0 and ax < data.width and az >= 0 and az < data.height:
								avg += data.get_height_at(ax, az)
								avg_count += 1
					avg /= float(avg_count)

					var blend_strength: float = drop_factor * dist_factor * 0.7
					var key: int = nz * data.width + nx
					var blended: float = lerpf(data.get_height_at(nx, nz), avg, blend_strength)
					if not smooth_edits.has(key):
						smooth_edits[key] = blended
					else:
						var prev: float = smooth_edits[key]
						smooth_edits[key] = (prev + blended) * 0.5

		# Apply smoothed heights
		var keys: Array = smooth_edits.keys()
		for ki in range(keys.size()):
			var key: int = keys[ki]
			@warning_ignore("integer_division")
			var iz: int = key / data.width
			var ix: int = key - iz * data.width
			data.set_height_at(ix, iz, smooth_edits[key])


# ---------------------------------------------------------------------------
# Paint banks: slope-adapted textures + wet ground darkening
# ---------------------------------------------------------------------------

## Splatmap targets — Color(grass, dirt, rock, snow)
const _SPLAT_DIRT: Color = Color(0.1, 0.8, 0.1, 0.0)
const _SPLAT_ROCK: Color = Color(0.0, 0.1, 0.85, 0.05)
const _SPLAT_WET_GRASS: Color = Color(0.5, 0.45, 0.05, 0.0)
const WET_RADIUS: int = 20  ## Radius for wet ground darkening beyond banks
const WET_DARKEN: float = 0.15  ## Max splatmap blend toward dirt for wet ground
const BANK_CLIFF_THRESHOLD: float = 2.0  ## Height drop (world units) above this → rock banks


static func _paint_banks(data: HeightmapData, river: RiverPath) -> void:
	var inv_sx: float = 1.0 / data.terrain_scale.x
	var inv_sz: float = 1.0 / data.terrain_scale.z
	var tscale_y: float = data.terrain_scale.y

	for pi in range(river.points.size()):
		var wp: Vector3 = river.points[pi]
		var gx: int = roundi(wp.x * inv_sx)
		var gz: int = roundi(wp.z * inv_sz)
		# River bed height at this point
		var river_h: float = data.get_height_at(
			clampi(gx, 0, data.width - 1),
			clampi(gz, 0, data.height - 1)) * tscale_y

		for dz in range(-WET_RADIUS, WET_RADIUS + 1):
			for dx in range(-WET_RADIUS, WET_RADIUS + 1):
				var nx: int = gx + dx
				var nz: int = gz + dz
				if nx < 1 or nx >= data.width - 1 or nz < 1 or nz >= data.height - 1:
					continue
				var dist: float = sqrt(float(dx * dx + dz * dz))
				if dist > float(WET_RADIUS):
					continue

				var cur: Color = data.get_splatmap_weights(nx, nz)

				if dist <= float(BANK_RADIUS):
					# --- Inner zone: bank painting based on height drop ---
					var t: float = dist / float(BANK_RADIUS)
					var cell_h: float = data.get_height_at(nx, nz) * tscale_y
					var drop: float = absf(cell_h - river_h)

					# Choose bank material based on height difference
					var bank_target: Color
					if drop > BANK_CLIFF_THRESHOLD:
						# Big cliff (>2m) → rock
						bank_target = _SPLAT_ROCK
					elif drop > BANK_CLIFF_THRESHOLD * 0.5:
						# Moderate drop (1-2m) → blend rock and dirt
						var rock_t: float = (drop - BANK_CLIFF_THRESHOLD * 0.5) / (BANK_CLIFF_THRESHOLD * 0.5)
						bank_target = _SPLAT_DIRT.lerp(_SPLAT_ROCK, rock_t)
					else:
						# Small drop (<1m) → wet grass/dirt mix
						bank_target = _SPLAT_WET_GRASS if t > 0.6 else _SPLAT_DIRT

					var blend: float = (1.0 - t) * 0.8
					var blended: Color = cur.lerp(bank_target, blend)
					_normalize_and_set(data, nx, nz, blended)

				else:
					# --- Outer zone: wet ground darkening ---
					var wet_t: float = (dist - float(BANK_RADIUS)) / float(WET_RADIUS - BANK_RADIUS)
					var wet_blend: float = (1.0 - wet_t * wet_t) * WET_DARKEN
					var blended: Color = cur.lerp(_SPLAT_WET_GRASS, wet_blend)
					_normalize_and_set(data, nx, nz, blended)


static func _normalize_and_set(data: HeightmapData, x: int, z: int, splat: Color) -> void:
	var total: float = splat.r + splat.g + splat.b + splat.a
	if total > 0.001:
		splat.r /= total
		splat.g /= total
		splat.b /= total
		splat.a /= total
	data.set_splatmap_weights(x, z, splat)
