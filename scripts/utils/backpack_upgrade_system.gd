class_name BackpackUpgradeSystem
extends RefCounted
## Stateless utility for backpack tier upgrades.
## Mirrors ItemUpgradeSystem — all methods are static, no scene tree dependency.
## The authoritative state lives in Party.backpack_states (persisted via SaveManager).
## State format: { "tier": int, "purchased_cells": Array }
## purchased_cells holds Vector2i values for every cell the player has individually bought.
## The cost of the next purchase is cell_costs[purchased_cells.size()], regardless of
## which specific cell the player chooses — so earlier purchases are always cheaper.

const GROWTH_ROWS := 0
const GROWTH_COLUMNS := 1


## Returns the ordered list of all cells for a tier config.
## Respects custom_cell_layout if set; otherwise generates row-by-row or column-by-column.
static func get_cell_layout(config: BackpackTierConfig) -> Array[Vector2i]:
	if not config.custom_cell_layout.is_empty():
		return config.custom_cell_layout.duplicate()
	var cells: Array[Vector2i] = []
	if config.growth_direction == GROWTH_COLUMNS:
		for x in range(config.bounding_width):
			for y in range(config.bounding_height):
				cells.append(Vector2i(x, y))
	else:  # GROWTH_ROWS (default)
		for y in range(config.bounding_height):
			for x in range(config.bounding_width):
				cells.append(Vector2i(x, y))
	return cells


## Build a GridTemplate reflecting the current backpack state.
## Active cells = initial cells (fixed) + cells individually purchased by the player.
## The full bounding box is always rendered; unpurchased cells appear grayed-out.
static func build_grid_template(character: CharacterData, state: Dictionary) -> GridTemplate:
	var tier_idx: int = state.get("tier", 0)
	var config: BackpackTierConfig = character.backpack_tiers[tier_idx]
	var layout: Array[Vector2i] = get_cell_layout(config)

	# Initial cells: the first initial_cell_count entries from the layout (always active).
	var active: Array[Vector2i] = []
	for i in range(mini(config.initial_cell_count, layout.size())):
		active.append(layout[i])

	# Player-purchased cells: added in whatever order the player chose them.
	var purchased: Array = state.get("purchased_cells", [])
	for cell in purchased:
		var v: Vector2i = cell if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
		if not active.has(v):
			active.append(v)

	var tpl := GridTemplate.new()
	tpl.id = "grid_%s_t%d" % [character.id, tier_idx + 1]
	tpl.display_name = config.display_name
	tpl.width = config.bounding_width
	tpl.height = config.bounding_height
	tpl.active_cells = active
	# layout_cells = the full shape (initial + purchasable). Empty = full rectangle (backward compat).
	tpl.layout_cells = layout.duplicate()
	return tpl


## Returns the gold cost of the NEXT cell purchase for this character, or -1 if at tier max.
static func get_next_cell_cost(character: CharacterData, state: Dictionary) -> int:
	var tier_idx: int = state.get("tier", 0)
	if tier_idx >= character.backpack_tiers.size():
		return -1
	var config: BackpackTierConfig = character.backpack_tiers[tier_idx]
	var purchased_count: int = state.get("purchased_cells", []).size()
	if purchased_count >= config.cell_costs.size():
		return -1
	return config.cell_costs[purchased_count]


