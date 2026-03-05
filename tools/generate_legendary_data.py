#!/usr/bin/env python3
"""Generate the status effect and skill .tres files needed for legendary items.

Creates:
  - data/status_effects/phys_atk_buff.tres
  - data/skills/chain_lightning.tres
  - data/skills/soul_rend.tres
  - data/skills/warcry.tres

Usage:
    python tools/generate_legendary_data.py           # dry run
    python tools/generate_legendary_data.py --apply   # write files
"""

import os
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")

FILES = {}

# === phys_atk_buff.tres ===
# StatusEffectData with +8 PHYS_ATK flat, duration 3, not stackable
# StatusCategory.STAT_MODIFICATION = 2, Stat.PHYSICAL_ATTACK = 4, ModifierType.FLAT = 0
FILES[os.path.join("data", "status_effects", "phys_atk_buff.tres")] = """\
[gd_resource type="Resource" script_class="StatusEffectData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/status_effect_data.gd" id="1_sed"]
[ext_resource type="Script" path="res://scripts/resources/stat_modifier.gd" id="2_sm"]

[sub_resource type="Resource" id="Resource_atkmod"]
script = ExtResource("2_sm")
stat = 4
value = 8.0

[resource]
script = ExtResource("1_sed")
id = "phys_atk_buff"
display_name = "Battle Fury"
description = "Physical Attack increased by 8."
category = 2
duration = 3
stat_modifiers = Array[ExtResource("2_sm")]([SubResource("Resource_atkmod")])
"""

# === chain_lightning.tres ===
# ALL_ENEMIES (4), mag scaling 1.8, MP 12, cooldown 2
FILES[os.path.join("data", "skills", "chain_lightning.tres")] = """\
[gd_resource type="Resource" script_class="SkillData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/skill_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "chain_lightning"
display_name = "Chain Lightning"
description = "Arcs of lightning leap between all enemies, dealing magical damage."
usage = 0
mp_cost = 12
cooldown_turns = 2
target_type = 4
physical_scaling = 0.0
magical_scaling = 1.8
heal_amount = 0
heal_percent = 0.0
"""

# === soul_rend.tres ===
# SINGLE_ENEMY (2), phys scaling 2.0, MP 15, cooldown 2
FILES[os.path.join("data", "skills", "soul_rend.tres")] = """\
[gd_resource type="Resource" script_class="SkillData" load_steps=2 format=3]

[ext_resource type="Script" path="res://scripts/resources/skill_data.gd" id="1"]

[resource]
script = ExtResource("1")
id = "soul_rend"
display_name = "Soul Rend"
description = "Tears at the target's essence, dealing heavy physical damage."
usage = 0
mp_cost = 15
cooldown_turns = 2
target_type = 2
physical_scaling = 2.0
magical_scaling = 0.0
heal_amount = 0
heal_percent = 0.0
"""

# === warcry.tres ===
# ALL_ALLIES (3), no scaling, applies phys_atk_buff, MP 8, cooldown 3
FILES[os.path.join("data", "skills", "warcry.tres")] = """\
[gd_resource type="Resource" script_class="SkillData" load_steps=3 format=3]

[ext_resource type="Script" path="res://scripts/resources/skill_data.gd" id="1"]
[ext_resource type="Resource" path="res://data/status_effects/phys_atk_buff.tres" id="2_buff"]

[resource]
script = ExtResource("1")
id = "warcry"
display_name = "Warcry"
description = "A thunderous battle cry that empowers all allies, boosting their Physical Attack for 3 turns."
usage = 0
mp_cost = 8
cooldown_turns = 3
target_type = 3
physical_scaling = 0.0
magical_scaling = 0.0
applied_statuses = Array[ExtResource("2_buff")]([ExtResource("2_buff")])
heal_amount = 0
heal_percent = 0.0
"""


def main():
    apply = "--apply" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    print(f"=== {mode} ===\n")

    total = 0
    for rel_path, content in FILES.items():
        filepath = os.path.join(PROJECT_ROOT, rel_path)
        os.makedirs(os.path.dirname(filepath), exist_ok=True)

        if apply:
            with open(filepath, "w", encoding="utf-8", newline="\n") as f:
                f.write(content)
            print(f"  Created: {rel_path}")
        else:
            print(f"  Would create: {rel_path}")
        total += 1

    print(f"\n{'Created' if apply else 'Would create'}: {total} files")
    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
