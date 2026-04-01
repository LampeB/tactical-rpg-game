class_name BiomeHeightmapGenerator
extends RefCounted
## Generates HeightmapData with biome-driven terrain: height, splatmap, water, and structures.
## Each biome profile defines noise parameters, height range, and texture weights.
## A moisture + temperature noise pair selects the biome at each vertex.

const _TerrainErosion := preload("res://scripts/terrain/terrain_erosion.gd")
const _RiverGenerator := preload("res://scripts/terrain/river_generator.gd")
const _PoiGenerator := preload("res://scripts/terrain/poi_generator.gd")
const _RoadGenerator := preload("res://scripts/terrain/road_generator.gd")

## Material-LIB base path (gitignored — textures only exist locally)
const _LIB := AssetPaths.MATERIALS_NATURE

## Layer definitions: [folder, base, uv_scale, label]
## Layers 0-3 → splatmap1 (vertex colors R/G/B/A)
## Layers 4-7 → splatmap2 (texture channels R/G/B/A)
const _LAYER_DEFS: Array[Dictionary] = [
	{"folder": "FoliageGrass",  "base": "FoliageGrass",  "uv": 15.0, "label": "Grass"},
	{"folder": "Sand",          "base": "Sand",           "uv": 12.0, "label": "Sand"},
	{"folder": "SurfaceRock",   "base": "SurfaceRock",   "uv": 8.0,  "label": "Rock"},
	{"folder": "SurfaceStone",  "base": "SurfaceStone",  "uv": 10.0, "label": "Snow"},
	{"folder": "SurfaceSoil",   "base": "SurfaceSoil",   "uv": 10.0, "label": "Soil"},
	{"folder": "SurfacePebbles","base": "SurfacePebbles","uv": 8.0,  "label": "Pebbles"},
	{"folder": "SurfaceCliff",  "base": "SurfaceCliff",  "uv": 6.0,  "label": "Cliff"},
	{"folder": "Moss",          "base": "Moss",          "uv": 12.0, "label": "Moss"},
]


## Biome profile: controls terrain generation for a region.
## height_base + noise * height_amplitude = final height.
## splat_weights = Color(grass, dirt, rock, snow) — dominant texture blend.
class BiomeProfile:
	var id: String
	var height_base: float
	var height_amplitude: float
	var noise_frequency: float
	var noise_octaves: int
	var splat_weights: Color   ## Splatmap1 blend: R=Grass G=Sand B=Rock A=Snow
	var splat_weights2: Color  ## Splatmap2 blend: R=Soil G=Pebbles B=Cliff A=Moss
	var water_level: float  ## Below this height, terrain is submerged (negative = no water)

	func _init(
		p_id: String, p_base: float, p_amp: float,
		p_freq: float, p_oct: int, p_splat: Color, p_water: float = -1.0,
		p_splat2: Color = Color(0, 0, 0, 0)
	) -> void:
		id = p_id
		height_base = p_base
		height_amplitude = p_amp
		noise_frequency = p_freq
		noise_octaves = p_oct
		splat_weights = p_splat
		splat_weights2 = p_splat2
		water_level = p_water


## Built-in biome profiles (lazy-initialized)
static var _biomes_cache: Array = []


static func _get_biomes() -> Array:
	if not _biomes_cache.is_empty():
		return _biomes_cache
	_biomes_cache = [
		# Plains: flat grass, soil patches
		#                                                splat1                        water  splat2(Soil Pebbles Cliff Moss)
		BiomeProfile.new("plains",     0.2, 0.3, 0.015, 3, Color(0.9, 0.0, 0.05, 0.0), -1.0, Color(0.05, 0.0, 0.0, 0.0)),
		# Forest: grass + moss understory
		BiomeProfile.new("forest",     0.3, 0.5, 0.025, 4, Color(0.7, 0.0, 0.1,  0.0), -1.0, Color(0.05, 0.0, 0.0, 0.15)),
		# Hills: rock dominant, pebble scree
		BiomeProfile.new("hills",      0.5, 0.7, 0.02,  4, Color(0.2, 0.0, 0.7,  0.0), -1.0, Color(0.0,  0.1, 0.0, 0.0)),
		# Mountains: rock + cliff faces
		BiomeProfile.new("mountains",  0.7, 1.0, 0.03,  5, Color(0.0, 0.0, 0.8,  0.1), -1.0, Color(0.0,  0.1, 0.1, 0.0)),
		# Snow peaks: snow + rock + cliff
		BiomeProfile.new("snow_peaks", 0.8, 1.0, 0.035, 5, Color(0.0, 0.0, 0.15, 0.8), -1.0, Color(0.0,  0.05,0.05,0.0)),
		# Wetlands: grass + soil + moss
		BiomeProfile.new("wetlands",   0.05,0.15,0.01,  2, Color(0.5, 0.0, 0.1,  0.0), 0.8,  Color(0.25, 0.0, 0.0, 0.15)),
	]
	return _biomes_cache


