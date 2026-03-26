class_name OverworldHeightmapGenerator
extends RefCounted
## Generates an island-shaped overworld HeightmapData in the style of classic
## FF/DQ overworlds: ocean on all 4 edges, central landmass with 6 biomes
## (plains, forest, hills, mountains, arid, wetlands).
##
## Key differences from BiomeHeightmapGenerator:
##   - Island falloff mask instead of directional mountain/ocean edges
##   - terrain_scale = Vector3(3, 20, 3): 3m per vertex, dramatic height range
##   - No roads — overworld uses direct free-roaming movement
##   - Single ocean WaterZone covering the whole map
##   - Tiny walk-through props via OverworldPropRegistry

const _TerrainErosion := preload("res://scripts/terrain/terrain_erosion.gd")
const _RiverGenerator := preload("res://scripts/terrain/river_generator.gd")
const _PoiGenerator := preload("res://scripts/terrain/poi_generator.gd")

## Material-LIB base path (same textures as area maps)
const _LIB := "res://assets/3D/Material-LIB/Material-LIB/Nature/"
const _LIB_ROOT := "res://assets/3D/Material-LIB/Material-LIB/"
const _TERRAIN_LIB := "res://assets/terrain_textures/"

## Splatmap layer defs — 12 layers across 3 splatmaps
## Splatmap1 (0-3): Grass, Sand, Rock, Snow
## Splatmap2 (4-7): Soil, Pebbles, Cliff, Moss
## Splatmap3 (8-11): Mud, Cracked, ForestFloor, Cobblestone
## "src": "terrain" uses _TERRAIN_LIB, "lib" uses _LIB/_LIB_ROOT
const _LAYER_DEFS: Array[Dictionary] = [
	{"folder": "Grass",          "base": "Grass",           "uv": 15.0, "label": "Grass"},
	{"folder": "Sand",           "base": "Sand",            "uv": 12.0, "label": "Sand"},
	{"folder": "Rock",           "base": "Rock",            "uv": 8.0,  "label": "Rock"},
	{"folder": "Snow",           "base": "Snow",            "uv": 10.0, "label": "Snow"},
	{"folder": "Soil",           "base": "Soil",            "uv": 10.0, "label": "Soil"},
	{"folder": "Pebbles",        "base": "Pebbles",         "uv": 8.0,  "label": "Pebbles"},
	{"folder": "Cliff",          "base": "Cliff",           "uv": 6.0,  "label": "Cliff"},
	{"folder": "Moss",           "base": "Moss",            "uv": 12.0, "label": "Moss"},
	{"folder": "Mud",            "base": "Mud",             "uv": 10.0, "label": "Mud"},
	{"folder": "Cracked",        "base": "Cracked",         "uv": 8.0,  "label": "Cracked"},
	{"folder": "ForestFloor",    "base": "ForestFloor",     "uv": 12.0, "label": "ForestFloor"},
	{"folder": "Cobblestone",    "base": "Cobblestone",     "uv": 8.0,  "label": "Cobblestone"},
]


## Biome profile for overworld terrain generation.
class BiomeProfile:
	var id: String
	var height_base: float
	var height_amplitude: float
	var noise_frequency: float
	var noise_octaves: int
	var splat_weights: Color   ## Splatmap1: R=Grass G=Sand B=Rock A=Snow
	var splat_weights2: Color  ## Splatmap2: R=Soil G=Pebbles B=Cliff A=Moss

	func _init(
		p_id: String, p_base: float, p_amp: float,
		p_freq: float, p_oct: int, p_splat: Color,
		p_splat2: Color = Color(0, 0, 0, 0)
	) -> void:
		id = p_id
		height_base = p_base
		height_amplitude = p_amp
		noise_frequency = p_freq
		noise_octaves = p_oct
		splat_weights = p_splat
		splat_weights2 = p_splat2


## Lazy-cached biomes
static var _biomes_cache: Array = []


static func _get_biomes() -> Array:
	if not _biomes_cache.is_empty():
		return _biomes_cache
	_biomes_cache = [
		#                                                 splat1(Grass Sand Rock Snow)    splat2(Soil Pebbles Cliff Moss)
		BiomeProfile.new("plains",    0.15, 0.20, 0.015, 3, Color(0.90, 0.00, 0.04, 0.0), Color(0.04, 0.0,  0.0,  0.02)),
		BiomeProfile.new("forest",    0.25, 0.35, 0.025, 4, Color(0.70, 0.00, 0.08, 0.0), Color(0.04, 0.0,  0.0,  0.18)),
		BiomeProfile.new("hills",     0.45, 0.45, 0.022, 4, Color(0.30, 0.00, 0.55, 0.0), Color(0.0,  0.12, 0.03, 0.0)),
		BiomeProfile.new("mountains", 0.65, 0.70, 0.030, 5, Color(0.05, 0.00, 0.75, 0.1), Color(0.0,  0.08, 0.12, 0.0)),
		BiomeProfile.new("arid",      0.08, 0.18, 0.018, 3, Color(0.10, 0.78, 0.08, 0.0), Color(0.14, 0.0,  0.0,  0.0)),
		BiomeProfile.new("wetlands",  0.03, 0.10, 0.012, 2, Color(0.55, 0.00, 0.08, 0.0), Color(0.22, 0.0,  0.0,  0.15)),
	]
	return _biomes_cache


## Island warp noise (lazy) — used to give the coastline an organic shape
static var _island_warp: FastNoiseLite = null
static var _island_warp2: FastNoiseLite = null  ## Second warp layer for X/Z independent distortion
static var _forest_placement: FastNoiseLite = null  ## Cellular noise for forest patch centers
static var _forest_shape: FastNoiseLite = null       ## Simplex noise for organic edge distortion


static func _init_noises(map_seed: int) -> void:
	# Large-scale shape distortion
	_island_warp = FastNoiseLite.new()
	_island_warp.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_island_warp.frequency = 0.012
	_island_warp.fractal_octaves = 3
	_island_warp.fractal_lacunarity = 2.0
	_island_warp.fractal_gain = 0.5
	_island_warp.seed = map_seed + 7500
	# Second layer — warps independently for asymmetric coastlines
	_island_warp2 = FastNoiseLite.new()
	_island_warp2.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_island_warp2.frequency = 0.025
	_island_warp2.fractal_octaves = 4
	_island_warp2.fractal_lacunarity = 2.2
	_island_warp2.fractal_gain = 0.45
	_island_warp2.seed = map_seed + 8200

	# Forest patch placement — cellular creates distinct blob centers
	_forest_placement = FastNoiseLite.new()
	_forest_placement.noise_type = FastNoiseLite.TYPE_CELLULAR
	_forest_placement.frequency = 0.007
	_forest_placement.fractal_octaves = 1
	_forest_placement.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	_forest_placement.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	_forest_placement.seed = map_seed + 9000

	# Forest edge distortion — makes patch shapes organic and irregular
	_forest_shape = FastNoiseLite.new()
	_forest_shape.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_forest_shape.frequency = 0.03
	_forest_shape.fractal_octaves = 3
	_forest_shape.fractal_lacunarity = 2.0
	_forest_shape.fractal_gain = 0.5
	_forest_shape.seed = map_seed + 9500


## Computed at generation time — main continent placed first, second island fills remaining space
static var _islands: Array[Dictionary] = []

