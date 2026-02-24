#!/usr/bin/env python3
"""
Generate all 18 backpack tier .tres files with custom non-rectangular shapes.
Each shape is defined as a multiline grid string:
  '#' = initial cell (active from tier start)
  '+' = expansion cell (purchasable by the player)
  anything else = VOID (not rendered at all)

Run from the project root:  python tools/generate_backpack_tiers.py
"""

import os

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "backpack_tiers")
SCRIPT_PATH = "res://scripts/resources/backpack_tier_config.gd"


def parse_shape(grid_lines: list[str]) -> tuple[list, list, int, int]:
    """Parse a grid into (initial_cells, expansion_cells, width, height)."""
    initial = []
    expansion = []
    height = len(grid_lines)
    width = max(len(row) for row in grid_lines) if grid_lines else 0
    for y, row in enumerate(grid_lines):
        for x, ch in enumerate(row):
            if ch == '#':
                initial.append((x, y))
            elif ch == '+':
                expansion.append((x, y))
    return initial, expansion, width, height


def vec2i_array(cells: list) -> str:
    """Format a list of (x, y) tuples as a GDScript typed Array[Vector2i]."""
    if not cells:
        return "Array[Vector2i]([])"
    parts = ", ".join(f"Vector2i({x}, {y})" for x, y in cells)
    return f"Array[Vector2i]([{parts}])"


def int_array(values: list[int]) -> str:
    if not values:
        return "Array[int]([])"
    return "Array[int]([" + ", ".join(str(v) for v in values) + "])"


def make_costs(expansion_cells: list, base_cost: int, premium_cost: int, premium_start: int) -> list[int]:
    """
    Build a cost list for expansion cells.
    First (len - premium_start) cells cost base_cost, remaining cost premium_cost.
    premium_start counts from the END (i.e. last N cells are premium).
    """
    n = len(expansion_cells)
    costs = []
    for i in range(n):
        if i < n - premium_start:
            costs.append(base_cost)
        else:
            costs.append(premium_cost)
    return costs


def write_tres(filename: str, tier_index: int, display_name: str,
               bounding_w: int, bounding_h: int,
               initial_cells: list, expansion_cells: list,
               cell_costs: list[int],
               unlock_gold: int, unlock_runes: int):
    all_cells = initial_cells + expansion_cells
    initial_count = len(initial_cells)

    content = f"""[gd_resource type="Resource" script_class="BackpackTierConfig" format=3]

[ext_resource type="Script" path="{SCRIPT_PATH}" id="1"]

[resource]
script = ExtResource("1")
tier_index = {tier_index}
display_name = "{display_name}"
bounding_width = {bounding_w}
bounding_height = {bounding_h}
initial_cell_count = {initial_count}
cell_costs = {int_array(cell_costs)}
unlock_gold_cost = {unlock_gold}
unlock_rune_count = {unlock_runes}
growth_direction = 0
custom_cell_layout = {vec2i_array(all_cells)}
"""
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="\n") as f:
        f.write(content)
    exp_count = len(expansion_cells)
    total = len(all_cells)
    void_count = bounding_w * bounding_h - total
    print(f"  {filename}: init={initial_count}, exp={exp_count}, total={total}, void={void_count}")


# ─────────────────────────────────────────────────────────────────────────────
# WARRIOR — Hiking backpack silhouette
# Top lid (narrower), main body (full width), expansion row, two hip-strap tabs.
# T1–T5: template-generated.  T6: hand-crafted unique shape.
# ─────────────────────────────────────────────────────────────────────────────

