#!/usr/bin/env python3
"""Batch rename display_name fields in all item .tres files.

Strips rarity prefixes (Fine, Superior, Elite, Legendary, Mythic) and
material prefixes (Iron, Leather, Wooden, Oak, Hunting, Battle) so that
items are named by their type alone. Rarity is shown via color + tooltip.

Also applies fantasy name renames for crafted weapons.

Usage:
    python tools/rename_item_display_names.py           # dry run
    python tools/rename_item_display_names.py --apply    # write changes
"""

import os
import re
import sys

ITEMS_DIR = os.path.join(os.path.dirname(__file__), "..", "data", "items")

# Rarity prefixes to strip (order matters — longest first)
RARITY_PREFIXES = ["Legendary ", "Superior ", "Mythic ", "Elite ", "Fine "]

# Material / qualifier prefixes to strip after rarity
MATERIAL_PREFIXES = [
    "Iron ",
    "Leather ",
    "Wooden ",
    "Oak ",
    "Hunting ",
    "Battle ",
    "L-Shaped ",
]

# Fantasy name renames for crafted weapons (applied AFTER prefix stripping)
FANTASY_RENAMES = {
    "Flameblade": "Hellbane",
    "Thunder Mace": "Stormbringer",
    "Vampiric Axe": "Soulreaver",
    "Twin Dagger": "Shadow Blades",
    "Arcane Staff": "Arcanum",
    "Venom Dagger": "Venomfang",
    "Power Gauntlets": "Iron Fists",
    "Swift Treads": "Windwalkers",
}

# Build blueprint rename map: "Blueprint: X" -> "Blueprint: NewX"
BLUEPRINT_RENAMES = {}
for old_name, new_name in FANTASY_RENAMES.items():
    BLUEPRINT_RENAMES[old_name] = new_name


def clean_display_name(name: str) -> str:
    """Strip rarity and material prefixes from a display name."""
    cleaned = name

    # Handle blueprints specially: "Fine Blueprint: Flameblade" -> "Blueprint: Hellbane"
    if "Blueprint: " in cleaned:
        # Strip rarity prefix
        for prefix in RARITY_PREFIXES:
            if cleaned.startswith(prefix):
                cleaned = cleaned[len(prefix):]
                break
        # Apply fantasy renames to the item name after "Blueprint: "
        for old_name, new_name in BLUEPRINT_RENAMES.items():
            cleaned = cleaned.replace(old_name, new_name)
        return cleaned

    # Strip rarity prefix
    for prefix in RARITY_PREFIXES:
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            break

    # Strip material prefix
    for prefix in MATERIAL_PREFIXES:
        if cleaned.startswith(prefix):
            cleaned = cleaned[len(prefix):]
            break

    # Apply fantasy renames
    for old_name, new_name in FANTASY_RENAMES.items():
        if cleaned == old_name:
            cleaned = new_name
            break

    return cleaned


def process_file(filepath: str, apply: bool) -> tuple[str, str] | None:
    """Process a single .tres file. Returns (old, new) name if changed."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    match = re.search(r'display_name\s*=\s*"([^"]*)"', content)
    if not match:
        return None

    old_name = match.group(1)
    new_name = clean_display_name(old_name)

    if old_name == new_name:
        return None

    if apply:
        new_content = content.replace(
            f'display_name = "{old_name}"',
            f'display_name = "{new_name}"',
        )
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(new_content)

    return (old_name, new_name)


def main():
    apply = "--apply" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    print(f"=== {mode} ===\n")

    changes = []
    for root, _dirs, files in os.walk(ITEMS_DIR):
        for fname in sorted(files):
            if not fname.endswith(".tres"):
                continue
            filepath = os.path.join(root, fname)
            result = process_file(filepath, apply)
            if result:
                old, new = result
                rel = os.path.relpath(filepath, ITEMS_DIR)
                changes.append((rel, old, new))

    if not changes:
        print("No changes needed.")
        return

    # Group by directory
    current_dir = None
    for rel, old, new in changes:
        d = os.path.dirname(rel)
        if d != current_dir:
            current_dir = d
            print(f"\n--- {d}/ ---")
        print(f"  {old:40s} -> {new}")

    print(f"\nTotal: {len(changes)} renames")
    if not apply:
        print("\nRun with --apply to write changes.")


if __name__ == "__main__":
    main()
