---
name: update-shapes
description: Detect item shapes from sprites and update .tres files to match
disable-model-invocation: true
allowed-tools: Bash(python *), Read, Edit, Write, Glob, Grep
argument-hint: "[item_id...] [--dry-run]"
---

# Update Item Shapes from Sprites

Detect the grid shape of item sprites by analyzing pixel alpha channels, then update
item `.tres` files so their `shape` reference matches the actual sprite content.

## Steps

1. Run the detection script:
   ```
   python tools/detect_sprite_shapes.py $ARGUMENTS
   ```
   This writes a report to `tools/shape_report.json`.

2. Read `tools/shape_report.json` and process each mismatch:

   - **`action: "change_shape"`** — The sprite matches a different existing shape.
     Update the item's `.tres` file to reference the correct shape from `data/shapes/`.
     All rarity variants of the same base item should use the same shape.

   - **`action: "new_shape_needed"`** — The sprite doesn't match any existing shape.
     Create a new shape `.tres` in `data/shapes/` using the `vector2i_string` from the report,
     then update the item `.tres` to reference it.

3. When updating a `.tres` file's shape reference:
   - Find the `[ext_resource ... path="res://data/shapes/OLD.tres" ...]` line
   - Change the path to the new shape: `res://data/shapes/NEW.tres`
   - The `ext_resource` ID stays the same — only the path changes

4. When creating a new shape `.tres`:
   - Use this template:
     ```
     [gd_resource type="Resource" script_class="ItemShape" load_steps=2 format=3]

     [ext_resource type="Script" path="res://scripts/resources/item_shape.gd" id="1"]

     [resource]
     script = ExtResource("1")
     id = "SHAPE_ID"
     display_name = "DISPLAY_NAME"
     cells = VECTOR2I_ARRAY
     rotation_states = 1
     ```
   - Name the file `data/shapes/shape_SOMETHING.tres`
   - Set `rotation_states` to 1 unless the shape is symmetric (2 or 4)

5. Print a summary of all changes made.

## Detection settings

- Cell size: 64x64 pixels
- Alpha threshold: 10% of cell pixels must be opaque (alpha > 20)
- Sprites are at: `assets/sprites/items/`
- Shapes are at: `data/shapes/`
- Item data is at: `data/items/` (subdirs: weapons, armor, consumables, jewelry, modifiers)

## Flags

- `--dry-run`: Print the report without writing `shape_report.json`
- Pass item IDs as positional args to scan only specific items
