class_name EncounterData
extends Resource
## Defines a combat encounter: which enemies appear.

@export var id: String = ""
@export var display_name: String = ""

## Enemy groups — each entry is an EnemyData (can repeat for multiples).
@export var enemies: Array[EnemyData] = []

## Whether this encounter can be fled from.
@export var can_flee: bool = true

## Bonus gold awarded for clearing the encounter (on top of per-enemy gold).
@export var bonus_gold: int = 0

## Override loot table (if set, used instead of per-enemy loot).
@export var override_loot_table: LootTable
