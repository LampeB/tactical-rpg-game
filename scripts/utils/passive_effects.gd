class_name PassiveEffects
## String constants for special passive effect IDs.
## CombatManager checks these on CombatEntity.passive_special_effects.

# === MINOR EFFECTS (existing) ===
const COUNTER_ATTACK := "counter_attack"   ## COUNTER_CHANCE (15%) to counter physical attacks
const LIFESTEAL_5 := "lifesteal_5"         ## Heal 5% of damage dealt
const LIFESTEAL_10 := "lifesteal_10"       ## Heal 10% of damage dealt
const START_SHIELD := "start_shield"       ## Gain START_SHIELD_AMOUNT (15) HP shield at battle start
const THORNS := "thorns"                   ## Reflect THORNS_DAMAGE (5) damage when hit
const MANA_REGEN := "mana_regen"           ## Restore MANA_REGEN_AMOUNT (3) MP each turn
const EVASION := "evasion"                 ## EVASION_CHANCE (10%) to dodge attacks
const FIRST_STRIKE := "first_strike"       ## +FIRST_STRIKE_SPEED (50) speed in round 1
const DOUBLE_GOLD := "double_gold"         ## 2x gold from battles
const AUTO_REVIVE := "auto_revive"         ## Survive 1 lethal blow at AUTO_REVIVE_HP_PERCENT HP
const FIRST_HIT_EVASION := "first_hit_evasion"  ## Guaranteed dodge on first hit received
const DAMAGE_SHIELD_ON_KILL := "damage_shield_on_kill"  ## Gain shield HP on kill
const EXECUTE_THRESHOLD := "execute_threshold"  ## Bonus damage to low-HP targets
const MP_ON_KILL := "mp_on_kill"           ## Restore MP on kill

# === NOTABLE EFFECTS — Warrior ===
const BULWARK_STANCE := "bulwark_stance"           ## While defending, adjacent allies take 15% less damage
const CRUSHING_BLOW := "crushing_blow"             ## 15% chance to inflict -20% Phys Def debuff for 2 turns
const SECOND_WIND := "second_wind"                 ## Items heal 20% more HP
const UNBREAKING := "unbreaking"                   ## +30% status resist when above 50% HP
const TAUNT_MASTERY := "taunt_mastery"             ## Taunt skills last 1 extra turn
const IRONBLOOD := "ironblood"                     ## +15% Phys Def, -5% Speed (applied as stat mods)
const BLOODTHIRST := "bloodthirst"                 ## Heal 8% of physical damage dealt

# === NOTABLE EFFECTS — Mage ===
const ELEMENTAL_MASTERY := "elemental_mastery"     ## +15% damage vs element-weak enemies
const SPELL_ECHO := "spell_echo"                   ## 10% chance for offensive spells to trigger twice (half dmg)
const OVERCHARGED := "overcharged"                 ## Crit spells +30% Crit Dmg, spells cost +20% MP
const FOCUSED_MIND_COND := "focused_mind_cond"     ## +15% Mag Atk when MP above 50%
const CHAIN_REACTION := "chain_reaction"           ## Status effects 20% chance to spread to adjacent enemy
const ARCANE_SHIELD := "arcane_shield"             ## Unspent MP grants +1 Mag Def per 10 MP at turn start
const RESONANCE := "resonance"                     ## Same-element consecutive spells deal +20% damage

# === NOTABLE EFFECTS — Rogue ===
const AMBUSH := "ambush"                           ## First attack each battle deals +40% damage
const EXPLOIT_WEAKNESS := "exploit_weakness"       ## +25% damage vs enemies with status effects
const LUCKY_STRIKE := "lucky_strike"               ## Crit hits 20% chance to drop bonus gold
const SHADOWSTEP := "shadowstep"                   ## After dodging, next attack +30% Crit Rate
const POISON_MASTERY := "poison_mastery"           ## Poison lasts 1 extra turn, +15% Poison damage
const QUICK_HANDS := "quick_hands"                 ## Item use doesn't cost turn (once per battle)
const BLADE_FLURRY := "blade_flurry"               ## Multi-hit skills gain +1 extra hit at 50% damage
const TREASURE_SENSE := "treasure_sense"           ## +15% rare item drop, +25% gold

