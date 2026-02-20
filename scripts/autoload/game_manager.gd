extends Node
## Global game state: party, gold, story flags.
## Persists across scene changes.

var party: Party
var gold: int = 0
var story_flags: Dictionary = {}
var is_game_started: bool = false

func _ready():
	DebugLogger.log_info("GameManager ready", "GameManager")

func new_game():
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
			DebugLogger.log_warning("Starter character not found: %s" % char_id, "GameManager")

	# Give starter items to stash (by ID from ItemDatabase)
	var starter_items: Array = [
		"sword_common",
		"shield_common",
		"staff_common",
		"dagger_common",
		"potion_common",
		"potion_common",
		"potion_common",
		"fire_gem_common",
	]
	for item_id: String in starter_items:
		var item: ItemData = ItemDatabase.get_item(item_id)
		if item:
			party.add_to_stash(item)
		else:
			DebugLogger.log_warning("Starter item not found: %s" % item_id, "GameManager")

	EventBus.gold_changed.emit(gold)
	SaveManager._playtime_accumulator = 0.0
	SaveManager.start_playtime_tracking()
	DebugLogger.log_info("New game started — Gold: %d, Roster: %d, Stash: %d" % [gold, party.roster.size(), party.get_stash_size()], "GameManager")

func add_gold(amount: int):
	gold += amount
	EventBus.gold_changed.emit(gold)

func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	EventBus.gold_changed.emit(gold)
	return true

func set_flag(flag: String, value: Variant = true):
	story_flags[flag] = value

func get_flag(flag: String, default: Variant = false) -> Variant:
	return story_flags.get(flag, default)

func has_flag(flag: String) -> bool:
	return story_flags.has(flag)
