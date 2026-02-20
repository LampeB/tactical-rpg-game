class_name LootEntry
extends Resource
## A single entry in a loot table. Each entry = one potential item drop.
## To allow multiple of the same item, add the entry multiple times to the table.

@export var item: ItemData

## Independent drop chance (0.0 to 1.0). If > 0, uses this instead of weight.
## Example: 0.1 = 10% chance, 0.8 = 80% chance, 1.0 = 100% guaranteed
@export_range(0.0, 1.0, 0.01) var drop_chance: float = 0.0

## Weight for weighted random selection (only used if drop_chance is 0).
## Legacy system - prefer using drop_chance for clarity.
@export var weight: float = 1.0
