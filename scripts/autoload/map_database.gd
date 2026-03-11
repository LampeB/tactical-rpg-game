extends Node
## Autoload that loads and indexes all MapData resources at startup.
## Access maps by ID: MapDatabase.get_map("overworld")

var _maps: Dictionary = {}  # id -> MapData

const MAP_DIR := "res://data/maps/"


func _ready() -> void:
	_load_all_maps()
	DebugLogger.log_info("Loaded %d maps" % _maps.size(), "MapDatabase")


func _load_all_maps() -> void:
	_maps = ResourceLoaderHelper.load_dir(MAP_DIR, "MapDatabase", ResourceLoader.CACHE_MODE_REPLACE)


func get_map(map_id: String) -> MapData:
	if _maps.has(map_id):
		return _maps[map_id]
	DebugLogger.log_warn("Map not found: %s" % map_id, "MapDatabase")
	return null


func get_all_maps() -> Array:
	return _maps.values()


func get_all_map_ids() -> Array:
	return _maps.keys()


func has_map(map_id: String) -> bool:
	return _maps.has(map_id)


func reload() -> void:
	_maps.clear()
	_load_all_maps()
	DebugLogger.log_info("Reloaded %d maps" % _maps.size(), "MapDatabase")
