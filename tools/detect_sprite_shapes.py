"""Detect item shapes from sprite PNGs by analyzing alpha channels.

Scans all item .tres files, reads their referenced sprite, detects which 64x64
cells are filled, and compares against the currently assigned shape. Outputs a
JSON report at tools/shape_report.json listing mismatches for Claude to process.

Usage:
    python tools/detect_sprite_shapes.py                  # full scan, write report
    python tools/detect_sprite_shapes.py sword_common     # scan specific item IDs
    python tools/detect_sprite_shapes.py --dry-run        # print report, don't write file
"""

import json
import os
import re
import sys
from pathlib import Path
from PIL import Image

CELL_SIZE = 64
# Minimum percentage of non-transparent pixels in a cell to consider it "filled"
ALPHA_THRESHOLD = 10  # percent

# ─── sprite analysis ───────────────────────────────────────────────────────────

def get_filled_cells(image_path: str) -> list[tuple[int, int]]:
    """Return sorted list of (col, row) grid cells that have significant content."""
    img = Image.open(image_path).convert("RGBA")
    width, height = img.size
    cols = width // CELL_SIZE
    rows = height // CELL_SIZE

    filled = []
    for row in range(rows):
        for col in range(cols):
            x0 = col * CELL_SIZE
            y0 = row * CELL_SIZE
            cell = img.crop((x0, y0, x0 + CELL_SIZE, y0 + CELL_SIZE))
            pixels = cell.tobytes()
            # RGBA = 4 bytes per pixel, check alpha (every 4th byte starting at offset 3)
            total = CELL_SIZE * CELL_SIZE
            opaque = sum(1 for i in range(3, len(pixels), 4) if pixels[i] > 20)
            if (opaque / total * 100) >= ALPHA_THRESHOLD:
                filled.append((col, row))

    return filled


def normalize_cells(cells: list[tuple[int, int]]) -> list[tuple[int, int]]:
    """Translate cells so minimum col and row are 0. Returns sorted list."""
    if not cells:
        return []
    min_c = min(c for c, r in cells)
    min_r = min(r for c, r in cells)
    return sorted((c - min_c, r - min_r) for c, r in cells)


def cells_to_ascii(cells: list[tuple[int, int]]) -> str:
    """Convert cell coordinates to ASCII grid art."""
    if not cells:
        return "(empty)"
    max_col = max(c for c, r in cells)
    max_row = max(r for c, r in cells)
    cell_set = set(cells)
    lines = []
    for row in range(max_row + 1):
        line = " ".join("X" if (col, row) in cell_set else "." for col in range(max_col + 1))
        lines.append(line)
    return "\n".join(lines)


def cells_to_vector2i_str(cells: list[tuple[int, int]]) -> str:
    """Format cells as Godot Vector2i array string."""
    parts = [f"Vector2i({c}, {r})" for c, r in cells]
    return f"Array[Vector2i]([{', '.join(parts)}])"


# ─── shape .tres parsing ──────────────────────────────────────────────────────

def load_existing_shapes(shapes_dir: str) -> tuple[dict, dict]:
    """Parse shape .tres files.
    Returns:
        cells_to_id: frozenset of normalized cells -> shape_id
        id_to_cells: shape_id -> sorted list of cells
    """
    cells_to_id = {}
    id_to_cells = {}
    if not os.path.isdir(shapes_dir):
        return cells_to_id, id_to_cells

    for fname in os.listdir(shapes_dir):
        if not fname.endswith(".tres"):
            continue
        filepath = os.path.join(shapes_dir, fname)
        shape_id = None
        cells = []
        with open(filepath, "r", encoding="utf-8") as f:
            for line in f:
                if line.startswith("id = "):
                    shape_id = line.split('"')[1]
                if "cells = " in line:
                    for m in re.finditer(r"Vector2i\((\d+),\s*(\d+)\)", line):
                        cells.append((int(m.group(1)), int(m.group(2))))
        if shape_id and cells:
            norm = normalize_cells(cells)
            cells_to_id[frozenset(norm)] = shape_id
            id_to_cells[shape_id] = norm

    return cells_to_id, id_to_cells


# ─── item .tres parsing ──────────────────────────────────────────────────────

