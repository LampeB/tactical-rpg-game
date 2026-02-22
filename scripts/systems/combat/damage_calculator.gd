class_name DamageCalculator
extends RefCounted
## Pure functions for damage and healing calculations.
## Damage formula: each component = (weapon_power + stat) * (skill_scaling + passive_scaling)
## Defense: percentage-based reduction per component (0–100, 100 = immune).


static func calculate_damage(
	source: CombatEntity,
	target: CombatEntity,
	physical_scaling: float,
	magical_scaling: float,
) -> Dictionary:
	## Returns {"amount": int, "is_crit": bool}

	# Physical component
	var phys_power: float = float(source.get_total_weapon_physical_power())
	var phys_stat: float = source.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK)
	var passive_phys_scaling: float = source.get_effective_stat(Enums.Stat.PHYSICAL_SCALING) / 100.0
	var phys_raw: float = (phys_power + phys_stat) * maxf(physical_scaling + passive_phys_scaling, 0.0)

	# Magical component
	var mag_power: float = float(source.get_total_weapon_magical_power())
	var mag_stat: float = source.get_effective_stat(Enums.Stat.MAGICAL_ATTACK)
	var passive_mag_scaling: float = source.get_effective_stat(Enums.Stat.MAGICAL_SCALING) / 100.0
	var mag_raw: float = (mag_power + mag_stat) * maxf(magical_scaling + passive_mag_scaling, 0.0)

	# Defense reduction (percentage-based, clamped 0–100)
	var phys_def: float = clampf(target.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), 0.0, 100.0)
	var mag_def: float = clampf(target.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE), 0.0, 100.0)
	phys_raw *= (1.0 - phys_def / 100.0)
	mag_raw *= (1.0 - mag_def / 100.0)

	var total: float = phys_raw + mag_raw
	total = maxf(total, 1.0)  # Minimum 1 damage

	# Critical hit
	var luck: float = source.get_effective_stat(Enums.Stat.LUCK)
	var crit_rate: float = Constants.BASE_CRITICAL_RATE + luck * Constants.LUCK_CRIT_SCALING
	var bonus_crit: float = source.get_effective_stat(Enums.Stat.CRITICAL_RATE) / 100.0
	crit_rate += bonus_crit
	crit_rate = clampf(crit_rate, 0.0, Constants.MAX_CRITICAL_RATE)

	var is_crit: bool = randf() < crit_rate
	if is_crit:
		var crit_mult: float = Constants.BASE_CRITICAL_DAMAGE
		var bonus_crit_dmg: float = source.get_effective_stat(Enums.Stat.CRITICAL_DAMAGE) / 100.0
		crit_mult += bonus_crit_dmg
		total *= crit_mult

	# Defend multiplier
	if target.is_defending:
		total *= Constants.DEFEND_DAMAGE_REDUCTION

	# Status effect damage multiplier on target
	total *= target.get_damage_taken_multiplier()

	var amount: int = maxi(int(total), 1)
	return {"amount": amount, "is_crit": is_crit}


static func calculate_basic_attack(source: CombatEntity, target: CombatEntity) -> Dictionary:
	## Basic attack: 1.0/1.0 scaling for players, type-based for enemies.
	if source.is_player:
		return calculate_damage(source, target, 1.0, 1.0)
	elif source.enemy_data:
		# Enemies use single damage type for basic attacks
		if source.enemy_data.damage_type == Enums.DamageType.MAGICAL:
			return calculate_damage(source, target, 0.0, 1.0)
		else:
			return calculate_damage(source, target, 1.0, 0.0)

	return calculate_damage(source, target, 1.0, 0.0)


static func calculate_skill_damage(
	source: CombatEntity,
	target: CombatEntity,
	skill: SkillData,
) -> Dictionary:
	return calculate_damage(source, target, skill.physical_scaling, skill.magical_scaling)


static func calculate_healing(
	heal_amount: int,
	heal_percent: float,
	target_max_hp: int,
) -> int:
	var total: int = heal_amount + int(heal_percent * float(target_max_hp))
	return maxi(total, 0)
