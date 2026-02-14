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

	# Add starter character
	var warrior := load("res://data/characters/warrior.tres") as CharacterData
	if warrior:
		party.add_to_roster(warrior)
		DebugLogger.log_info("Added starter character: %s" % warrior.display_name, "GameManager")

	# Give starter items to stash
	var sword := load("res://data/items/weapons/sword_common.tres") as ItemData
	var shield := load("res://data/items/armor/shield_common.tres") as ItemData
	var potion := load("res://data/items/consumables/potion_common.tres") as ItemData
	var fire_gem := load("res://data/items/modifiers/fire_gem_common.tres") as ItemData
	if sword:
		party.add_to_stash(sword)
	if shield:
		party.add_to_stash(shield)
	if potion:
		party.add_to_stash(potion)
		party.add_to_stash(potion) # Give 2 potions
	if fire_gem:
		party.add_to_stash(fire_gem)

	EventBus.gold_changed.emit(gold)
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
