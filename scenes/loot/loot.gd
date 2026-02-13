extends Control

func _ready():
	$VBox/ContinueButton.pressed.connect(_on_continue)
	DebugLogger.log_info("Loot scene ready", "Loot")

func receive_data(data: Dictionary):
	if data.has("items"):
		var items: Array = data["items"]
		$VBox/Content.text = "Found %d item(s)!\n(Loot collection coming in Sprint 6)" % items.size()

func _on_continue():
	EventBus.loot_screen_closed.emit()
	SceneManager.pop_scene()
