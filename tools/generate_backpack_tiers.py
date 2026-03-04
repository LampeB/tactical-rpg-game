#!/usr/bin/env python3
"""
Generate all 30 backpack tier .tres files (3 characters x 10 tiers).

Each character uses a simple rectangular shape on a 25x25 master grid.
Tiers are auto-assigned via BFS from center: inner cells = early tiers,
outer cells = later tiers. Edit the SHAPE, CENTER, and AUTO_UNLOCK
constants to customize.

Symbols in the matrix:
    x  = void
    0  = auto-unlocked at start (free)
    1  = purchasable at Tier 1
    2..9 = appears at Tiers 2-9
    a  = appears at Tier 10

Run from the project root:  python tools/generate_backpack_tiers.py
"""

import os
import glob
from collections import deque

OUTPUT_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "backpack_tiers")
SCRIPT_PATH = "res://scripts/resources/backpack_tier_config.gd"

SYMBOL_TO_TIER = {
    '0': 0, '1': 0,
    '2': 1, '3': 2, '4': 3, '5': 4, '6': 5,
    '7': 6, '8': 7, '9': 8, 'a': 9,
}
TIER_TO_SYMBOL = {0: '1', 1: '2', 2: '3', 3: '4', 4: '5', 5: '6', 6: '7', 7: '8', 8: '9', 9: 'a'}


def vec2i_array(cells: list) -> str:
    if not cells:
        return "Array[Vector2i]([])"
    parts = ", ".join(f"Vector2i({x}, {y})" for x, y in cells)
    return f"Array[Vector2i]([{parts}])"


def int_array(values: list[int]) -> str:
    if not values:
        return "Array[int]([])"
    return "Array[int]([" + ", ".join(str(v) for v in values) + "])"


def make_costs(count: int, base_cost: int, premium_cost: int, premium_count: int) -> list[int]:
    costs = []
    for i in range(count):
        if i < count - premium_count:
            costs.append(base_cost)
        else:
            costs.append(premium_cost)
    return costs


def bfs_assign(width: int, height: int, auto_unlock: int, tier0_purchasable: int) -> list[list[str]]:
    """
    Create a WxH rectangle and assign tiers via BFS from center.
    Returns a 2D list of symbols.
    """
    all_cells = set()
    for y in range(height):
        for x in range(width):
            all_cells.add((x, y))

    # BFS from center
    cx, cy = width // 2, height // 2
    center = (cx, cy)
    dist = {center: 0}
    queue = deque([center])
    while queue:
        cell = queue.popleft()
        for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nb = (cell[0] + dx, cell[1] + dy)
            if nb in all_cells and nb not in dist:
                dist[nb] = dist[cell] + 1
                queue.append(nb)

    # Sort by distance, then by y, then by x for deterministic order
    sorted_cells = sorted(dist.keys(), key=lambda c: (dist[c], c[1], c[0]))

    total = len(sorted_cells)
    remaining = total - auto_unlock - tier0_purchasable
    tiers_for_remaining = 9  # tiers 1-9 (symbols 2-a)

    assignment = {}
    for i, cell in enumerate(sorted_cells):
        if i < auto_unlock:
            assignment[cell] = '0'
        elif i < auto_unlock + tier0_purchasable:
            assignment[cell] = '1'
        else:
            idx = i - auto_unlock - tier0_purchasable
            tier = min(int(idx * tiers_for_remaining / remaining), tiers_for_remaining - 1)
            assignment[cell] = TIER_TO_SYMBOL[tier + 1]  # +1 because tier 0 is done

    # Build matrix
    matrix = []
    for y in range(height):
        row = []
        for x in range(width):
            row.append(assignment.get((x, y), 'x'))
        matrix.append(row)
    return matrix


def print_matrix(name: str, matrix: list[list[str]]):
    print(f"\n  {name} matrix ({len(matrix[0])}x{len(matrix)}):")
    for row in matrix:
        print("  " + " ".join(row))


def extract_tiers(matrix: list[list[str]]) -> dict:
    """Extract cells per tier from the matrix."""
    tiers = {}
    for y, row in enumerate(matrix):
        for x, sym in enumerate(row):
            if sym == 'x':
                continue
            tier_idx = SYMBOL_TO_TIER.get(sym)
            if tier_idx is None:
                continue
            if tier_idx not in tiers:
                tiers[tier_idx] = {"auto_unlock": [], "purchasable": []}
            if sym == '0':
                tiers[tier_idx]["auto_unlock"].append((x, y))
            else:
                tiers[tier_idx]["purchasable"].append((x, y))
    return tiers


def write_tres(filename: str, tier_index: int, display_name: str,
               new_cells: list, auto_unlock_count: int,
               cell_costs: list[int],
               unlock_gold: int, unlock_runes: int):
    content = f"""[gd_resource type="Resource" script_class="BackpackTierConfig" format=3]

[ext_resource type="Script" path="{SCRIPT_PATH}" id="1"]

[resource]
script = ExtResource("1")
tier_index = {tier_index}
display_name = "{display_name}"
new_cells = {vec2i_array(new_cells)}
auto_unlock_count = {auto_unlock_count}
cell_costs = {int_array(cell_costs)}
unlock_gold_cost = {unlock_gold}
unlock_rune_count = {unlock_runes}
"""
    path = os.path.join(OUTPUT_DIR, filename)
    with open(path, "w", newline="\n") as f:
        f.write(content)
    purchasable = len(new_cells) - auto_unlock_count
    print(f"  {filename}: new={len(new_cells)}, auto={auto_unlock_count}, buy={purchasable}")


