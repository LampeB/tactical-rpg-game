extends Node
## Autoload that loads and indexes all ShopData resources at startup.
## Access shops by ID: ShopDatabase.get_shop("merchant_general")

var _shops: Dictionary = {}  # id -> ShopData

const SHOP_DIR := "res://data/shops/"


func _ready() -> void:
	_load_all_shops()
	DebugLogger.log_info("Loaded %d shops" % _shops.size(), "ShopDatabase")


func _load_all_shops() -> void:
	var dir := DirAccess.open(SHOP_DIR)
	if not dir:
		DebugLogger.log_warn("Shop directory not found: %s" % SHOP_DIR, "ShopDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := SHOP_DIR + file_name
			var shop := load(full_path) as ShopData
			if shop:
				if shop.id.is_empty():
					shop.id = file_name.get_basename()
				_register_shop(shop)
			else:
				DebugLogger.log_warn("Failed to load shop: %s" % full_path, "ShopDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_shop(shop: ShopData) -> void:
	if _shops.has(shop.id):
		DebugLogger.log_warn("Duplicate shop ID: %s" % shop.id, "ShopDatabase")
	_shops[shop.id] = shop


func get_shop(id: String) -> ShopData:
	if _shops.has(id):
		return _shops[id]
	DebugLogger.log_warn("Shop not found: %s" % id, "ShopDatabase")
	return null


func get_all_shops() -> Array:
	return _shops.values()


func has_shop(id: String) -> bool:
	return _shops.has(id)
