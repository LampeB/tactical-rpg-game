class_name ConditionalModifierRule
extends Resource
## Context-sensitive modifier effect applied when placed near specific tool categories.
## Example: Fire Gem + Sword → FIRE damage type, Fire Gem + Staff → Fire Bolt skill

@export var target_category: Enums.EquipmentCategory = Enums.EquipmentCategory.SWORD
@export var stat_bonuses: Array = []  ## of StatModifier
@export var override_damage_type: bool = false
@export var damage_type: Enums.DamageType = Enums.DamageType.FIRE
@export var granted_skills: Array = []  ## of SkillData
