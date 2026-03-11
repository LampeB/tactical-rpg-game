extends Node
## Autoload that loads and indexes all CharacterData resources at startup.
## Access characters by ID: CharacterDatabase.get_character("warrior")

var _characters: Dictionary = {}  # id -> CharacterData

const CHARACTER_DIR := "res://data/characters/"

func _ready() -> void:
	_characters = ResourceLoaderHelper.load_dir(CHARACTER_DIR, "CharacterDatabase")
	DebugLogger.log_info("Loaded %d characters" % _characters.size(), "CharacterDatabase")

func get_character(id: String) -> CharacterData:
	if _characters.has(id):
		return _characters[id]
	DebugLogger.log_warn("Character not found: %s" % id, "CharacterDatabase")
	return null

func get_all_characters() -> Array:
	return _characters.values()

func has_character(id: String) -> bool:
	return _characters.has(id)
