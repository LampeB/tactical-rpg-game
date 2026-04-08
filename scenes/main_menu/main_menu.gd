extends Control

@onready var _confirm_dialog: ConfirmationDialog = $ConfirmNewGame


func _ready() -> void:
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/TreeEditorButton.pressed.connect(_on_tree_editor_pressed)
	$VBoxContainer/ItemEditorButton.pressed.connect(_on_item_editor_pressed)
	$VBoxContainer/NpcEditorButton.pressed.connect(_on_npc_editor_pressed)
	$VBoxContainer/BackpackEditorButton.pressed.connect(_on_backpack_editor_pressed)
	$VBoxContainer/MapEditorButton.pressed.connect(_on_map_editor_pressed)
	# Heightmap editor removed — use Godot's scene editor with @tool nodes instead
	$VBoxContainer/TweaksEditorButton.pressed.connect(_on_tweaks_editor_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	_confirm_dialog.confirmed.connect(_start_new_game)

	_update_button_states()
	AudioManager.play_music("main_menu")


func _notification(what: int) -> void:
	# Refresh button visibility when returning from settings (debug mode may have changed)
	if what == NOTIFICATION_VISIBILITY_CHANGED and is_visible_in_tree():
		_update_button_states()


func _update_button_states() -> void:
	var has_game := GameManager.is_game_started
	var has_save := SaveManager.has_any_save()
	$VBoxContainer/ContinueButton.visible = has_game or has_save
	$VBoxContainer/LoadGameButton.visible = has_save

	# Developer/editor buttons are only visible when debug mode is enabled in settings
	var debug: bool = DisplayManager.debug_mode
	$VBoxContainer/TreeEditorButton.visible = debug
	$VBoxContainer/ItemEditorButton.visible = debug
	$VBoxContainer/NpcEditorButton.visible = debug
	$VBoxContainer/BackpackEditorButton.visible = debug
	$VBoxContainer/MapEditorButton.visible = debug
	$VBoxContainer/TweaksEditorButton.visible = debug
	$VBoxContainer/DebugSpacer.visible = debug


func _on_continue_pressed() -> void:
	if GameManager.is_game_started:
		SceneManager.clear_stack()
		SceneManager.replace_scene(_resolve_map_scene())
	else:
		SaveManager.load_most_recent()
		SaveManager.start_playtime_tracking()
		SceneManager.clear_stack()
		SceneManager.replace_scene(_resolve_map_scene())


func _on_load_game_pressed() -> void:
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})


func _on_new_game_pressed() -> void:
	if SaveManager.has_any_save():
		_confirm_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameManager.new_game()
	GameManager.current_map_id = "starter_town"
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/world/local_map.tscn")


func _resolve_map_scene() -> String:
	## Returns the correct scene path for the current map (overworld vs local).
	var target_map: MapData = MapDatabase.get_map(GameManager.current_map_id)
	if target_map and target_map.is_overworld:
		return "res://scenes/world/overworld.tscn"
	if target_map:
		return "res://scenes/world/local_map.tscn"
	return "res://scenes/world/overworld.tscn"  # fallback


func _on_tree_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/tree_editor/tree_editor.tscn")


func _on_item_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/item_editor/item_editor.tscn")


func _on_npc_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/npc_editor/npc_editor.tscn")


func _on_backpack_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/backpack_editor/backpack_editor.tscn")


func _on_map_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/map_editor/map_editor.tscn")




func _on_tweaks_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/debug/tweaks_editor.tscn")


func _on_settings_pressed() -> void:
	SceneManager.push_scene("res://scenes/settings/settings_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
