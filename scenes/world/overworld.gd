extends Node3D
## Main overworld scene controller (3D version).

@onready var _player: CharacterBody3D = $Player
@onready var _location_markers: Node3D = $LocationMarkers
@onready var _orbit_camera: OrbitCamera = $OrbitCamera
@onready var _ui: CanvasLayer = $UI
@onready var _fast_travel_menu: PanelContainer = $UI/FastTravelMenu
@onready var _hud_gold_label: Label = $UI/HUD/GoldLabel
@onready var _hud_location_label: Label = $UI/HUD/LocationLabel
@onready var _message_label: Label = $UI/HUD/MessageLabel if has_node("UI/HUD/MessageLabel") else null

const BATTLE_COOLDOWN_TIME: float = 0.0  ## Seconds of immunity after battle
const MESSAGE_DISPLAY_TIME: float = 3.0  ## Seconds to show messages
const _PAUSE_SCENE := preload("res://scenes/menus/pause_menu.tscn")
const _PARTY_HUD_SCRIPT := preload("res://scenes/world/party_hud.gd")
const _WaterBody := preload("res://scripts/terrain/water_body.gd")
const _TerrainManager := preload("res://scripts/terrain/terrain_manager.gd")
const _TestHeightmapGenerator := preload("res://scripts/terrain/test_heightmap_generator.gd")
const _BiomeHeightmapGenerator := preload("res://scripts/terrain/biome_heightmap_generator.gd")
const _HeightmapData := preload("res://scripts/terrain/heightmap_data.gd")
const _StructureManager := preload("res://scripts/terrain/structure_manager.gd")
const _RiverBody := preload("res://scripts/terrain/river_body.gd")

@export var map_id: String = "example_map"
## When true, uses the new heightmap terrain system instead of GridMap blocks.
@export var use_heightmap_terrain: bool = false
## Optional path to a map .tscn scene containing HeightmapTerrain3D + zone nodes.
## If set, loads this scene instead of procedural generation.
@export_file("*.tscn") var map_scene_path: String = ""
var _map_data: MapData
var _connection_markers: Node3D
var _terrain_manager: Node3D  ## TerrainManager — procedural terrain only
var _terrain_node: HeightmapTerrain3D = null  ## Scene-based terrain node (baked maps)
var _map_scene_root: Node3D = null  ## Loaded map scene instance
var _message_timer: float = 0.0
var _current_message: String = ""
var _pause_menu_instance: Control = null
var _party_hud: HBoxContainer = null
var _terrain_grid: GridMap = null

## Battle background preloading
var _preload_check_timer: float = 0.0
const _PRELOAD_CHECK_INTERVAL := 2.0  ## Seconds between proximity checks
const _PRELOAD_DISTANCE := 40.0  ## Preload when player is within this distance of a battle area
var _preloaded_area_name: String = ""  ## Tracks which area is preloaded to avoid redundant work