# === NOTABLE EFFECTS — Cross-path ===
const SPELL_SWORD := "spell_sword"                 ## Phys Atk adds 15% of its value to Mag Atk
const BATTLE_MAGE := "battle_mage"                 ## Mag Atk adds 15% of its value to Phys Atk
const SHADOW_KNIGHT := "shadow_knight"             ## Counter-attacks have +50% Crit Rate
const ARCANE_TRICKSTER := "arcane_trickster"       ## Status effects from spells last 1 extra turn

# === KEYSTONE EFFECTS ===
const KS_IMMORTAL_FORTRESS := "ks_immortal_fortress"   ## Survive lethal blow once per battle (30% HP). -20% Phys Atk.
const KS_BERSERKER_RAGE := "ks_berserker_rage"         ## +40% Phys Atk, +15% Crit Dmg. Cannot defend. Cannot be healed by allies.
const KS_ARCHMAGE := "ks_archmage"                     ## First spell each battle costs 0 MP. -30% Max HP.
const KS_ELEMENTAL_OVERLOAD := "ks_elemental_overload" ## +30% elemental damage. Non-elemental skills -50% damage.
const KS_PHANTOM := "ks_phantom"                       ## 25% dodge chance. -20% Max HP.
const KS_EXECUTIONER := "ks_executioner"               ## +100% damage to enemies below 25% HP. -15% damage to enemies above 50% HP.
const KS_JACK_OF_ALL_TRADES := "ks_jack_of_all_trades" ## +10% all stats. Cannot unlock other Keystones.

# === Passive effect values ===

# Minor values
const START_SHIELD_AMOUNT := 15
const THORNS_DAMAGE := 5
const EVASION_CHANCE := 0.10
const COUNTER_CHANCE := 0.15
const FIRST_STRIKE_SPEED := 50.0
const MANA_REGEN_AMOUNT := 3
const AUTO_REVIVE_HP_PERCENT := 0.30
const DAMAGE_SHIELD_ON_KILL_AMOUNT := 20
const EXECUTE_THRESHOLD_HP_PERCENT := 0.25
const EXECUTE_BONUS_DAMAGE := 1.5
const MP_ON_KILL_AMOUNT := 10

# Notable values
const CRUSHING_BLOW_CHANCE := 0.15
const CRUSHING_BLOW_DEF_REDUCTION := 0.20
const CRUSHING_BLOW_DURATION := 2
const SECOND_WIND_BONUS := 0.20
const UNBREAKING_STATUS_RESIST := 0.30
const UNBREAKING_HP_THRESHOLD := 0.50
const BLOODTHIRST_PERCENT := 0.08
const ELEMENTAL_MASTERY_BONUS := 0.15
const SPELL_ECHO_CHANCE := 0.10
const SPELL_ECHO_DAMAGE_MULT := 0.50
const OVERCHARGED_CRIT_BONUS := 0.30
const OVERCHARGED_MANA_PENALTY := 0.20
const FOCUSED_MIND_BONUS := 0.15
const FOCUSED_MIND_MP_THRESHOLD := 0.50
const CHAIN_REACTION_CHANCE := 0.20
const RESONANCE_BONUS := 0.20
const AMBUSH_BONUS := 0.40
const EXPLOIT_WEAKNESS_BONUS := 0.25
const LUCKY_STRIKE_CHANCE := 0.20
const SHADOWSTEP_CRIT_BONUS := 0.30
const QUICK_HANDS_USES := 1
const BLADE_FLURRY_EXTRA_HITS := 1
const BLADE_FLURRY_DAMAGE_MULT := 0.50
const TREASURE_SENSE_DROP_BONUS := 0.15
const TREASURE_SENSE_GOLD_BONUS := 0.25
const SPELL_SWORD_RATIO := 0.15
const BATTLE_MAGE_RATIO := 0.15
const SHADOW_KNIGHT_CRIT_BONUS := 0.50
const BULWARK_STANCE_REDUCTION := 0.15

