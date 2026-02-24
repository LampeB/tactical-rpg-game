class_name NpcData
extends Resource
## Data resource for a single NPC: identity, role, and full dialogue tree.

enum NpcRole {
	GENERIC,
	SHOPKEEPER,
	QUEST_GIVER,
}

@export var id: String = ""
@export var display_name: String = ""
@export var portrait: Texture2D = null          ## Optional face texture shown in dialogue.
@export var role: NpcRole = NpcRole.GENERIC
@export var shop_id: String = ""               ## Used when role == SHOPKEEPER.
@export var conversations: Array[DialogueConversation] = []
