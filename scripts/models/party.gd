class_name Party
extends RefCounted
## Runtime party state: roster of characters, active squad, shared item stash.

signal squad_changed()
signal roster_changed()
signal stash_changed()
signal passives_changed(character_id: String)
signal vitals_changed(character_id: String)

## All recruited characters (by id -> CharacterData).
var roster: Dictionary = {}

## Active squad member IDs (up to MAX_SQUAD_SIZE).
var squad: Array[String] = []

## Shared item stash (items not equipped on any character).
var stash: Array = [] ## of ItemData

## Persistent grid inventories (character_id -> GridInventory).
var grid_inventories: Dictionary = {}

## Unlocked passive skill tree nodes (character_id -> Array[String] of node IDs).
var unlocked_passives: Dictionary = {}

## Runtime HP/MP state per character (character_id -> {"current_hp": int, "current_mp": int}).
var character_vitals: Dictionary = {}

## Backpack upgrade state per character.
## Key: character_id -> { "tier": int, "purchased_cells": Array }
## purchased_cells holds every Vector2i cell the player individually unlocked.
var backpack_states: Dictionary = {}

func add_to_roster(character: CharacterData) -> bool:
	if roster.size() >= Constants.MAX_ROSTER_SIZE:
		return false
	if roster.has(character.id):
		return false
	roster[character.id] = character
	# Create persistent grid inventory with tier-aware template.
	if not grid_inventories.has(character.id):
		var bp_state := get_or_init_backpack_state(character)
		if not character.backpack_tiers.is_empty():
			var tpl := BackpackUpgradeSystem.build_grid_template(character, bp_state)
			grid_inventories[character.id] = GridInventory.new(tpl)
		elif character.grid_template:
			grid_inventories[character.id] = GridInventory.new(character.grid_template)
	roster_changed.emit()
	# Auto-add to squad if there's room
	if squad.size() < Constants.MAX_SQUAD_SIZE:
		squad.append(character.id)
		squad_changed.emit()
	return true

func remove_from_roster(character_id: String) -> void:
	roster.erase(character_id)
	squad.erase(character_id)
	grid_inventories.erase(character_id)
	character_vitals.erase(character_id)
	backpack_states.erase(character_id)
	roster_changed.emit()
	squad_changed.emit()


## Returns all characters in the roster as an Array of CharacterData.
func get_full_roster() -> Array:
	return roster.values()


## Returns (or initialises) the backpack state dict for a character.
## State format: { "tier": int, "purchased_cells": Array }
## Bootstraps from T1 config (no purchased cells = just the initial block).
## Falls back to grid_template dimensions if backpack_tiers is not configured.
func get_or_init_backpack_state(character: CharacterData) -> Dictionary:
	if backpack_states.has(character.id):
		var state: Dictionary = backpack_states[character.id]
		# Migrate old "unlocked_cells" saves: discard count, start fresh on this tier.
		if not state.has("purchased_cells"):
			state["purchased_cells"] = []
		return state

	var state: Dictionary = {"tier": 0, "purchased_cells": []}
	backpack_states[character.id] = state
	return state

func set_squad(member_ids: Array[String]) -> void:
	squad = member_ids.slice(0, Constants.MAX_SQUAD_SIZE)
	squad_changed.emit()

func get_squad_members() -> Array:
	var members: Array = []
	for id in squad:
		if roster.has(id):
			members.append(roster[id])
	return members

func add_to_stash(item: ItemData) -> bool:
	if stash.size() >= Constants.MAX_STASH_SLOTS:
		return false
	stash.append(item)
	stash_changed.emit()
	return true

func remove_from_stash(item: ItemData) -> void:
	var idx := stash.find(item)
	if idx >= 0:
		stash.remove_at(idx)
		stash_changed.emit()

func get_stash_size() -> int:
	return stash.size()


# === Passive Skill Tree ===

