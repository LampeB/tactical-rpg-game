"""
Generate MagicaVoxel .vox files for all game objects.
Run: python3 tools/generate_vox_python.py
"""
import struct
import os
import math

BASE_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "voxels")

# === Palette (0-based indices) ===
PALETTE = [
    # 0: skin_light
    (0.93, 0.76, 0.65, 1.0),
    # 1: skin_dark
    (0.78, 0.60, 0.48, 1.0),
    # 2: blue_steel (Kael)
    (0.35, 0.45, 0.62, 1.0),
    # 3: blue_steel_dark
    (0.25, 0.32, 0.48, 1.0),
    # 4: purple_robe (Lyra)
    (0.55, 0.30, 0.65, 1.0),
    # 5: purple_dark
    (0.38, 0.18, 0.48, 1.0),
    # 6: green_cloak (Vex)
    (0.30, 0.55, 0.35, 1.0),
    # 7: green_dark
    (0.18, 0.38, 0.22, 1.0),
    # 8: brown_leather
    (0.55, 0.35, 0.20, 1.0),
    # 9: brown_dark
    (0.38, 0.22, 0.12, 1.0),
    # 10: grey_metal
    (0.55, 0.55, 0.58, 1.0),
    # 11: grey_dark
    (0.35, 0.35, 0.38, 1.0),
    # 12: teal_cloth
    (0.25, 0.60, 0.58, 1.0),
    # 13: teal_dark
    (0.15, 0.42, 0.40, 1.0),
    # 14: white_cloth
    (0.92, 0.92, 0.90, 1.0),
    # 15: red_cross
    (0.85, 0.15, 0.15, 1.0),
    # 16: gold_accent
    (0.85, 0.72, 0.20, 1.0),
    # 17: hair_brown
    (0.45, 0.30, 0.18, 1.0),
    # 18: hair_blonde
    (0.90, 0.78, 0.45, 1.0),
    # 19: hair_dark
    (0.18, 0.12, 0.10, 1.0),
    # 20: slime_green
    (0.30, 0.78, 0.25, 1.0),
    # 21: slime_green_dark
    (0.20, 0.58, 0.15, 1.0),
    # 22: goblin_green
    (0.45, 0.62, 0.30, 1.0),
    # 23: goblin_dark
    (0.32, 0.45, 0.20, 1.0),
    # 24: minotaur_brown
    (0.50, 0.32, 0.18, 1.0),
    # 25: minotaur_dark
    (0.35, 0.20, 0.10, 1.0),
    # 26: eye_white
    (0.95, 0.95, 0.95, 1.0),
    # 27: eye_black
    (0.10, 0.10, 0.10, 1.0),
    # 28: trunk_brown
    (0.45, 0.30, 0.15, 1.0),
    # 29: foliage_green
    (0.25, 0.55, 0.20, 1.0),
    # 30: foliage_dark
    (0.15, 0.40, 0.12, 1.0),
    # 31: rock_grey
    (0.50, 0.50, 0.48, 1.0),
    # 32: rock_dark
    (0.35, 0.35, 0.33, 1.0),
    # 33: fence_brown
    (0.58, 0.40, 0.22, 1.0),
    # 34: flower_red
    (0.90, 0.20, 0.25, 1.0),
    # 35: flower_yellow
    (0.95, 0.88, 0.25, 1.0),
    # 36: grass_green
    (0.30, 0.65, 0.22, 1.0),
    # 37: stem_green
    (0.22, 0.48, 0.18, 1.0),
    # 38: horn_beige
    (0.82, 0.72, 0.55, 1.0),
]


# === Shape helpers (voxels dict: {(x,y,z): color_idx}) ===

def filled_box(voxels, x0, y0, z0, x1, y1, z1, color_idx):
    for x in range(x0, x1 + 1):
        for y in range(y0, y1 + 1):
            for z in range(z0, z1 + 1):
                voxels[(x, y, z)] = color_idx


