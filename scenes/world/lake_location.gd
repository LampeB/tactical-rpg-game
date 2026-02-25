extends Area2D

func _ready():
	collision_layer = 4
	collision_mask = 0

func try_enter():
	if not GameManager.party:
		return
	
	for char_id in GameManager.party.roster.keys():
		var tree = PassiveTreeDatabase.get_passive_tree()
		var max_hp = GameManager.party.get_max_hp(char_id, tree)
		var max_mp = GameManager.party.get_max_mp(char_id, tree)
		GameManager.party.set_current_hp(char_id, max_hp, tree)
		GameManager.party.set_current_mp(char_id, max_mp, tree)
	
	EventBus.show_message.emit("The lake's waters restore your party to full health!")
	SaveManager.auto_save()
