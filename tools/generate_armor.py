#!/usr/bin/env python3
"""Generate armor .tres files for all armor subtypes at applicable rarity tiers.

Creates 4 weight classes x 5 slots = 20 armor types, each across applicable rarities.
Some heavier armor starts at higher minimum rarities (Uncommon or Rare).

Usage:
    python tools/generate_armor.py           # dry run (count only)
    python tools/generate_armor.py --apply   # write files
    python tools/generate_armor.py --apply --force  # overwrite existing
"""

import os
import random
import string
import sys

ARMOR_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "items", "armor")

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

# --- Armor slot enum values (EquipmentCategory) ---
SLOT_HELMET = 7
SLOT_CHESTPLATE = 8
SLOT_GLOVES = 9
SLOT_LEGS = 10
SLOT_BOOTS = 11

# --- Rarity definitions (same multipliers as weapons) ---
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
    "1x3": "res://data/shapes/shape_1x3.tres",
    "2x2": "res://data/shapes/shape_2x2.tres",
    "2x3": "res://data/shapes/shape_2x3.tres",
    "l":   "res://data/shapes/shape_l.tres",
}

# --- Icon paths (placeholder per slot) ---
ICONS = {
    SLOT_HELMET:     "res://assets/sprites/items/helmet_common.png",
    SLOT_CHESTPLATE: "res://assets/sprites/items/chestplate_common.png",
    SLOT_GLOVES:     "res://assets/sprites/items/chestplate_common.png",  # placeholder
    SLOT_LEGS:       "res://assets/sprites/items/boots_common.png",       # placeholder
    SLOT_BOOTS:      "res://assets/sprites/items/boots_common.png",
}

