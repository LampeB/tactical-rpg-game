#!/usr/bin/env python3
"""
Exports the current hardcoded overworld data as a MapData .tres resource file.
Run from project root: python tools/export_overworld_map.py
Generates: data/maps/overworld.tres
"""
import os

# === Terrain logic (mirrors overworld.gd::_get_terrain_block) ===
# Block enum: GRASS=0, DIRT=1, STONE=2, WATER=3, PATH=4, SAND=5, DARK_GRASS=6, SNOW=7
GRASS, DIRT, STONE, WATER, PATH, SAND, DARK_GRASS, SNOW = range(8)

WIDTH = 80
HEIGHT = 50


def get_terrain_block(x: int, z: int) -> int:
    # Small pond in eastern wilds
    if 56 <= x <= 59 and 21 <= z <= 24:
        return WATER
    # Sand beach around pond
    if 55 <= x <= 60 and 20 <= z <= 25:
        return SAND
    # Stream from pond toward cave (z:18-21, x:50->55)
    if 50 <= x <= 55 and 19 <= z <= 20:
        return WATER
    # Stream bank
    if 49 <= x <= 56 and 18 <= z <= 21:
        return SAND
    # Road from town to cave (z:15-17, x:20->36)
    if 20 <= x <= 36 and 15 <= z <= 17:
        return PATH
    # Town main street (x:8-11)
    if 8 <= x <= 11 and 3 <= z <= 18:
        return PATH
    # Town cross street (z:10-11, x:5->18)
    if 5 <= x <= 18 and 10 <= z <= 11:
        return PATH
    # Town square (x:8-12, z:3-6)
    if 8 <= x <= 12 and 3 <= z <= 6:
        return PATH
    # Cave area (x:33-50, z:10-25)
    if 33 <= x <= 50 and 10 <= z <= 25:
        return STONE
    # Snow-capped peaks (northeast corner)
    if 65 <= x <= 78 and 2 <= z <= 10:
        return SNOW
    # Mountain foothills
    if 60 <= x <= 78 and 2 <= z <= 12:
        return STONE
    # Town area (x:3-20, z:3-18)
    if 3 <= x <= 20 and 3 <= z <= 18:
        return DIRT
    # Forest West (x:0-15, z:20-48)
    if x <= 15 and 20 <= z <= 48:
        return DARK_GRASS
    # Forest North (x:15-65, z:35-48)
    if 15 <= x <= 65 and 35 <= z <= 48:
        return DARK_GRASS
    # Default
    return GRASS


def build_terrain_cells() -> list[int]:
    cells = []
    for z in range(HEIGHT):
        for x in range(WIDTH):
            cells.append(get_terrain_block(x, z))
    return cells


# === Elements (from overworld.tscn) ===

ELEMENTS = [
    # Locations
    {
        "type": 3,  # LOCATION
        "pos": (9, 0, 6),
        "resource_id": "res://data/locations/town_start.tres",
    },
    {
        "type": 3,  # LOCATION
        "pos": (38, 0, 20),
        "resource_id": "res://data/locations/dungeon_cave.tres",
    },
    # NPCs
    {
        "type": 0,  # NPC
        "pos": (18, 0, 10),
        "resource_id": "blacksmith",
    },
    {
        "type": 0,  # NPC
        "pos": (9, 0, 10),
        "resource_id": "merchant",
    },
    {
        "type": 0,  # NPC
        "pos": (13, 0, 15),
        "resource_id": "weaver",
    },
    {
        "type": 0,  # NPC
        "pos": (13, 0, 10),
        "resource_id": "doctor",
    },
    # Enemies
    {
        "type": 1,  # ENEMY
        "pos": (19, 0, 12),
        "resource_id": "res://data/encounters/encounter_slimes.tres",
    },
    {
        "type": 1,  # ENEMY
        "pos": (25, 0, 19),
        "resource_id": "res://data/encounters/encounter_slimes.tres",
    },
    {
        "type": 1,  # ENEMY
        "pos": (16, 0, 22),
        "resource_id": "res://data/encounters/encounter_goblins.tres",
    },
    {
        "type": 1,  # ENEMY
        "pos": (34, 0, 12),
        "resource_id": "res://data/encounters/encounter_goblins.tres",
    },
    {
        "type": 1,  # ENEMY
        "pos": (41, 0, 22),
        "resource_id": "res://data/encounters/encounter_slimes.tres",
    },
    {
        "type": 1,  # ENEMY
        "pos": (30, 0, 11),
        "resource_id": "res://data/encounters/encounter_minotaur.tres",
    },
    # Chests
    {
        "type": 2,  # CHEST
        "pos": (22, 0, 15),
        "resource_id": "test_chest_wooden",
    },
    # Signs
    {
        "type": 5,  # SIGN
        "pos": (9, 0, 3.5),
        "resource_id": "res://scenes/world/objects/sign.tscn",
    },
    {
        "type": 5,  # SIGN
        "pos": (36, 0, 20),
        "resource_id": "res://scenes/world/objects/sign.tscn",
    },
    {
        "type": 5,  # SIGN
        "pos": (20, 0, 17),
        "resource_id": "res://scenes/world/objects/sign.tscn",
    },
    # Houses — town buildings
    {
        "type": 4,  # DECORATION
        "pos": (5, 0, 8),
        "rotation_y": 1.5707963,  # PI/2 — facing street
        "resource_id": "res://scenes/world/objects/house_blue.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (15, 0, 6),
        "resource_id": "res://scenes/world/objects/house_red.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (16, 0, 14),
        "resource_id": "res://scenes/world/objects/house_green.tscn",
    },
    # Lampposts — along town main street
    {
        "type": 4,  # DECORATION
        "pos": (9.5, 0, 5),
        "resource_id": "res://scenes/world/objects/lamppost.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (9.5, 0, 9),
        "resource_id": "res://scenes/world/objects/lamppost.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (9.5, 0, 13),
        "resource_id": "res://scenes/world/objects/lamppost.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (9.5, 0, 17),
        "resource_id": "res://scenes/world/objects/lamppost.tscn",
    },
    # Campfires
    {
        "type": 4,  # DECORATION
        "pos": (10, 0, 4.5),
        "resource_id": "res://scenes/world/objects/campfire.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (28, 0, 16),
        "resource_id": "res://scenes/world/objects/campfire.tscn",
    },
    {
        "type": 4,  # DECORATION
        "pos": (45, 0, 18),
        "resource_id": "res://scenes/world/objects/campfire.tscn",
    },
]

