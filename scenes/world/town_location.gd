extends Area2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0

func try_enter() -> void:
	var npcs: Array[String] = [
		"Blacksmith - Weapon upgrades",
		"Merchant - Buy and sell items",
		"Innkeeper - Rest and save",
		"Priest - Healing"
	]
	EventBus.show_message.emit("Available NPCs:\n" + "\n".join(npcs))
