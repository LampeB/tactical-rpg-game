extends Node2D
## Main overworld scene controller.

@onready var _player: CharacterBody2D = $Player
@onready var _location_markers: Node2D = $LocationMarkers
@onready var _camera: Camera2D = $Camera2D
@onready var _fast_travel_menu: PanelContainer = $UI/FastTravelMenu
@onready var _hud_gold_label: Label = $UI/HUD/GoldLabel
@onready var _hud_location_label: Label = $UI/HUD/LocationLabel


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
	_update_hud_gold(GameManager.gold)
	_hud_location_label.text = ""

	# Auto-save on entry
	SaveManager.save_game()
	DebugLogger.log_info("Auto-saved at: %s" % _player.global_position, "Overworld")

	# Set camera to follow player
	_camera.position_smoothing_enabled = false
	_camera.global_position = _player.global_position
	await get_tree().process_frame
	_camera.position_smoothing_enabled = true


func _physics_process(delta: float) -> void:
	# Camera follows player
	_camera.global_position = _player.global_position


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		# Open main menu
		SceneManager.push_scene("res://scenes/main_menu/main_menu.tscn")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fast_travel"):
		_open_fast_travel_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_inventory"):
		SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")
		get_viewport().set_input_as_handled()


func receive_data(data: Dictionary) -> void:
	## Called by SceneManager after returning from another scene.
	if data.get("from_battle", false):
		# Re-enable player input after battle
		_player.enable_input(true)
		# Auto-save after battle
		SaveManager.save_game()


func _update_hud_gold(gold: int) -> void:
	_hud_gold_label.text = "Gold: %d" % gold


func _on_location_prompt(visible: bool, location_name: String) -> void:
	if visible:
		_hud_location_label.text = "[E] Enter: %s" % location_name
	else:
		_hud_location_label.text = ""


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
			SaveManager.save_game()
			break
