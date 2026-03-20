class_name HeightmapData
extends Resource
## Stores a full heightmap terrain: per-vertex heights, splatmap weights,
## and texture layer configuration. Divided into chunks for streaming.

const CHUNK_SIZE := 16  ## Vertices per chunk edge (actual quads = CHUNK_SIZE - 1)

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Dimensions")
## Total map size in vertices (not chunks). Must be multiples of CHUNK_SIZE + 1
## for clean chunk boundaries. E.g. 129x81 = 8×5 chunks.
@export var width: int = 129
@export var height: int = 81

@export_group("Heights")
## Flat row-major array of vertex heights (floats). Size = width × height.
## Index = z * width + x.  Y-up in Godot world space.
@export var heights: PackedFloat32Array = PackedFloat32Array()

@export_group("Splatmap")
## Per-vertex texture weights stored as packed RGBA bytes (4 bytes per vertex).
## Size = width × height × 4.  Channels map to texture_layers[0..3].
## Weights are 0–255, normalized to 0.0–1.0 in the shader.
@export var splatmap: PackedByteArray = PackedByteArray()
## Second splatmap — channels map to texture_layers[4..7].
@export var splatmap2: PackedByteArray = PackedByteArray()

@export_group("Texture Layers")
## Up to 8 terrain texture layers. Each entry is an albedo texture path.
## splatmap channels 0-3 → layers 0-3. splatmap2 channels 0-3 → layers 4-7.
@export var texture_layers: Array[TerrainTextureLayer] = []

@export_group("Water")
## Placed water bodies (lakes, rivers, fountains). Each has its own position and size.
@export var water_zones: Array[WaterZone] = []
## Procedural river paths (polylines from mountain to ocean).
@export var rivers: Array[RiverPath] = []

@export_group("Structures (Procedural)")
## Modular building pieces placed on the terrain (walls, floors, roofs, etc.)
## Used by procedural generators. For scene-based maps, place structures as scene nodes instead.
@export var structures: Array[PlacedStructure] = []
## Points of interest placed by the procedural generator (dungeons, ruins, camps, shrines).
## Road generator routes toward these. Overworld spawns encounter zones around them.
@export var points_of_interest: Array[PointOfInterest] = []

@export_group("Metadata")
## World-space scale applied to the heightmap.  x/z = horizontal spacing between
## vertices, y = height multiplier.
@export var terrain_scale: Vector3 = Vector3(1.0, 10.0, 1.0)
## World-space position of the procedurally generated town center (set by BiomeHeightmapGenerator).
## Vector3.ZERO means no town has been placed yet.
@export var town_center: Vector3 = Vector3.ZERO
## True when this heightmap represents an overworld map (island shape, no roads,
## tiny decorative props). Used by TerrainManager to select the correct prop registry.
@export var is_overworld: bool = false
## Per-vertex island index (overworld only). 0 = ocean, 1 = first island, 2 = second, etc.
## Empty for non-overworld maps. Size = width × height when populated.
@export var island_indices: PackedByteArray = PackedByteArray()
## Per-vertex forest density (overworld only). 0 = open land, 255 = dense forest.
## Props with forest_only=true only spawn where this is > 0.
@export var forest_density: PackedByteArray = PackedByteArray()


## Cached river exclusion mask — one byte per vertex (0 = clear, 1 = inside river channel).
## Built lazily by build_river_mask(), queried by is_river_at().
var _river_mask: PackedByteArray = PackedByteArray()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func get_chunk_count_x() -> int:
	return ceili(float(width - 1) / (CHUNK_SIZE - 1))


func get_chunk_count_z() -> int:
	return ceili(float(height - 1) / (CHUNK_SIZE - 1))


func get_height_at(x: int, z: int) -> float:
	if x < 0 or x >= width or z < 0 or z >= height:
		return 0.0
	if heights.is_empty():
		return 0.0
	return heights[z * width + x]


func set_height_at(x: int, z: int, h: float) -> void:
	if x < 0 or x >= width or z < 0 or z >= height:
		return
	_ensure_heights()
	heights[z * width + x] = h


func get_splatmap_weights(x: int, z: int) -> Color:
	## Returns the 4-channel splatmap weight at (x, z) as a Color (0.0–1.0).
	if x < 0 or x >= width or z < 0 or z >= height:
		return Color(1, 0, 0, 0)  # default = layer 0 only
	if splatmap.is_empty():
		return Color(1, 0, 0, 0)
	var idx: int = (z * width + x) * 4
	if idx + 3 >= splatmap.size():
		return Color(1, 0, 0, 0)
	return Color(
		splatmap[idx] / 255.0,
		splatmap[idx + 1] / 255.0,
		splatmap[idx + 2] / 255.0,
		splatmap[idx + 3] / 255.0
	)


func set_splatmap_weights(x: int, z: int, weights: Color) -> void:
	if x < 0 or x >= width or z < 0 or z >= height:
		return
	_ensure_splatmap()
	var idx: int = (z * width + x) * 4
	splatmap[idx] = clampi(int(weights.r * 255.0), 0, 255)
	splatmap[idx + 1] = clampi(int(weights.g * 255.0), 0, 255)
	splatmap[idx + 2] = clampi(int(weights.b * 255.0), 0, 255)
	splatmap[idx + 3] = clampi(int(weights.a * 255.0), 0, 255)


