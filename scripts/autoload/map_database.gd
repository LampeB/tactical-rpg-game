extends Node
## Autoload that loads and indexes all MapData resources at startup.
## Access maps by ID: MapDatabase.get_map("overworld")

var _maps: Dictionary = {}  # id -> MapData

const MAP_DIR := "res://data/maps/"


func _ready() -> void:
	_load_all_maps()
	DebugLogger.log_info("Loaded %d maps" % _maps.size(), "MapDatabase")


func _load_all_maps() -> void:
	var dir := DirAccess.open(MAP_DIR)
	if not dir:
		DebugLogger.log_warn("Map directory not found: %s" % MAP_DIR, "MapDatabase")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := MAP_DIR + file_name
			var map_data := ResourceLoader.load(full_path, "", ResourceLoader.CACHE_MODE_REPLACE) as MapData
			if map_data:
				if map_data.id.is_empty():
					map_data.id = file_name.get_basename()
				_register_map(map_data)
			else:
				DebugLogger.log_warn("Failed to load map: %s" % full_path, "MapDatabase")
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_map(map_data: MapData) -> void:
	if _maps.has(map_data.id):
		DebugLogger.log_warn("Duplicate map ID: %s" % map_data.id, "MapDatabase")
	_maps[map_data.id] = map_data


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
