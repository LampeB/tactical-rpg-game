class_name Constants
## Central constants and magic numbers for the game.

# === GRID ===
const GRID_CELL_SIZE := 48          ## Pixel size of one inventory cell
const GRID_MAX_WIDTH := 12          ## Maximum grid width
const GRID_MAX_HEIGHT := 12         ## Maximum grid height

# === BACKPACK TIERS ===
const BACKPACK_TIER_COUNT := 6
const SPATIAL_RUNE_ITEM_ID := "spatial_rune"

# === COMBAT ===
const BASE_CRITICAL_RATE := 0.05    ## 5% base crit chance
const BASE_CRITICAL_DAMAGE := 1.5   ## 150% crit damage multiplier
const MAX_CRITICAL_RATE := 0.95     ## 95% cap (always 5% chance to not crit)
const LUCK_CRIT_SCALING := 0.001   ## Each luck point = +0.1% crit rate
const DEFEND_DAMAGE_REDUCTION := 0.5 ## 50% damage reduction when defending
const TURN_TIME_BASE := 100.0       ## ATB turn time divisor (time_increment = BASE / speed)
const ENEMY_SKILL_CHANCE := 0.6     ## 60% chance for enemy AI to use a skill vs basic attack

# === TIER SCALING ===
const TIER_BASE_POWER := [5, 8, 13, 21, 35, 50]
const TIER_PRICE_MULTIPLIER := [1.0, 2.5, 6.0, 15.0, 40.0, 100.0]

# === ECONOMY ===
const STARTING_GOLD := 100

# === PARTY ===
const MAX_SQUAD_SIZE := 4           ## Active party members in combat
const MAX_ROSTER_SIZE := 12         ## Total characters in roster
const MAX_STASH_SLOTS := 100        ## Items in shared stash

# === WORLD ===
const PLAYER_SPEED := 200.0         ## Pixels per second
const INTERACTION_RANGE := 48.0     ## Pixels
const CAMERA_SMOOTH_SPEED := 5.0

# === 3D CAMERA ===
const CAMERA_ORBIT_SPEED := 0.3			## Degrees per pixel of mouse movement
const CAMERA_ZOOM_SPEED := 2.0			## Units per scroll tick
const CAMERA_MIN_DISTANCE := 8.0
const CAMERA_MAX_DISTANCE := 40.0
const CAMERA_DEFAULT_DISTANCE := 20.0
const CAMERA_DEFAULT_PITCH := -45.0		## Degrees (isometric-ish default)
const CAMERA_DEFAULT_YAW := 0.0
const CAMERA_SMOOTH_WEIGHT := 10.0
const CAMERA_PITCH_MIN := -80.0			## Prevent flipping under ground
const CAMERA_PITCH_MAX := 10.0

# === 3D CHARACTER COLORS ===
const CHARACTER_CLASS_COLORS := {
	"Warrior": Color(0.2, 0.4, 0.8),		# Blue steel
	"Mage": Color(0.6, 0.2, 0.8),			# Purple
	"Rogue": Color(0.2, 0.6, 0.3),			# Green
}
const CHARACTER_DEFAULT_COLOR := Color(0.5, 0.5, 0.5)

# === COLORS (for rarity display) ===
const RARITY_COLORS := {
	Enums.Rarity.COMMON: Color.WHITE,
	Enums.Rarity.UNCOMMON: Color(0.2, 0.6, 1.0),      # Blue
	Enums.Rarity.RARE: Color(1.0, 0.84, 0.0),          # Gold
	Enums.Rarity.ELITE: Color(1.0, 0.5, 0.0),          # Orange
	Enums.Rarity.LEGENDARY: Color(0.86, 0.08, 0.24),   # Crimson
	Enums.Rarity.UNIQUE: Color(0.6, 0.2, 0.8),         # Purple
}

const RARITY_NAMES := {
	Enums.Rarity.COMMON: "Common",
	Enums.Rarity.UNCOMMON: "Uncommon",
	Enums.Rarity.RARE: "Rare",
	Enums.Rarity.ELITE: "Elite",
	Enums.Rarity.LEGENDARY: "Legendary",
	Enums.Rarity.UNIQUE: "Unique",
}

