class_name SaveData
extends Resource
## Serializable save state for the entire game.

@export var party_data: Dictionary = {}
@export var stash_items: Array[Dictionary] = []
@export var gold: int = 0
@export var story_flags: Dictionary = {}
@export var world_state: Dictionary = {}
@export var playtime_seconds: float = 0.0
@export var save_timestamp: String = ""