## Mountain peaks — {"cx", "cz" in -1..1 normalized, "height" in normalized units, "radius" in normalized}
static var _mountains: Array[Dictionary] = []

## Ridge polylines (normalized coords) — used for zone assignment via signed distance
## Each is an Array[Vector2] of spine points (not fillers), ordered along the ridge.
static var _ridge_main: Array[Vector2] = []
static var _ridge_sw: Array[Vector2] = []
static var _ridge_se: Array[Vector2] = []
static var _ridge_north_spur: Array[Vector2] = []


static func _compute_islands(map_width: int, map_height: int) -> void:
	## Places the main continent, scans its warped extent, then fits the second island
	## in the largest remaining gap.
	_islands.clear()
	# height_boost: extra normalized height added to land on this island
	# edge_sharp: smoothstep range (lower = steeper cliffs at coastline)
	var main := {"cx": -0.25, "cz": 0.0, "radius": 0.70, "height_boost": 0.0, "edge_sharp": 0.30}
	_islands.append(main)

	# Coarse scan: find the rightmost extent of the main continent (mask > 0.1)
	var step: int = maxi(map_width / 64, 4)
	var max_nx: float = -1.0  # rightmost normalized x where main island has land
	for sz in range(0, map_height, step):
		for sx in range(0, map_width, step):
			var mask: float = _island_mask_single(sx, sz, map_width, map_height, main)
			if mask > 0.1:
				var nx: float = float(sx) / float(map_width - 1) * 2.0 - 1.0
				max_nx = maxf(max_nx, nx)

	# Place second island in the remaining space to the right
	var gap_center: float = (max_nx + 1.0) * 0.5 + max_nx  # midpoint between edge and right border
	var gap_size: float = 1.0 - max_nx  # space available to the right
	var second_radius: float = gap_size * 0.55  # fill ~55% of the gap
	second_radius = clampf(second_radius, 0.20, 0.55)
	# Nudge vertically with slight offset for visual variety
	var second := {"cx": clampf(gap_center, -0.8, 0.8), "cz": 0.10, "radius": second_radius,
		"height_boost": 0.60, "edge_sharp": 0.10}  # elevated island with steep cliffs
	_islands.append(second)

	# Mountain ranges across the main continent
	_mountains.clear()
	var mcx: float = main["cx"]

	# --- Main ridge: runs diagonally NW to E across northern part ---
	var main_ridge: Array[Dictionary] = [
		{"ox": -0.28, "oz": -0.12, "h": 2.50, "r": 0.09},
		{"ox": -0.22, "oz": -0.16, "h": 3.40, "r": 0.07},
		{"ox": -0.16, "oz": -0.20, "h": 4.00, "r": 0.06},
		{"ox": -0.10, "oz": -0.22, "h": 4.80, "r": 0.06},
		{"ox": -0.04, "oz": -0.19, "h": 3.50, "r": 0.07},
		{"ox":  0.02, "oz": -0.17, "h": 4.20, "r": 0.06},
		{"ox":  0.08, "oz": -0.20, "h": 5.20, "r": 0.05},  # highest peak
		{"ox":  0.13, "oz": -0.18, "h": 4.60, "r": 0.06},
		{"ox":  0.18, "oz": -0.14, "h": 3.80, "r": 0.07},
		{"ox":  0.24, "oz": -0.10, "h": 2.80, "r": 0.09},
		{"ox":  0.28, "oz": -0.06, "h": 2.00, "r": 0.10},
	]
	# Filler peaks between main ridge points for density
	var ridge_fill: Array[Dictionary] = [
		{"ox": -0.19, "oz": -0.18, "h": 3.00, "r": 0.05},
		{"ox": -0.13, "oz": -0.21, "h": 3.60, "r": 0.05},
		{"ox": -0.07, "oz": -0.20, "h": 3.80, "r": 0.05},
		{"ox":  0.05, "oz": -0.18, "h": 3.20, "r": 0.05},
		{"ox":  0.11, "oz": -0.19, "h": 4.00, "r": 0.05},
		{"ox":  0.21, "oz": -0.12, "h": 3.00, "r": 0.06},
	]

	# --- Northern spur: branches off the main ridge toward the north ---
	var north_spur: Array[Dictionary] = [
		{"ox": -0.06, "oz": -0.26, "h": 3.20, "r": 0.06},
		{"ox": -0.02, "oz": -0.30, "h": 3.80, "r": 0.05},
		{"ox":  0.03, "oz": -0.33, "h": 3.00, "r": 0.06},
		{"ox":  0.00, "oz": -0.28, "h": 2.60, "r": 0.05},
		{"ox":  0.06, "oz": -0.25, "h": 2.80, "r": 0.06},
	]

	# --- SW branch: forks off the main ridge toward the southwest, fading into foothills ---
	var sw_branch: Array[Dictionary] = [
		{"ox": -0.12, "oz": -0.14, "h": 3.20, "r": 0.06},  # fork point from main ridge
		{"ox": -0.18, "oz": -0.06, "h": 3.60, "r": 0.05},
		{"ox": -0.24, "oz":  0.02, "h": 3.00, "r": 0.06},
		{"ox": -0.28, "oz":  0.10, "h": 2.40, "r": 0.07},
		{"ox": -0.30, "oz":  0.18, "h": 1.80, "r": 0.08},  # fades out
		# fillers
		{"ox": -0.15, "oz": -0.10, "h": 3.40, "r": 0.04},
		{"ox": -0.21, "oz": -0.02, "h": 3.20, "r": 0.04},
		{"ox": -0.26, "oz":  0.06, "h": 2.60, "r": 0.05},
	]

	# --- SE range: separate smaller range in the southeast, runs NE-SW ---
	var se_range: Array[Dictionary] = [
		{"ox":  0.22, "oz":  0.06, "h": 2.00, "r": 0.07},  # starts low
		{"ox":  0.16, "oz":  0.12, "h": 2.80, "r": 0.06},
		{"ox":  0.10, "oz":  0.18, "h": 3.20, "r": 0.05},
		{"ox":  0.04, "oz":  0.22, "h": 2.60, "r": 0.06},
		{"ox": -0.02, "oz":  0.26, "h": 2.00, "r": 0.07},  # fades out
		# fillers
		{"ox":  0.19, "oz":  0.09, "h": 2.40, "r": 0.04},
		{"ox":  0.13, "oz":  0.15, "h": 3.00, "r": 0.04},
		{"ox":  0.07, "oz":  0.20, "h": 2.80, "r": 0.04},
	]

	# Build ridge polylines from spine points (excluding fillers) for zone assignment
	_ridge_main.clear()
	for i in range(main_ridge.size()):
		_ridge_main.append(Vector2(mcx + main_ridge[i]["ox"], main_ridge[i]["oz"]))
	_ridge_sw.clear()
	for i in range(5):  # first 5 are spine, rest are fillers
		_ridge_sw.append(Vector2(mcx + sw_branch[i]["ox"], sw_branch[i]["oz"]))
	_ridge_se.clear()
	for i in range(5):  # first 5 are spine, rest are fillers
		_ridge_se.append(Vector2(mcx + se_range[i]["ox"], se_range[i]["oz"]))
	_ridge_north_spur.clear()
	for i in range(north_spur.size()):
		_ridge_north_spur.append(Vector2(mcx + north_spur[i]["ox"], north_spur[i]["oz"]))

	# Add all peaks
	var all_peaks: Array[Array] = [main_ridge, ridge_fill, north_spur,
		sw_branch, se_range]
	for gi in range(all_peaks.size()):
		var group: Array = all_peaks[gi]
		for pi in range(group.size()):
			var rp: Dictionary = group[pi]
			_mountains.append({
				"cx": mcx + rp["ox"],
				"cz": rp["oz"],
				"height": rp["h"],
				"radius": rp["r"],
			})


