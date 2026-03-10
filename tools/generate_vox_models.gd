@tool
extends EditorScript
## Generates placeholder voxel models for all game objects.
## Run via: Godot Editor → File → Run (with this script open).
## Output: assets/voxels/{characters,enemies,npcs,world}/*.vox

# === Shared Palette ===

enum P {
	SKIN_LIGHT,      # 0
	SKIN_DARK,       # 1
	HAIR_BROWN,      # 2
	HAIR_BLACK,      # 3
	HAIR_BLONDE,     # 4
	BLUE_STEEL,      # 5  — Warrior
	BLUE_DARK,       # 6
	PURPLE_MAGE,     # 7  — Mage
	PURPLE_DARK,     # 8
	GREEN_ROGUE,     # 9  — Rogue
	GREEN_DARK,      # 10
	BROWN_LEATHER,   # 11 — Merchant
	BROWN_DARK,      # 12
	GREY_METAL,      # 13 — Blacksmith
	GREY_DARK,       # 14
	GOLD_ACCENT,     # 15
	WHITE_CLOTH,     # 16 — Doctor
	RED_CROSS,       # 17
	SLIME_GREEN,     # 18
	SLIME_DARK,      # 19
	EYE_WHITE,       # 20
	EYE_BLACK,       # 21
	GOBLIN_GREEN,    # 22
	MINOTAUR_BROWN,  # 23
	MINOTAUR_HORN,   # 24
	TREE_TRUNK,      # 25
	FOLIAGE_GREEN,   # 26
	FOLIAGE_LIGHT,   # 27
	ROCK_GREY,       # 28
	ROCK_LIGHT,      # 29
	BUSH_GREEN,      # 30
	FENCE_BROWN,     # 31
	SIGN_BOARD,      # 32
	FLOWER_RED,      # 33
	FLOWER_YELLOW,   # 34
	STEM_GREEN,      # 35
	GRASS_GREEN,     # 36
	WEAVER_TEAL,     # 37
	BOOT_BROWN,      # 38
	BAT_BROWN,       # 39
	BAT_WING,        # 40
	WOLF_GREY,       # 41
	WOLF_DARK,       # 42
	SPIDER_BROWN,    # 43
	SPIDER_RED,      # 44
	BONE_WHITE,      # 45
	BONE_DARK,       # 46
	BANDIT_RED,      # 47
	BANDIT_DARK,     # 48
	ORC_GREEN,       # 49
	ORC_DARK,        # 50
	MAGE_PURPLE,     # 51
	MAGE_DARK_ROBE,  # 52
	WRAITH_BLUE,     # 53
	WRAITH_DARK,     # 54
	TROLL_GREEN,     # 55
	TROLL_DARK,      # 56
	ELEMENTAL_GREEN,  # 57
	ELEMENTAL_GLOW,  # 58
	FIRE_ORANGE,     # 59
}

var _palette: Array[Color] = [
	Color(0.93, 0.76, 0.60),  # SKIN_LIGHT
	Color(0.78, 0.60, 0.45),  # SKIN_DARK
	Color(0.40, 0.25, 0.10),  # HAIR_BROWN
	Color(0.15, 0.12, 0.10),  # HAIR_BLACK
	Color(0.90, 0.75, 0.40),  # HAIR_BLONDE
	Color(0.20, 0.40, 0.80),  # BLUE_STEEL
	Color(0.15, 0.30, 0.60),  # BLUE_DARK
	Color(0.60, 0.20, 0.80),  # PURPLE_MAGE
	Color(0.40, 0.15, 0.55),  # PURPLE_DARK
	Color(0.20, 0.60, 0.30),  # GREEN_ROGUE
	Color(0.15, 0.45, 0.20),  # GREEN_DARK
	Color(0.55, 0.35, 0.20),  # BROWN_LEATHER
	Color(0.40, 0.25, 0.12),  # BROWN_DARK
	Color(0.50, 0.50, 0.50),  # GREY_METAL
	Color(0.35, 0.35, 0.35),  # GREY_DARK
	Color(0.80, 0.70, 0.20),  # GOLD_ACCENT
	Color(0.90, 0.88, 0.85),  # WHITE_CLOTH
	Color(0.85, 0.15, 0.15),  # RED_CROSS
	Color(0.20, 0.80, 0.20),  # SLIME_GREEN
	Color(0.15, 0.60, 0.15),  # SLIME_DARK
	Color(0.95, 0.95, 0.95),  # EYE_WHITE
	Color(0.10, 0.10, 0.10),  # EYE_BLACK
	Color(0.30, 0.60, 0.20),  # GOBLIN_GREEN
	Color(0.50, 0.30, 0.15),  # MINOTAUR_BROWN
	Color(0.75, 0.65, 0.45),  # MINOTAUR_HORN
	Color(0.40, 0.25, 0.10),  # TREE_TRUNK
	Color(0.20, 0.50, 0.15),  # FOLIAGE_GREEN
	Color(0.30, 0.60, 0.20),  # FOLIAGE_LIGHT
	Color(0.45, 0.42, 0.40),  # ROCK_GREY
	Color(0.55, 0.50, 0.45),  # ROCK_LIGHT
	Color(0.18, 0.40, 0.12),  # BUSH_GREEN
	Color(0.45, 0.30, 0.15),  # FENCE_BROWN
	Color(0.55, 0.40, 0.20),  # SIGN_BOARD
	Color(0.85, 0.15, 0.15),  # FLOWER_RED
	Color(0.90, 0.80, 0.15),  # FLOWER_YELLOW
	Color(0.20, 0.45, 0.10),  # STEM_GREEN
	Color(0.25, 0.50, 0.15),  # GRASS_GREEN
	Color(0.20, 0.50, 0.50),  # WEAVER_TEAL
	Color(0.35, 0.22, 0.10),  # BOOT_BROWN
	Color(0.40, 0.28, 0.18),  # BAT_BROWN
	Color(0.30, 0.20, 0.12),  # BAT_WING
	Color(0.55, 0.55, 0.50),  # WOLF_GREY
	Color(0.35, 0.35, 0.30),  # WOLF_DARK
	Color(0.45, 0.30, 0.15),  # SPIDER_BROWN
	Color(0.70, 0.15, 0.10),  # SPIDER_RED
	Color(0.85, 0.82, 0.75),  # BONE_WHITE
	Color(0.65, 0.60, 0.50),  # BONE_DARK
	Color(0.60, 0.15, 0.15),  # BANDIT_RED
	Color(0.25, 0.20, 0.18),  # BANDIT_DARK
	Color(0.35, 0.50, 0.20),  # ORC_GREEN
	Color(0.25, 0.38, 0.12),  # ORC_DARK
	Color(0.45, 0.15, 0.55),  # MAGE_PURPLE
	Color(0.20, 0.10, 0.28),  # MAGE_DARK_ROBE
	Color(0.40, 0.55, 0.75),  # WRAITH_BLUE
	Color(0.20, 0.30, 0.50),  # WRAITH_DARK
	Color(0.30, 0.45, 0.20),  # TROLL_GREEN
	Color(0.22, 0.35, 0.12),  # TROLL_DARK
	Color(0.25, 0.60, 0.30),  # ELEMENTAL_GREEN
	Color(0.50, 0.90, 0.40),  # ELEMENTAL_GLOW
	Color(0.90, 0.45, 0.10),  # FIRE_ORANGE
]


# === Shape Helpers ===

static func filled_box(
	voxels: Dictionary,
	x0: int, y0: int, z0: int,
	x1: int, y1: int, z1: int,
	color_idx: int,
) -> void:
	for x in range(x0, x1 + 1):
		for y in range(y0, y1 + 1):
			for z in range(z0, z1 + 1):
				voxels[Vector3i(x, y, z)] = color_idx


