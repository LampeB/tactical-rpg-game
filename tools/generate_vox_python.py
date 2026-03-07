"""
Generate MagicaVoxel .vox files for all game objects.
Run: python3 tools/generate_vox_python.py
"""
import struct
import os
import math
import json

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
    # 39: skin_medium (hands/face detail)
    (0.85, 0.68, 0.55, 1.0),
    # 40: boot_leather
    (0.42, 0.28, 0.15, 1.0),
    # 41: boot_leather_light
    (0.52, 0.38, 0.22, 1.0),
    # 42: glove_leather
    (0.48, 0.32, 0.18, 1.0),
    # 43: nail_color
    (0.75, 0.65, 0.55, 1.0),
    # 44: blue_steel_light (armor highlight)
    (0.45, 0.55, 0.72, 1.0),
    # 45: purple_light (robe highlight)
    (0.68, 0.42, 0.78, 1.0),
    # 46: green_light (cloak highlight)
    (0.40, 0.65, 0.42, 1.0),
    # 47: mouth_color
    (0.70, 0.45, 0.40, 1.0),
    # 48: outline_dark (Sukuna-style edge shading)
    (0.12, 0.10, 0.08, 1.0),
    # 49: skin_shadow (face/body contouring)
    (0.72, 0.55, 0.42, 1.0),
    # 50: armor_highlight (bright metal shine)
    (0.70, 0.72, 0.78, 1.0),
    # 51: cloth_white_shadow
    (0.78, 0.78, 0.76, 1.0),
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


def add_edge_shading(voxels, dark_color_idx, front_face_z=None):
    """Darken exposed side/back voxels for Sukuna-style depth.

    Skips the front face (lowest z or explicit front_face_z) to preserve detail.
    """
    if front_face_z is None:
        front_face_z = min(k[2] for k in voxels) if voxels else 0
    exposed = set()
    dirs = [(1,0,0),(-1,0,0),(0,1,0),(0,-1,0),(0,0,1),(0,0,-1)]
    for pos in voxels:
        for dx, dy, dz in dirs:
            if (pos[0]+dx, pos[1]+dy, pos[2]+dz) not in voxels:
                # Only shade sides and back, not front face
                if pos[2] != front_face_z:
                    exposed.add(pos)
                break
    for pos in exposed:
        voxels[pos] = dark_color_idx


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


# === Multi-part humanoid template ===