static func _island_mask_single(x: int, z: int, map_width: int, map_height: int, isle: Dictionary) -> float:
	## Computes island mask for a single island definition.
	var nx: float = float(x) / float(map_width - 1) * 2.0 - 1.0
	var nz: float = float(z) / float(map_height - 1) * 2.0 - 1.0
	var warp_x: float = 0.0
	var warp_z: float = 0.0
	var warp_r: float = 0.0
	if _island_warp != null:
		warp_x = _island_warp.get_noise_2d(float(x), float(z)) * 0.25
		warp_z = _island_warp.get_noise_2d(float(x) + 500.0, float(z) + 500.0) * 0.25
	if _island_warp2 != null:
		warp_r = _island_warp2.get_noise_2d(float(x), float(z)) * 0.20
	var dx: float = (nx + warp_x) - isle["cx"]
	var dz: float = (nz + warp_z) - isle["cz"]
	var r: float = isle["radius"]
	var edge_sharp: float = isle.get("edge_sharp", 0.30)
	var dist: float = sqrt(dx * dx + dz * dz) / r + warp_r
	return 1.0 - smoothstep(0.50, 0.50 + edge_sharp, dist)


static func _island_mask(x: int, z: int, map_width: int, map_height: int) -> float:
	## Returns 1.0 in the interior, 0.0 at ocean edges, smooth transition in between.
	## Evaluates all computed islands and takes the highest mask value.
	var best: float = 0.0
	for i in range(_islands.size()):
		var mask: float = _island_mask_single(x, z, map_width, map_height, _islands[i])
		best = maxf(best, mask)
	return best


static func _mountain_height(x: int, z: int, map_width: int, map_height: int) -> float:
	## Returns extra height from nearby mountain peaks. Sharp conical falloff for jagged ridges.
	var nx: float = float(x) / float(map_width - 1) * 2.0 - 1.0
	var nz: float = float(z) / float(map_height - 1) * 2.0 - 1.0
	# Ridge noise adds craggy detail to mountain slopes
	var ridge: float = 0.0
	if _island_warp2 != null:
		ridge = absf(_island_warp2.get_noise_2d(float(x) * 1.5, float(z) * 1.5)) * 0.6
	var total: float = 0.0
	for i in range(_mountains.size()):
		var mtn: Dictionary = _mountains[i]
		var dx: float = nx - mtn["cx"]
		var dz: float = nz - mtn["cz"]
		var dist: float = sqrt(dx * dx + dz * dz)
		var r: float = mtn["radius"]
		if dist < r:
			# Sharp conical falloff — steep sides, pointed peak
			var t: float = dist / r
			var falloff: float = (1.0 - t) * (1.0 - t)  # quadratic = steeper than quartic
			# Ridge noise makes slopes jagged and uneven
			falloff *= (1.0 + ridge * (1.0 - t))
			total += mtn["height"] * falloff
	return total


static func _island_height_boost(x: int, z: int, map_width: int, map_height: int) -> float:
	## Returns the height_boost of the dominant island at this point.
	var best_mask: float = 0.0
	var boost: float = 0.0
	for i in range(_islands.size()):
		var mask: float = _island_mask_single(x, z, map_width, map_height, _islands[i])
		if mask > best_mask:
			best_mask = mask
			boost = _islands[i].get("height_boost", 0.0)
	return boost * best_mask


static func _island_index_at(x: int, z: int, map_width: int, map_height: int) -> int:
	## Returns which island this vertex belongs to (1-based), or 0 for ocean.
	var best_mask: float = 0.0
	var best_idx: int = 0
	for i in range(_islands.size()):
		var mask: float = _island_mask_single(x, z, map_width, map_height, _islands[i])
		if mask > best_mask:
			best_mask = mask
			best_idx = i + 1  # 1-based: island 1, island 2, etc.
	if best_mask < 0.15:
		return 0  # ocean
	return best_idx