# Town fences along south edge (z=3, x:4->20, spacing=1.5)
x = 4.0
while x <= 20.0:
    ELEMENTS.append({
        "type": 6,  # FENCE
        "pos": (x, 0, 3.0),
        "rotation_y": 0.0,
        "resource_id": "res://scenes/world/objects/fence.tscn",
    })
    x += 1.5

# Town fences along west edge (x=3, z:4->18, spacing=1.5, rotation=PI/2)
z = 4.0
while z <= 18.0:
    ELEMENTS.append({
        "type": 6,  # FENCE
        "pos": (3.0, 0, z),
        "rotation_y": 1.5707963,  # PI/2
        "resource_id": "res://scenes/world/objects/fence.tscn",
    })
    z += 1.5

# Town fences along east edge (x=20, z:4->18, spacing=1.5, rotation=PI/2)
z = 4.0
while z <= 18.0:
    ELEMENTS.append({
        "type": 6,  # FENCE
        "pos": (20.0, 0, z),
        "rotation_y": 1.5707963,  # PI/2
        "resource_id": "res://scenes/world/objects/fence.tscn",
    })
    z += 1.5

# Town fences along north edge (z=18, x:4->20, spacing=1.5)
x = 4.0
while x <= 20.0:
    ELEMENTS.append({
        "type": 6,  # FENCE
        "pos": (x, 0, 18.0),
        "rotation_y": 0.0,
        "resource_id": "res://scenes/world/objects/fence.tscn",
    })
    x += 1.5


# === Decoration zones (from overworld.gd::_populate_world) ===

