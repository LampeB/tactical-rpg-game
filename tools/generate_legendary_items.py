#!/usr/bin/env python3
"""Generate 16 unique legendary item .tres files with special effects.

Creates hand-crafted items in data/items/weapons/, data/items/armor/, and
data/items/jewelry/ with build-defining legendary effects.

Usage:
    python tools/generate_legendary_items.py           # dry run
    python tools/generate_legendary_items.py --apply   # write files
    python tools/generate_legendary_items.py --apply --force  # overwrite
"""

import os
import random
import string
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")

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

# --- ItemType ---
ITEM_ACTIVE_TOOL = 0
ITEM_PASSIVE_GEAR = 1

# --- EquipmentCategory ---
CAT_SWORD = 0
CAT_MACE = 1
CAT_BOW = 2
CAT_STAFF = 3
CAT_DAGGER = 4
CAT_SHIELD = 5
CAT_AXE = 6
CAT_HELMET = 7
CAT_CHESTPLATE = 8
CAT_GLOVES = 9
CAT_LEGS = 10
CAT_BOOTS = 11
CAT_NECKLACE = 12
CAT_RING = 13

# --- Rarity ---
RARITY_UNIQUE = 5

# --- Shape paths ---
SHAPES = {
    "1x1": "res://data/shapes/shape_1x1.tres",
    "1x2": "res://data/shapes/shape_1x2.tres",
    "1x3": "res://data/shapes/shape_1x3.tres",
    "1x4": "res://data/shapes/shape_1x4.tres",
    "2x2": "res://data/shapes/shape_2x2.tres",
    "axe": "res://data/shapes/shape_axe.tres",
    "bow": "res://data/shapes/shape_bow.tres",
    "l": "res://data/shapes/shape_l.tres",
    "bold_u": "res://data/shapes/shape_bold_u.tres",
    "great_axe": "res://data/shapes/shape_great_axe.tres",
    "double_scythe": "res://data/shapes/shape_double_scythe.tres",
    "longbow": "res://data/shapes/shape_longbow.tres",
    "staff_custom": "res://data/shapes/shape_custom_212525.tres",
}

# --- Icon paths by category ---
ICONS = {
    CAT_SWORD: "res://assets/sprites/items/longSword_common.png",
    CAT_MACE: "res://assets/sprites/items/mace_common.png",
    CAT_BOW: "res://assets/sprites/items/bow_common.png",
    CAT_STAFF: "res://assets/sprites/items/staff_common.png",
    CAT_DAGGER: "res://assets/sprites/items/dagger_common.png",
    CAT_SHIELD: "res://assets/sprites/items/shield_common.png",
    CAT_AXE: "res://assets/sprites/items/mace_common.png",  # Axes use mace icon
    CAT_HELMET: "res://assets/sprites/items/helmet_common.png",
    CAT_CHESTPLATE: "res://assets/sprites/items/chestplate_common.png",
    CAT_GLOVES: "res://assets/sprites/items/chestplate_common.png",  # Placeholder
    CAT_BOOTS: "res://assets/sprites/items/boots_common.png",
    CAT_NECKLACE: "res://assets/sprites/items/ring_common.png",  # Placeholder
    CAT_RING: "res://assets/sprites/items/ring_common.png",
}

# --- Skill paths ---
SKILLS = {
    "chain_lightning": "res://data/skills/chain_lightning.tres",
    "soul_rend": "res://data/skills/soul_rend.tres",
    "warcry": "res://data/skills/warcry.tres",
    "power_strike_iii": "res://data/skills/power_strike_iii.tres",
    "slash_iii": "res://data/skills/slash_iii.tres",
    "backstab_iii": "res://data/skills/backstab_iii.tres",
    "shield_bash_iii": "res://data/skills/shield_bash_iii.tres",
}

# --- Status effects ---
STATUS_EFFECTS = {
    "shocked": "res://data/status_effects/shocked.tres",
    "poisoned": "res://data/status_effects/poisoned.tres",
}


def random_id(length: int = 5) -> str:
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


# ==========================================================================
# 16 Legendary Items
# ==========================================================================

