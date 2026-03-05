#!/usr/bin/env python3
"""Generate weapon .tres files for all new weapon types at all rarity tiers.

Creates 5 new weapons per category (7 categories) × 6 rarity tiers = 210 files.
Each file follows the existing Godot .tres format for ItemData resources.

Usage:
    python tools/generate_weapons.py           # dry run (count only)
    python tools/generate_weapons.py --apply   # write files
"""

import math
import os
import random
import string
import sys

WEAPONS_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "items", "weapons")

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

# --- Category enum values ---
CAT_SWORD = 0
CAT_MACE = 1
CAT_BOW = 2
CAT_STAFF = 3
CAT_DAGGER = 4
CAT_SHIELD = 5
CAT_AXE = 6

# --- Rarity definitions ---
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
    "1x4": "res://data/shapes/shape_1x4.tres",
    "2x2": "res://data/shapes/shape_2x2.tres",
    "axe": "res://data/shapes/shape_axe.tres",
    "bow": "res://data/shapes/shape_bow.tres",
    "l":   "res://data/shapes/shape_l.tres",
}

# --- Skill paths (base = tier 1) ---
SKILLS = {
    "slash":        "res://data/skills/slash.tres",
    "power_strike": "res://data/skills/power_strike.tres",
    "backstab":     "res://data/skills/backstab.tres",
    "shield_bash":  "res://data/skills/shield_bash.tres",
    "fire_bolt":    "res://data/skills/fire_bolt.tres",
    "ice_shard":    "res://data/skills/ice_shard.tres",
    # Tier 2
    "slash_ii":        "res://data/skills/slash_ii.tres",
    "power_strike_ii": "res://data/skills/power_strike_ii.tres",
    "backstab_ii":     "res://data/skills/backstab_ii.tres",
    "shield_bash_ii":  "res://data/skills/shield_bash_ii.tres",
    "fire_bolt_ii":    "res://data/skills/fire_bolt_ii.tres",
    "ice_shard_ii":    "res://data/skills/ice_shard_ii.tres",
    # Tier 3
    "slash_iii":        "res://data/skills/slash_iii.tres",
    "power_strike_iii": "res://data/skills/power_strike_iii.tres",
    "backstab_iii":     "res://data/skills/backstab_iii.tres",
    "shield_bash_iii":  "res://data/skills/shield_bash_iii.tres",
    "fire_bolt_iii":    "res://data/skills/fire_bolt_iii.tres",
    "ice_shard_iii":    "res://data/skills/ice_shard_iii.tres",
}

# Rarity → skill tier suffix mapping
# Common/Uncommon = base, Rare/Elite = II, Legendary/Unique = III
SKILL_TIER_SUFFIX = {
    0: "",      # common
    1: "",      # uncommon
    2: "_ii",   # rare
    3: "_ii",   # elite
    4: "_iii",  # legendary
    5: "_iii",  # unique
}


def get_tiered_skill(base_skill: str, rarity_enum: int) -> str:
    """Return the tiered skill key for a given base skill and rarity."""
    suffix = SKILL_TIER_SUFFIX[rarity_enum]
    return base_skill + suffix

# --- Icon paths (reuse category icons as placeholders) ---
ICONS = {
    CAT_SWORD:  "res://assets/sprites/items/sword_common.png",
    CAT_MACE:   "res://assets/sprites/items/mace_common.png",
    CAT_BOW:    "res://assets/sprites/items/bow_common.png",
    CAT_STAFF:  "res://assets/sprites/items/staff_elite.png",
    CAT_DAGGER: "res://assets/sprites/items/dagger_common.png",
    CAT_SHIELD: "res://assets/sprites/items/shield_common.png",
    CAT_AXE:    "res://assets/sprites/items/mace_common.png",
}

