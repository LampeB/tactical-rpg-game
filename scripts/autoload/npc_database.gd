extends Node
## Autoload that loads and indexes all NpcData resources at startup.
## Access NPCs by ID: NpcDatabase.get_npc("blacksmith")

var _npcs: Dictionary = {}  # id -> NpcData

const NPC_DIR := "res://data/npcs/"


func _ready() -> void:
	_load_all_npcs()
	DebugLogger.log_info("Loaded %d NPCs" % _npcs.size(), "NpcDatabase")


func _load_all_npcs() -> void:
	_npcs = ResourceLoaderHelper.load_dir(NPC_DIR, "NpcDatabase")


func get_npc(id: String) -> NpcData:
	if _npcs.has(id):
		return _npcs[id]
	DebugLogger.log_warn("NPC not found: %s" % id, "NpcDatabase")
	return null


func get_all_npcs() -> Array:
	return _npcs.values()


func has_npc(id: String) -> bool:
	return _npcs.has(id)


func reload() -> void:
	_npcs.clear()
	_load_all_npcs()
	DebugLogger.log_info("Reloaded %d NPCs" % _npcs.size(), "NpcDatabase")
