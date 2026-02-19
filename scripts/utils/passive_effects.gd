class_name PassiveEffects
## String constants for special passive effect IDs.
## CombatManager checks these on CombatEntity.passive_special_effects.

const COUNTER_ATTACK := "counter_attack"   ## 15% chance to counter physical attacks
const LIFESTEAL_5 := "lifesteal_5"         ## Heal 5% of damage dealt
const LIFESTEAL_10 := "lifesteal_10"       ## Heal 10% of damage dealt
const START_SHIELD := "start_shield"       ## Gain 15 HP shield at battle start
const THORNS := "thorns"                   ## Reflect 5 damage when hit
const MANA_REGEN := "mana_regen"           ## Restore 3 MP each turn
const EVASION := "evasion"                 ## 10% chance to dodge attacks
const FIRST_STRIKE := "first_strike"       ## +50 speed in round 1
const DOUBLE_GOLD := "double_gold"         ## 2x gold from battles


static func has_effect(effects: Array, effect_id: String) -> bool:
	for i in range(effects.size()):
		if effects[i] == effect_id:
			return true
	return false
