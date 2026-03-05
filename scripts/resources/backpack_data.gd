class_name BackpackData
extends Resource
## Single-file container for a character's backpack tier layout.
## Stores a 25×25 grid where each cell holds its tier value, plus per-tier metadata.
## Lazily generates BackpackTierConfig objects for runtime consumption.

const GRID_SIZE := 25
const TIER_COUNT := 10

## 625-element flat grid. cell_tiers[y * 25 + x] gives the tier value:
## -1 = void, 0 = auto-unlock (tier 0 free cells), 1 = tier 0 purchasable,
## 2 = tier 1, 3 = tier 2, ..., 10 = tier 9
@export var cell_tiers: PackedInt32Array = PackedInt32Array()

## Per-tier metadata (10 entries, index 0..9)
@export var tier_names: PackedStringArray = PackedStringArray()
@export var tier_unlock_gold: PackedInt32Array = PackedInt32Array()
@export var tier_unlock_runes: PackedInt32Array = PackedInt32Array()
## Cell gold costs per tier. Each element is an Array[int].
@export var tier_cell_costs: Array = []

var _cached_tiers: Array[BackpackTierConfig] = []
var _cache_valid := false


func get_tier_configs() -> Array[BackpackTierConfig]:
	if not _cache_valid:
		_rebuild_cache()
	return _cached_tiers


func invalidate_cache() -> void:
	_cache_valid = false


func _rebuild_cache() -> void:
	_cached_tiers.clear()
	for tier_idx in range(TIER_COUNT):
		var config := BackpackTierConfig.new()
		config.tier_index = tier_idx
		if tier_idx < tier_names.size():
			config.display_name = tier_names[tier_idx]
		if tier_idx < tier_unlock_gold.size():
			config.unlock_gold_cost = tier_unlock_gold[tier_idx]
		if tier_idx < tier_unlock_runes.size():
			config.unlock_rune_count = tier_unlock_runes[tier_idx]

		# Collect cells for this tier from the grid (scan order: top→bottom, left→right)
		var auto_cells: Array[Vector2i] = []
		var purchasable_cells: Array[Vector2i] = []
		for y in range(GRID_SIZE):
			for x in range(GRID_SIZE):
				var val: int = cell_tiers[y * GRID_SIZE + x]
				if tier_idx == 0:
					if val == 0:
						auto_cells.append(Vector2i(x, y))
					elif val == 1:
						purchasable_cells.append(Vector2i(x, y))
				else:
					if val == tier_idx + 1:
						purchasable_cells.append(Vector2i(x, y))

		var new_cells: Array[Vector2i] = []
		new_cells.append_array(auto_cells)
		new_cells.append_array(purchasable_cells)
		config.new_cells = new_cells
		config.auto_unlock_count = auto_cells.size()

		if tier_idx < tier_cell_costs.size():
			config.cell_costs.assign(tier_cell_costs[tier_idx])

		_cached_tiers.append(config)
	_cache_valid = true
