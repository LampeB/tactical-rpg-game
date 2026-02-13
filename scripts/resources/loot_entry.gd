class_name LootEntry
extends Resource
## A single entry in a loot table.

@export var item: ItemData
@export var weight: float = 1.0
@export var min_count: int = 1
@export var max_count: int = 1