static func generate(
	map_width: int = 129, map_height: int = 81, map_seed: int = 42
) -> HeightmapData:
	## Creates a biome-driven heightmap. Different seeds produce different terrain.
	var data := HeightmapData.new()
	data.id = "biome_%d" % map_seed
	data.display_name = "Procedural Terrain"
	data.width = map_width
	data.height = map_height
	data.terrain_scale = Vector3(1.0, 8.0, 1.0)

	data.initialize(0.0)

	# --- Edge warp noise (organic coastline/mountain boundaries) ---
	_init_edge_noise(map_seed)

	# --- Biome selection noise (temperature + moisture) ---
	var temp_noise := FastNoiseLite.new()
	temp_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	temp_noise.frequency = 0.008
	temp_noise.fractal_octaves = 2
	temp_noise.seed = map_seed

	var moisture_noise := FastNoiseLite.new()
	moisture_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	moisture_noise.frequency = 0.006
	moisture_noise.fractal_octaves = 2
	moisture_noise.seed = map_seed + 1000

	# --- Detail height noise (shared, modulated per-biome) ---
	var detail_noise := FastNoiseLite.new()
	detail_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	detail_noise.frequency = 0.02
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

	# --- Pass 1: Generate heights only ---
	# Store biome-blended splatmap weights for Pass 2 (after erosion modifies heights).
	var biome_splats := PackedColorArray()
	biome_splats.resize(map_width * map_height)
	var biome_splats2 := PackedColorArray()
	biome_splats2.resize(map_width * map_height)

	for z in range(map_height):
		for x in range(map_width):
			var temp_val: float = temp_noise.get_noise_2d(x, z) * 0.5 + 0.5  # 0..1
			var moist_val: float = moisture_noise.get_noise_2d(x, z) * 0.5 + 0.5  # 0..1

			# Select biome blend weights from temperature + moisture
			var biome_weights: Array[float] = _get_biome_weights(temp_val, moist_val)

			# Blend height from all biomes
			var h: float = 0.0
			var splat := Color(0, 0, 0, 0)
			var splat2 := Color(0, 0, 0, 0)
			for bi in range(biome_count):
				var w: float = biome_weights[bi]
				if w < 0.001:
					continue
				var bp: BiomeProfile = biomes[bi]
				var bn: FastNoiseLite = biome_noises[bi]
				var noise_val: float = bn.get_noise_2d(x, z)  # -1..1
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

			# Add fine detail noise
			h += detail_noise.get_noise_2d(x, z) * 0.15

			# Edge treatment — mountains on north/west, ocean on south/east
			var edge_factor: float = _edge_elevation(x, z, map_width, map_height)
			if edge_factor < 0.0:
				# Ocean floor: push below sea level
				h = edge_factor * 0.3
				splat = Color(0.1, 0.8, 0.1, 0.0)  # Dirt (underwater ground)
			elif edge_factor > 0.01:
				h += edge_factor
				if _is_sea_edge(x, z, map_width, map_height):
					var coast_t: float = clampf(edge_factor / 0.15, 0.0, 0.5)
					splat = splat.lerp(Color(0.3, 0.5, 0.2, 0.0), coast_t)
				else:
					var wall_t: float = clampf(edge_factor / 0.6, 0.0, 1.0)
					splat = splat.lerp(Color(0.0, 0.05, 0.7, 0.25), wall_t)

			data.set_height_at(x, z, h)
			biome_splats[z * map_width + x] = splat
			biome_splats2[z * map_width + x] = splat2

	# --- Erosion pass (modifies heights for natural drainage and valleys) ---
	_TerrainErosion.apply(data, map_seed)

	# --- Rivers (trace from mountains to ocean, carve riverbeds) ---
	var rivers: Array[RiverPath] = _RiverGenerator.generate(data, map_seed)
	data.rivers = rivers

	# --- Pass 2: Assign splatmap from biome weights + post-erosion heights ---
	_assign_splatmap(data, biome_splats, biome_splats2, map_width, map_height)

	# --- Paint river banks AFTER splatmap so they aren't overwritten ---
	_RiverGenerator.paint_all_banks(data)

	# --- Texture layers ---
	_add_textured_layers(data)

	# --- Auto-place water in low areas ---
	_add_procedural_water(data, map_seed)

	# --- Place a town in a suitable flat area ---
	_add_procedural_town(data, map_seed)

	# --- Re-carve rivers and update Y coords after town flattening ---
	# Town flattening overwrites carved riverbeds, so rivers must be re-applied.
	_RiverGenerator.recarve_and_update(data)

	# --- Points of interest (dungeons, ruins, camps, shrines) ---
	_PoiGenerator.generate(data, map_seed)

	# --- Roads (connect town to POIs and ocean exits) ---
	_RoadGenerator.generate(data, map_seed)

	# --- Build river exclusion mask for prop scatter ---
	data.build_river_mask(8)

	return data


