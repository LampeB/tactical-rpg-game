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
		# NPCs
		{"name": "merchant", "dir": "npcs", "builder": "_build_merchant"},
		{"name": "blacksmith", "dir": "npcs", "builder": "_build_blacksmith"},
		{"name": "weaver", "dir": "npcs", "builder": "_build_weaver"},
		{"name": "doctor", "dir": "npcs", "builder": "_build_doctor"},
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
