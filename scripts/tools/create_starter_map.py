#!/usr/bin/env python3
"""
Generate a starter overworld map with enclosed area.
Creates a rectangular area surrounded by trees/rocks with town, cave, and lake inside.
"""

def generate_uid():
    """Generate a unique UID for Godot resources."""
    import random
    return f"uid://{''.join(random.choices('abcdefghijklmnopqrstuvwxyz0123456789', k=13))}"

def create_object_instance(scene_path, name, position_x, position_y, unique_id=None):
    """Generate a scene instance node."""
    uid_str = f' unique_id={unique_id}' if unique_id else ''
    return f'''[node name="{name}" parent="Objects" instance=ExtResource("{scene_path}"){uid_str}]
position = Vector2({position_x}, {position_y})
'''

def main():
    print("Generating starter map...")

    # Map dimensions
    MAP_WIDTH = 1920
    MAP_HEIGHT = 1080
    CENTER_X = MAP_WIDTH // 2
    CENTER_Y = MAP_HEIGHT // 2

    # Border margin
    MARGIN = 100
    SPACING = 30  # Reduced from 50 to make border denser

    # Resource paths (we'll assign ExtResource IDs)
    resources = {
        "tree_small": 1,
        "tree_medium": 2,
        "tree_large": 3,
        "rock_small": 4,
        "rock_medium": 5,
        "rock_large": 6,
        "roaming_enemy": 7,
    }

    scene_content = f'''[gd_scene load_steps=15 format=3 uid="{generate_uid()}"]

[ext_resource type="PackedScene" uid="uid://b8ncvuslxxv0r" path="res://scenes/world/objects/tree_small.tscn" id="1"]
[ext_resource type="PackedScene" uid="uid://cmuwryjy0xac6" path="res://scenes/world/objects/tree_medium.tscn" id="2"]
[ext_resource type="PackedScene" uid="uid://ckn3yehsixumh" path="res://scenes/world/objects/tree_large.tscn" id="3"]
[ext_resource type="PackedScene" uid="uid://dmiwvb7lskbbc" path="res://scenes/world/objects/rock_small.tscn" id="4"]
[ext_resource type="PackedScene" uid="uid://brnxqdp8m40qy" path="res://scenes/world/objects/rock_medium.tscn" id="5"]
[ext_resource type="PackedScene" uid="uid://dggbxhe11lh1u" path="res://scenes/world/objects/rock_large.tscn" id="6"]
[ext_resource type="PackedScene" path="res://scenes/world/roaming_enemy.tscn" id="7"]
[ext_resource type="Script" path="res://scenes/world/overworld.gd" id="8"]
[ext_resource type="Script" path="res://scenes/world/overworld_player.gd" id="9"]
[ext_resource type="Script" path="res://scenes/world/town_location.gd" id="10"]
[ext_resource type="Script" path="res://scenes/world/cave_location.gd" id="11"]
[ext_resource type="Script" path="res://scenes/world/lake_location.gd" id="12"]

[sub_resource type="RectangleShape2D" id="RectangleShape2D_player"]
size = Vector2(20, 20)

[sub_resource type="RectangleShape2D" id="RectangleShape2D_location"]
size = Vector2(60, 60)

[node name="Overworld" type="Node2D"]
y_sort_enabled = true
script = ExtResource("8")

[node name="GroundLayer" type="TileMapLayer" parent="."]
z_index = 0
y_sort_enabled = false

[node name="TerrainOverlay" type="TileMapLayer" parent="."]
z_index = 2
y_sort_enabled = false

[node name="Objects" type="Node2D" parent="."]
z_index = 1
y_sort_enabled = true

'''

    objects = []
    obj_id = 1

    # Create border - top side
    for x in range(MARGIN, MAP_WIDTH - MARGIN, SPACING):
        tree_type = "tree_medium" if (obj_id % 3 == 0) else "tree_small"
        objects.append(create_object_instance(
            resources[tree_type], f"BorderTree{obj_id}", x, MARGIN
        ))
        obj_id += 1

    # Create border - bottom side
    for x in range(MARGIN, MAP_WIDTH - MARGIN, SPACING):
        tree_type = "tree_large" if (obj_id % 4 == 0) else "tree_medium"
        objects.append(create_object_instance(
            resources[tree_type], f"BorderTree{obj_id}", x, MAP_HEIGHT - MARGIN
        ))
        obj_id += 1

    # Create border - left side
    for y in range(MARGIN + SPACING, MAP_HEIGHT - MARGIN, SPACING):
        obj_type = "rock_medium" if (obj_id % 3 == 0) else "tree_small"
        objects.append(create_object_instance(
            resources[obj_type], f"BorderObj{obj_id}", MARGIN, y
        ))
        obj_id += 1

    # Create border - right side
    for y in range(MARGIN + SPACING, MAP_HEIGHT - MARGIN, SPACING):
        obj_type = "rock_large" if (obj_id % 4 == 0) else "tree_medium"
        objects.append(create_object_instance(
            resources[obj_type], f"BorderObj{obj_id}", MAP_WIDTH - MARGIN, y
        ))
        obj_id += 1

    # Add some interior decorative trees/rocks
    interior_objects = [
        ("tree_large", CENTER_X - 300, CENTER_Y - 200),
        ("tree_large", CENTER_X + 300, CENTER_Y - 200),
        ("rock_large", CENTER_X - 250, CENTER_Y + 150),
        ("rock_medium", CENTER_X + 200, CENTER_Y + 180),
        ("tree_small", CENTER_X - 100, CENTER_Y - 300),
        ("tree_small", CENTER_X + 120, CENTER_Y - 280),
    ]

    for obj_type, x, y in interior_objects:
        objects.append(create_object_instance(
            resources[obj_type], f"DecorObj{obj_id}", x, y
        ))
        obj_id += 1

    # Add roaming enemies
    enemy_positions = [
        (CENTER_X - 200, CENTER_Y - 100),
        (CENTER_X + 250, CENTER_Y - 50),
        (CENTER_X - 150, CENTER_Y + 100),
        (CENTER_X + 180, CENTER_Y + 120),
        (CENTER_X, CENTER_Y - 200),
    ]

    for enemy_x, enemy_y in enemy_positions:
        objects.append(create_object_instance(
            resources["roaming_enemy"], f"Enemy{obj_id}", enemy_x, enemy_y
        ))
        obj_id += 1

    # Add all objects to scene
    scene_content += ''.join(objects)

    # Add Player (at root level, not under Objects, as script expects)
    scene_content += f'''
[node name="Player" type="CharacterBody2D" parent="."]
position = Vector2({CENTER_X}, {CENTER_Y})
collision_layer = 2
script = ExtResource("9")

[node name="ColorRect" type="ColorRect" parent="Player"]
offset_left = -15.0
offset_top = -30.0
offset_right = 15.0
offset_bottom = 0.0
color = Color(0, 0.7, 1, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player"]
shape = SubResource("RectangleShape2D_player")

[node name="InteractionArea" type="Area2D" parent="Player"]
collision_layer = 0
collision_mask = 4

[node name="CollisionShape2D" type="CollisionShape2D" parent="Player/InteractionArea"]
shape = SubResource("RectangleShape2D_player")

'''

    # Add location markers
    scene_content += f'''[node name="LocationMarkers" type="Node2D" parent="."]

[node name="Town" type="Area2D" parent="LocationMarkers"]
position = Vector2({CENTER_X - 400}, {CENTER_Y})
script = ExtResource("10")

[node name="ColorRect" type="ColorRect" parent="LocationMarkers/Town"]
offset_left = -50.0
offset_top = -50.0
offset_right = 30.0
offset_bottom = 30.0
color = Color(0.8, 0.5, 0.2, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="LocationMarkers/Town"]
shape = SubResource("RectangleShape2D_location")

[node name="Cave" type="Area2D" parent="LocationMarkers"]
position = Vector2({CENTER_X + 400}, {CENTER_Y})
script = ExtResource("11")

[node name="ColorRect" type="ColorRect" parent="LocationMarkers/Cave"]
offset_left = -50.0
offset_top = -50.0
offset_right = 30.0
offset_bottom = 30.0
color = Color(0.5, 0.5, 0.5, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="LocationMarkers/Cave"]
shape = SubResource("RectangleShape2D_location")

[node name="Lake" type="Area2D" parent="LocationMarkers"]
position = Vector2({CENTER_X}, {CENTER_Y + 300})
script = ExtResource("12")

[node name="ColorRect" type="ColorRect" parent="LocationMarkers/Lake"]
offset_left = -50.0
offset_top = -50.0
offset_right = 40.0
offset_bottom = 40.0
color = Color(0.3, 0.6, 1.0, 1)

[node name="CollisionShape2D" type="CollisionShape2D" parent="LocationMarkers/Lake"]
shape = SubResource("RectangleShape2D_location")

[node name="Camera2D" type="Camera2D" parent="."]
position = Vector2({CENTER_X}, {CENTER_Y})
position_smoothing_enabled = true

[node name="UI" type="CanvasLayer" parent="."]

[node name="HUD" type="Control" parent="UI"]
layout_mode = 3
anchors_preset = 15
anchor_right = 1.0
anchor_bottom = 1.0
grow_horizontal = 2
grow_vertical = 2

[node name="GoldLabel" type="Label" parent="UI/HUD"]
layout_mode = 0
offset_left = 20.0
offset_top = 20.0
offset_right = 200.0
offset_bottom = 50.0
text = "Gold: 0"

[node name="LocationLabel" type="Label" parent="UI/HUD"]
layout_mode = 1
anchors_preset = 7
anchor_left = 0.5
anchor_top = 1.0
anchor_right = 0.5
anchor_bottom = 1.0
offset_left = -200.0
offset_top = -60.0
offset_right = 200.0
offset_bottom = -30.0
grow_horizontal = 2
grow_vertical = 0
horizontal_alignment = 1

[node name="FastTravelMenu" type="PanelContainer" parent="UI"]
visible = false
anchors_preset = 8
anchor_left = 0.5
anchor_top = 0.5
anchor_right = 0.5
anchor_bottom = 0.5
offset_left = -200.0
offset_top = -150.0
offset_right = 200.0
offset_bottom = 150.0
grow_horizontal = 2
grow_vertical = 2
'''

    # Write to file
    output_file = "scenes/world/overworld_starter.tscn"
    with open(output_file, 'w') as f:
        f.write(scene_content)

    print(f"Created: {output_file}")
    print(f"Map size: {MAP_WIDTH}x{MAP_HEIGHT}")
    print(f"Objects placed: {obj_id - 1}")
    print(f"- Border trees/rocks: ~{len(objects) - len(interior_objects)}")
    print(f"- Interior objects: {len(interior_objects)}")
    print("\nLocations:")
    print(f"- Town (brown square): Left side")
    print(f"- Cave (gray square): Right side")
    print(f"- Lake (blue square): Bottom center")
    print(f"- Player (blue): Center")

if __name__ == "__main__":
    main()
