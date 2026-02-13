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
	## Passive (unmodifiable)
	HELMET,
	CHESTPLATE,
	BOOTS,
	RING,
}

# === STATS ===

enum Stat {
	MAX_HP,
	MAX_MP,
	SPEED,
	LUCK,
	PHYSICAL_ATTACK,
	PHYSICAL_DEFENSE,
	SPECIAL_ATTACK,
	SPECIAL_DEFENSE,
	CRITICAL_RATE,
	CRITICAL_DAMAGE,
}

enum ModifierType {
	FLAT,           ## Added directly to stat
	PERCENT,        ## Multiplied after flat bonuses
}

# === ELEMENTS & DAMAGE ===

enum DamageType {
	PHYSICAL,
	FIRE,
	ICE,
	THUNDER,
	POISON,
	WATER,
	EARTH,
	WIND,
	SPIRIT,
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