def warrior_shape_standard(W: int, H: int) -> tuple[list, list]:
    """
    Standard warrior template:
      row 0        : cols 1..W-2  (top lid, initial)
      rows 1..H-3  : all W cols  (main body, initial)
      row H-2      : all W cols  (expansion)
      row H-1      : col 0 and col W-1 only  (hip-strap tabs, expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y == 0:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
                # else VOID (top corners)
            elif y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                expansion.append((x, y))
            else:  # y == H-1
                if x == 0 or x == W - 1:
                    expansion.append((x, y))
                # else VOID (middle bottom gap between hip tabs)
    return initial, expansion


def warrior_t6_shape(W: int, H: int) -> tuple[list, list]:
    """
    Warrior T6 special shape — large alpine pack with wide hip frame:
      row 0        : cols 2..W-3  (narrow top lid)
      row 1        : cols 1..W-2  (slightly wider)
      rows 2..H-3  : all W  (full body)
      row H-2      : cols 1..W-2  (expansion, slightly inset)
      row H-1      : cols 0,1,W-2,W-1  (wide hip frame, expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y == 0:
                if 2 <= x <= W - 3:
                    initial.append((x, y))
            elif y == 1:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
            elif y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                if 1 <= x <= W - 2:
                    expansion.append((x, y))
            else:  # H-1
                if x in (0, 1, W - 2, W - 1):
                    expansion.append((x, y))
    return initial, expansion


WARRIOR_TIERS = [
    # (filename, tier_idx, display_name, W, H, base_cost, premium_cost, premium_count, unlock_g, unlock_r)
    ("warrior_tier1.tres", 0, "Worn Satchel",       6,  8,   20,   30,  2,     0, 0),
    ("warrior_tier2.tres", 1, "Traveler's Pack",    6, 10,   60,  100,  2,   500, 1),
    ("warrior_tier3.tres", 2, "Adventurer's Pack",  6, 12,  100,  150,  2,  1500, 2),
    ("warrior_tier4.tres", 3, "Veteran's Haversack",8, 12,  150,  200,  2,  4000, 3),
    ("warrior_tier5.tres", 4, "Champion's Haversack",10,12,  200,  300,  2, 10000, 4),
    ("warrior_tier6.tres", 5, "Warlord's Stronghold",12,12, 400,  600,  4, 25000, 5),
]

print("=== WARRIOR ===")
for fname, tidx, dname, W, H, bc, pc, prem, ug, ur in WARRIOR_TIERS:
    if tidx == 5:
        init, exp = warrior_t6_shape(W, H)
    else:
        init, exp = warrior_shape_standard(W, H)
    costs = make_costs(exp, bc, pc, prem)
    write_tres(fname, tidx, dname, W, H, init, exp, costs, ug, ur)


# ─────────────────────────────────────────────────────────────────────────────
# MAGE — Alchemist's pouch (oval/tapered shape)
# Narrow mouth at top, wide oval body, tapered bottom.
# T1–T5: template.  T6: concentric-ring arcane vault.
# ─────────────────────────────────────────────────────────────────────────────

def mage_shape_standard(W: int, H: int) -> tuple[list, list]:
    """
    Standard mage template (oval pouch):
      row 0        : cols 1..W-2  (narrow mouth, initial)
      rows 1..H-3  : all W        (body, initial)
      row H-2      : all W        (expansion)
      row H-1      : cols 1..W-2  (tapered bottom, expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y == 0:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
            elif y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                expansion.append((x, y))
            else:  # H-1
                if 1 <= x <= W - 2:
                    expansion.append((x, y))
    return initial, expansion


def mage_t6_shape(W: int, H: int) -> tuple[list, list]:
    """
    Mage T6 — Grand Arcanum Vault: concentric diamond pattern.
      Successive rows expand then contract from the center.
      Last 2 rows are expansion (mirror of first 2 rows).
    W=11, H=11:
      row 0  : cols 3..7   (5 init)
      row 1  : cols 2..8   (7 init)
      row 2  : cols 1..9   (9 init)
      rows 3..7: all 11    (5 rows, init)
      row 8  : cols 1..9   (9 init)   ← last init row
      row 9  : cols 2..8   (7 exp)
      row 10 : cols 3..7   (5 exp)
    """
    initial, expansion = [], []
    rings = [
        (3, W - 4),  # row 0 / row H-1
        (2, W - 3),  # row 1 / row H-2
        (1, W - 2),  # row 2 / row H-3
    ]
    ring_count = len(rings)
    for y in range(H):
        if y < ring_count:
            lo, hi = rings[y]
            for x in range(lo, hi + 1):
                initial.append((x, y))
        elif y >= H - ring_count:
            idx = H - 1 - y           # 0 for last row, 1 for second-to-last, etc.
            lo, hi = rings[idx]
            for x in range(lo, hi + 1):
                expansion.append((x, y))
        else:
            for x in range(W):
                initial.append((x, y))
    return initial, expansion


MAGE_TIERS = [
    ("mage_tier1.tres", 0, "Spell Pouch",       5,  7,   15,   25,  3,     0, 0),
    ("mage_tier2.tres", 1, "Arcane Satchel",    5,  9,   45,   70,  3,   500, 1),
    ("mage_tier3.tres", 2, "Mystic Satchel",    5, 11,   75,  110,  3,  1500, 2),
    ("mage_tier4.tres", 3, "Enchanted Pack",    7, 11,  110,  160,  5,  4000, 3),
    ("mage_tier5.tres", 4, "Sorcerer's Pack",   9, 11,  150,  220,  7, 10000, 4),
    ("mage_tier6.tres", 5, "Grand Arcanum Vault",11,11, 350,  500, 12, 25000, 5),
]

print("=== MAGE ===")
for fname, tidx, dname, W, H, bc, pc, prem, ug, ur in MAGE_TIERS:
    if tidx == 5:
        init, exp = mage_t6_shape(W, H)
    else:
        init, exp = mage_shape_standard(W, H)
    costs = make_costs(exp, bc, pc, prem)
    write_tres(fname, tidx, dname, W, H, init, exp, costs, ug, ur)


# ─────────────────────────────────────────────────────────────────────────────
# ROGUE — Utility satchel (horizontal, wider than tall for early tiers)
# T1–T3: rectangular with rounded-bottom expansion.
# T4–T5: wider, with cut top corners.
# T6: unique layout with separated pocket area.
# ─────────────────────────────────────────────────────────────────────────────

def rogue_shape_early(W: int, H: int) -> tuple[list, list]:
    """
    Rogue early template (T1-T3, 7-wide):
      rows 0..H-3  : all W  (initial — full rectangular body)
      row H-2      : all W  (expansion)
      row H-1      : cols 1..W-2  (rounded-bottom expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                expansion.append((x, y))
            else:  # H-1
                if 1 <= x <= W - 2:
                    expansion.append((x, y))
    return initial, expansion


def rogue_shape_wide(W: int, H: int) -> tuple[list, list]:
    """
    Rogue wide template (T4-T5):
      row 0        : cols 1..W-2  (cut top corners, initial)
      rows 1..H-3  : all W        (body, initial)
      row H-2      : all W        (expansion)
      row H-1      : cols 1..W-2  (rounded bottom, expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y == 0:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
            elif y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                expansion.append((x, y))
            else:  # H-1
                if 1 <= x <= W - 2:
                    expansion.append((x, y))
    return initial, expansion


def rogue_t6_shape(W: int, H: int) -> tuple[list, list]:
    """
    Rogue T6 — Shadowmaster's Cache (W=12, H=10):
    Main compartment with a separate bottom pocket strip.
      row 0        : cols 1..W-2  (cut top corners, initial)
      rows 1..H-4  : all W        (body, initial)
      row H-3      : all W        (body, initial)
      row H-2      : cols 1..W-2  (initial, slight inset)  ← last init row
      row H-1      : cols 1..W-2  (expansion)
    """
    initial, expansion = [], []
    for y in range(H):
        for x in range(W):
            if y == 0:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
            elif y <= H - 3:
                initial.append((x, y))
            elif y == H - 2:
                if 1 <= x <= W - 2:
                    initial.append((x, y))
            else:  # H-1
                if 1 <= x <= W - 2:
                    expansion.append((x, y))
    return initial, expansion


ROGUE_TIERS = [
    ("rogue_tier1.tres", 0, "Thief's Pouch",        7,  6,   18,   28,  5,     0, 0),
    ("rogue_tier2.tres", 1, "Scout's Pack",          7,  8,   50,   80,  5,   500, 1),
    ("rogue_tier3.tres", 2, "Shadow Pack",           7, 10,   80,  120,  5,  1500, 2),
    ("rogue_tier4.tres", 3, "Nightblade Satchel",    9, 10,  120,  180,  7,  4000, 3),
    ("rogue_tier5.tres", 4, "Assassin's Satchel",   11, 10,  180,  270,  9, 10000, 4),
    ("rogue_tier6.tres", 5, "Shadowmaster's Cache", 12, 10,  350,  500, 10, 25000, 5),
]

print("=== ROGUE ===")
for fname, tidx, dname, W, H, bc, pc, prem, ug, ur in ROGUE_TIERS:
    if tidx <= 2:
        init, exp = rogue_shape_early(W, H)
    elif tidx <= 4:
        init, exp = rogue_shape_wide(W, H)
    else:
        init, exp = rogue_t6_shape(W, H)
    costs = make_costs(exp, bc, pc, prem)
    write_tres(fname, tidx, dname, W, H, init, exp, costs, ug, ur)

print("\nDone! All 18 tier configs written.")
