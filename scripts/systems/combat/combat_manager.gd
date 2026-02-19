class_name CombatManager
extends RefCounted
## Manages turn-based combat logic: turn order, action execution, win/lose.
## Pure logic — no UI. Emits signals for the battle scene to react to.
## NOTE: Cannot reference autoloads (EventBus, GameManager) because class_name
## scripts compile before autoloads are registered. Battle scene bridges to autoloads.

signal turn_ready(entity: CombatEntity)
signal action_resolved(results: Dictionary)
signal combat_finished(victory: bool)
signal status_ticked(entity: CombatEntity, damage: int, status_name: String)
signal status_expired(entity: CombatEntity, status_name: String)
signal entity_died(entity: CombatEntity)
signal log_message(text: String, color: Color)
signal passive_effect_triggered(source: CombatEntity, effect_id: String, value: int)

var encounter: EncounterData
var all_entities: Array = []  ## of CombatEntity
var player_entities: Array = []  ## of CombatEntity
var enemy_entities: Array = []  ## of CombatEntity
var turn_order: Array = []  ## of CombatEntity (sorted by speed)
var current_turn_index: int = -1
var current_entity: CombatEntity = null
var is_combat_active: bool = false
var round_number: int = 0
var gold_earned: int = 0  ## Set on victory for the scene to read


func start_combat(
	encounter_data: EncounterData,
	party_entities: Array,
	enemy_list: Array,
) -> void:
	encounter = encounter_data
	player_entities = party_entities.duplicate()
	enemy_entities = enemy_list.duplicate()
	all_entities.clear()
	all_entities.append_array(player_entities)
	all_entities.append_array(enemy_entities)
	is_combat_active = true
	round_number = 0
	log_message.emit("[INIT] Players: %d, Enemies: %d" % [player_entities.size(), enemy_entities.size()], Color.WHITE)
	for i in range(player_entities.size()):
		var e: CombatEntity = player_entities[i]
		log_message.emit("[INIT]   Player: %s — HP:%d/%d MP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f" % [e.entity_name, e.current_hp, e.max_hp, e.current_mp, e.max_mp, e.get_effective_stat(Enums.Stat.SPEED), e.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), e.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE)], Color.WHITE)
	for i in range(enemy_entities.size()):
		var e: CombatEntity = enemy_entities[i]
		log_message.emit("[INIT]   Enemy: %s — HP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f" % [e.entity_name, e.current_hp, e.max_hp, e.get_effective_stat(Enums.Stat.SPEED), e.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), e.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE)], Color.WHITE)
	# Apply start_shield passive to entities that have it
	for i in range(player_entities.size()):
		var e: CombatEntity = player_entities[i]
		if e.has_passive_effect(PassiveEffects.START_SHIELD):
			e.shield_hp = 15
			log_message.emit("%s gains a shield (15 HP)!" % e.entity_name, Color(0.4, 0.8, 1.0))
			passive_effect_triggered.emit(e, PassiveEffects.START_SHIELD, 15)

	_build_turn_order()
	log_message.emit("Battle started: %s" % encounter.display_name, Color.WHITE)


func _build_turn_order() -> void:
	turn_order.clear()
	for i in range(all_entities.size()):
		var entity: CombatEntity = all_entities[i]
		if not entity.is_dead:
			turn_order.append(entity)
	# Sort by speed descending (faster goes first)
	# First strike grants +50 speed in round 1
	var is_round_one: bool = (round_number == 0)
	turn_order.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool:
		var speed_a: float = a.get_effective_stat(Enums.Stat.SPEED)
		var speed_b: float = b.get_effective_stat(Enums.Stat.SPEED)
		if is_round_one:
			if a.has_passive_effect(PassiveEffects.FIRST_STRIKE):
				speed_a += 50.0
			if b.has_passive_effect(PassiveEffects.FIRST_STRIKE):
				speed_b += 50.0
		return speed_a > speed_b
	)
	var order_names: String = ", ".join(turn_order.map(func(e: CombatEntity) -> String: return "%s(%.0f)" % [e.entity_name, e.get_effective_stat(Enums.Stat.SPEED)]))
	log_message.emit("[TURN ORDER] Round %d: %s" % [round_number + 1, order_names], Color(0.6, 0.6, 0.6))


