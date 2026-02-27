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
signal entity_died(entity: CombatEntity)
signal log_message(text: String, color: Color)

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
var player_fled: bool = false  ## True when the player chose to flee (not a defeat)


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
			e.shield_hp = PassiveEffects.START_SHIELD_AMOUNT
			log_message.emit("%s gains a shield (15 HP)!" % e.entity_name, Color(0.4, 0.8, 1.0))
	
	_build_turn_order()
	log_message.emit("Battle started: %s" % encounter.display_name, Color.WHITE)


func _build_turn_order() -> void:
	# Initialize time_until_turn for all entities
	# Faster characters have lower time increments, so they act more frequently
	var is_round_one: bool = (round_number == 0)
	for i in range(all_entities.size()):
		var entity: CombatEntity = all_entities[i]
		if not entity.is_dead:
			# First turn setup
			if entity.time_until_turn == 0.0:
				var speed: float = entity.get_effective_stat(Enums.Stat.SPEED)
				# First strike passive grants immediate first turn
				if is_round_one and entity.has_passive_effect(PassiveEffects.FIRST_STRIKE):
					entity.time_until_turn = 0.0
				else:
					# Random initial offset (0-50% of normal turn time) for variety
					entity.time_until_turn = randf_range(0.0, 50.0 / speed)

	# Build initial turn order (just for logging)
	turn_order.clear()
	for i in range(all_entities.size()):
		var entity: CombatEntity = all_entities[i]
		if not entity.is_dead:
			turn_order.append(entity)
	turn_order.sort_custom(func(a: CombatEntity, b: CombatEntity) -> bool:
		return a.time_until_turn < b.time_until_turn
	)
	var order_names: String = ", ".join(turn_order.map(func(e: CombatEntity) -> String: return "%s(%.0f,t=%.1f)" % [e.entity_name, e.get_effective_stat(Enums.Stat.SPEED), e.time_until_turn]))
	log_message.emit("[TURN ORDER] Initial: %s" % order_names, Color(0.6, 0.6, 0.6))


func advance_turn() -> void:
	if not is_combat_active:
		return

	# Find entity with lowest time_until_turn (who goes next)
	var next_entity: CombatEntity = null
	var min_time: float = INF
	for i in range(all_entities.size()):
		var entity: CombatEntity = all_entities[i]
		if not entity.is_dead and entity.time_until_turn < min_time:
			min_time = entity.time_until_turn
			next_entity = entity

	if not next_entity:
		log_message.emit("[TURN] No more entities can act!", Color(0.6, 0.6, 0.6))
		return

	current_entity = next_entity

	# Increment turn counter every ~10 actions for round tracking
	current_turn_index += 1
	if current_turn_index % 10 == 0:
		round_number += 1

	log_message.emit("[TURN] %s's turn (time=%.1f, HP:%d/%d)" % [current_entity.entity_name, current_entity.time_until_turn, current_entity.current_hp, current_entity.max_hp], Color(0.6, 0.6, 0.6))

	# Skip dead entities
	if current_entity.is_dead:
		log_message.emit("[TURN] %s is dead, skipping" % current_entity.entity_name, Color(0.6, 0.6, 0.6))
		advance_turn()
		return

	# Tick status effects at turn start
	if not current_entity.status_effects.is_empty():
		log_message.emit("[STATUS] Ticking %d status(es) on %s" % [current_entity.status_effects.size(), current_entity.entity_name], Color(0.6, 0.6, 0.6))
	_tick_statuses(current_entity)

	# Tick gem-based status effects (Burn, Poisoned, Chilled, Shocked)
	if not current_entity.active_gem_status_effects.is_empty():
		log_message.emit("[GEM STATUS] Ticking %d gem effect(s) on %s" % [current_entity.active_gem_status_effects.size(), current_entity.entity_name], Color(0.6, 0.6, 0.6))
		current_entity.process_gem_status_effects()

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
		_increment_turn_time(current_entity)  # Still increment time even if stunned
		if is_combat_active:
			advance_turn()
		return

	log_message.emit("[TURN] Emitting turn_ready for %s (is_player=%s)" % [current_entity.entity_name, str(current_entity.is_player)], Color(0.6, 0.6, 0.6))
	turn_ready.emit(current_entity)