static func _get_biome_weights(temperature: float, moisture: float) -> Array[float]:
	## Maps temperature (0=cold, 1=hot) and moisture (0=dry, 1=wet) to biome blend weights.
	## Returns an array with one weight per biome in _get_biomes() order:
	## [plains, forest, hills, mountains, snow_peaks, wetlands]
	var weights: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0]

	# Plains: moderate temp, low-mid moisture
	weights[0] = _biome_affinity(temperature, 0.5, 0.3) * _biome_affinity(moisture, 0.3, 0.3)
	# Forest: moderate temp, high moisture
	weights[1] = _biome_affinity(temperature, 0.5, 0.25) * _biome_affinity(moisture, 0.7, 0.25)
	# Hills: warm, moderate moisture
	weights[2] = _biome_affinity(temperature, 0.65, 0.25) * _biome_affinity(moisture, 0.5, 0.3)
	# Mountains: any temp, low moisture (dry highlands)
	weights[3] = _biome_affinity(temperature, 0.4, 0.4) * _biome_affinity(moisture, 0.15, 0.2)
	# Snow peaks: cold, any moisture
	weights[4] = _biome_affinity(temperature, 0.1, 0.2) * _biome_affinity(moisture, 0.5, 0.5)
	# Wetlands: warm, very high moisture
	weights[5] = _biome_affinity(temperature, 0.6, 0.3) * _biome_affinity(moisture, 0.9, 0.15)

	# Normalize
	var total: float = 0.0
	for i in range(weights.size()):
		total += weights[i]
	if total > 0.001:
		for i in range(weights.size()):
			weights[i] /= total
	else:
		weights[0] = 1.0  # Fallback to plains

	return weights


static func _biome_affinity(value: float, center: float, radius: float) -> float:
	## Gaussian-like affinity: 1.0 at center, falls off within radius.
	var dist: float = absf(value - center)
	if dist >= radius:
		return 0.0
	var t: float = dist / radius
	return (1.0 - t * t)  # Quadratic falloff


## Edge type constants returned by _classify_edge
const _EDGE_NONE := 0    ## Interior — no edge treatment
const _EDGE_MOUNTAIN := 1 ## Mountain wall (north + west)
const _EDGE_OCEAN := 2    ## Sea front (south + east)

const _OCEAN_STRIP := 3        ## Vertices that drop below sea level
const _MOUNTAIN_WALL_WIDTH := 16 ## Vertices of mountain range at edge

## Edge warp noise — initialized per-generation, used to break up straight edge lines.
static var _edge_noise: FastNoiseLite = null


