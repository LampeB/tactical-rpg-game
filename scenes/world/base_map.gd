extends Node3D
## Base class for all explorable map scenes (overworld, local maps, dungeons).
## Provides shared terrain loading, player spawning, HUD, combat, and navigation.
## Child classes override virtual methods for map-specific behavior.

@onready var _player: CharacterBody3D = $Player
@onready var _location_markers: Node3D = $LocationMarkers
@onready var _orbit_camera: OrbitCamera = $OrbitCamera
@onready var _ui: CanvasLayer = $UI
@onready var _hud_gold_label: Label = $UI/HUD/GoldLabel
@onready var _hud_location_label: Label = $UI/HUD/LocationLabel
@onready var _message_label: Label = $UI/HUD/MessageLabel if has_node("UI/HUD/MessageLabel") else null

const BATTLE_COOLDOWN_TIME: float = 0.0
const MESSAGE_DISPLAY_TIME: float = 3.0

## Menu tab actions — must match game_menu.gd TAB_ACTIONS
const _MENU_TAB_ACTIONS: Array[String] = [
	"open_inventory", "open_skills", "open_passives", "open_stats",
	"open_map", "open_quest_log", "open_glossary", "open_options",
]
const _PARTY_HUD_SCRIPT := preload("res://scenes/world/party_hud.gd")
const _WaterBody := preload("res://scripts/terrain/water_body.gd")
const _TerrainManager := preload("res://scripts/terrain/terrain_manager.gd")
const _TestHeightmapGenerator := preload("res://scripts/terrain/test_heightmap_generator.gd")
const _BiomeHeightmapGenerator := preload("res://scripts/terrain/biome_heightmap_generator.gd")
const _HeightmapData := preload("res://scripts/terrain/heightmap_data.gd")
const _StructureManager := preload("res://scripts/terrain/structure_manager.gd")
const _RiverBody := preload("res://scripts/terrain/river_body.gd")

@export var map_id: String = "example_map"
@export var use_heightmap_terrain: bool = false
@export_file("*.tscn") var map_scene_path: String = ""

var _map_data: MapData
var _connection_markers: Node3D
var _terrain_manager: Node3D
var _terrain_node: HeightmapTerrain3D = null
var _map_scene_root: Node3D = null
var _message_timer: float = 0.0
var _current_message: String = ""
var _game_menu_instance: Node = null
var _party_hud: HBoxContainer = null
var _terrain_grid: GridMap = null


# ---------------------------------------------------------------------------
# Virtual methods — override in child classes
# ---------------------------------------------------------------------------

func _start_music() -> void:
	## Override to play map-specific music/ambient.
	pass


func _load_legacy_terrain() -> void:
	## Override for legacy GridMap loading (e.g., overworld uses MapCache).
	_terrain_grid = MapLoader.build_terrain(_map_data, self)


func _on_map_loaded() -> void:
	## Called after map data is loaded and elements spawned.
	pass


func _restore_time_of_day() -> void:
	## Override to restore day/night state.
	pass


func _save_time_of_day() -> void:
	## Override to save day/night state.
	pass


func _map_process(_delta: float) -> void:
	## Override for map-specific per-frame logic.
	pass


func _handle_escape_override() -> bool:
	## Return true if escape was handled by child (e.g., closing fast travel menu).
	return false


func _handle_extra_input(_event: InputEvent) -> bool:
	## Return true if event was handled by child (e.g., fast travel key).
	return false


# ---------------------------------------------------------------------------
# Transition log — writes to tools/map_transition_log.txt
# ---------------------------------------------------------------------------

var _tlog: FileAccess = null

func _tlog_open() -> void:
	var path: String = ProjectSettings.globalize_path("res://tools/map_transition_log.txt")
	_tlog = FileAccess.open(path, FileAccess.READ_WRITE)
	if not _tlog:
		_tlog = FileAccess.open(path, FileAccess.WRITE)
	else:
		_tlog.seek_end()

func _tlog_write(msg: String) -> void:
	var line: String = "[%dms] %s" % [Time.get_ticks_msec(), msg]
	print("[MapTransition] %s" % msg)
	if _tlog:
		_tlog.store_line(line)
		_tlog.flush()


