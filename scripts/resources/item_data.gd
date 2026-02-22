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

@export_group("Equipment Slots")
## How many hand slots this weapon requires (1 for one-handed, 2 for two-handed, 0 for non-weapons)
@export_range(0, 2) var hand_slots_required: int = 0
## For armor: which armor slot this occupies (HELMET, CHESTPLATE, BOOTS, RING, or NONE)
@export var armor_slot: Enums.EquipmentCategory = Enums.EquipmentCategory.HELMET
## Number of additional hand slots this item grants when equipped (for mechanical arms, etc.)
@export var bonus_hand_slots: int = 0

@export_group("Shape")
@export var shape: ItemShape

@export_group("Stats")
## Direct stat bonuses this item provides when equipped.
@export var stat_modifiers: Array = [] ## of StatModifier

@export_group("Combat")
## Base physical damage for active tools.
@export var base_power: int = 0
## Base magical damage for active tools.
@export var magical_power: int = 0
## Skills granted by this item when equipped.
@export var granted_skills: Array = [] ## of SkillData

@export_group("Modifier")
## For gems: how many cells away the modifier reaches (Manhattan distance fallback).
@export var modifier_reach: int = 1
## For gems: custom reach pattern as cell offsets. If non-empty, overrides modifier_reach.
@export var modifier_reach_pattern: Array[Vector2i] = []
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

func get_reach_cells(rotations: int = 0) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if not modifier_reach_pattern.is_empty():
		cells = modifier_reach_pattern.duplicate()
	else:
		# Fallback: generate diamond from modifier_reach
		for dy in range(-modifier_reach, modifier_reach + 1):
			for dx in range(-modifier_reach, modifier_reach + 1):
				var dist: int = absi(dx) + absi(dy)
				if dist > 0 and dist <= modifier_reach:
					cells.append(Vector2i(dx, dy))
	# Rotate offsets (90° clockwise: (x,y) → (-y,x))
	for _r in range(rotations % 4):
		var rotated: Array[Vector2i] = []
		for cell in cells:
			rotated.append(Vector2i(-cell.y, cell.x))
		cells = rotated
	return cells


func get_weapon_type() -> Enums.WeaponType:
	match category:
		Enums.EquipmentCategory.SWORD, \
		Enums.EquipmentCategory.MACE, \
		Enums.EquipmentCategory.DAGGER, \
		Enums.EquipmentCategory.AXE, \
		Enums.EquipmentCategory.SHIELD:
			return Enums.WeaponType.MELEE
		Enums.EquipmentCategory.BOW:
			return Enums.WeaponType.RANGED
		Enums.EquipmentCategory.STAFF:
			return Enums.WeaponType.MAGIC
		_:
			return Enums.WeaponType.MELEE  # Default fallback
