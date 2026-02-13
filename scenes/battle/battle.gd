extends Control

var _encounter_data: EncounterData

func _ready():
	$VBox/FleeButton.pressed.connect(_on_flee)
	DebugLogger.log_info("Battle scene ready", "Battle")

func receive_data(data: Dictionary):
	if data.has("encounter"):
		_encounter_data = data["encounter"]
		$VBox/Title.text = "Battle: %s" % _encounter_data.display_name

func _on_flee():
	EventBus.combat_ended.emit(false)
	SceneManager.pop_scene()