# ---------------------------------------------------------------------------
# Lifecycle
# ---------------------------------------------------------------------------

func _ready() -> void:
	_tlog_open()
	_tlog_write("=== _ready() START map_id='%s' scene='%s' ===" % [GameManager.current_map_id, get_tree().current_scene.name if get_tree().current_scene else "?"])

	if not GameManager.current_map_id.is_empty():
		map_id = GameManager.current_map_id

	_tlog_write("map_id resolved to '%s'" % map_id)
	_orbit_camera.set_follow_target(_player)

	if GameManager.party:
		var saved_pos: Vector3 = _get_saved_position()
		DebugLogger.log_info("Saved position: %s" % saved_pos, "BaseMap")
		if saved_pos != Vector3.ZERO:
			_player.global_position = saved_pos
			DebugLogger.log_info("Restored player to: %s" % saved_pos, "BaseMap")

	DebugLogger.log_info("Player starting at: %s" % _player.global_position, "BaseMap")

	EventBus.gold_changed.connect(_update_hud_gold)
	EventBus.location_prompt_visible.connect(_on_location_prompt)
	EventBus.show_message.connect(_show_message)
	_update_hud_gold(GameManager.gold)
	_hud_location_label.text = ""

	if not _message_label:
		_message_label = Label.new()
		_message_label.name = "MessageLabel"
		_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_message_label.set_anchors_preset(Control.PRESET_CENTER)
		_message_label.position = Vector2(0, -200)
		UIThemes.set_font_size(_message_label, 24)
		_message_label.add_theme_color_override("font_color", Color.YELLOW)
		_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_message_label.add_theme_constant_override("outline_size", 4)
		_message_label.visible = false
		$UI/HUD.add_child(_message_label)

	_party_hud = HBoxContainer.new()
	_party_hud.set_script(_PARTY_HUD_SCRIPT)
	$UI/HUD.add_child(_party_hud)

	GameManager.current_map_id = map_id

	_start_music()

	_map_data = MapDatabase.get_map(map_id)
	_tlog_write("MapData loaded: %s (is_overworld=%s, scene_path='%s', heightmap=%s)" % [
		str(_map_data != null), str(_map_data.is_overworld) if _map_data else "?",
		_map_data.map_scene_path if _map_data else "", str(use_heightmap_terrain)])
	if _map_data:
		GameManager.current_location_name = _map_data.display_name if not _map_data.display_name.is_empty() else map_id.capitalize()

		# Auto-enable heightmap terrain when MapData has a scene path
		if not use_heightmap_terrain and _map_data and not _map_data.map_scene_path.is_empty():
			use_heightmap_terrain = true

		if use_heightmap_terrain:
			_tlog_write("Building heightmap terrain...")
			await _build_heightmap_terrain()
			_tlog_write("Heightmap terrain done. _terrain_node=%s _map_scene_root=%s" % [str(_terrain_node != null), str(_map_scene_root != null)])
		else:
			GameManager.current_heightmap_data = null
			_load_legacy_terrain()

		var enemies_node := Node3D.new()
		enemies_node.name = "Enemies"
		add_child(enemies_node)
		var chests_node := Node3D.new()
		chests_node.name = "Chests"
		add_child(chests_node)
		var is_scene_based: bool = use_heightmap_terrain and _terrain_node != null
		if is_scene_based and _map_scene_root:
			# Scene-based: spawn enemies from generator markers + elements for NPCs/chests
			MapLoader.spawn_scene_encounters(_map_scene_root, enemies_node)
			MapLoader.spawn_elements(_map_data, self, _location_markers, enemies_node, chests_node)
		elif not is_scene_based:
			MapLoader.spawn_elements(_map_data, self, _location_markers, enemies_node, chests_node)
		_connection_markers = Node3D.new()
		_connection_markers.name = "ConnectionMarkers"
		add_child(_connection_markers)
		MapLoader.spawn_connections(_map_data, _connection_markers)
		_tlog_write("Spawned %d connections" % _map_data.connections.size())

		# Resolve spawn from target_connection_id now that connections exist
		var target_conn_id: String = GameManager.get_flag("target_connection_id", "")
		_tlog_write("target_connection_id='%s'" % target_conn_id)
		if not target_conn_id.is_empty():
			GameManager.set_flag("target_connection_id", "")
			# Search MapData connections directly — more reliable than searching the scene tree
			var conn_pos: Vector3 = Vector3.ZERO
			for ci in range(_map_data.connections.size()):
				var conn: MapConnection = _map_data.connections[ci]
				if conn.connection_id == target_conn_id:
					conn_pos = conn.position
					break
			# Fallback: search spawned markers and scene tree
			if conn_pos == Vector3.ZERO:
				conn_pos = _find_connection_position(_connection_markers, target_conn_id)
			if conn_pos == Vector3.ZERO and _map_scene_root:
				conn_pos = _find_connection_position(_map_scene_root, target_conn_id)
			if conn_pos != Vector3.ZERO:
				var sy: float = conn_pos.y
				if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
					sy = _get_terrain_height(conn_pos)
				_player.global_position = Vector3(conn_pos.x, sy + 2.0, conn_pos.z)
				DebugLogger.log_info("Spawned at connection '%s': %s" % [target_conn_id, _player.global_position], "BaseMap")
			else:
				DebugLogger.log_warn("Connection '%s' not found on map '%s'" % [target_conn_id, map_id], "BaseMap")

		if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
			if not is_scene_based:
				_ground_elements_to_terrain(_location_markers)
				_ground_elements_to_terrain(enemies_node, 2.0)
				_ground_elements_to_terrain(chests_node)
			_ground_elements_to_terrain(_connection_markers)
			if not is_scene_based:
				_wire_terrain_sources(self)
				_wire_terrain_sources(enemies_node)

		_on_map_loaded()
	else:
		DebugLogger.log_error("Map not found: %s" % map_id, "BaseMap")

	var saved_cam: Variant = GameManager.get_flag("camera_state", {})
	if saved_cam is Dictionary and not saved_cam.is_empty():
		_orbit_camera.restore_state(saved_cam)

	_restore_time_of_day()

	_orbit_camera.global_position = _player.global_position

	SaveManager.auto_save()
	_tlog_write("=== _ready() DONE — player at %s ===" % _player.global_position)
	if _tlog:
		_tlog.close()
		_tlog = null

	var occlusion := CameraOcclusion.new()
	occlusion.camera = _orbit_camera
	occlusion.player = _player
	add_child(occlusion)

	_enable_enemy_detection()


