extends Node2D
## Main overworld scene controller.

@onready var _player: CharacterBody2D = $Player
@onready var _location_markers: Node2D = $LocationMarkers
@onready var _camera: Camera2D = $Camera2D
@onready var _ui: CanvasLayer = $UI
@onready var _fast_travel_menu: PanelContainer = $UI/FastTravelMenu
@onready var _hud_gold_label: Label = $UI/HUD/GoldLabel
@onready var _hud_location_label: Label = $UI/HUD/LocationLabel
@onready var _message_label: Label = $UI/HUD/MessageLabel if has_node("UI/HUD/MessageLabel") else null

const BATTLE_COOLDOWN_TIME: float = 3.0  ## Seconds of immunity after battle
const MESSAGE_DISPLAY_TIME: float = 3.0  ## Seconds to show messages
const _PAUSE_SCENE := preload("res://scenes/menus/pause_menu.tscn")

var _message_timer: float = 0.0
var _current_message: String = ""
var _pause_menu_instance: Control = null


func _ready() -> void:
	_camera.make_current()

	# Restore player position from save if returning
	if GameManager.party:
		var saved_pos: Vector2 = GameManager.get_flag("overworld_position", Vector2.ZERO)
		DebugLogger.log_info("Saved position: %s" % saved_pos, "Overworld")
		if saved_pos != Vector2.ZERO:
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
		_message_label.position = Vector2(0, -200)  # Above center
		_message_label.add_theme_font_size_override("font_size", 24)
		_message_label.add_theme_color_override("font_color", Color.YELLOW)
		_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_message_label.add_theme_constant_override("outline_size", 4)
		_message_label.visible = false
		$UI/HUD.add_child(_message_label)

	# Auto-save on entry
	GameManager.current_location_name = "Overworld"
	SaveManager.auto_save()
	DebugLogger.log_info("Auto-saved at: %s" % _player.global_position, "Overworld")

	# Set camera to follow player
	_camera.position_smoothing_enabled = false
	_camera.global_position = _player.global_position
	await get_tree().process_frame
	_camera.position_smoothing_enabled = true

	# Enable enemy detection after scene is fully loaded and player is positioned
	_enable_enemy_detection()


func _physics_process(_delta: float) -> void:
	# Camera follows player
	_camera.global_position = _player.global_position


func _process(delta: float) -> void:
	# Handle message display timer
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_hide_message()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
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


func receive_data(data: Dictionary) -> void:
	## Called by SceneManager after returning from another scene.
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


func _update_hud_gold(gold: int) -> void:
	_hud_gold_label.text = "Gold: %d" % gold


func _on_location_prompt(visible: bool, location_name: String) -> void:
	if visible:
		_hud_location_label.text = "[E] Enter: %s" % location_name
	else:
		_hud_location_label.text = ""


func _show_message(message: String) -> void:
	## Displays a temporary message to the player.
	if not _message_label:
		DebugLogger.log_warning("No message label to display: %s" % message, "Overworld")
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
	## Saves the player's current position so it can be restored when returning.
	if _player:
		GameManager.set_flag("overworld_position", _player.global_position)
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

			# Save new position
			GameManager.set_flag("overworld_position", _player.global_position)
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
	const SAFE_DISTANCE: float = 80.0  # Minimum distance from enemies
	const PUSH_DISTANCE: float = 100.0  # How far to push player

	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	var player_pos: Vector2 = _player.global_position
	var closest_enemy: Node = null
	var closest_distance: float = INF

	# Find closest enemy
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and is_instance_valid(enemy) and enemy is Node2D:
			var distance: float = player_pos.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy

	# If player is too close to an enemy, push them away
	if closest_enemy and closest_distance < SAFE_DISTANCE:
		var push_direction: Vector2 = (player_pos - closest_enemy.global_position).normalized()
		if push_direction.length() < 0.1:  # Handle case where positions are identical
			push_direction = Vector2(1, 0)  # Default push to the right

		var new_position: Vector2 = closest_enemy.global_position + (push_direction * PUSH_DISTANCE)
		_player.global_position = new_position

		# Update saved position
		GameManager.set_flag("overworld_position", _player.global_position)

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
	_pause_menu_instance.main_menu_requested.connect(_go_to_main_menu)


func _open_save_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "save"})


func _open_load_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})


func _go_to_main_menu() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")
