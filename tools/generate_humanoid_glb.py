#!/usr/bin/env python3
"""Generate a low-poly humanoid character model in GLB format.

Produces ~16 separate meshes with transform-based animations.
Compatible with Godot 4's native GLB import.

Usage: python tools/generate_humanoid_glb.py
Output: assets/models/characters/humanoid_test.glb
"""

import struct
import math
import os
from pygltflib import (
    GLTF2, Asset, Scene, Node, Mesh, Primitive, Attributes,
    Accessor, BufferView, Buffer, Material, PbrMetallicRoughness,
    Animation, AnimationChannel, AnimationSampler, AnimationChannelTarget,
)

# glTF constants
ELEMENT_ARRAY_BUFFER = 34963
ARRAY_BUFFER = 34962
UNSIGNED_SHORT = 5123
FLOAT = 5126

# ──────────────────────────────────────────────
#  Configuration
# ──────────────────────────────────────────────
OUTPUT_DIR = "assets/models/characters"
OUTPUT_FILE = "humanoid_test.glb"

# Material colors (R, G, B, A)
PALETTE = {
    "skin":    (0.87, 0.72, 0.53, 1.0),
    "shirt":   (0.20, 0.35, 0.60, 1.0),
    "pants":   (0.30, 0.25, 0.18, 1.0),
    "boots":   (0.35, 0.22, 0.12, 1.0),
    "belt":    (0.45, 0.32, 0.15, 1.0),
    "hair":    (0.18, 0.12, 0.06, 1.0),
    "gloves":  (0.50, 0.35, 0.20, 1.0),
}

# Body parts: (name, parent_index, translation, mesh_size, mesh_offset, color_key, subdivisions)
# parent_index: -1 = scene root
# translation: joint position relative to parent
# mesh_size: (w, h, d) of the box
# mesh_offset: center of box geometry relative to joint
# subdivisions: grid density per face (more = smoother)
BODY_PARTS = [
    #  idx  name              parent   translation             mesh_size             mesh_offset           color     subdiv
    # 0: Hips — skeleton root
    ("Hips",          -1, ( 0.00,  0.82,  0.00), (0.36, 0.14, 0.22), ( 0.00,  0.00,  0.00), "belt",   3),
    # 1: Torso
    ("Torso",          0, ( 0.00,  0.08,  0.00), (0.42, 0.42, 0.26), ( 0.00,  0.21,  0.00), "shirt",  4),
    # 2: Neck
    ("Neck",           1, ( 0.00,  0.42,  0.00), (0.10, 0.08, 0.10), ( 0.00,  0.04,  0.00), "skin",   2),
    # 3: Head
    ("Head",           2, ( 0.00,  0.08,  0.00), (0.28, 0.30, 0.28), ( 0.00,  0.15,  0.00), "hair",   4),
    # 4: Left Arm (shoulder joint)
    ("LeftArm",        1, (-0.26,  0.38,  0.00), (0.12, 0.24, 0.14), ( 0.00, -0.12,  0.00), "shirt",  3),
    # 5: Left Forearm
    ("LeftForearm",    4, ( 0.00, -0.24,  0.00), (0.10, 0.22, 0.12), ( 0.00, -0.11,  0.00), "skin",   3),
    # 6: Left Hand
    ("LeftHand",       5, ( 0.00, -0.22,  0.00), (0.08, 0.10, 0.06), ( 0.00, -0.05,  0.00), "gloves", 2),
    # 7: Right Arm (shoulder joint)
    ("RightArm",       1, ( 0.26,  0.38,  0.00), (0.12, 0.24, 0.14), ( 0.00, -0.12,  0.00), "shirt",  3),
    # 8: Right Forearm
    ("RightForearm",   7, ( 0.00, -0.24,  0.00), (0.10, 0.22, 0.12), ( 0.00, -0.11,  0.00), "skin",   3),
    # 9: Right Hand
    ("RightHand",      8, ( 0.00, -0.22,  0.00), (0.08, 0.10, 0.06), ( 0.00, -0.05,  0.00), "gloves", 2),
    # 10: Left Leg (hip joint)
    ("LeftLeg",        0, (-0.10, -0.06,  0.00), (0.15, 0.32, 0.16), ( 0.00, -0.16,  0.00), "pants",  4),
    # 11: Left Shin
    ("LeftShin",      10, ( 0.00, -0.32,  0.00), (0.12, 0.34, 0.14), ( 0.00, -0.17,  0.00), "pants",  3),
    # 12: Left Foot
    ("LeftFoot",      11, ( 0.00, -0.34,  0.04), (0.13, 0.08, 0.24), ( 0.00, -0.04,  0.04), "boots",  2),
    # 13: Right Leg (hip joint)
    ("RightLeg",       0, ( 0.10, -0.06,  0.00), (0.15, 0.32, 0.16), ( 0.00, -0.16,  0.00), "pants",  4),
    # 14: Right Shin
    ("RightShin",     13, ( 0.00, -0.32,  0.00), (0.12, 0.34, 0.14), ( 0.00, -0.17,  0.00), "pants",  3),
    # 15: Right Foot
    ("RightFoot",     14, ( 0.00, -0.34,  0.04), (0.13, 0.08, 0.24), ( 0.00, -0.04,  0.04), "boots",  2),
]