static func _init_edge_noise(map_seed: int) -> void:
	## Creates a noise field used to warp edge distances so boundaries aren't straight.
	_edge_noise = FastNoiseLite.new()
	_edge_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_edge_noise.frequency = 0.04  # Medium frequency — organic coastline wobble
	_edge_noise.fractal_octaves = 3
	_edge_noise.fractal_lacunarity = 2.0
	_edge_noise.fractal_gain = 0.5
	_edge_noise.seed = map_seed + 7000


static func _edge_warp(x: int, z: int) -> float:
	## Returns a distance warp offset (in vertices) from the edge noise.
	## Positive = push boundary outward, negative = push inward.
	if _edge_noise == null:
		return 0.0
	return _edge_noise.get_noise_2d(x, z) * 6.0  # ±6 vertex warp


static func _edge_elevation(x: int, z: int, w: int, h: int) -> float:
	## Returns extra height near map edges.
	## Mountain sides (north, west): tall rock walls.
	## Sea sides (south, east): coastal drop into ocean.
	## Returns negative for ocean floor, positive for mountain/cliff rise, 0 for interior.
	var wall_width: int = _MOUNTAIN_WALL_WIDTH
	# Foothills extend beyond the steep wall for a gradual slope into interior
	var foothills_width: int = wall_width

	# Per-edge distances with noise warp for organic boundaries
	var warp_n: float = _edge_warp(x, z)
	var warp_s: float = _edge_warp(x, z + 1000)  # Offset coords for different warp per edge
	var warp_w: float = _edge_warp(x, z + 2000)
	var warp_e: float = _edge_warp(x, z + 3000)

	var dist_north: float = float(z) + warp_n
	var dist_south: float = float(h - 1 - z) + warp_s
	var dist_west: float = float(x) + warp_w
	var dist_east: float = float(w - 1 - x) + warp_e

	# Find the closest mountain edge and closest sea edge
	var mountain_dist: float = minf(dist_north, dist_west)
	var sea_dist: float = minf(dist_south, dist_east)

	# Mountain range (north + west): steep peaks at edge, smooth transition to foothills
	var wall_f: float = float(wall_width)
	var foothills_f: float = float(foothills_width)
	var total_f: float = wall_f + foothills_f
	if mountain_dist < total_f:
		var t: float = maxf(mountain_dist, 0.0) / total_f  # 0 at edge, 1 at interior
		# Single smooth curve: 3.5 at edge, tapering to 0 at foothills end
		var mountain_h: float = (1.0 - t) * (1.0 - t) * 3.5
		return mountain_h

	# Ocean (south + east): drop below sea level at very edge, gentle coast slope
	@warning_ignore("integer_division")
	var coast_margin: int = maxi(mini(w, h) / 10, 8)
	var ocean_strip_f: float = float(_OCEAN_STRIP)
	if sea_dist < ocean_strip_f:
		var t: float = maxf(sea_dist, 0.0) / ocean_strip_f
		return lerpf(-1.0, -0.1, t)
	elif sea_dist < ocean_strip_f + float(coast_margin):
		# Gentle coastal slope — slight rise from shore into interior
		var t: float = (sea_dist - ocean_strip_f) / float(coast_margin)
		return (1.0 - (1.0 - t) * (1.0 - t)) * 0.2

	return 0.0


static func _is_sea_edge(x: int, z: int, w: int, h: int) -> bool:
	## Returns true if this vertex is in the ocean strip (south or east edge).
	## Uses warped distances for consistency with _edge_elevation.
	var warp_s: float = _edge_warp(x, z + 1000)
	var warp_e: float = _edge_warp(x, z + 3000)
	var dist_south: float = float(h - 1 - z) + warp_s
	var dist_east: float = float(w - 1 - x) + warp_e
	return minf(dist_south, dist_east) < float(_OCEAN_STRIP)


