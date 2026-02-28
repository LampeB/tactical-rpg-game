extends Node3D
## Quick test scene for 3D migration Phase 1.
## Spawns CSG characters, a ground plane, and the orbit camera.


func _ready() -> void:
	# Ground plane
	var ground := CSGBox3D.new()
	ground.name = "Ground"
	ground.size = Vector3(30, 0.1, 30)
	ground.position = Vector3(0, -0.05, 0)
	var ground_mat := StandardMaterial3D.new()
	ground_mat.albedo_color = Color(0.35, 0.55, 0.25)
	ground.material = ground_mat
	add_child(ground)

	# Spawn party characters
	var classes := ["Warrior", "Mage", "Rogue"]
	for i in classes.size():
		var char_data := CharacterData.new()
		char_data.display_name = classes[i]
		char_data.character_class = classes[i]
		var model := CSGCharacterFactory.create_from_character(char_data)
		model.position = Vector3((i - 1) * 3.0, 0, -2)
		add_child(model)

	# Spawn enemies
	var enemies_info := [
		{"id": "slime", "name": "Slime", "color": Color(0.2, 0.8, 0.2)},
		{"id": "goblin", "name": "Goblin", "color": Color(0.3, 0.6, 0.2)},
		{"id": "minotaur", "name": "Minotaur", "color": Color(0.5, 0.3, 0.15)},
	]
	for i in enemies_info.size():
		var enemy := EnemyData.new()
		enemy.id = enemies_info[i].id
		enemy.display_name = enemies_info[i].name
		enemy.model_color = enemies_info[i].color
		var model := CSGCharacterFactory.create_from_enemy(enemy)
		model.position = Vector3((i - 1) * 3.0, 0, 3)
		add_child(model)

	# Spawn an NPC
	var npc := NpcData.new()
	npc.display_name = "Merchant"
	npc.role = NpcData.NpcRole.SHOPKEEPER
	var npc_model := CSGCharacterFactory.create_from_npc(npc)
	npc_model.position = Vector3(6, 0, 0)
	add_child(npc_model)

	# Point the orbit camera at center
	var cam: OrbitCamera = $OrbitCamera
	if cam:
		cam.global_position = Vector3(0, 0, 0)
