extends Control

func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/NewGameButton.pressed.connect(_on_new_game_pressed)
	$VBoxContainer/InventoryButton.pressed.connect(_on_inventory_pressed)
	$VBoxContainer/SquadButton.pressed.connect(_on_squad_pressed)
	$VBoxContainer/TreeEditorButton.pressed.connect(_on_tree_editor_pressed)
	$VBoxContainer/SettingsButton.pressed.connect(_on_settings_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	var title = $VBoxContainer/Title
	title.add_theme_font_size_override("font_size", Constants.FONT_SIZE_MENU_TITLE)

	_update_button_states()

func _update_button_states():
	var has_game := GameManager.is_game_started
	var has_save := SaveManager.has_save()
	$VBoxContainer/InventoryButton.disabled = not has_game
	$VBoxContainer/SquadButton.disabled = not has_game
	if has_game or has_save:
		$VBoxContainer/PlayButton.text = "Continue"

func _on_play_pressed():
	if not GameManager.is_game_started:
		if SaveManager.has_save():
			SaveManager.load_game()
			SaveManager.start_playtime_tracking()
		else:
			GameManager.new_game()
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/world/overworld.tscn")

func _on_new_game_pressed():
	SaveManager.delete_save()
	GameManager.new_game()
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/world/overworld.tscn")

func _on_inventory_pressed():
	SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")

func _on_squad_pressed():
	SceneManager.push_scene("res://scenes/squad/squad.tscn")

func _on_tree_editor_pressed():
	SceneManager.push_scene("res://scenes/tree_editor/tree_editor.tscn")

func _on_settings_pressed():
	SceneManager.push_scene("res://scenes/settings/settings_menu.tscn")

func _on_quit_pressed():
	get_tree().quit()