func _ready() -> void:
	# Use current map from GameManager (handles map transitions, save/load, and test launches)
	if not GameManager.current_map_id.is_empty():
		map_id = GameManager.current_map_id

	# Camera setup — follow the player
	_orbit_camera.set_follow_target(_player)

	# Restore player position from save if returning
	if GameManager.party:
		var saved_pos: Vector3 = _get_saved_position()
		DebugLogger.log_info("Saved position: %s" % saved_pos, "Overworld")
		if saved_pos != Vector3.ZERO:
			_player.global_position = saved_pos
			DebugLogger.log_info("Restored player to: %s" % saved_pos, "Overworld")

	DebugLogger.log_info("Player starting at: %s" % _player.global_position, "Overworld")

	EventBus.gold_changed.connect(_update_hud_gold)
	EventBus.location_prompt_visible.connect(_on_location_prompt)
	EventBus.show_message.connect(_show_message)
	_update_hud_gold(GameManager.gold)
	_hud_location_label.text = ""

	# Setup message label if it doesn't exist
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

	# Party HUD (character cards: portrait, HP, MP)
	_party_hud = HBoxContainer.new()
	_party_hud.set_script(_PARTY_HUD_SCRIPT)
	$UI/HUD.add_child(_party_hud)

	# Track current map in GameManager
	GameManager.current_map_id = map_id

	# Start overworld music and ambient
	AudioManager.play_music("overworld")
	AudioManager.play_ambient("forest")

	# Load map data and build the world
	_map_data = MapDatabase.get_map(map_id)
	if _map_data:
		GameManager.current_location_name = _map_data.display_name if not _map_data.display_name.is_empty() else map_id.capitalize()

		if use_heightmap_terrain:
			# New heightmap terrain system
			_build_heightmap_terrain()
		else:
			# Legacy GridMap terrain
			GameManager.current_heightmap_data = null
			var cached: GridMap = MapCache.get_terrain(map_id)
			if cached:
				add_child(cached)
				_terrain_grid = cached
				DebugLogger.log_info("Using cached terrain for map: %s" % map_id, "Overworld")
			else:
				_terrain_grid = MapLoader.build_terrain(_map_data, self)
		# Scene-based maps have content baked into the .tscn — skip legacy element spawning.
		# Legacy GridMap maps still use MapLoader.spawn_elements for buildings/NPCs/enemies.
		var enemies_node := Node3D.new()
		enemies_node.name = "Enemies"
		add_child(enemies_node)
		var chests_node := Node3D.new()
		chests_node.name = "Chests"
		add_child(chests_node)
		var is_scene_based: bool = use_heightmap_terrain and _terrain_node != null
		if not is_scene_based:
			MapLoader.spawn_elements(_map_data, self, _location_markers, enemies_node, chests_node)
		# Spawn connection markers from MapData (legacy/procedural maps only).
		# Scene-based maps place ConnectionMarker nodes directly in the .tscn.
		_connection_markers = Node3D.new()
		_connection_markers.name = "ConnectionMarkers"
		add_child(_connection_markers)
		if not is_scene_based:
			MapLoader.spawn_connections(_map_data, _connection_markers)

		# Ground all elements to terrain height when using heightmap
		if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
			if not is_scene_based:
				_ground_elements_to_terrain(_location_markers)
				_ground_elements_to_terrain(enemies_node, 2.0)
				_ground_elements_to_terrain(chests_node)
			_ground_elements_to_terrain(_connection_markers)
			# Wire up terrain height source for NPCs and enemies (enables grounding + NavMesh)
			if not is_scene_based:
				_wire_terrain_sources(self)
				_wire_terrain_sources(enemies_node)

		# Preload terrain for adjacent maps in background
		if not use_heightmap_terrain:
			MapCache.preload_adjacent.call_deferred(map_id)
	else:
		DebugLogger.log_error("Map not found: %s" % map_id, "Overworld")

	# Restore camera orientation from save
	var saved_cam: Variant = GameManager.get_flag("camera_state", {})
	if saved_cam is Dictionary and not saved_cam.is_empty():
		_orbit_camera.restore_state(saved_cam)

	# Restore and unpause day/night cycle
	DayNightCycle.restore_state()
	DayNightCycle.paused = false

	# Snap camera to player immediately, then allow smooth follow
	_orbit_camera.global_position = _player.global_position

	# Auto-save on entry
	SaveManager.auto_save()

	# Camera occlusion — fade objects between camera and player
	var occlusion := CameraOcclusion.new()
	occlusion.camera = _orbit_camera
	occlusion.player = _player
	add_child(occlusion)

	# Enable enemy detection after scene is fully loaded and player is positioned
	_enable_enemy_detection()


