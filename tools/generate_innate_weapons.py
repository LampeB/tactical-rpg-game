#!/usr/bin/env python3
"""Generate weapon .tres files for weapons with innate effects.

Creates special weapons with innate status procs (burn, poison, chill, shock)
or unique stat profiles (high crit, speed, hybrid damage).

Usage:
    python tools/generate_innate_weapons.py           # dry run
    python tools/generate_innate_weapons.py --apply   # write files
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
    {"name": "common",    "enum_val": 0, "power_mult": 1.0,  "price_mult": 1.0,  "chance": 0.05, "stacks": 1, "crit_stacks": 2},
    {"name": "uncommon",  "enum_val": 1, "power_mult": 1.4,  "price_mult": 1.56, "chance": 0.15, "stacks": 1, "crit_stacks": 2},
    {"name": "rare",      "enum_val": 2, "power_mult": 1.8,  "price_mult": 2.04, "chance": 0.25, "stacks": 1, "crit_stacks": 3},
    {"name": "elite",     "enum_val": 3, "power_mult": 2.2,  "price_mult": 2.64, "chance": 0.35, "stacks": 2, "crit_stacks": 3},
    {"name": "legendary", "enum_val": 4, "power_mult": 3.0,  "price_mult": 3.60, "chance": 0.45, "stacks": 2, "crit_stacks": 4},
    {"name": "unique",    "enum_val": 5, "power_mult": 4.0,  "price_mult": 4.80, "chance": 0.60, "stacks": 3, "crit_stacks": 5},
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
    "shortbow": "res://data/shapes/shape_shortbow.tres",
    "longbow": "res://data/shapes/shape_longbow.tres",
    "cross": "res://data/shapes/shape_cross.tres",
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

# --- Status effect paths ---
STATUS_EFFECTS = {
    "burn":     "res://data/status_effects/burn.tres",
    "poisoned": "res://data/status_effects/poisoned.tres",
    "chilled":  "res://data/status_effects/chilled.tres",
    "shocked":  "res://data/status_effects/shocked.tres",
}

# --- Icon paths ---
ICONS = {
    CAT_SWORD:  "res://assets/sprites/items/sword_common.png",
    CAT_MACE:   "res://assets/sprites/items/mace_common.png",
    CAT_BOW:    "res://assets/sprites/items/bow_common.png",
    CAT_STAFF:  "res://assets/sprites/items/staff_elite.png",
    CAT_DAGGER: "res://assets/sprites/items/dagger_common.png",
    CAT_SHIELD: "res://assets/sprites/items/shield_common.png",
    CAT_AXE:    "res://assets/sprites/items/mace_common.png",
}

# --- Innate weapon definitions ---
# innate_effect: (status_key, chance) or None
# Stats that scale with rarity: base_power, magical_power, stat values, price
# Innate chance does NOT scale with rarity (same as Snake Fang / Frostbow)
WEAPONS = [
    # === SWORDS ===
    {
        "id": "flamberge", "name": "Flamberge", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5)],
        "skills": ["slash"],
        "innate_effect": ("burn", 0.3),
        "description": "A wavy-bladed sword wreathed in flame. Its strikes leave searing burns.",
        "base_price": 70,
    },
    {
        "id": "vorpal_blade", "name": "Vorpal Blade", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 3, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 3), (STAT_CRIT_RATE, 10), (STAT_CRIT_DMG, 15)],
        "skills": ["power_strike"],
        "innate_effect": None,
        "description": "A blade so sharp it finds vital points on its own. Devastating on a lucky strike.",
        "base_price": 80,
    },
    {
        "id": "windblade", "name": "Windblade", "category": CAT_SWORD,
        "hands": 1, "shape": "1x2",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_SPEED, 6)],
        "skills": ["slash"],
        "innate_effect": None,
        "description": "A feather-light blade that cuts faster than the eye can follow.",
        "base_price": 65,
    },

    # === MACES ===
    {
        "id": "frostmallet", "name": "Frostmallet", "category": CAT_MACE,
        "hands": 1, "shape": "1x2",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5)],
        "skills": [],
        "innate_effect": ("chilled", 0.4),
        "description": "A hammer forged from glacier ice that never melts. Each blow numbs the foe.",
        "base_price": 60,
    },
    {
        "id": "skullcracker", "name": "Skullcracker", "category": CAT_MACE,
        "hands": 2, "shape": "1x3",
        "base_power": 8, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 8), (STAT_CRIT_RATE, 8)],
        "skills": ["power_strike"],
        "innate_effect": None,
        "description": "A brutal weapon designed to find weak points in armor. Crits shatter bone.",
        "base_price": 95,
    },

    # === BOWS ===
    {
        "id": "viper_bow", "name": "Viper Bow", "category": CAT_BOW,
        "hands": 2, "shape": "bow",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5)],
        "skills": [],
        "innate_effect": ("poisoned", 0.4),
        "description": "A bow strung with serpent sinew. Its arrows carry venom that rots from within.",
        "base_price": 65,
    },
    {
        "id": "stormstring", "name": "Stormstring", "category": CAT_BOW,
        "hands": 2, "shape": "shortbow",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_SPEED, 3)],
        "skills": [],
        "innate_effect": ("shocked", 0.3),
        "description": "Each arrow crackles with captured lightning. Fast, relentless, and paralyzing.",
        "base_price": 70,
    },
    {
        "id": "hawkeye", "name": "Hawkeye", "category": CAT_BOW,
        "hands": 2, "shape": "bow",
        "base_power": 4, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 4), (STAT_CRIT_RATE, 8), (STAT_CRIT_DMG, 12)],
        "skills": [],
        "innate_effect": None,
        "description": "A precision-crafted bow that guides arrows to vital targets. Every shot counts.",
        "base_price": 85,
    },

    # === STAFFS ===
    {
        "id": "ember_wand", "name": "Ember Wand", "category": CAT_STAFF,
        "hands": 1, "shape": "1x1",
        "base_power": 0, "magical_power": 4,
        "stats": [(STAT_MAG_ATK, 6)],
        "skills": ["fire_bolt"],
        "innate_effect": ("burn", 0.35),
        "description": "A wand that smolders with inner flame. Its spells scorch and ignite.",
        "base_price": 55,
    },
    {
        "id": "frostspire", "name": "Frostspire", "category": CAT_STAFF,
        "hands": 2, "shape": "1x4",
        "base_power": 0, "magical_power": 6,
        "stats": [(STAT_MAG_ATK, 9)],
        "skills": ["ice_shard"],
        "innate_effect": ("chilled", 0.45),
        "description": "An icicle staff that radiates bitter cold. Enemies slow to a crawl.",
        "base_price": 80,
    },

    # === DAGGERS ===
    {
        "id": "frozen_fang", "name": "Frozen Fang", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 3, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 3)],
        "skills": ["backstab"],
        "innate_effect": ("chilled", 0.35),
        "description": "A blade of eternal ice that numbs on contact. Foes feel the cold long after the cut.",
        "base_price": 50,
    },
    {
        "id": "ember_shiv", "name": "Ember Shiv", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 3, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 3), (STAT_SPEED, 4)],
        "skills": ["backstab"],
        "innate_effect": ("burn", 0.25),
        "description": "A red-hot sliver of metal that sears flesh on contact. Quick and agonizing.",
        "base_price": 55,
    },
    {
        "id": "heartseeker", "name": "Heartseeker", "category": CAT_DAGGER,
        "hands": 1, "shape": "1x1",
        "base_power": 2, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 2), (STAT_CRIT_RATE, 12), (STAT_CRIT_DMG, 10)],
        "skills": ["backstab"],
        "innate_effect": None,
        "description": "A dagger that unerringly finds the heart. Low base damage, devastating crits.",
        "base_price": 75,
    },

    # === SHIELDS ===
    {
        "id": "spellward", "name": "Spellward", "category": CAT_SHIELD,
        "hands": 1, "shape": "1x2",
        "base_power": 0, "magical_power": 0,
        "stats": [(STAT_PHYS_DEF, 4), (STAT_MAG_DEF, 8)],
        "skills": ["shield_bash"],
        "innate_effect": None,
        "description": "A rune-etched shield that deflects spells. Mages dread its glimmering surface.",
        "base_price": 70,
    },

    # === AXES ===
    {
        "id": "infernal_cleaver", "name": "Infernal Cleaver", "category": CAT_AXE,
        "hands": 1, "shape": "1x2",
        "base_power": 5, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 5)],
        "skills": [],
        "innate_effect": ("burn", 0.35),
        "description": "A cleaver that glows white-hot. Every wound it inflicts is cauterized and searing.",
        "base_price": 60,
    },
    {
        "id": "permafrost_axe", "name": "Permafrost Axe", "category": CAT_AXE,
        "hands": 2, "shape": "axe",
        "base_power": 7, "magical_power": 0,
        "stats": [(STAT_PHYS_ATK, 7)],
        "skills": [],
        "innate_effect": ("chilled", 0.4),
        "description": "An axe of frozen steel that slows foes to a crawl. The cold bites deeper than the blade.",
        "base_price": 75,
    },
]


def random_id(length: int = 5) -> str:
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


def generate_tres(weapon: dict, rarity: dict) -> str:
    r = rarity
    w = weapon
    mult = r["power_mult"]

    base_power = round(w["base_power"] * mult) if w["base_power"] > 0 else 0
    mag_power = round(w["magical_power"] * mult) if w["magical_power"] > 0 else 0
    price = max(1, round(w["base_price"] * r["price_mult"]))
    scaled_stats = [(s, max(1, round(v * mult))) for s, v in w["stats"]]

    item_id = f"{w['id']}_{r['name']}"
    category = w["category"]

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
    eid_shape = add_ext("Resource", SHAPES[w["shape"]])

    # Icon
    eid_icon = add_ext("Texture2D", ICONS[category])

    # Status effect (if any)
    eid_status = None
    if w["innate_effect"]:
        status_key, _ = w["innate_effect"]
        eid_status = add_ext("Resource", STATUS_EFFECTS[status_key])

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

    if category != 0:
        res_lines.append(f"category = {category}")

    if r["enum_val"] != 0:
        res_lines.append(f"rarity = {r['enum_val']}")

    res_lines.append(f"hand_slots_required = {w['hands']}")
    res_lines.append(f"armor_slot = {category}")
    res_lines.append(f'shape = ExtResource("{eid_shape}")')

    # Stat modifiers
    if sub_ids:
        sub_refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
        res_lines.append(f'stat_modifiers = Array[ExtResource("{eid_stat_mod}")]([{sub_refs}])')

    # Base power
    if base_power > 0:
        res_lines.append(f"base_power = {base_power}")

    # Magical power
    if mag_power > 0:
        res_lines.append(f"magical_power = {mag_power}")

    # Innate status effect (chance and stacks scale with rarity)
    if eid_status:
        chance = r["chance"]
        res_lines.append(f'innate_status_effect = ExtResource("{eid_status}")')
        res_lines.append(f"innate_status_effect_chance = {chance}")
        if r["stacks"] != 1:
            res_lines.append(f"innate_status_stacks = {r['stacks']}")
        if r["crit_stacks"] != 2:
            res_lines.append(f"innate_crit_status_stacks = {r['crit_stacks']}")

    # Granted skills
    if skill_eids:
        skill_refs = ", ".join(f'ExtResource("{eid}")' for eid in skill_eids)
        res_lines.append(f'granted_skills = Array[ExtResource("{eid_skill_data}")]([{skill_refs}])')

    res_lines.append(f"base_price = {price}")

    # Assemble
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
                print(f"  Created: {filename}")

            total += 1

    print(f"\n{'Created' if apply else 'Would create'}: {total} files")
    if skipped:
        print(f"Skipped (already exist): {skipped}")

    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
