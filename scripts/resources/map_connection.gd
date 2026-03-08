class_name MapConnection
extends Resource
## Defines a connection point between two maps (e.g., overworld ↔ dungeon).

@export var position: Vector3 = Vector3.ZERO        ## Exit point on THIS map
@export var target_map_id: String = ""               ## Target map ID (e.g. "dungeon_cave")
@export var target_spawn: Vector3 = Vector3.ZERO     ## Spawn position on target map
@export var display_name: String = ""                ## HUD label (e.g. "Enter Dark Cave")
@export var unlock_flag: String = ""                 ## Story flag required (empty = always open)