func _check_battle_bg_preload() -> void:
	## Preloads the battle background when the player is near a battle area.
	var player_pos: Vector3 = _player.global_position
	var best_name: String = ""
	var best_pos: Vector3 = Vector3.ZERO
	var best_rot: float = 0.0
	var best_dist: float = INF

	# Check legacy BattleAreaData from MapData
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

	# Check scene-based BattleArea3D nodes
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
		# Player left all preload zones — clear preloaded data
		if not _preloaded_area_name.is_empty():
			GameManager.preloaded_battle_bg = null
			_preloaded_area_name = ""
		return

	# Already preloaded for this area
	if _preloaded_area_name == best_name:
		return

	# Preload battle background for this area
	var heightmap_data: HeightmapData = GameManager.current_heightmap_data as HeightmapData
	if not heightmap_data:
		return

	# Ground arena center to terrain height
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


func _build_heightmap_terrain() -> void:
	## Builds heightmap terrain from either a scene file or procedural generation.
	## MapData.map_scene_path takes priority over the exported map_scene_path property.
	var scene_path: String = map_scene_path
	if _map_data and not _map_data.map_scene_path.is_empty():
		scene_path = _map_data.map_scene_path
	if scene_path != "" and ResourceLoader.exists(scene_path):
		map_scene_path = scene_path  # sync so _build_scene_based_terrain reads the right path
		_build_scene_based_terrain()
	else:
		_build_procedural_terrain()


func _build_scene_based_terrain() -> void:
	## Loads a baked map .tscn scene containing HeightmapTerrain3D + PropScatterZone3D nodes.
	## No streaming or TerrainManager needed — everything is already in the scene.
	var scene: PackedScene = load(map_scene_path) as PackedScene
	if not scene:
		DebugLogger.log_error("Failed to load map scene: %s" % map_scene_path, "Overworld")
		_build_procedural_terrain()
		return

	_map_scene_root = scene.instantiate() as Node3D
	if not _map_scene_root:
		DebugLogger.log_error("Map scene is not a Node3D: %s" % map_scene_path, "Overworld")
		_build_procedural_terrain()
		return
	add_child(_map_scene_root)

	# Find HeightmapTerrain3D — chunks are baked into the scene and visible at runtime
	_terrain_node = _find_child_of_type(_map_scene_root, "HeightmapTerrain3D") as HeightmapTerrain3D
	if not _terrain_node or not _terrain_node.heightmap_data:
		DebugLogger.log_error("Map scene has no HeightmapTerrain3D with data: %s" % map_scene_path, "Overworld")
		_build_procedural_terrain()
		return

	GameManager.current_heightmap_data = _terrain_node.heightmap_data

	# Ground player to spawn position
	var spawn_pos: Vector3 = _map_data.player_spawn if _map_data else Vector3.ZERO
	spawn_pos.y = _get_terrain_height(spawn_pos) + 2.0
	_player.global_position = spawn_pos

	DebugLogger.log_info("Loaded scene-based map: %s (%dx%d)" % [
		map_scene_path, _terrain_node.heightmap_data.width, _terrain_node.heightmap_data.height
	], "Overworld")


func _build_procedural_terrain() -> void:
	## Generates heightmap terrain using biome-driven procedural generation.
	# Size the heightmap to match map data dimensions (add 1 for vertex grid)
	var hw: int = _map_data.grid_width + 1 if _map_data else 129
	var hh: int = _map_data.grid_height + 1 if _map_data else 81
	var terrain_seed: int = _map_data.decoration_seed if _map_data else 42
	var heightmap_data = _BiomeHeightmapGenerator.generate(hw, hh, terrain_seed)
	GameManager.current_heightmap_data = heightmap_data
	var spawn_pos: Vector3 = _map_data.player_spawn if _map_data else Vector3.ZERO
	_player.global_position = spawn_pos

	_terrain_manager = _TerrainManager.new()
	_terrain_manager.view_distance = 3
	_terrain_manager.unload_distance = heightmap_data.get_chunk_count_x() + 1  # never unload
	_terrain_manager._data = heightmap_data
	add_child(_terrain_manager)
	_terrain_manager.loading_complete.connect(_on_terrain_loading_complete)
	_terrain_manager.loading_progress.connect(_on_terrain_loading_progress)
	_show_loading_screen(heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z())
	_terrain_manager.preload_all(_player)

	# Spawn water bodies from data
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

	# Spawn river bodies from generated river paths
	var river_paths: Array = heightmap_data.rivers
	for ri in range(river_paths.size()):
		var rp = river_paths[ri]
		var river_body: MeshInstance3D = _RiverBody.new()
		river_body.setup(rp)
		add_child(river_body)
	if not river_paths.is_empty():
		DebugLogger.log_info("Spawned %d rivers" % river_paths.size(), "Overworld")

	# Spawn placed structures
	if not heightmap_data.structures.is_empty():
		var struct_mgr = _StructureManager.new()
		struct_mgr.build(heightmap_data)
		add_child(struct_mgr)
		DebugLogger.log_info("Placed %d structures" % heightmap_data.structures.size(), "Overworld")

	DebugLogger.log_info("Built procedural terrain: %dx%d, %d chunks" % [
		heightmap_data.width, heightmap_data.height,
		heightmap_data.get_chunk_count_x() * heightmap_data.get_chunk_count_z()
	], "Overworld")