# ──────────────────────────────────────────────
#  Geometry helpers
# ──────────────────────────────────────────────

def make_box(w, h, d, offset=(0, 0, 0), subdivisions=1):
    """Create a subdivided box mesh.

    subdivisions=1: regular 12-triangle box
    subdivisions=N: N×N grid per face (12*N² triangles total)
    """
    hw, hh, hd = w / 2, h / 2, d / 2
    ox, oy, oz = offset

    positions = []
    normals = []
    indices = []
    n = subdivisions

    # Six faces: (normal, origin corner, u_axis, v_axis, u_extent, v_extent)
    faces = [
        (( 0,  0,  1), (-hw, -hh,  hd), ( 1, 0, 0), (0,  1, 0), w, h),  # Front
        (( 0,  0, -1), ( hw, -hh, -hd), (-1, 0, 0), (0,  1, 0), w, h),  # Back
        (( 0,  1,  0), (-hw,  hh, -hd), ( 1, 0, 0), (0,  0, 1), w, d),  # Top
        (( 0, -1,  0), (-hw, -hh,  hd), ( 1, 0, 0), (0,  0,-1), w, d),  # Bottom
        (( 1,  0,  0), ( hw, -hh, -hd), ( 0, 0, 1), (0,  1, 0), d, h),  # Right
        ((-1,  0,  0), (-hw, -hh,  hd), ( 0, 0,-1), (0,  1, 0), d, h),  # Left
    ]

    for normal, origin, u_ax, v_ax, u_ext, v_ext in faces:
        base = len(positions)
        for j in range(n + 1):
            for i in range(n + 1):
                u = i / n
                v = j / n
                x = origin[0] + u_ax[0] * u * u_ext + v_ax[0] * v * v_ext + ox
                y = origin[1] + u_ax[1] * u * u_ext + v_ax[1] * v * v_ext + oy
                z = origin[2] + u_ax[2] * u * u_ext + v_ax[2] * v * v_ext + oz
                positions.append((x, y, z))
                normals.append(normal)
        for j in range(n):
            for i in range(n):
                a = base + j * (n + 1) + i
                b = a + 1
                c = a + (n + 1)
                dd = c + 1
                indices.extend([a, b, dd, a, dd, c])

    return positions, normals, indices


# ──────────────────────────────────────────────
#  Quaternion math
# ──────────────────────────────────────────────

def quat_id():
    """Identity quaternion (x, y, z, w)."""
    return (0.0, 0.0, 0.0, 1.0)


def quat_axis(axis, angle):
    """Axis-angle → quaternion (x, y, z, w)."""
    s = math.sin(angle / 2)
    c = math.cos(angle / 2)
    return (axis[0] * s, axis[1] * s, axis[2] * s, c)


def quat_mul(q1, q2):
    """Multiply two quaternions."""
    x1, y1, z1, w1 = q1
    x2, y2, z2, w2 = q2
    return (
        w1*x2 + x1*w2 + y1*z2 - z1*y2,
        w1*y2 - x1*z2 + y1*w2 + z1*x2,
        w1*z2 + x1*y2 - y1*x2 + z1*w2,
        w1*w2 - x1*x2 - y1*y2 - z1*z2,
    )


