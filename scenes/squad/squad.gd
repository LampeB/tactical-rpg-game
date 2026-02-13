extends Control

func _ready():
	$VBox/TopBar/BackButton.pressed.connect(_on_back)
	DebugLogger.log_info("Squad scene ready", "Squad")

func _unhandled_input(event: InputEvent):
	if event.is_action_pressed("escape"):
		_on_back()

func _on_back():
	SceneManager.pop_scene()
