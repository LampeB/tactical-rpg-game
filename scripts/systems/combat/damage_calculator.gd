class_name DamageCalculator
extends RefCounted
## Pure functions for damage and healing calculations.


static func calculate_damage(
	source: CombatEntity,
	target: CombatEntity,
	power: int,
	damage_type: Enums.DamageType,
	scaling: float = 1.0,
) -> Dictionary:
	## Returns {"amount": int, "is_crit": bool}

	# Determine attack and defense stats based on damage type
	var atk: float
	var def: float
	if damage_type == Enums.DamageType.PHYSICAL:
		atk = source.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK)
		def = target.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE)
	else:
		atk = source.get_effective_stat(Enums.Stat.SPECIAL_ATTACK)
		def = target.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE)

	# Base damage formula
	var raw: float = (atk * scaling + float(power)) - def * 0.5
	raw = maxf(raw, 1.0)  # Minimum 1 damage

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
		raw *= crit_mult

	# Defend multiplier
	if target.is_defending:
		raw *= Constants.DEFEND_DAMAGE_REDUCTION

	# Status effect damage multiplier on target
	raw *= target.get_damage_taken_multiplier()

	var amount: int = maxi(int(raw), 1)
	return {"amount": amount, "is_crit": is_crit}


static func calculate_damage_hybrid(
	source: CombatEntity,
	target: CombatEntity,
	physical_power: int,
	magical_power: int,
	scaling: float = 1.0,
) -> Dictionary:
	## Hybrid damage calculation for attacks with both physical and magical components.
	## Returns {"amount": int, "is_crit": bool}

	# Calculate physical component
	var phys_atk: float = source.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK)
	var phys_def: float = target.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE)
	var phys_dmg: float = (phys_atk * scaling + float(physical_power)) - phys_def * 0.5
	phys_dmg = maxf(phys_dmg, 0.0)

	# Calculate magical component
	var mag_atk: float = source.get_effective_stat(Enums.Stat.SPECIAL_ATTACK)
	var mag_def: float = target.get_effective_stat(Enums.Stat.MAGICAL_DEFENSE)
	var mag_dmg: float = (mag_atk * scaling + float(magical_power)) - mag_def * 0.5
	mag_dmg = maxf(mag_dmg, 0.0)

	# Sum components
	var total: float = phys_dmg + mag_dmg
	total = maxf(total, 1.0)  # Minimum 1 damage

	# Critical hit applies to total damage
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
	## Basic attack uses hybrid damage calculation for players with weapons.
	if source.is_player:
		# Use hybrid damage with weapon power + gem bonuses
		var phys_power: int = source.get_primary_weapon_physical_power()
		var mag_power: int = source.get_primary_weapon_magical_power()
		return calculate_damage_hybrid(source, target, phys_power, mag_power, 1.0)
	elif source.enemy_data:
		# Enemies use single damage type
		var damage_type: Enums.DamageType = source.enemy_data.damage_type
		return calculate_damage(source, target, 0, damage_type, 1.0)

	return calculate_damage(source, target, 0, Enums.DamageType.PHYSICAL, 1.0)


static func calculate_skill_damage(
	source: CombatEntity,
	target: CombatEntity,
	skill: SkillData,
) -> Dictionary:
	return calculate_damage(source, target, skill.power, skill.damage_type, skill.scaling)


static func calculate_healing(
	heal_amount: int,
	heal_percent: float,
	target_max_hp: int,
) -> int:
	var total: int = heal_amount + int(heal_percent * float(target_max_hp))
	return maxi(total, 0)