static func filled_sphere(
	voxels: Dictionary,
	cx: int, cy: int, cz: int,
	radius: float,
	color_idx: int,
) -> void:
	var r_int := int(ceil(radius))
	var r2 := radius * radius
	for x in range(cx - r_int, cx + r_int + 1):
		for y in range(cy - r_int, cy + r_int + 1):
			for z in range(cz - r_int, cz + r_int + 1):
				var dx := float(x - cx)
				var dy := float(y - cy)
				var dz := float(z - cz)
				if dx * dx + dy * dy + dz * dz <= r2:
					voxels[Vector3i(x, y, z)] = color_idx


static func filled_cylinder(
	voxels: Dictionary,
	cx: int, cz: int,
	y0: int, y1: int,
	radius: float,
	color_idx: int,
) -> void:
	var r_int := int(ceil(radius))
	var r2 := radius * radius
	for x in range(cx - r_int, cx + r_int + 1):
		for z in range(cz - r_int, cz + r_int + 1):
			var dx := float(x - cx)
			var dz := float(z - cz)
			if dx * dx + dz * dz <= r2:
				for y in range(y0, y1 + 1):
					voxels[Vector3i(x, y, z)] = color_idx


static func filled_ellipsoid(
	voxels: Dictionary,
	cx: int, cy: int, cz: int,
	rx: float, ry: float, rz: float,
	color_idx: int,
) -> void:
	var rx_int := int(ceil(rx))
	var ry_int := int(ceil(ry))
	var rz_int := int(ceil(rz))
	for x in range(cx - rx_int, cx + rx_int + 1):
		for y in range(cy - ry_int, cy + ry_int + 1):
			for z in range(cz - rz_int, cz + rz_int + 1):
				var dx := float(x - cx) / rx
				var dy := float(y - cy) / ry
				var dz := float(z - cz) / rz
				if dx * dx + dy * dy + dz * dz <= 1.0:
					voxels[Vector3i(x, y, z)] = color_idx


# === Model Builders ===

# -- Humanoid base template --
# Y=0 is feet. Standard height = 18 voxels (1.8 units at 0.1 voxel_size).
# cx = center X, cz = center Z (for symmetry).

static func _humanoid(
	voxels: Dictionary,
	cx: int, cz: int,
	body_color: int,
	arm_color: int,
	leg_color: int,
	skin_color: int,
	boot_color: int,
	torso_half_w: int,  # half-width of torso (2=narrow, 3=medium, 4=broad)
) -> void:
	var tw: int = torso_half_w
	# Feet / boots (Y=0..1)
	filled_box(voxels, cx - tw + 1, 0, cz - 1, cx - 1, 1, cz + 1, boot_color)
	filled_box(voxels, cx + 1, 0, cz - 1, cx + tw - 1, 1, cz + 1, boot_color)
	# Legs (Y=2..6)
	filled_box(voxels, cx - tw + 1, 2, cz - 1, cx - 1, 6, cz + 1, leg_color)
	filled_box(voxels, cx + 1, 2, cz - 1, cx + tw - 1, 6, cz + 1, leg_color)
	# Torso (Y=7..12)
	filled_box(voxels, cx - tw, 7, cz - 1, cx + tw, 12, cz + 1, body_color)
	# Arms (Y=7..12)
	filled_box(voxels, cx - tw - 2, 7, cz - 1, cx - tw - 1, 12, cz, arm_color)
	filled_box(voxels, cx + tw + 1, 7, cz - 1, cx + tw + 2, 12, cz, arm_color)
	# Hands (Y=7)
	voxels[Vector3i(cx - tw - 2, 7, cz)] = skin_color
	voxels[Vector3i(cx + tw + 2, 7, cz)] = skin_color
	# Neck (Y=13)
	filled_box(voxels, cx - 1, 13, cz, cx + 1, 13, cz, skin_color)
	# Head (Y=14..17)
	filled_box(voxels, cx - 2, 14, cz - 2, cx + 2, 17, cz + 2, skin_color)
	# Eyes (Y=16, front face)
	voxels[Vector3i(cx - 1, 16, cz + 2)] = P.EYE_BLACK
	voxels[Vector3i(cx + 1, 16, cz + 2)] = P.EYE_BLACK


# -- Characters --

func _build_kael() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BLUE_STEEL, P.BLUE_DARK, P.BLUE_DARK, P.SKIN_LIGHT, P.BOOT_BROWN, 3)
	# Brown hair (Y=17..18)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz - 1, P.HAIR_BROWN)
	filled_box(v, cx - 2, 18, cz - 2, cx + 2, 18, cz + 1, P.HAIR_BROWN)
	# Belt detail (Y=7, front)
	for x in range(cx - 3, cx + 4):
		v[Vector3i(x, 7, cz + 1)] = P.BROWN_DARK
	# Shoulder pads
	filled_box(v, cx - 5, 12, cz - 1, cx - 4, 13, cz + 1, P.GREY_METAL)
	filled_box(v, cx + 4, 12, cz - 1, cx + 5, 13, cz + 1, P.GREY_METAL)
	return v


func _build_lyra() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 4
	var cz: int = 3
	_humanoid(v, cx, cz, P.PURPLE_MAGE, P.PURPLE_DARK, P.PURPLE_DARK, P.SKIN_LIGHT, P.PURPLE_DARK, 2)
	# Robe extension (Y=2..6, wider skirt)
	filled_box(v, cx - 3, 2, cz - 2, cx + 3, 5, cz + 2, P.PURPLE_MAGE)
	# Blonde hair (Y=17..18)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 2, P.HAIR_BLONDE)
	# Pointed hat (Y=18..21)
	filled_box(v, cx - 2, 18, cz - 2, cx + 2, 19, cz + 2, P.PURPLE_DARK)
	filled_box(v, cx - 1, 20, cz - 1, cx + 1, 20, cz + 1, P.PURPLE_DARK)
	v[Vector3i(cx, 21, cz)] = P.PURPLE_DARK
	# Hat brim (Y=18)
	filled_box(v, cx - 3, 18, cz - 3, cx + 3, 18, cz + 3, P.PURPLE_MAGE)
	return v


func _build_vex() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 4
	var cz: int = 3
	_humanoid(v, cx, cz, P.GREEN_ROGUE, P.GREEN_DARK, P.GREEN_DARK, P.SKIN_DARK, P.BOOT_BROWN, 2)
	# Hood (covers head sides/back, Y=15..18)
	filled_box(v, cx - 3, 15, cz - 3, cx + 3, 18, cz - 2, P.GREEN_DARK)  # back
	filled_box(v, cx - 3, 15, cz - 2, cx - 2, 18, cz + 1, P.GREEN_DARK)  # left
	filled_box(v, cx + 2, 15, cz - 2, cx + 3, 18, cz + 1, P.GREEN_DARK)  # right
	filled_box(v, cx - 3, 18, cz - 3, cx + 3, 18, cz + 2, P.GREEN_DARK)  # top
	# Belt with gold buckle
	for x in range(cx - 2, cx + 3):
		v[Vector3i(x, 7, cz + 1)] = P.BROWN_DARK
	v[Vector3i(cx, 7, cz + 1)] = P.GOLD_ACCENT
	return v


# -- Enemies --

func _build_slime() -> Dictionary:
	var v: Dictionary = {}
	# Flattened ellipsoid body
	filled_ellipsoid(v, 5, 3, 5, 4.5, 3.0, 4.5, P.SLIME_GREEN)
	# Darker top
	filled_ellipsoid(v, 5, 5, 5, 3.0, 1.5, 3.0, P.SLIME_DARK)
	# Eyes (front face)
	v[Vector3i(3, 4, 8)] = P.EYE_WHITE
	v[Vector3i(7, 4, 8)] = P.EYE_WHITE
	v[Vector3i(3, 4, 9)] = P.EYE_BLACK
	v[Vector3i(7, 4, 9)] = P.EYE_BLACK
	return v