func _enter_tree() -> void:
	# Re-attach cached map scene root when restored from stash (push/pop)
	if _map_scene_root and is_instance_valid(_map_scene_root) and _map_scene_root.get_parent() != self:
		add_child(_map_scene_root)


func _exit_tree() -> void:
	# Detach cached map scene root so it survives scene transitions
	var should_cache: bool = _map_scene_root and is_instance_valid(_map_scene_root) and _map_scene_root.get_parent() == self and GameManager.cached_map_nodes.has(map_scene_path)
	print("[MapTransition] _exit_tree: map_id='%s' caching=%s" % [map_id, str(should_cache)])
	if should_cache:
		remove_child(_map_scene_root)


func _process(delta: float) -> void:
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_hide_message()
	_map_process(delta)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_released("escape"):
		if _handle_escape_override():
			get_viewport().set_input_as_handled()
			return
		_open_game_menu()
		get_viewport().set_input_as_handled()
	elif _handle_extra_input(event):
		get_viewport().set_input_as_handled()
	else:
		# Check game menu shortcut actions (all on release)
		for tab_id in range(_MENU_TAB_ACTIONS.size()):
			if event.is_action_released(_MENU_TAB_ACTIONS[tab_id]):
				_save_current_position()
				_open_game_menu(tab_id)
				get_viewport().set_input_as_handled()
				return
				return