def filled_sphere(voxels, cx, cy, cz, radius, color_idx):
    r2 = radius * radius
    ri = int(math.ceil(radius))
    for x in range(cx - ri, cx + ri + 1):
        for y in range(cy - ri, cy + ri + 1):
            for z in range(cz - ri, cz + ri + 1):
                dx = x - cx
                dy = y - cy
                dz = z - cz
                if dx * dx + dy * dy + dz * dz <= r2:
                    voxels[(x, y, z)] = color_idx


def filled_ellipsoid(voxels, cx, cy, cz, rx, ry, rz, color_idx):
    rix = int(math.ceil(rx))
    riy = int(math.ceil(ry))
    riz = int(math.ceil(rz))
    for x in range(cx - rix, cx + rix + 1):
        for y in range(cy - riy, cy + riy + 1):
            for z in range(cz - riz, cz + riz + 1):
                dx = (x - cx) / max(rx, 0.01)
                dy = (y - cy) / max(ry, 0.01)
                dz = (z - cz) / max(rz, 0.01)
                if dx * dx + dy * dy + dz * dz <= 1.0:
                    voxels[(x, y, z)] = color_idx


def filled_cylinder(voxels, cx, cz, y0, y1, radius, color_idx):
    r2 = radius * radius
    ri = int(math.ceil(radius))
    for x in range(cx - ri, cx + ri + 1):
        for z in range(cz - ri, cz + ri + 1):
            dx = x - cx
            dz = z - cz
            if dx * dx + dz * dz <= r2:
                for y in range(y0, y1 + 1):
                    voxels[(x, y, z)] = color_idx


# === Humanoid base template ===

