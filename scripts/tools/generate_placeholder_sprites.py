#!/usr/bin/env python3
"""
Generate placeholder sprites for prototyping.
Run this to create simple colored shapes as placeholder graphics.
"""

from PIL import Image, ImageDraw
import os

# Output directories
TILES_DIR = "assets/sprites/tiles/placeholders"
OBJECTS_DIR = "assets/sprites/objects/placeholders"

def create_directory(path):
    """Create directory if it doesn't exist."""
    os.makedirs(path, exist_ok=True)

def create_tile(filename, color, size=16):
    """Create a simple solid color tile."""
    img = Image.new('RGBA', (size, size), color)
    img.save(filename)
    print(f"Created: {filename}")

def create_circle(filename, color, size, outline_color=None):
    """Create a circular sprite."""
    img = Image.new('RGBA', size, (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw circle
    draw.ellipse([0, 0, size[0]-1, size[1]-1], fill=color, outline=outline_color, width=1)

    img.save(filename)
    print(f"Created: {filename}")

def create_triangle(filename, color, width, height):
    """Create a triangle sprite (for trees)."""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Draw triangle (tree shape)
    points = [
        (width // 2, 0),           # Top
        (0, height - 4),           # Bottom left
        (width - 1, height - 4)    # Bottom right
    ]
    draw.polygon(points, fill=color, outline=(0, 100, 0))

    # Draw trunk
    trunk_width = max(2, width // 4)
    trunk_x = (width - trunk_width) // 2
    draw.rectangle(
        [trunk_x, height - 4, trunk_x + trunk_width, height - 1],
        fill=(101, 67, 33)  # Brown
    )

    img.save(filename)
    print(f"Created: {filename}")

def create_rectangle(filename, color, width, height, outline_color=None):
    """Create a rectangular sprite."""
    img = Image.new('RGBA', (width, height), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    draw.rectangle([0, 0, width-1, height-1], fill=color, outline=outline_color, width=1)

    img.save(filename)
    print(f"Created: {filename}")

def main():
    print("Generating placeholder sprites...")

    # Create directories
    create_directory(TILES_DIR)
    create_directory(OBJECTS_DIR)

    print("\n=== TILES ===")
    # Tiles (16x16)
    create_tile(f"{TILES_DIR}/grass.png", (34, 139, 34))      # Green
    create_tile(f"{TILES_DIR}/dirt.png", (139, 90, 43))       # Brown
    create_tile(f"{TILES_DIR}/road_dirt.png", (160, 100, 50)) # Light brown
    create_tile(f"{TILES_DIR}/road_paved.png", (128, 128, 128)) # Gray
    create_tile(f"{TILES_DIR}/water.png", (30, 144, 255))     # Blue
    create_tile(f"{TILES_DIR}/mountain.png", (105, 105, 105)) # Dark gray
    create_tile(f"{TILES_DIR}/sand.png", (238, 214, 175))     # Tan

    print("\n=== TREES ===")
    # Trees (triangles)
    create_triangle(f"{OBJECTS_DIR}/tree_small.png", (34, 139, 34), 16, 24)
    create_triangle(f"{OBJECTS_DIR}/tree_medium.png", (0, 128, 0), 20, 32)
    create_triangle(f"{OBJECTS_DIR}/tree_large.png", (0, 100, 0), 28, 40)

    print("\n=== ROCKS ===")
    # Rocks (circles/ovals)
    create_circle(f"{OBJECTS_DIR}/rock_small.png", (128, 128, 128), (12, 12), (64, 64, 64))
    create_circle(f"{OBJECTS_DIR}/rock_medium.png", (105, 105, 105), (16, 16), (64, 64, 64))
    create_circle(f"{OBJECTS_DIR}/rock_large.png", (90, 90, 90), (24, 20), (64, 64, 64))

    print("\n=== OTHER OBJECTS ===")
    # Bush
    create_circle(f"{OBJECTS_DIR}/bush.png", (0, 100, 0), (14, 12), (0, 80, 0))

    # Sign
    create_rectangle(f"{OBJECTS_DIR}/sign.png", (139, 69, 19), 12, 20, (101, 67, 33))

    # Fence
    create_rectangle(f"{OBJECTS_DIR}/fence.png", (160, 82, 45), 16, 8, (101, 67, 33))

    # Flower (small decorative)
    create_circle(f"{OBJECTS_DIR}/flower_red.png", (220, 20, 60), (8, 8), (139, 0, 0))
    create_circle(f"{OBJECTS_DIR}/flower_yellow.png", (255, 215, 0), (8, 8), (218, 165, 32))

    # Grass tuft (decorative)
    create_circle(f"{OBJECTS_DIR}/grass_tuft.png", (50, 205, 50), (8, 6), (34, 139, 34))

    print("\n✅ All placeholder sprites created!")
    print(f"Tiles: {TILES_DIR}")
    print(f"Objects: {OBJECTS_DIR}")

if __name__ == "__main__":
    main()
