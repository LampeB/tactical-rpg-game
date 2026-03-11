#!/usr/bin/env python3
"""Generate jewelry .tres files (rings and necklaces) at all rarity tiers.

Creates 8 ring types (1x1) + 4 necklace types (1x2) x 6 rarities = 72 files.

Usage:
    python tools/generate_jewelry.py           # dry run (count only)
    python tools/generate_jewelry.py --apply   # write files
    python tools/generate_jewelry.py --apply --force  # overwrite existing
"""

import os
import random
import string
import sys

JEWELRY_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "items", "jewelry")

# --- Stat enum values (from enums.gd) ---
STAT_MAX_HP = 0
STAT_MAX_MP = 1
STAT_SPEED = 2
STAT_LUCK = 3
STAT_PHYS_ATK = 4
STAT_PHYS_DEF = 5
STAT_MAG_ATK = 6
STAT_MAG_DEF = 7
STAT_CRIT_RATE = 8
STAT_CRIT_DMG = 9

# --- Jewelry slot enum values (EquipmentCategory) ---
SLOT_NECKLACE = 12
SLOT_RING = 13

# --- Rarity definitions (same multipliers as weapons/armor) ---
RARITIES = [
    {"name": "common",    "enum_val": 0, "power_mult": 1.0,  "price_mult": 1.0},
    {"name": "uncommon",  "enum_val": 1, "power_mult": 1.4,  "price_mult": 1.56},
    {"name": "rare",      "enum_val": 2, "power_mult": 1.8,  "price_mult": 2.04},
    {"name": "elite",     "enum_val": 3, "power_mult": 2.2,  "price_mult": 2.64},
    {"name": "legendary", "enum_val": 4, "power_mult": 3.0,  "price_mult": 3.60},
    {"name": "unique",    "enum_val": 5, "power_mult": 4.0,  "price_mult": 4.80},
]

# --- Shape paths ---
SHAPES = {
    "1x1": "res://data/shapes/shape_1x1.tres",
    "1x2": "res://data/shapes/shape_1x2.tres",
}

# --- Icon paths ---
# All rarities use the same base icon; rarity is shown via cell tint
RING_ICONS = {
    0: "res://assets/sprites/items/ring_common.png",
    1: "res://assets/sprites/items/ring_common.png",
    2: "res://assets/sprites/items/ring_common.png",
    3: "res://assets/sprites/items/ring_common.png",
    4: "res://assets/sprites/items/ring_common.png",
    5: "res://assets/sprites/items/ring_common.png",
}

NECKLACE_ICON = "res://assets/sprites/items/ring_common.png"  # placeholder until necklace art exists

# --- Jewelry type definitions ---
JEWELRY_TYPES = [
    # === RINGS (slot=13, shape=1x1) ===
    {
        "id": "ruby_ring", "name": "Ruby Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_PHYS_ATK, 8)],
        "description": "A blood-red ruby set in gold. Its wearer strikes with savage force.",
        "base_price": 80,
    },
    {
        "id": "sapphire_ring", "name": "Sapphire Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_MAG_ATK, 8)],
        "description": "A deep blue sapphire that hums with arcane resonance. Amplifies spellcraft.",
        "base_price": 80,
    },
    {
        "id": "emerald_ring", "name": "Emerald Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_MAX_HP, 25)],
        "description": "A verdant emerald pulsing with vitality. The wearer feels invigorated.",
        "base_price": 80,
    },
    {
        "id": "diamond_ring", "name": "Diamond Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_CRIT_RATE, 5)],
        "description": "A flawless diamond that catches every glint of light. Sharpens the killer instinct.",
        "base_price": 80,
    },
    {
        "id": "opal_ring", "name": "Opal Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_SPEED, 5)],
        "description": "An iridescent opal shifting with inner fire. Quickens reflexes and footwork.",
        "base_price": 80,
    },
    {
        "id": "amethyst_ring", "name": "Amethyst Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_MAX_MP, 15)],
        "description": "A violet amethyst steeped in mana. Deepens the wearer's magical reserves.",
        "base_price": 80,
    },
    {
        "id": "onyx_ring", "name": "Onyx Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_PHYS_DEF, 6)],
        "description": "A jet-black onyx that absorbs impact. Hardens the skin against blows.",
        "base_price": 80,
    },
    {
        "id": "topaz_ring", "name": "Topaz Ring",
        "slot": SLOT_RING, "shape": "1x1",
        "stats": [(STAT_LUCK, 5)],
        "description": "A golden topaz that bends fortune. Lucky finds and narrow escapes follow its wearer.",
        "base_price": 80,
    },

    # === NECKLACES (slot=12, shape=1x2) ===
    {
        "id": "amber_pendant", "name": "Amber Pendant",
        "slot": SLOT_NECKLACE, "shape": "1x2",
        "stats": [(STAT_PHYS_ATK, 6), (STAT_MAG_ATK, 6)],
        "description": "Ancient amber encasing a trapped spark. Empowers both blade and spell alike.",
        "base_price": 150,
    },
    {
        "id": "crystal_amulet", "name": "Crystal Amulet",
        "slot": SLOT_NECKLACE, "shape": "1x2",
        "stats": [(STAT_MAX_HP, 20), (STAT_MAX_MP, 10)],
        "description": "A prismatic crystal amulet that bolsters body and mind in equal measure.",
        "base_price": 150,
    },
    {
        "id": "silver_chain", "name": "Silver Chain",
        "slot": SLOT_NECKLACE, "shape": "1x2",
        "stats": [(STAT_SPEED, 4), (STAT_LUCK, 4)],
        "description": "A delicate silver chain that jingles faintly. Its wearer moves with uncanny grace.",
        "base_price": 150,
    },
    {
        "id": "gold_medallion", "name": "Gold Medallion",
        "slot": SLOT_NECKLACE, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 5), (STAT_MAX_HP, 15)],
        "description": "A heavy gold medallion engraved with wards. A bulwark against harm.",
        "base_price": 150,
    },
]