func receive_data(data: Dictionary) -> void:
	if _party_hud:
		_party_hud.rebuild()

	var spawn_pos: Variant = data.get("spawn_position", null)
	if spawn_pos is Vector3 and spawn_pos != Vector3.ZERO:
		if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
			var ground_y: float = _get_terrain_height(spawn_pos as Vector3) + 2.0
			spawn_pos = Vector3((spawn_pos as Vector3).x, ground_y, (spawn_pos as Vector3).z)
		_player.global_position = spawn_pos
		GameManager.set_flag("overworld_position", spawn_pos)
		_orbit_camera.reset_orientation()
		_orbit_camera.global_position = spawn_pos
		GameManager.set_flag("camera_state", _orbit_camera.get_state())
		SaveManager.auto_save()

	if data.get("from_battle", false):
		_push_player_from_enemies()
		_player.enable_input(true)
		SaveManager.auto_save()
		_enable_enemy_detection()
		_apply_battle_cooldown()


# ---------------------------------------------------------------------------
# Terrain
# ---------------------------------------------------------------------------

func _build_heightmap_terrain() -> void:
	var scene_path_local: String = map_scene_path
	if _map_data and not _map_data.map_scene_path.is_empty():
		scene_path_local = _map_data.map_scene_path
	if scene_path_local != "" and ResourceLoader.exists(scene_path_local):
		map_scene_path = scene_path_local
		await _build_scene_based_terrain()
	else:
		_build_procedural_terrain()


func _build_scene_based_terrain() -> void:
	_tlog_write("_build_scene_based_terrain: map_scene_path='%s'" % map_scene_path)
	# Reuse cached node if available — avoids re-instantiating and rebuilding chunks
	var cached_node: Node3D = GameManager.cached_map_nodes.get(map_scene_path) as Node3D
	_tlog_write("  cached_node=%s valid=%s" % [str(cached_node != null), str(is_instance_valid(cached_node)) if cached_node else "n/a"])
	if cached_node and is_instance_valid(cached_node):
		_tlog_write("  Reusing cached node")
		if cached_node.get_parent():
			cached_node.get_parent().remove_child(cached_node)
		add_child(cached_node)
		_map_scene_root = cached_node
		_terrain_node = _find_child_of_type(_map_scene_root, "HeightmapTerrain3D") as HeightmapTerrain3D
		GameManager.current_heightmap_data = _terrain_node.heightmap_data if _terrain_node else null
		return

	# First load — Godot caches the PackedScene, but instantiate() + _ready() is the slow part
	_tlog_write("  First load — starting async request")
	_show_loading_screen(1)
	_loading_label.text = "Loading map..."
	_loading_bar.max_value = 100.0
	ResourceLoader.load_threaded_request(map_scene_path)
	await _await_scene_load()


func _await_scene_load() -> void:
	## Polls the threaded loader each frame until the scene is ready.
	_tlog_write("_await_scene_load: polling...")
	while true:
		var progress: Array = []
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(map_scene_path, progress)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if _loading_bar and not progress.is_empty():
				_loading_bar.value = progress[0] * 100.0
			await get_tree().process_frame
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			var scene: PackedScene = ResourceLoader.load_threaded_get(map_scene_path) as PackedScene
			await _finish_scene_load(scene)
			return
		else:
			DebugLogger.log_error("Failed to load map scene: %s" % map_scene_path, "BaseMap")
			if _loading_overlay:
				_loading_overlay.queue_free()
				_loading_overlay = null
			_player.visible = true
			_build_procedural_terrain()
			return


