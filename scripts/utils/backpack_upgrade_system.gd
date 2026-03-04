class_name BackpackUpgradeSystem
extends RefCounted
## Stateless utility for backpack tier upgrades (master-grid model).
## Mirrors ItemUpgradeSystem — all methods are static, no scene tree dependency.
## The authoritative state lives in Party.backpack_states (persisted via SaveManager).
## State format: { "tier": int, "purchased_cells": Array }
## purchased_cells is CUMULATIVE across all tiers — it never resets on upgrade.
## The cost of the next purchase is global_costs[purchased_cells.size()],
## where global_costs is the concatenation of cell_costs from tiers 0..current.


## Returns the union of all new_cells from tiers 0..tier_idx.
## This is the full shape (layout) visible to the player at the given tier.
static func get_layout_cells(character: CharacterData, tier_idx: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var count: int = mini(tier_idx + 1, character.backpack_tiers.size())
	for t_idx in range(count):
		var config: BackpackTierConfig = character.backpack_tiers[t_idx]
		for cell in config.new_cells:
			if not result.has(cell):
				result.append(cell)
	return result


## Returns all cells that are auto-unlocked (free) from tiers 0..tier_idx.
static func get_auto_unlocked_cells(character: CharacterData, tier_idx: int) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var count: int = mini(tier_idx + 1, character.backpack_tiers.size())
	for t_idx in range(count):
		var config: BackpackTierConfig = character.backpack_tiers[t_idx]
		for i in range(mini(config.auto_unlock_count, config.new_cells.size())):
			var cell: Vector2i = config.new_cells[i]
			if not result.has(cell):
				result.append(cell)
	return result


## Build the concatenated cost array across all tiers 0..tier_idx.
## The Nth purchase globally uses global_costs[N].
static func get_global_costs(character: CharacterData, tier_idx: int) -> Array[int]:
	var result: Array[int] = []
	var count: int = mini(tier_idx + 1, character.backpack_tiers.size())
	for t_idx in range(count):
		var config: BackpackTierConfig = character.backpack_tiers[t_idx]
		result.append_array(config.cell_costs)
	return result


## Compute the bounding box from a set of cells. Returns Vector2i(width, height).
static func compute_bounding_box(cells: Array[Vector2i]) -> Vector2i:
	if cells.is_empty():
		return Vector2i(1, 1)
	var max_x: int = 0
	var max_y: int = 0
	for cell in cells:
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	return Vector2i(max_x + 1, max_y + 1)


## Build a GridTemplate reflecting the current backpack state.
## Active cells = auto-unlocked + player-purchased (cumulative).
## Layout cells = all cells from tiers 0..current.
## Bounding box computed dynamically from layout.
static func build_grid_template(character: CharacterData, state: Dictionary) -> GridTemplate:
	var tier_idx: int = state.get("tier", 0)
	var layout: Array[Vector2i] = get_layout_cells(character, tier_idx)
	var auto_unlocked: Array[Vector2i] = get_auto_unlocked_cells(character, tier_idx)

	# Active cells = auto-unlocked + purchased (cumulative across all tiers).
	var active: Array[Vector2i] = auto_unlocked.duplicate()
	var purchased: Array = state.get("purchased_cells", [])
	for cell in purchased:
		var v: Vector2i = cell if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
		if not active.has(v):
			active.append(v)

	var bbox: Vector2i = compute_bounding_box(layout)
	var config: BackpackTierConfig = character.backpack_tiers[tier_idx]

	var tpl := GridTemplate.new()
	tpl.id = "grid_%s_t%d" % [character.id, tier_idx + 1]
	tpl.display_name = config.display_name
	tpl.width = bbox.x
	tpl.height = bbox.y
	tpl.active_cells = active
	tpl.layout_cells = layout.duplicate()
	return tpl


## Returns the gold cost of the NEXT cell purchase, or -1 if maxed out.
static func get_next_cell_cost(character: CharacterData, state: Dictionary) -> int:
	var tier_idx: int = state.get("tier", 0)
	var global_costs: Array[int] = get_global_costs(character, tier_idx)
	var purchased_count: int = state.get("purchased_cells", []).size()
	if purchased_count >= global_costs.size():
		return -1
	return global_costs[purchased_count]


## Returns all cells the player can still purchase.
## A cell is purchasable only if it is orthogonally adjacent to at least one
## already-active cell (initial or previously purchased). This prevents skipping
## ahead and forces organic outward growth from the starting block.
static func get_purchasable_cells(character: CharacterData, state: Dictionary) -> Array[Vector2i]:
	var tier_idx: int = state.get("tier", 0)
	var global_costs: Array[int] = get_global_costs(character, tier_idx)
	var purchased: Array = state.get("purchased_cells", [])
	if purchased.size() >= global_costs.size():
		return []  # All purchasable cells are already bought.

	var layout: Array[Vector2i] = get_layout_cells(character, tier_idx)
	var auto_unlocked: Array[Vector2i] = get_auto_unlocked_cells(character, tier_idx)

	# Build the full set of currently active cells for adjacency checks.
	var active: Array[Vector2i] = auto_unlocked.duplicate()
	for cell in purchased:
		var v: Vector2i = cell if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
		if not active.has(v):
			active.append(v)

	var result: Array[Vector2i] = []
	for cell in layout:
		if active.has(cell):
			continue  # Already unlocked.
		if _is_adjacent_to_active(cell, active):
			result.append(cell)
	return result


## Returns true if `cell` has at least one orthogonal neighbor in `active_cells`.
static func _is_adjacent_to_active(cell: Vector2i, active_cells: Array[Vector2i]) -> bool:
	var neighbors: Array[Vector2i] = [
		Vector2i(cell.x - 1, cell.y),
		Vector2i(cell.x + 1, cell.y),
		Vector2i(cell.x, cell.y - 1),
		Vector2i(cell.x, cell.y + 1),
	]
	for n in neighbors:
		if active_cells.has(n):
			return true
	return false


## Check if a specific cell can be purchased (it must be purchasable and gold must suffice).
## Returns: { ok: bool, reason: String, cost: int }
static func can_expand(character: CharacterData, state: Dictionary, cell: Vector2i, gold: int) -> Dictionary:
	var purchasable: Array[Vector2i] = get_purchasable_cells(character, state)
	if not purchasable.has(cell):
		return {"ok": false, "reason": "Cell not available for purchase.", "cost": 0}

	var cost: int = get_next_cell_cost(character, state)
	if cost < 0:
		return {"ok": false, "reason": "Already at maximum size.", "cost": 0}
	if gold < cost:
		return {"ok": false, "reason": "Not enough gold (need %d)." % cost, "cost": cost}

	return {"ok": true, "reason": "", "cost": cost}


## Purchase a specific cell chosen by the player: mutates the state dict, returns gold spent or -1.
static func expand(character: CharacterData, state: Dictionary, cell: Vector2i, gold_available: int) -> int:
	var check: Dictionary = can_expand(character, state, cell, gold_available)
	if not check.ok:
		return -1
	var purchased: Array = state.get("purchased_cells", [])
	purchased.append(cell)
	state["purchased_cells"] = purchased
	return check.cost


## Check if the next tier can be unlocked (party-wide rune pool, single gold payment).
## Returns: { ok: bool, reason: String, cost_gold: int, cost_runes: int }
static func can_unlock_next_tier(
	character: CharacterData, state: Dictionary, gold: int, rune_count: int
) -> Dictionary:
	var current_tier: int = state.get("tier", 0)
	var next_tier: int = current_tier + 1

	if next_tier >= character.backpack_tiers.size():
		return {"ok": false, "reason": "Already at maximum tier.", "cost_gold": 0, "cost_runes": 0}

	var next_config: BackpackTierConfig = character.backpack_tiers[next_tier]

	if gold < next_config.unlock_gold_cost:
		return {
			"ok": false,
			"reason": "Not enough gold (need %d)." % next_config.unlock_gold_cost,
			"cost_gold": next_config.unlock_gold_cost,
			"cost_runes": next_config.unlock_rune_count,
		}
	if rune_count < next_config.unlock_rune_count:
		return {
			"ok": false,
			"reason": "Need %d Spatial Rune(s)." % next_config.unlock_rune_count,
			"cost_gold": next_config.unlock_gold_cost,
			"cost_runes": next_config.unlock_rune_count,
		}
	return {
		"ok": true, "reason": "",
		"cost_gold": next_config.unlock_gold_cost,
		"cost_runes": next_config.unlock_rune_count,
	}


## Advance a character to the next tier. The grid only grows — no items are displaced.
## purchased_cells is NOT reset — it accumulates across tiers.
## Caller must deduct gold and runes BEFORE calling this.
## After this call, grid_inventory.grid_template is already updated.
static func unlock_next_tier(
	character: CharacterData,
	state: Dictionary,
	grid_inventory: GridInventory
) -> Array:
	state["tier"] = state.get("tier", 0) + 1
	# purchased_cells stays as is — cumulative across tiers.
	var new_tpl: GridTemplate = build_grid_template(character, state)
	grid_inventory.grid_template = new_tpl
	# Grid only grows — no items are ever displaced.
	return []