func unlock_passive(character_id: String, node_id: String) -> void:
	if not unlocked_passives.has(character_id):
		unlocked_passives[character_id] = []
	var nodes: Array = unlocked_passives[character_id]
	if not nodes.has(node_id):
		nodes.append(node_id)
		passives_changed.emit(character_id)


func is_passive_unlocked(character_id: String, node_id: String) -> bool:
	if not unlocked_passives.has(character_id):
		return false
	return unlocked_passives[character_id].has(node_id)


func get_unlocked_passives(character_id: String) -> Array:
	if not unlocked_passives.has(character_id):
		return []
	return unlocked_passives[character_id]


## Compute passive bonuses for a character. Requires a PassiveTreeData
## (caller must look it up since Party can't reference autoloads).
func get_passive_bonuses(character_id: String, tree: PassiveTreeData) -> Dictionary:
	var stat_mods: Array = []
	var effects: Array = []
	if not tree:
		return {"stat_modifiers": stat_mods, "special_effects": effects}
	var unlocked: Array = get_unlocked_passives(character_id)
	for i in range(tree.nodes.size()):
		var node: PassiveNodeData = tree.nodes[i]
		if node and unlocked.has(node.id):
			stat_mods.append_array(node.stat_modifiers)
			if not node.special_effect_id.is_empty():
				effects.append(node.special_effect_id)
	return {"stat_modifiers": stat_mods, "special_effects": effects}


# === Character Vitals (HP/MP) ===

## Initialize vitals for a character (sets current HP/MP to max).
## Called when character joins roster or on new game.
## Requires PassiveTreeData (caller must look it up since Party can't reference autoloads).
func initialize_vitals(character_id: String, tree: PassiveTreeData = null) -> void:
	if not roster.has(character_id):
		return
	var max_hp: int = get_max_hp(character_id, tree)
	var max_mp: int = get_max_mp(character_id, tree)
	character_vitals[character_id] = {
		"current_hp": max_hp,
		"current_mp": max_mp
	}


## Get current HP for a character (returns max if not initialized).
func get_current_hp(character_id: String) -> int:
	if not character_vitals.has(character_id):
		return 0
	return character_vitals[character_id].get("current_hp", 0)


## Get current MP for a character (returns max if not initialized).
func get_current_mp(character_id: String) -> int:
	if not character_vitals.has(character_id):
		return 0
	return character_vitals[character_id].get("current_mp", 0)


## Set current HP (clamped to 0-max).
## Requires PassiveTreeData for max HP calculation.
func set_current_hp(character_id: String, value: int, tree: PassiveTreeData = null) -> void:
	if not character_vitals.has(character_id):
		initialize_vitals(character_id, tree)
	var max_hp: int = get_max_hp(character_id, tree)
	character_vitals[character_id]["current_hp"] = clampi(value, 0, max_hp)
	vitals_changed.emit(character_id)


## Set current MP (clamped to 0-max).
## Requires PassiveTreeData for max MP calculation.
func set_current_mp(character_id: String, value: int, tree: PassiveTreeData = null) -> void:
	if not character_vitals.has(character_id):
		initialize_vitals(character_id, tree)
	var max_mp: int = get_max_mp(character_id, tree)
	character_vitals[character_id]["current_mp"] = clampi(value, 0, max_mp)
	vitals_changed.emit(character_id)


## Heal a character (add HP and/or MP, clamped to max).
## Requires PassiveTreeData for max HP/MP calculation.
func heal_character(character_id: String, hp_amount: int, mp_amount: int, tree: PassiveTreeData = null) -> void:
	if not character_vitals.has(character_id):
		initialize_vitals(character_id, tree)

	var current_hp: int = get_current_hp(character_id)
	var current_mp: int = get_current_mp(character_id)

	set_current_hp(character_id, current_hp + hp_amount, tree)
	set_current_mp(character_id, current_mp + mp_amount, tree)


