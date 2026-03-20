class_name MapConnection
extends Resource
## Defines a connection point between two maps (e.g., overworld ↔ dungeon).

@export var position: Vector3 = Vector3.ZERO        ## Exit point on THIS map
@export var target_map_id: String = ""               ## Target map ID (e.g. "dungeon_cave")
@export var target_spawn: Vector3 = Vector3.ZERO     ## Spawn position on target map (legacy, used if target_connection_id is empty)
@export var display_name: String = ""                ## HUD label (e.g. "Enter Dark Cave")
@export var unlock_flag: String = ""                 ## Story flag required (empty = always open)
@export var connection_id: String = ""               ## Unique ID for this connection point (e.g. "forest_entrance")
@export var target_connection_id: String = ""        ## ID of the matching connection on the target map (spawn at its position)