func advance_turn() -> void:
	if not is_combat_active:
		return

	current_turn_index += 1

	# New round
	if current_turn_index >= turn_order.size():
		round_number += 1
		_build_turn_order()
		current_turn_index = 0
		if turn_order.is_empty():
			return

	current_entity = turn_order[current_turn_index]
	log_message.emit("[TURN] %s's turn (index %d/%d, HP:%d/%d)" % [current_entity.entity_name, current_turn_index, turn_order.size() - 1, current_entity.current_hp, current_entity.max_hp], Color(0.6, 0.6, 0.6))

	# Skip dead entities
	if current_entity.is_dead:
		log_message.emit("[TURN] %s is dead, skipping" % current_entity.entity_name, Color(0.6, 0.6, 0.6))
		advance_turn()
		return

	# Tick status effects at turn start
	if not current_entity.status_effects.is_empty():
		log_message.emit("[STATUS] Ticking %d status(es) on %s" % [current_entity.status_effects.size(), current_entity.entity_name], Color(0.6, 0.6, 0.6))
	_tick_statuses(current_entity)

	# Check if entity died from status tick
	if current_entity.is_dead:
		log_message.emit("[TURN] %s died from status effects" % current_entity.entity_name, Color(0.6, 0.6, 0.6))
		entity_died.emit(current_entity)
		_check_combat_end()
		if is_combat_active:
			advance_turn()
		return

	# Clear defending flag (lasts one round)
	if current_entity.is_defending:
		log_message.emit("[TURN] %s defend stance cleared" % current_entity.entity_name, Color(0.6, 0.6, 0.6))
	current_entity.is_defending = false

	# Tick cooldowns
	current_entity.tick_cooldowns()

	# Check if entity can act (stun, etc.)
	if not current_entity.can_act():
		log_message.emit("%s is unable to act!" % current_entity.entity_name, Color(1.0, 0.6, 0.2))
		if is_combat_active:
			advance_turn()
		return

	log_message.emit("[TURN] Emitting turn_ready for %s (is_player=%s)" % [current_entity.entity_name, str(current_entity.is_player)], Color(0.6, 0.6, 0.6))
	turn_ready.emit(current_entity)