func _build_goblin() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 4
	var cz: int = 3
	# Smaller humanoid (12 voxels tall)
	# Feet (Y=0..1)
	filled_box(v, cx - 1, 0, cz - 1, cx, 1, cz, P.BROWN_DARK)
	filled_box(v, cx + 1, 0, cz - 1, cx + 2, 1, cz, P.BROWN_DARK)
	# Legs (Y=2..4)
	filled_box(v, cx - 1, 2, cz, cx, 4, cz + 1, P.BROWN_DARK)
	filled_box(v, cx + 1, 2, cz, cx + 2, 4, cz + 1, P.BROWN_DARK)
	# Torso (Y=5..7)
	filled_box(v, cx - 1, 5, cz - 1, cx + 2, 7, cz + 1, P.GOBLIN_GREEN)
	# Arms (Y=5..7)
	filled_box(v, cx - 3, 5, cz, cx - 2, 7, cz, P.GOBLIN_GREEN)
	filled_box(v, cx + 3, 5, cz, cx + 4, 7, cz, P.GOBLIN_GREEN)
	# Head (Y=8..11, big relative to body)
	filled_box(v, cx - 2, 8, cz - 2, cx + 3, 11, cz + 2, P.GOBLIN_GREEN)
	# Pointy ears
	v[Vector3i(cx - 3, 10, cz)] = P.GOBLIN_GREEN
	v[Vector3i(cx - 4, 10, cz)] = P.GOBLIN_GREEN
	v[Vector3i(cx + 4, 10, cz)] = P.GOBLIN_GREEN
	v[Vector3i(cx + 5, 10, cz)] = P.GOBLIN_GREEN
	# Eyes
	v[Vector3i(cx - 1, 10, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx + 2, 10, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx - 1, 10, cz + 3)] = P.EYE_BLACK
	v[Vector3i(cx + 2, 10, cz + 3)] = P.EYE_BLACK
	return v


func _build_minotaur() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 7
	var cz: int = 4
	# Large humanoid (25 voxels tall)
	# Hooves (Y=0..1)
	filled_box(v, cx - 3, 0, cz - 2, cx - 1, 1, cz + 2, P.BROWN_DARK)
	filled_box(v, cx + 1, 0, cz - 2, cx + 3, 1, cz + 2, P.BROWN_DARK)
	# Legs (Y=2..8)
	filled_box(v, cx - 3, 2, cz - 1, cx - 1, 8, cz + 1, P.MINOTAUR_BROWN)
	filled_box(v, cx + 1, 2, cz - 1, cx + 3, 8, cz + 1, P.MINOTAUR_BROWN)
	# Torso (Y=9..17, wide)
	filled_box(v, cx - 4, 9, cz - 2, cx + 4, 17, cz + 2, P.MINOTAUR_BROWN)
	# Arms (Y=10..17)
	filled_box(v, cx - 7, 10, cz - 1, cx - 5, 17, cz + 1, P.MINOTAUR_BROWN)
	filled_box(v, cx + 5, 10, cz - 1, cx + 7, 17, cz + 1, P.MINOTAUR_BROWN)
	# Head (Y=18..22)
	filled_box(v, cx - 3, 18, cz - 2, cx + 3, 22, cz + 2, P.MINOTAUR_BROWN)
	# Horns (Y=22..24, curving outward)
	v[Vector3i(cx - 4, 22, cz)] = P.MINOTAUR_HORN
	v[Vector3i(cx - 5, 23, cz)] = P.MINOTAUR_HORN
	v[Vector3i(cx - 5, 24, cz)] = P.MINOTAUR_HORN
	v[Vector3i(cx + 4, 22, cz)] = P.MINOTAUR_HORN
	v[Vector3i(cx + 5, 23, cz)] = P.MINOTAUR_HORN
	v[Vector3i(cx + 5, 24, cz)] = P.MINOTAUR_HORN
	# Eyes
	v[Vector3i(cx - 2, 21, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx + 2, 21, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx - 2, 21, cz + 3)] = P.EYE_BLACK
	v[Vector3i(cx + 2, 21, cz + 3)] = P.EYE_BLACK
	# Nose ring
	v[Vector3i(cx, 19, cz + 3)] = P.GOLD_ACCENT
	return v


func _build_bat() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 6
	var cz: int = 4
	# Small round body (Y=2..6)
	filled_ellipsoid(v, cx, 4, cz, 2.5, 2.5, 2.5, P.BAT_BROWN)
	# Head (Y=6..8, slightly protruding forward)
	filled_sphere(v, cx, 7, cz + 1, 2.0, P.BAT_BROWN)
	# Ears (pointed, on top of head)
	v[Vector3i(cx - 1, 9, cz + 1)] = P.BAT_BROWN
	v[Vector3i(cx - 1, 10, cz + 1)] = P.BAT_BROWN
	v[Vector3i(cx + 1, 9, cz + 1)] = P.BAT_BROWN
	v[Vector3i(cx + 1, 10, cz + 1)] = P.BAT_BROWN
	# Eyes (red, menacing)
	v[Vector3i(cx - 1, 8, cz + 3)] = P.SPIDER_RED
	v[Vector3i(cx + 1, 8, cz + 3)] = P.SPIDER_RED
	# Wings spread wide (Y=3..7, thin membrane)
	for y in range(3, 8):
		for x in range(cx - 8, cx - 2):
			v[Vector3i(x, y, cz)] = P.BAT_WING
		for x in range(cx + 3, cx + 9):
			v[Vector3i(x, y, cz)] = P.BAT_WING
	# Wing fingers (structural bones along top edge)
	for x in range(cx - 8, cx - 2):
		v[Vector3i(x, 7, cz)] = P.BAT_BROWN
	for x in range(cx + 3, cx + 9):
		v[Vector3i(x, 7, cz)] = P.BAT_BROWN
	# Tiny feet
	v[Vector3i(cx - 1, 1, cz)] = P.BAT_BROWN
	v[Vector3i(cx + 1, 1, cz)] = P.BAT_BROWN
	return v


func _build_wolf() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 6
	var cz: int = 5
	# Body — elongated horizontally (wolf is on all fours)
	# Using Z as the long axis (front-to-back)
	# Torso (Y=4..7, Z=2..8)
	filled_box(v, cx - 2, 4, cz - 3, cx + 2, 7, cz + 3, P.WOLF_GREY)
	# Darker back ridge
	filled_box(v, cx - 1, 7, cz - 2, cx + 1, 8, cz + 2, P.WOLF_DARK)
	# Front legs (Y=0..3)
	filled_box(v, cx - 2, 0, cz + 2, cx - 1, 3, cz + 3, P.WOLF_GREY)
	filled_box(v, cx + 1, 0, cz + 2, cx + 2, 3, cz + 3, P.WOLF_GREY)
	# Back legs (Y=0..3)
	filled_box(v, cx - 2, 0, cz - 3, cx - 1, 3, cz - 2, P.WOLF_GREY)
	filled_box(v, cx + 1, 0, cz - 3, cx + 2, 3, cz - 2, P.WOLF_GREY)
	# Head (Y=6..10, extending forward)
	filled_box(v, cx - 2, 6, cz + 4, cx + 2, 9, cz + 7, P.WOLF_GREY)
	# Snout (pointy)
	filled_box(v, cx - 1, 6, cz + 8, cx + 1, 8, cz + 9, P.WOLF_DARK)
	# Ears
	v[Vector3i(cx - 1, 10, cz + 5)] = P.WOLF_DARK
	v[Vector3i(cx + 1, 10, cz + 5)] = P.WOLF_DARK
	v[Vector3i(cx - 1, 11, cz + 5)] = P.WOLF_DARK
	v[Vector3i(cx + 1, 11, cz + 5)] = P.WOLF_DARK
	# Eyes
	v[Vector3i(cx - 2, 8, cz + 7)] = P.EYE_WHITE
	v[Vector3i(cx + 2, 8, cz + 7)] = P.EYE_WHITE
	# Nose
	v[Vector3i(cx, 7, cz + 10)] = P.EYE_BLACK
	# Tail (curving up)
	v[Vector3i(cx, 6, cz - 4)] = P.WOLF_DARK
	v[Vector3i(cx, 7, cz - 5)] = P.WOLF_DARK
	v[Vector3i(cx, 8, cz - 5)] = P.WOLF_DARK
	return v