def scan_item_tres_files(data_dir: str) -> list[dict]:
    """Walk data/items/ and extract item_id, sprite path, and current shape path from each .tres."""
    items = []
    items_dir = os.path.join(data_dir, "items")

    for root, _dirs, files in os.walk(items_dir):
        for fname in files:
            if not fname.endswith(".tres"):
                continue
            filepath = os.path.join(root, fname)
            item_id = None
            shape_ext_id = None
            sprite_path = None
            ext_resources = {}  # ext_id -> res:// path

            with open(filepath, "r", encoding="utf-8") as f:
                for line in f:
                    # Parse ext_resource lines to map IDs to paths
                    ext_match = re.match(
                        r'\[ext_resource .* path="(res://[^"]+)" id="([^"]+)"\]', line
                    )
                    if ext_match:
                        ext_resources[ext_match.group(2)] = ext_match.group(1)
                        continue

                    if line.startswith("id = "):
                        item_id = line.split('"')[1]
                    elif line.startswith("shape = "):
                        m = re.search(r'ExtResource\("([^"]+)"\)', line)
                        if m:
                            shape_ext_id = m.group(1)
                    elif line.startswith("icon = "):
                        m = re.search(r'ExtResource\("([^"]+)"\)', line)
                        if m:
                            sprite_path = ext_resources.get(m.group(1))

            if not item_id:
                continue

            # Resolve shape path from ext_resource
            current_shape_path = ext_resources.get(shape_ext_id, "") if shape_ext_id else ""
            # Extract shape ID from path like "res://data/shapes/shape_1x1.tres"
            current_shape_id = ""
            if current_shape_path:
                current_shape_id = Path(current_shape_path).stem

            items.append({
                "item_id": item_id,
                "tres_path": filepath,
                "sprite_res_path": sprite_path or "",
                "current_shape_id": current_shape_id,
            })

    return items


# ─── main ─────────────────────────────────────────────────────────────────────

def main():
    project_root = Path(__file__).resolve().parent.parent
    data_dir = project_root / "data"
    shapes_dir = data_dir / "shapes"
    report_path = project_root / "tools" / "shape_report.json"

    dry_run = "--dry-run" in sys.argv
    filter_ids = [a for a in sys.argv[1:] if not a.startswith("--")]

    # Load existing shapes
    cells_to_shape_id, shape_id_to_cells = load_existing_shapes(str(shapes_dir))
    print(f"Loaded {len(cells_to_shape_id)} existing shape definitions")

    # Scan all item .tres files
    all_items = scan_item_tres_files(str(data_dir))
    if filter_ids:
        all_items = [it for it in all_items if it["item_id"] in filter_ids]
    print(f"Scanning {len(all_items)} item(s)...\n")

    mismatches = []
    no_sprite = []
    matches = 0
    errors = []

    for item in all_items:
        sprite_res = item["sprite_res_path"]
        if not sprite_res:
            no_sprite.append(item["item_id"])
            continue

        # Convert res:// path to filesystem path
        rel_path = sprite_res.replace("res://", "")
        abs_path = project_root / rel_path
        if not abs_path.exists():
            errors.append({"item_id": item["item_id"], "error": f"Sprite not found: {abs_path}"})
            continue

        try:
            cells = get_filled_cells(str(abs_path))
        except Exception as e:
            errors.append({"item_id": item["item_id"], "error": str(e)})
            continue

        norm = normalize_cells(cells)
        detected_shape_id = cells_to_shape_id.get(frozenset(norm))

        current = item["current_shape_id"]
        current_cells = shape_id_to_cells.get(current, [])

        if detected_shape_id and detected_shape_id == current:
            matches += 1
            continue

        # Mismatch or new shape
        entry = {
            "item_id": item["item_id"],
            "tres_path": str(Path(item["tres_path"]).relative_to(project_root)),
            "sprite": rel_path,
            "current_shape": current,
            "current_cells": [[c, r] for c, r in current_cells],
            "detected_cells": [[c, r] for c, r in norm],
            "detected_ascii": cells_to_ascii(norm),
            "detected_cell_count": len(norm),
        }

        if detected_shape_id:
            entry["suggested_shape"] = detected_shape_id
            entry["action"] = "change_shape"
        else:
            entry["suggested_shape"] = None
            entry["action"] = "new_shape_needed"
            entry["vector2i_string"] = cells_to_vector2i_str(norm)

        mismatches.append(entry)

    # Build report
    report = {
        "summary": {
            "total_items_scanned": len(all_items),
            "matching": matches,
            "mismatches": len(mismatches),
            "no_sprite": len(no_sprite),
            "errors": len(errors),
        },
        "mismatches": mismatches,
        "errors": errors,
    }

    # Print summary
    print(f"Results:")
    print(f"  Matching shape:   {matches}")
    print(f"  Mismatches:       {len(mismatches)}")
    print(f"  No sprite:        {len(no_sprite)}")
    print(f"  Errors:           {len(errors)}")

    if mismatches:
        print(f"\nMismatches:")
        for m in mismatches:
            action = m["action"]
            current = m["current_shape"]
            suggested = m.get("suggested_shape", "NEW")
            print(f"  {m['item_id']}: {current} -> {suggested or 'NEW'} ({action})")
            print(f"    {m['detected_ascii'].replace(chr(10), '  |  ')}")

    if errors:
        print(f"\nErrors:")
        for e in errors:
            print(f"  {e['item_id']}: {e['error']}")

    if not dry_run:
        with open(report_path, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
        print(f"\nReport written to: {report_path}")
    else:
        print("\n(dry run — no file written)")


if __name__ == "__main__":
    main()
