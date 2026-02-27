class_name Enums
## Central enum definitions for the entire game.
## Usage: Enums.ItemType.ACTIVE_TOOL, Enums.Rarity.COMMON, etc.

# === ITEMS ===

enum ItemType {
	ACTIVE_TOOL,    ## Weapons/tools that can be modified by gems
	PASSIVE_GEAR,   ## Armor/accessories providing passive effects
	MODIFIER,       ## Gems that enhance adjacent active tools
	CONSUMABLE,     ## Single-use items (potions, scrolls)
	MATERIAL,       ## Crafting materials
	BLUEPRINT,      ## Unlocks a crafting recipe when used; id must match the recipe's unlock_flag
}

enum Rarity {
	COMMON,         ## White - T1
	UNCOMMON,       ## Blue - T2
	RARE,           ## Gold - T3
	ELITE,          ## Orange - T4
	LEGENDARY,      ## Crimson - T5
	UNIQUE,         ## Purple - T6
}

enum EquipmentCategory {
	## Active (modifiable)
	SWORD,
	MACE,
	BOW,
	STAFF,
	DAGGER,
	SHIELD,
	AXE,
	## Passive (unmodifiable)
	HELMET,
	CHESTPLATE,
	GLOVES,
	LEGS,
	BOOTS,
	NECKLACE,
	RING,
}

enum WeaponType {
	MELEE,   ## Sword, Mace, Dagger, Axe, Shield
	RANGED,  ## Bow
	MAGIC,   ## Staff
}

# === STATS ===

enum Stat {
	MAX_HP,
	MAX_MP,
	SPEED,
	LUCK,
	PHYSICAL_ATTACK,
	PHYSICAL_DEFENSE,
	MAGICAL_ATTACK,
	MAGICAL_DEFENSE,
	CRITICAL_RATE,
	CRITICAL_DAMAGE,
	PHYSICAL_SCALING,
	MAGICAL_SCALING,
}

enum ModifierType {
	FLAT,           ## Added directly to stat
	PERCENT,        ## Multiplied after flat bonuses
}

# === ELEMENTS & DAMAGE ===

enum DamageType {
	PHYSICAL,
	MAGICAL,
}

# === COMBAT ===

enum CombatAction {
	ATTACK,
	DEFEND,
	SKILL,
	ITEM,
	FLEE,
}

enum TargetType {
	SELF,
	SINGLE_ALLY,
	SINGLE_ENEMY,
	ALL_ALLIES,
	ALL_ENEMIES,
	ALL,
}

enum PopupType {
	DAMAGE,
	HEAL,
	CRIT,
}

enum CombatState {
	INIT,
	TURN_START,
	ACTION_SELECT,
	ACTION_EXECUTE,
	TURN_END,
	VICTORY,
	DEFEAT,
}

# === STATUS EFFECTS ===

enum StatusEffectType {
	BURN,      ## Fire damage over time
	POISONED,  ## Poison damage over time
	CHILLED,   ## Ice: reduce speed
	SHOCKED,   ## Thunder: chance to skip turn
}

enum StatusCategory {
	DAMAGE_OVER_TIME,
	VULNERABILITY,
	STAT_MODIFICATION,
	ACTION_RESTRICTION,
	PROTECTION,
	IMMUNITY,
}

enum StatusInteraction {
	CANCEL,         ## One removes the other (freeze + burn)
	AMPLIFY,        ## One boosts damage (oil + fire)
	TRANSFORM,      ## Both become something new
	TRIGGER,        ## Immediate effect triggered
	IMMUNITY,       ## One prevents the other
}

# === SKILLS ===

enum SkillUsage {
	COMBAT,
	MENU,
	BOTH,
}

# === WORLD ===

enum InteractableType {
	CHEST,
	NPC,
	DOOR,
	ENEMY_ENCOUNTER,
	SHOP,
}

# === SHOP ===

enum ShopType {
	GENERAL_GOODS,
	EQUIPMENT,
	BLUEPRINTS,
	GRID_UPGRADES,
	SPECIAL,
}

enum PricingType {
	FIXED,
	TIER_BASED,
	DYNAMIC,
	NEGOTIABLE,
}


# === DISPLAY NAME HELPERS ===

static func get_item_type_name(itype: ItemType) -> String:
	match itype:
		ItemType.ACTIVE_TOOL: return "Active Tool"
		ItemType.PASSIVE_GEAR: return "Passive Gear"
		ItemType.MODIFIER: return "Modifier"
		ItemType.CONSUMABLE: return "Consumable"
		ItemType.MATERIAL: return "Material"
		ItemType.BLUEPRINT: return "Blueprint"
	return ""


static func get_item_type_short_name(itype: ItemType) -> String:
	match itype:
		ItemType.ACTIVE_TOOL: return "Tool"
		ItemType.PASSIVE_GEAR: return "Gear"
		ItemType.MODIFIER: return "Gem"
		ItemType.CONSUMABLE: return "Consumable"
		ItemType.MATERIAL: return "Material"
		ItemType.BLUEPRINT: return "Blueprint"
	return ""


static func get_equipment_category_name(category: EquipmentCategory) -> String:
	match category:
		EquipmentCategory.SWORD: return "Sword"
		EquipmentCategory.MACE: return "Mace"
		EquipmentCategory.BOW: return "Bow"
		EquipmentCategory.STAFF: return "Staff"
		EquipmentCategory.DAGGER: return "Dagger"
		EquipmentCategory.SHIELD: return "Shield"
		EquipmentCategory.AXE: return "Axe"
		EquipmentCategory.HELMET: return "Helmet"
		EquipmentCategory.CHESTPLATE: return "Chestplate"
		EquipmentCategory.GLOVES: return "Gloves"
		EquipmentCategory.LEGS: return "Legs"
		EquipmentCategory.BOOTS: return "Boots"
		EquipmentCategory.NECKLACE: return "Necklace"
		EquipmentCategory.RING: return "Ring"
	return "Unknown"


static func get_damage_type_name(dtype: DamageType) -> String:
	match dtype:
		DamageType.PHYSICAL: return "Physical"
		DamageType.MAGICAL: return "Magical"
	return "Unknown"


static func get_stat_name(stat: Stat) -> String:
	match stat:
		Stat.MAX_HP: return "Max HP"
		Stat.MAX_MP: return "Max MP"
		Stat.PHYSICAL_ATTACK: return "Phys Atk"
		Stat.PHYSICAL_DEFENSE: return "Phys Def"
		Stat.MAGICAL_ATTACK: return "Mag Atk"
		Stat.MAGICAL_DEFENSE: return "Magical Def"
		Stat.SPEED: return "Speed"
		Stat.LUCK: return "Luck"
		Stat.CRITICAL_RATE: return "Crit Rate"
		Stat.CRITICAL_DAMAGE: return "Crit Dmg"
		Stat.PHYSICAL_SCALING: return "Phys Scaling"
		Stat.MAGICAL_SCALING: return "Mag Scaling"
	return "Unknown"


static func get_status_effect_name(effect_type: StatusEffectType) -> String:
	match effect_type:
		StatusEffectType.BURN: return "Burn"
		StatusEffectType.POISONED: return "Poisoned"
		StatusEffectType.CHILLED: return "Chilled"
		StatusEffectType.SHOCKED: return "Shocked"
	return "Unknown"


static func get_weapon_type_name(wtype: WeaponType) -> String:
	match wtype:
		WeaponType.MELEE: return "Melee Weapons"
		WeaponType.RANGED: return "Ranged Weapons"
		WeaponType.MAGIC: return "Magic Weapons"
	return "Unknown"
