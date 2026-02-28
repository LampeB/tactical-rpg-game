class_name QuestData
extends Resource
## Defines a quest's identity, objectives, rewards, and prerequisites.
## Stored as .tres files in data/quests/.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var icon: Texture2D = null

@export_group("Objectives")
@export var objectives: Array[QuestObjective] = []

@export_group("Rewards")
@export var reward_gold: int = 0
@export var reward_items: Array[ItemData] = []
@export var reward_xp: int = 0

@export_group("Prerequisites")
@export var required_flags: Array[String] = []         ## All must be true
@export var required_level: int = 0
@export var prerequisite_quest_ids: Array[String] = [] ## Must be completed first

@export_group("Config")
@export var is_main_quest: bool = false
@export var is_repeatable: bool = false
@export var auto_accept: bool = false    ## Accept on trigger without dialog
@export var quest_giver_npc_id: String = ""  ## NPC who offers the quest (for marker icons)
@export var turn_in_npc_id: String = ""  ## NPC to complete the quest at ("" = auto-complete)
