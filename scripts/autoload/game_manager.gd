extends Node
## Global game state: party, gold, story flags.
## Persists across scene changes.

var party: Party
var gold: int = 0
var story_flags: Dictionary = {}
var is_game_started: bool = false

func _ready() -> void:
	DebugLogger.log_info("GameManager ready", "GameManager")

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
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(character.id)
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
