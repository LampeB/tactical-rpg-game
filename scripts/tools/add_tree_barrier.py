#!/usr/bin/env python3
"""
Adds a tree barrier around the perimeter of the existing overworld map.
Preserves all existing features.
"""

def generate_tree_instance(name, x, y, unique_id):
    """Generate a tree instance node."""
    return f'''[node name="{name}" parent="Objects" unique_id={unique_id} instance=ExtResource("17_koevj")]
position = Vector2({x}, {y})

'''

def main():
    print("Adding tree barrier to overworld map...")

    # Map dimensions
    MAP_WIDTH = 1920
    MAP_HEIGHT = 1080
    MARGIN = 80  # Distance from edge
    SPACING = 35  # Distance between trees

    # Read existing scene
    scene_path = "scenes/world/overworld.tscn"
    with open(scene_path, 'r') as f:
        lines = f.readlines()

    # Find where to insert trees (after Objects node declaration)
    insert_index = None
    for i, line in enumerate(lines):
        if line.strip() == '[node name="Objects" type="Node2D" parent="."]':
            # Skip the next few lines (z_index, y_sort_enabled, blank line)
            insert_index = i + 4  # After blank line
            break

    if insert_index is None:
        print("ERROR: Could not find Objects node in scene file")
        return

    # Generate tree positions
    tree_nodes = []
    tree_id = 1
    unique_id_start = 3000000000  # Start with high ID to avoid conflicts

    # Top border
    for x in range(MARGIN, MAP_WIDTH - MARGIN + 1, SPACING):
        tree_nodes.append(generate_tree_instance(
            f"BorderTreeTop{tree_id}", x, MARGIN, unique_id_start + tree_id
        ))
        tree_id += 1

    # Bottom border
    for x in range(MARGIN, MAP_WIDTH - MARGIN + 1, SPACING):
        tree_nodes.append(generate_tree_instance(
            f"BorderTreeBottom{tree_id}", x, MAP_HEIGHT - MARGIN, unique_id_start + tree_id
        ))
        tree_id += 1

    # Left border (skip corners to avoid overlap)
    for y in range(MARGIN + SPACING, MAP_HEIGHT - MARGIN, SPACING):
        tree_nodes.append(generate_tree_instance(
            f"BorderTreeLeft{tree_id}", MARGIN, y, unique_id_start + tree_id
        ))
        tree_id += 1

    # Right border (skip corners to avoid overlap)
    for y in range(MARGIN + SPACING, MAP_HEIGHT - MARGIN, SPACING):
        tree_nodes.append(generate_tree_instance(
            f"BorderTreeRight{tree_id}", MAP_WIDTH - MARGIN, y, unique_id_start + tree_id
        ))
        tree_id += 1

    # Insert trees into scene
    for tree_node in reversed(tree_nodes):  # Reverse to maintain order
        lines.insert(insert_index, tree_node)

    # Write updated scene
    with open(scene_path, 'w') as f:
        f.writelines(lines)

    print(f"Added {len(tree_nodes)} trees around the border")
    print(f"  - Top border: ~{(MAP_WIDTH - 2*MARGIN) // SPACING} trees")
    print(f"  - Bottom border: ~{(MAP_WIDTH - 2*MARGIN) // SPACING} trees")
    print(f"  - Left border: ~{(MAP_HEIGHT - 2*MARGIN) // SPACING} trees")
    print(f"  - Right border: ~{(MAP_HEIGHT - 2*MARGIN) // SPACING} trees")
    print(f"\nMap now has a complete tree barrier!")

if __name__ == "__main__":
    main()
