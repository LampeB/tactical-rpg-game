extends Node
## Autoload that loads and indexes all PassiveTreeData resources at startup.
## Access trees by character ID: PassiveTreeDatabase.get_passive_tree("warrior")

var _trees: Dictionary = {}  # character_id -> PassiveTreeData

const TREE_DIR := "res://data/passive_trees/"

func _ready():
	_load_all_trees()
	DebugLogger.log_info("Loaded %d passive trees" % _trees.size(), "PassiveTreeDB")


func _load_all_trees():
	var dir := DirAccess.open(TREE_DIR)
	if not dir:
		DebugLogger.log_warning("Passive tree directory not found: %s" % TREE_DIR, "PassiveTreeDB")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := TREE_DIR + file_name
			var tree := load(full_path) as PassiveTreeData
			if tree and not tree.character_id.is_empty():
				_trees[tree.character_id] = tree
			elif tree:
				DebugLogger.log_warning("Passive tree missing character_id: %s" % full_path, "PassiveTreeDB")
			else:
				DebugLogger.log_warning("Failed to load passive tree: %s" % full_path, "PassiveTreeDB")
		file_name = dir.get_next()
	dir.list_dir_end()


func get_passive_tree(character_id: String) -> PassiveTreeData:
	return _trees.get(character_id)


func has_tree(character_id: String) -> bool:
	return _trees.has(character_id)


func get_all_trees() -> Array:
	return _trees.values()