func _build_spider() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 7
	var cz: int = 5
	# Round abdomen (back, large)
	filled_ellipsoid(v, cx, 4, cz - 2, 3.5, 2.5, 3.0, P.SPIDER_BROWN)
	# Red markings on abdomen
	v[Vector3i(cx, 5, cz - 3)] = P.SPIDER_RED
	v[Vector3i(cx - 1, 5, cz - 4)] = P.SPIDER_RED
	v[Vector3i(cx + 1, 5, cz - 4)] = P.SPIDER_RED
	# Cephalothorax (front, smaller)
	filled_ellipsoid(v, cx, 4, cz + 2, 2.5, 2.0, 2.0, P.SPIDER_BROWN)
	# Eyes (cluster of red dots on front)
	v[Vector3i(cx - 1, 5, cz + 4)] = P.SPIDER_RED
	v[Vector3i(cx + 1, 5, cz + 4)] = P.SPIDER_RED
	v[Vector3i(cx, 6, cz + 4)] = P.SPIDER_RED
	v[Vector3i(cx, 4, cz + 4)] = P.SPIDER_RED
	# Fangs
	v[Vector3i(cx - 1, 3, cz + 4)] = P.EYE_WHITE
	v[Vector3i(cx + 1, 3, cz + 4)] = P.EYE_WHITE
	# 8 legs (4 per side, arching outward then down)
	for i in range(4):
		var z_off: int = cz - 1 + i * 2
		# Left legs
		v[Vector3i(cx - 3, 4, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 4, 5, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 5, 5, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 6, 4, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 7, 3, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 7, 2, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx - 7, 1, z_off)] = P.SPIDER_BROWN
		# Right legs
		v[Vector3i(cx + 3, 4, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 4, 5, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 5, 5, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 6, 4, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 7, 3, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 7, 2, z_off)] = P.SPIDER_BROWN
		v[Vector3i(cx + 7, 1, z_off)] = P.SPIDER_BROWN
	return v


func _build_skeleton() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	# Skeleton is a humanoid made of bone
	# Feet (Y=0..1)
	filled_box(v, cx - 2, 0, cz - 1, cx - 1, 1, cz + 1, P.BONE_DARK)
	filled_box(v, cx + 1, 0, cz - 1, cx + 2, 1, cz + 1, P.BONE_DARK)
	# Thin leg bones (Y=2..6, single column each)
	filled_box(v, cx - 2, 2, cz, cx - 1, 6, cz, P.BONE_WHITE)
	filled_box(v, cx + 1, 2, cz, cx + 2, 6, cz, P.BONE_WHITE)
	# Pelvis (Y=7)
	filled_box(v, cx - 2, 7, cz - 1, cx + 2, 7, cz + 1, P.BONE_DARK)
	# Ribcage (Y=8..12, hollow-ish)
	filled_box(v, cx - 2, 8, cz - 1, cx + 2, 12, cz + 1, P.BONE_WHITE)
	# Hollow out center of ribcage (front)
	for y in range(9, 12):
		v[Vector3i(cx, y, cz + 1)] = P.BONE_DARK
	# Spine visible from front
	for y in range(8, 13):
		v[Vector3i(cx, y, cz - 1)] = P.BONE_DARK
	# Arms (thin bones, Y=8..12)
	filled_box(v, cx - 4, 8, cz, cx - 3, 12, cz, P.BONE_WHITE)
	filled_box(v, cx + 3, 8, cz, cx + 4, 12, cz, P.BONE_WHITE)
	# Hands
	v[Vector3i(cx - 4, 7, cz)] = P.BONE_DARK
	v[Vector3i(cx + 4, 7, cz)] = P.BONE_DARK
	# Neck (Y=13)
	v[Vector3i(cx, 13, cz)] = P.BONE_DARK
	# Skull (Y=14..17)
	filled_box(v, cx - 2, 14, cz - 2, cx + 2, 17, cz + 2, P.BONE_WHITE)
	# Eye sockets (dark)
	v[Vector3i(cx - 1, 16, cz + 2)] = P.EYE_BLACK
	v[Vector3i(cx + 1, 16, cz + 2)] = P.EYE_BLACK
	# Jaw detail
	filled_box(v, cx - 1, 14, cz + 2, cx + 1, 14, cz + 2, P.BONE_DARK)
	# Sword in right hand
	v[Vector3i(cx + 4, 6, cz)] = P.GREY_METAL
	v[Vector3i(cx + 4, 5, cz)] = P.GREY_METAL
	v[Vector3i(cx + 4, 4, cz)] = P.GREY_METAL
	v[Vector3i(cx + 4, 3, cz)] = P.GREY_METAL
	return v


func _build_bandit() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BANDIT_DARK, P.BANDIT_DARK, P.BANDIT_DARK, P.SKIN_DARK, P.BOOT_BROWN, 3)
	# Red bandana/hood (Y=16..18)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 2, P.BANDIT_RED)
	# Mask covering lower face (Y=14..15)
	filled_box(v, cx - 2, 14, cz + 2, cx + 2, 15, cz + 2, P.BANDIT_DARK)
	# Belt with gold buckle
	for x in range(cx - 3, cx + 4):
		v[Vector3i(x, 7, cz + 1)] = P.BROWN_DARK
	v[Vector3i(cx, 7, cz + 1)] = P.GOLD_ACCENT
	# Dagger in left hand
	v[Vector3i(cx - 5, 7, cz)] = P.GREY_METAL
	v[Vector3i(cx - 5, 6, cz)] = P.GREY_METAL
	v[Vector3i(cx - 5, 5, cz)] = P.GREY_METAL
	# Shoulder pauldron (asymmetric, left only)
	filled_box(v, cx - 5, 12, cz - 1, cx - 4, 13, cz + 1, P.BROWN_LEATHER)
	return v


func _build_orc() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 7
	var cz: int = 4
	# Larger humanoid (22 voxels tall, broad)
	# Hooves / boots (Y=0..1)
	filled_box(v, cx - 3, 0, cz - 2, cx - 1, 1, cz + 1, P.BROWN_DARK)
	filled_box(v, cx + 1, 0, cz - 2, cx + 3, 1, cz + 1, P.BROWN_DARK)
	# Legs (Y=2..7)
	filled_box(v, cx - 3, 2, cz - 1, cx - 1, 7, cz + 1, P.ORC_DARK)
	filled_box(v, cx + 1, 2, cz - 1, cx + 3, 7, cz + 1, P.ORC_DARK)
	# Torso (Y=8..15, wide)
	filled_box(v, cx - 4, 8, cz - 2, cx + 4, 15, cz + 2, P.ORC_GREEN)
	# Belly armor
	filled_box(v, cx - 3, 8, cz + 2, cx + 3, 12, cz + 2, P.BROWN_LEATHER)
	# Arms (Y=9..15, thick)
	filled_box(v, cx - 7, 9, cz - 1, cx - 5, 15, cz + 1, P.ORC_GREEN)
	filled_box(v, cx + 5, 9, cz - 1, cx + 7, 15, cz + 1, P.ORC_GREEN)
	# Fists
	filled_box(v, cx - 7, 8, cz - 1, cx - 5, 8, cz + 1, P.ORC_DARK)
	filled_box(v, cx + 5, 8, cz - 1, cx + 7, 8, cz + 1, P.ORC_DARK)
	# Neck (Y=16)
	filled_box(v, cx - 1, 16, cz - 1, cx + 1, 16, cz + 1, P.ORC_GREEN)
	# Head (Y=17..21)
	filled_box(v, cx - 3, 17, cz - 2, cx + 3, 21, cz + 2, P.ORC_GREEN)
	# Jaw (underbite with tusks)
	filled_box(v, cx - 2, 17, cz + 2, cx + 2, 18, cz + 3, P.ORC_DARK)
	# Tusks
	v[Vector3i(cx - 2, 19, cz + 3)] = P.BONE_WHITE
	v[Vector3i(cx + 2, 19, cz + 3)] = P.BONE_WHITE
	# Eyes (angry)
	v[Vector3i(cx - 2, 20, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx + 2, 20, cz + 2)] = P.EYE_WHITE
	v[Vector3i(cx - 1, 20, cz + 3)] = P.EYE_BLACK
	v[Vector3i(cx + 1, 20, cz + 3)] = P.EYE_BLACK
	# Battle axe in right hand
	v[Vector3i(cx + 7, 7, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx + 7, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 7, 5, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 7, 4, cz - 1)] = P.GREY_METAL  # axe head
	v[Vector3i(cx + 7, 4, cz)] = P.GREY_METAL
	v[Vector3i(cx + 7, 4, cz + 1)] = P.GREY_METAL
	v[Vector3i(cx + 7, 3, cz)] = P.GREY_METAL
	v[Vector3i(cx + 7, 3, cz + 1)] = P.GREY_METAL
	return v


