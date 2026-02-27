class_name SkillData
extends Resource
## Definition of a skill (attack, spell, item use effect, etc.)

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Usage")
@export var usage: Enums.SkillUsage = Enums.SkillUsage.COMBAT
@export var mp_cost: int = 0
@export var cooldown_turns: int = 0

@export_group("Targeting")
@export var target_type: Enums.TargetType = Enums.TargetType.SINGLE_ENEMY

@export_group("Damage")
## How much this skill scales with physical damage (weapon power + stat).
@export var physical_scaling: float = 0.0
## How much this skill scales with magical damage (weapon power + stat).
@export var magical_scaling: float = 0.0
## If true, consumes ALL remaining MP. Damage = mp_spent * mp_damage_ratio.
@export var use_all_mp: bool = false
## Damage multiplier per MP spent (only used when use_all_mp is true).
@export var mp_damage_ratio: float = 0.0

@export_group("Effects")
## Status effects applied on hit.
@export var applied_statuses: Array[StatusEffectData] = []
## Healing amount (flat).
@export var heal_amount: int = 0
## Healing as percentage of max HP.
@export var heal_percent: float = 0.0


func has_damage() -> bool:
	return physical_scaling > 0.0 or magical_scaling > 0.0 or (use_all_mp and mp_damage_ratio > 0.0)
