# Placeholder Sprites Guide

## Overview
This project uses simple colored placeholder sprites for prototyping. Replace the PNG files with real art later - the .tscn files won't need to change!

## What Was Created

### Tiles (for painting on GroundLayer)
Located in: `assets/sprites/tiles/placeholders/`

| File | Color | Use For |
|------|-------|---------|
| grass.png | Green | Default ground |
| dirt.png | Brown | Dirt paths |
| road_dirt.png | Light brown | Dirt roads |
| road_paved.png | Gray | Stone roads |
| water.png | Blue | Lakes, rivers |
| mountain.png | Dark gray | Mountains, cliffs |
| sand.png | Tan | Beaches, desert |

**How to use:** Create a tileset in Godot using these images, then paint on GroundLayer.

### Object Sprites (placeable .tscn scenes)
Located in: `scenes/world/objects/`

#### Trees (with collision)
- `tree_small.tscn` - 16x24px green triangle
- `tree_medium.tscn` - 20x32px green triangle
- `tree_large.tscn` - 28x40px green triangle

#### Rocks (with collision)
- `rock_small.tscn` - 12x12px gray circle
- `rock_medium.tscn` - 16x16px gray circle
- `rock_large.tscn` - 24x20px gray oval

#### Props (with collision)
- `bush.tscn` - 14x12px dark green circle
- `sign.tscn` - 12x20px brown rectangle
- `fence.tscn` - 16x8px brown rectangle

#### Decorative (NO collision - player walks through)
- `flower_red.tscn` - 8x8px red dot
- `flower_yellow.tscn` - 8x8px yellow dot
- `grass_tuft.tscn` - 8x6px green tuft

**How to use:** Drag .tscn files from FileSystem into your scene as children of the **Objects** node.

## How to Replace Placeholders with Real Art

### For Objects:
1. Create/download a real sprite (e.g., `tree_oak.png`)
2. Save it to `assets/sprites/objects/` (or wherever)
3. Open the .tscn file in Godot
4. Select the Sprite2D node
5. Change the Texture property to point to your new PNG
6. Done! Collision and all settings are preserved

### For Tiles:
1. Replace the PNG files in `assets/sprites/tiles/placeholders/`
2. Or create a new tileset with real art
3. Update the GroundLayer's tileset reference

## Regenerating Placeholders

If you need to regenerate or modify placeholders:

```bash
# Regenerate all placeholder sprites
python scripts/tools/generate_placeholder_sprites.py

# Regenerate all .tscn scene files
python scripts/tools/generate_object_scenes.py
```

## Tips

- **Testing layout:** Use placeholders to quickly build your world layout
- **Performance:** Placeholders are tiny files, very fast to load
- **Consistency:** All objects follow the same structure - easy to manage
- **Art replacement:** When you get real art, just swap the PNG files!
