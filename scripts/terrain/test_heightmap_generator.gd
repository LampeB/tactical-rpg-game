class_name TestHeightmapGenerator
extends RefCounted
## Generates a test HeightmapData resource with procedural noise terrain.
## Used for development and testing of the heightmap terrain system.

## Material-LIB base path (gitignored — textures only exist locally)
const _LIB := "res://assets/3D/Material-LIB/Material-LIB/Nature/"

## Layer definitions: [folder, albedo_suffix, normal_suffix, uv_scale]
const _LAYER_DEFS: Array[Dictionary] = [
	{"folder": "FoliageGrass", "base": "FoliageGrass", "uv": 15.0, "label": "Grass"},
	{"folder": "SurfaceGround", "base": "SurfaceGround", "uv": 12.0, "label": "Dirt"},
	{"folder": "SurfaceRock", "base": "SurfaceRock", "uv": 8.0, "label": "Rock"},
	{"folder": "SurfaceStone", "base": "SurfaceStone", "uv": 10.0, "label": "Snow"},
]


static func generate(map_width: int = 129, map_height: int = 81) -> HeightmapData:
	## Creates a test heightmap with rolling hills and auto-assigned splatmap.
	var data := HeightmapData.new()
	data.id = "test_heightmap"
	data.display_name = "Test Heightmap"
	data.width = map_width
	data.height = map_height
	data.terrain_scale = Vector3(1.0, 8.0, 1.0)

	# Generate height from noise
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.02
	noise.fractal_octaves = 4
	noise.fractal_lacunarity = 2.0
	noise.fractal_gain = 0.5
	noise.seed = 42

	data.initialize(0.0)
	data.generate_from_noise(noise, 1.0)

	# Auto-assign splatmap by height:
	# Layer 0 = grass (low), Layer 1 = dirt (mid), Layer 2 = rock (high), Layer 3 = snow (peak)
	var thresholds := PackedFloat32Array([1.5, 4.0, 6.5])
	data.auto_splatmap_by_height(thresholds)

	# Load real Material-LIB textures
	_add_textured_layers(data)

	# Place test water zones (mountain lake + valley pond)
	_add_test_water_zones(data)

	# Place test structures (small building near player spawn)
	_add_test_structures(data)

	return data


static func _add_textured_layers(data: HeightmapData) -> void:
	## Loads Material-LIB terrain textures into the 4 splatmap layers.
	## Falls back gracefully if textures aren't present (gitignored assets).
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


static func _add_test_water_zones(data: HeightmapData) -> void:
	## Places a few test water bodies at low-lying areas of the map.
	var sx: float = data.terrain_scale.x
	var sz: float = data.terrain_scale.z

	# Mountain lake near center (elliptical)
	var lake := WaterZone.new()
	lake.id = "mountain_lake"
	lake.center = Vector3(float(data.width) * sx * 0.5, 0.8, float(data.height) * sz * 0.4)
	lake.size = Vector2(25.0, 20.0)
	lake.shape = WaterZone.Shape.ELLIPSE
	lake.shallow_color = Color(0.15, 0.45, 0.65, 0.55)
	lake.deep_color = Color(0.04, 0.12, 0.28, 0.85)
	lake.wave_strength = 0.02
	data.water_zones.append(lake)

	# Pond in lower area (elliptical)
	var pond := WaterZone.new()
	pond.id = "valley_pond"
	pond.center = Vector3(float(data.width) * sx * 0.25, 0.3, float(data.height) * sz * 0.6)
	pond.size = Vector2(12.0, 10.0)
	pond.shape = WaterZone.Shape.ELLIPSE
	pond.shallow_color = Color(0.2, 0.5, 0.6, 0.5)
	pond.deep_color = Color(0.06, 0.18, 0.3, 0.8)
	pond.wave_strength = 0.01
	data.water_zones.append(pond)

	# Small fountain pool (circular)
	var fountain := WaterZone.new()
	fountain.id = "fountain"
	fountain.center = Vector3(float(data.width) * sx * 0.7, 2.0, float(data.height) * sz * 0.3)
	fountain.size = Vector2(4.0, 4.0)
	fountain.shape = WaterZone.Shape.ELLIPSE
	fountain.shallow_color = Color(0.25, 0.55, 0.75, 0.6)
	fountain.deep_color = Color(0.1, 0.2, 0.4, 0.7)
	fountain.wave_speed = 0.5
	fountain.wave_strength = 0.03
	data.water_zones.append(fountain)


static func _add_test_structures(data: HeightmapData) -> void:
	## Places a small test building near the player spawn point.
	var sx: float = data.terrain_scale.x
	var sz: float = data.terrain_scale.z
	var sy: float = data.terrain_scale.y
	var cx: float = float(data.width) * sx * 0.5
	var cz: float = float(data.height) * sz * 0.5

	# Get terrain height near center for grounding
	var hx: int = data.width / 2 + 5
	var hz: int = data.height / 2
	var ground_y: float = data.get_height_at(hx, hz) * sy

	# Piece IDs use snake_case from StructureRegistry
	var base_x: float = float(hx) * sx
	var base_z: float = float(hz) * sz

	# Four walls forming a small room
	var wall_ids: Array[String] = [
		"wall_plaster_straight", "wall_plaster_straight",
		"wall_plaster_door_flat", "wall_plaster_straight",
	]
	var wall_positions: Array[Vector3] = [
		Vector3(base_x, ground_y, base_z),          # Front wall
		Vector3(base_x + 4.0, ground_y, base_z),    # Right wall (rotated)
		Vector3(base_x + 4.0, ground_y, base_z + 4.0),  # Back wall
		Vector3(base_x, ground_y, base_z + 4.0),    # Left wall (rotated)
	]
	var wall_rotations: Array[float] = [0.0, PI * 0.5, PI, PI * 1.5]

	for i in range(wall_ids.size()):
		var s := PlacedStructure.new()
		s.piece_id = wall_ids[i]
		s.position = wall_positions[i]
		s.rotation_y = wall_rotations[i]
		data.structures.append(s)

	# Floor
	var floor_s := PlacedStructure.new()
	floor_s.piece_id = "floor_brick"
	floor_s.position = Vector3(base_x, ground_y, base_z)
	data.structures.append(floor_s)

	# Roof
	var roof_s := PlacedStructure.new()
	roof_s.piece_id = "roof_round_tiles_4x4"
	roof_s.position = Vector3(base_x, ground_y + 3.0, base_z)
	data.structures.append(roof_s)
