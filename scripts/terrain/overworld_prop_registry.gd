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
## Zone bitmasks: bit N = zone N allowed. 0 = all zones.
## Zone IDs: 1=jungle, 2=desert, 3=swamp, 4=deathblight, 5=fortress
const _Z_JUNGLE: int = 1 << 1
const _Z_DESERT: int = 1 << 2
const _Z_SWAMP: int = 1 << 3
const _Z_DEATH: int = 1 << 4
const _Z_FORT: int = 1 << 5

const _PROP_TABLE: Array[Dictionary] = [
	# --- Living trees (jungle + fortress, forest zones only) ---
	{"id": "ow_tree_1", "file": "CommonTree_1", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 0, "forest": true, "zones": _Z_JUNGLE | _Z_FORT},
	{"id": "ow_tree_2", "file": "CommonTree_2", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 0, "forest": true, "zones": _Z_JUNGLE | _Z_FORT},
	{"id": "ow_tree_3", "file": "CommonTree_3", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.025, "min_s": 0.18, "max_s": 0.30, "wind": true,  "lod": 200.0, "island": 0, "forest": true, "zones": _Z_JUNGLE | _Z_FORT},

	# --- Dead trees (deathblight patch within jungle) ---
	{"id": "ow_blight_1", "file": "DeadTree_1", "layers": 1 | 2 | 4 | 16 | 32 | 64 | 128, "density": 0.012, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_DEATH},
	{"id": "ow_blight_2", "file": "DeadTree_2", "layers": 1 | 2 | 4 | 16 | 32 | 64 | 128, "density": 0.012, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_DEATH},
	{"id": "ow_blight_3", "file": "DeadTree_3", "layers": 1 | 2 | 4 | 16 | 32 | 64 | 128, "density": 0.008, "min_s": 0.16, "max_s": 0.28, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_DEATH},

	# --- Swamp dead trees (sparse, scattered across swamp zone) ---
	{"id": "ow_swamp_1", "file": "DeadTree_4", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.006, "min_s": 0.16, "max_s": 0.28, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_SWAMP},
	{"id": "ow_swamp_2", "file": "DeadTree_5", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.006, "min_s": 0.16, "max_s": 0.28, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_SWAMP},

	# --- Dead trees (cliff island, forest zones) ---
	{"id": "ow_dead_1", "file": "DeadTree_1", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true, "zones": 0},
	{"id": "ow_dead_2", "file": "DeadTree_2", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.035, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true, "zones": 0},
	{"id": "ow_dead_3", "file": "DeadTree_3", "layers": 1 | 2 | 4 | 16 | 128, "density": 0.025, "min_s": 0.18, "max_s": 0.30, "wind": false, "lod": 200.0, "island": 2, "forest": true, "zones": 0},

	# --- Desert twisted trees (sparse, no wind — stand-in for dead vegetation) ---
	{"id": "ow_desert_1", "file": "TwistedTree_1", "layers": 1 | 2 | 4 | 16 | 32, "density": 0.003, "min_s": 0.16, "max_s": 0.26, "wind": false, "lod": 200.0, "island": 1, "forest": false, "zones": _Z_DESERT},

	# --- Rocks (any island, all zones) ---
	{"id": "ow_rock_1", "file": "Rock_Medium_1", "layers": 4 | 32, "density": 0.004, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false, "zones": 0},
	{"id": "ow_rock_2", "file": "Rock_Medium_2", "layers": 4 | 32, "density": 0.004, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false, "zones": 0},
	{"id": "ow_rock_3", "file": "Rock_Medium_3", "layers": 4 | 32, "density": 0.003, "min_s": 0.12, "max_s": 0.28, "wind": false, "lod": 120.0, "island": 0, "forest": false, "zones": 0},

	# --- Desert rocks (higher density in desert) ---
	{"id": "ow_drock_1", "file": "Rock_Medium_1", "layers": 2 | 4 | 16 | 32, "density": 0.008, "min_s": 0.14, "max_s": 0.32, "wind": false, "lod": 120.0, "island": 1, "forest": false, "zones": _Z_DESERT},
	{"id": "ow_drock_2", "file": "Rock_Medium_2", "layers": 2 | 4 | 16 | 32, "density": 0.008, "min_s": 0.14, "max_s": 0.32, "wind": false, "lod": 120.0, "island": 1, "forest": false, "zones": _Z_DESERT},
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
		def.allowed_zones = entry.get("zones", 0)
		def.random_rotation_y = true
		def.max_slope = 50.0  # Allow props on moderate slopes
		_cache.append(def)
	return _cache
