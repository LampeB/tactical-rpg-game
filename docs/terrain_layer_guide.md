# Terrain Layer System

## Overview
The overworld uses a multi-layer rendering system for proper depth sorting and terrain organization.

## Layer Structure

### 1. GroundLayer (TileMapLayer)
- **z_index**: 0
- **Y-sorting**: Disabled
- **Purpose**: Base terrain (grass, dirt, water, mountains)
- **Always renders**: Behind everything
- **Use for**:
  - Ground tiles (grass, sand, dirt)
  - Water, lava, shallow terrain
  - Mountain/cliff base tiles
  - Any flat terrain

### 2. Objects (Node2D)
- **z_index**: 1
- **Y-sorting**: Enabled
- **Purpose**: Dynamic objects that need depth sorting
- **Contains**:
  - Player
  - Trees, rocks, bushes (tree.tscn, rock.tscn, etc.)
  - NPCs, enemies
  - Any object that should sort by Y position
- **Use for**: Anything that moves or needs to appear in front/behind based on Y position

### 3. TerrainOverlay (TileMapLayer)
- **z_index**: 2
- **Y-sorting**: Disabled
- **Purpose**: Upper terrain features
- **Always renders**: On top of everything
- **Use for**:
  - Bridges (that player walks under)
  - Upper cliffs/ledges
  - Cave roofs
  - Any terrain that should render above the player

## How to Use

### Adding Base Terrain (Grass, Water, Mountains)
1. Select **GroundLayer** in the scene tree
2. Use the TileMap editor to paint tiles
3. Add collision polygons in the tileset for impassable terrain

### Adding Objects (Trees, Rocks)
1. Drag object scenes (tree.tscn, rock.tscn) into the scene
2. Make sure they're children of the **Objects** node
3. They will automatically Y-sort with the player

### Adding Bridges/Upper Cliffs
1. Select **TerrainOverlay** in the scene tree
2. Paint bridge/cliff tiles
3. These will render on top of everything (including the player)

## Collision Layers

- **Layer 1**: Static terrain (GroundLayer tiles, tree/rock objects)
- **Layer 2**: Player
- **Mask**: Player collision_mask = 1 (collides with layer 1)

## Example Scene Hierarchy

```
Overworld (Node2D, y_sort_enabled=true)
├── GroundLayer (TileMapLayer, z_index=0)
│   └── [Grass, water, mountain tiles painted here]
├── TerrainOverlay (TileMapLayer, z_index=2)
│   └── [Bridge, cliff tiles painted here]
├── Objects (Node2D, z_index=1, y_sort_enabled=true)
│   ├── Player (CharacterBody2D)
│   ├── Tree (instance of tree.tscn)
│   ├── Tree2 (instance of tree.tscn)
│   └── Rock (instance of rock.tscn)
├── LocationMarkers
├── Enemies
├── Camera2D
└── UI (CanvasLayer)
```

## Tips

1. **Ground tiles disappear behind objects?** → Make sure y_sort_enabled=false on GroundLayer
2. **Objects rendering in wrong order?** → Check they're children of Objects node
3. **Bridges not rendering over player?** → Use TerrainOverlay with z_index=2
4. **Player walking through objects?** → Check collision layers and tree collision shapes