func _find_child_of_type(node: Node, type_name: String) -> Node:
	## Recursively finds the first child matching the given class name.
	if node.get_class() == type_name or (node.get_script() and node.get_script().get_global_name() == type_name):
		return node
	for i in range(node.get_child_count()):
		var found: Node = _find_child_of_type(node.get_child(i), type_name)
		if found:
			return found
	return null


func _find_children_of_type(node: Node, type_name: String) -> Array:
	## Recursively finds all children matching the given class name.
	var results: Array = []
	if node.get_script() and node.get_script().get_global_name() == type_name:
		results.append(node)
	for i in range(node.get_child_count()):
		results.append_array(_find_children_of_type(node.get_child(i), type_name))
	return results


func _get_terrain_height(world_pos: Vector3) -> float:
	## Returns terrain height at a world-space XZ position.
	## Works for both scene-based (_terrain_node) and procedural (_terrain_manager) maps.
	if _terrain_node and _terrain_node.heightmap_data:
		return _terrain_node.get_height_at_world(world_pos)
	if _terrain_manager:
		return _terrain_manager.get_height_at_world(world_pos)
	return 0.0


func _ground_elements_to_terrain(parent: Node3D, y_offset: float = 0.0) -> void:
	## Adjusts Y position of all children to sit on the terrain surface.
	for i in range(parent.get_child_count()):
		var child: Node3D = parent.get_child(i) as Node3D
		if child:
			_ground_node_to_terrain(child, y_offset)


func _ground_node_to_terrain(node: Node3D, y_offset: float = 0.0) -> void:
	## Sets a node's Y position to the terrain height at its XZ position.
	var height: float = _get_terrain_height(node.position)
	node.position.y = height + y_offset


func _wire_terrain_sources(parent: Node3D) -> void:
	## Assigns terrain height source to all children that support it (NPCs, enemies).
	var height_source: Node = _terrain_node if _terrain_node else _terrain_manager
	for i in range(parent.get_child_count()):
		var child: Node = parent.get_child(i)
		if child.has_method("set_terrain_height_source"):
			child.set_terrain_height_source(height_source)
			if child is Node3D:
				_ground_node_to_terrain(child as Node3D)


func _process(delta: float) -> void:
	# Handle message display timer
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_hide_message()

	# Periodically check if player is near a battle area and preload the background
	if use_heightmap_terrain and _map_data and (_terrain_node != null or _terrain_manager != null):
		_preload_check_timer += delta
		if _preload_check_timer >= _PRELOAD_CHECK_INTERVAL:
			_preload_check_timer = 0.0
			_check_battle_bg_preload()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if _fast_travel_menu.visible:
			_fast_travel_menu._on_cancel()
		else:
			_toggle_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fast_travel"):
		_open_fast_travel_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_inventory"):
		# Save position before opening inventory
		_save_current_position()
		SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_quest_log"):
		_save_current_position()
		SceneManager.push_scene("res://scenes/menus/quest_log_ui.tscn")
		get_viewport().set_input_as_handled()


