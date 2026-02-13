class_name Constants
## Central constants and magic numbers for the game.

# === GRID ===
const GRID_CELL_SIZE := 48          ## Pixel size of one inventory cell
const GRID_MAX_WIDTH := 12          ## Maximum grid width
const GRID_MAX_HEIGHT := 12         ## Maximum grid height

# === COMBAT ===
const BASE_CRITICAL_RATE := 0.05    ## 5% base crit chance
const BASE_CRITICAL_DAMAGE := 1.5   ## 150% crit damage multiplier
const MAX_CRITICAL_RATE := 0.95     ## 95% cap (always 5% chance to not crit)
const LUCK_CRIT_SCALING := 0.001   ## Each luck point = +0.1% crit rate
const DEFEND_DAMAGE_REDUCTION := 0.5 ## 50% damage reduction when defending

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