func execute_attack(source: CombatEntity, target: CombatEntity) -> Dictionary:
	log_message.emit("[ACTION] %s → Attack → %s (target HP:%d/%d, defending:%s)" % [source.entity_name, target.entity_name, target.current_hp, target.max_hp, str(target.is_defending)], Color(0.6, 0.6, 0.6))

	# Evasion check — target dodges the attack entirely
	if target.has_passive_effect(PassiveEffects.EVASION):
		if randf() < 0.10:
			log_message.emit("%s dodges %s's attack!" % [target.entity_name, source.entity_name], Color(0.4, 0.9, 1.0))
			passive_effect_triggered.emit(target, PassiveEffects.EVASION, 0)
			var dodge_result: Dictionary = {
				"source": source, "target": target,
				"action_type": Enums.CombatAction.ATTACK,
				"actual_damage": 0, "dodged": true,
			}
			action_resolved.emit(dodge_result)
			return dodge_result

	var result: Dictionary = DamageCalculator.calculate_basic_attack(source, target)
	log_message.emit("[DAMAGE] Calculated: %d, crit: %s" % [result.amount, str(result.is_crit)], Color(0.6, 0.6, 0.6))
	var actual: int = target.take_damage(result.amount)
	result["actual_damage"] = actual
	result["target"] = target
	result["source"] = source
	result["action_type"] = Enums.CombatAction.ATTACK

	var crit_text: String = " (CRITICAL!)" if result.is_crit else ""
	log_message.emit(
		"%s attacks %s for %d damage%s" % [source.entity_name, target.entity_name, actual, crit_text],
		Color(1.0, 0.3, 0.3) if result.is_crit else Color.WHITE,
	)

	# Lifesteal — heal attacker for % of damage dealt
	if actual > 0 and not source.is_dead:
		var lifesteal_pct: float = 0.0
		if source.has_passive_effect(PassiveEffects.LIFESTEAL_10):
			lifesteal_pct = 0.10
		elif source.has_passive_effect(PassiveEffects.LIFESTEAL_5):
			lifesteal_pct = 0.05
		if lifesteal_pct > 0.0:
			var heal_amount: int = maxi(int(float(actual) * lifesteal_pct), 1)
			var healed: int = source.heal(heal_amount)
			if healed > 0:
				log_message.emit("%s drains %d HP!" % [source.entity_name, healed], Color(0.6, 1.0, 0.6))
				passive_effect_triggered.emit(source, PassiveEffects.LIFESTEAL_5, healed)

	# Thorns — reflect flat damage back to attacker
	if actual > 0 and target.has_passive_effect(PassiveEffects.THORNS) and not target.is_dead and not source.is_dead:
		var thorn_dmg: int = source.take_damage(5)
		if thorn_dmg > 0:
			log_message.emit("%s takes %d thorn damage!" % [source.entity_name, thorn_dmg], Color(0.8, 0.5, 0.2))
			passive_effect_triggered.emit(target, PassiveEffects.THORNS, thorn_dmg)
			if source.is_dead:
				log_message.emit("%s has been defeated by thorns!" % source.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(source)

	if target.is_dead:
		log_message.emit("%s has been defeated!" % target.entity_name, Color(1.0, 0.5, 0.5))
		entity_died.emit(target)

	# Counter-attack — 15% chance to strike back
	if actual > 0 and target.has_passive_effect(PassiveEffects.COUNTER_ATTACK) and not target.is_dead and not source.is_dead:
		if randf() < 0.15:
			var counter_result: Dictionary = DamageCalculator.calculate_basic_attack(target, source)
			var counter_dmg: int = source.take_damage(counter_result.amount)
			log_message.emit("%s counter-attacks for %d damage!" % [target.entity_name, counter_dmg], Color(1.0, 0.7, 0.3))
			passive_effect_triggered.emit(target, PassiveEffects.COUNTER_ATTACK, counter_dmg)
			if source.is_dead:
				log_message.emit("%s has been defeated by counter-attack!" % source.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(source)

	action_resolved.emit(result)
	_check_combat_end()
	return result


func execute_defend(source: CombatEntity) -> Dictionary:
	log_message.emit("[ACTION] %s → Defend" % source.entity_name, Color(0.6, 0.6, 0.6))
	source.is_defending = true
	var result: Dictionary = {
		"source": source,
		"action_type": Enums.CombatAction.DEFEND,
	}
	log_message.emit("%s takes a defensive stance." % source.entity_name, Color(0.5, 0.8, 1.0))
	action_resolved.emit(result)
	return result


func execute_skill(source: CombatEntity, skill: SkillData, targets: Array) -> Dictionary:
	var target_names: String = ", ".join(targets.map(func(t: CombatEntity) -> String: return t.entity_name))
	log_message.emit("[ACTION] %s → Skill: %s (power:%d, type:%s, MP cost:%d) → %s" % [source.entity_name, skill.display_name, skill.power, Enums.DamageType.keys()[skill.damage_type] if skill.power > 0 else "N/A", skill.mp_cost, target_names], Color(0.6, 0.6, 0.6))
	source.spend_mp(skill.mp_cost)

	if skill.cooldown_turns > 0:
		source.cooldowns[skill.id] = skill.cooldown_turns

	var result: Dictionary = {
		"source": source,
		"action_type": Enums.CombatAction.SKILL,
		"skill": skill,
		"target_results": [],
	}

	# Damage-dealing skill
	if skill.power > 0:
		for t_i in range(targets.size()):
			var target: CombatEntity = targets[t_i]
			if target.is_dead:
				continue
			var dmg: Dictionary = DamageCalculator.calculate_skill_damage(source, target, skill)
			var actual: int = target.take_damage(dmg.amount)
			var crit_text: String = " (CRITICAL!)" if dmg.is_crit else ""
			log_message.emit(
				"%s uses %s on %s for %d damage%s" % [source.entity_name, skill.display_name, target.entity_name, actual, crit_text],
				Color(1.0, 0.9, 0.3),
			)
			var target_result: Dictionary = {"target": target, "damage": actual, "is_crit": dmg.is_crit}

			# Apply status effects
			for s_i in range(skill.applied_statuses.size()):
				var status = skill.applied_statuses[s_i]
				if status is StatusEffectData:
					target.apply_status(status)
					target_result["status_applied"] = status.display_name

			result.target_results.append(target_result)

			if target.is_dead:
				log_message.emit("%s has been defeated!" % target.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(target)

	# Healing skill
	if skill.heal_amount > 0 or skill.heal_percent > 0.0:
		for t_i in range(targets.size()):
			var target: CombatEntity = targets[t_i]
			if target.is_dead:
				continue
			var heal_val: int = DamageCalculator.calculate_healing(
				skill.heal_amount, skill.heal_percent, target.max_hp,
			)
			var actual_heal: int = target.heal(heal_val)
			log_message.emit(
				"%s uses %s — %s recovers %d HP" % [source.entity_name, skill.display_name, target.entity_name, actual_heal],
				Color(0.3, 1.0, 0.3),
			)
			result.target_results.append({"target": target, "heal": actual_heal})

	action_resolved.emit(result)
	_check_combat_end()
	return result


func execute_flee() -> bool:
	log_message.emit("[ACTION] Flee attempt (can_flee: %s)" % str(encounter.can_flee if encounter else "no encounter"), Color(0.6, 0.6, 0.6))
	if encounter and not encounter.can_flee:
		log_message.emit("Can't flee from this battle!", Color(1.0, 0.3, 0.3))
		return false
	log_message.emit("Fled from battle!", Color(0.8, 0.8, 0.8))
	is_combat_active = false
	combat_finished.emit(false)
	return true


func get_alive_players() -> Array:
	var alive: Array = []
	for i in range(player_entities.size()):
		var entity: CombatEntity = player_entities[i]
		if not entity.is_dead:
			alive.append(entity)
	return alive


func get_alive_enemies() -> Array:
	var alive: Array = []
	for i in range(enemy_entities.size()):
		var entity: CombatEntity = enemy_entities[i]
		if not entity.is_dead:
			alive.append(entity)
	return alive


func get_turn_order() -> Array:
	return turn_order


# === Internal ===

func _tick_statuses(entity: CombatEntity) -> void:
	# Mana regen passive — restore MP at turn start
	if entity.has_passive_effect(PassiveEffects.MANA_REGEN):
		var restored: int = entity.restore_mp(3)
		if restored > 0:
			log_message.emit("%s regenerates %d MP." % [entity.entity_name, restored], Color(0.4, 0.6, 1.0))
			passive_effect_triggered.emit(entity, PassiveEffects.MANA_REGEN, restored)

	var expired: Array = []
	for i in range(entity.status_effects.size() - 1, -1, -1):
		var effect: Dictionary = entity.status_effects[i]
		var data: StatusEffectData = effect.data

		# DoT damage
		if data.tick_damage > 0 and data.tick_on_start:
			var dmg: int = data.tick_damage * effect.stacks
			var actual: int = entity.take_damage(dmg)
			status_ticked.emit(entity, actual, data.display_name)
			log_message.emit(
				"%s takes %d damage from %s" % [entity.entity_name, actual, data.display_name],
				Color(0.8, 0.4, 0.8),
			)

		# Decrement duration
		if effect.remaining_turns > 0:
			effect.remaining_turns -= 1
			if effect.remaining_turns <= 0:
				expired.append(i)
		# -1 duration = permanent, don't decrement

	# Remove expired effects (iterate in reverse to keep indices valid)
	for e_i in range(expired.size()):
		var idx: int = expired[e_i]
		var data: StatusEffectData = entity.status_effects[idx].data
		entity.status_effects.remove_at(idx)
		status_expired.emit(entity, data.display_name)
		log_message.emit(
			"%s's %s has worn off." % [entity.entity_name, data.display_name],
			Color(0.7, 0.7, 0.7),
		)


func _check_combat_end() -> void:
	if not is_combat_active:
		return

	var alive_players: Array = get_alive_players()
	var alive_enemies: Array = get_alive_enemies()
	log_message.emit("[CHECK END] Alive players: %d, Alive enemies: %d" % [alive_players.size(), alive_enemies.size()], Color(0.6, 0.6, 0.6))

	if alive_enemies.is_empty():
		# Victory
		is_combat_active = false
		gold_earned = encounter.bonus_gold
		for i in range(enemy_entities.size()):
			var entity: CombatEntity = enemy_entities[i]
			if entity.enemy_data:
				gold_earned += entity.enemy_data.gold_reward

		# Double gold passive — any alive player with the effect doubles gold
		for i in range(player_entities.size()):
			var pe: CombatEntity = player_entities[i]
			if not pe.is_dead and pe.has_passive_effect(PassiveEffects.DOUBLE_GOLD):
				gold_earned *= 2
				log_message.emit("%s's fortune doubles the gold!" % pe.entity_name, Color(1.0, 0.84, 0.0))
				passive_effect_triggered.emit(pe, PassiveEffects.DOUBLE_GOLD, gold_earned)
				break  # Only apply once

		log_message.emit("Victory! Earned %d gold." % gold_earned, Color(1.0, 0.84, 0.0))
		combat_finished.emit(true)

	elif alive_players.is_empty():
		# Defeat
		is_combat_active = false
		log_message.emit("Defeat...", Color(1.0, 0.2, 0.2))
		combat_finished.emit(false)
