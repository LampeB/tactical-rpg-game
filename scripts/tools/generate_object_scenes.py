#!/usr/bin/env python3
"""
Auto-generate .tscn scene files for object sprites.
"""

import os
import hashlib
from PIL import Image

SPRITES_DIR = "assets/sprites/objects/placeholders"
SCENES_DIR = "scenes/world/objects"

# Object configurations
CONFIGS = {
    # Trees - collision at base
    "tree_small": {"collision": "circle", "radius": 6, "has_collision": True},
    "tree_medium": {"collision": "circle", "radius": 7, "has_collision": True},
    "tree_large": {"collision": "circle", "radius": 9, "has_collision": True},

    # Rocks - collision
    "rock_small": {"collision": "circle", "radius": 5, "has_collision": True},
    "rock_medium": {"collision": "circle", "radius": 7, "has_collision": True},
    "rock_large": {"collision": "circle", "radius": 10, "has_collision": True},

    # Bush - collision
    "bush": {"collision": "circle", "radius": 6, "has_collision": True},

    # Sign - collision
    "sign": {"collision": "rect", "width": 10, "height": 8, "has_collision": True},

    # Fence - collision
    "fence": {"collision": "rect", "width": 14, "height": 6, "has_collision": True},

    # Decorative - no collision
    "flower_red": {"has_collision": False},
    "flower_yellow": {"has_collision": False},
    "grass_tuft": {"has_collision": False},
}

def generate_uid():
    """Generate a unique UID for Godot resources."""
    import random
    return f"uid://{''.join(random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=13))}"

def get_image_size(filepath):
    """Get image dimensions."""
    with Image.open(filepath) as img:
        return img.size

def create_scene_with_collision(name, sprite_path, width, height, config):
    """Create a scene file with StaticBody2D and collision."""
    y_sort_origin = height // 2
    collision_y = height // 2 - 2

    # Collision shape
    if config.get("collision") == "circle":
        radius = config.get("radius", 8)
        collision_shape = f"""[sub_resource type="CircleShape2D" id="CircleShape2D_{name}"]
radius = {radius}.0"""
        shape_ref = f'SubResource("CircleShape2D_{name}")'

    else:  # rectangle
        w = config.get("width", width)
        h = config.get("height", height // 2)
        collision_shape = f"""[sub_resource type="RectangleShape2D" id="RectangleShape2D_{name}"]
size = Vector2({w}, {h})"""
        shape_ref = f'SubResource("RectangleShape2D_{name}")'

    scene_content = f"""[gd_scene load_steps=3 format=3 uid="{generate_uid()}"]

[ext_resource type="Texture2D" path="res://{sprite_path}" id="1"]

{collision_shape}

[node name="{name.title().replace('_', '')}" type="StaticBody2D"]
y_sort_origin = {y_sort_origin}
collision_mask = 0

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("1")

[node name="CollisionShape2D" type="CollisionShape2D" parent="."]
position = Vector2(0, {collision_y})
shape = {shape_ref}
"""
    return scene_content

def create_scene_no_collision(name, sprite_path, width, height):
    """Create a scene file without collision (decorative)."""
    y_sort_origin = height // 2

    scene_content = f"""[gd_scene load_steps=2 format=3 uid="{generate_uid()}"]

[ext_resource type="Texture2D" path="res://{sprite_path}" id="1"]

[node name="{name.title().replace('_', '')}" type="Node2D"]
y_sort_origin = {y_sort_origin}

[node name="Sprite2D" type="Sprite2D" parent="."]
texture = ExtResource("1")
"""
    return scene_content

def main():
    print("Generating .tscn scene files...")

    os.makedirs(SCENES_DIR, exist_ok=True)

    for name, config in CONFIGS.items():
        sprite_file = f"{SPRITES_DIR}/{name}.png"
        scene_file = f"{SCENES_DIR}/{name}.tscn"

        if not os.path.exists(sprite_file):
            print(f"Warning: {sprite_file} not found, skipping...")
            continue

        # Get image dimensions
        width, height = get_image_size(sprite_file)

        # Generate scene content
        if config.get("has_collision", False):
            content = create_scene_with_collision(name, sprite_file, width, height, config)
        else:
            content = create_scene_no_collision(name, sprite_file, width, height)

        # Write scene file
        with open(scene_file, 'w') as f:
            f.write(content)

        print(f"Created: {scene_file}")

    print(f"\nDone! Created {len(CONFIGS)} scene files in {SCENES_DIR}/")

if __name__ == "__main__":
    main()
