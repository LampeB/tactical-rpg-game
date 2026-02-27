extends Area2D

func _ready() -> void:
	collision_layer = 4
	collision_mask = 0

func try_enter() -> void:
	if not GameManager.party:
		return

	for char_id in GameManager.party.roster.keys():
		var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
		var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
		var max_mp: int = GameManager.party.get_max_mp(char_id, tree)
		GameManager.party.set_current_hp(char_id, max_hp, tree)
		GameManager.party.set_current_mp(char_id, max_mp, tree)

	EventBus.show_message.emit("The lake's waters restore your party to full health!")
	SaveManager.auto_save()
