class_name MapData
extends Resource
## Defines a complete map: terrain grid, placed elements, decoration zones, metadata.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
## Optional path to a .tscn scene containing HeightmapTerrain3D. Empty = procedural generation.
@export_file("*.tscn") var map_scene_path: String = ""
## True for the main overworld map. False for local maps (forests, caves, towns).
@export var is_overworld: bool = false

@export_group("Grid")
@export var grid_width: int = 80
@export var grid_height: int = 50
## Flat array of terrain block indices, row-major: index = z * grid_width + x.
## Values correspond to Enums.Block (GRASS=0, DIRT=1, STONE=2, WATER=3, PATH=4, SAND=5, DARK_GRASS=6, SNOW=7).
@export var terrain_cells: PackedInt32Array = PackedInt32Array()
## Flat array of terrain Y-levels, row-major: index = z * grid_width + x.
## Default 0 = ground level. Positive values raise terrain cells.
@export var terrain_heights: PackedInt32Array = PackedInt32Array()

## Extra terrain blocks for multi-level maps. Key: "x,y,z" string, value: block type int.
## The primary terrain_cells/terrain_heights store one block per (x,z) column;
## any additional blocks at different Y-levels for the same (x,z) go here.
@export var extra_terrain: Dictionary = {}

@export_group("Player")
@export var player_spawn: Vector3 = Vector3(30, 0, 17)

@export_group("Elements")
@export var elements: Array[MapElement] = []

@export_group("Decoration Zones")
@export var decoration_zones: Array[DecorationZoneData] = []
@export var decoration_seed: int = 42

@export_group("Encounter Zones")
@export var encounter_zones: Array[MapEncounterZone] = []

@export_group("Connections")
@export var connections: Array[MapConnection] = []

@export_group("Battle Areas")
@export var battle_areas: Array[BattleAreaData] = []

@export_group("Safe Zones")
## Rect2 zones where enemies cannot patrol (x, z, width, depth).
@export var enemy_safe_zones: Array[Rect2] = []


func get_terrain_at(x: int, z: int) -> int:
	## Returns the block type at cell (x, z). Returns 0 (Grass) for out-of-bounds.
	if x < 0 or x >= grid_width or z < 0 or z >= grid_height:
		return 0
	return terrain_cells[z * grid_width + x]


func set_terrain_at(x: int, z: int, block_type: int) -> void:
	## Sets the block type at cell (x, z). No-op for out-of-bounds.
	if x < 0 or x >= grid_width or z < 0 or z >= grid_height:
		return
	terrain_cells[z * grid_width + x] = block_type


func get_height_at(x: int, z: int) -> int:
	## Returns the terrain Y-level at cell (x, z). Returns 0 for out-of-bounds or uninitialized.
	if x < 0 or x >= grid_width or z < 0 or z >= grid_height:
		return 0
	if terrain_heights.is_empty():
		return 0
	return terrain_heights[z * grid_width + x]


func set_height_at(x: int, z: int, height: int) -> void:
	## Sets the terrain Y-level at cell (x, z). Auto-initializes heights array if needed.
	if x < 0 or x >= grid_width or z < 0 or z >= grid_height:
		return
	_ensure_heights()
	terrain_heights[z * grid_width + x] = height


func _ensure_heights() -> void:
	## Lazily initializes terrain_heights to match terrain_cells size.
	var expected: int = grid_width * grid_height
	if terrain_heights.size() != expected:
		terrain_heights.resize(expected)
		terrain_heights.fill(0)


func get_extra_terrain_at(x: int, y: int, z: int) -> int:
	## Returns the extra terrain block at (x, y, z), or -1 if none exists.
	var key: String = "%d,%d,%d" % [x, y, z]
	if extra_terrain.has(key):
		return extra_terrain[key] as int
	return -1


func set_extra_terrain_at(x: int, y: int, z: int, block_type: int) -> void:
	## Sets an extra terrain block at (x, y, z).
	var key: String = "%d,%d,%d" % [x, y, z]
	extra_terrain[key] = block_type


func remove_extra_terrain_at(x: int, y: int, z: int) -> void:
	## Removes an extra terrain block at (x, y, z).
	var key: String = "%d,%d,%d" % [x, y, z]
	extra_terrain.erase(key)


func initialize_terrain(default_block: int = 0) -> void:
	## Fills the entire terrain grid with a single block type.
	terrain_cells.resize(grid_width * grid_height)
	terrain_cells.fill(default_block)
	terrain_heights.resize(grid_width * grid_height)
	terrain_heights.fill(0)
