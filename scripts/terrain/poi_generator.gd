extends RefCounted
## Places named points of interest on the procedural terrain.
## Candidates are sampled on a regular grid with jitter, then scored per POI type
## based on height, slope, and river proximity. A greedy selection enforces minimum
## spacing between POIs and between POIs and the town.
##
## Order in the generation pipeline: after town (so we can avoid it),
## before roads (so roads know where to route).

## Candidate sampling grid spacing (vertices)
const _SAMPLE_STEP: int = 14

## How many of each type to target [DUNGEON, RUINS, CAMP, SHRINE]
const _TARGET_COUNTS: Array[int] = [2, 3, 3, 2]

## Minimum vertex distance between any two POIs
const _MIN_POI_SPACING: int = 45

## Minimum vertex distance from the town center
const _MIN_TOWN_SPACING: int = 30

## Margin from map edges (vertices) — avoid ocean strips and mountain walls
const _EDGE_MARGIN: int = 14


static func generate(data: HeightmapData, map_seed: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 11000

	var tscale: Vector3 = data.terrain_scale
	var town_gx: int = clampi(roundi(data.town_center.x / tscale.x), 0, data.width - 1)
	var town_gz: int = clampi(roundi(data.town_center.z / tscale.z), 0, data.height - 1)

	# Build and score candidates once — reused across all types
	var candidates: Array[Vector2i] = _build_candidates(data, rng)

	# Track placed grid positions for distance checks
	var placed_positions: Array[Vector2i] = []

	for poi_type in range(4):
		var target: int = _TARGET_COUNTS[poi_type]
		var names: Array = _names_for(poi_type)
		var placed_count: int = 0

		# Score all candidates for this type and sort best-first
		var scored: Array = []
		for i in range(candidates.size()):
			var pos: Vector2i = candidates[i]
			var score: float = _score(data, pos.x, pos.y, poi_type)
			if score > 0.0:
				scored.append({"pos": pos, "score": score})
		scored.sort_custom(func(a, b) -> bool:
			return float(a["score"]) > float(b["score"]))

		for ei in range(scored.size()):
			if placed_count >= target:
				break
			var entry: Dictionary = scored[ei]
			var pos = entry["pos"]  # Variant from dict — known to be Vector2i at runtime

			# Must be far enough from town
			var dtx: int = pos.x - town_gx
			var dtz: int = pos.y - town_gz
			if dtx * dtx + dtz * dtz < _MIN_TOWN_SPACING * _MIN_TOWN_SPACING:
				continue

			# Must be far enough from all other placed POIs
			var too_close: bool = false
			for pi in range(placed_positions.size()):
				var pp: Vector2i = placed_positions[pi]
				var dx: int = pos.x - pp.x
				var dz: int = pos.y - pp.y
				if dx * dx + dz * dz < _MIN_POI_SPACING * _MIN_POI_SPACING:
					too_close = true
					break
			if too_close:
				continue

			# Place it
			var poi := PointOfInterest.new()
			poi.id = "poi_%d_%d" % [poi_type, placed_count]
			poi.type = poi_type  # Direct int → enum assignment
			poi.display_name = names[rng.randi() % names.size()]
			poi.position = Vector3(
				float(pos.x) * tscale.x,
				data.get_height_at(pos.x, pos.y) * tscale.y,
				float(pos.y) * tscale.z
			)
			data.points_of_interest.append(poi)
			placed_positions.append(pos)
			placed_count += 1

	print("[PoiGenerator] Placed %d POIs" % data.points_of_interest.size())
	for i in range(data.points_of_interest.size()):
		var p: PointOfInterest = data.points_of_interest[i]
		var _type_keys = PointOfInterest.Type.keys()
		var type_name: String = str(_type_keys[int(p.type)]) if int(p.type) < _type_keys.size() else "UNKNOWN"
		print("  [%s] %s  @ (%.0f, %.1f, %.0f)" % [
			type_name, p.display_name, p.position.x, p.position.y, p.position.z])


# ---------------------------------------------------------------------------
# Candidate grid
# ---------------------------------------------------------------------------

static func _build_candidates(data: HeightmapData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var m: int = _EDGE_MARGIN
	var s: int = _SAMPLE_STEP
	@warning_ignore("integer_division")
	var half: int = s / 3

	var z: int = m
	while z < data.height - m:
		var x: int = m
		while x < data.width - m:
			var jx: int = clampi(x + rng.randi_range(-half, half), m, data.width - m - 1)
			var jz: int = clampi(z + rng.randi_range(-half, half), m, data.height - m - 1)
			result.append(Vector2i(jx, jz))
			x += s
		z += s
	return result


# ---------------------------------------------------------------------------
# Terrain scoring per POI type
# ---------------------------------------------------------------------------

static func _score(data: HeightmapData, gx: int, gz: int, poi_type: int) -> float:
	var tscale: Vector3 = data.terrain_scale
	var world_h: float = data.get_height_at(gx, gz) * tscale.y

	# Reject ocean floor (negative height)
	if world_h < 0.0:
		return 0.0

	# Slope via central differencing
	var w: int = data.width - 1
	var h: int = data.height - 1
	var ddx: float = (data.get_height_at(mini(gx + 2, w), gz) -
		data.get_height_at(maxi(gx - 2, 0), gz)) * tscale.y / (4.0 * tscale.x)
	var ddz: float = (data.get_height_at(gx, mini(gz + 2, h)) -
		data.get_height_at(gx, maxi(gz - 2, 0))) * tscale.y / (4.0 * tscale.x)
	var slope: float = sqrt(ddx * ddx + ddz * ddz)

	# River proximity check (5-vertex radius)
	var river_near: bool = false
	for dz in range(-5, 6):
		for dx in range(-5, 6):
			if data.is_river_at(gx + dx, gz + dz):
				river_near = true
				break
		if river_near:
			break

	var score: float = 0.0
	match poi_type:
		0:  # DUNGEON — moderate height, any slope (tucked in hillsides or cliff faces)
			if world_h < 1.5 or world_h > 7.0:
				return 0.0
			score = 1.0 - absf(world_h - 4.0) / 3.5
			score += slope * 0.3  # Slight preference for slopes

		1:  # RUINS — elevated hilltop, accessible (low-moderate slope)
			if world_h < 3.0 or world_h > 9.0:
				return 0.0
			if slope > 0.7:
				return 0.0
			score = world_h / 9.0  # Higher = better viewpoint

		2:  # CAMP — flat ground, low altitude, near water
			if world_h < 0.5 or world_h > 4.5:
				return 0.0
			if slope > 0.4:
				return 0.0
			score = 1.0 - slope * 2.0
			if river_near:
				score += 0.5

		3:  # SHRINE — elevated or beside a river, gentle slope
			if world_h < 1.0 or world_h > 7.0:
				return 0.0
			if slope > 0.55:
				return 0.0
			score = 0.3 + (world_h / 7.0) * 0.4
			if river_near:
				score += 0.45

	return maxf(score, 0.0)


# ---------------------------------------------------------------------------
# Display names
# ---------------------------------------------------------------------------

static func _names_for(poi_type: int) -> Array:
	match poi_type:
		0:  # DUNGEON
			return ["Ancient Crypt", "Dark Cave", "Lost Mine", "Forgotten Vault", "Shadow Pit"]
		1:  # RUINS
			return ["Crumbled Tower", "Ancient Ruins", "Stone Circle", "Overgrown Temple", "Fallen Keep"]
		2:  # CAMP
			return ["Bandit Camp", "Goblin Outpost", "Mercenary Den", "Raider Hideout", "Marauder Camp"]
		3:  # SHRINE
			return ["Forest Shrine", "Mountain Altar", "River Shrine", "Ancient Shrine", "Sacred Stone"]
	return ["Unknown"]
