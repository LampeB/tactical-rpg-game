class_name PassiveEffects
## String constants for special passive effect IDs.
## CombatManager checks these on CombatEntity.passive_special_effects.

const COUNTER_ATTACK := "counter_attack"   ## COUNTER_CHANCE (15%) to counter physical attacks
const LIFESTEAL_5 := "lifesteal_5"         ## Heal 5% of damage dealt
const LIFESTEAL_10 := "lifesteal_10"       ## Heal 10% of damage dealt
const START_SHIELD := "start_shield"       ## Gain START_SHIELD_AMOUNT (15) HP shield at battle start
const THORNS := "thorns"                   ## Reflect THORNS_DAMAGE (5) damage when hit
const MANA_REGEN := "mana_regen"           ## Restore MANA_REGEN_AMOUNT (3) MP each turn
const EVASION := "evasion"                 ## EVASION_CHANCE (10%) to dodge attacks
const FIRST_STRIKE := "first_strike"       ## +FIRST_STRIKE_SPEED (50) speed in round 1
const DOUBLE_GOLD := "double_gold"         ## 2x gold from battles

# Passive effect values
const START_SHIELD_AMOUNT := 15
const THORNS_DAMAGE := 5
const EVASION_CHANCE := 0.10
const COUNTER_CHANCE := 0.15
const FIRST_STRIKE_SPEED := 50.0
const MANA_REGEN_AMOUNT := 3


static func get_description(effect_id: String) -> String:
	match effect_id:
		COUNTER_ATTACK:
			return "%d%% chance to counter-attack" % int(COUNTER_CHANCE * 100)
		LIFESTEAL_5:
			return "Heal 5% of damage dealt"
		LIFESTEAL_10:
			return "Heal 10% of damage dealt"
		START_SHIELD:
			return "Gain %d HP shield at battle start" % START_SHIELD_AMOUNT
		THORNS:
			return "Reflect %d damage when hit" % THORNS_DAMAGE
		MANA_REGEN:
			return "Restore %d MP each turn" % MANA_REGEN_AMOUNT
		EVASION:
			return "%d%% chance to dodge attacks" % int(EVASION_CHANCE * 100)
		FIRST_STRIKE:
			return "+%.0f Speed in round 1" % FIRST_STRIKE_SPEED
		DOUBLE_GOLD:
			return "Double gold earned from battles"
		_:
			return effect_id


static func has_effect(effects: Array, effect_id: String) -> bool:
	for i in range(effects.size()):
		if effects[i] == effect_id:
			return true
	return false