static func generate(
	map_width: int = 512, map_depth: int = 512, map_seed: int = 42
) -> HeightmapData:
	## Creates a complete overworld HeightmapData: island terrain, biomes, rivers,
	## splatmap, water, town, and POIs. No roads — overworld traversal is direct.
	var data := HeightmapData.new()
	data.id = "overworld_%d" % map_seed
	data.display_name = "Overworld"
	data.width = map_width
	data.height = map_depth
	data.terrain_scale = Vector3(3.0, 20.0, 3.0)
	data.is_overworld = true

	data.initialize(0.0)
	data.island_indices.resize(map_width * map_depth)
	data.forest_density.resize(map_width * map_depth)
	data.zone_ids.resize(map_width * map_depth)

	# --- Initialize island warp noise + compute island placement ---
	_init_noises(map_seed)
	_compute_islands(map_width, map_depth)

	# --- Biome selection noises ---
	var temp_noise := FastNoiseLite.new()
	temp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temp_noise.frequency = 0.006
	temp_noise.fractal_octaves = 2
	temp_noise.seed = map_seed

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.005
	moisture_noise.fractal_octaves = 2
	moisture_noise.seed = map_seed + 1000

	# --- Detail height noise ---
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.018
	detail_noise.fractal_octaves = 4
	detail_noise.fractal_lacunarity = 2.0
	detail_noise.fractal_gain = 0.5
	detail_noise.seed = map_seed + 2000

	# --- Per-biome noise layers ---
	var biomes: Array = _get_biomes()
	var biome_count: int = biomes.size()
	var biome_noises: Array[FastNoiseLite] = []
	for i in range(biome_count):
		var bp: BiomeProfile = biomes[i]
		var bn := FastNoiseLite.new()
		bn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		bn.frequency = bp.noise_frequency
		bn.fractal_octaves = bp.noise_octaves
		bn.fractal_lacunarity = 2.0
		bn.fractal_gain = 0.5
		bn.seed = map_seed + 3000 + i * 100
		biome_noises.append(bn)

	# --- Pass 1: Heights + biome splat storage ---
	var biome_splats := PackedColorArray()
	biome_splats.resize(map_width * map_depth)
	var biome_splats2 := PackedColorArray()
	biome_splats2.resize(map_width * map_depth)
	# Per-vertex island mask, stored for Pass 2 splatmap (beach detection uses it)
	var island_masks := PackedFloat32Array()
	island_masks.resize(map_width * map_depth)

	for z in range(map_depth):
		for x in range(map_width):
			var island: float = _island_mask(x, z, map_width, map_depth)
			var island_boost: float = _island_height_boost(x, z, map_width, map_depth)
			island_masks[z * map_width + x] = island
			data.island_indices[z * map_width + x] = _island_index_at(x, z, map_width, map_depth)

			var temp_val: float = temp_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var moist_val: float = moisture_noise.get_noise_2d(x, z) * 0.5 + 0.5
			var biome_weights: Array[float] = _get_biome_weights(temp_val, moist_val)

			var h: float = 0.0
			var splat := Color(0, 0, 0, 0)
			var splat2 := Color(0, 0, 0, 0)
			for bi in range(biome_count):
				var w: float = biome_weights[bi]
				if w < 0.001:
					continue
				var bp: BiomeProfile = biomes[bi]
				var bn: FastNoiseLite = biome_noises[bi]
				var noise_val: float = bn.get_noise_2d(x, z)
				var biome_h: float = bp.height_base + noise_val * bp.height_amplitude
				h += biome_h * w
				splat.r += bp.splat_weights.r * w
				splat.g += bp.splat_weights.g * w
				splat.b += bp.splat_weights.b * w
				splat.a += bp.splat_weights.a * w
				splat2.r += bp.splat_weights2.r * w
				splat2.g += bp.splat_weights2.g * w
				splat2.b += bp.splat_weights2.b * w
				splat2.a += bp.splat_weights2.a * w

			# Fine detail
			h += detail_noise.get_noise_2d(x, z) * 0.10

			# Mountain peaks — added before island mask so they're part of the landmass
			h += _mountain_height(x, z, map_width, map_depth)

			# Apply island mask: interior keeps full height, edges sink to ocean floor
			# +0.15 base lift keeps all land well above sea level
			# island_boost raises elevated islands (e.g. cliff island)
			h = (h + 0.15 + island_boost) * island - (1.0 - island) * 1.50

			data.set_height_at(x, z, h)

			if island < 0.25:
				# Deep ocean floor — dark rock/soil
				biome_splats[z * map_width + x] = Color(0.0, 0.15, 0.45, 0.0)
				biome_splats2[z * map_width + x] = Color(0.20, 0.0, 0.20, 0.0)
			else:
				biome_splats[z * map_width + x] = splat
				biome_splats2[z * map_width + x] = splat2

	# --- Zone assignment: classify vertices into regions using ridge polylines ---
	_compute_zone_ids(data, map_width, map_depth)

	# --- Forest zones: noise-based organic patches (zone-aware) ---
	_compute_forest_zones(data, map_width, map_depth, island_masks)

	# --- Erosion ---
	_TerrainErosion.apply(data, map_seed)

	# --- Pass 2: Splatmap (slope/shore/snow base) ---
	_assign_splatmap(data, biome_splats, biome_splats2, island_masks, map_width, map_depth)

	# --- Pass 3: Zone-based noise variation (overwrites per-zone textures) ---
	rebuild_splatmap_from_zones(data)

	# --- Texture layers ---
	_add_textured_layers(data)

	# --- Water zones ---
	_add_water(data, map_seed)

	# --- Points of interest ---
	_PoiGenerator.generate(data, map_seed)

	print("[OverworldGenerator] %dx%d overworld generated (seed %d)" % [map_width, map_depth, map_seed])

	return data


# ---------------------------------------------------------------------------
# Zone assignment
# ---------------------------------------------------------------------------

## Zone IDs — painted in the zone map layer of the ORA file
const ZONE_OCEAN: int = 0
const ZONE_GRASSLAND: int = 1     ## Green plains — default land
const ZONE_DESERT: int = 2        ## Arid sandy terrain
const ZONE_MOUNTAIN: int = 3      ## Rocky highland
const ZONE_SNOW_PEAK: int = 4     ## High-altitude snow
const ZONE_FARMLAND: int = 5      ## Tilled soil
const ZONE_GRAVEL_PATH: int = 6   ## Pebble paths / roads
const ZONE_CLIFF: int = 7         ## Steep cliff faces
const ZONE_DEEP_FOREST: int = 8   ## Dense mossy forest
const ZONE_SWAMP: int = 9         ## Muddy wetlands
const ZONE_DEATHBLIGHT: int = 10  ## Cracked dead wasteland
const ZONE_JUNGLE: int = 11       ## Lush tropical forest floor
const ZONE_FORTRESS: int = 12     ## Stone / cobblestone fortifications

## Deathblight patch center (normalized coords) — placed in the middle of the jungle
const _DEATHBLIGHT_CENTER := Vector2(-0.15, 0.12)
const _DEATHBLIGHT_RADIUS: float = 0.12


static func _compute_zone_ids(data: HeightmapData, map_width: int, map_height: int) -> void:
	## Assigns a zone ID to each vertex using Z-interpolation on ridge polylines.
	## For roughly horizontal ridges: compare point.z vs ridge.z at point.x → north/south.
	## For roughly vertical ridges: compare point.x vs ridge.x at point.z → west/east.
	for z in range(map_height):
		for x in range(map_width):
			var idx: int = z * map_width + x

			var isle_idx: int = data.island_indices[idx]
			if isle_idx == 0 or data.get_height_at(x, z) < 0.0:
				data.zone_ids[idx] = ZONE_OCEAN
				continue
			if isle_idx == 2:
				data.zone_ids[idx] = ZONE_FORTRESS
				continue

			var nx: float = float(x) / float(map_width - 1) * 2.0 - 1.0
			var nz: float = float(z) / float(map_height - 1) * 2.0 - 1.0

			# Main ridge runs W→E: check if point is north (nz < ridge_z)
			var north_of_main: bool = _is_north_of(nx, nz, _ridge_main)
			# SW branch runs NE→SW (more vertical): check if point is west (nx < ridge_x)
			var west_of_sw: bool = _is_west_of(nx, nz, _ridge_sw)

			if north_of_main:
				# Fortress pocket between main ridge and north spur
				if not _ridge_north_spur.is_empty():
					var d_main: float = _dist_to_polyline(nx, nz, _ridge_main)
					var d_spur: float = _dist_to_polyline(nx, nz, _ridge_north_spur)
					if d_main < 0.10 and d_spur < 0.10:
						data.zone_ids[idx] = ZONE_FORTRESS
						continue
				data.zone_ids[idx] = ZONE_SWAMP
			elif west_of_sw:
				data.zone_ids[idx] = ZONE_DESERT
			else:
				# Deathblight circle in the jungle
				var dx: float = nx - _DEATHBLIGHT_CENTER.x
				var dz: float = nz - _DEATHBLIGHT_CENTER.y
				if dx * dx + dz * dz < _DEATHBLIGHT_RADIUS * _DEATHBLIGHT_RADIUS:
					data.zone_ids[idx] = ZONE_DEATHBLIGHT
				else:
					data.zone_ids[idx] = ZONE_JUNGLE


static func _is_north_of(px: float, pz: float, ridge: Array[Vector2]) -> bool:
	## Returns true if point is north of the ridge (pz < ridge's interpolated z at px).
	if ridge.size() < 2:
		return false
	for i in range(ridge.size() - 1):
		var ax: float = ridge[i].x
		var bx: float = ridge[i + 1].x
		var min_x: float = minf(ax, bx)
		var max_x: float = maxf(ax, bx)
		if px >= min_x and px <= max_x:
			var t: float = (px - ax) / (bx - ax) if absf(bx - ax) > 0.001 else 0.0
			var ridge_z: float = ridge[i].y + t * (ridge[i + 1].y - ridge[i].y)
			return pz < ridge_z
	# Outside ridge X range — compare to nearest endpoint
	if px < minf(ridge[0].x, ridge[ridge.size() - 1].x):
		return pz < ridge[0].y
	return pz < ridge[ridge.size() - 1].y