## Get computed max HP (base + equipment + passives).
## Requires PassiveTreeData (caller must look it up since Party can't reference autoloads).
func get_max_hp(character_id: String, tree: PassiveTreeData = null) -> int:
	if not roster.has(character_id):
		return 0

	var char_data: CharacterData = roster[character_id]
	var inv: GridInventory = grid_inventories.get(character_id)

	# Base HP from character
	var hp_flat: float = float(char_data.max_hp)
	var hp_pct: float = 0.0

	# Equipment bonuses
	if inv:
		var equip_stats: Dictionary = inv.get_computed_stats()
		hp_flat += equip_stats.get(Enums.Stat.MAX_HP, 0.0)

	# Passive bonuses
	if tree:
		var passive_bonuses: Dictionary = get_passive_bonuses(character_id, tree)
		var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])
		for i in range(passive_mods.size()):
			var mod: StatModifier = passive_mods[i]
			if mod.stat == Enums.Stat.MAX_HP:
				if mod.modifier_type == Enums.ModifierType.FLAT:
					hp_flat += mod.value
				else:
					hp_pct += mod.value

	return int(hp_flat * (1.0 + hp_pct / 100.0))


## Returns display names for the current squad members.
func get_squad_display_names() -> Array[String]:
	var names: Array[String] = []
	for char_id: String in squad:
		var char_data: CharacterData = roster.get(char_id)
		if char_data:
			names.append(char_data.display_name)
	return names


## Count all Spatial Runes available in the entire party (all inventories + stash).
func count_runes() -> int:
	var count := 0
	for char_id: String in grid_inventories:
		var inv: GridInventory = grid_inventories[char_id]
		for placed in inv.placed_items:
			if placed.item_data.id == Constants.SPATIAL_RUNE_ITEM_ID:
				count += 1
	for item in stash:
		if item.id == Constants.SPATIAL_RUNE_ITEM_ID:
			count += 1
	return count


## Consume `count` Spatial Runes from the party pool (inventories first, then stash).
## Returns false (and consumes nothing) if fewer than `count` runes are available.
func consume_runes(count: int) -> bool:
	if count_runes() < count:
		return false

	var remaining := count

	for char_id: String in grid_inventories:
		if remaining <= 0:
			break
		var inv: GridInventory = grid_inventories[char_id]
		var to_remove: Array = []
		for placed in inv.placed_items:
			if remaining <= 0:
				break
			if placed.item_data.id == Constants.SPATIAL_RUNE_ITEM_ID:
				to_remove.append(placed)
				remaining -= 1
		for placed in to_remove:
			inv.remove_item(placed)

	var i := stash.size() - 1
	while i >= 0 and remaining > 0:
		if stash[i].id == Constants.SPATIAL_RUNE_ITEM_ID:
			stash.remove_at(i)
			remaining -= 1
		i -= 1

	return true


## Get computed max MP (base + equipment + passives).
## Requires PassiveTreeData (caller must look it up since Party can't reference autoloads).
func get_max_mp(character_id: String, tree: PassiveTreeData = null) -> int:
	if not roster.has(character_id):
		return 0

	var char_data: CharacterData = roster[character_id]
	var inv: GridInventory = grid_inventories.get(character_id)

	# Base MP from character
	var mp_flat: float = float(char_data.max_mp)
	var mp_pct: float = 0.0

	# Equipment bonuses
	if inv:
		var equip_stats: Dictionary = inv.get_computed_stats()
		mp_flat += equip_stats.get(Enums.Stat.MAX_MP, 0.0)

	# Passive bonuses
	if tree:
		var passive_bonuses: Dictionary = get_passive_bonuses(character_id, tree)
		var passive_mods: Array = passive_bonuses.get("stat_modifiers", [])
		for i in range(passive_mods.size()):
			var mod: StatModifier = passive_mods[i]
			if mod.stat == Enums.Stat.MAX_MP:
				if mod.modifier_type == Enums.ModifierType.FLAT:
					mp_flat += mod.value
				else:
					mp_pct += mod.value

	return int(mp_flat * (1.0 + mp_pct / 100.0))
