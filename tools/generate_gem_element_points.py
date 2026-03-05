#!/usr/bin/env python3
"""Add element_points to gem .tres files and remove granted_skills from conditional rules.

Scans data/items/modifiers/*.tres, identifies gem families, and:
  1. Adds element_points = { ... } to the [resource] section
  2. Removes granted_skills = ... lines from conditional modifier rule sub-resources

Element enum values: FIRE=0, WATER=1, AIR=2, EARTH=3, PLANT=4, LIGHT=5, DARK=6

Usage:
    python tools/generate_gem_element_points.py           # dry run
    python tools/generate_gem_element_points.py --apply   # write files
"""

import os
import re
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
MODIFIERS_DIR = os.path.join(PROJECT_ROOT, "data", "items", "modifiers")

# Element enum values
FIRE = 0
WATER = 1
AIR = 2
EARTH = 3
PLANT = 4
LIGHT = 5
DARK = 6

# Gem family → element points mapping
# Points scale with gem type/family, NOT rarity
GEM_ELEMENT_MAP = {
    "fire_gem":         {FIRE: 3},
    "ice_gem":          {WATER: 3},
    "thunder_gem":      {AIR: 3},
    "poison_gem":       {PLANT: 3},
    "power_gem":        {EARTH: 2},
    "precision_gem":    {LIGHT: 2},
    "devastation_gem":  {DARK: 2},
    "swift_gem":        {AIR: 2},
    "vampiric_gem":     {DARK: 2},
    "mystic_gem":       {LIGHT: 2},
    "ripple_gem":       {WATER: 2},
    "megummy_gem":      {DARK: 3, FIRE: 1},
}


def get_gem_family(filename):
    """Extract gem family from filename (e.g. 'fire_gem_common.tres' → 'fire_gem')."""
    name = filename.replace(".tres", "")
    # Try each known family prefix
    for family in sorted(GEM_ELEMENT_MAP.keys(), key=len, reverse=True):
        if name == family or name.startswith(family + "_"):
            return family
    return None


def format_element_points(points):
    """Format element points as Godot Dictionary string."""
    parts = [f"{k}: {v}" for k, v in sorted(points.items())]
    return "{ " + ", ".join(parts) + " }"


def process_gem_file(filepath, element_points, apply):
    """Process a single gem .tres file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    lines = content.split("\n")
    new_lines = []
    changes = []
    in_resource_section = False

    for line in lines:
        # Track when we enter the main [resource] section
        if line.strip() == "[resource]":
            in_resource_section = True

        # Remove granted_skills from conditional modifier rule sub-resources
        if line.startswith("granted_skills = ") and not in_resource_section:
            changes.append("  Removed granted_skills from conditional rule")
            continue

        # Add element_points before base_price in the main [resource] section
        if in_resource_section and line.startswith("base_price = "):
            pts_str = format_element_points(element_points)
            new_lines.append(f"element_points = {pts_str}")
            changes.append(f"  Added element_points = {pts_str}")

        new_lines.append(line)

    if changes and apply:
        with open(filepath, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(new_lines))

    return changes


def main():
    apply = "--apply" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    print(f"=== {mode} ===\n")

    total_modified = 0
    total_skipped = 0

    for filename in sorted(os.listdir(MODIFIERS_DIR)):
        if not filename.endswith(".tres"):
            continue

        family = get_gem_family(filename)
        if family is None:
            print(f"  SKIP (unknown family): {filename}")
            total_skipped += 1
            continue

        element_points = GEM_ELEMENT_MAP[family]
        filepath = os.path.join(MODIFIERS_DIR, filename)

        # Check if already has element_points
        with open(filepath, "r", encoding="utf-8") as f:
            content = f.read()
        if "element_points = " in content:
            print(f"  SKIP (already has element_points): {filename}")
            total_skipped += 1
            continue

        changes = process_gem_file(filepath, element_points, apply)
        if changes:
            action = "Modified" if apply else "Would modify"
            print(f"  {action}: {filename}")
            for change in changes:
                print(f"    {change}")
            total_modified += 1

    print(f"\n{'Modified' if apply else 'Would modify'}: {total_modified} files")
    if total_skipped:
        print(f"Skipped: {total_skipped} files")

    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
