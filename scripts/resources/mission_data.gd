class_name MissionData
extends Resource
## Defines a mission shown on the Mission Board.
## MVP version — random-encounter only. Will gain encounter_path (for fixed
## encounters), unlock conditions, and story_chapter fields in later iterations.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var summary: String = ""

@export_group("Difficulty")
## Hint shown to the player; doesn't directly affect generation yet.
@export_range(1, 20) var recommended_level: int = 1
## Min/max enemies for the random encounter generator. Inclusive.
@export_range(1, 10) var enemy_count_min: int = 1
@export_range(1, 10) var enemy_count_max: int = 5

@export_group("Rewards")
## Bonus gold awarded on victory (on top of per-enemy gold from EncounterData).
@export var gold_reward: int = 0
@export var xp_reward: int = 0