func _finish_scene_load(scene: PackedScene) -> void:
	_tlog_write("_finish_scene_load: scene=%s" % str(scene != null))
	if _loading_label:
		_loading_label.text = "Building terrain..."
		await get_tree().process_frame

	_map_scene_root = scene.instantiate() as Node3D
	if not _map_scene_root:
		DebugLogger.log_error("Map scene is not a Node3D: %s" % map_scene_path, "BaseMap")
		if _loading_overlay:
			_loading_overlay.queue_free()
			_loading_overlay = null
		_player.visible = true
		_build_procedural_terrain()
		return
	_tlog_write("  Adding scene root to tree...")
	add_child(_map_scene_root)
	_tlog_write("  Scene root added. Finding HeightmapTerrain3D...")

	_terrain_node = _find_child_of_type(_map_scene_root, "HeightmapTerrain3D") as HeightmapTerrain3D
	_tlog_write("  _terrain_node=%s has_data=%s" % [str(_terrain_node != null), str(_terrain_node.heightmap_data != null) if _terrain_node else "n/a"])
	if not _terrain_node or not _terrain_node.heightmap_data:
		DebugLogger.log_error("Map scene has no HeightmapTerrain3D with data: %s" % map_scene_path, "BaseMap")
		if _loading_overlay:
			_loading_overlay.queue_free()
			_loading_overlay = null
		_player.visible = true
		_build_procedural_terrain()
		return

	GameManager.current_heightmap_data = _terrain_node.heightmap_data

	# Player position is resolved in _ready() after connections are spawned.
	# Just set a temporary position from spawn point or saved pos.
	var spawn_pos: Vector3 = _map_data.player_spawn if _map_data else Vector3.ZERO
	if GameManager.get_flag("overworld_position", Vector3.ZERO) != Vector3.ZERO:
		spawn_pos = GameManager.get_flag("overworld_position", Vector3.ZERO)
	spawn_pos.y = _get_terrain_height(spawn_pos) + 2.0
	_player.global_position = spawn_pos

	# Hide loading screen
	_player.visible = true
	if _loading_overlay:
		_loading_overlay.queue_free()
		_loading_overlay = null

	# Cache the instantiated node for instant reuse on future visits
	GameManager.cached_map_nodes[map_scene_path] = _map_scene_root

	DebugLogger.log_info("Loaded scene-based map: %s (%dx%d)" % [
		map_scene_path, _terrain_node.heightmap_data.width, _terrain_node.heightmap_data.height
	], "BaseMap")


func _build_procedural_terrain() -> void:
	var hw: int = _map_data.grid_width + 1 if _map_data else 129
	var hh: int = _map_data.grid_height + 1 if _map_data else 81
	var terrain_seed: int = _map_data.decoration_seed if _map_data else 42
	var heightmap_data = _BiomeHeightmapGenerator.generate(hw, hh, terrain_seed)
	GameManager.current_heightmap_data = heightmap_data
	var spawn_pos: Vector3 = _map_data.player_spawn if _map_data else Vector3.ZERO
	_player.global_position = spawn_pos

	_terrain_manager = _TerrainManager.new()
	_terrain_manager.view_distance = 3
	_terrain_manager.unload_distance = heightmap_data.get_chunk_count_x() + 1
	_terrain_manager._data = heightmap_data
	add_child(_terrain_manager)
	_terrain_manager.loading_complete.connect(_on_terrain_loading_complete)
	_terrain_manager.loading_progress.connect(_on_terrain_loading_progress)
	_show_loading_screen(heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z())
	_terrain_manager.preload_all(_player)

	var zones: Array = heightmap_data.water_zones
	for i in range(zones.size()):
		var zone = zones[i]
		var water: MeshInstance3D = _WaterBody.new()
		water.water_size = zone.size
		water.water_shape = zone.shape
		water.water_level = zone.center.y
		water.shallow_color = zone.shallow_color
		water.deep_color = zone.deep_color
		water.wave_speed = zone.wave_speed
		water.wave_strength = zone.wave_strength
		water.position = Vector3(zone.center.x, zone.center.y, zone.center.z)
		add_child(water)

	var river_paths: Array = heightmap_data.rivers
	for ri in range(river_paths.size()):
		var rp = river_paths[ri]
		var river_body: MeshInstance3D = _RiverBody.new()
		river_body.setup(rp)
		add_child(river_body)
	if not river_paths.is_empty():
		DebugLogger.log_info("Spawned %d rivers" % river_paths.size(), "BaseMap")

	if not heightmap_data.structures.is_empty():
		var struct_mgr = _StructureManager.new()
		struct_mgr.build(heightmap_data)
		add_child(struct_mgr)
		DebugLogger.log_info("Placed %d structures" % heightmap_data.structures.size(), "BaseMap")

	DebugLogger.log_info("Built procedural terrain: %dx%d, %d chunks" % [
		heightmap_data.width, heightmap_data.height,
		heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z()
	], "BaseMap")


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _find_child_of_type(node: Node, type_name: String) -> Node:
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node
	for i in range(node.get_child_count()):
		var found: Node = _find_child_of_type(node.get_child(i), type_name)
		if found:
			return found
	return null


