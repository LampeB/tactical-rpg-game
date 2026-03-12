"""Generate a large test map to stress-test performance.

Creates a MapData .tres file with a big terrain grid, lots of decoration zones,
encounter zones, and scattered elements.

Usage:
    python tools/generate_large_map.py [size]
    size: small=200x125, medium=400x250, large=800x500, huge=1600x1000
    default: medium
"""

import sys
import random
from pathlib import Path

SIZES = {
    "small":  (200, 125),    # 25,000 cells (6x current)
    "medium": (400, 250),    # 100,000 cells (25x current)
    "large":  (800, 500),    # 400,000 cells (100x current)
    "huge":   (1600, 1000),  # 1,600,000 cells (400x current)
}

BLOCK_TYPES = {
    "GRASS": 0, "DIRT": 1, "STONE": 2, "WATER": 3,
    "PATH": 4, "SAND": 5, "DARK_GRASS": 6, "SNOW": 7,
}

DECORATION_SCENES = [
    "res://scenes/world/objects/tree_large.tscn",
    "res://scenes/world/objects/tree_medium.tscn",
    "res://scenes/world/objects/tree_small.tscn",
    "res://scenes/world/objects/rock_large.tscn",
    "res://scenes/world/objects/rock_medium.tscn",
    "res://scenes/world/objects/rock_small.tscn",
    "res://scenes/world/objects/bush_green.tscn",
    "res://scenes/world/objects/grass_tuft.tscn",
    "res://scenes/world/objects/flower_white.tscn",
    "res://scenes/world/objects/flower_yellow.tscn",
]

ENCOUNTER_PATHS = [
    "res://data/encounters/encounter_bats.tres",
    "res://data/encounters/encounter_wolves.tres",
    "res://data/encounters/encounter_spiders.tres",
    "res://data/encounters/encounter_skeletons.tres",
    "res://data/encounters/encounter_bandits.tres",
    "res://data/encounters/encounter_orcs.tres",
    "res://data/encounters/encounter_dark_mages.tres",
    "res://data/encounters/encounter_wraiths.tres",
    "res://data/encounters/encounter_troll.tres",
]


