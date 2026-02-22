class_name ConditionalModifierRule
extends Resource
## Context-sensitive modifier effect applied when placed near specific weapon types.
## Example: Fire Gem + Melee → adds magical damage + burn, Fire Gem + Magic → Fire Bolt skill

@export var target_weapon_type: Enums.WeaponType = Enums.WeaponType.MELEE
@export var stat_bonuses: Array = []  ## of StatModifier
@export var status_effect: StatusEffect = null  ## Which status effect this applies
@export var status_effect_chance: float = 0.15  ## Chance to apply status effect (0.0 to 1.0)
@export var granted_skills: Array = []  ## of SkillData
@export var force_aoe: bool = false  ## If true, all attacks with this weapon hit all enemies
@export var hp_cost_per_attack: int = 0  ## HP lost by the attacker on each basic attack
