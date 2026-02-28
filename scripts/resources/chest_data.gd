class_name ChestData
extends Resource
## Defines a chest's contents, unlock conditions, and visual type.
## Placed on the overworld via ChestMarker scenes.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = "Chest"
@export var description: String = ""

@export_group("Content")
@export var loot_table: LootTable = null
@export var guaranteed_items: Array[ItemData] = []
@export var gold_reward: int = 0

@export_group("Grid")
## Grid shape for the loot screen. Null uses the default 8x5 grid.
@export var loot_grid_template: GridTemplate = null

@export_group("Unlocking")
## Story flag required to open this chest (empty = always unlockable).
@export var unlock_flag: String = ""
@export var is_visible_when_locked: bool = true
@export var locked_message: String = "This chest is locked."

@export_group("Behavior")
## If true, the chest can only be looted once (state persisted via story flags).
@export var one_time_only: bool = true
## Visual style for the 3D model: wooden, iron, gold, ornate.
@export var visual_type: String = "wooden"