# --- Armor type definitions ---
# Each: id, name, slot, shape, stats [(stat, value)...],
#        description, base_price, min_rarity (enum val)
ARMOR_TYPES = [
    # === HELMETS (slot=7) ===
    {
        "id": "cloth_helmet", "name": "Cloth Hood",
        "slot": SLOT_HELMET, "shape": "1x1",
        "stats": [(STAT_MAG_DEF, 3), (STAT_MAX_MP, 5)],
        "description": "A soft hood woven with arcane thread. Shields the mind from hostile magic.",
        "base_price": 25, "min_rarity": 0,
    },
    {
        "id": "leather_helmet", "name": "Leather Cap",
        "slot": SLOT_HELMET, "shape": "1x1",
        "stats": [(STAT_PHYS_DEF, 2), (STAT_SPEED, 2)],
        "description": "A fitted leather cap that keeps the head protected without slowing the wearer.",
        "base_price": 30, "min_rarity": 0,
    },
    {
        "id": "chain_helmet", "name": "Chain Coif",
        "slot": SLOT_HELMET, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 4), (STAT_MAG_DEF, 2)],
        "description": "Interlocking metal rings drape over the head and neck, offering sturdy protection.",
        "base_price": 40, "min_rarity": 1,
    },
    {
        "id": "plate_helmet", "name": "Plate Helm",
        "slot": SLOT_HELMET, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 6), (STAT_MAG_DEF, 1), (STAT_MAX_HP, 8)],
        "description": "A full-face helm of forged steel. Heavy, but few blows can penetrate it.",
        "base_price": 55, "min_rarity": 1,
    },

    # === CHESTPLATES (slot=8) ===
    {
        "id": "cloth_chestplate", "name": "Cloth Robe",
        "slot": SLOT_CHESTPLATE, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 1), (STAT_MAG_DEF, 5), (STAT_MAX_MP, 10)],
        "description": "An enchanter's robe layered with protective wards. Light as silk, strong against spells.",
        "base_price": 50, "min_rarity": 0,
    },
    {
        "id": "leather_chestplate", "name": "Leather Vest",
        "slot": SLOT_CHESTPLATE, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 4), (STAT_SPEED, 2), (STAT_CRIT_RATE, 2)],
        "description": "A form-fitting vest of hardened leather. Favored by scouts and thieves alike.",
        "base_price": 55, "min_rarity": 0,
    },
    {
        "id": "chain_chestplate", "name": "Chain Hauberk",
        "slot": SLOT_CHESTPLATE, "shape": "2x2",
        "stats": [(STAT_PHYS_DEF, 7), (STAT_MAG_DEF, 4), (STAT_MAX_HP, 10)],
        "description": "A knee-length shirt of riveted chain. The backbone of any soldier's kit.",
        "base_price": 85, "min_rarity": 1,
    },
    {
        "id": "plate_chestplate", "name": "Plate Cuirass",
        "slot": SLOT_CHESTPLATE, "shape": "2x3",
        "stats": [(STAT_PHYS_DEF, 10), (STAT_MAG_DEF, 2), (STAT_MAX_HP, 25), (STAT_SPEED, -3)],
        "description": "Thick steel plates shaped to the torso. Nearly impenetrable, but cumbersome.",
        "base_price": 120, "min_rarity": 2,
    },

    # === GLOVES (slot=9) ===
    {
        "id": "cloth_gloves", "name": "Cloth Wraps",
        "slot": SLOT_GLOVES, "shape": "1x1",
        "stats": [(STAT_MAG_ATK, 2), (STAT_MAG_DEF, 1)],
        "description": "Spell-threaded bandages that channel magic through the fingertips.",
        "base_price": 20, "min_rarity": 0,
    },
    {
        "id": "leather_gloves", "name": "Leather Bracers",
        "slot": SLOT_GLOVES, "shape": "1x2",
        "stats": [(STAT_PHYS_ATK, 2), (STAT_CRIT_RATE, 3)],
        "description": "Reinforced leather forearm guards. Keep the wrists steady for a killing stroke.",
        "base_price": 30, "min_rarity": 0,
    },
    {
        "id": "chain_gloves", "name": "Chain Gauntlets",
        "slot": SLOT_GLOVES, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 3), (STAT_PHYS_ATK, 1), (STAT_MAG_DEF, 1)],
        "description": "Chain-linked gloves with padded palms. Protect without sacrificing grip.",
        "base_price": 35, "min_rarity": 1,
    },
    {
        "id": "plate_gloves", "name": "Plate Gauntlets",
        "slot": SLOT_GLOVES, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 4), (STAT_PHYS_ATK, 2), (STAT_MAX_HP, 5), (STAT_SPEED, -1)],
        "description": "Articulated steel gauntlets. Every punch lands like a hammer blow.",
        "base_price": 50, "min_rarity": 2,
    },

    # === LEGS (slot=10) ===
    {
        "id": "cloth_legs", "name": "Cloth Trousers",
        "slot": SLOT_LEGS, "shape": "1x2",
        "stats": [(STAT_MAG_DEF, 3), (STAT_MAX_MP, 8), (STAT_SPEED, 1)],
        "description": "Loose-fitting trousers sewn with glyphs of warding. Move freely, think clearly.",
        "base_price": 35, "min_rarity": 0,
    },
    {
        "id": "leather_legs", "name": "Leather Leggings",
        "slot": SLOT_LEGS, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 2), (STAT_SPEED, 3), (STAT_CRIT_RATE, 2)],
        "description": "Supple leather leggings built for quick footwork and silent movement.",
        "base_price": 40, "min_rarity": 0,
    },
    {
        "id": "chain_legs", "name": "Chain Chausses",
        "slot": SLOT_LEGS, "shape": "1x3",
        "stats": [(STAT_PHYS_DEF, 5), (STAT_MAG_DEF, 3)],
        "description": "Chain leggings laced over padded cloth. Standard issue for men-at-arms.",
        "base_price": 55, "min_rarity": 1,
    },
    {
        "id": "plate_legs", "name": "Plate Greaves",
        "slot": SLOT_LEGS, "shape": "l",
        "stats": [(STAT_PHYS_DEF, 7), (STAT_MAG_DEF, 1), (STAT_MAX_HP, 10), (STAT_SPEED, -2)],
        "description": "Massive leg plates bolted to a steel frame. Standing ground has never been easier.",
        "base_price": 75, "min_rarity": 2,
    },

    # === BOOTS (slot=11) ===
    {
        "id": "cloth_boots", "name": "Cloth Sandals",
        "slot": SLOT_BOOTS, "shape": "1x1",
        "stats": [(STAT_SPEED, 2), (STAT_MAG_DEF, 2), (STAT_MAX_MP, 5)],
        "description": "Simple enchanted sandals. The wearer's feet barely touch the ground.",
        "base_price": 20, "min_rarity": 0,
    },
    {
        "id": "leather_boots", "name": "Leather Boots",
        "slot": SLOT_BOOTS, "shape": "1x2",
        "stats": [(STAT_SPEED, 4), (STAT_CRIT_RATE, 2)],
        "description": "Soft-soled boots that make no sound. Perfect for those who strike first.",
        "base_price": 35, "min_rarity": 0,
    },
    {
        "id": "chain_boots", "name": "Chain Boots",
        "slot": SLOT_BOOTS, "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 3), (STAT_SPEED, 2), (STAT_MAG_DEF, 1)],
        "description": "Mail-clad boots with reinforced soles. Steady footing on any battlefield.",
        "base_price": 40, "min_rarity": 1,
    },
    {
        "id": "plate_boots", "name": "Plate Sabatons",
        "slot": SLOT_BOOTS, "shape": "1x3",
        "stats": [(STAT_PHYS_DEF, 5), (STAT_MAX_HP, 8), (STAT_SPEED, -2)],
        "description": "Armored boots of solid steel. Each step shakes the earth.",
        "base_price": 55, "min_rarity": 1,
    },
]