# ─────────────────────────────────────────────────────────────────────────────
# SHAPE DEFINITIONS — same simple rectangle for all characters
# ─────────────────────────────────────────────────────────────────────────────

SHAPE_WIDTH = 11
SHAPE_HEIGHT = 11
AUTO_UNLOCK = 20
TIER0_PURCHASABLE = 10

# ─────────────────────────────────────────────────────────────────────────────
# TIER CONFIG TABLES
# ─────────────────────────────────────────────────────────────────────────────

WARRIOR_CONFIG = [
    (0, "warrior_tier1.tres",  "Worn Satchel",            15,   25,  2,      0, 0),
    (1, "warrior_tier2.tres",  "Traveler's Pack",          25,   40,  2,    200, 1),
    (2, "warrior_tier3.tres",  "Adventurer's Pack",        40,   65,  2,    500, 2),
    (3, "warrior_tier4.tres",  "Explorer's Pack",          55,   85,  2,   1000, 3),
    (4, "warrior_tier5.tres",  "Pathfinder's Pack",        75,  115,  2,   2000, 4),
    (5, "warrior_tier6.tres",  "Veteran's Haversack",     100,  150,  3,   4000, 5),
    (6, "warrior_tier7.tres",  "Champion's Pack",         140,  210,  3,   7000, 6),
    (7, "warrior_tier8.tres",  "Commander's Haversack",   180,  270,  3,  12000, 7),
    (8, "warrior_tier9.tres",  "Hero's Stronghold",       230,  350,  3,  20000, 8),
    (9, "warrior_tier10.tres", "Warlord's Stronghold",    350,  550,  4,  35000, 9),
]

MAGE_CONFIG = [
    (0, "mage_tier1.tres",  "Spell Pouch",            15,   25,  2,      0, 0),
    (1, "mage_tier2.tres",  "Arcane Satchel",          25,   40,  2,    200, 1),
    (2, "mage_tier3.tres",  "Mystic Satchel",          40,   65,  2,    500, 2),
    (3, "mage_tier4.tres",  "Enchanted Pack",          55,   85,  2,   1000, 3),
    (4, "mage_tier5.tres",  "Sorcerer's Pack",         75,  115,  2,   2000, 4),
    (5, "mage_tier6.tres",  "Wizard's Pack",          100,  150,  3,   4000, 5),
    (6, "mage_tier7.tres",  "Arch-Mage's Satchel",   140,  210,  3,   7000, 6),
    (7, "mage_tier8.tres",  "Warlock's Vault",        180,  270,  3,  12000, 7),
    (8, "mage_tier9.tres",  "Arcanum Vault",          230,  350,  3,  20000, 8),
    (9, "mage_tier10.tres", "Grand Arcanum Vault",    350,  550,  4,  35000, 9),
]

ROGUE_CONFIG = [
    (0, "rogue_tier1.tres",  "Thief's Pouch",          15,   25,  2,      0, 0),
    (1, "rogue_tier2.tres",  "Pickpocket's Satchel",    25,   40,  2,    200, 1),
    (2, "rogue_tier3.tres",  "Scout's Pack",            40,   65,  2,    500, 2),
    (3, "rogue_tier4.tres",  "Shadow Pack",             55,   85,  2,   1000, 3),
    (4, "rogue_tier5.tres",  "Burglar's Pack",          75,  115,  2,   2000, 4),
    (5, "rogue_tier6.tres",  "Nightblade Satchel",     100,  150,  3,   4000, 5),
    (6, "rogue_tier7.tres",  "Stalker's Pack",         140,  210,  3,   7000, 6),
    (7, "rogue_tier8.tres",  "Assassin's Satchel",     180,  270,  3,  12000, 7),
    (8, "rogue_tier9.tres",  "Phantom's Cache",        230,  350,  3,  20000, 8),
    (9, "rogue_tier10.tres", "Shadowmaster's Cache",   350,  550,  4,  35000, 9),
]


def generate_character(name: str, config_table: list):
    print(f"\n=== {name.upper()} ===")
    matrix = bfs_assign(SHAPE_WIDTH, SHAPE_HEIGHT, AUTO_UNLOCK, TIER0_PURCHASABLE)
    print_matrix(name, matrix)
    tiers = extract_tiers(matrix)

    total = 0
    for t_idx in sorted(tiers.keys()):
        data = tiers[t_idx]
        n = len(data["auto_unlock"]) + len(data["purchasable"])
        total += n
    print(f"  Total cells: {total}")

    for tier_idx, filename, display_name, base_cost, premium_cost, premium_count, unlock_gold, unlock_runes in config_table:
        data = tiers.get(tier_idx, {"auto_unlock": [], "purchasable": []})
        new_cells = data["auto_unlock"] + data["purchasable"]
        auto_unlock_count = len(data["auto_unlock"])
        purchasable_count = len(data["purchasable"])
        cell_costs = make_costs(purchasable_count, base_cost, premium_cost, premium_count)
        write_tres(filename, tier_idx, display_name,
                   new_cells, auto_unlock_count, cell_costs,
                   unlock_gold, unlock_runes)


if __name__ == "__main__":
    old_files = glob.glob(os.path.join(OUTPUT_DIR, "*.tres"))
    for f in old_files:
        os.remove(f)
    if old_files:
        print(f"Removed {len(old_files)} old files.")

    generate_character("Warrior", WARRIOR_CONFIG)
    generate_character("Mage", MAGE_CONFIG)
    generate_character("Rogue", ROGUE_CONFIG)

    print("\nDone! All 30 tier configs written.")
