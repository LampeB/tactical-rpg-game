class_name BackpackTierConfig
extends Resource
## Defines one tier of a character's backpack upgrade ladder.
## Each tier introduces new cells on a shared 25x25 master grid.
## Cells accumulate across tiers — upgrading never removes cells.

@export var tier_index: int = 0
@export var display_name: String = ""

## Cells introduced at this tier, in absolute master-grid coordinates.
## For tier 0, the first auto_unlock_count cells are free (auto-unlocked).
## The remaining cells are purchasable (locked until bought with gold).
@export var new_cells: Array[Vector2i] = []

## How many of new_cells are auto-unlocked (free) when this tier is reached.
## For tier 0, this is the starting inventory size.
## For higher tiers, typically 0 (all new cells must be purchased).
@export var auto_unlock_count: int = 0

## Gold cost per purchasable cell in this tier, in unlock order.
## Length must equal: new_cells.size() - auto_unlock_count.
@export var cell_costs: Array[int] = []

## Gold + Spatial Rune cost to unlock THIS tier from the previous one.
## Both are 0 for tier 0 (active from the very start of a new game).
@export var unlock_gold_cost: int = 0
@export var unlock_rune_count: int = 0
