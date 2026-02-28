class_name QuestObjective
extends Resource
## A single objective within a quest.
## Progress tracked via GameManager.story_flags using progress_flag key.

enum ObjectiveType { KILL, COLLECT, TALK_TO, REACH_LOCATION, DEFEAT_BOSS, SET_FLAG }

@export var objective_type: ObjectiveType = ObjectiveType.KILL
@export var description: String = ""  ## e.g. "Kill 5 goblins"

@export_group("Target")
@export var target_id: String = ""  ## enemy_id, item_id, npc_id, or location_id
@export var target_count: int = 1   ## How many to kill/collect

@export_group("Tracking")
## GameManager flag key for tracking progress. Convention: quest_<quest_id>_obj_<index>
## Set automatically by QuestManager when quest is accepted.
@export var progress_flag: String = ""
