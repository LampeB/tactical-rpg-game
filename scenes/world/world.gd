extends Node2D

func _ready() -> void:
	$UI/Controls/BattleButton.pressed.connect(_on_battle)
	$UI/Controls/CharacterButton.pressed.connect(_on_character)
	$UI/Controls/SquadButton.pressed.connect(_on_squad)
	$UI/Controls/MenuButton.pressed.connect(_on_menu)

	# Update gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(GameManager.gold)

	# Auto-save when entering the world scene
	if GameManager.is_game_started:
		SaveManager.auto_save()

	DebugLogger.log_info("World scene ready", "World")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("open_inventory"):
		_on_character()
	elif event.is_action_pressed("escape"):
		_on_menu()

func _on_battle() -> void:
	var encounter: EncounterData = load("res://data/encounters/encounter_slimes.tres") as EncounterData
	if encounter:
		SceneManager.push_scene("res://scenes/battle/battle.tscn", {
			"encounter": encounter,
			"grid_inventories": GameManager.party.grid_inventories if GameManager.party else {},
		})

func _on_character() -> void:
	SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")

func _on_squad() -> void:
	SceneManager.push_scene("res://scenes/squad/squad.tscn")

func _on_menu() -> void:
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")

func _on_gold_changed(new_gold: int) -> void:
	$UI/TopBar/GoldLabel.text = "Gold: %d" % new_gold