static func _assign_splatmap(data: HeightmapData, biome_splats: PackedColorArray,
		biome_splats2: PackedColorArray, map_width: int, map_height: int) -> void:
	## Pass 2: Assigns splatmap weights using biome-blended colors + post-erosion heights.
	## Adds slope-based cliff painting and height-based overrides.
	var tscale_y: float = data.terrain_scale.y
	var tscale_x: float = data.terrain_scale.x

	var beach_vertex_count: int = 0
	var cliff_vertex_count: int = 0
	var scree_vertex_count: int = 0

	for z in range(map_height):
		for x in range(map_width):
			var splat: Color = biome_splats[z * map_width + x]
			var splat2: Color = biome_splats2[z * map_width + x]
			var h: float = data.get_height_at(x, z)
			var world_h: float = h * tscale_y

			# --- Slope-based cliff detection ---
			# Central differencing for slope magnitude (same approach as HeightmapChunk normals)
			var h_left: float = data.get_height_at(x - 1, z) * tscale_y
			var h_right: float = data.get_height_at(x + 1, z) * tscale_y
			var h_up: float = data.get_height_at(x, z - 1) * tscale_y
			var h_down: float = data.get_height_at(x, z + 1) * tscale_y
			var dx: float = (h_right - h_left) / (2.0 * tscale_x)
			var dz: float = (h_down - h_up) / (2.0 * tscale_x)
			var slope: float = sqrt(dx * dx + dz * dz)
			# slope ~0.6 = 31° (scree begins), ~1.0 = 45° (cliff begins), ~1.73 = 60° (full cliff)
			if slope > 0.5:
				if slope < 1.0:
					# Medium slope — pebble scree (layer5 = Pebbles)
					var scree_t: float = clampf((slope - 0.5) / 0.5, 0.0, 1.0)
					splat = splat.lerp(Color(0.1, 0.0, 0.6, 0.0), scree_t * 0.6)
					splat2 = splat2.lerp(Color(0.0, 0.4, 0.0, 0.0), scree_t * 0.6)
					scree_vertex_count += 1
				else:
					# Steep cliff — cliff texture (layer6 = Cliff)
					var cliff_t: float = clampf((slope - 1.0) / 0.73, 0.0, 1.0)
					splat = splat.lerp(Color(0.0, 0.0, 0.3, 0.0), cliff_t)
					splat2 = splat2.lerp(Color(0.0, 0.0, 0.7, 0.0), cliff_t)
					cliff_vertex_count += 1

			# --- Height-based overrides ---
			if world_h > 6.0:
				var snow_t: float = clampf((world_h - 6.0) / 2.0, 0.0, 1.0)
				splat = splat.lerp(Color(0, 0, 0.3, 0.7), snow_t)
			elif world_h < 1.0:
				# Check if not ocean floor (ocean already has its own splat from biome pass)
				var edge_factor: float = _edge_elevation(x, z, map_width, map_height)
				if edge_factor >= 0.0:
					var grass_t: float = clampf((1.0 - world_h) / 1.0, 0.0, 1.0)
					splat = splat.lerp(Color(0.8, 0.2, 0.0, 0.0), grass_t * 0.5)

			# --- Beach detection (near ocean edges) ---
			# Wide sandy shore: wet sand right at waterline, dry sand further in.
			var warp_s: float = _edge_warp(x, z + 1000)
			var warp_e: float = _edge_warp(x, z + 3000)
			var dist_south: float = float(map_height - 1 - z) + warp_s
			var dist_east: float = float(map_width - 1 - x) + warp_e
			var sea_dist: float = minf(dist_south, dist_east)
			var beach_start: float = float(_OCEAN_STRIP)
			var beach_end: float = beach_start + 20.0
			if sea_dist >= beach_start and sea_dist < beach_end and world_h >= 0.0 and world_h < 2.5 and slope < 0.35:
				var beach_t: float = 1.0 - (sea_dist - beach_start) / (beach_end - beach_start)
				# Wet sand at waterline (pure dirt), dry sand fades to grass further in
				var wet_t: float = clampf(1.0 - (sea_dist - beach_start) / 10.0, 0.0, 1.0)
				var sand_color: Color = Color(0.0, 0.95, 0.05, 0.0).lerp(
					Color(0.25, 0.65, 0.1, 0.0), 1.0 - wet_t)
				splat = splat.lerp(sand_color, beach_t)
				beach_vertex_count += 1

			# Normalize across all 8 channels together
			var total_w: float = splat.r + splat.g + splat.b + splat.a \
				+ splat2.r + splat2.g + splat2.b + splat2.a
			if total_w > 0.001:
				splat.r /= total_w
				splat.g /= total_w
				splat.b /= total_w
				splat.a /= total_w
				splat2.r /= total_w
				splat2.g /= total_w
				splat2.b /= total_w
				splat2.a /= total_w
			else:
				splat = Color(1, 0, 0, 0)
				splat2 = Color(0, 0, 0, 0)

			data.set_splatmap_weights(x, z, splat)
			data.set_splatmap2_weights(x, z, splat2)

	print("[Splatmap] beach=%d  scree=%d  cliff=%d  (total=%d, layers=8)" % [
		beach_vertex_count, scree_vertex_count, cliff_vertex_count, map_width * map_height])