LEGENDARY_ITEMS = [
    # --- Group A: granted_effects only (PASSIVE_GEAR) ---

    # 1. Aegis of the Eternal — Shield (ACTIVE_TOOL)
    {
        "id": "aegis_of_the_eternal",
        "name": "Aegis of the Eternal",
        "description": "A shield of starforged metal that refuses to let its bearer fall. Once per battle, it defies death itself.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_SHIELD,
        "shape": "2x2",
        "hand_slots": 1,
        "stats": [(STAT_PHYS_DEF, 20), (STAT_MAX_HP, 30)],
        "base_power": 0,
        "magical_power": 0,
        "granted_effects": ["auto_revive"],
        "skills": ["shield_bash_iii"],
        "base_price": 500,
        "dir": "weapons",
    },

    # 2. Shadow Mantle — Chestplate (PASSIVE_GEAR)
    {
        "id": "shadow_mantle",
        "name": "Shadow Mantle",
        "description": "Woven from midnight silk and enchanted shadow. The first blow against its wearer always misses.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_CHESTPLATE,
        "shape": "2x2",
        "stats": [(STAT_PHYS_DEF, 10), (STAT_MAG_DEF, 8), (STAT_SPEED, 5)],
        "granted_effects": ["first_hit_evasion"],
        "base_price": 480,
        "dir": "armor",
    },

    # 3. Crown of the Undying — Helmet (PASSIVE_GEAR)
    {
        "id": "crown_of_the_undying",
        "name": "Crown of the Undying",
        "description": "A crown of bone and blackened iron. Each kill feeds the wearer's shield with stolen vitality.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_HELMET,
        "shape": "1x2",
        "stats": [(STAT_MAX_HP, 25), (STAT_PHYS_DEF, 5)],
        "granted_effects": ["damage_shield_on_kill"],
        "base_price": 400,
        "dir": "armor",
    },

    # 4. Mindflayer's Band — Ring (PASSIVE_GEAR)
    {
        "id": "mindflayers_band",
        "name": "Mindflayer's Band",
        "description": "A tentacled ring of alien metal. It drains magical essence from the fallen.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_RING,
        "shape": "1x1",
        "stats": [(STAT_MAX_MP, 15), (STAT_MAG_ATK, 5)],
        "granted_effects": ["mp_on_kill"],
        "base_price": 380,
        "dir": "jewelry",
    },

    # 5. Boneweaver Gauntlets — Gloves (PASSIVE_GEAR)
    {
        "id": "boneweaver_gauntlets",
        "name": "Boneweaver Gauntlets",
        "description": "Gauntlets sewn from dragon sinew. They strike back with terrifying speed.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_GLOVES,
        "shape": "1x2",
        "stats": [(STAT_PHYS_ATK, 8), (STAT_PHYS_DEF, 8)],
        "granted_effects": ["counter_attack"],
        "base_price": 420,
        "dir": "armor",
    },

    # 6. Ember Heart Pendant — Necklace (PASSIVE_GEAR)
    {
        "id": "ember_heart_pendant",
        "name": "Ember Heart Pendant",
        "description": "A pendant housing a captive ember. It scorches any who dare strike the wearer.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_NECKLACE,
        "shape": "1x2",
        "stats": [(STAT_MAG_ATK, 12), (STAT_MAX_HP, 8)],
        "granted_effects": ["thorns"],
        "base_price": 400,
        "dir": "jewelry",
    },

    # 7. Ironhide Greaves — Boots (PASSIVE_GEAR)
    {
        "id": "ironhide_greaves",
        "name": "Ironhide Greaves",
        "description": "Boots forged from living iron. They slow the wearer but grant an impenetrable barrier at battle's start.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_BOOTS,
        "shape": "1x2",
        "stats": [(STAT_PHYS_DEF, 12), (STAT_MAG_DEF, 5), (STAT_SPEED, -2)],
        "granted_effects": ["start_shield"],
        "base_price": 380,
        "dir": "armor",
    },

    # 8. Bloodstone Signet — Ring (PASSIVE_GEAR)
    {
        "id": "bloodstone_signet",
        "name": "Bloodstone Signet",
        "description": "A ring set with a pulsing bloodstone. It steadily feeds mana to its wearer.",
        "item_type": ITEM_PASSIVE_GEAR,
        "category": CAT_RING,
        "shape": "1x1",
        "stats": [(STAT_MAX_HP, 10), (STAT_LUCK, 5)],
        "granted_effects": ["mana_regen"],
        "base_price": 360,
        "dir": "jewelry",
    },

    # --- Group B: Lifesteal weapons ---

    # 9. Soulreaver — Sword (ACTIVE_TOOL)
    {
        "id": "soulreaver",
        "name": "Soulreaver",
        "description": "A cursed blade that drinks deeply of every wound it inflicts. The wielder heals with each strike.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_SWORD,
        "shape": "1x3",
        "hand_slots": 1,
        "stats": [(STAT_PHYS_ATK, 18)],
        "base_power": 22,
        "innate_lifesteal_percent": 0.15,
        "skills": ["slash_iii", "power_strike_iii"],
        "base_price": 520,
        "dir": "weapons",
    },

    # 10. Vampiric Halberd — Axe 2H (ACTIVE_TOOL)
    {
        "id": "vampiric_halberd",
        "name": "Vampiric Halberd",
        "description": "A massive halberd steeped in blood magic. It siphons life on every hit and feasts on the fallen.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_AXE,
        "shape": "great_axe",
        "hand_slots": 2,
        "stats": [(STAT_PHYS_ATK, 22)],
        "base_power": 30,
        "innate_lifesteal_percent": 0.10,
        "on_kill_heal_percent": 0.15,
        "skills": ["power_strike_iii"],
        "base_price": 580,
        "dir": "weapons",
    },

    # --- Group C: Multi-hit ---

    # 11. Zephyr Fangs — Dagger (ACTIVE_TOOL)
    {
        "id": "zephyr_fangs",
        "name": "Zephyr Fangs",
        "description": "Twin daggers forged from wind-touched steel. They bite twice more after each strike.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_DAGGER,
        "shape": "l",
        "hand_slots": 1,
        "stats": [(STAT_PHYS_ATK, 12), (STAT_SPEED, 10)],
        "base_power": 14,
        "extra_hit_count": 2,
        "extra_hit_damage_fraction": 0.4,
        "skills": ["backstab_iii"],
        "base_price": 500,
        "dir": "weapons",
    },

    # --- Group D: Innate force AoE + granted skill ---

    # 12. Stormcaller — Staff 2H (ACTIVE_TOOL)
    {
        "id": "stormcaller",
        "name": "Stormcaller",
        "description": "A staff crackling with captured lightning. Every strike arcs to all foes, and it commands the storm itself.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_STAFF,
        "shape": "1x4",
        "hand_slots": 2,
        "stats": [(STAT_MAG_ATK, 20)],
        "magical_power": 28,
        "innate_force_aoe": True,
        "skills": ["chain_lightning"],
        "innate_status": "shocked",
        "innate_status_chance": 0.40,
        "base_price": 600,
        "dir": "weapons",
    },

    # --- Group E: On-kill heal ---

    # 13. Harvester's Scythe — Axe 2H (ACTIVE_TOOL)
    {
        "id": "harvesters_scythe",
        "name": "Harvester's Scythe",
        "description": "A wicked scythe that reaps more than grain. Every fallen foe restores the wielder's vitality.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_AXE,
        "shape": "double_scythe",
        "hand_slots": 2,
        "stats": [(STAT_PHYS_ATK, 16)],
        "base_power": 26,
        "on_kill_heal_percent": 0.25,
        "skills": ["power_strike_iii"],
        "base_price": 540,
        "dir": "weapons",
    },

    # --- Group F: Execute threshold ---

    # 14. Mercy's End — Mace (ACTIVE_TOOL)
    {
        "id": "mercys_end",
        "name": "Mercy's End",
        "description": "A mace of cold iron etched with merciless runes. It strikes hardest when the enemy is weakest.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_MACE,
        "shape": "axe",
        "hand_slots": 1,
        "stats": [(STAT_PHYS_ATK, 15)],
        "base_power": 20,
        "granted_effects": ["execute_threshold"],
        "skills": ["shield_bash_iii"],
        "base_price": 480,
        "dir": "weapons",
    },

    # --- Group G: Granted unique skills ---

    # 15. Worldsplitter — Mace 2H (ACTIVE_TOOL)
    {
        "id": "worldsplitter",
        "name": "Worldsplitter",
        "description": "A titanic warhammer that shakes the earth. Its battle cry empowers all who fight alongside the wielder.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_MACE,
        "shape": "bold_u",
        "hand_slots": 2,
        "stats": [(STAT_PHYS_ATK, 25)],
        "base_power": 35,
        "skills": ["warcry", "power_strike_iii"],
        "base_price": 620,
        "dir": "weapons",
    },

    # 16. Whispering Bow — Bow 2H (ACTIVE_TOOL)
    {
        "id": "whispering_bow",
        "name": "Whispering Bow",
        "description": "A bow strung with spectral sinew. Its arrows carry whispered curses that rend the soul.",
        "item_type": ITEM_ACTIVE_TOOL,
        "category": CAT_BOW,
        "shape": "longbow",
        "hand_slots": 2,
        "stats": [(STAT_PHYS_ATK, 14), (STAT_MAG_ATK, 8)],
        "base_power": 18,
        "magical_power": 12,
        "skills": ["soul_rend"],
        "innate_status": "poisoned",
        "innate_status_chance": 0.30,
        "base_price": 560,
        "dir": "weapons",
    },
]