# --- Weapon definitions ---
# Each weapon: id_prefix, display_name, category, hand_slots, shape_key,
#              base_power, magical_power, stat_mods [(stat, value)...],
#              skills [skill_key...], description, base_price
WEAPONS = [
    # === SWORDS (CAT_SWORD=0) ===
    {
        "id": "katana", "name": "Katana", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 6, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 6)],
        "skills": ["slash", "power_strike"],
        "description": "A curved single-edged blade forged for swift, precise cuts.",
        "base_price": 55,
    },
    {
        "id": "scimitar", "name": "Scimitar", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5), (STAT_SPEED, 3)],
        "skills": ["slash"],
        "description": "A wide curved blade designed for sweeping strikes from horseback.",
        "base_price": 52,
    },
    {
        "id": "rapier", "name": "Rapier", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_CRIT_RATE, 5)],
        "skills": ["backstab"],
        "description": "A thin thrusting sword that finds gaps in any defense.",
        "base_price": 58,
    },
    {
        "id": "claymore", "name": "Claymore", "category": CAT_SWORD,
        "hands": 2, "shape": "1x3",
        "base_power": 9, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 9)],
        "skills": ["power_strike"],
        "description": "A massive two-handed greatsword that cleaves through armor.",
        "base_price": 75,
    },
    {
        "id": "falchion", "name": "Falchion", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 7, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 7)],
        "skills": ["slash", "power_strike"],
        "description": "A heavy single-edged blade favored by veteran soldiers.",
        "base_price": 60,
    },

    # === MACES (CAT_MACE=1) ===
    {
        "id": "war_hammer", "name": "War Hammer", "category": CAT_MACE,
        "hands": 2, "shape": "axe",
        "base_power": 10, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 10)],
        "skills": ["shield_bash"],
        "description": "A massive hammer that crushes armor and bone alike.",
        "base_price": 80,
    },
    {
        "id": "flail", "name": "Flail", "category": CAT_MACE,
        "hands": 1, "shape": "1x2",
        "base_power": 6, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 6), (STAT_CRIT_RATE, 4)],
        "skills": [],
        "description": "A spiked ball on a chain, unpredictable and devastating.",
        "base_price": 55,
    },
    {
        "id": "morning_star", "name": "Morning Star", "category": CAT_MACE,
        "hands": 1, "shape": "1x2",
        "base_power": 7, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 7)],
        "skills": ["shield_bash"],
        "description": "A heavy spiked mace that punctures the thickest plate.",
        "base_price": 62,
    },
    {
        "id": "cudgel", "name": "Cudgel", "category": CAT_MACE,
        "hands": 1, "shape": "1x1",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_SPEED, 2)],
        "skills": ["shield_bash"],
        "description": "A short, sturdy club. Simple but effective.",
        "base_price": 40,
    },
    {
        "id": "maul", "name": "Maul", "category": CAT_MACE,
        "hands": 2, "shape": "1x3",
        "base_power": 14, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 14), (STAT_CRIT_DMG, 8)],
        "skills": [],
        "description": "An enormous two-handed hammer built to shatter.",
        "base_price": 90,
    },

    # === BOWS (CAT_BOW=2) ===
    {
        "id": "longbow", "name": "Longbow", "category": CAT_BOW,
        "hands": 2, "shape": "bow",
        "base_power": 7, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 7)],
        "skills": ["power_strike"],
        "description": "A tall bow with exceptional range and stopping power.",
        "base_price": 60,
    },
    {
        "id": "crossbow", "name": "Crossbow", "category": CAT_BOW,
        "hands": 2, "shape": "1x2",
        "base_power": 8, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 8), (STAT_CRIT_DMG, 6)],
        "skills": [],
        "description": "A mechanical bow that trades speed for raw penetration.",
        "base_price": 65,
    },
    {
        "id": "shortbow", "name": "Shortbow", "category": CAT_BOW,
        "hands": 2, "shape": "1x2",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_SPEED, 4)],
        "skills": [],
        "description": "A compact bow for rapid volleys at close range.",
        "base_price": 42,
    },
    {
        "id": "recurve_bow", "name": "Recurve Bow", "category": CAT_BOW,
        "hands": 2, "shape": "bow",
        "base_power": 6, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 6), (STAT_SPEED, 2)],
        "skills": [],
        "description": "Curved limbs store extra energy for a powerful shot.",
        "base_price": 55,
    },
    {
        "id": "greatbow", "name": "Greatbow", "category": CAT_BOW,
        "hands": 2, "shape": "bow",
        "base_power": 10, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 10)],
        "skills": ["power_strike"],
        "description": "A massive siege bow that fires bolts as thick as spears.",
        "base_price": 80,
    },

    # === STAFFS (CAT_STAFF=3) ===
    {
        "id": "wand", "name": "Wand", "category": CAT_STAFF,
        "hands": 1, "shape": "1x1",
        "base_power": 0, "magical_power": 4,
        "stats": [(STAT_MAG_ATK, 6)],
        "skills": ["fire_bolt"],
        "description": "A slender focus for channeling quick bursts of magic.",
        "base_price": 45,
    },
    {
        "id": "rod", "name": "Rod", "category": CAT_STAFF,
        "hands": 1, "shape": "1x2",
        "base_power": 0, "magical_power": 6,
        "stats": [(STAT_MAG_ATK, 9)],
        "skills": ["fire_bolt"],
        "description": "A sturdy rod infused with arcane resonance.",
        "base_price": 55,
    },
    {
        "id": "scepter", "name": "Scepter", "category": CAT_STAFF,
        "hands": 1, "shape": "1x2",
        "base_power": 0, "magical_power": 5,
        "stats": [(STAT_MAG_ATK, 8), (STAT_CRIT_RATE, 3)],
        "skills": ["ice_shard"],
        "description": "An ornate scepter crackling with elemental power.",
        "base_price": 58,
    },
    {
        "id": "oracle_staff", "name": "Oracle Staff", "category": CAT_STAFF,
        "hands": 2, "shape": "1x4",
        "base_power": 0, "magical_power": 8,
        "stats": [(STAT_MAG_ATK, 12)],
        "skills": ["fire_bolt", "ice_shard"],
        "description": "An ancient staff that bends the fabric of reality.",
        "base_price": 75,
    },
    {
        "id": "grimoire", "name": "Grimoire", "category": CAT_STAFF,
        "hands": 1, "shape": "2x2",
        "base_power": 0, "magical_power": 7,
        "stats": [(STAT_MAG_ATK, 11)],
        "skills": ["fire_bolt", "ice_shard"],
        "description": "A tome of forbidden knowledge, heavy with power.",
        "base_price": 70,
    },

    # === DAGGERS (CAT_DAGGER=4) ===
    {
        "id": "stiletto", "name": "Stiletto", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 3, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 3), (STAT_CRIT_RATE, 6)],
        "skills": ["backstab"],
        "description": "A needle-thin blade made for piercing vital points.",
        "base_price": 48,
    },
    {
        "id": "kris", "name": "Kris", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5), (STAT_SPEED, 3)],
        "skills": ["backstab"],
        "description": "A wavy-bladed dagger that leaves jagged wounds.",
        "base_price": 45,
    },
    {
        "id": "tanto", "name": "Tanto", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 6, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 6), (STAT_SPEED, 2)],
        "skills": ["backstab"],
        "description": "A short, thick blade designed to punch through armor.",
        "base_price": 50,
    },
    {
        "id": "kukri", "name": "Kukri", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5), (STAT_SPEED, 4)],
        "skills": ["backstab"],
        "description": "A curved chopping knife from distant highlands.",
        "base_price": 47,
    },
    {
        "id": "dirk", "name": "Dirk", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x2",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5), (STAT_SPEED, 3)],
        "skills": ["backstab"],
        "description": "A long thrusting dagger favored by naval fighters.",
        "base_price": 50,
    },

    # === SHIELDS (CAT_SHIELD=5) ===
    {
        "id": "buckler", "name": "Buckler", "category": CAT_SHIELD,
        "hands": 1, "shape": "1x1",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 6), (STAT_SPEED, 3)],
        "skills": ["shield_bash"],
        "description": "A small, light shield for parrying quick blows.",
        "base_price": 35,
    },
    {
        "id": "tower_shield", "name": "Tower Shield", "category": CAT_SHIELD,
        "hands": 1, "shape": "2x2",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 12), (STAT_MAG_DEF, 6)],
        "skills": ["shield_bash"],
        "description": "A massive shield that covers the entire body.",
        "base_price": 70,
    },
    {
        "id": "kite_shield", "name": "Kite Shield", "category": CAT_SHIELD,
        "hands": 1, "shape": "1x2",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 8), (STAT_MAG_DEF, 4)],
        "skills": ["shield_bash"],
        "description": "A tapered shield offering solid all-round protection.",
        "base_price": 50,
    },
    {
        "id": "round_shield", "name": "Round Shield", "category": CAT_SHIELD,
        "hands": 1, "shape": "1x1",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 7)],
        "skills": ["shield_bash"],
        "description": "A versatile circular shield, sturdy and balanced.",
        "base_price": 40,
    },
    {
        "id": "pavise", "name": "Pavise", "category": CAT_SHIELD,
        "hands": 1, "shape": "1x2",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 10), (STAT_MAG_DEF, 4)],
        "skills": [],
        "description": "A tall standing shield that deflects arrows and spells alike.",
        "base_price": 55,
    },

    # === AXES (CAT_AXE=6) ===
    {
        "id": "hatchet", "name": "Hatchet", "category": CAT_AXE,
        "hands": 1, "shape": "1x1",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5), (STAT_SPEED, 2)],
        "skills": [],
        "description": "A light throwing axe, quick and brutal.",
        "base_price": 42,
    },
    {
        "id": "halberd", "name": "Halberd", "category": CAT_AXE,
        "hands": 2, "shape": "1x4",
        "base_power": 10, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 10)],
        "skills": ["power_strike"],
        "description": "A polearm topped with an axe blade, hook, and spike.",
        "base_price": 78,
    },
    {
        "id": "tomahawk", "name": "Tomahawk", "category": CAT_AXE,
        "hands": 1, "shape": "1x1",
        "base_power": 6, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 6), (STAT_CRIT_RATE, 3)],
        "skills": [],
        "description": "A balanced hand axe that strikes with lethal precision.",
        "base_price": 48,
    },
    {
        "id": "great_axe", "name": "Great Axe", "category": CAT_AXE,
        "hands": 2, "shape": "axe",
        "base_power": 12, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 12)],
        "skills": ["power_strike"],
        "description": "A towering double-headed axe that splits foes in two.",
        "base_price": 85,
    },
    {
        "id": "cleaver", "name": "Cleaver", "category": CAT_AXE,
        "hands": 1, "shape": "1x2",
        "base_power": 7, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 7)],
        "skills": ["slash"],
        "description": "A wide-bladed chopping weapon with a butcher's edge.",
        "base_price": 55,
    },
]