def humanoid(torso_color, torso_dark, leg_color, arm_color, hair_color, height=18, torso_width=6):
    """Create a humanoid figure. Y=0 at feet, centered on X/Z."""
    voxels = {}
    hw = torso_width // 2  # half width
    cx = 8  # center X
    cz = 4  # center Z

    scale = height / 18.0

    # Legs (y=0..5)
    leg_top = int(5 * scale)
    for side in [-1, 1]:
        lx = cx + side * 1
        filled_box(voxels, lx, 0, cz - 1, lx + 1, leg_top, cz, leg_color)

    # Torso (y=6..11)
    torso_bot = leg_top + 1
    torso_top = int(11 * scale)
    filled_box(voxels, cx - hw // 2, torso_bot, cz - 1,
               cx + hw // 2, torso_top, cz, torso_color)

    # Arms (y=6..11)
    for side in [-1, 1]:
        ax = cx + side * (hw // 2 + 1)
        filled_box(voxels, ax, torso_bot, cz - 1, ax, torso_top - 1, cz, arm_color)

    # Neck (y=12)
    neck_y = torso_top + 1
    filled_box(voxels, cx - 1, neck_y, cz - 1, cx, neck_y, cz, 0)  # skin

    # Head (y=13..16)
    head_bot = neck_y + 1
    head_top = int(16 * scale)
    filled_box(voxels, cx - 2, head_bot, cz - 2, cx + 1, head_top, cz + 1, 0)  # skin

    # Hair (top of head)
    filled_box(voxels, cx - 2, head_top, cz - 2, cx + 1, head_top + 1, cz + 1, hair_color)
    # Hair sides
    filled_box(voxels, cx - 2, head_bot + 1, cz + 1, cx + 1, head_top, cz + 1, hair_color)

    # Eyes
    eye_y = head_bot + 1
    voxels[(cx - 1, eye_y, cz - 2)] = 27  # left eye
    voxels[(cx, eye_y, cz - 2)] = 27  # right eye

    return voxels


# === Character Models ===

def make_kael():
    """Warrior - broad shoulders, blue steel armor, brown hair."""
    voxels = humanoid(
        torso_color=2, torso_dark=3, leg_color=3,
        arm_color=2, hair_color=17, height=18, torso_width=8
    )
    # Shoulder pads
    cx, cz = 8, 4
    for side in [-1, 1]:
        sx = cx + side * 5
        filled_box(voxels, sx, 10, cz - 1, sx + (1 if side > 0 else 0), 12, cz, 10)
    # Belt
    filled_box(voxels, cx - 3, 6, cz - 2, cx + 2, 6, cz + 1, 9)
    return voxels


def make_lyra():
    """Mage - narrow build, purple robe, pointed hat, blonde hair."""
    voxels = humanoid(
        torso_color=4, torso_dark=5, leg_color=5,
        arm_color=4, hair_color=18, height=18, torso_width=6
    )
    cx, cz = 8, 4
    # Robe skirt extension (flare out from waist)
    for y in range(0, 6):
        w = 4 + (5 - y) // 2
        filled_box(voxels, cx - w // 2, y, cz - 2, cx + w // 2, y, cz + 1, 5)
    # Pointed hat
    filled_box(voxels, cx - 2, 17, cz - 2, cx + 1, 18, cz + 1, 4)
    filled_box(voxels, cx - 1, 19, cz - 1, cx, 20, cz, 4)
    voxels[(cx, 21, cz)] = 4  # tip
    return voxels


def make_vex():
    """Rogue - slim build, green hood, dark green legs."""
    voxels = humanoid(
        torso_color=6, torso_dark=7, leg_color=7,
        arm_color=6, hair_color=19, height=18, torso_width=6
    )
    cx, cz = 8, 4
    # Hood
    filled_box(voxels, cx - 2, 15, cz - 2, cx + 1, 17, cz + 1, 7)
    # Hood opening (face visible)
    filled_box(voxels, cx - 1, 14, cz - 2, cx, 16, cz - 2, 0)
    # Belt with dagger
    filled_box(voxels, cx - 3, 6, cz - 2, cx + 2, 6, cz + 1, 9)
    voxels[(cx + 3, 5, cz)] = 10  # dagger
    voxels[(cx + 3, 6, cz)] = 10
    return voxels


# === Enemy Models ===

def make_slime():
    """Green slime blob with eyes."""
    voxels = {}
    cx, cy, cz = 6, 3, 6
    filled_ellipsoid(voxels, cx, cy, cz, 5, 3, 5, 20)
    # Darker bottom
    filled_ellipsoid(voxels, cx, cy - 1, cz, 5, 2, 5, 21)
    # Eyes
    voxels[(cx - 2, cy + 2, cz - 4)] = 26  # left white
    voxels[(cx + 1, cy + 2, cz - 4)] = 26  # right white
    voxels[(cx - 2, cy + 2, cz - 5)] = 27  # left pupil
    voxels[(cx + 1, cy + 2, cz - 5)] = 27  # right pupil
    return voxels


def make_goblin():
    """Small green humanoid with big head and pointy ears."""
    voxels = humanoid(
        torso_color=22, torso_dark=23, leg_color=23,
        arm_color=22, hair_color=23, height=12, torso_width=6
    )
    cx, cz = 8, 4
    # Override head to be bigger (goblin feature)
    head_bot = 9
    head_top = 12
    filled_box(voxels, cx - 3, head_bot, cz - 2, cx + 2, head_top, cz + 2, 22)
    # Pointy ears
    voxels[(cx - 4, head_bot + 1, cz)] = 22
    voxels[(cx + 3, head_bot + 1, cz)] = 22
    # Eyes
    voxels[(cx - 1, head_bot + 1, cz - 2)] = 26
    voxels[(cx + 1, head_bot + 1, cz - 2)] = 26
    voxels[(cx - 1, head_bot + 1, cz - 3)] = 27
    voxels[(cx + 1, head_bot + 1, cz - 3)] = 27
    return voxels


def make_minotaur():
    """Large brown humanoid with horns."""
    voxels = humanoid(
        torso_color=24, torso_dark=25, leg_color=25,
        arm_color=24, hair_color=19, height=25, torso_width=10
    )
    cx, cz = 8, 4
    # Horns
    head_top = int(16 * 25.0 / 18.0)
    for side in [-1, 1]:
        hx = cx + side * 3
        for dy in range(3):
            voxels[(hx, head_top + dy, cz)] = 38
        voxels[(hx + side, head_top + 2, cz)] = 38  # horn tip curves out
    # Snout
    filled_box(voxels, cx - 1, int(14 * 25.0 / 18.0), cz - 3,
               cx, int(14 * 25.0 / 18.0) + 1, cz - 3, 24)
    return voxels


# === NPC Models ===

def make_merchant():
    """Brown leather outfit with gold belt pouch."""
    voxels = humanoid(
        torso_color=8, torso_dark=9, leg_color=9,
        arm_color=8, hair_color=17, height=18, torso_width=7
    )
    cx, cz = 8, 4
    # Apron front
    filled_box(voxels, cx - 2, 3, cz - 2, cx + 1, 10, cz - 2, 9)
    # Gold belt pouch
    voxels[(cx + 2, 6, cz - 2)] = 16
    voxels[(cx + 3, 6, cz - 2)] = 16
    return voxels


def make_blacksmith():
    """Grey metal torso, brown arms, muscular build."""
    voxels = humanoid(
        torso_color=10, torso_dark=11, leg_color=9,
        arm_color=8, hair_color=19, height=18, torso_width=8
    )
    cx, cz = 8, 4
    # Apron
    filled_box(voxels, cx - 2, 3, cz - 2, cx + 1, 9, cz - 2, 11)
    return voxels


def make_weaver():
    """Teal robes, hooded figure."""
    voxels = humanoid(
        torso_color=12, torso_dark=13, leg_color=13,
        arm_color=12, hair_color=19, height=18, torso_width=6
    )
    cx, cz = 8, 4
    # Robe extension
    for y in range(0, 6):
        w = 4 + (5 - y) // 2
        filled_box(voxels, cx - w // 2, y, cz - 2, cx + w // 2, y, cz + 1, 13)
    # Hood
    filled_box(voxels, cx - 2, 15, cz - 2, cx + 1, 17, cz + 1, 13)
    filled_box(voxels, cx - 1, 14, cz - 2, cx, 16, cz - 2, 0)  # face opening
    return voxels


def make_doctor():
    """White cloth with red cross on chest."""
    voxels = humanoid(
        torso_color=14, torso_dark=14, leg_color=14,
        arm_color=14, hair_color=17, height=18, torso_width=6
    )
    cx, cz = 8, 4
    # Red cross on chest
    voxels[(cx, 9, cz - 2)] = 15
    voxels[(cx - 1, 8, cz - 2)] = 15
    voxels[(cx, 8, cz - 2)] = 15
    voxels[(cx + 1, 8, cz - 2)] = 15
    voxels[(cx, 7, cz - 2)] = 15
    return voxels


# === World Object Models ===

def make_tree_oak():
    """Medium oak tree with round foliage."""
    voxels = {}
    cx, cz = 8, 8
    # Trunk
    filled_cylinder(voxels, cx, cz, 0, 14, 2, 28)
    # Foliage
    filled_sphere(voxels, cx, 20, cz, 7, 29)
    filled_sphere(voxels, cx - 3, 18, cz, 5, 30)
    filled_sphere(voxels, cx + 3, 18, cz, 5, 29)
    return voxels


def make_tree_pine():
    """Tall pine tree with cone foliage."""
    voxels = {}
    cx, cz = 6, 6
    # Trunk
    filled_cylinder(voxels, cx, cz, 0, 18, 1, 28)
    # Cone-shaped foliage layers
    for layer in range(5):
        y = 8 + layer * 3
        r = 5 - layer
        filled_cylinder(voxels, cx, cz, y, y + 2, r, 30 if layer % 2 == 0 else 29)
    return voxels


def make_tree_willow():
    """Weeping willow with droopy foliage."""
    voxels = {}
    cx, cz = 10, 10
    # Trunk
    filled_cylinder(voxels, cx, cz, 0, 16, 2, 28)
    # Wide canopy
    filled_ellipsoid(voxels, cx, 20, cz, 9, 6, 9, 29)
    # Drooping branches (vertical columns around edges)
    for angle_step in range(8):
        a = angle_step * math.pi / 4
        bx = cx + int(7 * math.cos(a))
        bz = cz + int(7 * math.sin(a))
        for y in range(12, 20):
            voxels[(bx, y, bz)] = 30
    return voxels


def make_rock_small():
    """Small round rock."""
    voxels = {}
    filled_ellipsoid(voxels, 4, 2, 4, 3, 2, 3, 31)
    # Darker patches
    filled_ellipsoid(voxels, 3, 2, 3, 1, 1, 1, 32)
    return voxels


def make_rock_medium():
    """Medium jagged rock."""
    voxels = {}
    filled_ellipsoid(voxels, 6, 3, 6, 5, 3, 4, 31)
    filled_ellipsoid(voxels, 7, 5, 6, 3, 2, 3, 32)
    return voxels


def make_rock_large():
    """Large boulder."""
    voxels = {}
    filled_ellipsoid(voxels, 8, 5, 8, 7, 5, 6, 31)
    filled_ellipsoid(voxels, 6, 6, 7, 4, 3, 3, 32)
    filled_ellipsoid(voxels, 10, 4, 9, 3, 2, 3, 32)
    return voxels


def make_bush():
    """Low round bush."""
    voxels = {}
    filled_ellipsoid(voxels, 5, 3, 5, 4, 3, 4, 30)
    filled_ellipsoid(voxels, 5, 4, 5, 3, 2, 3, 29)
    return voxels


def make_fence():
    """Simple wooden fence section."""
    voxels = {}
    # Posts
    filled_box(voxels, 0, 0, 1, 1, 7, 2, 33)
    filled_box(voxels, 8, 0, 1, 9, 7, 2, 33)
    # Planks
    filled_box(voxels, 1, 5, 1, 8, 6, 2, 33)
    filled_box(voxels, 1, 2, 1, 8, 3, 2, 33)
    return voxels


def make_sign():
    """Wooden sign post with board."""
    voxels = {}
    # Post
    filled_box(voxels, 3, 0, 2, 4, 8, 3, 28)
    # Sign board
    filled_box(voxels, 0, 7, 1, 7, 11, 2, 33)
    # Text hint (darker line)
    filled_box(voxels, 1, 9, 1, 6, 9, 1, 9)
    return voxels


def make_flower_red():
    """Small red flower."""
    voxels = {}
    # Stem
    voxels[(2, 0, 2)] = 37
    voxels[(2, 1, 2)] = 37
    voxels[(2, 2, 2)] = 37
    # Bloom
    voxels[(2, 3, 2)] = 34
    voxels[(1, 3, 2)] = 34
    voxels[(3, 3, 2)] = 34
    voxels[(2, 3, 1)] = 34
    voxels[(2, 3, 3)] = 34
    voxels[(2, 4, 2)] = 35  # center yellow
    return voxels


def make_flower_yellow():
    """Small yellow flower."""
    voxels = {}
    # Stem
    voxels[(2, 0, 2)] = 37
    voxels[(2, 1, 2)] = 37
    voxels[(2, 2, 2)] = 37
    # Bloom
    voxels[(2, 3, 2)] = 35
    voxels[(1, 3, 2)] = 35
    voxels[(3, 3, 2)] = 35
    voxels[(2, 3, 1)] = 35
    voxels[(2, 3, 3)] = 35
    voxels[(2, 4, 2)] = 34  # center red
    return voxels


def make_grass_tuft():
    """Small grass tuft - a few blades."""
    voxels = {}
    # Three blades
    for bx, bz in [(1, 2), (3, 2), (2, 3)]:
        voxels[(bx, 0, bz)] = 36
        voxels[(bx, 1, bz)] = 36
        voxels[(bx, 2, bz)] = 36
    # Middle blade taller
    voxels[(2, 3, 2)] = 36
    return voxels


# === .vox file writer ===

def write_vox(path, voxels, palette):
    """Write a MagicaVoxel .vox file."""
    if not voxels:
        print(f"  SKIP {path}: no voxels")
        return

    # Compute bounding box and offset to zero-origin
    keys = list(voxels.keys())
    min_x = min(k[0] for k in keys)
    min_y = min(k[1] for k in keys)
    min_z = min(k[2] for k in keys)
    max_x = max(k[0] for k in keys)
    max_y = max(k[1] for k in keys)
    max_z = max(k[2] for k in keys)

    godot_sx = max_x - min_x + 1
    godot_sy = max_y - min_y + 1
    godot_sz = max_z - min_z + 1

    # MagicaVoxel: MV(x, y_depth, z_up) = Godot(x, z, y)
    mv_sx = godot_sx
    mv_sy = godot_sz  # Godot.z -> MV.y
    mv_sz = godot_sy  # Godot.y -> MV.z

    # SIZE chunk
    size_content = struct.pack('<iii', mv_sx, mv_sy, mv_sz)

    # XYZI chunk
    num_voxels = len(voxels)
    xyzi_data = struct.pack('<i', num_voxels)
    for (gx, gy, gz), color_idx in voxels.items():
        mv_x = gx - min_x
        mv_y = gz - min_z  # Godot.z -> MV.y
        mv_z = gy - min_y  # Godot.y -> MV.z
        mv_color = (color_idx + 1) & 0xFF  # 0-based -> 1-based
        xyzi_data += struct.pack('BBBB', mv_x, mv_y, mv_z, mv_color)

    # RGBA chunk (256 entries x 4 bytes)
    rgba_data = b''
    for i in range(256):
        if i < len(palette):
            r, g, b, a = palette[i]
            rgba_data += struct.pack('BBBB',
                int(r * 255) & 0xFF,
                int(g * 255) & 0xFF,
                int(b * 255) & 0xFF,
                int(a * 255) & 0xFF)
        else:
            rgba_data += struct.pack('BBBB', 0, 0, 0, 255)

    def make_chunk(chunk_id, content, children=b''):
        return (chunk_id.encode('ascii') +
                struct.pack('<ii', len(content), len(children)) +
                content + children)

    size_chunk = make_chunk('SIZE', size_content)
    xyzi_chunk = make_chunk('XYZI', xyzi_data)
    rgba_chunk = make_chunk('RGBA', rgba_data)

    children = size_chunk + xyzi_chunk + rgba_chunk
    main_chunk = make_chunk('MAIN', b'', children)

    # Header: "VOX " + version 150
    header = b'VOX ' + struct.pack('<i', 150)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'wb') as f:
        f.write(header)
        f.write(main_chunk)

    print(f"  OK  {path} ({num_voxels} voxels, {godot_sx}x{godot_sy}x{godot_sz})")


# === Generate all models ===

def main():
    models = {
        "characters": {
            "warrior": make_kael,
            "mage": make_lyra,
            "rogue": make_vex,
        },
        "enemies": {
            "slime": make_slime,
            "goblin": make_goblin,
            "minotaur": make_minotaur,
        },
        "npcs": {
            "merchant": make_merchant,
            "blacksmith": make_blacksmith,
            "weaver": make_weaver,
            "doctor": make_doctor,
        },
        "world": {
            "tree_oak": make_tree_oak,
            "tree_pine": make_tree_pine,
            "tree_willow": make_tree_willow,
            "rock_small": make_rock_small,
            "rock_medium": make_rock_medium,
            "rock_large": make_rock_large,
            "bush": make_bush,
            "fence": make_fence,
            "sign": make_sign,
            "flower_red": make_flower_red,
            "flower_yellow": make_flower_yellow,
            "grass_tuft": make_grass_tuft,
        },
    }

    total = 0
    for category, items in models.items():
        print(f"\n=== {category.upper()} ===")
        for name, builder in items.items():
            path = os.path.join(BASE_DIR, category, f"{name}.vox")
            voxels = builder()
            write_vox(path, voxels, PALETTE)
            total += 1

    print(f"\nDone! Generated {total} .vox files.")


if __name__ == "__main__":
    main()