static func _add_textured_layers(data: HeightmapData) -> void:
	## Loads Material-LIB terrain textures into the 4 splatmap layers.
	for i in range(_LAYER_DEFS.size()):
		var def: Dictionary = _LAYER_DEFS[i]
		var layer := TerrainTextureLayer.new()
		layer.name = def["label"]
		layer.uv_scale = def["uv"]

		var folder: String = def["folder"]
		var base_name: String = def["base"]
		var albedo_path: String = _LIB + folder + "/" + base_name + "-B.png"
		var normal_path: String = _LIB + folder + "/" + base_name + "-N.png"

		if ResourceLoader.exists(albedo_path):
			layer.albedo_texture = load(albedo_path)
		if ResourceLoader.exists(normal_path):
			layer.normal_texture = load(normal_path)

		data.texture_layers.append(layer)


static func _add_procedural_water(data: HeightmapData, map_seed: int) -> void:
	## Scans for low-elevation basins and places water zones.
	var tscale: Vector3 = data.terrain_scale
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 5000

	# Find low points by sampling a grid
	var sample_step: int = maxi(data.width / 10, 8)
	var candidates: Array[Vector3] = []  # Vector3(world_x, height, world_z)

	for sz in range(2, data.height - 2, sample_step):
		for sx in range(2, data.width - 2, sample_step):
			var h: float = data.get_height_at(sx, sz) * tscale.y
			if h < 1.2 and h > 0.0:
				# Check if this is a local minimum (lower than neighbors)
				var is_basin: bool = true
				@warning_ignore("integer_division")
				var check_r: int = sample_step / 2
				for dz in range(-check_r, check_r + 1, maxi(check_r, 1)):
					for dx in range(-check_r, check_r + 1, maxi(check_r, 1)):
						if dx == 0 and dz == 0:
							continue
						var nx: int = clampi(sx + dx, 0, data.width - 1)
						var nz: int = clampi(sz + dz, 0, data.height - 1)
						if data.get_height_at(nx, nz) * tscale.y < h - 0.1:
							is_basin = false
							break
					if not is_basin:
						break
				if is_basin:
					candidates.append(Vector3(
						float(sx) * tscale.x,
						h,
						float(sz) * tscale.z
					))

	# Place up to 3 water zones at the lowest basins
	candidates.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.y < b.y)
	var placed: int = 0
	var min_dist_sq: float = 400.0  # Min 20 units between water zones
	for ci in range(candidates.size()):
		if placed >= 3:
			break
		var c: Vector3 = candidates[ci]

		# Check distance to already placed zones
		var too_close: bool = false
		for wi in range(data.water_zones.size()):
			var existing: WaterZone = data.water_zones[wi]
			var dx: float = c.x - existing.center.x
			var dz: float = c.z - existing.center.z
			if dx * dx + dz * dz < min_dist_sq:
				too_close = true
				break
		if too_close:
			continue

		var zone := WaterZone.new()
		zone.id = "lake_%d" % placed
		zone.center = Vector3(c.x, c.y + 0.2, c.z)  # Slightly above ground
		zone.size = Vector2(
			rng.randf_range(12.0, 25.0),
			rng.randf_range(10.0, 20.0)
		)
		zone.shape = WaterZone.Shape.ELLIPSE
		zone.shallow_color = Color(0.15, 0.45, 0.65, 0.55)
		zone.deep_color = Color(0.04, 0.12, 0.28, 0.85)
		zone.wave_strength = rng.randf_range(0.01, 0.03)
		zone.wave_speed = rng.randf_range(0.2, 0.4)
		data.water_zones.append(zone)
		placed += 1

	# --- Ocean strips around map perimeter ---
	_add_ocean_border(data)


