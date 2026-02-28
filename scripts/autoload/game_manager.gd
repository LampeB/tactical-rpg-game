extends Node
## Global game state: party, gold, story flags.
## Persists across scene changes.

var party: Party
var gold: int = 0
var story_flags: Dictionary = {}
var is_game_started: bool = false
var current_location_name: String = "Overworld"

func _ready() -> void:
	EventBus.item_database_reloaded.connect(_on_item_database_reloaded)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	DebugLogger.log_info("GameManager ready", "GameManager")


func _on_inventory_changed(character_id: String) -> void:
	## Re-clamp vitals when equipment changes so current HP/MP never exceeds new max.
	## If the character was at full HP before the change, top them up to the new max.
	if not party or not party.character_vitals.has(character_id):
		return
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var old_hp: int = party.get_current_hp(character_id)
	var old_mp: int = party.get_current_mp(character_id)
	var new_max_hp: int = party.get_max_hp(character_id, tree)
	var new_max_mp: int = party.get_max_mp(character_id, tree)
	# Clamp down (removed equipment) or keep current
	party.character_vitals[character_id]["current_hp"] = clampi(old_hp, 0, new_max_hp)
	party.character_vitals[character_id]["current_mp"] = clampi(old_mp, 0, new_max_mp)

func new_game() -> void:
	party = Party.new()
	gold = Constants.STARTING_GOLD
	story_flags.clear()
	is_game_started = true

	# Add starter characters
	var starter_characters: Array = ["warrior", "mage", "rogue"]
	for char_id: String in starter_characters:
		var character: CharacterData = CharacterDatabase.get_character(char_id)
		if character:
			party.add_to_roster(character)
			# Initialize vitals (HP/MP) to full
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
			party.initialize_vitals(character.id, tree)
			DebugLogger.log_info("Added starter character: %s (HP: %d/%d, MP: %d/%d)" % [
				character.display_name,
				party.get_current_hp(character.id),
				party.get_max_hp(character.id, tree),
				party.get_current_mp(character.id),
				party.get_max_mp(character.id, tree)
			], "GameManager")
		else:
			DebugLogger.log_warn("Starter character not found: %s" % char_id, "GameManager")

	# Give starter items to stash (by ID from ItemDatabase)
	var starter_items: Array = [
		# Weapons - various shapes for testing
		"sword_common",       # 1x2 shape
		"sword_lshaped",      # L-shape
		"dagger_common",      # 1x1 shape
		"dagger_lshaped",     # L-shape
		"mace_common",        # 2x2 shape
		"staff_common",       # 1x3 shape (2-handed)
		"staff_long",         # 1x4 shape (2-handed)
		"shield_common",      # 1x2 shape (1 hand)
		"bow_common",         # Bow zigzag shape (2-handed)
		"axe_common",         # Axe T-shape (2-handed)

		# Additional weapons for testing hand slots
		"sword_common",
		"dagger_common",

		# Armor - test equipment slots
		"helmet_common",      # 1x1 shape (helmet slot)
		"chestplate_common",  # 2x2 shape (chestplate slot)
		"gloves_common",      # 1x2 shape (gloves slot)
		"legs_common",        # 1x3 shape (legs slot)
		"boots_common",       # 1x2 shape (boots slot)
		"skeleton_arm",       # 1x3 shape (gloves slot, +1 hand slot!)

		# Elemental gems - add elemental damage
		"fire_gem_common",
		"ice_gem_common",
		"thunder_gem_common",

		# Modifier gems - stat bonuses and effects
		"precision_gem_common",   # +5% crit rate, +10% crit dmg
		"devastation_gem_common", # +25% crit dmg (specialized)
		"power_gem_common",       # +15% physical attack
		"mystic_gem_common",      # +15% magical attack
		"poison_gem_common",      # Poison damage [Future: DoT]
		"swift_gem_common",       # +5 speed [Future: Double attack]
		"vampiric_gem_common",    # Damage boost [Future: Life steal]
		"megummy_gem",            # +8 mag atk, AOE [Melee: -10 HP penalty!]
		"ripple_gem_common",      # Chain to 1 enemy (20% dmg) [Combo: MeGummy]
		"ripple_gem_uncommon",    # Chain to 1 enemy (40% dmg) [Combo: MeGummy]

		# Consumables
		"potion_common",
		"potion_common",
		"potion_common",
		"potion_common",
	]
	for item_id: String in starter_items:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item:
			party.add_to_stash(item)
		else:
			DebugLogger.log_warn("Starter item not found: %s" % item_id, "GameManager")

	EventBus.gold_changed.emit(gold)
	SaveManager._playtime_accumulator = 0.0
	SaveManager.start_playtime_tracking()
	DebugLogger.log_info("New game started — Gold: %d, Roster: %d, Stash: %d" % [gold, party.roster.size(), party.get_stash_size()], "GameManager")

## Restore game state from a save. Called by SaveManager during deserialization.
## Keeps all direct property writes in one place instead of scattered in SaveManager.
func restore_game_state(new_party: Party, new_gold: int, new_flags: Dictionary, location: String) -> void:
	party = new_party
	gold = new_gold
	story_flags = new_flags
	current_location_name = location
	is_game_started = true
	EventBus.gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	gold += amount
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true

func set_flag(flag: String, value: Variant = true) -> void:
	story_flags[flag] = value

func get_flag(flag: String, default: Variant = false) -> Variant:
	return story_flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return story_flags.has(flag)


func is_quest_done(quest_id: String) -> bool:
	return get_flag("quest_%s_completed" % quest_id, false)