def random_id(length: int = 5) -> str:
    """Generate a random alphanumeric ID for Godot resource references."""
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


def generate_tres(jewelry: dict, rarity: dict) -> str:
    """Generate the content of a .tres file for a jewelry piece at a given rarity."""
    r = rarity
    j = jewelry
    mult = r["power_mult"]

    price = max(1, round(j["base_price"] * r["price_mult"]))
    scaled_stats = []
    for s, v in j["stats"]:
        if v > 0:
            scaled_stats.append((s, max(1, round(v * mult))))
        elif v < 0:
            scaled_stats.append((s, round(v * mult)))

    item_id = f"{j['id']}_{r['name']}"
    slot = j["slot"]

    # Build ext_resource entries
    ext_resources = []
    ext_id_counter = [1]

    def add_ext(res_type: str, path: str) -> str:
        eid = f"{ext_id_counter[0]}_{random_id()}"
        ext_id_counter[0] += 1
        ext_resources.append((res_type, path, eid))
        return eid

    # Required scripts
    eid_item_data = add_ext("Script", "res://scripts/resources/item_data.gd")
    eid_stat_mod = add_ext("Script", "res://scripts/resources/stat_modifier.gd")

    # Shape
    shape_path = SHAPES[j["shape"]]
    eid_shape = add_ext("Resource", shape_path)

    # Icon
    if slot == SLOT_RING:
        icon_path = RING_ICONS[r["enum_val"]]
    else:
        icon_path = NECKLACE_ICON
    eid_icon = add_ext("Texture2D", icon_path)

    # Build ext_resource section
    ext_lines = []
    for res_type, path, eid in ext_resources:
        ext_lines.append(f'[ext_resource type="{res_type}" path="{path}" id="{eid}"]')

    # Build sub_resource section (stat modifiers)
    sub_lines = []
    sub_ids = []
    for stat, value in scaled_stats:
        sid = f"Resource_{random_id()}"
        sub_ids.append(sid)
        sub_lines.append(f'[sub_resource type="Resource" id="{sid}"]')
        sub_lines.append(f'script = ExtResource("{eid_stat_mod}")')
        sub_lines.append(f"stat = {stat}")
        sub_lines.append(f"value = {float(value)}")
        sub_lines.append("")

    # Build [resource] section
    res_lines = []
    res_lines.append("[resource]")
    res_lines.append(f'script = ExtResource("{eid_item_data}")')
    res_lines.append(f'id = "{item_id}"')
    res_lines.append(f'display_name = "{j["name"]}"')
    res_lines.append(f'description = "{j["description"]}"')
    res_lines.append(f'icon = ExtResource("{eid_icon}")')
    res_lines.append("item_type = 1")  # PASSIVE_GEAR
    res_lines.append(f"category = {slot}")

    if r["enum_val"] != 0:
        res_lines.append(f"rarity = {r['enum_val']}")

    res_lines.append(f"armor_slot = {slot}")
    res_lines.append(f'shape = ExtResource("{eid_shape}")')

    # Stat modifiers
    sub_refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
    res_lines.append(f'stat_modifiers = Array[ExtResource("{eid_stat_mod}")]([{sub_refs}])')

    res_lines.append(f"base_price = {price}")

    # Assemble full file
    lines = ['[gd_resource type="Resource" script_class="ItemData" format=3]', ""]
    lines.extend(ext_lines)
    lines.append("")
    lines.extend(sub_lines)
    lines.extend(res_lines)
    lines.append("")

    return "\n".join(lines)


def main():
    apply = "--apply" in sys.argv
    force = "--force" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    if force:
        mode += " (FORCE OVERWRITE)"
    print(f"=== {mode} ===\n")

    os.makedirs(JEWELRY_DIR, exist_ok=True)

    total = 0
    skipped = 0

    for jewelry in JEWELRY_TYPES:
        for rarity in RARITIES:
            item_id = f"{jewelry['id']}_{rarity['name']}"
            filename = f"{item_id}.tres"
            filepath = os.path.join(JEWELRY_DIR, filename)

            if os.path.exists(filepath) and not force:
                print(f"  SKIP (exists): {filename}")
                skipped += 1
                continue

            if apply:
                content = generate_tres(jewelry, rarity)
                with open(filepath, "w", encoding="utf-8", newline="\n") as f:
                    f.write(content)
                print(f"  Created: {filename}")

            total += 1

    print(f"\n{'Created' if apply else 'Would create'}: {total} files")
    if skipped:
        print(f"Skipped (already exist): {skipped}")

    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