func _find_connection_position(root: Node, conn_id: String) -> Vector3:
	if root is Area3D and root.has_method("get_display_name"):
		var data = root.get("connection_data")
		if data is MapConnection and data.connection_id == conn_id:
			return root.global_position
	for i in range(root.get_child_count()):
		var result: Vector3 = _find_connection_position(root.get_child(i), conn_id)
		if result != Vector3.ZERO:
			return result
	return Vector3.ZERO


func _find_children_of_type(node: Node, type_name: String) -> Array:
	var results: Array = []
	if node.get_script() and node.get_script().get_global_name() == type_name:
		results.append(node)
	for i in range(node.get_child_count()):
		results.append_array(_find_children_of_type(node.get_child(i), type_name))
	return results


func _get_terrain_height(world_pos: Vector3) -> float:
	if _terrain_node and _terrain_node.heightmap_data:
		return _terrain_node.get_height_at_world(world_pos)
	if _terrain_manager:
		return _terrain_manager.get_height_at_world(world_pos)
	return 0.0


func _ground_elements_to_terrain(parent: Node3D, y_offset: float = 0.0) -> void:
	for i in range(parent.get_child_count()):
		var child: Node3D = parent.get_child(i) as Node3D
		if child:
			_ground_node_to_terrain(child, y_offset)


func _ground_node_to_terrain(node: Node3D, y_offset: float = 0.0) -> void:
	var height: float = _get_terrain_height(node.position)
	node.position.y = height + y_offset


func _wire_terrain_sources(parent: Node3D) -> void:
	var height_source: Node = _terrain_node if _terrain_node else _terrain_manager
	for i in range(parent.get_child_count()):
		var child: Node = parent.get_child(i)
		if child.has_method("set_terrain_height_source"):
			child.set_terrain_height_source(height_source)
			if child is Node3D:
				_ground_node_to_terrain(child as Node3D)


# ---------------------------------------------------------------------------
# HUD
# ---------------------------------------------------------------------------

func _get_saved_position() -> Vector3:
	var saved: Variant = GameManager.get_flag("overworld_position", Vector3.ZERO)
	if saved is Vector3:
		return saved
	if saved is Vector2:
		return Vector3(saved.x / Constants.PIXEL_TO_WORLD, 0.0, saved.y / Constants.PIXEL_TO_WORLD)
	return Vector3.ZERO


func _update_hud_gold(gold: int) -> void:
	_hud_gold_label.text = "Gold: %d" % gold


func _on_location_prompt(prompt_visible: bool, location_name: String) -> void:
	if prompt_visible:
		_hud_location_label.text = "[E] Enter: %s" % location_name
	else:
		_hud_location_label.text = ""


func _show_message(message: String) -> void:
	if not _message_label:
		DebugLogger.log_warn("No message label to display: %s" % message, "BaseMap")
		return
	_current_message = message
	_message_label.text = message
	_message_label.visible = true
	_message_timer = MESSAGE_DISPLAY_TIME
	DebugLogger.log_info("Showing message: %s" % message, "BaseMap")


func _hide_message() -> void:
	if _message_label:
		_message_label.visible = false
	_current_message = ""


func _save_current_position() -> void:
	if _player:
		GameManager.set_flag("overworld_position", _player.global_position)
		GameManager.set_flag("camera_state", _orbit_camera.get_state())
		_save_time_of_day()
		DebugLogger.log_info("Saved current position: %s" % _player.global_position, "BaseMap")


# ---------------------------------------------------------------------------
# Combat
# ---------------------------------------------------------------------------

func _enable_enemy_detection() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and enemy.has_method("enable_detection"):
			enemy.enable_detection()
	DebugLogger.log_info("Enabled detection for %d enemies" % enemies.size(), "BaseMap")