func execute_attack(source: CombatEntity, target: CombatEntity) -> Dictionary:
	log_message.emit("[ACTION] %s → Attack → %s (target HP:%d/%d, defending:%s)" % [source.entity_name, target.entity_name, target.current_hp, target.max_hp, str(target.is_defending)], Color(0.6, 0.6, 0.6))

	# Increment source's turn timer (acts AFTER the action completes)
	_increment_turn_time(source)

	# Evasion check — target dodges the attack entirely
	if target.has_passive_effect(PassiveEffects.EVASION):
		if randf() < PassiveEffects.EVASION_CHANCE:
			log_message.emit("%s dodges %s's attack!" % [target.entity_name, source.entity_name], Color(0.4, 0.9, 1.0))
			var dodge_result: Dictionary = {
				"source": source, "target": target,
				"action_type": Enums.CombatAction.ATTACK,
				"actual_damage": 0, "dodged": true,
			}
			action_resolved.emit(dodge_result)
			return dodge_result

	var result: Dictionary = DamageCalculator.calculate_basic_attack(source, target)
	log_message.emit("[DAMAGE] Calculated: %d, crit: %s" % [result.amount, str(result.is_crit)], Color(0.6, 0.6, 0.6))
	var target_was_alive: bool = not target.is_dead
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

	# MeGummy AoE — splash damage to all other enemies
	var splash_results: Array = []
	if source.is_player and source.has_force_aoe():
		log_message.emit("[AOE] %s has force_aoe — splashing to all enemies!" % source.entity_name, Color(1.0, 0.6, 0.2))
		var splash_targets: Array = get_alive_enemies()
		for s_i in range(splash_targets.size()):
			var splash_target: CombatEntity = splash_targets[s_i]
			if splash_target == target or splash_target.is_dead:
				continue
			var splash_dmg: Dictionary = DamageCalculator.calculate_basic_attack(source, splash_target)
			var splash_actual: int = splash_target.take_damage(splash_dmg.amount)
			log_message.emit(
				"  Explosive splash hits %s for %d damage!" % [splash_target.entity_name, splash_actual],
				Color(1.0, 0.6, 0.2),
			)
			splash_results.append({"target": splash_target, "damage": splash_actual, "is_crit": splash_dmg.is_crit})
			if splash_target.is_dead:
				log_message.emit("%s has been defeated!" % splash_target.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(splash_target)
	result["splash_results"] = splash_results

	# Gem/innate status effects — roll each proc independently
	if actual > 0 and source.is_player and target_was_alive:
		var modifier_state: ToolModifierState = source.get_primary_tool_modifier_state()
		if modifier_state:
			for proc in modifier_state.status_procs:
				if randf() < proc.chance:
					var stacks: int = proc.crit_stacks if result.is_crit else proc.stacks
					var status_template: StatusEffect = _get_status_effect_template(proc.type)
					if status_template:
						target.apply_gem_status_effect(status_template, stacks)
						var effect_name: String = Enums.StatusEffectType.keys()[proc.type]
						var crit_tag: String = " (CRIT — %d stacks)" % stacks if result.is_crit else " (+%d stack)" % stacks
						log_message.emit("%s is afflicted with %s%s" % [target.entity_name, effect_name, crit_tag], Color(1.0, 0.6, 0.2))

	# Gem HP cost per attack (e.g. MeGummy)
	if source.is_player and not source.is_dead:
		var modifier_state_cost: ToolModifierState = source.get_primary_tool_modifier_state()
		if modifier_state_cost and modifier_state_cost.hp_cost_per_attack > 0:
			var hp_lost: int = source.take_damage(modifier_state_cost.hp_cost_per_attack)
			if hp_lost > 0:
				log_message.emit("%s suffers %d HP from unstable gem!" % [source.entity_name, hp_lost], Color(0.9, 0.3, 0.6))
				result["self_damage"] = hp_lost
				if source.is_dead:
					log_message.emit("%s has been defeated by their own gem!" % source.entity_name, Color(1.0, 0.5, 0.5))
					entity_died.emit(source)

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
	
	# Thorns — reflect flat damage back to attacker
	if actual > 0 and target.has_passive_effect(PassiveEffects.THORNS) and not target.is_dead and not source.is_dead:
		var thorn_dmg: int = source.take_damage(PassiveEffects.THORNS_DAMAGE)
		if thorn_dmg > 0:
			log_message.emit("%s takes %d thorn damage!" % [source.entity_name, thorn_dmg], Color(0.8, 0.5, 0.2))
			if source.is_dead:
				log_message.emit("%s has been defeated by thorns!" % source.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(source)

	if target.is_dead:
		log_message.emit("%s has been defeated!" % target.entity_name, Color(1.0, 0.5, 0.5))
		entity_died.emit(target)

	# Counter-attack — 15% chance to strike back
	if actual > 0 and target.has_passive_effect(PassiveEffects.COUNTER_ATTACK) and not target.is_dead and not source.is_dead:
		if randf() < PassiveEffects.COUNTER_CHANCE:
			var counter_result: Dictionary = DamageCalculator.calculate_basic_attack(target, source)
			var counter_dmg: int = source.take_damage(counter_result.amount)
			log_message.emit("%s counter-attacks for %d damage!" % [target.entity_name, counter_dmg], Color(1.0, 0.7, 0.3))
			if source.is_dead:
				log_message.emit("%s has been defeated by counter-attack!" % source.entity_name, Color(1.0, 0.5, 0.5))
				entity_died.emit(source)

	action_resolved.emit(result)
	_check_combat_end()
	return result


func execute_defend(source: CombatEntity) -> Dictionary:
	log_message.emit("[ACTION] %s → Defend" % source.entity_name, Color(0.6, 0.6, 0.6))

	# Increment source's turn timer (acts AFTER the action completes)
	_increment_turn_time(source)

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
	log_message.emit("[ACTION] %s → Skill: %s (phys:%.1f, mag:%.1f, MP cost:%d) → %s" % [source.entity_name, skill.display_name, skill.physical_scaling, skill.magical_scaling, skill.mp_cost, target_names], Color(0.6, 0.6, 0.6))

	# Increment source's turn timer (acts AFTER the action completes)
	_increment_turn_time(source)

	# Handle use_all_mp skills: capture MP before spending
	var mp_spent: int = 0
	if skill.use_all_mp:
		mp_spent = source.current_mp
		source.spend_mp(mp_spent)
		log_message.emit("%s channels ALL %d MP!" % [source.entity_name, mp_spent], Color(1.0, 0.4, 0.0))
	else:
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
	if skill.has_damage():
		for t_i in range(targets.size()):
			var target: CombatEntity = targets[t_i]
			if target.is_dead:
				continue
			var dmg: Dictionary
			if skill.use_all_mp and skill.mp_damage_ratio > 0.0:
				# Special: damage = MP spent * ratio, bypasses normal formula
				var raw_dmg: int = maxi(int(float(mp_spent) * skill.mp_damage_ratio), 1)
				dmg = {"amount": raw_dmg, "is_crit": false}
			else:
				dmg = DamageCalculator.calculate_skill_damage(source, target, skill)
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
	player_fled = true
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
	# Simulate the next 10 turns to show upcoming turn order
	return _simulate_future_turns(10)


func _simulate_future_turns(count: int) -> Array:
	# Create a copy of entity times to simulate forward without affecting actual state
	var entity_times: Dictionary = {}  # CombatEntity -> float (time_until_turn)
	var active_entities: Array = []

	for i in range(all_entities.size()):
		var entity: CombatEntity = all_entities[i]
		if not entity.is_dead:
			entity_times[entity] = entity.time_until_turn
			active_entities.append(entity)

	if active_entities.is_empty():
		return []

	var future_order: Array = []

	# Simulate forward `count` turns
	for turn_idx in range(count):
		# Find entity with minimum time
		var next_entity: CombatEntity = null
		var min_time: float = INF

		for j in range(active_entities.size()):
			var entity: CombatEntity = active_entities[j]
			var time: float = entity_times[entity]
			if time < min_time:
				min_time = time
				next_entity = entity

		if not next_entity:
			break

		future_order.append(next_entity)

		# Increment this entity's time for next turn
		var speed: float = next_entity.get_effective_stat(Enums.Stat.SPEED)
		var time_increment: float = 100.0 / max(speed, 1.0)
		entity_times[next_entity] = entity_times[next_entity] + time_increment

	return future_order


# === Internal ===

func _increment_turn_time(entity: CombatEntity) -> void:
	## Increments an entity's turn timer based on their speed.
	## Called AFTER an action executes, not before.
	var speed: float = entity.get_effective_stat(Enums.Stat.SPEED)
	var time_increment: float = 100.0 / max(speed, 1.0)
	entity.time_until_turn += time_increment


func _tick_statuses(entity: CombatEntity) -> void:
	# Mana regen passive — restore MP at turn start
	if entity.has_passive_effect(PassiveEffects.MANA_REGEN):
		var restored: int = entity.restore_mp(PassiveEffects.MANA_REGEN_AMOUNT)
		if restored > 0:
			log_message.emit("%s regenerates %d MP." % [entity.entity_name, restored], Color(0.4, 0.6, 1.0))
	
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
				Color(1.0, 0.6, 0.2),
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
		log_message.emit(
			"%s's %s has worn off." % [entity.entity_name, data.display_name],
			Color(1.0, 0.6, 0.2),
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
				break  # Only apply once

		log_message.emit("Victory! Earned %d gold." % gold_earned, Color(1.0, 0.84, 0.0))
		combat_finished.emit(true)

	elif alive_players.is_empty():
		# Defeat
		is_combat_active = false
		log_message.emit("Defeat...", Color(1.0, 0.2, 0.2))
		combat_finished.emit(false)


func _get_status_effect_template(effect_type: int) -> StatusEffect:
	## Returns the status effect template for the given type.
	## Loads from data/status_effects/ directory.
	match effect_type:
		Enums.StatusEffectType.BURN:
			return load("res://data/status_effects/burn.tres")
		Enums.StatusEffectType.POISONED:
			return load("res://data/status_effects/poisoned.tres")
		Enums.StatusEffectType.CHILLED:
			return load("res://data/status_effects/chilled.tres")
		Enums.StatusEffectType.SHOCKED:
			return load("res://data/status_effects/shocked.tres")
		_:
			return null