SCENE_PATH = "res://scenes/world/objects/"
DECORATION_ZONES = [
    # === Map borders — dense tree walls ===
    {
        "name": "Border Top",
        "rect": (1, 1, 78, 2),
        "scenes": [f"{SCENE_PATH}tree_large.tscn", f"{SCENE_PATH}tree_medium.tscn"],
        "count": 18,
        "spacing": 4.5,
    },
    {
        "name": "Border Bottom",
        "rect": (1, 47, 78, 2),
        "scenes": [f"{SCENE_PATH}tree_large.tscn", f"{SCENE_PATH}tree_medium.tscn"],
        "count": 18,
        "spacing": 4.5,
    },
    {
        "name": "Border Left",
        "rect": (1, 3, 2, 44),
        "scenes": [f"{SCENE_PATH}tree_large.tscn"],
        "count": 10,
        "spacing": 4.5,
    },
    {
        "name": "Border Right",
        "rect": (77, 3, 2, 44),
        "scenes": [f"{SCENE_PATH}tree_large.tscn"],
        "count": 10,
        "spacing": 4.5,
    },
    # === Forest West — dense mixed forest ===
    {
        "name": "Forest West Trees",
        "rect": (0, 20, 15, 28),
        "scenes": [
            f"{SCENE_PATH}tree_large.tscn",
            f"{SCENE_PATH}tree_large.tscn",
            f"{SCENE_PATH}tree_medium.tscn",
            f"{SCENE_PATH}tree_small.tscn",
        ],
        "count": 30,
        "spacing": 3.0,
    },
    {
        "name": "Forest West Undergrowth",
        "rect": (0, 20, 15, 28),
        "scenes": [
            f"{SCENE_PATH}bush.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}flower_white.tscn",
        ],
        "count": 20,
        "spacing": 2.0,
    },
    # === Forest North — mixed forest ===
    {
        "name": "Forest North Trees",
        "rect": (15, 35, 50, 13),
        "scenes": [
            f"{SCENE_PATH}tree_large.tscn",
            f"{SCENE_PATH}tree_medium.tscn",
            f"{SCENE_PATH}tree_small.tscn",
        ],
        "count": 30,
        "spacing": 3.0,
    },
    {
        "name": "Forest North Undergrowth",
        "rect": (15, 35, 50, 13),
        "scenes": [
            f"{SCENE_PATH}bush.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}rock_small.tscn",
        ],
        "count": 18,
        "spacing": 2.5,
    },
    # === Town — gardens and flowers ===
    {
        "name": "Town Gardens",
        "rect": (4, 4, 15, 14),
        "scenes": [
            f"{SCENE_PATH}flower_red.tscn",
            f"{SCENE_PATH}flower_yellow.tscn",
            f"{SCENE_PATH}flower_white.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
        ],
        "count": 30,
        "spacing": 1.5,
    },
    {
        "name": "Town Trees",
        "rect": (4, 4, 15, 14),
        "scenes": [
            f"{SCENE_PATH}tree_small.tscn",
            f"{SCENE_PATH}tree_medium.tscn",
        ],
        "count": 6,
        "spacing": 4.0,
    },
    # === Road — scattered vegetation ===
    {
        "name": "Road Edges",
        "rect": (20, 12, 18, 12),
        "scenes": [
            f"{SCENE_PATH}bush.tscn",
            f"{SCENE_PATH}flower_red.tscn",
            f"{SCENE_PATH}flower_yellow.tscn",
            f"{SCENE_PATH}flower_white.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
        ],
        "count": 20,
        "spacing": 2.0,
    },
    # === Cave Area — rocky terrain ===
    {
        "name": "Cave Rocks",
        "rect": (33, 10, 17, 15),
        "scenes": [
            f"{SCENE_PATH}rock_large.tscn",
            f"{SCENE_PATH}rock_medium.tscn",
            f"{SCENE_PATH}rock_small.tscn",
            f"{SCENE_PATH}rock_small.tscn",
        ],
        "count": 20,
        "spacing": 2.0,
    },
    {
        "name": "Cave Sparse Trees",
        "rect": (33, 10, 17, 15),
        "scenes": [
            f"{SCENE_PATH}tree_small.tscn",
            f"{SCENE_PATH}bush.tscn",
        ],
        "count": 8,
        "spacing": 3.5,
    },
    # === Eastern Wilds — open grassland with scattered features ===
    {
        "name": "Eastern Wilds Trees",
        "rect": (50, 2, 28, 32),
        "scenes": [
            f"{SCENE_PATH}tree_medium.tscn",
            f"{SCENE_PATH}tree_small.tscn",
            f"{SCENE_PATH}tree_large.tscn",
        ],
        "count": 18,
        "spacing": 5.0,
    },
    {
        "name": "Eastern Wilds Ground",
        "rect": (50, 2, 28, 32),
        "scenes": [
            f"{SCENE_PATH}rock_medium.tscn",
            f"{SCENE_PATH}rock_small.tscn",
            f"{SCENE_PATH}bush.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}flower_yellow.tscn",
        ],
        "count": 25,
        "spacing": 3.0,
    },
    # === Pond area — lush vegetation ===
    {
        "name": "Pond Edge",
        "rect": (53, 19, 9, 8),
        "scenes": [
            f"{SCENE_PATH}flower_red.tscn",
            f"{SCENE_PATH}flower_yellow.tscn",
            f"{SCENE_PATH}flower_white.tscn",
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}bush.tscn",
        ],
        "count": 15,
        "spacing": 1.5,
    },
    # === Central grasslands — between town and cave ===
    {
        "name": "Central Grasslands",
        "rect": (20, 20, 15, 15),
        "scenes": [
            f"{SCENE_PATH}grass_tuft.tscn",
            f"{SCENE_PATH}flower_red.tscn",
            f"{SCENE_PATH}flower_white.tscn",
            f"{SCENE_PATH}bush.tscn",
            f"{SCENE_PATH}tree_small.tscn",
        ],
        "count": 15,
        "spacing": 2.5,
    },
]