func receive_data(data: Dictionary) -> void:
	## Called by SceneManager after returning from another scene or arriving via map transition.
	# Refresh party HUD (HP/MP may have changed in battle, shop, dialogue, etc.)
	if _party_hud:
		_party_hud.rebuild()

	# Handle spawn position from map connection transitions
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
		# Push player away from any nearby enemies to prevent immediate re-engagement
		_push_player_from_enemies()
		# Re-enable player input after battle
		_player.enable_input(true)
		# Auto-save after battle (with new position)
		SaveManager.auto_save()
		# Re-enable enemy detection after player is safely positioned
		_enable_enemy_detection()
		# Apply battle cooldown to all enemies
		_apply_battle_cooldown()


func _get_saved_position() -> Vector3:
	## Reads saved position, handling both old Vector2 and new Vector3 formats.
	var saved: Variant = GameManager.get_flag("overworld_position", Vector3.ZERO)
	if saved is Vector3:
		return saved
	if saved is Vector2:
		# Legacy 2D position — convert using pixel scale
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
	## Displays a temporary message to the player.
	if not _message_label:
		DebugLogger.log_warn("No message label to display: %s" % message, "Overworld")
		return

	_current_message = message
	_message_label.text = message
	_message_label.visible = true
	_message_timer = MESSAGE_DISPLAY_TIME
	DebugLogger.log_info("Showing message: %s" % message, "Overworld")


func _hide_message() -> void:
	## Hides the current message.
	if _message_label:
		_message_label.visible = false
	_current_message = ""


func _save_current_position() -> void:
	## Saves the player's current position and camera state so they can be restored when returning.
	if _player:
		GameManager.set_flag("overworld_position", _player.global_position)
		GameManager.set_flag("camera_state", _orbit_camera.get_state())
		DayNightCycle.save_state()
		DebugLogger.log_info("Saved current position: %s" % _player.global_position, "Overworld")


func _open_fast_travel_menu() -> void:
	## Opens the fast travel menu with all available locations.
	# Gather all LocationData from markers
	var all_locations: Array[LocationData] = []
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data"):
			all_locations.append(marker.get_location_data())

	_fast_travel_menu.open_menu(all_locations)
	_fast_travel_menu.location_selected.connect(_on_fast_travel_selected, CONNECT_ONE_SHOT)
	_fast_travel_menu.visibility_changed.connect(_on_fast_travel_menu_visibility_changed, CONNECT_ONE_SHOT)
	_player.enable_input(false)


func _on_fast_travel_menu_visibility_changed() -> void:
	## Re-enable input when fast travel menu is closed (if not traveling)
	if not _fast_travel_menu.visible:
		_player.enable_input(true)


func _on_fast_travel_selected(location: LocationData) -> void:
	## Teleports player to the selected fast travel location.
	# Find the marker node with this location
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data") and marker.get_location_data() == location:
			# Teleport player to marker
			_player.global_position = marker.global_position
			_player.enable_input(true)

			# Save new position and camera state
			GameManager.set_flag("overworld_position", _player.global_position)
			GameManager.set_flag("camera_state", _orbit_camera.get_state())
			SaveManager.auto_save()
			break


func _enable_enemy_detection() -> void:
	## Enables battle detection on all enemies after player is safely positioned.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and enemy.has_method("enable_detection"):
			enemy.enable_detection()
	DebugLogger.log_info("Enabled detection for %d enemies" % enemies.size(), "Overworld")