def humanoid_parts(torso_color, torso_dark, leg_color, arm_color, hair_color,
                   height=18, torso_width=6):
    """Create separate body parts for an articulated humanoid.

    Each part is a dict of (x, y, z) -> color_idx in local coordinates.
    Returns (parts_dict, assembly_metadata).
    """
    scale = height / 18.0
    hw = torso_width // 2

    leg_top = int(5 * scale)
    torso_bot = leg_top + 1
    torso_top = int(11 * scale)
    neck_y = torso_top + 1
    head_bot = neck_y + 1
    head_top = int(16 * scale)
    arm_top = torso_top - 1  # arms are 1 shorter than torso

    parts = {}

    # --- Legs (local: 2 wide x leg_height x 2 deep) ---
    for side_name in ("left_leg", "right_leg"):
        leg = {}
        filled_box(leg, 0, 0, 0, 1, leg_top, 1, leg_color)
        parts[side_name] = leg

    # --- Body (torso + neck, local coords) ---
    body = {}
    # Original torso: cx - hw//2 to cx + hw//2 (inclusive) = hw//2*2+1 voxels wide
    body_voxel_w = hw // 2 * 2 + 1
    filled_box(body, 0, 0, 0, body_voxel_w - 1, torso_top - torso_bot, 1, torso_color)
    # Neck (2 voxels wide, centered within body)
    neck_local_y = neck_y - torso_bot
    neck_cx = (body_voxel_w - 1) // 2
    filled_box(body, neck_cx, neck_local_y, 0, neck_cx + 1, neck_local_y, 1, 0)
    parts["body"] = body

    # --- Arms (local: 1 wide x arm_height x 2 deep) ---
    arm_h = arm_top - torso_bot  # voxels from 0 to arm_h
    for side_name in ("left_arm", "right_arm"):
        arm = {}
        filled_box(arm, 0, 0, 0, 0, arm_h, 1, arm_color)
        parts[side_name] = arm

    # --- Head (local: 4 wide x head_height x 4 deep) ---
    head = {}
    head_h = head_top - head_bot
    filled_box(head, 0, 0, 0, 3, head_h, 3, 0)  # skin
    # Hair top
    filled_box(head, 0, head_h, 0, 3, head_h + 1, 3, hair_color)
    # Hair back
    filled_box(head, 0, 1, 3, 3, head_h, 3, hair_color)
    # Eyes (front face)
    head[(1, 1, 0)] = 27
    head[(2, 1, 0)] = 27
    parts["head"] = head

    # --- Assembly metadata ---
    vs = 0.1  # voxel_size
    leg_height = (leg_top + 1) * vs
    arm_height = (arm_h + 1) * vs
    hip_y = round(leg_height, 3)
    shoulder_y = round((arm_top + 1) * vs, 3)
    neck_y_pos = round(head_bot * vs, 3)
    leg_x = round(1 * vs, 3)  # 1 voxel offset from center
    arm_x = round((hw // 2 + 1) * vs, 3)

    assembly = {
        "body":      {"node_name": "Body",     "pivot": [0.0, hip_y, 0.0],       "top_pivot": False},
        "head":      {"node_name": "Head",     "pivot": [0.0, neck_y_pos, 0.0],  "top_pivot": False},
        "left_leg":  {"node_name": "LeftLeg",  "pivot": [-leg_x, hip_y, 0.0],    "top_pivot": True},
        "right_leg": {"node_name": "RightLeg", "pivot": [leg_x, hip_y, 0.0],     "top_pivot": True},
        "left_arm":  {"node_name": "LeftArm",  "pivot": [-arm_x, shoulder_y, 0.0], "top_pivot": True},
        "right_arm": {"node_name": "RightArm", "pivot": [arm_x, shoulder_y, 0.0],  "top_pivot": True},
    }

    return parts, assembly


def add_body_customization(parts, voxels_to_add, part_name="body"):
    """Add custom voxels to a specific body part dict."""
    for pos, color in voxels_to_add.items():
        parts[part_name][pos] = color


# === High-resolution multi-part humanoid template ===

def humanoid_parts_hd(torso_color, torso_dark, leg_color, arm_color, hair_color,
                      skin_color=0, boot_color=40, glove_color=42,
                      height=30, torso_width=8):
    """Create high-resolution body parts for an articulated humanoid.

    30 voxels tall at voxel_size=0.06 => 1.8 Godot units (same world size).
    8 parts: body, head, left/right_leg, left/right_arm, left/right_hand, left/right_foot.
    """
    vs = 0.06  # voxel size

    # --- Proportions (scaled from 30-voxel base) ---
    hw = torso_width // 2  # half-width of torso

    foot_h = 2           # foot height in voxels
    leg_h = 9            # leg height (without foot)
    torso_h = 10         # torso height
    neck_h = 1           # neck
    head_h = 6           # head height
    arm_h = 8            # arm length (without hand)
    hand_h = 2           # hand height

    # Y positions (bottom-up)
    foot_top = foot_h - 1                    # 0..1
    leg_top = foot_h + leg_h - 1             # 2..10
    torso_bot = leg_top + 1                  # 11
    torso_top = torso_bot + torso_h - 1      # 11..20
    neck_bot = torso_top + 1                 # 21
    head_bot = neck_bot + neck_h             # 22
    head_top = head_bot + head_h - 1         # 22..27
    shoulder_y_vox = torso_top               # arms hang from top of torso
    arm_bot = shoulder_y_vox - arm_h + 1     # arms extend down from shoulder

    parts = {}

    # --- Legs: 3 wide x leg_h tall x 3 deep ---
    for side_name in ("left_leg", "right_leg"):
        leg = {}
        # Main leg column
        filled_box(leg, 0, 0, 0, 2, leg_h - 1, 2, leg_color)
        # Knee highlight (middle row, front face)
        knee_y = leg_h // 2
        leg[(0, knee_y, 0)] = torso_dark
        leg[(1, knee_y, 0)] = torso_dark
        leg[(2, knee_y, 0)] = torso_dark
        parts[side_name] = leg

    # --- Feet: 3 wide x foot_h tall x 4 deep (extends forward) ---
    for side_name in ("left_foot", "right_foot"):
        foot = {}
        filled_box(foot, 0, 0, 0, 2, foot_h - 1, 3, boot_color)
        # Toe cap (front, lighter)
        for x in range(3):
            foot[(x, 0, 3)] = 41  # boot_leather_light
            foot[(x, 1, 3)] = 41
        # Sole (bottom row slightly darker)
        for x in range(3):
            for z in range(4):
                foot[(x, 0, z)] = 9  # brown_dark sole
        parts[side_name] = foot

    # --- Body: torso_width wide x (torso_h + neck) x 4 deep ---
    body = {}
    body_w = torso_width
    body_d = 4
    filled_box(body, 0, 0, 0, body_w - 1, torso_h - 1, body_d - 1, torso_color)
    # Darker sides for depth
    for y in range(torso_h):
        for z in range(body_d):
            body[(0, y, z)] = torso_dark
            body[(body_w - 1, y, z)] = torso_dark
    # Darker back
    for x in range(body_w):
        for y in range(torso_h):
            body[(x, y, body_d - 1)] = torso_dark
    # Neck (centered, 2 wide x 2 deep)
    neck_cx = body_w // 2
    for x in range(neck_cx - 1, neck_cx + 1):
        for z in range(1, 3):
            body[(x, torso_h, z)] = skin_color
    parts["body"] = body

    # --- Arms: 2 wide x arm_h tall x 3 deep ---
    for side_name in ("left_arm", "right_arm"):
        arm = {}
        filled_box(arm, 0, 0, 0, 1, arm_h - 1, 2, arm_color)
        # Slight skin at bottom (exposed wrist)
        for x in range(2):
            for z in range(3):
                arm[(x, 0, z)] = skin_color
        parts[side_name] = arm

    # --- Hands: 2 wide x hand_h tall x 3 deep ---
    for side_name in ("left_hand", "right_hand"):
        hand = {}
        filled_box(hand, 0, 0, 0, 1, hand_h - 1, 2, skin_color)
        # Fingertip row
        for x in range(2):
            hand[(x, 0, 0)] = 43  # nail_color
            hand[(x, 0, 2)] = 43
        parts[side_name] = hand

    # --- Head: 6 wide x head_h tall x 5 deep ---
    head = {}
    head_w = 6
    head_d = 5
    # Base head shape (slightly rounded - cut corners)
    filled_box(head, 0, 0, 0, head_w - 1, head_h - 1, head_d - 1, skin_color)
    # Cut corners for rounder shape (remove 8 corner columns)
    for cx, cz in [(0, 0), (0, head_d - 1), (head_w - 1, 0), (head_w - 1, head_d - 1)]:
        for cy in range(head_h):
            if (cx, cy, cz) in head:
                del head[(cx, cy, cz)]

    # Hair (top 2 rows + back + sides)
    for x in range(head_w):
        for z in range(head_d):
            if (x, head_h - 1, z) in head or True:
                head[(x, head_h - 1, z)] = hair_color
                head[(x, head_h - 2, z)] = hair_color
    # Hair back
    for x in range(head_w):
        for y in range(1, head_h):
            head[(x, y, head_d - 1)] = hair_color
    # Hair sides
    for z in range(head_d):
        for y in range(head_h // 2, head_h):
            head[(0, y, z)] = hair_color
            head[(head_w - 1, y, z)] = hair_color

    # Face (front, z=0): eyes, eyebrows, mouth
    eye_y = 3  # eye height within head
    # Eyes (2 voxels each with white + pupil)
    head[(1, eye_y, 0)] = 26       # left eye white
    head[(2, eye_y, 0)] = 27       # left pupil
    head[(3, eye_y, 0)] = 27       # right pupil
    head[(4, eye_y, 0)] = 26       # right eye white
    # Eyebrows
    head[(1, eye_y + 1, 0)] = hair_color
    head[(2, eye_y + 1, 0)] = hair_color
    head[(3, eye_y + 1, 0)] = hair_color
    head[(4, eye_y + 1, 0)] = hair_color
    # Mouth
    head[(2, 1, 0)] = 47  # mouth_color
    head[(3, 1, 0)] = 47
    # Nose
    head[(2, 2, 0)] = 39  # skin_medium (slight bump)
    head[(3, 2, 0)] = 39
    # Ears
    head[(0, eye_y, 2)] = 39      # left ear
    head[(head_w - 1, eye_y, 2)] = 39  # right ear

    parts["head"] = head

    # --- Assembly metadata ---
    leg_height_units = round((foot_h + leg_h) * vs, 3)
    hip_y = round(leg_height_units, 3)
    shoulder_y_units = round((torso_top + 1) * vs, 3)
    neck_y_units = round(head_bot * vs, 3)
    leg_x = round(2 * vs, 3)  # offset from center for legs
    arm_x = round((hw + 1) * vs, 3)  # offset from center for arms
    wrist_y_local = round(-arm_h * vs, 3)  # local to arm pivot
    ankle_y_local = round(-leg_h * vs, 3)  # local to leg pivot

    assembly = {
        "voxel_size": vs,
        "body":       {"node_name": "Body",      "pivot": [0.0, hip_y, 0.0],         "top_pivot": False},
        "head":       {"node_name": "Head",       "pivot": [0.0, neck_y_units, 0.0],  "top_pivot": False},
        "left_leg":   {"node_name": "LeftLeg",    "pivot": [-leg_x, hip_y, 0.0],      "top_pivot": True},
        "right_leg":  {"node_name": "RightLeg",   "pivot": [leg_x, hip_y, 0.0],       "top_pivot": True},
        "left_arm":   {"node_name": "LeftArm",    "pivot": [-arm_x, shoulder_y_units, 0.0], "top_pivot": True},
        "right_arm":  {"node_name": "RightArm",   "pivot": [arm_x, shoulder_y_units, 0.0],  "top_pivot": True},
        "left_hand":  {"node_name": "LeftHand",   "pivot": [0.0, wrist_y_local, 0.0],  "top_pivot": False, "parent": "LeftArm"},
        "right_hand": {"node_name": "RightHand",  "pivot": [0.0, wrist_y_local, 0.0],  "top_pivot": False, "parent": "RightArm"},
        "left_foot":  {"node_name": "LeftFoot",   "pivot": [0.0, ankle_y_local, 0.0],  "top_pivot": False, "parent": "LeftLeg"},
        "right_foot": {"node_name": "RightFoot",  "pivot": [0.0, ankle_y_local, 0.0],  "top_pivot": False, "parent": "RightLeg"},
    }

    return parts, assembly


# === Multi-part character builders ===

def make_kael_parts():
    """Warrior multi-part: blue steel armor, broad build."""
    parts, assembly = humanoid_parts(
        torso_color=2, torso_dark=3, leg_color=3,
        arm_color=2, hair_color=17, height=18, torso_width=8
    )
    # Shoulder pads on body (body is 4 wide: 0..4, shoulder pads at edges)
    body = parts["body"]
    for y in range(4, 7):  # top of torso
        body[(0, y, 0)] = 10  # left pad
        body[(0, y, 1)] = 10
        body[(4, y, 0)] = 10  # right pad
        body[(4, y, 1)] = 10
    # Belt (bottom row of body)
    for x in range(5):
        body[(x, 0, 0)] = 9
    return parts, assembly


def make_lyra_parts():
    """Mage multi-part: purple robe, pointed hat."""
    parts, assembly = humanoid_parts(
        torso_color=4, torso_dark=5, leg_color=5,
        arm_color=4, hair_color=18, height=18, torso_width=6
    )
    # Robe extension on legs (overwrite with robe color)
    for side in ("left_leg", "right_leg"):
        leg = parts[side]
        for y in range(6):
            for x in range(2):
                for z in range(2):
                    leg[(x, y, z)] = 5  # dark purple robe
    # Pointed hat on head
    head = parts["head"]
    # Hat brim (wider than head)
    for x in range(4):
        for z in range(4):
            head[(x, 5, z)] = 4  # purple
    # Hat cone
    head[(1, 6, 1)] = 4
    head[(2, 6, 1)] = 4
    head[(1, 6, 2)] = 4
    head[(2, 6, 2)] = 4
    head[(1, 7, 1)] = 4  # tip
    return parts, assembly


def make_vex_parts():
    """Rogue multi-part: green hood, slim build."""
    parts, assembly = humanoid_parts(
        torso_color=6, torso_dark=7, leg_color=7,
        arm_color=6, hair_color=19, height=18, torso_width=6
    )
    # Hood on head (overwrites hair)
    head = parts["head"]
    for x in range(4):
        for z in range(4):
            for y in range(2, 5):
                head[(x, y, z)] = 7  # dark green hood
    # Face opening
    head[(1, 2, 0)] = 0  # skin
    head[(2, 2, 0)] = 0
    head[(1, 1, 0)] = 27  # eyes still visible
    head[(2, 1, 0)] = 27
    # Belt on body
    body = parts["body"]
    for x in range(3):
        body[(x, 0, 0)] = 9
    return parts, assembly


def make_goblin_parts():
    """Goblin multi-part: small green humanoid with big head."""
    parts, assembly = humanoid_parts(
        torso_color=22, torso_dark=23, leg_color=23,
        arm_color=22, hair_color=23, height=12, torso_width=6
    )
    # Override head to be bigger (5 wide x 4 tall x 4 deep)
    head = {}
    filled_box(head, 0, 0, 0, 4, 3, 3, 22)
    # Pointy ears
    head[(0, 1, 1)] = 22  # extra width for ears
    head[(5, 1, 1)] = 22
    # Eyes
    head[(1, 1, 0)] = 26  # white
    head[(3, 1, 0)] = 26
    parts["head"] = head
    return parts, assembly


def make_minotaur_parts():
    """Minotaur multi-part: large brown humanoid with horns."""
    parts, assembly = humanoid_parts(
        torso_color=24, torso_dark=25, leg_color=25,
        arm_color=24, hair_color=19, height=25, torso_width=10
    )
    # Horns on head
    head = parts["head"]
    # Existing head is 4 wide, add horn voxels above and to sides
    head_h = max(k[1] for k in head.keys())
    for dy in range(3):
        head[(0, head_h + dy, 1)] = 38  # left horn
        head[(3, head_h + dy, 1)] = 38  # right horn
    head[(0, head_h + 2, 0)] = 38  # horn tip curves
    head[(3, head_h + 2, 0)] = 38
    # Snout (front of head)
    head[(1, 1, 0)] = 24  # override eyes with snout
    head[(2, 1, 0)] = 24
    return parts, assembly


def make_merchant_parts():
    """Merchant multi-part: brown leather with apron."""
    parts, assembly = humanoid_parts(
        torso_color=8, torso_dark=9, leg_color=9,
        arm_color=8, hair_color=17, height=18, torso_width=7
    )
    # Apron on body front
    body = parts["body"]
    for y in range(5):
        body[(1, y, 0)] = 9
        body[(2, y, 0)] = 9
    return parts, assembly


def make_blacksmith_parts():
    """Blacksmith multi-part: grey metal, muscular."""
    parts, assembly = humanoid_parts(
        torso_color=10, torso_dark=11, leg_color=9,
        arm_color=8, hair_color=19, height=18, torso_width=8
    )
    # Apron on body
    body = parts["body"]
    for y in range(4):
        body[(1, y, 0)] = 11
        body[(2, y, 0)] = 11
        body[(3, y, 0)] = 11
    return parts, assembly


def make_weaver_parts():
    """Weaver multi-part: teal robes, hooded."""
    parts, assembly = humanoid_parts(
        torso_color=12, torso_dark=13, leg_color=13,
        arm_color=12, hair_color=19, height=18, torso_width=6
    )
    # Robe on legs
    for side in ("left_leg", "right_leg"):
        leg = parts[side]
        for y in range(6):
            for x in range(2):
                for z in range(2):
                    leg[(x, y, z)] = 13
    # Hood on head
    head = parts["head"]
    for x in range(4):
        for z in range(4):
            for y in range(2, 5):
                head[(x, y, z)] = 13
    head[(1, 2, 0)] = 0  # face
    head[(2, 2, 0)] = 0
    head[(1, 1, 0)] = 27
    head[(2, 1, 0)] = 27
    return parts, assembly


def make_doctor_parts():
    """Doctor multi-part: white cloth with red cross."""
    parts, assembly = humanoid_parts(
        torso_color=14, torso_dark=14, leg_color=14,
        arm_color=14, hair_color=17, height=18, torso_width=6
    )
    # Red cross on body front
    body = parts["body"]
    body[(1, 2, 0)] = 15  # center
    body[(0, 2, 0)] = 15  # left
    body[(2, 2, 0)] = 15  # right (if wide enough)
    body[(1, 3, 0)] = 15  # top
    body[(1, 1, 0)] = 15  # bottom
    return parts, assembly


# === HD multi-part character builders ===

def make_kael_parts_hd():
    """Warrior HD: blue steel armor, broad build, shoulder pads, gauntlets."""
    parts, assembly = humanoid_parts_hd(
        torso_color=2, torso_dark=3, leg_color=3,
        arm_color=2, hair_color=17, boot_color=40, glove_color=10,
        height=30, torso_width=8
    )
    body = parts["body"]
    bw = 8  # body width

    # Shoulder pads (top rows of body, sides, metal grey)
    for y in range(8, 10):
        for z in range(4):
            body[(0, y, z)] = 10
            body[(1, y, z)] = 10
            body[(bw - 2, y, z)] = 10
            body[(bw - 1, y, z)] = 10

    # Chest plate detail (front face, lighter center stripe)
    for y in range(3, 8):
        body[(3, y, 0)] = 44  # blue_steel_light
        body[(4, y, 0)] = 44

    # Belt (gold accent)
    for x in range(bw):
        body[(x, 1, 0)] = 16  # gold_accent
        body[(x, 1, 1)] = 9   # brown_dark behind

    # Belt buckle
    body[(3, 1, 0)] = 16
    body[(4, 1, 0)] = 16
    body[(3, 2, 0)] = 16
    body[(4, 2, 0)] = 16

    # Arms: gauntlets (metal instead of skin at wrist)
    for side in ("left_arm", "right_arm"):
        arm = parts[side]
        for x in range(2):
            for z in range(3):
                arm[(x, 0, z)] = 10   # grey_metal wrist guard
                arm[(x, 1, z)] = 10

    # Hands: armored gauntlets
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 10  # grey_metal gauntlets

    # Legs: armored greaves (metal shin guards on front)
    for side in ("left_leg", "right_leg"):
        leg = parts[side]
        for y in range(3, 7):
            leg[(1, y, 0)] = 10  # shin guard front

    # Boots: metal-tipped
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for x in range(3):
            foot[(x, 1, 3)] = 10  # metal toe cap

    return parts, assembly


def make_lyra_parts_hd():
    """Mage HD: purple robe, pointed wizard hat, flowing sleeves."""
    parts, assembly = humanoid_parts_hd(
        torso_color=4, torso_dark=5, leg_color=5,
        arm_color=4, hair_color=18, boot_color=5, glove_color=4,
        height=30, torso_width=6
    )
    body = parts["body"]
    bw = 6  # body width

    # Robe details on body (vertical trim down center)
    for y in range(10):
        body[(2, y, 0)] = 45  # purple_light center trim
        body[(3, y, 0)] = 45

    # Sash/belt (gold)
    for x in range(bw):
        body[(x, 3, 0)] = 16
    body[(2, 3, 0)] = 16
    body[(3, 3, 0)] = 16

    # Robe extension on legs (purple robe over legs)
    for side in ("left_leg", "right_leg"):
        leg = parts[side]
        for y in range(9):
            for x in range(3):
                for z in range(3):
                    leg[(x, y, z)] = 5  # dark purple robe

    # Pointed hat on head (replaces hair top)
    head = parts["head"]
    head_w = 6
    head_d = 5
    # Hat brim (wider than head at top)
    for x in range(head_w):
        for z in range(head_d):
            head[(x, 5, z)] = 4  # purple brim
    # Hat cone layers
    for x in range(1, 5):
        for z in range(1, 4):
            head[(x, 6, z)] = 4
    for x in range(2, 4):
        for z in range(1, 4):
            head[(x, 7, z)] = 4
    # Hat tip
    head[(2, 8, 2)] = 4
    head[(3, 8, 2)] = 4
    head[(2, 9, 2)] = 4  # very tip

    # Sleeves: wider at bottom (robe sleeves)
    for side in ("left_arm", "right_arm"):
        arm = parts[side]
        # Widen bottom of arms with robe color
        for z in range(3):
            arm[(0, 0, z)] = 4
            arm[(1, 0, z)] = 4

    # Hands: cloth-wrapped
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 4  # purple cloth wrappings

    # Feet: sandals over robe (barely visible)
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for pos in list(foot.keys()):
            foot[pos] = 5  # dark purple, blends with robe

    return parts, assembly


def make_vex_parts_hd():
    """Rogue HD: green hooded cloak, leather armor, daggers."""
    parts, assembly = humanoid_parts_hd(
        torso_color=6, torso_dark=7, leg_color=7,
        arm_color=6, hair_color=19, boot_color=9, glove_color=42,
        height=30, torso_width=6
    )
    body = parts["body"]
    bw = 6  # body width

    # Leather vest over cloak (front face detail)
    for y in range(4, 9):
        body[(2, y, 0)] = 8  # brown_leather vest
        body[(3, y, 0)] = 8
    for y in range(4, 9):
        body[(1, y, 0)] = 9  # brown_dark edge
        body[(4, y, 0)] = 9

    # Belt with dagger sheaths
    for x in range(bw):
        body[(x, 2, 0)] = 9  # dark belt
    body[(0, 1, 0)] = 10  # left dagger sheath
    body[(0, 2, 0)] = 10
    body[(bw - 1, 1, 0)] = 10  # right dagger sheath
    body[(bw - 1, 2, 0)] = 10

    # Hood on head
    head = parts["head"]
    head_w = 6
    head_d = 5
    # Hood covers top and back of head
    for x in range(head_w):
        for z in range(head_d):
            for y in range(3, 6):
                if (x, y, z) in head:
                    head[(x, y, z)] = 7  # dark green hood
    # Hood peak
    for x in range(1, 5):
        for z in range(1, 4):
            head[(x, 6, z)] = 7
    # Face opening (front, lower half visible)
    for x in range(1, 5):
        for y in range(0, 4):
            head[(x, y, 0)] = 0  # skin
    # Re-add facial features
    head[(1, 3, 0)] = 27   # left eye
    head[(2, 3, 0)] = 27
    head[(3, 3, 0)] = 27   # right eye
    head[(4, 3, 0)] = 27
    head[(2, 1, 0)] = 47   # mouth
    head[(3, 1, 0)] = 47
    head[(2, 2, 0)] = 39   # nose
    head[(3, 2, 0)] = 39

    # Gloved hands (dark leather)
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 42  # glove_leather

    # Dark boots
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for pos in list(foot.keys()):
            foot[pos] = 9  # brown_dark

    return parts, assembly


# === Sukuna-quality humanoid template (60 voxels tall, vs=0.03) ===

def sukuna_humanoid_parts(torso_color, torso_dark, leg_color, arm_color, hair_color,
                          skin_color=0, boot_color=40, glove_color=42,
                          torso_width=14, body_depth=8, height_scale=1.0):
    """Create Sukuna-quality body parts: 60 voxels tall at voxel_size=0.03.

    Produces 16 articulated parts:
    Hip, Belly, Chest, Head,
    LeftThigh, LeftLeg, LeftFoot, RightThigh, RightLeg, RightFoot,
    LeftArm, LeftForearm, LeftHand, RightArm, RightForearm, RightHand.

    height_scale: 1.0=standard (1.8 units), 0.7=goblin, 1.4=minotaur.
    Returns (parts_dict, assembly_metadata).
    """
    vs = 0.03  # voxel size

    # --- Proportions (scaled from 60-voxel base) ---
    def sv(v):
        return max(1, int(round(v * height_scale)))

    foot_h = sv(5)
    thigh_h = sv(10)
    calf_h = sv(8)
    hip_h = sv(5)
    belly_h = sv(5)
    chest_h = sv(9)   # includes neck (2 rows)
    head_h = sv(16)
    upper_arm_h = sv(8)
    forearm_h = sv(6)
    hand_h = sv(4)

    hw = torso_width // 2
    bd = body_depth

    # Head dimensions scale with height
    head_w = max(6, sv(10))
    head_d = max(5, sv(8))
    # Arm dimensions
    arm_w = max(2, sv(4))
    arm_d = max(2, sv(4))
    # Leg dimensions
    leg_w = max(3, sv(6))
    leg_d = max(3, sv(6))
    # Foot dimensions
    foot_w = max(3, sv(6))
    foot_d = max(4, sv(7))
    # Hand dimensions
    hand_w = max(2, sv(4))
    hand_d = max(2, sv(4))

    # Torso narrows: hip slightly narrower than chest
    hip_w = max(4, torso_width - 2)
    belly_w = max(4, torso_width - 1)
    chest_w = torso_width

    # Y positions (bottom-up, absolute)
    foot_top = foot_h - 1
    calf_top = foot_h + calf_h - 1
    thigh_top = foot_h + calf_h + thigh_h - 1
    hip_bot = thigh_top + 1
    belly_bot = hip_bot + hip_h
    chest_bot = belly_bot + belly_h
    chest_top = chest_bot + chest_h - 1
    shoulder_vox = chest_top - 2
    head_bot_y = chest_top + 1

    parts = {}

    # --- Hip: hip_w x hip_h x body_depth ---
    hip = {}
    filled_box(hip, 0, 0, 0, hip_w - 1, hip_h - 1, bd - 1, torso_dark)
    # Belt at top
    for x in range(hip_w):
        hip[(x, hip_h - 1, 0)] = 9  # brown_dark belt front
    # Darker sides
    for y in range(hip_h):
        for z in range(bd):
            hip[(0, y, z)] = torso_dark
            hip[(hip_w - 1, y, z)] = torso_dark
    parts["hip"] = hip

    # --- Belly: belly_w x belly_h x body_depth ---
    belly = {}
    filled_box(belly, 0, 0, 0, belly_w - 1, belly_h - 1, bd - 1, torso_color)
    # Darker sides
    for y in range(belly_h):
        for z in range(bd):
            belly[(0, y, z)] = torso_dark
            belly[(belly_w - 1, y, z)] = torso_dark
        for x in range(belly_w):
            belly[(x, y, bd - 1)] = torso_dark
    parts["belly"] = belly

    # --- Chest: chest_w x chest_h x body_depth (includes neck at top) ---
    chest = {}
    filled_box(chest, 0, 0, 0, chest_w - 1, chest_h - 1, bd - 1, torso_color)
    # Darker sides
    for y in range(chest_h):
        for z in range(bd):
            chest[(0, y, z)] = torso_dark
            chest[(chest_w - 1, y, z)] = torso_dark
        for x in range(chest_w):
            chest[(x, y, bd - 1)] = torso_dark
    # Neck zone at top (skin colored, centered narrower)
    neck_rows = max(1, sv(2))
    neck_w = max(2, chest_w // 3)
    neck_start_x = (chest_w - neck_w) // 2
    neck_d = max(2, bd // 2)
    neck_start_z = (bd - neck_d) // 2
    for y in range(chest_h - neck_rows, chest_h):
        for x in range(chest_w):
            for z in range(bd):
                if (x, y, z) in chest:
                    del chest[(x, y, z)]
        for x in range(neck_start_x, neck_start_x + neck_w):
            for z in range(neck_start_z, neck_start_z + neck_d):
                chest[(x, y, z)] = skin_color
    parts["chest"] = chest

    # --- Thighs: leg_w x thigh_h x leg_d ---
    for side_name in ("left_thigh", "right_thigh"):
        thigh = {}
        filled_box(thigh, 0, 0, 0, leg_w - 1, thigh_h - 1, leg_d - 1, leg_color)
        # Darker sides
        for y in range(thigh_h):
            for z in range(leg_d):
                thigh[(0, y, z)] = torso_dark
                thigh[(leg_w - 1, y, z)] = torso_dark
            thigh[(leg_w // 2, y, leg_d - 1)] = torso_dark
        parts[side_name] = thigh

    # --- Calves (LeftLeg/RightLeg): leg_w x calf_h x leg_d ---
    for side_name in ("left_leg", "right_leg"):
        calf = {}
        filled_box(calf, 0, 0, 0, leg_w - 1, calf_h - 1, leg_d - 1, leg_color)
        # Knee highlight at top
        for x in range(leg_w):
            calf[(x, calf_h - 1, 0)] = torso_dark
        # Darker sides
        for y in range(calf_h):
            for z in range(leg_d):
                calf[(0, y, z)] = torso_dark
                calf[(leg_w - 1, y, z)] = torso_dark
            calf[(leg_w // 2, y, leg_d - 1)] = torso_dark
        parts[side_name] = calf

    # --- Feet: foot_w x foot_h x foot_d (extends forward) ---
    for side_name in ("left_foot", "right_foot"):
        foot = {}
        filled_box(foot, 0, 0, 0, foot_w - 1, foot_h - 1, foot_d - 1, boot_color)
        # Toe cap (front, lighter)
        for x in range(foot_w):
            for y in range(foot_h):
                foot[(x, y, foot_d - 1)] = 41  # boot_leather_light
        # Sole (bottom row darker)
        for x in range(foot_w):
            for z in range(foot_d):
                foot[(x, 0, z)] = 9  # brown_dark sole
        parts[side_name] = foot

    # --- Upper Arms: arm_w x upper_arm_h x arm_d ---
    for side_name in ("left_arm", "right_arm"):
        arm = {}
        filled_box(arm, 0, 0, 0, arm_w - 1, upper_arm_h - 1, arm_d - 1, arm_color)
        parts[side_name] = arm

    # --- Forearms: arm_w x forearm_h x arm_d ---
    for side_name in ("left_forearm", "right_forearm"):
        forearm = {}
        filled_box(forearm, 0, 0, 0, arm_w - 1, forearm_h - 1, arm_d - 1, arm_color)
        # Skin at wrist (bottom 2 rows)
        for x in range(arm_w):
            for z in range(arm_d):
                forearm[(x, 0, z)] = skin_color
                forearm[(x, 1, z)] = skin_color
        parts[side_name] = forearm

    # --- Hands: hand_w x hand_h x hand_d ---
    for side_name in ("left_hand", "right_hand"):
        hand = {}
        filled_box(hand, 0, 0, 0, hand_w - 1, hand_h - 1, hand_d - 1, skin_color)
        # Fingertip row (darker)
        for x in range(hand_w):
            for z in range(hand_d):
                hand[(x, 0, z)] = 43  # nail_color
        parts[side_name] = hand

    # --- Head: head_w x head_h x head_d (rounded with face) ---
    head = {}
    filled_box(head, 0, 0, 0, head_w - 1, head_h - 1, head_d - 1, skin_color)
    # Cut corners for rounder shape
    for cy in range(head_h):
        for cx, cz in [(0, 0), (0, head_d - 1), (head_w - 1, 0), (head_w - 1, head_d - 1)]:
            if (cx, cy, cz) in head:
                del head[(cx, cy, cz)]
    # Also round top corners
    for cx, cz in [(0, 0), (0, head_d - 1), (head_w - 1, 0), (head_w - 1, head_d - 1),
                   (1, 0), (0, 1), (1, head_d - 1), (0, head_d - 2),
                   (head_w - 2, 0), (head_w - 1, 1), (head_w - 2, head_d - 1), (head_w - 1, head_d - 2)]:
        top_y = head_h - 1
        if (cx, top_y, cz) in head:
            del head[(cx, top_y, cz)]

    # Hair: top rows + back + sides upper half
    hair_start_y = head_h // 2
    for y in range(head_h - 3, head_h):
        for x in range(head_w):
            for z in range(head_d):
                if (x, y, z) in head:
                    head[(x, y, z)] = hair_color
    for x in range(head_w):
        for y in range(1, head_h):
            if (x, y, head_d - 1) in head:
                head[(x, y, head_d - 1)] = hair_color
    for z in range(head_d):
        for y in range(hair_start_y, head_h):
            for side_x in [0, head_w - 1]:
                if (side_x, y, z) in head:
                    head[(side_x, y, z)] = hair_color

    # Face features (front face z=0)
    eye_y = head_h // 2 - 1
    face_left = head_w // 2 - 2
    face_right = head_w // 2 + 1
    if face_left >= 0 and face_right < head_w:
        head[(face_left, eye_y, 0)] = 26
        head[(face_left + 1, eye_y, 0)] = 27
        head[(face_right - 1, eye_y, 0)] = 27
        head[(face_right, eye_y, 0)] = 26
        for x in range(face_left, face_right + 1):
            head[(x, eye_y + 1, 0)] = hair_color
    nose_y = eye_y - 1
    mid_x = head_w // 2
    head[(mid_x - 1, nose_y, 0)] = 39
    head[(mid_x, nose_y, 0)] = 39
    mouth_y = nose_y - 2
    if mouth_y >= 0:
        head[(mid_x - 1, mouth_y, 0)] = 47
        head[(mid_x, mouth_y, 0)] = 47
    head[(0, eye_y, head_d // 2)] = 39
    head[(head_w - 1, eye_y, head_d // 2)] = 39

    parts["head"] = head

    # --- Assembly metadata (16-part hierarchy) ---
    hip_y_abs = (foot_h + calf_h + thigh_h) * vs
    belly_local_y = round(hip_h * vs, 3)
    chest_local_y = round(belly_h * vs, 3)
    head_local_y = round(chest_h * vs, 3)

    leg_x = round((hip_w // 4) * vs, 3)
    thigh_local_y = round(-hip_h * vs * 0.1, 3)  # slightly below hip bottom
    calf_local_y = round(-thigh_h * vs, 3)
    ankle_local_y = round(-calf_h * vs, 3)

    arm_x = round((chest_w // 2 + 1) * vs, 3)
    arm_local_y = round((chest_h - 2) * vs, 3)  # near top of chest
    forearm_local_y = round(-upper_arm_h * vs, 3)
    wrist_local_y = round(-forearm_h * vs, 3)

    assembly = {
        "voxel_size": vs,
        "hip":            {"node_name": "Hip",           "pivot": [0.0, round(hip_y_abs, 3), 0.0], "top_pivot": False},
        "belly":          {"node_name": "Belly",         "pivot": [0.0, belly_local_y, 0.0],       "top_pivot": False, "parent": "Hip"},
        "chest":          {"node_name": "Chest",         "pivot": [0.0, chest_local_y, 0.0],       "top_pivot": False, "parent": "Belly"},
        "head":           {"node_name": "Head",          "pivot": [0.0, head_local_y, 0.0],        "top_pivot": False, "parent": "Chest"},
        "left_thigh":     {"node_name": "LeftThigh",     "pivot": [-leg_x, thigh_local_y, 0.0],    "top_pivot": True,  "parent": "Hip"},
        "right_thigh":    {"node_name": "RightThigh",    "pivot": [leg_x, thigh_local_y, 0.0],     "top_pivot": True,  "parent": "Hip"},
        "left_leg":       {"node_name": "LeftLeg",       "pivot": [0.0, calf_local_y, 0.0],        "top_pivot": True,  "parent": "LeftThigh"},
        "right_leg":      {"node_name": "RightLeg",      "pivot": [0.0, calf_local_y, 0.0],        "top_pivot": True,  "parent": "RightThigh"},
        "left_foot":      {"node_name": "LeftFoot",      "pivot": [0.0, ankle_local_y, 0.0],       "top_pivot": False, "parent": "LeftLeg"},
        "right_foot":     {"node_name": "RightFoot",     "pivot": [0.0, ankle_local_y, 0.0],       "top_pivot": False, "parent": "RightLeg"},
        "left_arm":       {"node_name": "LeftArm",       "pivot": [-arm_x, arm_local_y, 0.0],      "top_pivot": True,  "parent": "Chest"},
        "right_arm":      {"node_name": "RightArm",      "pivot": [arm_x, arm_local_y, 0.0],       "top_pivot": True,  "parent": "Chest"},
        "left_forearm":   {"node_name": "LeftForearm",   "pivot": [0.0, forearm_local_y, 0.0],     "top_pivot": True,  "parent": "LeftArm"},
        "right_forearm":  {"node_name": "RightForearm",  "pivot": [0.0, forearm_local_y, 0.0],     "top_pivot": True,  "parent": "RightArm"},
        "left_hand":      {"node_name": "LeftHand",      "pivot": [0.0, wrist_local_y, 0.0],       "top_pivot": False, "parent": "LeftForearm"},
        "right_hand":     {"node_name": "RightHand",     "pivot": [0.0, wrist_local_y, 0.0],       "top_pivot": False, "parent": "RightForearm"},
    }

    return parts, assembly


# === Sukuna-quality character builders ===

def make_kael_sukuna():
    """Warrior Sukuna-quality: blue steel armor, shoulder pads, gauntlets, wide build."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=2, torso_dark=3, leg_color=3,
        arm_color=2, hair_color=17, boot_color=40, glove_color=10,
        torso_width=16, body_depth=9,
    )
    chest = parts["chest"]   # 16w x 9h x 9d
    belly = parts["belly"]   # 15w x 5h x 9d
    hip = parts["hip"]       # 14w x 5h x 9d

    # Shoulder pads on chest (top rows below neck, metal grey)
    for y in range(4, 7):
        for z in range(9):
            for dx in range(3):
                chest[(dx, y, z)] = 10       # left shoulder
                chest[(15 - dx, y, z)] = 10  # right shoulder

    # Chest plate detail (center stripe, lighter blue)
    for y in range(0, 7):
        chest[(7, y, 0)] = 44
        chest[(8, y, 0)] = 44
    for y in range(0, 5):
        belly[(7, y, 0)] = 44

    # Belt buckle on hip (gold accent)
    for x in range(14):
        hip[(x, 4, 0)] = 16  # gold belt at top
    hip[(6, 3, 0)] = 16  # buckle
    hip[(7, 3, 0)] = 16

    # Forearms: full metal gauntlets
    for side in ("left_forearm", "right_forearm"):
        forearm = parts[side]
        for pos in list(forearm.keys()):
            forearm[pos] = 10

    # Hands: armored gauntlets
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 10  # grey_metal gauntlets

    # Shin guards on thighs (front)
    for side in ("left_thigh", "right_thigh"):
        thigh = parts[side]
        for y in range(2, 10):
            for x in range(1, 5):
                thigh[(x, y, 0)] = 10

    # Shin guards on calves (front)
    for side in ("left_leg", "right_leg"):
        calf = parts[side]
        for y in range(1, 7):
            for x in range(1, 5):
                calf[(x, y, 0)] = 10

    # Boots: metal-tipped
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for x in range(6):
            for y in range(1, 5):
                foot[(x, y, 6)] = 10  # metal toe cap

    # Edge shading on torso parts
    for part in (hip, belly, chest):
        add_edge_shading(part, 48)

    return parts, assembly


def make_lyra_sukuna():
    """Mage Sukuna-quality: purple robe, wizard hat, flowing sleeves, slender."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=4, torso_dark=5, leg_color=5,
        arm_color=4, hair_color=18, boot_color=5, glove_color=4,
        torso_width=12, body_depth=7,
    )
    chest = parts["chest"]   # 12w x 9h
    belly = parts["belly"]   # 11w x 5h
    hip = parts["hip"]       # 10w x 5h

    # Robe trim down center (lighter purple)
    for y in range(5):
        hip[(4, y, 0)] = 45
        hip[(5, y, 0)] = 45
    for y in range(5):
        belly[(5, y, 0)] = 45
    for y in range(7):
        chest[(5, y, 0)] = 45
        chest[(6, y, 0)] = 45

    # Gold sash at waist (belly)
    for x in range(11):
        belly[(x, 2, 0)] = 16
        belly[(x, 3, 0)] = 16

    # Robe covers legs entirely (dark purple)
    for side in ("left_thigh", "right_thigh", "left_leg", "right_leg"):
        leg_part = parts[side]
        for pos in list(leg_part.keys()):
            leg_part[pos] = 5

    # Pointed wizard hat on head
    head = parts["head"]
    head_w = 10
    head_d = 8
    head_h = 16
    for x in range(head_w):
        for z in range(head_d):
            head[(x, head_h - 3, z)] = 4  # purple brim
    for layer in range(4):
        inset = layer + 1
        y_base = head_h - 2 + layer
        for x in range(inset, head_w - inset):
            for z in range(inset, head_d - inset):
                head[(x, y_base, z)] = 4
    tip_x = head_w // 2
    tip_z = head_d // 2
    head[(tip_x, head_h + 2, tip_z)] = 4
    head[(tip_x - 1, head_h + 2, tip_z)] = 4
    head[(tip_x, head_h + 3, tip_z)] = 4

    # Robe sleeves: upper arms in robe color
    for side in ("left_arm", "right_arm"):
        arm = parts[side]
        for pos in list(arm.keys()):
            arm[pos] = 4

    # Forearms: darker flowing sleeves
    for side in ("left_forearm", "right_forearm"):
        forearm = parts[side]
        for pos in list(forearm.keys()):
            forearm[pos] = 5

    # Hands: cloth-wrapped purple
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 4

    # Feet: barely visible under robe
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for pos in list(foot.keys()):
            foot[pos] = 5

    for part in (hip, belly, chest):
        add_edge_shading(part, 48)
    return parts, assembly


def make_vex_sukuna():
    """Rogue Sukuna-quality: green hooded cloak, leather vest, daggers, agile."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=6, torso_dark=7, leg_color=7,
        arm_color=6, hair_color=19, boot_color=9, glove_color=42,
        torso_width=12, body_depth=7,
    )
    chest = parts["chest"]   # 12w x 9h
    belly = parts["belly"]   # 11w x 5h
    hip = parts["hip"]       # 10w x 5h

    # Leather vest on chest (front face, center)
    for y in range(0, 7):
        for x in range(4, 8):
            chest[(x, y, 0)] = 8  # brown_leather
        chest[(3, y, 0)] = 9  # dark edge
        chest[(8, y, 0)] = 9

    # Vest continues on belly
    for y in range(3, 5):
        for x in range(4, 7):
            belly[(x, y, 0)] = 8

    # Belt with dagger sheaths on belly
    for x in range(11):
        belly[(x, 1, 0)] = 9  # dark belt
    belly[(0, 0, 0)] = 10  # left dagger
    belly[(0, 1, 0)] = 10
    belly[(0, 2, 0)] = 10
    belly[(10, 0, 0)] = 10  # right dagger
    belly[(10, 1, 0)] = 10
    belly[(10, 2, 0)] = 10

    # Hood on head
    head = parts["head"]
    head_w = 10
    head_d = 8
    head_h = 16
    for x in range(head_w):
        for z in range(head_d):
            for y in range(head_h // 2, head_h):
                if (x, y, z) in head:
                    head[(x, y, z)] = 7  # dark green hood
    for x in range(2, head_w - 2):
        for z in range(2, head_d - 2):
            head[(x, head_h, z)] = 7
    for x in range(3, head_w - 3):
        for z in range(3, head_d - 3):
            head[(x, head_h + 1, z)] = 7
    for x in range(1, head_w - 1):
        for y in range(0, head_h // 2):
            head[(x, y, 0)] = 0  # skin_color
    eye_y = head_h // 2 - 1
    face_left = head_w // 2 - 2
    face_right = head_w // 2 + 1
    head[(face_left, eye_y, 0)] = 26
    head[(face_left + 1, eye_y, 0)] = 27
    head[(face_right - 1, eye_y, 0)] = 27
    head[(face_right, eye_y, 0)] = 26
    mid_x = head_w // 2
    head[(mid_x - 1, eye_y - 1, 0)] = 39
    head[(mid_x, eye_y - 1, 0)] = 39
    head[(mid_x - 1, eye_y - 3, 0)] = 47
    head[(mid_x, eye_y - 3, 0)] = 47

    # Gloved hands (dark leather)
    for side in ("left_hand", "right_hand"):
        hand = parts[side]
        for pos in list(hand.keys()):
            hand[pos] = 42

    # Dark boots
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for pos in list(foot.keys()):
            foot[pos] = 9

    for part in (hip, belly, chest):
        add_edge_shading(part, 48)
    return parts, assembly


# === Sukuna-quality NPC builders ===

def make_merchant_sukuna():
    """Merchant Sukuna-quality: brown leather, apron, wider build."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=8, torso_dark=9, leg_color=9,
        arm_color=8, hair_color=17,
        torso_width=15, body_depth=9,
    )
    chest = parts["chest"]   # 15w x 9h
    belly = parts["belly"]   # 14w x 5h
    hip = parts["hip"]       # 13w x 5h

    # Front apron across torso (darker brown)
    for y in range(2, 5):
        for x in range(4, 9):
            hip[(x, y, 0)] = 9
    for y in range(5):
        for x in range(5, 10):
            belly[(x, y, 0)] = 9
    for y in range(0, 6):
        for x in range(5, 10):
            chest[(x, y, 0)] = 9

    # Gold belt pouch on hip
    hip[(9, 4, 0)] = 16
    hip[(10, 4, 0)] = 16
    hip[(9, 3, 0)] = 16
    hip[(10, 3, 0)] = 16

    for part in (hip, belly, chest):
        add_edge_shading(part, 48)
    return parts, assembly


def make_blacksmith_sukuna():
    """Blacksmith Sukuna-quality: grey metal, muscular, dark leather apron."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=10, torso_dark=11, leg_color=9,
        arm_color=8, hair_color=19,
        torso_width=16, body_depth=9,
    )
    chest = parts["chest"]   # 16w x 9h
    belly = parts["belly"]   # 15w x 5h
    hip = parts["hip"]       # 14w x 5h

    # Apron (grey-dark) on front across torso
    for y in range(2, 5):
        for x in range(4, 10):
            hip[(x, y, 0)] = 11
    for y in range(5):
        for x in range(5, 11):
            belly[(x, y, 0)] = 11
    for y in range(0, 5):
        for x in range(5, 11):
            chest[(x, y, 0)] = 11

    # Exposed muscular arms (skin tone upper portion of upper arm)
    for side in ("left_arm", "right_arm"):
        arm = parts[side]
        for y in range(2, 8):
            for x in range(4):
                for z in range(4):
                    arm[(x, y, z)] = 0  # skin_light (exposed bicep)

    for part in (hip, belly, chest):
        add_edge_shading(part, 48)
    return parts, assembly


def make_doctor_sukuna():
    """Doctor Sukuna-quality: white cloth, red cross on chest."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=14, torso_dark=51, leg_color=14,
        arm_color=14, hair_color=17,
        torso_width=12, body_depth=7,
    )
    chest = parts["chest"]   # 12w x 9h

    # Red cross on chest front (centered)
    mid_x = 6
    cross_y = 4
    for dy in range(-3, 4):
        y = cross_y + dy
        if 0 <= y < 7:
            chest[(mid_x, y, 0)] = 15
            chest[(mid_x - 1, y, 0)] = 15
    for dx in range(-3, 4):
        x = mid_x + dx
        if 0 <= x < 12:
            chest[(x, cross_y, 0)] = 15
            chest[(x, cross_y - 1, 0)] = 15

    for part in (parts["hip"], parts["belly"], chest):
        add_edge_shading(part, 48)
    return parts, assembly


def make_weaver_sukuna():
    """Weaver Sukuna-quality: teal robes, hooded, mystical."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=12, torso_dark=13, leg_color=13,
        arm_color=12, hair_color=19,
        torso_width=12, body_depth=7,
    )
    chest = parts["chest"]   # 12w x 9h
    belly = parts["belly"]   # 11w x 5h
    hip = parts["hip"]       # 10w x 5h

    # Robe covers legs (teal dark)
    for side in ("left_thigh", "right_thigh", "left_leg", "right_leg"):
        leg_part = parts[side]
        for pos in list(leg_part.keys()):
            leg_part[pos] = 13

    # Hood on head (similar to Vex but teal)
    head = parts["head"]
    head_w = 10
    head_d = 8
    head_h = 16
    for x in range(head_w):
        for z in range(head_d):
            for y in range(head_h // 2, head_h):
                if (x, y, z) in head:
                    head[(x, y, z)] = 13
    for x in range(2, head_w - 2):
        for z in range(2, head_d - 2):
            head[(x, head_h, z)] = 13
    for x in range(1, head_w - 1):
        for y in range(0, head_h // 2):
            head[(x, y, 0)] = 0
    eye_y = head_h // 2 - 1
    face_left = head_w // 2 - 2
    face_right = head_w // 2 + 1
    head[(face_left, eye_y, 0)] = 26
    head[(face_left + 1, eye_y, 0)] = 27
    head[(face_right - 1, eye_y, 0)] = 27
    head[(face_right, eye_y, 0)] = 26
    mid_x = head_w // 2
    head[(mid_x - 1, eye_y - 1, 0)] = 39
    head[(mid_x, eye_y - 1, 0)] = 39
    head[(mid_x - 1, eye_y - 3, 0)] = 47
    head[(mid_x, eye_y - 3, 0)] = 47

    # Mystical gold accents on torso
    for x in range(11):
        belly[(x, 1, 0)] = 16
    for x in range(12):
        chest[(x, 0, 0)] = 16
        chest[(x, 4, 0)] = 16

    for part in (hip, belly, chest):
        add_edge_shading(part, 48)
    return parts, assembly


# === Sukuna-quality enemy builders ===

def make_goblin_sukuna():
    """Goblin Sukuna-quality: small green humanoid, big head, pointy ears."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=22, torso_dark=23, leg_color=23,
        arm_color=22, hair_color=23, skin_color=22,
        torso_width=10, body_depth=6,
        height_scale=0.7,
    )
    # Override head to be proportionally bigger (goblin trait)
    head = parts["head"]
    head_w = 9  # wider than normal for this scale
    head_d = 7
    head_h = 14  # taller than proportional
    head.clear()
    filled_box(head, 0, 0, 0, head_w - 1, head_h - 1, head_d - 1, 22)
    # Cut corners
    for cy in range(head_h):
        for cx, cz in [(0, 0), (0, head_d - 1), (head_w - 1, 0), (head_w - 1, head_d - 1)]:
            if (cx, cy, cz) in head:
                del head[(cx, cy, cz)]
    # Pointy ears (extending beyond head width)
    ear_y = head_h // 2
    for dy in range(-1, 3):
        head[(-1, ear_y + dy, head_d // 2)] = 22  # left ear
        head[(head_w, ear_y + dy, head_d // 2)] = 22  # right ear
    head[(-2, ear_y + 2, head_d // 2)] = 22  # ear tips
    head[(head_w + 1, ear_y + 2, head_d // 2)] = 22
    # Big yellow eyes
    eye_y = head_h // 2
    head[(2, eye_y, 0)] = 26  # left white
    head[(3, eye_y, 0)] = 27  # left pupil
    head[(5, eye_y, 0)] = 27  # right pupil
    head[(6, eye_y, 0)] = 26  # right white
    # Big nose
    head[(4, eye_y - 1, 0)] = 23
    head[(4, eye_y - 2, 0)] = 23
    # Wide mouth
    for x in range(2, 7):
        head[(x, eye_y - 3, 0)] = 47

    return parts, assembly


def make_minotaur_sukuna():
    """Minotaur Sukuna-quality: large brown, horns, muscular."""
    parts, assembly = sukuna_humanoid_parts(
        torso_color=24, torso_dark=25, leg_color=25,
        arm_color=24, hair_color=19, skin_color=24,
        torso_width=18, body_depth=10,
        height_scale=1.4,
    )
    # Horns on head
    head = parts["head"]
    head_h = max(k[1] for k in head.keys()) + 1
    head_w = max(k[0] for k in head.keys()) + 1
    head_d_max = max(k[2] for k in head.keys()) + 1
    mid_z = head_d_max // 2
    # Large curved horns
    for dy in range(6):
        # Left horn curving outward
        head[(-1, head_h + dy, mid_z)] = 38  # horn_beige
        head[(-2, head_h + dy, mid_z)] = 38
        # Right horn curving outward
        head[(head_w, head_h + dy, mid_z)] = 38
        head[(head_w + 1, head_h + dy, mid_z)] = 38
    # Horn tips curve outward more
    head[(-3, head_h + 4, mid_z)] = 38
    head[(-3, head_h + 5, mid_z)] = 38
    head[(head_w + 2, head_h + 4, mid_z)] = 38
    head[(head_w + 2, head_h + 5, mid_z)] = 38

    # Snout/muzzle (front of face, protruding)
    eye_y = head_h // 2 - 1
    mid_x = head_w // 2
    for x in range(mid_x - 2, mid_x + 2):
        for y in range(eye_y - 3, eye_y):
            head[(x, y, -1)] = 24  # snout protrudes forward
            head[(x, y, 0)] = 24
    # Nostrils
    head[(mid_x - 1, eye_y - 2, -1)] = 25
    head[(mid_x, eye_y - 2, -1)] = 25
    # Red eyes
    face_left = mid_x - 2
    face_right = mid_x + 1
    head[(face_left, eye_y, 0)] = 15  # red
    head[(face_right, eye_y, 0)] = 15

    # Hooves on feet (darker)
    for side in ("left_foot", "right_foot"):
        foot = parts[side]
        for pos in list(foot.keys()):
            foot[pos] = 25  # dark brown hooves

    for part in (parts["hip"], parts["belly"], parts["chest"]):
        add_edge_shading(part, 48)
    return parts, assembly


# === Multi-part .vox writer ===

def write_multipart_vox(base_dir, parts, assembly, palette):
    """Write separate .vox files for each body part + parts.json metadata."""
    os.makedirs(base_dir, exist_ok=True)

    for part_name, voxels in parts.items():
        if not voxels:
            continue
        path = os.path.join(base_dir, f"{part_name}.vox")
        write_vox(path, voxels, palette)

    # Write assembly metadata
    meta_path = os.path.join(base_dir, "parts.json")
    with open(meta_path, 'w') as f:
        json.dump(assembly, f, indent=2)
    print(f"  META {meta_path}")


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
    # --- Monolithic models (backward compat) ---
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
        print(f"\n=== {category.upper()} (monolithic) ===")
        for name, builder in items.items():
            path = os.path.join(BASE_DIR, category, f"{name}.vox")
            voxels = builder()
            write_vox(path, voxels, PALETTE)
            total += 1

    # --- Multi-part articulated models (Sukuna-quality for all) ---
    multipart = {
        "characters": {
            "warrior": make_kael_sukuna,
            "mage": make_lyra_sukuna,
            "rogue": make_vex_sukuna,
        },
        "enemies": {
            "goblin": make_goblin_sukuna,
            "minotaur": make_minotaur_sukuna,
        },
        "npcs": {
            "merchant": make_merchant_sukuna,
            "blacksmith": make_blacksmith_sukuna,
            "weaver": make_weaver_sukuna,
            "doctor": make_doctor_sukuna,
        },
    }

    mp_count = 0
    for category, items in multipart.items():
        print(f"\n=== {category.upper()} (multi-part) ===")
        for name, builder in items.items():
            base_dir = os.path.join(BASE_DIR, category, name)
            parts, assembly = builder()
            write_multipart_vox(base_dir, parts, assembly, PALETTE)
            mp_count += 1

    print(f"\nDone! Generated {total} monolithic + {mp_count} multi-part models.")


if __name__ == "__main__":
    main()