static func _add_ocean_border(data: HeightmapData) -> void:
	## Places rectangular water zones along south and east edges (sea front).
	## North and west edges are mountain walls — no water.
	var tscale: Vector3 = data.terrain_scale
	var world_w: float = float(data.width) * tscale.x
	var world_h: float = float(data.height) * tscale.z
	var strip_w: float = float(_OCEAN_STRIP + 1) * tscale.x
	var sea_level: float = 0.0

	var ocean_color_shallow := Color(0.1, 0.35, 0.55, 0.6)
	var ocean_color_deep := Color(0.02, 0.08, 0.2, 0.9)

	# South edge (z = max) — sea front
	var south := WaterZone.new()
	south.id = "ocean_south"
	south.shape = WaterZone.Shape.RECTANGLE
	south.center = Vector3(world_w * 0.5, sea_level, world_h - strip_w * 0.5)
	south.size = Vector2(world_w, strip_w)
	south.shallow_color = ocean_color_shallow
	south.deep_color = ocean_color_deep
	south.wave_strength = 0.04
	south.wave_speed = 0.3
	data.water_zones.append(south)

	# East edge (x = max) — sea front
	var east := WaterZone.new()
	east.id = "ocean_east"
	east.shape = WaterZone.Shape.RECTANGLE
	east.center = Vector3(world_w - strip_w * 0.5, sea_level, world_h * 0.5)
	east.size = Vector2(strip_w, world_h)
	east.shallow_color = ocean_color_shallow
	east.deep_color = ocean_color_deep
	east.wave_strength = 0.04
	east.wave_speed = 0.3
	data.water_zones.append(east)


static func _add_procedural_town(data: HeightmapData, map_seed: int) -> void:
	## Finds a suitable flat area and places a procedural town.
	## Prefers interior terrain (away from edges) with moderate height.
	var tscale: Vector3 = data.terrain_scale
	var world_w: float = float(data.width) * tscale.x
	var world_h: float = float(data.height) * tscale.z
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed + 9000

	# Search for the flattest area in the interior (avoid edges by 20%)
	var margin_x: float = world_w * 0.2
	var margin_z: float = world_h * 0.2
	var best_x: float = world_w * 0.5
	var best_z: float = world_h * 0.5
	var best_variance: float = INF
	var sample_step: float = world_w * 0.1

	var sx: float = margin_x
	while sx <= world_w - margin_x:
		var sz: float = margin_z
		while sz <= world_h - margin_z:
			var variance: float = _terrain_variance(data, sx, sz, 20.0)
			if variance < best_variance:
				best_variance = variance
				best_x = sx
				best_z = sz
			sz += sample_step
		sx += sample_step

	# Determine town size based on map size
	var town_size: TownLayoutGenerator.TownSize
	var map_area: float = world_w * world_h
	if map_area < 15000.0:
		town_size = TownLayoutGenerator.TownSize.VILLAGE
	elif map_area < 60000.0:
		town_size = TownLayoutGenerator.TownSize.TOWN
	else:
		town_size = TownLayoutGenerator.TownSize.CITY

	TownLayoutGenerator.generate_town(data, best_x, best_z, town_size, map_seed + 9500)
	data.town_center = Vector3(best_x, data.get_height_at(
		clampi(roundi(best_x / data.terrain_scale.x), 0, data.width - 1),
		clampi(roundi(best_z / data.terrain_scale.z), 0, data.height - 1)
	) * data.terrain_scale.y, best_z)


static func _terrain_variance(data: HeightmapData, cx: float, cz: float, radius: float) -> float:
	## Returns height variance in a circle. Lower = flatter = better for towns.
	var tscale: Vector3 = data.terrain_scale
	var heights: Array[float] = []
	var step: float = 4.0

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
