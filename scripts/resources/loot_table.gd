class_name LootTable
extends Resource
## Defines what items can drop and their probabilities.

@export var id: String = ""

## Each entry: { item: ItemData, weight: float, min_count: int, max_count: int }
@export var entries: Array = [] ## of LootEntry

## How many rolls to make on this table.
@export var roll_count: int = 1

## Guaranteed drops (always included regardless of rolls).
@export var guaranteed_drops: Array = [] ## of ItemData