func _build_dark_mage() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.MAGE_DARK_ROBE, P.MAGE_DARK_ROBE, P.MAGE_DARK_ROBE, P.SKIN_LIGHT, P.MAGE_DARK_ROBE, 3)
	# Flowing robe extension (Y=1..6, wider)
	filled_box(v, cx - 4, 1, cz - 2, cx + 4, 5, cz + 2, P.MAGE_DARK_ROBE)
	# Purple trim on robe edges
	for x in range(cx - 4, cx + 5):
		v[Vector3i(x, 1, cz + 2)] = P.MAGE_PURPLE
	# Hood (Y=15..18)
	filled_box(v, cx - 3, 15, cz - 3, cx + 3, 18, cz - 2, P.MAGE_DARK_ROBE)
	filled_box(v, cx - 3, 15, cz - 2, cx - 2, 18, cz + 1, P.MAGE_DARK_ROBE)
	filled_box(v, cx + 2, 15, cz - 2, cx + 3, 18, cz + 1, P.MAGE_DARK_ROBE)
	filled_box(v, cx - 3, 18, cz - 3, cx + 3, 18, cz + 2, P.MAGE_DARK_ROBE)
	# Glowing eyes under hood
	v[Vector3i(cx - 1, 16, cz + 2)] = P.FIRE_ORANGE
	v[Vector3i(cx + 1, 16, cz + 2)] = P.FIRE_ORANGE
	# Staff in left hand (with fire orb)
	v[Vector3i(cx - 5, 7, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx - 5, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx - 5, 5, cz)] = P.BROWN_DARK
	v[Vector3i(cx - 5, 4, cz)] = P.BROWN_DARK
	v[Vector3i(cx - 5, 13, cz)] = P.BROWN_DARK
	v[Vector3i(cx - 5, 14, cz)] = P.BROWN_DARK
	v[Vector3i(cx - 5, 15, cz)] = P.FIRE_ORANGE  # orb
	v[Vector3i(cx - 5, 16, cz)] = P.FIRE_ORANGE
	v[Vector3i(cx - 6, 15, cz)] = P.FIRE_ORANGE
	return v


func _build_wraith() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	# Ghostly, floaty shape — no legs, tattered robe bottom
	# Tattered robe bottom (Y=0..4, wispy)
	v[Vector3i(cx - 2, 0, cz)] = P.WRAITH_DARK
	v[Vector3i(cx + 2, 0, cz)] = P.WRAITH_DARK
	v[Vector3i(cx - 1, 1, cz - 1)] = P.WRAITH_DARK
	v[Vector3i(cx + 1, 1, cz + 1)] = P.WRAITH_DARK
	v[Vector3i(cx, 1, cz)] = P.WRAITH_DARK
	filled_box(v, cx - 2, 2, cz - 1, cx + 2, 4, cz + 1, P.WRAITH_DARK)
	# Body / robe (Y=5..12)
	filled_box(v, cx - 3, 5, cz - 2, cx + 3, 12, cz + 2, P.WRAITH_BLUE)
	# Darker center
	filled_box(v, cx - 1, 5, cz - 1, cx + 1, 10, cz + 1, P.WRAITH_DARK)
	# Arms reaching forward (Y=9..11)
	filled_box(v, cx - 5, 9, cz, cx - 4, 11, cz + 1, P.WRAITH_BLUE)
	filled_box(v, cx + 4, 9, cz, cx + 5, 11, cz + 1, P.WRAITH_BLUE)
	# Bony hands
	v[Vector3i(cx - 6, 9, cz)] = P.BONE_WHITE
	v[Vector3i(cx + 6, 9, cz)] = P.BONE_WHITE
	# Hood (Y=13..17)
	filled_box(v, cx - 3, 13, cz - 3, cx + 3, 17, cz - 2, P.WRAITH_DARK)
	filled_box(v, cx - 3, 13, cz - 2, cx - 2, 17, cz + 1, P.WRAITH_DARK)
	filled_box(v, cx + 2, 13, cz - 2, cx + 3, 17, cz + 1, P.WRAITH_DARK)
	filled_box(v, cx - 3, 17, cz - 3, cx + 3, 17, cz + 2, P.WRAITH_DARK)
	# Face area (Y=14..16)
	filled_box(v, cx - 1, 14, cz + 1, cx + 1, 16, cz + 1, P.WRAITH_DARK)
	# Glowing eyes
	v[Vector3i(cx - 1, 15, cz + 2)] = P.WRAITH_BLUE
	v[Vector3i(cx + 1, 15, cz + 2)] = P.WRAITH_BLUE
	return v


func _build_troll() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 8
	var cz: int = 5
	# Very large humanoid (28 voxels tall, bulky)
	# Feet (Y=0..2)
	filled_box(v, cx - 4, 0, cz - 2, cx - 1, 2, cz + 2, P.TROLL_DARK)
	filled_box(v, cx + 1, 0, cz - 2, cx + 4, 2, cz + 2, P.TROLL_DARK)
	# Legs (Y=3..10, thick)
	filled_box(v, cx - 4, 3, cz - 1, cx - 1, 10, cz + 2, P.TROLL_GREEN)
	filled_box(v, cx + 1, 3, cz - 1, cx + 4, 10, cz + 2, P.TROLL_GREEN)
	# Torso (Y=11..20, wide and round)
	filled_box(v, cx - 5, 11, cz - 3, cx + 5, 20, cz + 3, P.TROLL_GREEN)
	# Belly (slightly lighter/darker)
	filled_box(v, cx - 3, 11, cz + 3, cx + 3, 16, cz + 3, P.TROLL_DARK)
	# Arms (Y=12..20, very long and thick)
	filled_box(v, cx - 8, 12, cz - 2, cx - 6, 20, cz + 1, P.TROLL_GREEN)
	filled_box(v, cx + 6, 12, cz - 2, cx + 8, 20, cz + 1, P.TROLL_GREEN)
	# Forearms hanging down (Y=7..11)
	filled_box(v, cx - 8, 7, cz - 1, cx - 6, 11, cz + 1, P.TROLL_GREEN)
	filled_box(v, cx + 6, 7, cz - 1, cx + 8, 11, cz + 1, P.TROLL_GREEN)
	# Fists
	filled_box(v, cx - 8, 5, cz - 1, cx - 6, 6, cz + 1, P.TROLL_DARK)
	filled_box(v, cx + 6, 5, cz - 1, cx + 8, 6, cz + 1, P.TROLL_DARK)
	# Head (Y=21..26, small relative to body)
	filled_box(v, cx - 3, 21, cz - 2, cx + 3, 26, cz + 3, P.TROLL_GREEN)
	# Brow ridge
	filled_box(v, cx - 3, 25, cz + 3, cx + 3, 26, cz + 4, P.TROLL_DARK)
	# Eyes (small, under brow)
	v[Vector3i(cx - 2, 24, cz + 4)] = P.EYE_WHITE
	v[Vector3i(cx + 2, 24, cz + 4)] = P.EYE_WHITE
	# Mouth / underbite
	filled_box(v, cx - 2, 21, cz + 3, cx + 2, 22, cz + 4, P.TROLL_DARK)
	# Small tusks
	v[Vector3i(cx - 2, 23, cz + 4)] = P.BONE_WHITE
	v[Vector3i(cx + 2, 23, cz + 4)] = P.BONE_WHITE
	# Club in right hand
	v[Vector3i(cx + 8, 4, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx + 8, 3, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 8, 2, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 8, 1, cz - 1)] = P.BROWN_DARK  # club head
	v[Vector3i(cx + 8, 1, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 8, 1, cz + 1)] = P.BROWN_DARK
	v[Vector3i(cx + 8, 0, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 9, 1, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 7, 1, cz)] = P.BROWN_DARK
	return v


