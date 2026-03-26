extends "res://scenes/world/base_map.gd"
## Overworld map controller — adds fast travel, day/night cycle, terrain caching,
## and battle background preloading on top of the shared base_map logic.

@onready var _fast_travel_menu: PanelContainer = $UI/FastTravelMenu

## Battle background preloading
var _preload_check_timer: float = 0.0
const _PRELOAD_CHECK_INTERVAL := 2.0
const _PRELOAD_DISTANCE := 40.0
var _preloaded_area_name: String = ""


# ---------------------------------------------------------------------------
# Virtual overrides
# ---------------------------------------------------------------------------

func _start_music() -> void:
	AudioManager.play_music("overworld")
	AudioManager.play_ambient("forest")


func _load_legacy_terrain() -> void:
	var cached: GridMap = MapCache.get_terrain(map_id)
	if cached:
		add_child(cached)
		_terrain_grid = cached
		DebugLogger.log_info("Using cached terrain for map: %s" % map_id, "Overworld")
	else:
		_terrain_grid = MapLoader.build_terrain(_map_data, self)


func _on_map_loaded() -> void:
	if not use_heightmap_terrain:
		MapCache.preload_adjacent.call_deferred(map_id)


func _restore_time_of_day() -> void:
	DayNightCycle.restore_state()
	DayNightCycle.paused = false


func _save_time_of_day() -> void:
	DayNightCycle.save_state()


func _map_process(delta: float) -> void:
	if use_heightmap_terrain and _map_data and (_terrain_node != null or _terrain_manager != null):
		_preload_check_timer += delta
		if _preload_check_timer >= _PRELOAD_CHECK_INTERVAL:
			_preload_check_timer = 0.0
			_check_battle_bg_preload()


func _handle_escape_override() -> bool:
	if _fast_travel_menu.visible:
		_fast_travel_menu._on_cancel()
		return true
	return false


func _handle_extra_input(event: InputEvent) -> bool:
	if event.is_action_pressed("fast_travel"):
		_open_fast_travel_menu()
		return true
	return false


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if not use_heightmap_terrain and _terrain_grid and is_instance_valid(_terrain_grid):
			MapCache.store_terrain(map_id, _terrain_grid)
			_terrain_grid = null


# ---------------------------------------------------------------------------
# Fast Travel (overworld only)
# ---------------------------------------------------------------------------

func _open_fast_travel_menu() -> void:
	var all_locations: Array[LocationData] = []
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data"):
			all_locations.append(marker.get_location_data())
	_fast_travel_menu.open_menu(all_locations)
	_fast_travel_menu.location_selected.connect(_on_fast_travel_selected, CONNECT_ONE_SHOT)
	_fast_travel_menu.visibility_changed.connect(_on_fast_travel_menu_visibility_changed, CONNECT_ONE_SHOT)
	_player.enable_input(false)


func _on_fast_travel_menu_visibility_changed() -> void:
	if not _fast_travel_menu.visible:
		_player.enable_input(true)


func _on_fast_travel_selected(location: LocationData) -> void:
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data") and marker.get_location_data() == location:
			_player.global_position = marker.global_position
			_player.enable_input(true)
			GameManager.set_flag("overworld_position", _player.global_position)
			GameManager.set_flag("camera_state", _orbit_camera.get_state())
			SaveManager.auto_save()
			break


# ---------------------------------------------------------------------------
# Battle Background Preloading (overworld only)
# ---------------------------------------------------------------------------

func _check_battle_bg_preload() -> void:
	var player_pos: Vector3 = _player.global_position
	var best_name: String = ""
	var best_pos: Vector3 = Vector3.ZERO
	var best_rot: float = 0.0
	var best_dist: float = INF

	for i in range(_map_data.battle_areas.size()):
		var area: BattleAreaData = _map_data.battle_areas[i]
		var dx: float = player_pos.x - area.position.x
		var dz: float = player_pos.z - area.position.z
		var dist: float = sqrt(dx * dx + dz * dz)
		if dist < best_dist:
			best_dist = dist
			best_name = area.area_name
			best_pos = area.position
			best_rot = area.rotation_y

	if _map_scene_root:
		var ba_nodes: Array = _find_children_of_type(_map_scene_root, "BattleArea3D")
		for i in range(ba_nodes.size()):
			var ba: Node3D = ba_nodes[i] as Node3D
			var dx: float = player_pos.x - ba.global_position.x
			var dz: float = player_pos.z - ba.global_position.z
			var dist: float = sqrt(dx * dx + dz * dz)
			if dist < best_dist:
				best_dist = dist
				best_name = ba.get("area_name") if ba.get("area_name") != "" else ba.name
				best_pos = ba.global_position
				best_rot = ba.get("rotation_offset_y") if ba.get("rotation_offset_y") else 0.0

	if best_name == "" or best_dist > _PRELOAD_DISTANCE:
		if not _preloaded_area_name.is_empty():
			GameManager.preloaded_battle_bg = null
			_preloaded_area_name = ""
		return

	if _preloaded_area_name == best_name:
		return

	var heightmap_data: HeightmapData = GameManager.current_heightmap_data as HeightmapData
	if not heightmap_data:
		return

	var arena_center: Vector3 = best_pos
	arena_center.y = _get_terrain_height(arena_center)

	var bg: Node3D = MapLoader.build_heightmap_battle_background(
		heightmap_data, arena_center, best_rot
	)
	GameManager.preloaded_battle_bg = bg
	GameManager.preloaded_battle_arena_center = arena_center
	GameManager.preloaded_battle_arena_rotation = best_rot
	_preloaded_area_name = best_name
	DebugLogger.log_info("Preloaded battle background for area: %s" % best_name, "Overworld")
