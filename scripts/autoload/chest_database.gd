extends Node
## Autoload that loads and indexes all ChestData resources at startup.
## Access chests by ID: ChestDatabase.get_chest("dungeon_chest_01")

var _chests: Dictionary = {}  # id -> ChestData

const CHEST_DIR := "res://data/chests/"


func _ready() -> void:
	_load_all_chests()
	DebugLogger.log_info("Loaded %d chests" % _chests.size(), "ChestDatabase")


func _load_all_chests() -> void:
	var dir := DirAccess.open(CHEST_DIR)
	if not dir:
		DebugLogger.log_warn("Chest directory not found: %s" % CHEST_DIR, "ChestDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := CHEST_DIR + file_name
			var chest := load(full_path) as ChestData
			if chest:
				if chest.id.is_empty():
					chest.id = file_name.get_basename()
				_register_chest(chest)
			else:
				DebugLogger.log_warn("Failed to load chest: %s" % full_path, "ChestDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_chest(chest: ChestData) -> void:
	if _chests.has(chest.id):
		DebugLogger.log_warn("Duplicate chest ID: %s" % chest.id, "ChestDatabase")
	_chests[chest.id] = chest


func get_chest(id: String) -> ChestData:
	if _chests.has(id):
		return _chests[id]
	DebugLogger.log_warn("Chest not found: %s" % id, "ChestDatabase")
	return null


func get_all_chests() -> Array:
	return _chests.values()


func has_chest(id: String) -> bool:
	return _chests.has(id)