func _build_forest_elemental() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 7
	var cz: int = 5
	# Tree-like creature, twisted and organic
	# Root feet (Y=0..3, spread wide)
	for i in range(-5, 6):
		v[Vector3i(cx + i, 0, cz)] = P.TROLL_DARK
		if abs(i) < 4:
			v[Vector3i(cx + i, 1, cz)] = P.TROLL_DARK
	v[Vector3i(cx - 4, 0, cz - 1)] = P.TROLL_DARK
	v[Vector3i(cx + 4, 0, cz - 1)] = P.TROLL_DARK
	v[Vector3i(cx - 4, 0, cz + 1)] = P.TROLL_DARK
	v[Vector3i(cx + 4, 0, cz + 1)] = P.TROLL_DARK
	# Trunk / body (Y=2..16)
	filled_cylinder(v, cx, cz, 2, 16, 3.0, P.TREE_TRUNK)
	# Bark texture (darker patches)
	for y in range(4, 16, 3):
		v[Vector3i(cx - 3, y, cz)] = P.BROWN_DARK
		v[Vector3i(cx + 3, y, cz)] = P.BROWN_DARK
		v[Vector3i(cx, y, cz - 3)] = P.BROWN_DARK
		v[Vector3i(cx, y, cz + 3)] = P.BROWN_DARK
	# Branch arms (Y=12..16, extending outward)
	filled_box(v, cx - 7, 13, cz - 1, cx - 4, 15, cz + 1, P.TREE_TRUNK)
	filled_box(v, cx + 4, 13, cz - 1, cx + 7, 15, cz + 1, P.TREE_TRUNK)
	# Leaves on arm tips
	filled_sphere(v, cx - 8, 15, cz, 2.5, P.ELEMENTAL_GREEN)
	filled_sphere(v, cx + 8, 15, cz, 2.5, P.ELEMENTAL_GREEN)
	# Head crown of leaves (Y=17..22)
	filled_sphere(v, cx, 20, cz, 5.0, P.ELEMENTAL_GREEN)
	filled_sphere(v, cx, 22, cz, 3.0, P.ELEMENTAL_GLOW)
	# Face (carved into trunk, Y=12..15)
	# Glowing eyes
	v[Vector3i(cx - 1, 14, cz + 3)] = P.ELEMENTAL_GLOW
	v[Vector3i(cx + 1, 14, cz + 3)] = P.ELEMENTAL_GLOW
	# Mouth (dark hollow)
	filled_box(v, cx - 1, 11, cz + 3, cx + 1, 12, cz + 3, P.BROWN_DARK)
	return v


# -- NPCs --

func _build_merchant() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BROWN_LEATHER, P.BROWN_DARK, P.BROWN_DARK, P.SKIN_LIGHT, P.BOOT_BROWN, 3)
	# Apron (front, Y=7..11)
	for y in range(7, 12):
		for x in range(cx - 2, cx + 3):
			v[Vector3i(x, y, cz + 2)] = P.SKIN_LIGHT
	# Belt pouch (gold)
	v[Vector3i(cx + 3, 7, cz + 1)] = P.GOLD_ACCENT
	# Brown hair
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 1, P.HAIR_BROWN)
	return v


func _build_blacksmith() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.GREY_METAL, P.BROWN_DARK, P.GREY_DARK, P.SKIN_DARK, P.BOOT_BROWN, 3)
	# Hammer on right hand (extend right arm)
	v[Vector3i(cx + 6, 7, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx + 6, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 6, 5, cz - 1)] = P.GREY_METAL  # head
	v[Vector3i(cx + 6, 5, cz)] = P.GREY_METAL
	v[Vector3i(cx + 6, 5, cz + 1)] = P.GREY_METAL
	# Dark hair
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 1, P.HAIR_BLACK)
	return v


func _build_weaver() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 4
	var cz: int = 3
	_humanoid(v, cx, cz, P.WEAVER_TEAL, P.WEAVER_TEAL, P.WEAVER_TEAL, P.SKIN_LIGHT, P.WEAVER_TEAL, 2)
	# Hood
	filled_box(v, cx - 3, 15, cz - 3, cx + 3, 18, cz - 2, P.WEAVER_TEAL)
	filled_box(v, cx - 3, 15, cz - 2, cx - 2, 18, cz + 1, P.WEAVER_TEAL)
	filled_box(v, cx + 2, 15, cz - 2, cx + 3, 18, cz + 1, P.WEAVER_TEAL)
	filled_box(v, cx - 3, 18, cz - 3, cx + 3, 18, cz + 2, P.WEAVER_TEAL)
	# Flowing robe extension
	filled_box(v, cx - 3, 1, cz - 2, cx + 3, 5, cz + 2, P.WEAVER_TEAL)
	return v


func _build_doctor() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.WHITE_CLOTH, P.WHITE_CLOTH, P.WHITE_CLOTH, P.SKIN_LIGHT, P.BOOT_BROWN, 3)
	# Red cross on chest (front face, Y=9..11)
	v[Vector3i(cx, 10, cz + 2)] = P.RED_CROSS
	v[Vector3i(cx - 1, 10, cz + 2)] = P.RED_CROSS
	v[Vector3i(cx + 1, 10, cz + 2)] = P.RED_CROSS
	v[Vector3i(cx, 11, cz + 2)] = P.RED_CROSS
	v[Vector3i(cx, 9, cz + 2)] = P.RED_CROSS
	# Brown hair
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 1, P.HAIR_BROWN)
	return v


func _build_old_man() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BROWN_LEATHER, P.BROWN_DARK, P.BROWN_DARK, P.SKIN_LIGHT, P.BOOT_BROWN, 2)
	# Grey hair (balding on top)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 17, cz + 1, P.GREY_METAL)
	filled_box(v, cx - 2, 16, cz - 2, cx - 2, 17, cz + 1, P.GREY_METAL)
	filled_box(v, cx + 2, 16, cz - 2, cx + 2, 17, cz + 1, P.GREY_METAL)
	# Walking cane in right hand
	v[Vector3i(cx + 4, 7, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 5, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 4, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 3, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 2, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 1, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 4, 0, cz)] = P.BROWN_DARK
	# Curved handle
	v[Vector3i(cx + 4, 8, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 8, cz)] = P.BROWN_DARK
	return v


func _build_guard() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BLUE_STEEL, P.BLUE_DARK, P.BLUE_DARK, P.SKIN_LIGHT, P.BOOT_BROWN, 3)
	# Helmet (Y=17..19)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 19, cz + 2, P.GREY_METAL)
	# Helmet visor slit
	filled_box(v, cx - 1, 18, cz + 2, cx + 1, 18, cz + 3, P.GREY_DARK)
	# Shield on left arm
	filled_box(v, cx - 6, 8, cz - 1, cx - 5, 12, cz + 2, P.BLUE_STEEL)
	# Shield emblem (gold)
	v[Vector3i(cx - 5, 10, cz + 2)] = P.GOLD_ACCENT
	# Spear in right hand
	v[Vector3i(cx + 5, 7, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx + 5, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 5, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 13, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 14, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 15, cz)] = P.GREY_METAL  # spear tip
	v[Vector3i(cx + 5, 16, cz)] = P.GREY_METAL
	# Shoulder pads
	filled_box(v, cx - 5, 12, cz - 1, cx - 4, 13, cz + 1, P.GREY_METAL)
	filled_box(v, cx + 4, 12, cz - 1, cx + 5, 13, cz + 1, P.GREY_METAL)
	return v


