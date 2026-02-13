extends Control

func _ready():
	$VBox/TopBar/BackButton.pressed.connect(_on_back)
	DebugLogger.log_info("Inventory scene ready", "Inventory")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("escape") or event.is_action_pressed("open_inventory"):
		_on_back()

func _on_back():
	SceneManager.pop_scene()