# === UI COLORS ===
## Text colors for labels and UI elements
const COLOR_TEXT_PRIMARY := Color(0.8, 0.8, 0.8)      ## Primary text (light grey)
const COLOR_TEXT_SECONDARY := Color(0.7, 0.7, 0.7)    ## Secondary text (grey)
const COLOR_TEXT_HEADER := Color(0.9, 0.9, 1.0)       ## Header text (blue-white)
const COLOR_TEXT_FADED := Color(0.5, 0.5, 0.5)        ## Disabled/faded text
const COLOR_TEXT_EMPHASIS := Color(0.4, 0.8, 1.0)     ## Emphasis/link (blue)
const COLOR_TEXT_SUCCESS := Color(0.2, 0.8, 0.3)      ## Success/positive (green)
const COLOR_TEXT_IMPORTANT := Color(1.0, 0.9, 0.5)    ## Important/gold
const COLOR_TEXT_SKILL := Color(0.8, 1.0, 0.8)        ## Skill text (light green)
const COLOR_TEXT_MODIFIER := Color(1.0, 0.8, 0.5)     ## Modifier text (orange)

## HP/MP bar colors
const COLOR_HP_HIGH := Color(0.4, 1.0, 0.4)           ## High HP (green)
const COLOR_HP_MID := Color(1.0, 0.8, 0.2)            ## Medium HP (yellow)
const COLOR_HP_LOW := Color(1.0, 0.3, 0.3)            ## Low HP (red)
const COLOR_MP := Color(0.4, 0.6, 1.0)                ## MP bar (blue)
const COLOR_DEAD := Color(0.5, 0.5, 0.5, 0.6)         ## Dead entity (grey)

## Combat feedback colors
const COLOR_DAMAGE := Color(1.0, 0.3, 0.3)            ## Damage (red)
const COLOR_HEAL := Color(0.3, 1.0, 0.3)              ## Healing (green)
const COLOR_CRIT := Color(1.0, 0.84, 0.0)             ## Critical/gold
const COLOR_DEATH_MSG := Color(1.0, 0.5, 0.5)         ## Death message (light red)

## Combat log colors
const COLOR_LOG_DEBUG := Color(0.6, 0.6, 0.6)         ## Debug/system messages
const COLOR_LOG_BUFF := Color(0.4, 0.8, 1.0)          ## Buffs/shield (cyan-blue)
const COLOR_LOG_STATUS := Color(1.0, 0.6, 0.2)        ## Status effects (orange)
const COLOR_LOG_DODGE := Color(0.4, 0.9, 1.0)         ## Dodge (bright cyan)
const COLOR_LOG_LIFESTEAL := Color(0.6, 1.0, 0.6)     ## Lifesteal (light green)
const COLOR_LOG_THORNS := Color(0.8, 0.5, 0.2)        ## Thorns (brown-orange)
const COLOR_LOG_COUNTER := Color(1.0, 0.7, 0.3)       ## Counter-attack (orange-gold)
const COLOR_LOG_DEFENSE := Color(0.5, 0.8, 1.0)       ## Defense stance (light blue)
const COLOR_LOG_SKILL := Color(1.0, 0.9, 0.3)         ## Skill damage (gold)
const COLOR_LOG_FLEE := Color(0.8, 0.8, 0.8)          ## Flee (light grey)
const COLOR_LOG_MANA := Color(0.4, 0.6, 1.0)          ## Mana regen (blue)
const COLOR_LOG_STATUS_DMG := Color(0.8, 0.4, 0.8)    ## Status damage (purple)
const COLOR_LOG_STATUS_MSG := Color(0.7, 0.7, 0.7)    ## Status message (grey)
const COLOR_LOG_DEFEAT := Color(1.0, 0.2, 0.2)        ## Defeat (bright red)

## Drag & drop colors
const COLOR_DRAG_VALID := Color(0.2, 1.0, 0.2, 0.6)   ## Valid drag target (green)
const COLOR_DRAG_INVALID := Color(1.0, 0.2, 0.2, 0.6) ## Invalid drag target (red)

## Status bar highlights
const COLOR_HIGHLIGHT_ACTIVE := Color(1.3, 1.3, 0.9)  ## Active turn (bright yellow)
const COLOR_HIGHLIGHT_HOVER := Color(1.15, 1.15, 1.0) ## Hovered (subtle)
const COLOR_HIGHLIGHT_TARGET := Color(1.2, 0.8, 0.8)  ## Targeted (red tint)

# === FONT SIZES ===
const FONT_SIZE_TINY := 12          ## Status icons, very small text
const FONT_SIZE_SMALL := 14         ## Descriptions, footnotes
const FONT_SIZE_DETAIL := 16        ## Detail text, tooltips
const FONT_SIZE_BODY := 17          ## Standard body text
const FONT_SIZE_NORMAL := 18        ## Normal UI text
const FONT_SIZE_HEADER := 20        ## Section headers, item names
const FONT_SIZE_TITLE := 24         ## Screen titles
const FONT_SIZE_POPUP := 26         ## Damage popups
const FONT_SIZE_POPUP_CRIT := 32    ## Critical damage popups
const FONT_SIZE_MENU_TITLE := 56    ## Main menu title