static func _is_west_of(px: float, pz: float, ridge: Array[Vector2]) -> bool:
	## Returns true if point is west of the ridge (px < ridge's interpolated x at pz).
	if ridge.size() < 2:
		return false
	for i in range(ridge.size() - 1):
		var az: float = ridge[i].y
		var bz: float = ridge[i + 1].y
		var min_z: float = minf(az, bz)
		var max_z: float = maxf(az, bz)
		if pz >= min_z and pz <= max_z:
			var t: float = (pz - az) / (bz - az) if absf(bz - az) > 0.001 else 0.0
			var ridge_x: float = ridge[i].x + t * (ridge[i + 1].x - ridge[i].x)
			return px < ridge_x
	# Outside ridge Z range — compare to nearest endpoint
	if pz < minf(ridge[0].y, ridge[ridge.size() - 1].y):
		return px < ridge[0].x
	return px < ridge[ridge.size() - 1].x


static func _dist_to_polyline(px: float, pz: float, poly: Array[Vector2]) -> float:
	## Returns unsigned distance from point to the closest point on the polyline.
	var best: float = INF
	for i in range(poly.size() - 1):
		var a: Vector2 = poly[i]
		var b: Vector2 = poly[i + 1]
		var ab: Vector2 = b - a
		var ap := Vector2(px - a.x, pz - a.y)
		var len_sq: float = ab.dot(ab)
		if len_sq < 0.0001:
			continue
		var t: float = clampf(ap.dot(ab) / len_sq, 0.0, 1.0)
		var closest: Vector2 = a + ab * t
		var d: float = Vector2(px - closest.x, pz - closest.y).length()
		best = minf(best, d)
	return best


# ---------------------------------------------------------------------------
# Forest density
# ---------------------------------------------------------------------------

static func _compute_forest_zones(data: HeightmapData, map_width: int, map_height: int,
		island_masks: PackedFloat32Array) -> void:
	## Noise-based organic forest patches. Cellular noise picks where forests go,
	## simplex noise distorts edges for natural shapes. Filtered by elevation and island.
	var tscale_y: float = data.terrain_scale.y

	for z in range(map_height):
		for x in range(map_width):
			var idx: int = z * map_width + x
			var island: float = island_masks[idx]

			# No forest on ocean or coastline
			if island < 0.50:
				data.forest_density[idx] = 0
				continue

			var h: float = data.get_height_at(x, z) * tscale_y

			# No forest on mountains (above 12m) or very low coast (below 1.5m)
			if h > 12.0 or h < 1.5:
				data.forest_density[idx] = 0
				continue

			# Cellular noise: -1 at cell center, ~0 at cell edge
			var cell_val: float = _forest_placement.get_noise_2d(float(x), float(z))

			# Simplex distortion: warps the threshold for irregular edges
			var warp: float = _forest_shape.get_noise_2d(float(x), float(z)) * 0.18

			# Zone overrides for forest density
			var zone: int = data.zone_ids[idx] if not data.zone_ids.is_empty() else ZONE_GRASSLAND
			if zone == ZONE_DESERT or zone == ZONE_DEATHBLIGHT or zone == ZONE_SNOW_PEAK \
				or zone == ZONE_CLIFF or zone == ZONE_GRAVEL_PATH or zone == ZONE_FORTRESS:
				data.forest_density[idx] = 0
				continue
			if zone == ZONE_JUNGLE or zone == ZONE_DEEP_FOREST:
				data.forest_density[idx] = 255
				continue
			if zone == ZONE_SWAMP or zone == ZONE_FARMLAND or zone == ZONE_MOUNTAIN:
				data.forest_density[idx] = 0
				continue

			# Only the core of each cell becomes forest (with warped edge)
			if cell_val + warp < -0.65:
				data.forest_density[idx] = 255
			else:
				data.forest_density[idx] = 0


# ---------------------------------------------------------------------------
# Biome blending
# ---------------------------------------------------------------------------

static func _get_biome_weights(temperature: float, moisture: float) -> Array[float]:
	## Maps temperature (0=cold, 1=hot) and moisture (0=dry, 1=wet) to blend weights.
	## Order matches _get_biomes(): [plains, forest, hills, mountains, arid, wetlands]
	var weights: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
	# Plains: moderate temp, low-mid moisture
	weights[0] = _affinity(temperature, 0.5, 0.30) * _affinity(moisture, 0.35, 0.30)
	# Forest: moderate temp, high moisture
	weights[1] = _affinity(temperature, 0.5, 0.25) * _affinity(moisture, 0.75, 0.25)
	# Hills: warm, moderate moisture
	weights[2] = _affinity(temperature, 0.65, 0.25) * _affinity(moisture, 0.50, 0.30)
	# Mountains: any temp, low moisture (dry highlands)
	weights[3] = _affinity(temperature, 0.40, 0.40) * _affinity(moisture, 0.15, 0.20)
	# Arid: hot, dry
	weights[4] = _affinity(temperature, 0.85, 0.20) * _affinity(moisture, 0.15, 0.20)
	# Wetlands: warm, very high moisture
	weights[5] = _affinity(temperature, 0.60, 0.30) * _affinity(moisture, 0.92, 0.12)

	var total: float = 0.0
	for i in range(weights.size()):
		total += weights[i]
	if total > 0.001:
		for i in range(weights.size()):
			weights[i] /= total
	else:
		weights[0] = 1.0  # Fallback to plains
	return weights


static func _affinity(value: float, center: float, radius: float) -> float:
	var dist: float = absf(value - center)
	if dist >= radius:
		return 0.0
	var t: float = dist / radius
	return 1.0 - t * t


# ---------------------------------------------------------------------------
# Splatmap rebuild from imported zone map
# ---------------------------------------------------------------------------

