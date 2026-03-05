#!/usr/bin/env python3
"""Generate the central element skill unlock table.

Creates data/element_skill_table.tres — an ElementSkillTable resource
that maps element point thresholds to skill unlocks.

Element enum values: FIRE=0, WATER=1, AIR=2, EARTH=3, PLANT=4, LIGHT=5, DARK=6

Usage:
    python tools/generate_element_skill_table.py           # dry run
    python tools/generate_element_skill_table.py --apply   # write file
"""

import os
import random
import string
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
OUTPUT_PATH = os.path.join(PROJECT_ROOT, "data", "element_skill_table.tres")

# Element enum values
FIRE = 0
WATER = 1
AIR = 2
EARTH = 3
PLANT = 4
LIGHT = 5
DARK = 6

# Skill entries: (skill_id, skill_path, required_points_dict)
ENTRIES = [
    # === FIRE (from fire_gem: 3 per gem) ===
    ("fire_bolt", "res://data/skills/fire_bolt.tres", {FIRE: 3}),
    ("fire_bolt_ii", "res://data/skills/fire_bolt_ii.tres", {FIRE: 6}),
    ("fire_bolt_iii", "res://data/skills/fire_bolt_iii.tres", {FIRE: 9}),

    # === WATER (from ice_gem: 3, ripple_gem: 2) ===
    ("ice_shard", "res://data/skills/ice_shard.tres", {WATER: 3}),
    ("ice_shard_ii", "res://data/skills/ice_shard_ii.tres", {WATER: 6}),
    ("ice_shard_iii", "res://data/skills/ice_shard_iii.tres", {WATER: 9}),

    # === AIR (from thunder_gem: 3, swift_gem: 2) ===
    ("thunder_bolt", "res://data/skills/thunder_bolt.tres", {AIR: 3}),

    # === EARTH (from power_gem: 2) — physical melee ===
    ("slash", "res://data/skills/slash.tres", {EARTH: 2}),
    ("slash_ii", "res://data/skills/slash_ii.tres", {EARTH: 4}),
    ("slash_iii", "res://data/skills/slash_iii.tres", {EARTH: 6}),
    ("power_strike", "res://data/skills/power_strike.tres", {EARTH: 3}),
    ("power_strike_ii", "res://data/skills/power_strike_ii.tres", {EARTH: 5}),
    ("power_strike_iii", "res://data/skills/power_strike_iii.tres", {EARTH: 8}),
    ("shield_bash", "res://data/skills/shield_bash.tres", {EARTH: 2}),
    ("shield_bash_ii", "res://data/skills/shield_bash_ii.tres", {EARTH: 4}),
    ("shield_bash_iii", "res://data/skills/shield_bash_iii.tres", {EARTH: 7}),

    # === DARK (from devastation_gem: 2, vampiric_gem: 2, megummy: 3) — rogue ===
    ("backstab", "res://data/skills/backstab.tres", {DARK: 2}),
    ("backstab_ii", "res://data/skills/backstab_ii.tres", {DARK: 4}),
    ("backstab_iii", "res://data/skills/backstab_iii.tres", {DARK: 7}),

    # === LIGHT (from precision_gem: 2, mystic_gem: 2) — healing ===
    ("heal_minor", "res://data/skills/heal_minor.tres", {LIGHT: 2}),
    ("heal_light", "res://data/skills/heal_light.tres", {LIGHT: 4}),
    ("heal_moderate", "res://data/skills/heal_moderate.tres", {LIGHT: 6}),
    ("heal_major", "res://data/skills/heal_major.tres", {LIGHT: 8}),
    ("heal_superior", "res://data/skills/heal_superior.tres", {LIGHT: 10}),

    # === Multi-element (advanced/legendary) ===
    ("chain_lightning", "res://data/skills/chain_lightning.tres", {AIR: 6, FIRE: 3}),
    ("soul_rend", "res://data/skills/soul_rend.tres", {DARK: 5, EARTH: 3}),
    ("warcry", "res://data/skills/warcry.tres", {EARTH: 5, LIGHT: 3}),
    ("explosion", "res://data/skills/explosion.tres", {FIRE: 6, DARK: 3}),
]


def random_id(length=5):
    chars = string.ascii_lowercase + string.digits
    return "".join(random.choice(chars) for _ in range(length))


def generate_tres():
    ext_id_counter = [1]
    ext_resources = []

    def add_ext(res_type, path):
        eid = f"{ext_id_counter[0]}_{random_id()}"
        ext_id_counter[0] += 1
        ext_resources.append((res_type, path, eid))
        return eid

    # Scripts
    eid_table = add_ext("Script", "res://scripts/resources/element_skill_table.gd")
    eid_entry = add_ext("Script", "res://scripts/resources/element_skill_entry.gd")

    # Skill resources
    skill_eids = []
    for skill_id, skill_path, _req in ENTRIES:
        eid = add_ext("Resource", skill_path)
        skill_eids.append(eid)

    # Build ext_resource lines
    ext_lines = []
    for res_type, path, eid in ext_resources:
        ext_lines.append(f'[ext_resource type="{res_type}" path="{path}" id="{eid}"]')

    # Build sub_resources (one per entry)
    sub_lines = []
    sub_ids = []
    for i, (skill_id, _path, req_points) in enumerate(ENTRIES):
        sid = f"Resource_{random_id()}"
        sub_ids.append(sid)
        sub_lines.append(f'[sub_resource type="Resource" id="{sid}"]')
        sub_lines.append(f'script = ExtResource("{eid_entry}")')
        sub_lines.append(f'skill = ExtResource("{skill_eids[i]}")')
        # Format required_points as Godot Dictionary
        pts_parts = [f"{k}: {v}" for k, v in sorted(req_points.items())]
        pts_str = "{ " + ", ".join(pts_parts) + " }"
        sub_lines.append(f"required_points = {pts_str}")
        sub_lines.append("")

    # Build [resource] section
    entry_refs = ", ".join(f'SubResource("{sid}")' for sid in sub_ids)

    lines = ['[gd_resource type="Resource" script_class="ElementSkillTable" format=3]', ""]
    lines.extend(ext_lines)
    lines.append("")
    lines.extend(sub_lines)
    lines.append("[resource]")
    lines.append(f'script = ExtResource("{eid_table}")')
    lines.append(f'entries = Array[ExtResource("{eid_entry}")]([{entry_refs}])')
    lines.append("")

    return "\n".join(lines)


def main():
    apply = "--apply" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    print(f"=== {mode} ===\n")
    print(f"  Element Skill Table: {len(ENTRIES)} entries")
    print()

    for skill_id, _path, req in ENTRIES:
        elem_names = {0: "FIRE", 1: "WATER", 2: "AIR", 3: "EARTH", 4: "PLANT", 5: "LIGHT", 6: "DARK"}
        req_str = ", ".join(f"{elem_names[k]}: {v}" for k, v in sorted(req.items()))
        print(f"    {skill_id:25s} -> {req_str}")

    print()

    if apply:
        os.makedirs(os.path.dirname(OUTPUT_PATH), exist_ok=True)
        content = generate_tres()
        with open(OUTPUT_PATH, "w", encoding="utf-8", newline="\n") as f:
            f.write(content)
        print(f"  Created: data/element_skill_table.tres")
    else:
        print(f"  Would create: data/element_skill_table.tres")
        print("\nRun with --apply to write file.")


if __name__ == "__main__":
    main()