## Returns all cells the player can still purchase in the current tier.
## A cell is purchasable only if it is orthogonally adjacent to at least one
## already-active cell (initial or previously purchased). This prevents skipping
## ahead and forces organic outward growth from the starting block.
static func get_purchasable_cells(character: CharacterData, state: Dictionary) -> Array[Vector2i]:
	var tier_idx: int = state.get("tier", 0)
	if tier_idx >= character.backpack_tiers.size():
		return []
	var config: BackpackTierConfig = character.backpack_tiers[tier_idx]
	var purchased: Array = state.get("purchased_cells", [])
	if purchased.size() >= config.cell_costs.size():
		return []  # All purchasable cells are already bought.

	var layout: Array[Vector2i] = get_cell_layout(config)

	# Build the full set of currently active cells for adjacency checks.
	var active: Array[Vector2i] = []
	for i in range(mini(config.initial_cell_count, layout.size())):
		active.append(layout[i])
	for p in purchased:
		var pv: Vector2i = p if p is Vector2i else Vector2i(int(p[0]), int(p[1]))
		if not active.has(pv):
			active.append(pv)

	var result: Array[Vector2i] = []
	for i in range(config.initial_cell_count, layout.size()):
		var cell: Vector2i = layout[i]
		# Skip already purchased cells.
		var already_bought := false
		for p in purchased:
			var pv: Vector2i = p if p is Vector2i else Vector2i(int(p[0]), int(p[1]))
			if pv == cell:
				already_bought = true
				break
		if already_bought:
			continue
		# Only offer cells touching the existing active region.
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
	var tier_idx: int = state.get("tier", 0)
	if tier_idx >= character.backpack_tiers.size():
		return {"ok": false, "reason": "Invalid tier.", "cost": 0}

	var config: BackpackTierConfig = character.backpack_tiers[tier_idx]
	var purchased: Array = state.get("purchased_cells", [])

	if purchased.size() >= config.cell_costs.size():
		return {"ok": false, "reason": "Already at maximum size for this tier.", "cost": 0}

	var purchasable: Array[Vector2i] = get_purchasable_cells(character, state)
	if not purchasable.has(cell):
		return {"ok": false, "reason": "Cell not available for purchase.", "cost": 0}

	var cost: int = config.cell_costs[purchased.size()]
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


## Advance a character to the next tier: resets purchased_cells to empty (fresh start),
## re-places existing items in the new grid, returns displaced items.
## Caller must deduct gold and runes BEFORE calling this.
## After this call, grid_inventory.grid_template is already updated.
static func unlock_next_tier(
	character: CharacterData,
	state: Dictionary,
	grid_inventory: GridInventory
) -> Array:
	var next_tier: int = state.get("tier", 0) + 1
	var next_config: BackpackTierConfig = character.backpack_tiers[next_tier]

	var snapshot: Array = []
	for placed in grid_inventory.placed_items:
		snapshot.append({"item": placed.item_data, "pos": placed.grid_position, "rot": placed.rotation})

	state["tier"] = next_tier
	state["purchased_cells"] = []  # Player starts fresh on the new tier.

	var new_tpl: GridTemplate = build_grid_template(character, state)
	grid_inventory.grid_template = new_tpl
	grid_inventory.clear()

	var displaced: Array = []
	for entry in snapshot:
		if not grid_inventory.place_item(entry.item, entry.pos, entry.rot):
			displaced.append(entry.item)

	return displaced


## Count all Spatial Runes available in the entire party (all inventories + stash).
static func count_party_runes(party: Party) -> int:
	var count := 0
	for char_id: String in party.grid_inventories:
		var inv: GridInventory = party.grid_inventories[char_id]
		for placed in inv.placed_items:
			if placed.item_data.id == Constants.SPATIAL_RUNE_ITEM_ID:
				count += 1
	for item in party.stash:
		if item.id == Constants.SPATIAL_RUNE_ITEM_ID:
			count += 1
	return count


## Consume `count` Spatial Runes from the party pool (inventories first, then stash).
## Returns false (and consumes nothing) if fewer than `count` runes are available.
static func consume_party_runes(party: Party, count: int) -> bool:
	if count_party_runes(party) < count:
		return false

	var remaining := count

	for char_id: String in party.grid_inventories:
		if remaining <= 0:
			break
		var inv: GridInventory = party.grid_inventories[char_id]
		var to_remove: Array = []
		for placed in inv.placed_items:
			if remaining <= 0:
				break
			if placed.item_data.id == Constants.SPATIAL_RUNE_ITEM_ID:
				to_remove.append(placed)
				remaining -= 1
		for placed in to_remove:
			inv.remove_item(placed)

	var i := party.stash.size() - 1
	while i >= 0 and remaining > 0:
		if party.stash[i].id == Constants.SPATIAL_RUNE_ITEM_ID:
			party.stash.remove_at(i)
			remaining -= 1
		i -= 1

	return true