# Keystone values
const KS_IMMORTAL_FORTRESS_HP := 0.30
const KS_IMMORTAL_FORTRESS_ATK_PENALTY := 0.20
const KS_BERSERKER_ATK_BONUS := 0.40
const KS_BERSERKER_CRIT_BONUS := 0.15
const KS_ARCHMAGE_HP_PENALTY := 0.30
const KS_ELEMENTAL_OVERLOAD_BONUS := 0.30
const KS_ELEMENTAL_OVERLOAD_PENALTY := 0.50
const KS_PHANTOM_DODGE := 0.25
const KS_PHANTOM_HP_PENALTY := 0.20
const KS_EXECUTIONER_BONUS := 1.00
const KS_EXECUTIONER_THRESHOLD := 0.25
const KS_EXECUTIONER_PENALTY := 0.15
const KS_EXECUTIONER_PENALTY_THRESHOLD := 0.50
const KS_JACK_STAT_BONUS := 0.10


static func get_description(effect_id: String) -> String:
	match effect_id:
		# Minor
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
		AUTO_REVIVE:
			return "Survive a lethal blow once (revive at %d%% HP)" % int(AUTO_REVIVE_HP_PERCENT * 100)
		FIRST_HIT_EVASION:
			return "Guaranteed dodge on the first hit received"
		DAMAGE_SHIELD_ON_KILL:
			return "Gain %d HP shield on kill" % DAMAGE_SHIELD_ON_KILL_AMOUNT
		EXECUTE_THRESHOLD:
			return "+%d%% damage to targets below %d%% HP" % [int((EXECUTE_BONUS_DAMAGE - 1.0) * 100), int(EXECUTE_THRESHOLD_HP_PERCENT * 100)]
		MP_ON_KILL:
			return "Restore %d MP on kill" % MP_ON_KILL_AMOUNT
		# Notable — Warrior
		BULWARK_STANCE:
			return "While defending, adjacent allies take %d%% less damage" % int(BULWARK_STANCE_REDUCTION * 100)
		CRUSHING_BLOW:
			return "%d%% chance to inflict -%d%% Phys Def for %d turns" % [int(CRUSHING_BLOW_CHANCE * 100), int(CRUSHING_BLOW_DEF_REDUCTION * 100), CRUSHING_BLOW_DURATION]
		SECOND_WIND:
			return "Items heal %d%% more HP" % int(SECOND_WIND_BONUS * 100)
		UNBREAKING:
			return "+%d%% status resist when above %d%% HP" % [int(UNBREAKING_STATUS_RESIST * 100), int(UNBREAKING_HP_THRESHOLD * 100)]
		TAUNT_MASTERY:
			return "Taunt skills last 1 extra turn"
		IRONBLOOD:
			return "+15% Phys Def, -5% Speed"
		BLOODTHIRST:
			return "Heal %d%% of physical damage dealt" % int(BLOODTHIRST_PERCENT * 100)
		# Notable — Mage
		ELEMENTAL_MASTERY:
			return "+%d%% damage vs element-weak enemies" % int(ELEMENTAL_MASTERY_BONUS * 100)
		SPELL_ECHO:
			return "%d%% chance for spells to trigger twice at %d%% damage" % [int(SPELL_ECHO_CHANCE * 100), int(SPELL_ECHO_DAMAGE_MULT * 100)]
		OVERCHARGED:
			return "Crit spells +%d%% Crit Dmg, spells cost +%d%% MP" % [int(OVERCHARGED_CRIT_BONUS * 100), int(OVERCHARGED_MANA_PENALTY * 100)]
		FOCUSED_MIND_COND:
			return "+%d%% Mag Atk when MP above %d%%" % [int(FOCUSED_MIND_BONUS * 100), int(FOCUSED_MIND_MP_THRESHOLD * 100)]
		CHAIN_REACTION:
			return "%d%% chance for status effects to spread" % int(CHAIN_REACTION_CHANCE * 100)
		ARCANE_SHIELD:
			return "+1 Mag Def per 10 unspent MP at turn start"
		RESONANCE:
			return "Same-element consecutive spells deal +%d%% damage" % int(RESONANCE_BONUS * 100)
		# Notable — Rogue
		AMBUSH:
			return "First attack each battle deals +%d%% damage" % int(AMBUSH_BONUS * 100)
		EXPLOIT_WEAKNESS:
			return "+%d%% damage vs enemies with status effects" % int(EXPLOIT_WEAKNESS_BONUS * 100)
		LUCKY_STRIKE:
			return "Crits have %d%% chance to drop bonus gold" % int(LUCKY_STRIKE_CHANCE * 100)
		SHADOWSTEP:
			return "After dodging, next attack +%d%% Crit Rate" % int(SHADOWSTEP_CRIT_BONUS * 100)
		POISON_MASTERY:
			return "Poison lasts 1 extra turn, +15% Poison damage"
		QUICK_HANDS:
			return "Item use doesn't cost turn (once per battle)"
		BLADE_FLURRY:
			return "Multi-hit skills +%d extra hit at %d%% damage" % [BLADE_FLURRY_EXTRA_HITS, int(BLADE_FLURRY_DAMAGE_MULT * 100)]
		TREASURE_SENSE:
			return "+%d%% rare drops, +%d%% gold" % [int(TREASURE_SENSE_DROP_BONUS * 100), int(TREASURE_SENSE_GOLD_BONUS * 100)]
		# Notable — Cross-path
		SPELL_SWORD:
			return "Phys Atk adds %d%% to Mag Atk" % int(SPELL_SWORD_RATIO * 100)
		BATTLE_MAGE:
			return "Mag Atk adds %d%% to Phys Atk" % int(BATTLE_MAGE_RATIO * 100)
		SHADOW_KNIGHT:
			return "Counter-attacks have +%d%% Crit Rate" % int(SHADOW_KNIGHT_CRIT_BONUS * 100)
		ARCANE_TRICKSTER:
			return "Spell status effects last 1 extra turn"
		# Keystones
		KS_IMMORTAL_FORTRESS:
			return "Survive lethal blow once (at %d%% HP). -%d%% Phys Atk." % [int(KS_IMMORTAL_FORTRESS_HP * 100), int(KS_IMMORTAL_FORTRESS_ATK_PENALTY * 100)]
		KS_BERSERKER_RAGE:
			return "+%d%% Phys Atk, +%d%% Crit Dmg. Cannot defend or be healed by allies." % [int(KS_BERSERKER_ATK_BONUS * 100), int(KS_BERSERKER_CRIT_BONUS * 100)]
		KS_ARCHMAGE:
			return "First spell each battle costs 0 MP. -%d%% Max HP." % int(KS_ARCHMAGE_HP_PENALTY * 100)
		KS_ELEMENTAL_OVERLOAD:
			return "+%d%% elemental damage. Non-elemental -%d%%." % [int(KS_ELEMENTAL_OVERLOAD_BONUS * 100), int(KS_ELEMENTAL_OVERLOAD_PENALTY * 100)]
		KS_PHANTOM:
			return "%d%% dodge chance. -%d%% Max HP." % [int(KS_PHANTOM_DODGE * 100), int(KS_PHANTOM_HP_PENALTY * 100)]
		KS_EXECUTIONER:
			return "+%d%% damage below %d%% HP. -%d%% above %d%%." % [int(KS_EXECUTIONER_BONUS * 100), int(KS_EXECUTIONER_THRESHOLD * 100), int(KS_EXECUTIONER_PENALTY * 100), int(KS_EXECUTIONER_PENALTY_THRESHOLD * 100)]
		KS_JACK_OF_ALL_TRADES:
			return "+%d%% all stats. No other Keystones." % int(KS_JACK_STAT_BONUS * 100)
		_:
			return effect_id


static func has_effect(effects: Array, effect_id: String) -> bool:
	for i in range(effects.size()):
		if effects[i] == effect_id:
			return true
	return false