X = (1, 0, 0)
Y = (0, 1, 0)
Z = (0, 0, 1)

# Base hips Y position (used in animations)
HIPS_Y = 0.82


# ──────────────────────────────────────────────
#  Animation definitions
# ──────────────────────────────────────────────

def _hips_pos(dy=0.0, dz=0.0, dx=0.0):
    """Helper: hips translation with offsets from base."""
    return (dx, HIPS_Y + dy, dz)


def define_animations():
    """Return list of (name, tracks) where each track is (part_name, property, keyframes).

    property: "rotation" | "translation" | "scale"
    keyframes: [(time, value), ...] — quaternion for rotation, vec3 for others
    """
    anims = []

    # ── IDLE (2s loop) ──
    t = []
    bob = 0.015
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.5, _hips_pos(bob)), (1.0, _hips_pos()),
        (1.5, _hips_pos(bob)), (2.0, _hips_pos()),
    ]))
    t.append(("Torso", "rotation", [
        (0.0, quat_axis(Z, 0)), (1.0, quat_axis(Z, 0.02)), (2.0, quat_axis(Z, 0)),
    ]))
    t.append(("Head", "rotation", [
        (0.0, quat_axis(Y, 0)), (1.0, quat_axis(Y, 0.04)), (2.0, quat_axis(Y, 0)),
    ]))
    for arm, s in [("LeftArm", 1), ("RightArm", -1)]:
        t.append((arm, "rotation", [
            (0.0, quat_axis(Z, s*0.05)), (1.0, quat_axis(Z, s*0.08)),
            (2.0, quat_axis(Z, s*0.05)),
        ]))
    anims.append(("idle", t))

    # ── WALK (1s loop) ──
    t = []
    ls, arm_s = 0.5, 0.35
    # Body bob
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.125, _hips_pos(0.02)), (0.25, _hips_pos()),
        (0.375, _hips_pos(0.02)), (0.5, _hips_pos()), (0.625, _hips_pos(0.02)),
        (0.75, _hips_pos()), (0.875, _hips_pos(0.02)), (1.0, _hips_pos()),
    ]))
    # Legs
    for leg, sign in [("LeftLeg", 1), ("RightLeg", -1)]:
        t.append((leg, "rotation", [
            (0.0, quat_axis(X, sign*ls)), (0.25, quat_axis(X, 0)),
            (0.5, quat_axis(X, -sign*ls)), (0.75, quat_axis(X, 0)),
            (1.0, quat_axis(X, sign*ls)),
        ]))
    # Knees
    kb = 0.4
    t.append(("LeftShin", "rotation", [
        (0.0, quat_axis(X, 0)), (0.25, quat_axis(X, kb)),
        (0.5, quat_axis(X, 0)), (0.75, quat_axis(X, kb*0.3)),
        (1.0, quat_axis(X, 0)),
    ]))
    t.append(("RightShin", "rotation", [
        (0.0, quat_axis(X, 0)), (0.25, quat_axis(X, kb*0.3)),
        (0.5, quat_axis(X, 0)), (0.75, quat_axis(X, kb)),
        (1.0, quat_axis(X, 0)),
    ]))
    # Feet
    ft = 0.25
    for foot, sign in [("LeftFoot", 1), ("RightFoot", -1)]:
        t.append((foot, "rotation", [
            (0.0, quat_axis(X, -sign*ft)), (0.25, quat_axis(X, 0)),
            (0.5, quat_axis(X, sign*ft)), (0.75, quat_axis(X, 0)),
            (1.0, quat_axis(X, -sign*ft)),
        ]))
    # Arms (opposite legs)
    for arm, sign in [("LeftArm", -1), ("RightArm", 1)]:
        t.append((arm, "rotation", [
            (0.0, quat_axis(X, sign*arm_s)), (0.25, quat_axis(X, 0)),
            (0.5, quat_axis(X, -sign*arm_s)), (0.75, quat_axis(X, 0)),
            (1.0, quat_axis(X, sign*arm_s)),
        ]))
    # Elbows
    eb = 0.3
    t.append(("LeftForearm", "rotation", [
        (0.0, quat_axis(X, -eb)), (0.25, quat_axis(X, -eb*0.5)),
        (0.5, quat_axis(X, 0)), (0.75, quat_axis(X, -eb*0.5)),
        (1.0, quat_axis(X, -eb)),
    ]))
    t.append(("RightForearm", "rotation", [
        (0.0, quat_axis(X, 0)), (0.25, quat_axis(X, -eb*0.5)),
        (0.5, quat_axis(X, -eb)), (0.75, quat_axis(X, -eb*0.5)),
        (1.0, quat_axis(X, 0)),
    ]))
    # Torso counter-rotation
    tw = 0.06
    t.append(("Torso", "rotation", [
        (0.0, quat_axis(Y, tw)), (0.25, quat_axis(Y, 0)),
        (0.5, quat_axis(Y, -tw)), (0.75, quat_axis(Y, 0)),
        (1.0, quat_axis(Y, tw)),
    ]))
    anims.append(("walk", t))

    # ── RUN (0.6s loop) ──
    t = []
    rl, ra, rk = 0.7, 0.5, 0.6
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.075, _hips_pos(0.04)), (0.15, _hips_pos()),
        (0.225, _hips_pos(-0.01)), (0.3, _hips_pos()), (0.375, _hips_pos(0.04)),
        (0.45, _hips_pos()), (0.525, _hips_pos(-0.01)), (0.6, _hips_pos()),
    ]))
    for leg, sign in [("LeftLeg", 1), ("RightLeg", -1)]:
        t.append((leg, "rotation", [
            (0.0, quat_axis(X, sign*rl)), (0.15, quat_axis(X, 0)),
            (0.3, quat_axis(X, -sign*rl*0.7)), (0.45, quat_axis(X, 0)),
            (0.6, quat_axis(X, sign*rl)),
        ]))
    for shin, phase in [("LeftShin", 0), ("RightShin", 1)]:
        hi, lo = rk, rk*0.3
        if phase:
            hi, lo = lo, hi
        t.append((shin, "rotation", [
            (0.0, quat_axis(X, 0)), (0.15, quat_axis(X, hi)),
            (0.3, quat_axis(X, 0)), (0.45, quat_axis(X, lo)),
            (0.6, quat_axis(X, 0)),
        ]))
    for arm, sign in [("LeftArm", -1), ("RightArm", 1)]:
        t.append((arm, "rotation", [
            (0.0, quat_axis(X, sign*ra)), (0.15, quat_axis(X, 0)),
            (0.3, quat_axis(X, -sign*ra)), (0.45, quat_axis(X, 0)),
            (0.6, quat_axis(X, sign*ra)),
        ]))
    for fa, phase in [("LeftForearm", 0.5), ("RightForearm", 0.3)]:
        t.append((fa, "rotation", [
            (0.0, quat_axis(X, -rk*phase)), (0.15, quat_axis(X, -rk*0.7)),
            (0.3, quat_axis(X, -rk*(1-phase))), (0.45, quat_axis(X, -rk*0.7)),
            (0.6, quat_axis(X, -rk*phase)),
        ]))
    t.append(("Torso", "rotation", [
        (0.0, quat_axis(X, 0.12)), (0.3, quat_axis(X, 0.12)), (0.6, quat_axis(X, 0.12)),
    ]))
    anims.append(("run", t))

    # ── ATTACK SLASH (0.8s) ──
    t = []
    t.append(("RightArm", "rotation", [
        (0.0, quat_id()), (0.2, quat_axis(X, -1.2)),
        (0.35, quat_axis(X, 0.8)), (0.5, quat_axis(X, 0.4)),
        (0.8, quat_id()),
    ]))
    t.append(("RightForearm", "rotation", [
        (0.0, quat_id()), (0.2, quat_axis(X, -0.4)),
        (0.35, quat_axis(X, -0.2)), (0.8, quat_id()),
    ]))
    t.append(("RightHand", "rotation", [
        (0.0, quat_id()), (0.2, quat_axis(X, -0.3)),
        (0.35, quat_axis(X, 0.4)), (0.8, quat_id()),
    ]))
    t.append(("Torso", "rotation", [
        (0.0, quat_id()), (0.2, quat_axis(Y, 0.3)),
        (0.35, quat_axis(Y, -0.25)), (0.8, quat_id()),
    ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.2, _hips_pos(0, -0.05)),
        (0.35, _hips_pos(0, 0.1)), (0.8, _hips_pos()),
    ]))
    anims.append(("attack_slash", t))

    # ── ATTACK THRUST (0.6s) ──
    t = []
    t.append(("RightArm", "rotation", [
        (0.0, quat_id()), (0.15, quat_axis(X, -0.5)),
        (0.3, quat_axis(X, 1.2)), (0.6, quat_id()),
    ]))
    t.append(("RightForearm", "rotation", [
        (0.0, quat_id()), (0.15, quat_axis(X, -0.8)),
        (0.3, quat_axis(X, 0)), (0.6, quat_id()),
    ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.15, _hips_pos(0, -0.08)),
        (0.3, _hips_pos(0, 0.15)), (0.6, _hips_pos()),
    ]))
    t.append(("Torso", "rotation", [
        (0.0, quat_id()), (0.3, quat_axis(X, 0.15)), (0.6, quat_id()),
    ]))
    anims.append(("attack_thrust", t))

    # ── ATTACK BASH (0.9s) ──
    t = []
    for arm in ["LeftArm", "RightArm"]:
        t.append((arm, "rotation", [
            (0.0, quat_id()), (0.3, quat_axis(X, -1.5)),
            (0.5, quat_axis(X, 0.9)), (0.9, quat_id()),
        ]))
    for fa in ["LeftForearm", "RightForearm"]:
        t.append((fa, "rotation", [
            (0.0, quat_id()), (0.3, quat_axis(X, -0.5)),
            (0.5, quat_axis(X, -0.2)), (0.9, quat_id()),
        ]))
    for h in ["LeftHand", "RightHand"]:
        t.append((h, "rotation", [
            (0.0, quat_id()), (0.3, quat_axis(X, -0.3)),
            (0.5, quat_axis(X, 0.3)), (0.9, quat_id()),
        ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.3, _hips_pos(0.03)),
        (0.5, _hips_pos(-0.04)), (0.9, _hips_pos()),
    ]))
    anims.append(("attack_bash", t))

    # ── CAST SPELL (1.2s) ──
    t = []
    t.append(("LeftArm", "rotation", [
        (0.0, quat_id()),
        (0.3, quat_mul(quat_axis(X, -0.8), quat_axis(Z, 0.3))),
        (0.8, quat_mul(quat_axis(X, -0.6), quat_axis(Z, 0.5))),
        (1.0, quat_axis(X, -1.0)), (1.2, quat_id()),
    ]))
    t.append(("RightArm", "rotation", [
        (0.0, quat_id()),
        (0.3, quat_mul(quat_axis(X, -0.8), quat_axis(Z, -0.3))),
        (0.8, quat_mul(quat_axis(X, -0.6), quat_axis(Z, -0.5))),
        (1.0, quat_axis(X, -1.0)), (1.2, quat_id()),
    ]))
    for fa in ["LeftForearm", "RightForearm"]:
        t.append((fa, "rotation", [
            (0.0, quat_id()), (0.3, quat_axis(X, -0.6)),
            (0.8, quat_axis(X, -0.4)), (1.0, quat_axis(X, -0.3)),
            (1.2, quat_id()),
        ]))
    for h in ["LeftHand", "RightHand"]:
        t.append((h, "rotation", [
            (0.0, quat_id()), (0.3, quat_axis(X, -0.4)),
            (0.8, quat_axis(X, -0.4)), (1.0, quat_axis(X, 0.3)),
            (1.2, quat_id()),
        ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.3, _hips_pos(0.02)),
        (0.8, _hips_pos(0.03)), (1.0, _hips_pos()), (1.2, _hips_pos()),
    ]))
    anims.append(("cast_spell", t))

    # ── HIT REACT (0.5s) ──
    t = []
    t.append(("Torso", "rotation", [
        (0.0, quat_id()), (0.1, quat_axis(X, -0.3)),
        (0.3, quat_axis(X, -0.15)), (0.5, quat_id()),
    ]))
    t.append(("Head", "rotation", [
        (0.0, quat_id()), (0.1, quat_axis(X, -0.2)), (0.5, quat_id()),
    ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.1, _hips_pos(-0.02, -0.06)),
        (0.3, _hips_pos(-0.01, -0.02)), (0.5, _hips_pos()),
    ]))
    anims.append(("hit_react", t))

    # ── DEATH (1.5s) ──
    t = []
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.3, _hips_pos(-0.07, -0.05)),
        (0.6, _hips_pos(-0.32, -0.10)), (1.0, _hips_pos(-0.62, -0.15)),
        (1.5, _hips_pos(-0.72, -0.15)),
    ]))
    t.append(("Hips", "rotation", [
        (0.0, quat_id()), (0.3, quat_axis(X, -0.2)),
        (0.6, quat_axis(X, -0.6)), (1.0, quat_axis(X, -1.3)),
        (1.5, quat_axis(X, -1.5)),
    ]))
    t.append(("Head", "rotation", [
        (0.0, quat_id()), (0.6, quat_axis(X, -0.3)), (1.5, quat_axis(X, 0.4)),
    ]))
    for arm, s in [("LeftArm", 1), ("RightArm", -1)]:
        t.append((arm, "rotation", [
            (0.0, quat_id()), (0.6, quat_axis(Z, s*0.5)), (1.5, quat_axis(Z, s*0.8)),
        ]))
    for leg, s in [("LeftLeg", 1), ("RightLeg", -1)]:
        t.append((leg, "rotation", [
            (0.0, quat_id()), (1.0, quat_axis(Z, s*0.3)), (1.5, quat_axis(Z, s*0.4)),
        ]))
    anims.append(("death", t))

    # ── VICTORY (2s) ──
    t = []
    for arm in ["LeftArm", "RightArm"]:
        t.append((arm, "rotation", [
            (0.0, quat_id()), (0.4, quat_axis(X, -2.0)),
            (1.5, quat_axis(X, -2.0)), (2.0, quat_id()),
        ]))
    for fa in ["LeftForearm", "RightForearm"]:
        t.append((fa, "rotation", [
            (0.0, quat_id()), (0.4, quat_axis(X, -0.3)),
            (1.5, quat_axis(X, -0.3)), (2.0, quat_id()),
        ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.4, _hips_pos(0.03)),
        (0.7, _hips_pos()), (1.0, _hips_pos(0.05)),
        (1.2, _hips_pos()), (2.0, _hips_pos()),
    ]))
    anims.append(("victory", t))

    # ── BLOCK (0.5s) ──
    t = []
    t.append(("LeftArm", "rotation", [
        (0.0, quat_id()),
        (0.15, quat_mul(quat_axis(X, -0.8), quat_axis(Z, 0.4))),
        (0.4, quat_mul(quat_axis(X, -0.8), quat_axis(Z, 0.4))),
        (0.5, quat_id()),
    ]))
    t.append(("LeftForearm", "rotation", [
        (0.0, quat_id()), (0.15, quat_axis(X, -1.0)),
        (0.4, quat_axis(X, -1.0)), (0.5, quat_id()),
    ]))
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.15, _hips_pos(-0.04)),
        (0.4, _hips_pos(-0.04)), (0.5, _hips_pos()),
    ]))
    for leg in ["LeftLeg", "RightLeg"]:
        t.append((leg, "rotation", [
            (0.0, quat_id()), (0.15, quat_axis(X, 0.15)),
            (0.4, quat_axis(X, 0.15)), (0.5, quat_id()),
        ]))
    anims.append(("block", t))

    # ── DODGE (0.5s) ──
    t = []
    t.append(("Hips", "translation", [
        (0.0, _hips_pos()), (0.15, _hips_pos(-0.04)),
        (0.25, _hips_pos(-0.04, 0, 0.3)), (0.4, _hips_pos(0, 0, 0.1)),
        (0.5, _hips_pos()),
    ]))
    t.append(("Torso", "rotation", [
        (0.0, quat_id()), (0.15, quat_axis(Z, -0.3)),
        (0.25, quat_axis(Z, -0.2)), (0.5, quat_id()),
    ]))
    anims.append(("dodge", t))

    return anims


