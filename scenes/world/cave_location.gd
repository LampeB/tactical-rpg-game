extends Area2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0

func try_enter() -> void:
	var flags_to_clear: Array = []
	for flag in GameManager.story_flags.keys():
		if flag.begins_with("defeated_enemy_"):
			flags_to_clear.append(flag)

	for flag in flags_to_clear:
		GameManager.story_flags.erase(flag)

	SaveManager.auto_save()
	EventBus.show_message.emit("Cave cleared! Enemies will respawn.")
