class_name OverworldPropRegistry
extends RefCounted
## Prop definitions for the overworld map. All props use NONE collision so the
## player walks through them (purely decorative, like classic FF/DQ overworlds).
## Tiny scales (~0.25–0.45) so trees look like map-icon miniatures at overworld
## camera height. No grass patches — too small to see at overworld scale.

const _KIT_PATH := "res://assets/3D/Stylized Nature MegaKit[Standard]/glTF/"

## Layers: 0=Grass, 1=Sand/Dirt, 2=Rock, 3=Snow, 4=Soil, 5=Pebbles, 6=Cliff, 7=Moss
## Bitmask: grass=1, dirt=2, rock=4, snow=8, soil=16, pebbles=32, cliff=64, moss=128
##
## Density is per square metre. With terrain_scale=3, a 16-vert chunk = 45×45m = 2025m².
## density=0.005 → ~10 trees per chunk in fully grassed areas — good mid-range coverage.
const _PROP_TABLE: Array[Dictionary] = [
	# --- Forest trees (island 1, forest zones only, packed tight) ---
	{"id": "ow_tree_1", "file": "CommonTree_1", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 1, "forest": true},
	{"id": "ow_tree_2", "file": "CommonTree_2", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 1, "forest": true},
	{"id": "ow_tree_3", "file": "CommonTree_3", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.025, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 1, "forest": true},

	# --- Dead tree forest (island 2, forest zones only, packed tight) ---
	{"id": "ow_dead_1", "file": "DeadTree_1", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true},
	{"id": "ow_dead_2", "file": "DeadTree_2", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true},
	{"id": "ow_dead_3", "file": "DeadTree_3", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.025, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true},

	# --- Rocks (any island, not forest-only) ---
	{"id": "ow_rock_1", "file": "Rock_Medium_1", "layers": 4 | 32, "density": 0.004, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false},
	{"id": "ow_rock_2", "file": "Rock_Medium_2", "layers": 4 | 32, "density": 0.004, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false},
	{"id": "ow_rock_3", "file": "Rock_Medium_3", "layers": 4 | 32, "density": 0.003, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false},
]

static var _cache: Array[PropDefinition] = []


static func get_all() -> Array[PropDefinition]:
	## Returns all overworld prop definitions, cached after first call.
	if not _cache.is_empty():
		return _cache
	for entry in _PROP_TABLE:
		var def := PropDefinition.new()
		def.id = entry["id"]
		def.scene_path = _KIT_PATH + entry["file"] + ".gltf"
		def.collision_type = PropDefinition.CollisionType.NONE  # All overworld props walk-through
		def.allowed_layers = entry["layers"]
		def.density = entry["density"]
		def.min_scale = entry["min_s"]
		def.max_scale = entry["max_s"]
		def.affected_by_wind = entry["wind"]
		def.lod_distance = entry["lod"]
		def.allowed_island = entry.get("island", 0)
		def.forest_only = entry.get("forest", false)
		def.random_rotation_y = true
		def.max_slope = 50.0  # Allow props on moderate slopes
		_cache.append(def)
	return _cache