def generate_terrain(width: int, height: int, seed: int = 42) -> list[int]:
    """Generate terrain with biomes, paths, rivers, and lakes."""
    rng = random.Random(seed)
    terrain = [0] * (width * height)  # Default grass

    # Create several biome patches
    num_biomes = (width * height) // 2000
    for _ in range(num_biomes):
        cx = rng.randint(0, width - 1)
        cz = rng.randint(0, height - 1)
        radius = rng.randint(5, 20)
        block = rng.choice([1, 2, 5, 6, 7])  # dirt, stone, sand, dark_grass, snow

        for dz in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                x, z = cx + dx, cz + dz
                if 0 <= x < width and 0 <= z < height:
                    if dx * dx + dz * dz <= radius * radius:
                        terrain[z * width + x] = block

    # Create a river
    river_x = width // 3
    for z in range(height):
        river_x += rng.randint(-1, 1)
        river_x = max(2, min(width - 3, river_x))
        for dx in range(-2, 3):
            x = river_x + dx
            if 0 <= x < width:
                terrain[z * width + x] = 3  # water

    # Create paths
    num_paths = max(3, width // 50)
    for _ in range(num_paths):
        px = rng.randint(10, width - 10)
        pz = rng.randint(10, height - 10)
        length = rng.randint(20, min(80, width // 3))
        dx = rng.choice([-1, 0, 1])
        dz = 1 if dx == 0 else rng.choice([0, 1])
        for step in range(length):
            x = px + dx * step + rng.randint(-1, 1)
            z = pz + dz * step
            if 0 <= x < width and 0 <= z < height:
                terrain[z * width + x] = 4  # path
                if x + 1 < width:
                    terrain[z * width + x + 1] = 4

    # Create a few lakes
    num_lakes = max(2, (width * height) // 20000)
    for _ in range(num_lakes):
        cx = rng.randint(20, width - 20)
        cz = rng.randint(20, height - 20)
        rx = rng.randint(4, 10)
        rz = rng.randint(4, 10)
        for dz in range(-rz, rz + 1):
            for dx in range(-rx, rx + 1):
                x, z = cx + dx, cz + dz
                if 0 <= x < width and 0 <= z < height:
                    if (dx * dx) / (rx * rx) + (dz * dz) / (rz * rz) <= 1.0:
                        terrain[z * width + x] = 3

    # Mountain range border
    for x in range(width):
        for border_z in [0, 1, height - 2, height - 1]:
            terrain[border_z * width + x] = 2
    for z in range(height):
        for border_x in [0, 1, width - 2, width - 1]:
            terrain[z * width + border_x] = 2

    return terrain


def generate_decoration_zones(width: int, height: int, rng: random.Random) -> list[dict]:
    """Generate decoration zones to scatter trees, rocks, etc."""
    zones = []
    # Border zones
    zones.append({"name": "Border Top", "rect": f"Rect2(2, 2, {width - 4}, 3)",
                  "scenes": DECORATION_SCENES[:3], "count": width // 5, "spacing": 4.0})
    zones.append({"name": "Border Bottom", "rect": f"Rect2(2, {height - 5}, {width - 4}, 3)",
                  "scenes": DECORATION_SCENES[:3], "count": width // 5, "spacing": 4.0})

    # Random forest patches
    num_forests = max(5, (width * height) // 5000)
    for i in range(num_forests):
        cx = rng.randint(10, width - 30)
        cz = rng.randint(10, height - 30)
        w = rng.randint(10, 30)
        h = rng.randint(10, 30)
        count = (w * h) // 8
        zones.append({
            "name": f"Forest {i+1}",
            "rect": f"Rect2({cx}, {cz}, {w}, {h})",
            "scenes": DECORATION_SCENES[:6],  # trees and rocks
            "count": count,
            "spacing": 3.0,
        })

    # Flower meadows
    num_meadows = max(3, (width * height) // 15000)
    for i in range(num_meadows):
        cx = rng.randint(10, width - 20)
        cz = rng.randint(10, height - 20)
        w = rng.randint(8, 20)
        h = rng.randint(8, 20)
        zones.append({
            "name": f"Meadow {i+1}",
            "rect": f"Rect2({cx}, {cz}, {w}, {h})",
            "scenes": DECORATION_SCENES[6:],  # bushes, grass, flowers
            "count": (w * h) // 4,
            "spacing": 2.0,
        })

    return zones


def generate_encounters(width: int, height: int, rng: random.Random) -> list[dict]:
    """Generate enemy encounter elements scattered across the map."""
    encounters = []
    # Scale enemy count with map size, but not linearly
    num_enemies = max(10, int((width * height) ** 0.5 / 5))
    safe_margin = 15  # keep away from spawn

    for i in range(num_enemies):
        x = rng.randint(10, width - 10)
        z = rng.randint(10, height - 10)
        # Skip near player spawn
        if abs(x - width // 4) < safe_margin and abs(z - height // 4) < safe_margin:
            continue
        enc = rng.choice(ENCOUNTER_PATHS)
        encounters.append({"id": f"enc_{i}", "x": x, "z": z, "resource": enc})

    return encounters


def write_tres(filepath: str, width: int, height: int):
    """Write the complete .tres MapData resource file."""
    rng = random.Random(42)
    terrain = generate_terrain(width, height)
    deco_zones = generate_decoration_zones(width, height, rng)
    encounters = generate_encounters(width, height, rng)

    lines = []
    # Header
    num_sub = len(deco_zones) + len(encounters) + 1  # +1 for battle area
    lines.append(f'[gd_resource type="Resource" script_class="MapData" format=3]')
    lines.append('')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/battle_area_data.gd" id="1_battle"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/map_encounter_zone.gd" id="1_enczone"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/decoration_zone_data.gd" id="script_deco_zone"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/map_data.gd" id="script_map_data"]')
    lines.append('[ext_resource type="Script" path="res://scripts/resources/map_element.gd" id="script_map_element"]')
    lines.append('')

    # Battle area sub_resource
    lines.append('[sub_resource type="Resource" id="Resource_battle1"]')
    lines.append('script = ExtResource("1_battle")')
    lines.append('area_name = "Battle Area 1"')
    lines.append(f'position = Vector3({width // 2}, 0, {height // 2})')
    lines.append('')

    # Decoration zone sub_resources
    deco_ids = []
    for i, zone in enumerate(deco_zones):
        rid = f"Resource_deco_{i}"
        deco_ids.append(rid)
        scenes_str = ", ".join(f'"{s}"' for s in zone["scenes"])
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append('script = ExtResource("script_deco_zone")')
        lines.append(f'zone_name = "{zone["name"]}"')
        lines.append(f'rect = {zone["rect"]}')
        lines.append(f'decoration_scenes = Array[String]([{scenes_str}])')
        lines.append(f'count = {zone["count"]}')
        lines.append(f'min_spacing = {zone["spacing"]}')
        lines.append('')

    # Encounter element sub_resources
    enc_ids = []
    for enc in encounters:
        rid = f"Resource_{enc['id']}"
        enc_ids.append(rid)
        lines.append(f'[sub_resource type="Resource" id="{rid}"]')
        lines.append('script = ExtResource("script_map_element")')
        lines.append('element_type = 1')
        lines.append(f'position = Vector3({enc["x"]}, 0, {enc["z"]})')
        lines.append(f'resource_id = "{enc["resource"]}"')
        lines.append('')

    # Main resource block
    terrain_str = ", ".join(str(t) for t in terrain)
    elements_str = ", ".join(f'SubResource("{rid}")' for rid in enc_ids)
    deco_str = ", ".join(f'SubResource("{rid}")' for rid in deco_ids)
    spawn_x = width // 4
    spawn_z = height // 4

    lines.append('[resource]')
    lines.append('script = ExtResource("script_map_data")')
    lines.append(f'id = "large_test"')
    lines.append(f'display_name = "Large Test Map ({width}x{height})"')
    lines.append(f'grid_width = {width}')
    lines.append(f'grid_height = {height}')
    lines.append(f'terrain_cells = PackedInt32Array({terrain_str})')
    lines.append(f'player_spawn = Vector3({spawn_x}, 0, {spawn_z})')
    lines.append(f'elements = Array[ExtResource("script_map_element")]([{elements_str}])')
    lines.append(f'decoration_zones = Array[ExtResource("script_deco_zone")]([{deco_str}])')
    lines.append('decoration_seed = 42')
    lines.append(f'battle_areas = Array[ExtResource("1_battle")]([SubResource("Resource_battle1")])')
    lines.append(f'enemy_safe_zones = Array[Rect2]([Rect2({spawn_x - 10}, {spawn_z - 10}, 20, 20)])')
    lines.append('')

    with open(filepath, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(lines))

    cells = width * height
    print(f"Generated: {filepath}")
    print(f"  Grid: {width}x{height} = {cells:,} cells")
    print(f"  Decoration zones: {len(deco_zones)}")
    print(f"  Enemies: {len(encounters)}")
    print(f"  File size: {Path(filepath).stat().st_size // 1024:,} KB")


def main():
    size_name = sys.argv[1] if len(sys.argv) > 1 else "medium"
    if size_name not in SIZES:
        print(f"Unknown size: {size_name}. Use: {', '.join(SIZES.keys())}")
        return

    width, height = SIZES[size_name]
    project_root = Path(__file__).resolve().parent.parent
    output = project_root / "data" / "maps" / "large_test.tres"
    write_tres(str(output), width, height)


if __name__ == "__main__":
    main()