static func rebuild_splatmap_from_zones(data: HeightmapData) -> void:
	## Re-applies zone-based splatmap tinting after a zone map import.
	## Uses noise to blend multiple textures within each zone for natural variation.
	var w: int = data.width
	var h: int = data.height

	# Noise layers for intra-zone variation (different frequencies for different scales)
	var noise_lo := FastNoiseLite.new()
	noise_lo.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_lo.frequency = 0.008  # Large patches
	noise_lo.seed = 42

	var noise_hi := FastNoiseLite.new()
	noise_hi.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise_hi.frequency = 0.035  # Fine detail
	noise_hi.seed = 137

	var noise_cell := FastNoiseLite.new()
	noise_cell.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise_cell.frequency = 0.015  # Organic patches
	noise_cell.seed = 271
	noise_cell.cellular_return_type = FastNoiseLite.RETURN_DISTANCE

	for z in range(h):
		for x in range(w):
			var idx: int = z * w + x
			var zone: int = data.zone_ids[idx] if not data.zone_ids.is_empty() else ZONE_GRASSLAND

			# Sample noise at this position (range ~-1..1, remap to 0..1)
			var fx: float = float(x)
			var fz: float = float(z)
			var n_lo: float = noise_lo.get_noise_2d(fx, fz) * 0.5 + 0.5
			var n_hi: float = noise_hi.get_noise_2d(fx, fz) * 0.5 + 0.5
			var n_cell: float = clampf(noise_cell.get_noise_2d(fx, fz) * 0.5 + 0.5, 0.0, 1.0)
			# Blend: 60% large scale, 25% detail, 15% cellular
			var n: float = clampf(n_lo * 0.6 + n_hi * 0.25 + n_cell * 0.15, 0.0, 1.0)

			# Also factor in slope for cliff/rock breakup
			var slope: float = 0.0
			if x > 0 and x < w - 1 and z > 0 and z < h - 1:
				var tsy: float = data.terrain_scale.y
				var tsx: float = data.terrain_scale.x
				var dx: float = (data.get_height_at(x + 1, z) - data.get_height_at(x - 1, z)) * tsy / (2.0 * tsx)
				var dz: float = (data.get_height_at(x, z + 1) - data.get_height_at(x, z - 1)) * tsy / (2.0 * tsx)
				slope = clampf(sqrt(dx * dx + dz * dz), 0.0, 1.0)

			## Channel reference:
			## Splatmap1: R=Grass(0) G=Sand(1) B=Rock(2) A=Snow(3)
			## Splatmap2: R=Soil(4) G=Pebbles(5) B=Cliff(6) A=Moss(7)
			## Splatmap3: R=Mud(8) G=Cracked(9) B=ForestFloor(10) A=Cobblestone(11)
			var weights: Array[float] = [0,0,0,0, 0,0,0,0, 0,0,0,0]

			# Use thresholded noise to create distinct patches rather than subtle blending.
			# n_patch: hard-edged patches (0 or 1 with soft transition)
			var n_patch: float = clampf((n - 0.45) / 0.10, 0.0, 1.0)      # sharp cutoff around 0.45
			var n_patch2: float = clampf((n_cell - 0.4) / 0.15, 0.0, 1.0) # cellular patches
			var n_patch3: float = clampf((n_hi - 0.5) / 0.12, 0.0, 1.0)   # fine patches

			if zone == ZONE_OCEAN:
				# Dark seabed: sand + rock (underwater, mostly hidden by water mesh)
				weights[1] = 0.40                            # Sand
				weights[2] = 0.50                            # Rock
				weights[6] = 0.10                            # Cliff
			elif zone == ZONE_GRASSLAND:
				# Mostly grass, distinct soil patches, moss clusters
				weights[0] = 0.80 * n_patch + 0.20          # Grass: 20-100%
				weights[4] = 0.70 * (1.0 - n_patch)         # Soil: 0-70% (inverse of grass)
				weights[7] = 0.50 * n_patch2                 # Moss: 0-50% in cell patches
				weights[2] = slope * 0.6                     # Rock on slopes
			elif zone == ZONE_DESERT:
				# Sand with rock outcrops and cracked earth zones
				weights[1] = 0.75 * n_patch + 0.15          # Sand: 15-90%
				weights[2] = 0.60 * (1.0 - n_patch)         # Rock outcrops: 0-60%
				weights[9] = 0.55 * n_patch2                 # Cracked earth patches: 0-55%
				weights[5] = 0.30 * n_patch3                 # Pebble streaks: 0-30%
			elif zone == ZONE_MOUNTAIN:
				# Rock with pebble scree fields and cliff on slopes
				weights[2] = 0.70 * n_patch + 0.15          # Rock: 15-85%
				weights[5] = 0.65 * (1.0 - n_patch)         # Pebbles/scree: 0-65%
				weights[6] = slope * 0.8                     # Cliff on steep parts
				weights[0] = 0.40 * n_patch2 * (1.0 - slope) # Grass in flat spots: 0-40%
			elif zone == ZONE_SNOW_PEAK:
				# Snow with exposed rock patches
				weights[3] = 0.75 * n_patch + 0.15          # Snow: 15-90%
				weights[2] = 0.65 * (1.0 - n_patch)         # Rock: 0-65%
				weights[6] = slope * 0.6                     # Cliff on slopes
				weights[5] = 0.25 * n_patch2                 # Pebble/scree: 0-25%
			elif zone == ZONE_FARMLAND:
				# Soil with grass strips and muddy patches
				weights[4] = 0.70 * n_patch + 0.15          # Soil: 15-85%
				weights[0] = 0.65 * (1.0 - n_patch)         # Grass strips: 0-65%
				weights[8] = 0.50 * n_patch2                 # Mud patches: 0-50%
				weights[5] = 0.25 * n_patch3                 # Pebble paths: 0-25%
			elif zone == ZONE_GRAVEL_PATH:
				# Pebbles with cobblestone sections and soil edges
				weights[5] = 0.65 * n_patch + 0.15          # Pebbles: 15-80%
				weights[11] = 0.60 * (1.0 - n_patch)        # Cobblestone sections: 0-60%
				weights[4] = 0.40 * n_patch2                 # Soil edges: 0-40%
				weights[1] = 0.20 * n_patch3                 # Sand streaks: 0-20%
			elif zone == ZONE_CLIFF:
				# Cliff with rock faces and moss in crevices
				weights[6] = 0.70 * n_patch + 0.20          # Cliff: 20-90%
				weights[2] = 0.60 * (1.0 - n_patch)         # Rock: 0-60%
				weights[5] = 0.35 * n_patch2                 # Pebble scree: 0-35%
				weights[7] = 0.30 * n_patch3 * (1.0 - slope) # Moss in crevices: 0-30%
			elif zone == ZONE_DEEP_FOREST:
				# Moss and forest floor in large alternating patches
				weights[7] = 0.75 * n_patch + 0.10          # Moss: 10-85%
				weights[10] = 0.70 * (1.0 - n_patch)        # Forest floor: 0-70%
				weights[0] = 0.45 * n_patch2                 # Grass clearings: 0-45%
				weights[4] = 0.30 * n_patch3                 # Soil patches: 0-30%
				weights[2] = slope * 0.5                     # Rock on slopes
			elif zone == ZONE_SWAMP:
				# Mud with moss banks and soil islands
				weights[8] = 0.70 * n_patch + 0.15          # Mud: 15-85%
				weights[7] = 0.65 * (1.0 - n_patch)         # Moss banks: 0-65%
				weights[4] = 0.45 * n_patch2                 # Soil islands: 0-45%
				weights[0] = 0.25 * n_patch3                 # Sparse grass tufts: 0-25%
			elif zone == ZONE_DEATHBLIGHT:
				# Cracked earth with cliff rubble zones
				weights[9] = 0.70 * n_patch + 0.15          # Cracked: 15-85%
				weights[6] = 0.60 * (1.0 - n_patch)         # Cliff rubble: 0-60%
				weights[4] = 0.35 * n_patch2                 # Soil/dust: 0-35%
				weights[2] = 0.30 * n_patch3                 # Rock fragments: 0-30%
			elif zone == ZONE_JUNGLE:
				# Forest floor with moss patches and grass breaks
				weights[10] = 0.70 * n_patch + 0.15         # Forest floor: 15-85%
				weights[7] = 0.60 * (1.0 - n_patch)         # Moss: 0-60%
				weights[0] = 0.40 * n_patch2                 # Grass: 0-40%
				weights[8] = 0.30 * n_patch3                 # Mud patches: 0-30%
			elif zone == ZONE_FORTRESS:
				# Cobblestone with rock sections and dirt fill
				weights[11] = 0.70 * n_patch + 0.15         # Cobblestone: 15-85%
				weights[2] = 0.60 * (1.0 - n_patch)         # Rock: 0-60%
				weights[5] = 0.40 * n_patch2                 # Pebble fill: 0-40%
				weights[4] = 0.25 * n_patch3                 # Soil in cracks: 0-25%

			# Pack into splatmap Colors
			var splat := Color(weights[0], weights[1], weights[2], weights[3])
			var splat2 := Color(weights[4], weights[5], weights[6], weights[7])
			var splat3 := Color(weights[8], weights[9], weights[10], weights[11])

			data.set_splatmap_weights(x, z, splat)
			data.set_splatmap2_weights(x, z, splat2)
			data.set_splatmap3_weights(x, z, splat3)

	# Also update forest density per zone
	if not data.forest_density.is_empty():
		for z2 in range(h):
			for x2 in range(w):
				var idx2: int = z2 * w + x2
				var zone2: int = data.zone_ids[idx2]
				if zone2 == ZONE_DESERT or zone2 == ZONE_DEATHBLIGHT or zone2 == ZONE_SWAMP \
					or zone2 == ZONE_SNOW_PEAK or zone2 == ZONE_CLIFF \
					or zone2 == ZONE_GRAVEL_PATH or zone2 == ZONE_FORTRESS \
					or zone2 == ZONE_FARMLAND or zone2 == ZONE_MOUNTAIN:
					data.forest_density[idx2] = 0
				elif zone2 == ZONE_JUNGLE or zone2 == ZONE_DEEP_FOREST:
					data.forest_density[idx2] = 255


