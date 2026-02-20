extends Node
## Autoload that loads and indexes all CharacterData resources at startup.
## Access characters by ID: CharacterDatabase.get_character("warrior")

var _characters: Dictionary = {}  # id -> CharacterData

const CHARACTER_DIR := "res://data/characters/"

func _ready():
	_load_all_characters()
	DebugLogger.log_info("Loaded %d characters" % _characters.size(), "CharacterDatabase")

func _load_all_characters():
	var dir := DirAccess.open(CHARACTER_DIR)
	if not dir:
		DebugLogger.log_warn("Character directory not found: %s" % CHARACTER_DIR, "CharacterDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := CHARACTER_DIR + file_name
			var character := load(full_path) as CharacterData
			if character:
				if character.id.is_empty():
					character.id = file_name.get_basename()
				_register_character(character)
			else:
				DebugLogger.log_warn("Failed to load character: %s" % full_path, "CharacterDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_character(character: CharacterData):
	if _characters.has(character.id):
		DebugLogger.log_warn("Duplicate character ID: %s" % character.id, "CharacterDatabase")
	_characters[character.id] = character

func get_character(id: String) -> CharacterData:
	if _characters.has(id):
		return _characters[id]
	DebugLogger.log_warn("Character not found: %s" % id, "CharacterDatabase")
	return null

func get_all_characters() -> Array:
	return _characters.values()

func has_character(id: String) -> bool:
	return _characters.has(id)
