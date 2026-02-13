extends Node2D

func _ready():
	$UI/Controls/InventoryButton.pressed.connect(_on_inventory)
	$UI/Controls/SquadButton.pressed.connect(_on_squad)
	$UI/Controls/MenuButton.pressed.connect(_on_menu)

	# Update gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	_on_gold_changed(GameManager.gold)

	DebugLogger.log_info("World scene ready", "World")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("open_inventory"):
		_on_inventory()
	elif event.is_action_pressed("escape"):
		_on_menu()

func _on_inventory():
	SceneManager.push_scene("res://scenes/inventory/inventory.tscn")

func _on_squad():
	SceneManager.push_scene("res://scenes/squad/squad.tscn")

func _on_menu():
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")

func _on_gold_changed(new_gold: int):
	$UI/TopBar/GoldLabel.text = "Gold: %d" % new_gold