func _push_player_from_enemies() -> void:
	## Moves player away from any nearby enemies to prevent immediate re-engagement after battle.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	var player_pos: Vector3 = _player.global_position
	var closest_enemy: Node = null
	var closest_distance: float = INF

	# Find closest enemy
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and is_instance_valid(enemy) and enemy is Node3D:
			var distance: float = player_pos.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy

	# If player is too close to an enemy, push them away
	if closest_enemy and closest_distance < Constants.SAFE_DISTANCE:
		var push_direction: Vector3 = (player_pos - closest_enemy.global_position).normalized()
		push_direction.y = 0.0  # Keep on ground plane
		if push_direction.length() < 0.1:  # Handle case where positions are identical
			push_direction = Vector3.RIGHT  # Default push to the right

		var new_position: Vector3 = closest_enemy.global_position + (push_direction.normalized() * Constants.PUSH_DISTANCE)
		if use_heightmap_terrain and (_terrain_node != null or _terrain_manager != null):
			new_position.y = _get_terrain_height(new_position) + 1.0
		else:
			new_position.y = 0.0
		_player.global_position = new_position

		# Update saved position (camera orientation preserved)
		GameManager.set_flag("overworld_position", _player.global_position)
		GameManager.set_flag("camera_state", _orbit_camera.get_state())

		DebugLogger.log_info("Pushed player away from enemy (distance was %.1f)" % closest_distance, "Overworld")


func _apply_battle_cooldown() -> void:
	## Disables battle triggers on all enemies for a short period.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for ei in range(enemies.size()):
		var e: Node = enemies[ei]
		if e.has_method("disable_battles_temporarily"):
			e.disable_battles_temporarily()

	# Re-enable after cooldown
	await get_tree().create_timer(BATTLE_COOLDOWN_TIME).timeout

	for ri in range(enemies.size()):
		var re: Node = enemies[ri]
		if re and is_instance_valid(re) and re.has_method("re_enable_battles"):
			re.re_enable_battles()

	DebugLogger.log_info("Battle cooldown ended - enemies can trigger battles again", "Overworld")


func _notification(what: int) -> void:
	## Cache terrain before this scene is freed (replace_scene / main menu).
	## Does NOT fire on push_scene (scene is stashed, not freed).
	if what == NOTIFICATION_PREDELETE:
		if not use_heightmap_terrain and _terrain_grid and is_instance_valid(_terrain_grid):
			MapCache.store_terrain(map_id, _terrain_grid)
			_terrain_grid = null


# === Pause Menu ===

func _toggle_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.queue_free()
		_pause_menu_instance = null
		return
	_save_current_position()
	_pause_menu_instance = _PAUSE_SCENE.instantiate()
	_ui.add_child(_pause_menu_instance)
	_pause_menu_instance.resume_requested.connect(_toggle_pause_menu)
	_pause_menu_instance.save_requested.connect(_open_save_screen)
	_pause_menu_instance.load_requested.connect(_open_load_screen)
	_pause_menu_instance.quest_log_requested.connect(_open_quest_log)
	_pause_menu_instance.settings_requested.connect(_open_settings)
	_pause_menu_instance.main_menu_requested.connect(_go_to_main_menu)


func _open_save_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "save"})


func _open_load_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})


func _open_quest_log() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/quest_log_ui.tscn")


func _open_settings() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/settings/settings_menu.tscn")


func _go_to_main_menu() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")


# ---------------------------------------------------------------------------
# Loading screen
# ---------------------------------------------------------------------------

var _loading_overlay: CanvasLayer = null
var _loading_bar: ProgressBar = null
var _loading_label: Label = null
var _loading_chunk_total: int = 0


func _show_loading_screen(total_chunks: int) -> void:
	_loading_chunk_total = total_chunks
	_player.visible = false  # hide player until terrain is ready

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
	# Ground player now that terrain exists
	var spawn_pos: Vector3 = _player.global_position
	if _terrain_manager:
		var ground_y: float = _terrain_manager.get_height_at_world(spawn_pos) + 2.0
		_player.global_position = Vector3(spawn_pos.x, ground_y, spawn_pos.z)
		_orbit_camera.global_position = _player.global_position

	_player.visible = true

	if _loading_overlay:
		_loading_overlay.queue_free()
		_loading_overlay = null
		_loading_bar = null
		_loading_label = null