func _push_player_from_enemies() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	var player_pos: Vector3 = _player.global_position
	var closest_enemy: Node = null
	var closest_distance: float = INF
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and is_instance_valid(enemy) and enemy is Node3D:
			var distance: float = player_pos.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy
	if closest_enemy and closest_distance < Constants.SAFE_DISTANCE:
		var push_direction: Vector3 = (player_pos - closest_enemy.global_position).normalized()
		push_direction.y = 0.0
		if push_direction.length() < 0.1:
			push_direction = Vector3.RIGHT
		var new_position: Vector3 = closest_enemy.global_position + (push_direction.normalized() * Constants.PUSH_DISTANCE)
		if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
			new_position.y = _get_terrain_height(new_position) + 1.0
		else:
			new_position.y = 0.0
		_player.global_position = new_position
		GameManager.set_flag("overworld_position", _player.global_position)
		GameManager.set_flag("camera_state", _orbit_camera.get_state())
		DebugLogger.log_info("Pushed player away from enemy (distance was %.1f)" % closest_distance, "BaseMap")


func _apply_battle_cooldown() -> void:
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for ei in range(enemies.size()):
		var e: Node = enemies[ei]
		if e.has_method("disable_battles_temporarily"):
			e.disable_battles_temporarily()
	await get_tree().create_timer(BATTLE_COOLDOWN_TIME).timeout
	for ri in range(enemies.size()):
		var re: Node = enemies[ri]
		if re and is_instance_valid(re) and re.has_method("re_enable_battles"):
			re.re_enable_battles()
	DebugLogger.log_info("Battle cooldown ended - enemies can trigger battles again", "BaseMap")


# ---------------------------------------------------------------------------
# Game Menu
# ---------------------------------------------------------------------------

func _open_game_menu(initial_tab: int = -1) -> void:
	## Opens the unified game menu. Optionally opens a specific tab.
	if _game_menu_instance:
		return  # Already open
	_save_current_position()
	var menu_scene: PackedScene = load("res://scenes/menus/game_menu.tscn")
	_game_menu_instance = menu_scene.instantiate()
	add_child(_game_menu_instance)
	_game_menu_instance.closed.connect(_on_game_menu_closed)
	if initial_tab >= 0:
		_game_menu_instance.open_tab(initial_tab)
	else:
		_game_menu_instance.open_tab(0)  # Default to Inventory


func _on_game_menu_closed() -> void:
	_game_menu_instance = null


# ---------------------------------------------------------------------------
# Loading screen
# ---------------------------------------------------------------------------

var _loading_overlay: CanvasLayer = null
var _loading_bar: ProgressBar = null
var _loading_label: Label = null
var _loading_chunk_total: int = 0


func _show_loading_screen(total_chunks: int) -> void:
	_loading_chunk_total = total_chunks
	_player.visible = false

	_loading_overlay = CanvasLayer.new()
	_loading_overlay.layer = 128
	add_child(_loading_overlay)

	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.08, 1.0)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading_overlay.add_child(bg)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(500, 120)
	vbox.position = Vector2(-250, -60)
	vbox.add_theme_constant_override("separation", 16)
	_loading_overlay.add_child(vbox)

	_loading_label = Label.new()
	_loading_label.text = "Loading world..."
	_loading_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading_label.add_theme_font_size_override("font_size", 24)
	vbox.add_child(_loading_label)

	_loading_bar = ProgressBar.new()
	_loading_bar.min_value = 0.0
	_loading_bar.max_value = float(total_chunks)
	_loading_bar.value = 0.0
	_loading_bar.custom_minimum_size = Vector2(500, 28)
	vbox.add_child(_loading_bar)


func _on_terrain_loading_progress(done: int, total: int) -> void:
	if _loading_bar:
		_loading_bar.value = float(done)
	if _loading_label:
		_loading_label.text = "Loading world... %d / %d chunks" % [done, total]


func _on_terrain_loading_complete() -> void:
	var spawn_pos: Vector3 = _player.global_position
	if _terrain_manager:
		var ground_y: float = _terrain_manager.get_height_at_world(spawn_pos) + 2.0
		_player.global_position = Vector3(spawn_pos.x, ground_y, spawn_pos.z)
		_orbit_camera.global_position = _player.global_position
	_player.visible = true
	if _loading_overlay:
		_loading_overlay.queue_free()
		_loading_overlay = null
