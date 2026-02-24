class_name GridInventory
extends RefCounted
## Manages item placement on a character's tetris-style inventory grid.
## Pure data — no UI dependencies.

var grid_template: GridTemplate
var placed_items: Array = []  ## of PlacedItem
var _cell_map: Dictionary = {}  ## Vector2i -> PlacedItem


func _init(template: GridTemplate) -> void:
	grid_template = template


# === Placement API ===

func can_place(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> bool:
	var cells: Array[Vector2i] = _get_world_cells(item_data.shape, grid_pos, rotation)
	if not _are_cells_valid(cells):
		return false

	# Check equipment slot restrictions
	if item_data.item_type == Enums.ItemType.ACTIVE_TOOL and item_data.hand_slots_required > 0:
		# Check if we have enough hand slots available
		var available_slots: int = get_available_hand_slots()
		var used_slots: int = get_used_hand_slots()
		if used_slots + item_data.hand_slots_required > available_slots:
			return false

	if item_data.item_type == Enums.ItemType.PASSIVE_GEAR:
		# Special handling for rings (max 10) and necklaces (max 1)
		if item_data.armor_slot == Enums.EquipmentCategory.RING:
			var ring_count := _count_equipped_by_slot(Enums.EquipmentCategory.RING)
			if ring_count >= 10:
				return false
		elif item_data.armor_slot == Enums.EquipmentCategory.NECKLACE:
			var necklace_count := _count_equipped_by_slot(Enums.EquipmentCategory.NECKLACE)
			if necklace_count >= 1:
				return false
		else:
			# Other armor slots: only one allowed
			var occupied_armor_slots: Dictionary = get_equipped_armor_slots()
			if occupied_armor_slots.has(item_data.armor_slot):
				return false

	return true


## Returns a human-readable reason why placement would fail, or "" if it can be placed.
func get_placement_failure_reason(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> String:
	var cells: Array[Vector2i] = _get_world_cells(item_data.shape, grid_pos, rotation)
	for cell in cells:
		if not grid_template.is_cell_active(cell):
			return "Out of bounds at (%d, %d)" % [cell.x, cell.y]
		if _cell_map.has(cell):
			var blocking: PlacedItem = _cell_map[cell]
			return "Blocked by %s at (%d, %d)" % [blocking.item_data.display_name, cell.x, cell.y]
	if item_data.item_type == Enums.ItemType.ACTIVE_TOOL and item_data.hand_slots_required > 0:
		var available_slots: int = get_available_hand_slots()
		var used_slots: int = get_used_hand_slots()
		if used_slots + item_data.hand_slots_required > available_slots:
			return "Need %d hand slots, only %d available" % [item_data.hand_slots_required, available_slots - used_slots]
	if item_data.item_type == Enums.ItemType.PASSIVE_GEAR:
		if item_data.armor_slot == Enums.EquipmentCategory.RING:
			if _count_equipped_by_slot(Enums.EquipmentCategory.RING) >= 10:
				return "Max rings equipped"
		elif item_data.armor_slot == Enums.EquipmentCategory.NECKLACE:
			if _count_equipped_by_slot(Enums.EquipmentCategory.NECKLACE) >= 1:
				return "Necklace slot occupied"
		else:
			if get_equipped_armor_slots().has(item_data.armor_slot):
				return "Armor slot already occupied"
	return ""


func place_item(item_data: ItemData, grid_pos: Vector2i, rotation: int) -> PlacedItem:
	if not can_place(item_data, grid_pos, rotation):
		return null
	var placed: PlacedItem = PlacedItem.new()
	placed.item_data = item_data
	placed.grid_position = grid_pos
	placed.rotation = rotation
	placed_items.append(placed)
	var occupied: Array[Vector2i] = placed.get_occupied_cells()
	for cell in occupied:
		_cell_map[cell] = placed
	return placed


func remove_item(placed: PlacedItem) -> void:
	var occupied: Array[Vector2i] = placed.get_occupied_cells()
	for cell in occupied:
		_cell_map.erase(cell)
	placed_items.erase(placed)


func get_item_at(cell: Vector2i) -> PlacedItem:
	return _cell_map.get(cell, null)


func get_all_placed_items() -> Array:
	return placed_items


func clear() -> void:
	placed_items.clear()
	_cell_map.clear()


# === Equipment Slot Tracking ===

## Returns the total number of hand slots available (base 2 + bonuses from equipped items).
func get_available_hand_slots() -> int:
	var base_slots: int = 2
	var bonus_slots: int = 0

	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		bonus_slots += placed.item_data.bonus_hand_slots

	return base_slots + bonus_slots


## Returns the number of hand slots currently used by equipped weapons.
func get_used_hand_slots() -> int:
	var used: int = 0

	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			used += placed.item_data.hand_slots_required

	return used


## Returns Dictionary mapping EquipmentCategory -> PlacedItem for all equipped armor pieces.
func get_equipped_armor_slots() -> Dictionary:
	var slots: Dictionary = {}

	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR:
			var armor_slot: Enums.EquipmentCategory = placed.item_data.armor_slot
			slots[armor_slot] = placed

	return slots


# === Modifier System ===

## Returns all MODIFIER PlacedItems whose cells are within reach of the target ACTIVE_TOOL.
func get_modifiers_affecting(target: PlacedItem) -> Array:
	var result: Array = []
	if target.item_data.item_type != Enums.ItemType.ACTIVE_TOOL:
		return result
	var target_cells: Array[Vector2i] = target.get_occupied_cells()
	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type != Enums.ItemType.MODIFIER:
			continue
		var in_reach: bool = _items_within_reach(placed, target_cells, placed.item_data.modifier_reach)
		if in_reach:
			result.append(placed)
	return result


## Returns all ACTIVE_TOOL PlacedItems affected by a given MODIFIER.
func get_tools_affected_by(modifier_placed: PlacedItem) -> Array:
	var result: Array = []
	if modifier_placed.item_data.item_type != Enums.ItemType.MODIFIER:
		return result
	var reach: int = modifier_placed.item_data.modifier_reach
	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type != Enums.ItemType.ACTIVE_TOOL:
			continue
		var tool_cells: Array[Vector2i] = placed.get_occupied_cells()
		if _items_within_reach(modifier_placed, tool_cells, reach):
			result.append(placed)
	return result


## Returns aggregated conditional modifier effects for a specific ACTIVE_TOOL.
func get_tool_modifier_state(tool_placed: PlacedItem) -> ToolModifierState:
	var state := ToolModifierState.new()
	state.tool_placed_item = tool_placed

	var weapon_type: Enums.WeaponType = tool_placed.item_data.get_weapon_type()

	var modifiers: Array = get_modifiers_affecting(tool_placed)
	for i in range(modifiers.size()):
		var modifier_placed: PlacedItem = modifiers[i]
		var gem: ItemData = modifier_placed.item_data

		# Check conditional rules
		for j in range(gem.conditional_modifier_rules.size()):
			var rule: ConditionalModifierRule = gem.conditional_modifier_rules[j]
			# Match by weapon type
			if rule.target_weapon_type == weapon_type:
				# Match! Apply this rule's effects
				state.active_modifiers.append({"gem": modifier_placed, "rule": rule})

				# Aggregate stat bonuses (stacking)
				for k in range(rule.stat_bonuses.size()):
					var stat_mod: StatModifier = rule.stat_bonuses[k]
					var stat: Enums.Stat = stat_mod.stat
					var existing: float = state.aggregate_stats.get(stat, 0.0)
					state.aggregate_stats[stat] = existing + stat_mod.value

				# Status effect (first wins)
				if rule.status_effect and state.status_effect_type == null:
					state.status_effect_type = rule.status_effect.effect_type
					state.status_effect_chance = rule.status_effect_chance

				# Conditional skills (no duplicates)
				for k in range(rule.granted_skills.size()):
					var skill: SkillData = rule.granted_skills[k]
					if skill not in state.conditional_skills:
						state.conditional_skills.append(skill)

				# AoE flag (any rule with force_aoe enables it)
				if rule.force_aoe:
					state.force_aoe = true

				# HP cost per attack (stacking)
				if rule.hp_cost_per_attack > 0:
					state.hp_cost_per_attack += rule.hp_cost_per_attack

	return state


## Returns Dictionary: PlacedItem -> ToolModifierState for all ACTIVE_TOOLs.
func get_all_tool_modifier_states() -> Dictionary:
	var states := {}
	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
			states[placed] = get_tool_modifier_state(placed)
	return states


## Computes aggregate stat bonuses from all placed items + modifier interactions.
func get_computed_stats() -> Dictionary:
	var flat_bonuses: Dictionary = {}  ## Enums.Stat -> float
	var pct_bonuses: Dictionary = {}   ## Enums.Stat -> float

	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		var item: ItemData = placed.item_data
		# Direct stat modifiers from the item itself
		for mod in item.stat_modifiers:
			if mod is StatModifier:
				_accumulate_modifier(mod, flat_bonuses, pct_bonuses)

		# Modifier bonuses from adjacent gems (only for ACTIVE_TOOLs)
		if item.item_type == Enums.ItemType.ACTIVE_TOOL:
			var modifiers: Array = get_modifiers_affecting(placed)
			for j in range(modifiers.size()):
				var gem_placed: PlacedItem = modifiers[j]
				for gem_mod in gem_placed.item_data.modifier_bonuses:
					if gem_mod is StatModifier:
						_accumulate_modifier(gem_mod, flat_bonuses, pct_bonuses)

	# Combine: final = flat * (1 + pct)
	var stats: Dictionary = {}
	var all_stats: Array = []
	all_stats.append_array(flat_bonuses.keys())
	for k in pct_bonuses.keys():
		if k not in all_stats:
			all_stats.append(k)
	for stat in all_stats:
		var flat_val: float = flat_bonuses.get(stat, 0.0)
		var pct_val: float = pct_bonuses.get(stat, 0.0)
		stats[stat] = flat_val * (1.0 + pct_val / 100.0)

	# Add per-tool modifier states and fold conditional gem stats into totals
	var tool_states: Dictionary = get_all_tool_modifier_states()
	for placed_key in tool_states:
		var state: ToolModifierState = tool_states[placed_key]
		for stat in state.aggregate_stats:
			var val: float = state.aggregate_stats[stat]
			flat_bonuses[stat] = flat_bonuses.get(stat, 0.0) + val
			# Recompute this stat's final value
			var pct_val: float = pct_bonuses.get(stat, 0.0)
			stats[stat] = flat_bonuses.get(stat, 0.0) * (1.0 + pct_val / 100.0)

	return {
		"stats": stats,
		"tool_states": tool_states
	}


# === Internal Helpers ===

func _get_world_cells(shape: ItemShape, grid_pos: Vector2i, rotation: int) -> Array[Vector2i]:
	var rotated: Array[Vector2i] = shape.get_rotated_cells(rotation)
	var result: Array[Vector2i] = []
	for cell in rotated:
		result.append(grid_pos + cell)
	return result


func _are_cells_valid(cells: Array[Vector2i]) -> bool:
	for cell in cells:
		if not grid_template.is_cell_active(cell):
			return false
		if _cell_map.has(cell):
			return false
	return true


func _count_equipped_by_slot(slot_type: Enums.EquipmentCategory) -> int:
	var count := 0
	for i in range(placed_items.size()):
		var placed: PlacedItem = placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR and placed.item_data.armor_slot == slot_type:
			count += 1
	return count


func _items_within_reach(modifier_placed: PlacedItem, target_cells: Array[Vector2i], _reach: int) -> bool:
	var mod_cells: Array[Vector2i] = modifier_placed.get_occupied_cells()
	var reach_pattern: Array[Vector2i] = modifier_placed.item_data.get_reach_cells(modifier_placed.rotation)
	for mc in mod_cells:
		for offset in reach_pattern:
			var affected: Vector2i = mc + offset
			if target_cells.has(affected):
				return true
	return false


func _accumulate_modifier(mod: StatModifier, flat: Dictionary, pct: Dictionary) -> void:
	if mod.modifier_type == Enums.ModifierType.FLAT:
		flat[mod.stat] = flat.get(mod.stat, 0.0) + mod.value
	else:
		pct[mod.stat] = pct.get(mod.stat, 0.0) + mod.value


# === Inner Class ===

class PlacedItem:
	var item_data: ItemData
	var grid_position: Vector2i
	var rotation: int = 0

	func get_occupied_cells() -> Array[Vector2i]:
		var shape_cells: Array[Vector2i] = item_data.shape.get_rotated_cells(rotation)
		var result: Array[Vector2i] = []
		for cell in shape_cells:
			result.append(grid_position + cell)
		return result
