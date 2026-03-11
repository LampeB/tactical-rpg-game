extends Node
## Autoload that loads and indexes all ShopData resources at startup.
## Access shops by ID: ShopDatabase.get_shop("merchant_general")

var _shops: Dictionary = {}  # id -> ShopData

const SHOP_DIR := "res://data/shops/"


func _ready() -> void:
	_shops = ResourceLoaderHelper.load_dir(SHOP_DIR, "ShopDatabase")
	DebugLogger.log_info("Loaded %d shops" % _shops.size(), "ShopDatabase")


func get_shop(id: String) -> ShopData:
	if _shops.has(id):
		return _shops[id]
	DebugLogger.log_warn("Shop not found: %s" % id, "ShopDatabase")
	return null


func get_all_shops() -> Array:
	return _shops.values()


func has_shop(id: String) -> bool:
	return _shops.has(id)
