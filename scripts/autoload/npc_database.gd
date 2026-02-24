extends Node
## Autoload that loads and indexes all NpcData resources at startup.
## Access NPCs by ID: NpcDatabase.get_npc("blacksmith")

var _npcs: Dictionary = {}  # id -> NpcData

const NPC_DIR := "res://data/npcs/"


func _ready() -> void:
	_load_all_npcs()
	DebugLogger.log_info("Loaded %d NPCs" % _npcs.size(), "NpcDatabase")


func _load_all_npcs() -> void:
	var dir := DirAccess.open(NPC_DIR)
	if not dir:
		DebugLogger.log_warn("NPC directory not found: %s" % NPC_DIR, "NpcDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := NPC_DIR + file_name
			var npc := load(full_path) as NpcData
			if npc:
				if npc.id.is_empty():
					npc.id = file_name.get_basename()
				_register_npc(npc)
			else:
				DebugLogger.log_warn("Failed to load NPC: %s" % full_path, "NpcDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_npc(npc: NpcData) -> void:
	if _npcs.has(npc.id):
		DebugLogger.log_warn("Duplicate NPC ID: %s" % npc.id, "NpcDatabase")
	_npcs[npc.id] = npc


func get_npc(id: String) -> NpcData:
	if _npcs.has(id):
		return _npcs[id]
	DebugLogger.log_warn("NPC not found: %s" % id, "NpcDatabase")
	return null


func get_all_npcs() -> Array:
	return _npcs.values()


func has_npc(id: String) -> bool:
	return _npcs.has(id)
