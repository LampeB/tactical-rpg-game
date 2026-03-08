extends Node
## Caches terrain GridMap nodes to avoid rebuilding on map revisit.
## Preloads adjacent maps' terrain in background.

const MAX_CACHE_SIZE := 3

## map_id → {gridmap: GridMap, timestamp: int}
var _cache: Dictionary = {}


func get_terrain(map_id: String) -> GridMap:
	## Returns a cached terrain GridMap for the given map, or null if not cached.
	if _cache.has(map_id):
		_cache[map_id].timestamp = Time.get_ticks_msec()
		return _cache[map_id].gridmap
	return null


func store_terrain(map_id: String, gridmap: GridMap) -> void:
	## Detaches a terrain GridMap from its parent and stores it in the cache.
	if gridmap.get_parent():
		gridmap.get_parent().remove_child(gridmap)
	_cache[map_id] = {
		"gridmap": gridmap,
		"timestamp": Time.get_ticks_msec(),
	}
	_evict_if_needed()
	DebugLogger.log_info("Cached terrain for map: %s (cache size: %d)" % [map_id, _cache.size()], "MapCache")


func preload_adjacent(current_map_id: String) -> void:
	## Queues background terrain builds for maps connected to the current map.
	var map_data: MapData = MapDatabase.get_map(current_map_id)
	if not map_data:
		return
	for conn in map_data.connections:
		if conn.target_map_id.is_empty():
			continue
		if _cache.has(conn.target_map_id):
			continue
		_preload_map.call_deferred(conn.target_map_id)


func clear() -> void:
	## Frees all cached terrain nodes and clears the cache.
	for id in _cache:
		_cache[id].gridmap.queue_free()
	_cache.clear()


func _preload_map(map_id: String) -> void:
	if _cache.has(map_id):
		return
	var target_data: MapData = MapDatabase.get_map(map_id)
	if not target_data:
		return
	var gridmap: GridMap = MapLoader.build_terrain_node(target_data)
	store_terrain(map_id, gridmap)


func _evict_if_needed() -> void:
	while _cache.size() > MAX_CACHE_SIZE:
		var oldest_id: String = ""
		var oldest_time: int = Time.get_ticks_msec()
		for id in _cache:
			if _cache[id].timestamp < oldest_time:
				oldest_time = _cache[id].timestamp
				oldest_id = id
		if not oldest_id.is_empty():
			var entry: Dictionary = _cache[oldest_id]
			entry.gridmap.queue_free()
			_cache.erase(oldest_id)
			DebugLogger.log_info("Evicted cached terrain: %s" % oldest_id, "MapCache")
