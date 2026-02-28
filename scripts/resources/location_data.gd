class_name LocationData
extends Resource
## Defines an overworld location (town, dungeon, shop, etc.)

@export_group("Identity")
@export var id: String = ""  ## Unique identifier (e.g., "town_start", "dungeon_forest")
@export var display_name: String = ""  ## Display name shown to player
@export_multiline var description: String = ""
@export var icon: Texture2D  ## Map marker icon

@export_group("Scene")
@export_file("*.tscn") var scene_path: String = ""  ## Scene to load when entered
@export var entrance_position: Vector3 = Vector3.ZERO  ## Where player spawns in location

@export_group("Unlocking")
@export var unlock_flag: String = ""  ## Story flag required to access (empty = always unlocked)
@export var is_visible_when_locked: bool = true  ## Show greyed-out marker when locked?

@export_group("Fast Travel")
@export var allow_fast_travel_to: bool = true  ## Can warp here via fast travel menu?
@export var must_visit_first: bool = true  ## Require visiting before fast travel enabled?

@export_group("Type")
enum LocationType { TOWN, DUNGEON, LANDMARK, SHOP, INN, LAKE, CAVE }
@export var location_type: LocationType = LocationType.TOWN
