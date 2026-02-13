extends Control

func _ready():
	$VBoxContainer/PlayButton.pressed.connect(_on_play_pressed)
	$VBoxContainer/InventoryButton.pressed.connect(_on_inventory_pressed)
	$VBoxContainer/SquadButton.pressed.connect(_on_squad_pressed)
	$VBoxContainer/QuitButton.pressed.connect(_on_quit_pressed)

	var title = $VBoxContainer/Title
	title.add_theme_font_size_override("font_size", 48)

	# Disable inventory/squad if no game has been started
	_update_button_states()

func _update_button_states():
	var has_game := GameManager.is_game_started
	$VBoxContainer/InventoryButton.disabled = not has_game
	$VBoxContainer/SquadButton.disabled = not has_game
	if has_game:
		$VBoxContainer/PlayButton.text = "Continue"

func _on_play_pressed():
	if not GameManager.is_game_started:
		GameManager.new_game()
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/world/world.tscn")

func _on_inventory_pressed():
	SceneManager.push_scene("res://scenes/inventory/inventory.tscn")

func _on_squad_pressed():
	SceneManager.push_scene("res://scenes/squad/squad.tscn")

func _on_quit_pressed():
	get_tree().quit()