func _build_bard() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.GOLD_ACCENT, P.BROWN_LEATHER, P.BROWN_LEATHER, P.SKIN_LIGHT, P.BOOT_BROWN, 2)
	# Feathered hat (Y=17..20)
	filled_box(v, cx - 2, 17, cz - 2, cx + 2, 18, cz + 2, P.BROWN_LEATHER)
	filled_box(v, cx - 1, 19, cz - 1, cx + 1, 19, cz + 1, P.BROWN_LEATHER)
	v[Vector3i(cx, 20, cz)] = P.BROWN_LEATHER
	# Feather (red, sticking up from hat)
	v[Vector3i(cx + 2, 19, cz + 1)] = P.FLOWER_RED
	v[Vector3i(cx + 2, 20, cz + 1)] = P.FLOWER_RED
	v[Vector3i(cx + 2, 21, cz + 1)] = P.FLOWER_RED
	# Brown hair peeking out
	filled_box(v, cx - 2, 16, cz + 2, cx + 2, 17, cz + 2, P.HAIR_BROWN)
	# Lute held across body (simplified)
	v[Vector3i(cx - 4, 9, cz + 1)] = P.BROWN_DARK
	v[Vector3i(cx - 3, 9, cz + 2)] = P.BROWN_DARK
	v[Vector3i(cx - 3, 10, cz + 2)] = P.BROWN_DARK
	v[Vector3i(cx - 3, 8, cz + 2)] = P.BROWN_DARK
	v[Vector3i(cx - 2, 9, cz + 2)] = P.GOLD_ACCENT  # lute body
	v[Vector3i(cx - 1, 9, cz + 2)] = P.GOLD_ACCENT
	# Cape flowing behind
	filled_box(v, cx - 2, 5, cz - 2, cx + 2, 12, cz - 2, P.BANDIT_RED)
	return v


func _build_farmer() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 5
	var cz: int = 3
	_humanoid(v, cx, cz, P.BROWN_LEATHER, P.BROWN_DARK, P.BROWN_DARK, P.SKIN_LIGHT, P.BOOT_BROWN, 3)
	# Straw hat (Y=17..19, wide brim)
	filled_box(v, cx - 3, 17, cz - 3, cx + 3, 17, cz + 3, P.HAIR_BLONDE)
	filled_box(v, cx - 2, 18, cz - 2, cx + 2, 18, cz + 2, P.HAIR_BLONDE)
	filled_box(v, cx - 1, 19, cz - 1, cx + 1, 19, cz + 1, P.HAIR_BLONDE)
	# Brown hair underneath
	filled_box(v, cx - 2, 16, cz - 1, cx + 2, 16, cz + 1, P.HAIR_BROWN)
	# Apron over clothes
	for y in range(7, 12):
		for x in range(cx - 2, cx + 3):
			v[Vector3i(x, y, cz + 2)] = P.SKIN_LIGHT
	# Pitchfork in right hand
	v[Vector3i(cx + 5, 7, cz)] = P.BROWN_DARK  # handle
	v[Vector3i(cx + 5, 6, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 5, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 13, cz)] = P.BROWN_DARK
	v[Vector3i(cx + 5, 14, cz)] = P.GREY_METAL  # prongs
	v[Vector3i(cx + 4, 14, cz)] = P.GREY_METAL
	v[Vector3i(cx + 6, 14, cz)] = P.GREY_METAL
	return v


func _build_child() -> Dictionary:
	var v: Dictionary = {}
	var cx: int = 4
	var cz: int = 3
	# Smaller humanoid (12 voxels tall like goblin, but human proportions)
	# Feet (Y=0..1)
	filled_box(v, cx - 1, 0, cz, cx, 1, cz + 1, P.BOOT_BROWN)
	filled_box(v, cx + 1, 0, cz, cx + 2, 1, cz + 1, P.BOOT_BROWN)
	# Legs (Y=2..4)
	filled_box(v, cx - 1, 2, cz, cx, 4, cz + 1, P.BROWN_DARK)
	filled_box(v, cx + 1, 2, cz, cx + 2, 4, cz + 1, P.BROWN_DARK)
	# Torso (Y=5..8)
	filled_box(v, cx - 1, 5, cz - 1, cx + 2, 8, cz + 1, P.GREEN_ROGUE)
	# Arms (Y=5..7)
	filled_box(v, cx - 2, 5, cz, cx - 2, 7, cz, P.GREEN_ROGUE)
	filled_box(v, cx + 3, 5, cz, cx + 3, 7, cz, P.GREEN_ROGUE)
	# Hands
	v[Vector3i(cx - 2, 5, cz)] = P.SKIN_LIGHT
	v[Vector3i(cx + 3, 5, cz)] = P.SKIN_LIGHT
	# Neck (Y=9)
	v[Vector3i(cx, 9, cz)] = P.SKIN_LIGHT
	v[Vector3i(cx + 1, 9, cz)] = P.SKIN_LIGHT
	# Head (Y=10..13, big for a child)
	filled_box(v, cx - 1, 10, cz - 1, cx + 2, 13, cz + 2, P.SKIN_LIGHT)
	# Eyes
	v[Vector3i(cx, 12, cz + 2)] = P.EYE_BLACK
	v[Vector3i(cx + 1, 12, cz + 2)] = P.EYE_BLACK
	# Brown hair (messy)
	filled_box(v, cx - 1, 13, cz - 1, cx + 2, 14, cz + 2, P.HAIR_BROWN)
	filled_box(v, cx - 1, 12, cz - 1, cx + 2, 13, cz - 1, P.HAIR_BROWN)
	return v


# -- World Objects --

func _build_tree_large() -> Dictionary:
	var v: Dictionary = {}
	# Trunk (Y=0..20)
	filled_cylinder(v, 6, 6, 0, 20, 2.0, P.TREE_TRUNK)
	# Foliage sphere (Y center=28)
	filled_sphere(v, 6, 28, 6, 10.0, P.FOLIAGE_GREEN)
	# Lighter top
	filled_sphere(v, 6, 32, 6, 5.0, P.FOLIAGE_LIGHT)
	return v


func _build_tree_medium() -> Dictionary:
	var v: Dictionary = {}
	filled_cylinder(v, 5, 5, 0, 14, 1.5, P.TREE_TRUNK)
	filled_sphere(v, 5, 20, 5, 7.0, P.FOLIAGE_GREEN)
	filled_sphere(v, 5, 23, 5, 3.5, P.FOLIAGE_LIGHT)
	return v


func _build_tree_small() -> Dictionary:
	var v: Dictionary = {}
	filled_cylinder(v, 4, 4, 0, 9, 1.0, P.TREE_TRUNK)
	filled_sphere(v, 4, 14, 4, 5.0, P.FOLIAGE_GREEN)
	filled_sphere(v, 4, 16, 4, 2.5, P.FOLIAGE_LIGHT)
	return v


func _build_rock_large() -> Dictionary:
	var v: Dictionary = {}
	filled_ellipsoid(v, 8, 5, 8, 7.0, 5.0, 7.0, P.ROCK_GREY)
	# Lighter highlight on top
	filled_ellipsoid(v, 8, 8, 8, 4.0, 2.0, 4.0, P.ROCK_LIGHT)
	return v


func _build_rock_medium() -> Dictionary:
	var v: Dictionary = {}
	filled_ellipsoid(v, 5, 3, 5, 4.5, 3.0, 4.5, P.ROCK_GREY)
	filled_ellipsoid(v, 5, 5, 5, 2.5, 1.5, 2.5, P.ROCK_LIGHT)
	return v


func _build_rock_small() -> Dictionary:
	var v: Dictionary = {}
	filled_ellipsoid(v, 3, 2, 3, 2.8, 2.0, 2.8, P.ROCK_GREY)
	return v


func _build_bush() -> Dictionary:
	var v: Dictionary = {}
	filled_ellipsoid(v, 6, 3, 6, 5.0, 3.5, 5.0, P.BUSH_GREEN)
	# Lighter patches
	filled_ellipsoid(v, 4, 5, 6, 2.0, 1.5, 2.0, P.FOLIAGE_LIGHT)
	filled_ellipsoid(v, 8, 4, 5, 1.5, 1.5, 1.5, P.FOLIAGE_LIGHT)
	return v