func get_splatmap2_weights(x: int, z: int) -> Color:
	if x < 0 or x >= width or z < 0 or z >= height:
		return Color(0, 0, 0, 0)
	if splatmap2.is_empty():
		return Color(0, 0, 0, 0)
	var idx: int = (z * width + x) * 4
	if idx + 3 >= splatmap2.size():
		return Color(0, 0, 0, 0)
	return Color(
		splatmap2[idx] / 255.0,
		splatmap2[idx + 1] / 255.0,
		splatmap2[idx + 2] / 255.0,
		splatmap2[idx + 3] / 255.0
	)


func set_splatmap2_weights(x: int, z: int, weights: Color) -> void:
	if x < 0 or x >= width or z < 0 or z >= height:
		return
	_ensure_splatmap2()
	var idx: int = (z * width + x) * 4
	splatmap2[idx] = clampi(int(weights.r * 255.0), 0, 255)
	splatmap2[idx + 1] = clampi(int(weights.g * 255.0), 0, 255)
	splatmap2[idx + 2] = clampi(int(weights.b * 255.0), 0, 255)
	splatmap2[idx + 3] = clampi(int(weights.a * 255.0), 0, 255)


func initialize(default_height: float = 0.0) -> void:
	## Fills heights with a flat plane and splatmap with layer 0 only.
	var total: int = width * height
	heights.resize(total)
	heights.fill(default_height)
	splatmap.resize(total * 4)
	splatmap.fill(0)
	# Set all R channel to 255 (layer 0 = full weight)
	for i in range(total):
		splatmap[i * 4] = 255


func generate_from_noise(noise: FastNoiseLite, amplitude: float = 1.0, offset: Vector2 = Vector2.ZERO) -> void:
	## Fills heights from a noise generator. Splatmap is NOT modified.
	_ensure_heights()
	for z in range(height):
		for x in range(width):
			heights[z * width + x] = noise.get_noise_2d(x + offset.x, z + offset.y) * amplitude


func auto_splatmap_by_height(thresholds: PackedFloat32Array) -> void:
	## Auto-assigns splatmap weights based on vertex height.
	## thresholds should have 3 values: [low_to_mid, mid_to_high, high_to_peak].
	## Layer 0 = low, Layer 1 = mid, Layer 2 = high, Layer 3 = peak.
	if thresholds.size() < 3:
		return
	_ensure_splatmap()
	for z in range(height):
		for x in range(width):
			var h: float = get_height_at(x, z) * terrain_scale.y
			var weights := Color(0, 0, 0, 0)
			if h < thresholds[0]:
				weights.r = 1.0
			elif h < thresholds[1]:
				var t: float = (h - thresholds[0]) / (thresholds[1] - thresholds[0])
				weights.r = 1.0 - t
				weights.g = t
			elif h < thresholds[2]:
				var t: float = (h - thresholds[1]) / (thresholds[2] - thresholds[1])
				weights.g = 1.0 - t
				weights.b = t
			else:
				weights.b = 0.0
				weights.a = 1.0
			set_splatmap_weights(x, z, weights)


# ---------------------------------------------------------------------------
# River exclusion mask
# ---------------------------------------------------------------------------

func build_river_mask(exclusion_radius: int = 8) -> void:
	## Builds a per-vertex mask marking cells inside river channels.
	## exclusion_radius is in heightmap grid units from each river centerline point.
	## Call this once after rivers are generated and carved.
	var total: int = width * height
	_river_mask.resize(total)
	_river_mask.fill(0)

	var inv_sx: float = 1.0 / terrain_scale.x
	var inv_sz: float = 1.0 / terrain_scale.z
	var excl_sq: float = float(exclusion_radius * exclusion_radius)

	for ri in range(rivers.size()):
		var river: RiverPath = rivers[ri]
		var pts: PackedVector3Array = river.points
		for pi in range(pts.size()):
			var wp: Vector3 = pts[pi]
			var gx: int = roundi(wp.x * inv_sx)
			var gz: int = roundi(wp.z * inv_sz)
			for dz in range(-exclusion_radius, exclusion_radius + 1):
				for dx in range(-exclusion_radius, exclusion_radius + 1):
					if dx * dx + dz * dz > int(excl_sq):
						continue
					var nx: int = gx + dx
					var nz: int = gz + dz
					if nx < 0 or nx >= width or nz < 0 or nz >= height:
						continue
					_river_mask[nz * width + nx] = 1


func is_river_at(x: int, z: int) -> bool:
	## Returns true if the grid cell is inside a river exclusion zone.
	## Lazily builds the mask on first call (mask is not serialized to .tres).
	if _river_mask.is_empty() and not rivers.is_empty():
		build_river_mask()
	if _river_mask.is_empty():
		return false
	if x < 0 or x >= width or z < 0 or z >= height:
		return false
	return _river_mask[z * width + x] == 1


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

func _ensure_heights() -> void:
	var total: int = width * height
	if heights.size() != total:
		heights.resize(total)
		heights.fill(0.0)


func _ensure_splatmap() -> void:
	var total: int = width * height * 4
	if splatmap.size() != total:
		splatmap.resize(total)
		splatmap.fill(0)
		for i in range(width * height):
			splatmap[i * 4] = 255  # Default: layer 0 full weight


func _ensure_splatmap2() -> void:
	var total: int = width * height * 4
	if splatmap2.size() != total:
		splatmap2.resize(total)
		splatmap2.fill(0)  # Default: all zeros (no weight in layers 4-7)
