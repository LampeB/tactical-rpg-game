class_name BackpackTierConfig
extends Resource
## Defines one tier of a character's backpack upgrade ladder.
## Within a tier, cells are purchased one at a time with gold.
## Advancing to the next tier requires gold + Spatial Runes.

@export var tier_index: int = 0
@export var display_name: String = ""

## Full bounding box for this tier (includes both active and purchasable cells).
## Inactive cells in the bounding box appear grayed-out in the UI — the player
## can see exactly what they are working toward within this tier.
@export var bounding_width: int = 6
@export var bounding_height: int = 6

## How many cells are already active when this tier is first obtained.
## For tier 0 this equals the character's default starting inventory size.
@export var initial_cell_count: int = 36

## Gold cost per cell, in unlock order.
## Length must equal: total cells in layout − initial_cell_count.
@export var cell_costs: Array[int] = []

## Gold + Spatial Rune cost to unlock THIS tier from the previous one.
## Both are 0 for tier 0 (active from the very start of a new game).
@export var unlock_gold_cost: int = 0
@export var unlock_rune_count: int = 0

## Growth direction used when generating the auto layout (no custom_cell_layout set).
## 0 = ROWS : cells added row-by-row from the bottom  (height growth tiers T1–T3).
## 1 = COLUMNS : cells added column-by-column from the right (width growth tiers T4–T6).
@export var growth_direction: int = 0

## Optional fully-custom cell layout defining the unlock order for every cell.
## When non-empty this overrides the auto-generated row/column layout.
## Used for the T6 unique irregular backpack shape.
## Length must equal bounding_width × bounding_height (or the intended total cell count).
@export var custom_cell_layout: Array[Vector2i] = []
