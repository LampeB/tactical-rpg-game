#!/usr/bin/env python3
"""
Checks all gem files for common issues.
"""
import os
import re

def check_gem_file(filepath):
    """Check a single gem file for issues."""
    issues = []

    with open(filepath, 'r') as f:
        content = f.read()

    filename = os.path.basename(filepath)

    # Check if modifier_reach is set
    if 'modifier_reach = 1' not in content and 'modifier_reach = 2' not in content:
        issues.append(f"  [!]Missing modifier_reach")

    # Check elemental gems (should have override_damage_type = true)
    elemental_gems = ['fire_gem', 'ice_gem', 'thunder_gem', 'poison_gem']
    is_elemental = any(gem in filename for gem in elemental_gems)

    if is_elemental:
        if 'override_damage_type = false' in content:
            issues.append(f"  [!]Elemental gem should have override_damage_type = true")
        elif 'override_damage_type = true' not in content:
            issues.append(f"  [!]Missing override_damage_type declaration")

    # Check rarity is set
    if 'rarity = 0' not in content and 'rarity = 1' not in content and 'rarity = 2' not in content:
        issues.append(f"  [!]Missing rarity field")

    return issues

def main():
    gems_dir = "data/items/modifiers"
    print("Checking all gem files for issues...\n")

    all_ok = True
    for filename in sorted(os.listdir(gems_dir)):
        if filename.endswith('.tres'):
            filepath = os.path.join(gems_dir, filename)
            issues = check_gem_file(filepath)

            if issues:
                all_ok = False
                print(f"[ISSUE] {filename}")
                for issue in issues:
                    print(issue)
                print()
            else:
                print(f"[OK] {filename}")

    if all_ok:
        print("\nAll gems are configured correctly!")
    else:
        print("\n[WARNING] Some gems have issues that need fixing")

if __name__ == "__main__":
    main()
