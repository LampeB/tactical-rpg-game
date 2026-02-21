#!/usr/bin/env python3
"""
Creates simple GDScript files for location interactions.
"""

def create_lake_script():
    return '''extends Area2D

func _ready():
\tcollision_layer = 4
\tcollision_mask = 0

func try_enter():
\tif not GameManager.party:
\t\treturn
\t
\tfor char_id in GameManager.party.roster.keys():
\t\tvar tree = PassiveTreeDatabase.get_passive_tree(char_id)
\t\tvar max_hp = GameManager.party.get_max_hp(char_id, tree)
\t\tvar max_mp = GameManager.party.get_max_mp(char_id, tree)
\t\tGameManager.party.set_current_hp(char_id, max_hp, tree)
\t\tGameManager.party.set_current_mp(char_id, max_mp, tree)
\t
\tEventBus.show_message.emit("The lake's waters restore your party to full health!")
\tSaveManager.save_game()
'''

def create_cave_script():
    return '''extends Area2D

func _ready():
\tcollision_layer = 4
\tcollision_mask = 0

func try_enter():
\tvar flags_to_clear = []
\tfor flag in GameManager.story_flags.keys():
\t\tif flag.begins_with("defeated_enemy_"):
\t\t\tflags_to_clear.append(flag)
\t
\tfor flag in flags_to_clear:
\t\tGameManager.story_flags.erase(flag)
\t
\tSaveManager.save_game()
\tEventBus.show_message.emit("Cave cleared! Enemies will respawn.")
'''

def create_town_script():
    return '''extends Area2D

func _ready():
\tcollision_layer = 4
\tcollision_mask = 0

func try_enter():
\tvar npcs = [
\t\t"Blacksmith - Weapon upgrades",
\t\t"Merchant - Buy and sell items",
\t\t"Innkeeper - Rest and save",
\t\t"Priest - Healing"
\t]
\tEventBus.show_message.emit("Available NPCs:\\n" + "\\n".join(npcs))
'''

if __name__ == "__main__":
    import os

    scripts_dir = "scenes/world"
    os.makedirs(scripts_dir, exist_ok=True)

    with open(f"{scripts_dir}/lake_location.gd", "w") as f:
        f.write(create_lake_script())
    print(f"Created: {scripts_dir}/lake_location.gd")

    with open(f"{scripts_dir}/cave_location.gd", "w") as f:
        f.write(create_cave_script())
    print(f"Created: {scripts_dir}/cave_location.gd")

    with open(f"{scripts_dir}/town_location.gd", "w") as f:
        f.write(create_town_script())
    print(f"Created: {scripts_dir}/town_location.gd")
