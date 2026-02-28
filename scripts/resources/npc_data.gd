class_name NpcData
extends Resource
## Data resource for a single NPC: identity, role, and full dialogue tree.

enum NpcRole {
	GENERIC,
	SHOPKEEPER,
	QUEST_GIVER,
	CRAFTSMAN,
}

@export var id: String = ""
@export var display_name: String = ""
@export var sprite: Texture2D = null                    ## Overworld sprite shown on the map.
@export var portrait: Texture2D = null                  ## Optional face texture shown in dialogue.
@export_group("3D Model")
## Custom 3D model scene. Null = CSG placeholder from CSGCharacterFactory.
@export var model_scene: PackedScene
## CSG placeholder tint color.
@export var model_color: Color = Color(0.6, 0.6, 0.6)

@export_group("Role")
@export var role: NpcRole = NpcRole.GENERIC
@export var shop_id: String = ""                       ## Used when role == SHOPKEEPER.
@export var crafting_station_id: String = ""           ## Used when role == CRAFTSMAN.
@export var conversations: Array[DialogueConversation] = []