# ---------------------------------------------------------------------------
# Splatmap Pass 2
# ---------------------------------------------------------------------------

static func _assign_splatmap(
	data: HeightmapData,
	biome_splats: PackedColorArray, biome_splats2: PackedColorArray,
	island_masks: PackedFloat32Array,
	map_width: int, map_height: int
) -> void:
	var tscale_y: float = data.terrain_scale.y
	var tscale_x: float = data.terrain_scale.x

	for z in range(map_height):
		for x in range(map_width):
			var splat: Color = biome_splats[z * map_width + x]
			var splat2: Color = biome_splats2[z * map_width + x]
			var h: float = data.get_height_at(x, z)
			var world_h: float = h * tscale_y
			var island: float = island_masks[z * map_width + x]

			# --- Slope-based cliff/scree detection ---
			var h_left: float = data.get_height_at(x - 1, z) * tscale_y
			var h_right: float = data.get_height_at(x + 1, z) * tscale_y
			var h_up: float = data.get_height_at(x, z - 1) * tscale_y
			var h_down: float = data.get_height_at(x, z + 1) * tscale_y
			var ddx: float = (h_right - h_left) / (2.0 * tscale_x)
			var ddz: float = (h_down - h_up) / (2.0 * tscale_x)
			var slope: float = sqrt(ddx * ddx + ddz * ddz)

			if slope > 0.5:
				if slope < 1.0:
					var scree_t: float = clampf((slope - 0.5) / 0.5, 0.0, 1.0)
					splat = splat.lerp(Color(0.1, 0.0, 0.6, 0.0), scree_t * 0.6)
					splat2 = splat2.lerp(Color(0.0, 0.4, 0.0, 0.0), scree_t * 0.6)
				else:
					var cliff_t: float = clampf((slope - 1.0) / 0.73, 0.0, 1.0)
					splat = splat.lerp(Color(0.0, 0.0, 0.3, 0.0), cliff_t)
					splat2 = splat2.lerp(Color(0.0, 0.0, 0.7, 0.0), cliff_t)

			# --- Height-based overrides ---
			# Snow caps above ~24m world height (h > 1.2 with tscale_y=20)
			if world_h > 22.0:
				var snow_t: float = clampf((world_h - 22.0) / 6.0, 0.0, 1.0)
				splat = splat.lerp(Color(0.0, 0.0, 0.2, 0.8), snow_t)

			# --- Beach / shoreline (where island mask is transitioning and height is low) ---
			if island > 0.15 and island < 0.70 and world_h > -2.0 and world_h < 3.5 and slope < 0.30:
				var shore_t: float = clampf(1.0 - (island - 0.15) / 0.55, 0.0, 1.0)
				# Wet sand at waterline, dry sand further inland
				var wet: float = clampf(1.0 - (island - 0.15) / 0.25, 0.0, 1.0)
				var sand_color: Color = Color(0.05, 0.90, 0.05, 0.0).lerp(Color(0.25, 0.65, 0.10, 0.0), 1.0 - wet)
				splat = splat.lerp(sand_color, shore_t)
				splat2 = splat2.lerp(Color(0.0, 0.0, 0.0, 0.0), shore_t * 0.6)

			# Zone-based splatmap is now handled entirely by rebuild_splatmap_from_zones.
			# During generation we skip per-zone tinting — it will be applied after.
			var splat3 := Color(0, 0, 0, 0)

			# --- Normalize all 12 channels ---
			var total_w: float = (splat.r + splat.g + splat.b + splat.a
				+ splat2.r + splat2.g + splat2.b + splat2.a
				+ splat3.r + splat3.g + splat3.b + splat3.a)
			if total_w > 0.001:
				splat.r /= total_w; splat.g /= total_w; splat.b /= total_w; splat.a /= total_w
				splat2.r /= total_w; splat2.g /= total_w; splat2.b /= total_w; splat2.a /= total_w
				splat3.r /= total_w; splat3.g /= total_w; splat3.b /= total_w; splat3.a /= total_w
			else:
				splat = Color(1, 0, 0, 0)
				splat2 = Color(0, 0, 0, 0)
				splat3 = Color(0, 0, 0, 0)

			data.set_splatmap_weights(x, z, splat)
			data.set_splatmap2_weights(x, z, splat2)
			data.set_splatmap3_weights(x, z, splat3)


# ---------------------------------------------------------------------------
# Texture layers
# ---------------------------------------------------------------------------

static func refresh_texture_layers(data: HeightmapData) -> void:
	## Public wrapper — clears and reloads all texture layers from current _LAYER_DEFS.
	data.texture_layers.clear()
	_add_textured_layers(data)


static func _find_texture(base_path: String, suffix: String) -> Texture2D:
	## Tries .png then .jpg for a given base path + suffix (e.g. "-B").
	for ext in [".png", ".jpg"]:
		var p: String = base_path + suffix + ext
		if ResourceLoader.exists(p):
			return load(p) as Texture2D
	return null


static func _add_textured_layers(data: HeightmapData) -> void:
	for i in range(_LAYER_DEFS.size()):
		var def: Dictionary = _LAYER_DEFS[i]
		var layer := TerrainTextureLayer.new()
		layer.name = def["label"]
		layer.uv_scale = def["uv"]
		var base_path: String = _TERRAIN_LIB + def["folder"] + "/" + def["base"]
		layer.albedo_texture = _find_texture(base_path, "-B")
		layer.normal_texture = _find_texture(base_path, "-N")
		layer.roughness_texture = _find_texture(base_path, "-R")
		layer.metallic_texture = _find_texture(base_path, "-M")
		if not layer.albedo_texture:
			print("[TerrainTex] WARNING: no albedo for layer %d (%s) at %s" % [i, def["label"], base_path])
		data.texture_layers.append(layer)


