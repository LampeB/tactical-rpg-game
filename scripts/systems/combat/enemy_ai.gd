class_name EnemyAI
extends RefCounted
## Simple AI for enemy action selection during combat.


static func choose_action(
	enemy: CombatEntity,
	player_targets: Array,
) -> Dictionary:
	## Returns {"action": CombatAction, "skill": SkillData or null, "targets": Array[CombatEntity]}

	var alive_targets: Array = []
	for i in range(player_targets.size()):
		var t: CombatEntity = player_targets[i]
		if not t.is_dead:
			alive_targets.append(t)

	if alive_targets.is_empty():
		return {"action": Enums.CombatAction.DEFEND, "skill": null, "targets": []}

	# Check available skills
	var available: Array = enemy.get_available_skills()
	var usable_skills: Array = []
	for i in range(available.size()):
		var skill: SkillData = available[i]
		if enemy.can_use_skill(skill):
			usable_skills.append(skill)

	# 60% chance to use a skill if available, 40% basic attack
	if not usable_skills.is_empty() and randf() < 0.6:
		var skill: SkillData = usable_skills[randi() % usable_skills.size()]
		var targets: Array = _select_targets(skill.target_type, enemy, alive_targets)
		return {"action": Enums.CombatAction.SKILL, "skill": skill, "targets": targets}

	# Basic attack on random target
	var target: CombatEntity = alive_targets[randi() % alive_targets.size()]
	return {"action": Enums.CombatAction.ATTACK, "skill": null, "targets": [target]}


static func _select_targets(
	target_type: Enums.TargetType,
	source: CombatEntity,
	alive_players: Array,
) -> Array:
	match target_type:
		Enums.TargetType.SINGLE_ENEMY:
			# For enemies, "enemy" means a player character
			return [alive_players[randi() % alive_players.size()]]
		Enums.TargetType.ALL_ENEMIES:
			return alive_players.duplicate()
		Enums.TargetType.SELF:
			return [source]
		Enums.TargetType.SINGLE_ALLY:
			return [source]  # Simple: just target self
		_:
			return [alive_players[randi() % alive_players.size()]]