def random_id(length: int = 5) -> str:
    """Generate a random alphanumeric ID for Godot resource references."""
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


def generate_tres(armor: dict, rarity: dict) -> str:
    """Generate the content of a .tres file for an armor piece at a given rarity."""
    r = rarity
    a = armor
    mult = r["power_mult"]

    # Scale stats: positive stats get max(1, round(v*m)),
    # negative stats get round(v*m) without clamping
    price = max(1, round(a["base_price"] * r["price_mult"]))
    scaled_stats = []
    for s, v in a["stats"]:
        if v > 0:
            scaled_stats.append((s, max(1, round(v * mult))))
        elif v < 0:
            scaled_stats.append((s, round(v * mult)))

    item_id = f"{a['id']}_{r['name']}"
    slot = a["slot"]

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
    eid_cond_mod = add_ext("Script", "res://scripts/resources/conditional_modifier_rule.gd")
    eid_stat_mod = add_ext("Script", "res://scripts/resources/stat_modifier.gd")
    eid_skill_data = add_ext("Script", "res://scripts/resources/skill_data.gd")

    # Shape
    shape_path = SHAPES[a["shape"]]
    eid_shape = add_ext("Resource", shape_path)

    # Icon
    icon_path = ICONS[slot]
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
    res_lines.append(f'display_name = "{a["name"]}"')
    res_lines.append(f'description = "{a["description"]}"')
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

    total = 0
    skipped = 0

    for armor in ARMOR_TYPES:
        min_rarity = armor["min_rarity"]
        for rarity in RARITIES:
            if rarity["enum_val"] < min_rarity:
                continue

            item_id = f"{armor['id']}_{rarity['name']}"
            filename = f"{item_id}.tres"
            filepath = os.path.join(ARMOR_DIR, filename)

            if os.path.exists(filepath) and not force:
                print(f"  SKIP (exists): {filename}")
                skipped += 1
                continue

            if apply:
                content = generate_tres(armor, rarity)
                with open(filepath, "w", encoding="utf-8") as f:
                    f.write(content)

            total += 1

    print(f"\n{'Created' if apply else 'Would create'}: {total} files")
    if skipped:
        print(f"Skipped (already exist): {skipped}")

    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
