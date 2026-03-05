#!/usr/bin/env python3
"""Remove granted_skills from all weapon .tres files.

Skills are now unlocked via the element points system, so weapons
no longer grant skills directly.

Usage:
    python tools/generate_weapon_skill_removal.py           # dry run
    python tools/generate_weapon_skill_removal.py --apply   # write files
"""

import os
import sys

PROJECT_ROOT = os.path.join(os.path.dirname(__file__), "..")
WEAPONS_DIR = os.path.join(PROJECT_ROOT, "data", "items", "weapons")


def process_weapon_file(filepath, apply):
    """Remove granted_skills line from a weapon .tres file."""
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()

    if "granted_skills = " not in content:
        return False

    lines = content.split("\n")
    new_lines = []
    removed = False

    for line in lines:
        if line.startswith("granted_skills = "):
            removed = True
            continue
        new_lines.append(line)

    if removed and apply:
        with open(filepath, "w", encoding="utf-8", newline="\n") as f:
            f.write("\n".join(new_lines))

    return removed


def main():
    apply = "--apply" in sys.argv
    mode = "APPLYING" if apply else "DRY RUN"
    print(f"=== {mode} ===\n")

    total_modified = 0
    total_skipped = 0

    for filename in sorted(os.listdir(WEAPONS_DIR)):
        if not filename.endswith(".tres"):
            continue

        filepath = os.path.join(WEAPONS_DIR, filename)
        removed = process_weapon_file(filepath, apply)

        if removed:
            action = "Modified" if apply else "Would modify"
            print(f"  {action}: {filename} (removed granted_skills)")
            total_modified += 1
        else:
            total_skipped += 1

    print(f"\n{'Modified' if apply else 'Would modify'}: {total_modified} files")
    if total_skipped:
        print(f"Skipped (no granted_skills): {total_skipped} files")

    if not apply:
        print("\nRun with --apply to write files.")


if __name__ == "__main__":
    main()
