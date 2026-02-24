extends Node
## Central color palette for all UI backgrounds and grid elements.
## Every ColorRect/background color in the game reads from here.
## Edit this file to restyle the entire UI at once.

# ── Scene backgrounds ───────────────────────────────────────────────
const BG_MAIN_MENU     := Color(0.10, 0.12, 0.18, 1)
const BG_CHARACTER_HUB := Color(0.232, 0.024, 0.391, 1.0)
const BG_CHARACTER_STATS := Color(0.071, 0.0, 0.508, 1.0)
const BG_ITEM_EDITOR   := Color(0.974, 0.0, 0.429, 1.0)
const BG_LOOT          := Color(0.147, 0.501, 0.573, 1.0)
const BG_BATTLE        := Color(0.0, 0.558, 0.172, 1.0)
const BG_PASSIVE_TREE  := Color(0.674, 0.335, 0.934, 1.0)
const BG_SETTINGS      := Color(0.0, 0.0, 0.0, 1.0)
const BG_SQUAD         := Color(0.453, 0.365, 0.0, 1.0)

# ── Inventory grid cell ─────────────────────────────────────────────
const GRID_CELL_BG     := Color(0.20, 0.20, 0.30, 0.8)
const GRID_CELL_BORDER := Color(0.40, 0.40, 0.50, 0.3)
