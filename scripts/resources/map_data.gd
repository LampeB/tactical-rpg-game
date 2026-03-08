class_name MapData
extends Resource
## Defines a complete map: terrain grid, placed elements, decoration zones, metadata.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""

@export_group("Grid")
@export var grid_width: int = 80
@export var grid_height: int = 50
## Flat array of terrain block indices, row-major: index = z * grid_width + x.
## Values map to Block enum: 0=Grass, 1=Dirt, 2=Stone, 3=Water, 4=Path, 5=Sand, 6=DarkGrass, 7=Snow.
@export var terrain_cells: PackedInt32Array = PackedInt32Array()

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


func initialize_terrain(default_block: int = 0) -> void:
	## Fills the entire terrain grid with a single block type.
	terrain_cells.resize(grid_width * grid_height)
	terrain_cells.fill(default_block)