# ---------------------------------------------------------------------------
# Water zones
# ---------------------------------------------------------------------------

static func _add_water(data: HeightmapData, map_seed: int) -> void:
	## Adds one full-map ocean zone (sits at y=0, island terrain rises above it)
	## plus a few interior lakes at low basins.
	var tscale: Vector3 = data.terrain_scale
	var world_w: float = float(data.width) * tscale.x
	var world_d: float = float(data.height) * tscale.z

	# Ocean as 4 non-overlapping border strips — N/S span full width, W/E fill the gap
	var border_frac: float = 0.45
	var bw: float = world_w * border_frac
	var bd: float = world_d * border_frac
	var mid_h: float = world_d - bd * 2.0  # height of W/E strips (between N and S)
	var shallow_col := Color(0.15, 0.40, 0.60, 0.85)
	var deep_col := Color(0.03, 0.10, 0.25, 0.95)
	var strip_defs: Array[Dictionary] = [
		{"id": "ocean_north", "center": Vector3(world_w * 0.5, 0.0, bd * 0.5), "size": Vector2(world_w, bd)},
		{"id": "ocean_south", "center": Vector3(world_w * 0.5, 0.0, world_d - bd * 0.5), "size": Vector2(world_w, bd)},
		{"id": "ocean_west",  "center": Vector3(bw * 0.5, 0.0, world_d * 0.5), "size": Vector2(bw, mid_h)},
		{"id": "ocean_east",  "center": Vector3(world_w - bw * 0.5, 0.0, world_d * 0.5), "size": Vector2(bw, mid_h)},
	]
	for i in range(strip_defs.size()):
		var sd: Dictionary = strip_defs[i]
		var strip := WaterZone.new()
		strip.id = sd["id"]
		strip.shape = WaterZone.Shape.RECTANGLE
		strip.center = sd["center"]
		strip.size = sd["size"]
		strip.shallow_color = shallow_col
		strip.deep_color = deep_col
		strip.wave_strength = 0.25
		strip.wave_speed = 0.6
		data.water_zones.append(strip)

	# Interior lakes at local basins — each gets its own water level at basin height
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 5000
	var sample_step: int = maxi(data.width / 12, 8)
	var candidates: Array[Vector3] = []

	for sz in range(2, data.height - 2, sample_step):
		for sx in range(2, data.width - 2, sample_step):
			var h: float = data.get_height_at(sx, sz) * tscale.y
			# Consider any land basin (including below sea level for sunken areas)
			if h < -8.0 or h > 12.0:
				continue
			# Must be a local minimum
			var is_basin: bool = true
			@warning_ignore("integer_division")
			var check_r: int = sample_step / 2
			for dz in range(-check_r, check_r + 1, maxi(check_r, 1)):
				for dx in range(-check_r, check_r + 1, maxi(check_r, 1)):
					if dx == 0 and dz == 0:
						continue
					var nx: int = clampi(sx + dx, 0, data.width - 1)
					var nz: int = clampi(sz + dz, 0, data.height - 1)
					if data.get_height_at(nx, nz) * tscale.y < h - 0.2:
						is_basin = false
						break
				if not is_basin:
					break
			if is_basin:
				candidates.append(Vector3(float(sx) * tscale.x, h, float(sz) * tscale.z))

	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var placed: int = 0
	for ci in range(candidates.size()):
		if placed >= 3:
			break
		var c: Vector3 = candidates[ci]
		var too_close: bool = false
		for wi in range(data.water_zones.size()):
			var existing: WaterZone = data.water_zones[wi]
			if existing.id.begins_with("ocean_"):
				continue
			var ddx: float = c.x - existing.center.x
			var ddz: float = c.z - existing.center.z
			if ddx * ddx + ddz * ddz < 1600.0:
				too_close = true
				break
		if too_close:
			continue
		var zone := WaterZone.new()
		zone.id = "lake_%d" % placed
		# Water level sits at basin height + small offset so surface is visible
		zone.center = Vector3(c.x, c.y + 0.3, c.z)
		zone.size = Vector2(rng.randf_range(18.0, 40.0), rng.randf_range(15.0, 35.0))
		zone.shape = WaterZone.Shape.ELLIPSE
		zone.shallow_color = Color(0.15, 0.45, 0.65, 0.55)
		zone.deep_color = Color(0.04, 0.12, 0.28, 0.85)
		zone.wave_strength = rng.randf_range(0.01, 0.03)
		zone.wave_speed = rng.randf_range(0.2, 0.4)
		data.water_zones.append(zone)
		placed += 1


# ---------------------------------------------------------------------------
# Town placement
# ---------------------------------------------------------------------------

static func _add_procedural_town(data: HeightmapData, map_seed: int) -> void:
	## Finds the flattest interior area and places the starting town/hub.
	var tscale: Vector3 = data.terrain_scale
	var world_w: float = float(data.width) * tscale.x
	var world_d: float = float(data.height) * tscale.z

	# Avoid 30% of the map edges (ocean fringe)
	var margin_x: float = world_w * 0.30
	var margin_z: float = world_d * 0.30
	var best_x: float = world_w * 0.5
	var best_z: float = world_d * 0.5
	var best_variance: float = INF
	var step: float = world_w * 0.08

	var sx: float = margin_x
	while sx <= world_w - margin_x:
		var sz: float = margin_z
		while sz <= world_d - margin_z:
			# Only consider land (height > 1.0m world)
			var ix: int = clampi(roundi(sx / tscale.x), 0, data.width - 1)
			var iz: int = clampi(roundi(sz / tscale.z), 0, data.height - 1)
			if data.get_height_at(ix, iz) * tscale.y > 0.5:
				var variance: float = _terrain_variance(data, sx, sz, 30.0)
				if variance < best_variance:
					best_variance = variance
					best_x = sx
					best_z = sz
			sz += step
		sx += step

	# Overworld maps are large — always use CITY
	TownLayoutGenerator.generate_town(data, best_x, best_z,
		TownLayoutGenerator.TownSize.CITY, map_seed + 9500)
	var tc_ix: int = clampi(roundi(best_x / tscale.x), 0, data.width - 1)
	var tc_iz: int = clampi(roundi(best_z / tscale.z), 0, data.height - 1)
	data.town_center = Vector3(best_x, data.get_height_at(tc_ix, tc_iz) * tscale.y, best_z)


static func _terrain_variance(data: HeightmapData, cx: float, cz: float, radius: float) -> float:
	var tscale: Vector3 = data.terrain_scale
	var heights: Array[float] = []
	var step: float = 6.0

	var x: float = cx - radius
	while x <= cx + radius:
		var z: float = cz - radius
		while z <= cz + radius:
			var ix: int = clampi(roundi(x / tscale.x), 0, data.width - 1)
			var iz: int = clampi(roundi(z / tscale.z), 0, data.height - 1)
			heights.append(data.get_height_at(ix, iz))
			z += step
		x += step

	if heights.is_empty():
		return INF

	var mean: float = 0.0
	for i in range(heights.size()):
		mean += heights[i]
	mean /= float(heights.size())

	var variance: float = 0.0
	for i in range(heights.size()):
		var diff: float = heights[i] - mean
		variance += diff * diff
	return variance / float(heights.size())
