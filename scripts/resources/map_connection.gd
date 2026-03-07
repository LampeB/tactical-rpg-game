class_name MapConnection
extends Resource
## Defines a connection between two locations for fast travel or transitions.

@export var from_location_id: String = ""
@export var to_location_id: String = ""
@export var bidirectional: bool = true
@export var unlock_flag: String = ""  ## Story flag required (empty = always available)
