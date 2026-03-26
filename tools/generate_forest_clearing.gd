@tool
extends EditorScript
## Run from Editor → Script → Run to generate terrain for forest_clearing.tres

const GRASS: int = 0
const DIRT: int = 1
const STONE: int = 2
const WATER: int = 3
const PATH: int = 4
const DARK_GRASS: int = 6

const W: int = 40
const H: int = 40

func _run() -> void:
	var map: MapData = load("res://data/maps/forest_clearing.tres") as MapData
	if not map:
		print("ERROR: Could not load forest_clearing.tres")
		return

	map.grid_width = W
	map.grid_height = H
	map.terrain_cells.resize(W * H)
	map.terrain_heights.resize(W * H)

	# Fill with dark grass (forest)
	map.terrain_cells.fill(DARK_GRASS)
	map.terrain_heights.fill(0)

	# Clearing in the center (roughly 14x14 area centered around 25,25)
	for z in range(H):
		for x in range(W):
			var cx: float = float(x) - 25.0
			var cz: float = float(z) - 25.0
			var dist: float = sqrt(cx * cx + cz * cz)

			# Central clearing: grass
			if dist < 7.0:
				map.terrain_cells[z * W + x] = GRASS
			# Transition ring: mix of grass and dark grass
			elif dist < 9.0:
				if (x + z) % 3 == 0:
					map.terrain_cells[z * W + x] = GRASS
			# Stone circle in the very center (ritual stones)
			if dist < 2.5 and dist > 1.5:
				map.terrain_cells[z * W + x] = STONE
				map.terrain_heights[z * W + x] = 1

	# Dirt path from entrance (west edge) to clearing
	for x in range(0, 22):
		var pz: int = 20
		# Slight winding
		if x > 5 and x < 15:
			pz = 20 + (x % 3 - 1)
		for dz in range(-1, 2):
			var tz: int = pz + dz
			if tz >= 0 and tz < H:
				map.terrain_cells[tz * W + x] = PATH if dz == 0 else DIRT

	# Small pond in the southeast
	for z in range(30, 36):
		for x in range(32, 38):
			var px: float = float(x) - 34.5
			var pz: float = float(z) - 32.5
			if sqrt(px * px + pz * pz) < 2.8:
				map.terrain_cells[z * W + x] = WATER

	# Some height variation: gentle hills at corners
	for z in range(H):
		for x in range(W):
			var edge_dist: float = minf(minf(float(x), float(W - 1 - x)), minf(float(z), float(H - 1 - z)))
			if edge_dist < 3.0:
				map.terrain_heights[z * W + x] = 1
			if edge_dist < 1.0:
				map.terrain_heights[z * W + x] = 2

	ResourceSaver.save(map, "res://data/maps/forest_clearing.tres")
	print("[ForestClearing] Terrain generated and saved! %dx%d grid" % [W, H])
