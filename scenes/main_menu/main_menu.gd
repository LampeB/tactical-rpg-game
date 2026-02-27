extends Control

@onready var _confirm_dialog: ConfirmationDialog = $ConfirmNewGame


func _ready() -> void:
	$Background.color = UIColors.BG_MAIN_MENU
	$VBoxContainer/ContinueButton.pressed.connect(_on_continue_pressed)
	$VBoxContainer/LoadGameButton.pressed.connect(_on_load_game_pressed)
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/InventoryButton.pressed.connect(_on_inventory_pressed)
	$VBoxContainer/SquadButton.pressed.connect(_on_squad_pressed)
	$VBoxContainer/TreeEditorButton.pressed.connect(_on_tree_editor_pressed)
	$VBoxContainer/ItemEditorButton.pressed.connect(_on_item_editor_pressed)
	$VBoxContainer/NpcEditorButton.pressed.connect(_on_npc_editor_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)
	_confirm_dialog.confirmed.connect(_start_new_game)

	var title: Label = $VBoxContainer/Title
	title.add_theme_font_size_override("font_size", Constants.FONT_SIZE_MENU_TITLE)

	_update_button_states()


func _update_button_states() -> void:
	var has_game := GameManager.is_game_started
	var has_save := SaveManager.has_any_save()
	$VBoxContainer/ContinueButton.visible = has_game or has_save
	$VBoxContainer/LoadGameButton.visible = has_save
	$VBoxContainer/InventoryButton.disabled = not has_game
	$VBoxContainer/SquadButton.disabled = not has_game


func _on_continue_pressed() -> void:
	if GameManager.is_game_started:
		# Already in session — just return to overworld
		SceneManager.clear_stack()
		SceneManager.replace_scene("res://scenes/world/overworld.tscn")
	else:
		SaveManager.load_most_recent()
		SaveManager.start_playtime_tracking()
		SceneManager.clear_stack()
		SceneManager.replace_scene("res://scenes/world/overworld.tscn")


func _on_load_game_pressed() -> void:
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})


func _on_new_game_pressed() -> void:
	if SaveManager.has_any_save():
		_confirm_dialog.popup_centered()
	else:
		_start_new_game()


func _start_new_game() -> void:
	GameManager.new_game()
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/world/overworld.tscn")


func _on_inventory_pressed() -> void:
	SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")


func _on_squad_pressed() -> void:
	SceneManager.push_scene("res://scenes/squad/squad.tscn")


func _on_tree_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/tree_editor/tree_editor.tscn")


func _on_item_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/item_editor/item_editor.tscn")


func _on_npc_editor_pressed() -> void:
	SceneManager.push_scene("res://scenes/npc_editor/npc_editor.tscn")


func _on_settings_pressed() -> void:
	SceneManager.push_scene("res://scenes/settings/settings_menu.tscn")


func _on_quit_pressed() -> void:
	get_tree().quit()
