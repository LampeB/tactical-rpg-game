class_name PropRegistry
extends RefCounted
## Central registry of all scatterable props. Returns PropDefinition arrays
## filtered by biome layer. Loads glTF models from the Nature MegaKit.

const _KIT_PATH := "res://assets/3D/Stylized Nature MegaKit[Standard]/glTF/"

## Prop categories — each entry: [gltf_name, collision, allowed_layers_bitmask, density, min_scale, max_scale, wind, lod]
## Layers: 0=Grass, 1=Dirt, 2=Rock, 3=Snow  →  bitmask: 1=grass, 2=dirt, 4=rock, 8=snow
## lod: visibility_range_end in metres (0 = no culling)
const _PROP_TABLE: Array[Dictionary] = [
	# --- Trees (blocking, grass + dirt) ---
	{"id": "common_tree_1", "file": "CommonTree_1", "collision": 1, "layers": 3, "density": 0.0015, "min_s": 2.4, "max_s": 3.9, "wind": true,  "lod": 120.0},
	{"id": "common_tree_2", "file": "CommonTree_2", "collision": 1, "layers": 3, "density": 0.0015, "min_s": 2.4, "max_s": 3.9, "wind": true,  "lod": 120.0},
	{"id": "common_tree_3", "file": "CommonTree_3", "collision": 1, "layers": 3, "density": 0.001,  "min_s": 2.4, "max_s": 3.9, "wind": true,  "lod": 120.0},
	{"id": "common_tree_4", "file": "CommonTree_4", "collision": 1, "layers": 3, "density": 0.001,  "min_s": 2.4, "max_s": 3.9, "wind": true,  "lod": 120.0},
	{"id": "common_tree_5", "file": "CommonTree_5", "collision": 1, "layers": 3, "density": 0.001,  "min_s": 2.4, "max_s": 3.9, "wind": true,  "lod": 120.0},
	{"id": "pine_1",        "file": "Pine_1",        "collision": 1, "layers": 7, "density": 0.0015, "min_s": 2.4, "max_s": 4.2, "wind": true,  "lod": 120.0},
	{"id": "pine_2",        "file": "Pine_2",        "collision": 1, "layers": 7, "density": 0.0015, "min_s": 2.4, "max_s": 4.2, "wind": true,  "lod": 120.0},
	{"id": "pine_3",        "file": "Pine_3",        "collision": 1, "layers": 7, "density": 0.001,  "min_s": 2.4, "max_s": 4.2, "wind": true,  "lod": 120.0},
	{"id": "dead_tree_1",   "file": "DeadTree_1",    "collision": 1, "layers": 6, "density": 0.0005, "min_s": 2.1, "max_s": 3.3, "wind": false, "lod": 120.0},
	{"id": "dead_tree_2",   "file": "DeadTree_2",    "collision": 1, "layers": 6, "density": 0.0005, "min_s": 2.1, "max_s": 3.3, "wind": false, "lod": 120.0},
	{"id": "twisted_tree_1","file": "TwistedTree_1", "collision": 1, "layers": 5, "density": 0.0005, "min_s": 2.1, "max_s": 3.6, "wind": true,  "lod": 120.0},
	{"id": "twisted_tree_2","file": "TwistedTree_2", "collision": 1, "layers": 5, "density": 0.0005, "min_s": 2.1, "max_s": 3.6, "wind": true,  "lod": 120.0},

	# --- Rocks (blocking, rock + dirt + snow) ---
	{"id": "rock_medium_1", "file": "Rock_Medium_1", "collision": 1, "layers": 14, "density": 0.003, "min_s": 0.6, "max_s": 1.5, "wind": false, "lod": 80.0},
	{"id": "rock_medium_2", "file": "Rock_Medium_2", "collision": 1, "layers": 14, "density": 0.003, "min_s": 0.6, "max_s": 1.5, "wind": false, "lod": 80.0},
	{"id": "rock_medium_3", "file": "Rock_Medium_3", "collision": 1, "layers": 14, "density": 0.003, "min_s": 0.6, "max_s": 1.5, "wind": false, "lod": 80.0},

	# --- Bushes (blocking, grass) ---
	{"id": "bush_common",  "file": "Bush_Common",        "collision": 1, "layers": 1, "density": 0.005, "min_s": 0.7, "max_s": 1.2, "wind": true, "lod": 60.0},
	{"id": "bush_flowers", "file": "Bush_Common_Flowers", "collision": 1, "layers": 1, "density": 0.004, "min_s": 0.7, "max_s": 1.2, "wind": true, "lod": 60.0},

	# --- Grass (visual only, grass + dirt) ---
	{"id": "grass_short",      "file": "Grass_Common_Short", "collision": 0, "layers": 3, "density": 0.6, "min_s": 0.18, "max_s": 0.39, "wind": true, "lod": 40.0},
	{"id": "grass_tall",       "file": "Grass_Common_Tall",  "collision": 0, "layers": 1, "density": 0.3, "min_s": 0.18, "max_s": 0.39, "wind": true, "lod": 40.0},
	{"id": "grass_wispy_short","file": "Grass_Wispy_Short",  "collision": 0, "layers": 3, "density": 0.4, "min_s": 0.18, "max_s": 0.39, "wind": true, "lod": 40.0},
	{"id": "grass_wispy_tall", "file": "Grass_Wispy_Tall",   "collision": 0, "layers": 1, "density": 0.2, "min_s": 0.18, "max_s": 0.39, "wind": true, "lod": 40.0},

	# --- Flowers (visual only, grass) ---
	{"id": "flower_3_group", "file": "Flower_3_Group", "collision": 0, "layers": 1, "density": 0.008, "min_s": 0.21, "max_s": 0.36, "wind": true, "lod": 40.0},
	{"id": "flower_4_group", "file": "Flower_4_Group", "collision": 0, "layers": 1, "density": 0.008, "min_s": 0.21, "max_s": 0.36, "wind": true, "lod": 40.0},
	{"id": "clover_1", "file": "Clover_1", "collision": 0, "layers": 1, "density": 0.01,  "min_s": 0.18, "max_s": 0.33, "wind": true, "lod": 40.0},
	{"id": "clover_2", "file": "Clover_2", "collision": 0, "layers": 1, "density": 0.01,  "min_s": 0.18, "max_s": 0.33, "wind": true, "lod": 40.0},
	{"id": "fern_1",   "file": "Fern_1",   "collision": 0, "layers": 3, "density": 0.01,  "min_s": 0.18, "max_s": 0.36, "wind": true, "lod": 40.0},
	{"id": "plant_1",  "file": "Plant_1",  "collision": 0, "layers": 1, "density": 0.006, "min_s": 0.21, "max_s": 0.33, "wind": true, "lod": 40.0},

	# --- Small decorations (visual only, various) ---
	{"id": "mushroom", "file": "Mushroom_Common", "collision": 0, "layers": 3,  "density": 0.003, "min_s": 0.6, "max_s": 1.2, "wind": false, "lod": 30.0},
	{"id": "pebble_1", "file": "Pebble_Round_1",  "collision": 0, "layers": 6,  "density": 0.008, "min_s": 0.5, "max_s": 1.5, "wind": false, "lod": 30.0},
	{"id": "pebble_2", "file": "Pebble_Round_2",  "collision": 0, "layers": 6,  "density": 0.008, "min_s": 0.5, "max_s": 1.5, "wind": false, "lod": 30.0},
	{"id": "pebble_3", "file": "Pebble_Square_1", "collision": 0, "layers": 14, "density": 0.005, "min_s": 0.5, "max_s": 1.5, "wind": false, "lod": 30.0},
]

static var _cache: Array[PropDefinition] = []


static func get_all() -> Array[PropDefinition]:
	## Returns all prop definitions, cached after first call.
	if not _cache.is_empty():
		return _cache
	for entry in _PROP_TABLE:
		var def := PropDefinition.new()
		def.id = entry["id"]
		def.scene_path = _KIT_PATH + entry["file"] + ".gltf"
		def.collision_type = entry["collision"] as PropDefinition.CollisionType
		def.allowed_layers = entry["layers"]
		def.density = entry["density"]
		def.min_scale = entry["min_s"]
		def.max_scale = entry["max_s"]
		def.affected_by_wind = entry["wind"]
		def.lod_distance = entry["lod"]
		def.random_rotation_y = true
		def.max_slope = 45.0
		_cache.append(def)
	return _cache


static func get_for_layer(layer_index: int) -> Array[PropDefinition]:
	## Returns props allowed on the given splatmap layer.
	var bit: int = 1 << layer_index
	var result: Array[PropDefinition] = []
	for def in get_all():
		if def.allowed_layers & bit:
			result.append(def)
	return result