def random_id(length: int = 5) -> str:
    """Generate a random alphanumeric ID for Godot resource references."""
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


def generate_tres(weapon: dict, rarity: dict) -> str:
    """Generate the content of a .tres file for a weapon at a given rarity."""
    r = rarity
    w = weapon
    mult = r["power_mult"]

    # Scale stats (keep 0 as 0 for weapons that don't use that power type)
    base_power = round(w["base_power"] * mult) if w["base_power"] > 0 else 0
    mag_power = round(w["magical_power"] * mult) if w["magical_power"] > 0 else 0
    price = max(1, round(w["base_price"] * r["price_mult"]))
    scaled_stats = [(s, max(1, round(v * mult))) for s, v in w["stats"]]

    item_id = f"{w['id']}_{r['name']}"
    category = w["category"]

    # Build ext_resource entries
    ext_resources = []
    ext_id_counter = [1]

    def add_ext(res_type: str, path: str, hint: str = "") -> str:
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
    shape_path = SHAPES[w["shape"]]
    eid_shape = add_ext("Resource", shape_path)

    # Icon
    icon_path = ICONS[category]
    eid_icon = add_ext("Texture2D", icon_path)

    # Skills (tiered by rarity)
    skill_eids = []
    for sk in w["skills"]:
        tiered_sk = get_tiered_skill(sk, r["enum_val"])
        eid = add_ext("Resource", SKILLS[tiered_sk])
        skill_eids.append(eid)

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
    res_lines.append(f'display_name = "{w["name"]}"')
    res_lines.append(f'description = "{w["description"]}"')
    res_lines.append(f'icon = ExtResource("{eid_icon}")')

    # Category (0 = SWORD is default, only write if non-zero)
    if category != 0:
        res_lines.append(f"category = {category}")

    # Rarity (0 = COMMON is default, only write if non-zero)
    if r["enum_val"] != 0:
        res_lines.append(f"rarity = {r['enum_val']}")

    res_lines.append(f"hand_slots_required = {w['hands']}")
    res_lines.append(f"armor_slot = {category}")
    res_lines.append(f'shape = ExtResource("{eid_shape}")')

    # Stat modifiers
    sub_refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
    res_lines.append(f'stat_modifiers = Array[ExtResource("{eid_stat_mod}")]([{sub_refs}])')

    # Base power (only write if > 0)
    if base_power > 0:
        res_lines.append(f"base_power = {base_power}")

    # Magical power (only write if > 0)
    if mag_power > 0:
        res_lines.append(f"magical_power = {mag_power}")

    # NOTE: granted_skills removed — skills now come from element points system

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

    for weapon in WEAPONS:
        for rarity in RARITIES:
            item_id = f"{weapon['id']}_{rarity['name']}"
            filename = f"{item_id}.tres"
            filepath = os.path.join(WEAPONS_DIR, filename)

            if os.path.exists(filepath) and not force:
                print(f"  SKIP (exists): {filename}")
                skipped += 1
                continue

            if apply:
                content = generate_tres(weapon, rarity)
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
