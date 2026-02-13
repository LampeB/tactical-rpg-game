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
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
@export var power: int = 0
## Scaling factor for the relevant attack stat.
@export var scaling: float = 1.0

@export_group("Effects")
## Status effects applied on hit.
@export var applied_statuses: Array = [] ## of StatusEffectData
## Healing amount (flat).
@export var heal_amount: int = 0
## Healing as percentage of max HP.
@export var heal_percent: float = 0.0