# ──────────────────────────────────────────────
#  GLB builder
# ──────────────────────────────────────────────

class GLBBuilder:
    """Assembles a GLTF2 object with meshes, materials, and animations."""

    def __init__(self):
        self.gltf = GLTF2()
        self.gltf.asset = Asset(version="2.0", generator="tactical-rpg-humanoid-gen")
        self.gltf.scene = 0
        self.gltf.scenes = [Scene(nodes=[0])]
        self.gltf.nodes = []
        self.gltf.meshes = []
        self.gltf.materials = []
        self.gltf.accessors = []
        self.gltf.bufferViews = []
        self.gltf.buffers = [Buffer(byteLength=0)]
        self.gltf.animations = []

        self._bin = bytearray()
        self._mat_cache = {}
        self._name_to_node = {}

    def build(self):
        self._create_materials()
        self._create_body()
        self._create_animations()
        self.gltf.buffers[0].byteLength = len(self._bin)
        self.gltf.set_binary_blob(bytes(self._bin))
        return self.gltf

    # ── Materials ──

    def _create_materials(self):
        for key, rgba in PALETTE.items():
            mat = Material(
                name=key,
                pbrMetallicRoughness=PbrMetallicRoughness(
                    baseColorFactor=list(rgba),
                    metallicFactor=0.1,
                    roughnessFactor=0.8,
                ),
            )
            self._mat_cache[key] = len(self.gltf.materials)
            self.gltf.materials.append(mat)

    # ── Binary helpers ──

    def _add_bv(self, data, target=None):
        """Append data to binary blob, create BufferView, return its index."""
        # 4-byte alignment
        pad = (4 - len(self._bin) % 4) % 4
        self._bin.extend(b'\x00' * pad)

        offset = len(self._bin)
        self._bin.extend(data)

        bv = BufferView(buffer=0, byteOffset=offset, byteLength=len(data))
        if target:
            bv.target = target
        idx = len(self.gltf.bufferViews)
        self.gltf.bufferViews.append(bv)
        return idx

    def _add_acc(self, bv, comp_type, count, acc_type, mins=None, maxs=None):
        """Create an Accessor, return its index."""
        acc = Accessor(
            bufferView=bv, componentType=comp_type,
            count=count, type=acc_type,
        )
        if mins is not None:
            acc.min = mins
        if maxs is not None:
            acc.max = maxs
        idx = len(self.gltf.accessors)
        self.gltf.accessors.append(acc)
        return idx

    # ── Mesh creation ──

    def _make_mesh(self, size, offset, mat_idx, subdivisions=1):
        """Build a box mesh, add to gltf, return mesh index."""
        positions, norms, indices = make_box(
            size[0], size[1], size[2], offset, subdivisions
        )

        # Pack positions
        pos_bytes = bytearray()
        mn = [1e9, 1e9, 1e9]
        mx = [-1e9, -1e9, -1e9]
        for p in positions:
            pos_bytes.extend(struct.pack('<fff', *p))
            for i in range(3):
                mn[i] = min(mn[i], p[i])
                mx[i] = max(mx[i], p[i])

        # Pack normals
        norm_bytes = bytearray()
        for n in norms:
            norm_bytes.extend(struct.pack('<fff', *n))

        # Pack indices
        idx_bytes = bytearray()
        for ii in indices:
            idx_bytes.extend(struct.pack('<H', ii))

        pos_bv = self._add_bv(bytes(pos_bytes), ARRAY_BUFFER)
        norm_bv = self._add_bv(bytes(norm_bytes), ARRAY_BUFFER)
        idx_bv = self._add_bv(bytes(idx_bytes), ELEMENT_ARRAY_BUFFER)

        pos_acc = self._add_acc(pos_bv, FLOAT, len(positions), "VEC3", mn, mx)
        norm_acc = self._add_acc(norm_bv, FLOAT, len(norms), "VEC3")
        idx_acc = self._add_acc(
            idx_bv, UNSIGNED_SHORT, len(indices), "SCALAR",
            [min(indices)], [max(indices)]
        )

        mesh_idx = len(self.gltf.meshes)
        self.gltf.meshes.append(Mesh(
            name=f"mesh_{mesh_idx}",
            primitives=[Primitive(
                attributes=Attributes(POSITION=pos_acc, NORMAL=norm_acc),
                indices=idx_acc,
                material=mat_idx,
            )],
        ))
        return mesh_idx

    # ── Body hierarchy ──

    def _create_body(self):
        # Root node (no mesh, just a container)
        root = Node(name="Root", children=[])
        self.gltf.nodes.append(root)
        self._name_to_node["Root"] = 0

        for i, (name, parent_idx, trans, size, offset, color, subdiv) in enumerate(BODY_PARTS):
            node_idx = len(self.gltf.nodes)
            self._name_to_node[name] = node_idx

            mesh_idx = self._make_mesh(size, offset, self._mat_cache[color], subdiv)
            node = Node(name=name, mesh=mesh_idx, translation=list(trans), children=[])
            self.gltf.nodes.append(node)

            if parent_idx == -1:
                root.children.append(node_idx)
            else:
                # +1 because Root is node 0, BODY_PARTS[0] is node 1
                self.gltf.nodes[parent_idx + 1].children.append(node_idx)

    # ── Animations ──

    def _create_animations(self):
        for anim_name, tracks in define_animations():
            channels = []
            samplers = []

            for part_name, prop, keyframes in tracks:
                node_idx = self._name_to_node.get(part_name)
                if node_idx is None:
                    print(f"  WARNING: unknown part '{part_name}' in anim '{anim_name}'")
                    continue

                times = [kf[0] for kf in keyframes]
                values = [kf[1] for kf in keyframes]

                # Time accessor
                t_data = struct.pack(f'<{len(times)}f', *times)
                t_bv = self._add_bv(t_data)
                t_acc = self._add_acc(
                    t_bv, FLOAT, len(times), "SCALAR",
                    [min(times)], [max(times)]
                )

                # Value accessor
                if prop == "rotation":
                    v_data = bytearray()
                    for q in values:
                        v_data.extend(struct.pack('<ffff', *q))
                    v_bv = self._add_bv(bytes(v_data))
                    v_acc = self._add_acc(v_bv, FLOAT, len(values), "VEC4")
                else:  # translation or scale
                    v_data = bytearray()
                    for v in values:
                        v_data.extend(struct.pack('<fff', *v))
                    v_bv = self._add_bv(bytes(v_data))
                    v_acc = self._add_acc(v_bv, FLOAT, len(values), "VEC3")

                sampler_idx = len(samplers)
                samplers.append(AnimationSampler(
                    input=t_acc, output=v_acc, interpolation="LINEAR",
                ))
                channels.append(AnimationChannel(
                    sampler=sampler_idx,
                    target=AnimationChannelTarget(node=node_idx, path=prop),
                ))

            if channels:
                self.gltf.animations.append(Animation(
                    name=anim_name, channels=channels, samplers=samplers,
                ))


# ──────────────────────────────────────────────
#  Main
# ──────────────────────────────────────────────

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output_path = os.path.join(OUTPUT_DIR, OUTPUT_FILE)

    print("Generating humanoid GLB model...")
    builder = GLBBuilder()
    gltf = builder.build()

    # Stats
    total_tris = 0
    total_verts = 0
    for mesh in gltf.meshes:
        for prim in mesh.primitives:
            if prim.indices is not None:
                total_tris += gltf.accessors[prim.indices].count // 3
            if prim.attributes.POSITION is not None:
                total_verts += gltf.accessors[prim.attributes.POSITION].count

    total_tracks = sum(len(a.channels) for a in gltf.animations)

    print(f"  Meshes:     {len(gltf.meshes)}")
    print(f"  Triangles:  {total_tris}")
    print(f"  Vertices:   {total_verts}")
    print(f"  Materials:  {len(gltf.materials)}")
    print(f"  Animations: {len(gltf.animations)}")
    print(f"  Anim tracks:{total_tracks}")

    gltf.save(output_path)
    file_size = os.path.getsize(output_path)
    print(f"\n  Output: {output_path}")
    print(f"  Size:   {file_size / 1024:.1f} KB")
    print("  Done!")


if __name__ == "__main__":
    main()
