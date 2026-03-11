extends Node
## Autoload that loads and indexes all ChestData resources at startup.
## Access chests by ID: ChestDatabase.get_chest("dungeon_chest_01")

var _chests: Dictionary = {}  # id -> ChestData

const CHEST_DIR := "res://data/chests/"


func _ready() -> void:
	_chests = ResourceLoaderHelper.load_dir(CHEST_DIR, "ChestDatabase")
	DebugLogger.log_info("Loaded %d chests" % _chests.size(), "ChestDatabase")


func get_chest(id: String) -> ChestData:
	if _chests.has(id):
		return _chests[id]
	DebugLogger.log_warn("Chest not found: %s" % id, "ChestDatabase")
	return null


func get_all_chests() -> Array:
	return _chests.values()


func has_chest(id: String) -> bool:
	return _chests.has(id)