def generate_tres(item: dict) -> str:
    """Generate a .tres file for a legendary item."""
    ext_resources = []
    ext_id_counter = [1]

    def add_ext(res_type: str, path: str) -> str:
        eid = f"{ext_id_counter[0]}_{random_id()}"
        ext_id_counter[0] += 1
        ext_resources.append((res_type, path, eid))
        return eid

    # Always needed
    eid_item_data = add_ext("Script", "res://scripts/resources/item_data.gd")
    eid_stat_mod = add_ext("Script", "res://scripts/resources/stat_modifier.gd")

    # Shape
    shape_key = item["shape"]
    eid_shape = add_ext("Resource", SHAPES[shape_key])

    # Icon
    icon_path = ICONS[item["category"]]
    eid_icon = add_ext("Texture2D", icon_path)

    # Skills (if any)
    skill_eids = []
    eid_skill_data = None
    skills = item.get("skills", [])
    if skills:
        eid_skill_data = add_ext("Script", "res://scripts/resources/skill_data.gd")
        for skill_id in skills:
            eid = add_ext("Resource", SKILLS[skill_id])
            skill_eids.append(eid)

    # Innate status effect
    eid_innate_status = None
    if item.get("innate_status"):
        eid_innate_status = add_ext("Resource", STATUS_EFFECTS[item["innate_status"]])

    # Build ext_resource lines
    ext_lines = []
    for res_type, path, eid in ext_resources:
        ext_lines.append(f'[ext_resource type="{res_type}" path="{path}" id="{eid}"]')

    # Build sub_resource lines (stat modifiers)
    sub_lines = []
    sub_ids = []
    for stat, value in item.get("stats", []):
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
    res_lines.append(f'id = "{item["id"]}"')
    res_lines.append(f'display_name = "{item["name"]}"')
    res_lines.append(f'description = "{item["description"]}"')
    res_lines.append(f'icon = ExtResource("{eid_icon}")')

    if item["item_type"] != ITEM_ACTIVE_TOOL:
        res_lines.append(f"item_type = {item['item_type']}")

    if item["category"] != CAT_SWORD:
        res_lines.append(f"category = {item['category']}")

    res_lines.append(f"rarity = {RARITY_UNIQUE}")

    # Hand slots (weapons only)
    if item.get("hand_slots", 0) > 0:
        res_lines.append(f"hand_slots_required = {item['hand_slots']}")

    # Armor slot
    if item["item_type"] == ITEM_PASSIVE_GEAR:
        res_lines.append(f"armor_slot = {item['category']}")
    elif item["category"] == CAT_SHIELD:
        res_lines.append(f"armor_slot = {CAT_SHIELD}")

    res_lines.append(f'shape = ExtResource("{eid_shape}")')

    # Stat modifiers
    if sub_ids:
        sub_refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)
        res_lines.append(f'stat_modifiers = Array[ExtResource("{eid_stat_mod}")]([{sub_refs}])')

    # Base power
    if item.get("base_power", 0) > 0:
        res_lines.append(f"base_power = {item['base_power']}")

    # Magical power
    if item.get("magical_power", 0) > 0:
        res_lines.append(f"magical_power = {item['magical_power']}")

    # NOTE: granted_skills removed — skills now come from element points system

    # Innate status effect
    if eid_innate_status:
        res_lines.append(f'innate_status_effect = ExtResource("{eid_innate_status}")')
        res_lines.append(f"innate_status_effect_chance = {item['innate_status_chance']}")

    # --- Legendary Effects ---
    granted_effects = item.get("granted_effects", [])
    if granted_effects:
        effects_str = ", ".join(f'"{e}"' for e in granted_effects)
        res_lines.append(f"granted_effects = Array[String]([{effects_str}])")

    if item.get("extra_hit_count", 0) > 0:
        res_lines.append(f"extra_hit_count = {item['extra_hit_count']}")
        res_lines.append(f"extra_hit_damage_fraction = {item['extra_hit_damage_fraction']}")

    if item.get("innate_force_aoe", False):
        res_lines.append("innate_force_aoe = true")

    if item.get("innate_lifesteal_percent", 0) > 0:
        res_lines.append(f"innate_lifesteal_percent = {item['innate_lifesteal_percent']}")

    if item.get("on_kill_heal_percent", 0) > 0:
        res_lines.append(f"on_kill_heal_percent = {item['on_kill_heal_percent']}")

    res_lines.append(f"base_price = {item['base_price']}")

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

    for item in LEGENDARY_ITEMS:
        filename = f"{item['id']}.tres"
        subdir = item["dir"]
        dirpath = os.path.join(PROJECT_ROOT, "data", "items", subdir)
        filepath = os.path.join(dirpath, filename)

        if os.path.exists(filepath) and not force:
            print(f"  SKIP (exists): {subdir}/{filename}")
            skipped += 1
            continue

        if apply:
            os.makedirs(dirpath, exist_ok=True)
            content = generate_tres(item)
            with open(filepath, "w", encoding="utf-8", newline="\n") as f:
                f.write(content)
            print(f"  Created: {subdir}/{filename}")

        total += 1

    print(f"\n{'Created' if apply else 'Would create'}: {total} files")
    if skipped:
        print(f"Skipped (already exist): {skipped}")
    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
