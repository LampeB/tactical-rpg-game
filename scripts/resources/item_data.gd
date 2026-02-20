class_name ItemData
extends Resource
## Definition of an item type. Instances of items in-game reference this.

@export_group("Identity")
@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D

@export_group("Classification")
@export var item_type: Enums.ItemType = Enums.ItemType.ACTIVE_TOOL
@export var category: Enums.EquipmentCategory = Enums.EquipmentCategory.SWORD
@export var rarity: Enums.Rarity = Enums.Rarity.COMMON

@export_group("Shape")
@export var shape: ItemShape

@export_group("Stats")
## Direct stat bonuses this item provides when equipped.
@export var stat_modifiers: Array = [] ## of StatModifier

@export_group("Combat")
## Element for damage-dealing active tools.
@export var damage_type: Enums.DamageType = Enums.DamageType.PHYSICAL
## Base damage for active tools.
@export var base_power: int = 0
## Skills granted by this item when equipped.
@export var granted_skills: Array = [] ## of SkillData

@export_group("Modifier")
## For gems: how many cells away the modifier reaches.
@export var modifier_reach: int = 1
## For gems: stat bonuses applied to adjacent active tools.
@export var modifier_bonuses: Array = [] ## of StatModifier
## For gems: context-sensitive effects based on neighboring item categories.
@export var conditional_modifier_rules: Array = [] ## of ConditionalModifierRule

@export_group("Consumable")
## For consumables: the skill triggered on use.
@export var use_skill: SkillData

@export_group("Economy")
@export var base_price: int = 10

func get_sell_price() -> int:
	return int(base_price * 0.5)
