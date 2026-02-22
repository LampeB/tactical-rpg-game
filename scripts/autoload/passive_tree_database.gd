extends Node
## Autoload that loads the unified PassiveTreeData resource at startup.
## Access the shared tree: PassiveTreeDatabase.get_passive_tree()

var _tree: PassiveTreeData = null

const TREE_PATH := "res://data/passive_trees/tree_unified.tres"


func _ready():
	_tree = load(TREE_PATH) as PassiveTreeData
	if _tree:
		DebugLogger.log_info("Loaded unified passive tree (%d nodes)" % _tree.nodes.size(), "PassiveTreeDB")
	else:
		DebugLogger.log_warn("Failed to load unified passive tree: %s" % TREE_PATH, "PassiveTreeDB")


## Returns the single unified passive tree shared by all characters.
func get_passive_tree() -> PassiveTreeData:
	return _tree