def format_packed_int32_array(cells: list[int]) -> str:
    """Format cells as Godot PackedInt32Array."""
    return "PackedInt32Array(" + ", ".join(str(c) for c in cells) + ")"


def write_tres(path: str) -> None:
    """Write the complete .tres file."""
    terrain = build_terrain_cells()

    # Count sub-resources needed
    sub_id = 1
    element_ids = []
    zone_ids = []

    for _ in ELEMENTS:
        element_ids.append(sub_id)
        sub_id += 1

    for _ in DECORATION_ZONES:
        zone_ids.append(sub_id)
        sub_id += 1

    lines = []

    # Header
    lines.append(f'[gd_resource type="Resource" script_class="MapData" load_steps={sub_id + 1} format=3]')
    lines.append("")

    # External resources
    lines.append('[ext_resource type="Script" path="res://scripts/resources/map_data.gd" id="script_map_data"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/map_element.gd" id="script_map_element"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/decoration_zone_data.gd" id="script_deco_zone"]')
    lines.append("")

    # Sub-resources: MapElements
    for i, elem in enumerate(ELEMENTS):
        sid = element_ids[i]
        lines.append(f'[sub_resource type="Resource" id="{sid}"]')
        lines.append('script = ExtResource("script_map_element")')
        lines.append(f'element_type = {elem["type"]}')
        px, py, pz = elem["pos"]
        lines.append(f'position = Vector3({px}, {py}, {pz})')
        rot = elem.get("rotation_y", 0.0)
        if rot != 0.0:
            lines.append(f'rotation_y = {rot}')
        lines.append(f'resource_id = "{elem["resource_id"]}"')

        # Enemy defaults
        if elem["type"] == 1:  # ENEMY
            ec = elem.get("enemy_color", (1, 0.3, 0.3))
            if isinstance(ec, tuple):
                lines.append(f'enemy_color = Color({ec[0]}, {ec[1]}, {ec[2]}, 1)')
            lines.append(f'patrol_distance = {elem.get("patrol_distance", 3.0)}')

        lines.append("")

    # Sub-resources: DecorationZoneData
    for i, zone in enumerate(DECORATION_ZONES):
        sid = zone_ids[i]
        rx, ry, rw, rh = zone["rect"]
        scenes_str = ", ".join(f'"{s}"' for s in zone["scenes"])
        lines.append(f'[sub_resource type="Resource" id="{sid}"]')
        lines.append('script = ExtResource("script_deco_zone")')
        lines.append(f'zone_name = "{zone["name"]}"')
        lines.append(f'rect = Rect2({rx}, {ry}, {rw}, {rh})')
        lines.append(f'decoration_scenes = Array[String]([{scenes_str}])')
        lines.append(f'count = {zone["count"]}')
        lines.append(f'min_spacing = {zone["spacing"]}')
        lines.append("")

    # Main resource
    lines.append('[resource]')
    lines.append('script = ExtResource("script_map_data")')
    lines.append('id = "overworld"')
    lines.append('display_name = "Overworld"')
    lines.append(f'grid_width = {WIDTH}')
    lines.append(f'grid_height = {HEIGHT}')
    lines.append(f'terrain_cells = {format_packed_int32_array(terrain)}')
    lines.append('player_spawn = Vector3(30, 0, 17)')

    # Elements array
    elem_refs = ", ".join(f'SubResource("{eid}")' for eid in element_ids)
    lines.append(f'elements = Array[Resource]([{elem_refs}])')

    # Decoration zones array
    zone_refs = ", ".join(f'SubResource("{zid}")' for zid in zone_ids)
    lines.append(f'decoration_zones = Array[Resource]([{zone_refs}])')

    lines.append('decoration_seed = 42')

    # Encounter zones (none currently)
    lines.append('encounter_zones = Array[Resource]([])')

    # Connections (none currently)
    lines.append('connections = Array[Resource]([])')

    # Enemy safe zones
    lines.append('enemy_safe_zones = Array[Rect2]([Rect2(2, 2, 19, 17)])')

    lines.append("")

    content = "\n".join(lines)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", newline="\n") as f:
        f.write(content)

    print(f"Wrote {path}")
    print(f"  Terrain cells: {len(terrain)}")
    print(f"  Elements: {len(ELEMENTS)}")
    print(f"  Decoration zones: {len(DECORATION_ZONES)}")


if __name__ == "__main__":
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir)
    output_path = os.path.join(project_root, "data", "maps", "overworld.tres")
    write_tres(output_path)
