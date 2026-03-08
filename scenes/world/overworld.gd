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

const BATTLE_COOLDOWN_TIME: float = 3.0  ## Seconds of immunity after battle
const MESSAGE_DISPLAY_TIME: float = 3.0  ## Seconds to show messages
const _PAUSE_SCENE := preload("res://scenes/menus/pause_menu.tscn")
const _PARTY_HUD_SCRIPT := preload("res://scenes/world/party_hud.gd")

@export var map_id: String = "overworld"
var _map_data: MapData
var _connection_markers: Node3D

var _message_timer: float = 0.0
var _current_message: String = ""
var _pause_menu_instance: Control = null
var _party_hud: HBoxContainer = null
var _terrain_grid: GridMap = null


func _ready() -> void:
	# Use current map from GameManager if game is in progress (handles map transitions + save/load)
	if GameManager.is_game_started:
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

	# Load map data and build the world
	_map_data = MapDatabase.get_map(map_id)
	if _map_data:
		GameManager.current_location_name = _map_data.display_name if not _map_data.display_name.is_empty() else map_id.capitalize()
		# Use cached terrain if available, otherwise build from scratch
		var cached: GridMap = MapCache.get_terrain(map_id)
		if cached:
			add_child(cached)
			_terrain_grid = cached
			DebugLogger.log_info("Using cached terrain for map: %s" % map_id, "Overworld")
		else:
			_terrain_grid = MapLoader.build_terrain(_map_data, self)
		# Create parent nodes for spawned elements
		var enemies_node := Node3D.new()
		enemies_node.name = "Enemies"
		add_child(enemies_node)
		var chests_node := Node3D.new()
		chests_node.name = "Chests"
		add_child(chests_node)
		MapLoader.spawn_elements(_map_data, self, _location_markers, enemies_node, chests_node)
		# Spawn connection markers
		_connection_markers = Node3D.new()
		_connection_markers.name = "ConnectionMarkers"
		add_child(_connection_markers)
		MapLoader.spawn_connections(_map_data, _connection_markers)
		# Preload terrain for adjacent maps in background
		MapCache.preload_adjacent.call_deferred(map_id)
	else:
		DebugLogger.log_error("Map not found: %s" % map_id, "Overworld")

	# Restore camera orientation from save
	var saved_cam: Variant = GameManager.get_flag("camera_state", {})
	if saved_cam is Dictionary and not saved_cam.is_empty():
		_orbit_camera.restore_state(saved_cam)

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


func _process(delta: float) -> void:
	# Handle message display timer
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_hide_message()


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
		if re and is_instance_valid(re) and "_can_trigger_battle" in re:
			re._can_trigger_battle = true

	DebugLogger.log_info("Battle cooldown ended - enemies can trigger battles again", "Overworld")


func _notification(what: int) -> void:
	## Cache terrain before this scene is freed (replace_scene / main menu).
	## Does NOT fire on push_scene (scene is stashed, not freed).
	if what == NOTIFICATION_PREDELETE:
		if _terrain_grid and is_instance_valid(_terrain_grid):
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


