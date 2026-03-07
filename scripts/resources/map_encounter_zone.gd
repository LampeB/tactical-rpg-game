class_name MapEncounterZone
extends Resource
## Associates a rectangular area on the map with random encounter data.

@export var rect: Rect2 = Rect2(0, 0, 10, 10)  ## XZ bounds
@export var encounter_zone_data_path: String = ""  ## Path to EncounterZoneData .tres
