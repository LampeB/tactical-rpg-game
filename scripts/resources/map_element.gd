class_name MapElement
extends Resource
## Lightweight placement descriptor for a single object on the map.

enum ElementType {
	NPC,         ## References NpcData via resource_id (npc_id)
	ENEMY,       ## References EncounterData via resource_id (.tres path)
	CHEST,       ## References ChestData via resource_id (chest_id)
	LOCATION,    ## References LocationData via resource_id (.tres path)
	DECORATION,  ## References a scene via resource_id (.tscn path)
	SIGN,        ## A sign post scene
	FENCE,       ## A fence segment scene
}

@export var element_type: ElementType = ElementType.DECORATION

@export_group("Position")
@export var position: Vector3 = Vector3.ZERO
@export var rotation_y: float = 0.0

@export_group("Reference")
## Meaning depends on element_type:
##   NPC: npc_id (e.g. "blacksmith")
##   ENEMY: encounter .tres path (e.g. "res://data/encounters/encounter_slimes.tres")
##   CHEST: chest_id (e.g. "test_chest_wooden")
##   LOCATION: location .tres path (e.g. "res://data/locations/town_start.tres")
##   DECORATION/SIGN/FENCE: scene .tscn path
@export var resource_id: String = ""

@export_group("Enemy")
@export var enemy_color: Color = Color(1, 0.3, 0.3)
@export var patrol_distance: float = 3.0

@export_group("Sign")
@export var sign_label: String = ""