func _build_fence() -> Dictionary:
	var v: Dictionary = {}
	# Horizontal planks
	filled_box(v, 0, 2, 1, 11, 3, 1, P.FENCE_BROWN)
	filled_box(v, 0, 5, 1, 11, 6, 1, P.FENCE_BROWN)
	# Vertical posts
	filled_box(v, 0, 0, 0, 1, 7, 2, P.BROWN_DARK)
	filled_box(v, 5, 0, 0, 6, 7, 2, P.BROWN_DARK)
	filled_box(v, 10, 0, 0, 11, 7, 2, P.BROWN_DARK)
	return v


func _build_sign() -> Dictionary:
	var v: Dictionary = {}
	# Post
	filled_box(v, 3, 0, 1, 3, 7, 1, P.TREE_TRUNK)
	# Board
	filled_box(v, 0, 8, 0, 6, 11, 1, P.SIGN_BOARD)
	# Text line (darker)
	filled_box(v, 1, 9, 1, 5, 10, 1, P.BROWN_DARK)
	return v


func _build_flower_red() -> Dictionary:
	var v: Dictionary = {}
	# Stem
	v[Vector3i(1, 0, 1)] = P.STEM_GREEN
	v[Vector3i(1, 1, 1)] = P.STEM_GREEN
	v[Vector3i(1, 2, 1)] = P.STEM_GREEN
	# Bloom
	v[Vector3i(1, 3, 1)] = P.FLOWER_RED
	v[Vector3i(0, 3, 1)] = P.FLOWER_RED
	v[Vector3i(2, 3, 1)] = P.FLOWER_RED
	v[Vector3i(1, 3, 0)] = P.FLOWER_RED
	v[Vector3i(1, 3, 2)] = P.FLOWER_RED
	v[Vector3i(1, 4, 1)] = P.FLOWER_RED
	return v


func _build_flower_yellow() -> Dictionary:
	var v: Dictionary = {}
	v[Vector3i(1, 0, 1)] = P.STEM_GREEN
	v[Vector3i(1, 1, 1)] = P.STEM_GREEN
	v[Vector3i(1, 2, 1)] = P.STEM_GREEN
	v[Vector3i(1, 3, 1)] = P.FLOWER_YELLOW
	v[Vector3i(0, 3, 1)] = P.FLOWER_YELLOW
	v[Vector3i(2, 3, 1)] = P.FLOWER_YELLOW
	v[Vector3i(1, 3, 0)] = P.FLOWER_YELLOW
	v[Vector3i(1, 3, 2)] = P.FLOWER_YELLOW
	v[Vector3i(1, 4, 1)] = P.FLOWER_YELLOW
	return v


func _build_grass_tuft() -> Dictionary:
	var v: Dictionary = {}
	# Three blades of different heights
	v[Vector3i(1, 0, 1)] = P.GRASS_GREEN
	v[Vector3i(1, 1, 1)] = P.GRASS_GREEN

	v[Vector3i(2, 0, 1)] = P.GRASS_GREEN
	v[Vector3i(2, 1, 1)] = P.GRASS_GREEN
	v[Vector3i(2, 2, 1)] = P.GRASS_GREEN

	v[Vector3i(3, 0, 1)] = P.GRASS_GREEN
	v[Vector3i(3, 1, 1)] = P.STEM_GREEN

	v[Vector3i(0, 0, 2)] = P.STEM_GREEN
	v[Vector3i(0, 1, 2)] = P.GRASS_GREEN
	v[Vector3i(0, 2, 2)] = P.GRASS_GREEN

	v[Vector3i(4, 0, 0)] = P.GRASS_GREEN
	v[Vector3i(4, 1, 0)] = P.GRASS_GREEN
	return v


# === Main Entry Point ===

func _run() -> void:
	var models: Array[Dictionary] = [
		# Characters
		{"name": "warrior", "dir": "characters", "builder": "_build_kael"},
		{"name": "mage", "dir": "characters", "builder": "_build_lyra"},
		{"name": "rogue", "dir": "characters", "builder": "_build_vex"},
		# Enemies
		{"name": "slime", "dir": "enemies", "builder": "_build_slime"},
		{"name": "goblin", "dir": "enemies", "builder": "_build_goblin"},
		{"name": "minotaur", "dir": "enemies", "builder": "_build_minotaur"},
		{"name": "bat", "dir": "enemies", "builder": "_build_bat"},
		{"name": "wolf", "dir": "enemies", "builder": "_build_wolf"},
		{"name": "spider", "dir": "enemies", "builder": "_build_spider"},
		{"name": "skeleton", "dir": "enemies", "builder": "_build_skeleton"},
		{"name": "bandit", "dir": "enemies", "builder": "_build_bandit"},
		{"name": "orc", "dir": "enemies", "builder": "_build_orc"},
		{"name": "dark_mage", "dir": "enemies", "builder": "_build_dark_mage"},
		{"name": "wraith", "dir": "enemies", "builder": "_build_wraith"},
		{"name": "troll", "dir": "enemies", "builder": "_build_troll"},
		{"name": "forest_elemental", "dir": "enemies", "builder": "_build_forest_elemental"},
		# NPCs
		{"name": "merchant", "dir": "npcs", "builder": "_build_merchant"},
		{"name": "blacksmith", "dir": "npcs", "builder": "_build_blacksmith"},
		{"name": "weaver", "dir": "npcs", "builder": "_build_weaver"},
		{"name": "doctor", "dir": "npcs", "builder": "_build_doctor"},
		{"name": "old_man", "dir": "npcs", "builder": "_build_old_man"},
		{"name": "guard", "dir": "npcs", "builder": "_build_guard"},
		{"name": "bard", "dir": "npcs", "builder": "_build_bard"},
		{"name": "farmer", "dir": "npcs", "builder": "_build_farmer"},
		{"name": "child", "dir": "npcs", "builder": "_build_child"},
		# World objects
		{"name": "tree_large", "dir": "world", "builder": "_build_tree_large"},
		{"name": "tree_medium", "dir": "world", "builder": "_build_tree_medium"},
		{"name": "tree_small", "dir": "world", "builder": "_build_tree_small"},
		{"name": "rock_large", "dir": "world", "builder": "_build_rock_large"},
		{"name": "rock_medium", "dir": "world", "builder": "_build_rock_medium"},
		{"name": "rock_small", "dir": "world", "builder": "_build_rock_small"},
		{"name": "bush", "dir": "world", "builder": "_build_bush"},
		{"name": "fence", "dir": "world", "builder": "_build_fence"},
		{"name": "sign", "dir": "world", "builder": "_build_sign"},
		{"name": "flower_red", "dir": "world", "builder": "_build_flower_red"},
		{"name": "flower_yellow", "dir": "world", "builder": "_build_flower_yellow"},
		{"name": "grass_tuft", "dir": "world", "builder": "_build_grass_tuft"},
	]

	var ok_count: int = 0
	var fail_count: int = 0

	for entry in models:
		var model_name: String = entry["name"]
		var dir_name: String = entry["dir"]
		var builder_name: String = entry["builder"]

		var voxels: Dictionary = call(builder_name)
		var path := "res://assets/voxels/%s/%s.vox" % [dir_name, model_name]

		var err: Error = VoxWriter.write_vox(path, voxels, _palette)
		if err != OK:
			print("[VoxGen] FAILED to write %s: error %d" % [path, err])
			fail_count += 1
			continue

		# Round-trip verification
		var mesh: ArrayMesh = VoxImporter.load_vox(path)
		if mesh and mesh.get_aabb().size.length() > 0.0:
			print("[VoxGen] OK: %s (%d voxels)" % [model_name, voxels.size()])
			ok_count += 1
		else:
			print("[VoxGen] ROUND-TRIP FAIL: %s" % model_name)
			fail_count += 1

	print("[VoxGen] Done: %d OK, %d failed" % [ok_count, fail_count])
