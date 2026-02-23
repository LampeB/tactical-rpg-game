extends Node
## Autoload that loads and indexes all ItemData resources at startup.
## Access items by ID: ItemDatabase.get_item("sword_common")

var _items: Dictionary = {}  # id -> ItemData
var _items_by_type: Dictionary = {}  # ItemType -> Array[ItemData]
var _items_by_rarity: Dictionary = {}  # Rarity -> Array[ItemData]

const ITEM_DIRS: Array[String] = [
	"res://data/items/weapons/",
	"res://data/items/armor/",
	"res://data/items/consumables/",
	"res://data/items/modifiers/",
]

func _ready():
	_load_all_items()
	DebugLogger.log_info("Loaded %d items" % _items.size(), "ItemDatabase")

func _load_all_items():
	for dir_path in ITEM_DIRS:
		_load_items_from_directory(dir_path)

func _load_items_from_directory(dir_path: String):
	var dir := DirAccess.open(dir_path)
	if not dir:
		DebugLogger.log_warn("Item directory not found: %s" % dir_path, "ItemDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := dir_path + file_name
			var item := load(full_path) as ItemData
			if item:
				if item.id.is_empty():
					item.id = file_name.get_basename()
				_register_item(item)
			else:
				DebugLogger.log_warn("Failed to load item: %s" % full_path, "ItemDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()

func _register_item(item: ItemData):
	if _items.has(item.id):
		DebugLogger.log_warn("Duplicate item ID: %s" % item.id, "ItemDatabase")
	_items[item.id] = item

	# Index by type
	if not _items_by_type.has(item.item_type):
		_items_by_type[item.item_type] = []
	_items_by_type[item.item_type].append(item)

	# Index by rarity
	if not _items_by_rarity.has(item.rarity):
		_items_by_rarity[item.rarity] = []
	_items_by_rarity[item.rarity].append(item)

func get_item(id: String) -> ItemData:
	if _items.has(id):
		return _items[id]
	DebugLogger.log_warn("Item not found: %s" % id, "ItemDatabase")
	return null

func get_all_items() -> Array:
	return _items.values()

func get_items_by_type(item_type: Enums.ItemType) -> Array:
	if _items_by_type.has(item_type):
		return _items_by_type[item_type]
	return []

func get_items_by_rarity(rarity: Enums.Rarity) -> Array:
	if _items_by_rarity.has(rarity):
		return _items_by_rarity[rarity]
	return []

func has_item(id: String) -> bool:
	return _items.has(id)

func reload():
	_items.clear()
	_items_by_type.clear()
	_items_by_rarity.clear()
	_load_all_items()
	DebugLogger.log_info("Reloaded %d items" % _items.size(), "ItemDatabase")
