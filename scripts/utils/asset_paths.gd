class_name AssetPaths
## Centralized asset folder constants. Change paths here when reorganizing assets.
## This is a class_name script (not autoload) so it works everywhere.

# --- Material Library ---
const MATERIALS := "res://assets/3D/materials/"
const MATERIALS_NATURE := MATERIALS + "Nature/"
const WATER_NORMAL := MATERIALS_NATURE + "Water/Water-N.png"

# --- Terrain Textures ---
const TERRAIN_TEXTURES := "res://assets/terrain_textures/"

# --- Nature Kit (Stylized Nature MegaKit) ---
const NATURE_KIT := "res://assets/3D/nature/"

# --- Props Kit (Fantasy Props MegaKit) ---
const PROPS_KIT := "res://assets/3D/props/"

# --- Buildings ---
const VILLAGE_KIT := "res://assets/3D/buildings/village_kit/"
const BUILDING_PREFABS := "res://assets/3D/buildings/prefabs/"

# --- Characters ---
const CHARACTER_BASE := "res://assets/3D/characters/base/"
const CHARACTER_OUTFITS := "res://assets/3D/characters/outfits/"
const CHARACTER_HAIRSTYLES := "res://assets/3D/characters/hairstyles/"

# --- Animation Libraries ---
const UAL1 := "res://assets/3D/animations/UAL1.glb"
const UAL2 := "res://assets/3D/animations/UAL2.glb"

# --- Animals ---
const ANIMALS := "res://assets/3D/animals/"

# --- Skybox ---
const SKYBOX := "res://assets/3D/skybox/"

# --- Default weapon/equipment models by EquipmentCategory ---
# Used when ItemData.model_path is empty. Maps Enums.EquipmentCategory → model path.
const _P := PROPS_KIT
const DEFAULT_EQUIPMENT_MODELS: Dictionary = {
	# Weapons
	0: _P + "Sword_Steel.gltf",         # SWORD
	1: _P + "Hammer_Medium_Steel.gltf",  # MACE
	2: "",                                # BOW (no bow model in props)
	3: "",                                # STAFF (no staff model in props)
	4: _P + "Dagger_Steel_Steel.gltf",   # DAGGER
	5: _P + "Shield_Metal.gltf",         # SHIELD
	6: _P + "Axe_Steel.gltf",            # AXE
	# Armor (no 3D models yet)
	7: "",   # HELMET
	8: "",   # CHESTPLATE
	9: "",   # GLOVES
	10: "",  # LEGS
	11: "",  # BOOTS
	12: "",  # NECKLACE
	13: "",  # RING
}

# Tier variants: bronze versions for lower-rarity items
const BRONZE_WEAPON_MODELS: Dictionary = {
	0: _P + "Sword_Bronze.gltf",          # SWORD
	1: _P + "Hammer_Medium_Bronze.gltf",   # MACE
	4: _P + "Dagger_Bronze.gltf",          # DAGGER
	6: _P + "Axe_Bronze.gltf",             # AXE
}