func is_quest_active(quest_id: String) -> bool:
	return get_flag("quest_%s_accepted" % quest_id, false) and not is_quest_done(quest_id)

## Purchase a specific backpack cell chosen by the player for a given character.
## Called directly from the inventory UI when the player clicks a grayed-out cell.
## Returns true if the purchase succeeded.
func buy_backpack_cell(character_id: String, cell: Vector2i) -> bool:
	if not party:
		return false
	var character: CharacterData = party.roster.get(character_id)
	if not character or character.backpack_tiers.is_empty():
		return false
	var state := party.get_or_init_backpack_state(character)
	var cost := BackpackUpgradeSystem.expand(character, state, cell, gold)
	if cost < 0:
		return false
	spend_gold(cost)
	var tpl := BackpackUpgradeSystem.build_grid_template(character, state)
	party.grid_inventories[character_id].grid_template = tpl
	EventBus.backpack_expanded.emit(character_id, state.get("purchased_cells", []).size())
	EventBus.inventory_expanded.emit()
	return true


## Returns true if at least one character has purchasable cells and enough gold.
func can_expand_any() -> bool:
	for character in party.get_full_roster():
		var state := party.get_or_init_backpack_state(character)
		var cost := BackpackUpgradeSystem.get_next_cell_cost(character, state)
		if cost > 0 and gold >= cost:
			return true
	return false


## Unlock the next backpack tier for all characters simultaneously.
## Costs gold + Spatial Runes drawn from the party pool. Called by the Weaver NPC.
## Returns true if the unlock succeeded.
func unlock_next_tier_via_weaver() -> bool:
	var characters: Array = party.get_full_roster()
	if characters.is_empty():
		return false

	# Use the first character as the cost reference (all share the same tier).
	var first_char: CharacterData = characters[0]
	var first_state := party.get_or_init_backpack_state(first_char)
	var total_runes := party.count_runes()
	var check := BackpackUpgradeSystem.can_unlock_next_tier(first_char, first_state, gold, total_runes)

	if not check.ok:
		DebugLogger.log_warn("Cannot unlock backpack tier: %s" % check.reason, "GameManager")
		return false

	# Deduct resources (one payment for the whole party).
	spend_gold(check.cost_gold)
	party.consume_runes(check.cost_runes)

	# Unlock for every character; displaced items go to stash.
	for character in characters:
		var state := party.get_or_init_backpack_state(character)
		var displaced: Array = BackpackUpgradeSystem.unlock_next_tier(
			character, state, party.grid_inventories[character.id])
		for item in displaced:
			party.add_to_stash(item)
		EventBus.backpack_tier_unlocked.emit(character.id, state.get("tier", 0))

	EventBus.inventory_expanded.emit()
	return true


## Called when ItemDatabase reloads — refresh all live item references held by the party.
func _on_item_database_reloaded() -> void:
	if not is_game_started or not party:
		return

	# Refresh stash items
	for i in range(party.stash.size()):
		var old_item: ItemData = party.stash[i]
		var fresh: ItemData = ItemDatabase.get_item(old_item.id)
		if fresh:
			if old_item.rarity == fresh.rarity:
				party.stash[i] = fresh
			else:
				old_item.shape = fresh.shape

	# Refresh grid inventory items — rebuild cell maps with updated references
	var displaced_items: Array = []
	var char_ids: Array = party.grid_inventories.keys()
	for ci in range(char_ids.size()):
		var char_id: String = char_ids[ci]
		var grid: GridInventory = party.grid_inventories[char_id]
		var placements: Array = []
		for pi in range(grid.placed_items.size()):
			var placed: GridInventory.PlacedItem = grid.placed_items[pi]
			placements.append({
				"id": placed.item_data.id,
				"rarity": placed.item_data.rarity,
				"pos": placed.grid_position,
				"rot": placed.rotation,
				"old_item": placed.item_data,
			})
		grid.clear()
		for pi in range(placements.size()):
			var entry: Dictionary = placements[pi]
			var fresh: ItemData = ItemDatabase.get_item(entry.id)
			var item_to_place: ItemData
			if fresh and entry.rarity == fresh.rarity:
				item_to_place = fresh
			elif fresh:
				entry.old_item.shape = fresh.shape
				item_to_place = entry.old_item
			else:
				item_to_place = entry.old_item
			if not item_to_place.shape or item_to_place.shape.cells.is_empty():
				DebugLogger.log_warn("Item %s has no shape — moved to stash" % item_to_place.id, "GameManager")
				displaced_items.append(item_to_place)
				continue
			var placed: GridInventory.PlacedItem = grid.place_item(item_to_place, entry.pos, entry.rot)
			if not placed:
				DebugLogger.log_warn("Item %s no longer fits at (%d,%d) on %s — moved to stash" % [
					item_to_place.id, entry.pos.x, entry.pos.y, char_id
				], "GameManager")
				displaced_items.append(item_to_place)

	for item in displaced_items:
		party.stash.append(item)
	if not displaced_items.is_empty():
		DebugLogger.log_info("Moved %d displaced items to stash after reload" % displaced_items.size(), "GameManager")
		EventBus.stash_changed.emit()


## Returns true if the next tier can be unlocked (enough gold + runes in party pool).
func can_unlock_tier_any() -> bool:
	var characters: Array = party.get_full_roster()
	if characters.is_empty():
		return false
	var first_char: CharacterData = characters[0]
	var first_state := party.get_or_init_backpack_state(first_char)
	var total_runes := party.count_runes()
	var check := BackpackUpgradeSystem.can_unlock_next_tier(first_char, first_state, gold, total_runes)
	return check.ok
