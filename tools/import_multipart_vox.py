"""
Import a multi-model MagicaVoxel .vox file (e.g. Sukuna) and convert it
to the project's multipart format (separate .vox per part + parts.json).

Merges 18 Sukuna parts into 10 pipeline parts:
  Hip + Belly + Chest_A  → body
  LeftThigh + LeftLeg    → left_leg
  RightThigh + RightLeg  → right_leg
  LeftArm + LeftForearm  → left_arm
  RightArm + RightForearm→ right_arm
  LeftHand               → left_hand
  RightHand              → right_hand
  LeftFoot               → left_foot
  RightFoot              → right_foot
  Head_A                 → head

Usage:
  python tools/import_multipart_vox.py <input.vox> <output_dir> [voxel_size]

Example:
  python tools/import_multipart_vox.py "assets/models/characters/Sukuna Model/Sukuna Character VOX.vox" assets/voxels/characters/sukuna 0.03
"""
import struct
import os
import sys
import json
import math


# ─── VOX parser ───────────────────────────────────────────────────────────────

def parse_vox(path):
    """Parse a MagicaVoxel .vox file. Returns models, palette, and scene tree nodes."""
    with open(path, "rb") as f:
        data = f.read()

    assert data[:4] == b"VOX ", "Not a VOX file"
    _version = struct.unpack_from("<I", data, 4)[0]

    models = []   # list of (sx, sy, sz, [(x,y,z,ci), ...])
    palette = None
    nodes = {}    # node_id -> dict

    pos = 8  # skip header

    def read_chunk(offset):
        cid = data[offset:offset + 4].decode("ascii")
        n_content = struct.unpack_from("<I", data, offset + 4)[0]
        n_children = struct.unpack_from("<I", data, offset + 8)[0]
        content = data[offset + 12: offset + 12 + n_content]
        return cid, content, n_content, n_children, offset + 12 + n_content + n_children

    # Read MAIN
    cid, _, nc, nch, _ = read_chunk(pos)
    assert cid == "MAIN"
    pos += 12  # skip MAIN header, children follow

    end = pos + nch
    while pos < end:
        cid, content, nc, nch, next_pos = read_chunk(pos)

        if cid == "SIZE":
            sx, sy, sz = struct.unpack_from("<III", content)
            models.append({"size": (sx, sy, sz), "voxels": []})

        elif cid == "XYZI":
            num = struct.unpack_from("<I", content)[0]
            voxels = []
            for i in range(num):
                off = 4 + i * 4
                x, y, z, ci = struct.unpack_from("BBBB", content, off)
                voxels.append((x, y, z, ci))
            if models:
                models[-1]["voxels"] = voxels

        elif cid == "RGBA":
            palette = []
            for i in range(256):
                r, g, b, a = struct.unpack_from("BBBB", content, i * 4)
                palette.append((r, g, b, a))

        elif cid == "nTRN":
            node = _parse_ntrn(content)
            nodes[node["id"]] = node

        elif cid == "nGRP":
            node = _parse_ngrp(content)
            nodes[node["id"]] = node

        elif cid == "nSHP":
            node = _parse_nshp(content)
            nodes[node["id"]] = node

        pos = next_pos

    return models, palette, nodes


def _parse_dict(data, offset):
    """Parse a DICT (num_pairs, then key/value strings)."""
    n = struct.unpack_from("<I", data, offset)[0]
    offset += 4
    d = {}
    for _ in range(n):
        klen = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        key = data[offset:offset + klen].decode("utf-8")
        offset += klen
        vlen = struct.unpack_from("<I", data, offset)[0]
        offset += 4
        val = data[offset:offset + vlen].decode("utf-8")
        offset += vlen
        d[key] = val
    return d, offset


def _parse_ntrn(content):
    node_id = struct.unpack_from("<I", content, 0)[0]
    attrs, off = _parse_dict(content, 4)
    child_id = struct.unpack_from("<I", content, off)[0]
    off += 4
    _reserved = struct.unpack_from("<I", content, off)[0]
    off += 4
    _layer_id = struct.unpack_from("<I", content, off)[0]
    off += 4
    num_frames = struct.unpack_from("<I", content, off)[0]
    off += 4

    frames = []
    for _ in range(num_frames):
        fd, off = _parse_dict(content, off)
        frames.append(fd)

    # Extract translation
    translation = (0, 0, 0)
    rotation = None
    for frame in frames:
        if "_t" in frame:
            parts = frame["_t"].split()
            translation = (int(parts[0]), int(parts[1]), int(parts[2]))
        if "_r" in frame:
            rotation = int(frame["_r"])

    return {
        "type": "nTRN",
        "id": node_id,
        "name": attrs.get("_name", ""),
        "child_id": child_id,
        "translation": translation,
        "rotation": rotation,
        "frames": frames,
    }


def _parse_ngrp(content):
    node_id = struct.unpack_from("<I", content, 0)[0]
    _attrs, off = _parse_dict(content, 4)
    num_children = struct.unpack_from("<I", content, off)[0]
    off += 4
    children = []
    for _ in range(num_children):
        children.append(struct.unpack_from("<I", content, off)[0])
        off += 4
    return {"type": "nGRP", "id": node_id, "children": children}


def _parse_nshp(content):
    node_id = struct.unpack_from("<I", content, 0)[0]
    _attrs, off = _parse_dict(content, 4)
    num_models = struct.unpack_from("<I", content, off)[0]
    off += 4
    model_ids = []
    for _ in range(num_models):
        mid = struct.unpack_from("<I", content, off)[0]
        off += 4
        _mattrs, off = _parse_dict(content, off)
        model_ids.append(mid)
    return {"type": "nSHP", "id": node_id, "model_ids": model_ids}


# ─── Rotation decoder ─────────────────────────────────────────────────────────

def decode_rotation(r_byte):
    """Decode MagicaVoxel packed rotation byte into a 3x3 matrix (row-major).

    Bits 0-1: index of non-zero in first row
    Bits 2-3: index of non-zero in second row
    Bit 4: sign of first non-zero (0=positive, 1=negative)
    Bit 5: sign of second non-zero
    Bit 6: sign of third non-zero
    """
    if r_byte is None:
        return [[1, 0, 0], [0, 1, 0], [0, 0, 1]]  # identity

    i1 = r_byte & 0x3
    i2 = (r_byte >> 2) & 0x3
    s1 = -1 if (r_byte >> 4) & 1 else 1
    s2 = -1 if (r_byte >> 5) & 1 else 1
    s3 = -1 if (r_byte >> 6) & 1 else 1

    # Third index is the remaining one
    i3 = 3 - i1 - i2

    mat = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
    mat[0][i1] = s1
    mat[1][i2] = s2
    mat[2][i3] = s3
    return mat


def apply_rotation(mat, point):
    """Apply 3x3 rotation matrix to a point (x, y, z)."""
    x, y, z = point
    return (
        mat[0][0] * x + mat[0][1] * y + mat[0][2] * z,
        mat[1][0] * x + mat[1][1] * y + mat[1][2] * z,
        mat[2][0] * x + mat[2][1] * y + mat[2][2] * z,
    )


def mat_mul(a, b):
    """Multiply two 3x3 matrices."""
    result = [[0, 0, 0], [0, 0, 0], [0, 0, 0]]
    for i in range(3):
        for j in range(3):
            for k in range(3):
                result[i][j] += a[i][k] * b[k][j]
    return result


# ─── World-space voxel extraction ─────────────────────────────────────────────

def collect_world_voxels(nodes, models):
    """Walk the scene tree and collect voxels in world space for each named model.

    Returns dict: model_name -> list of (wx, wy, wz, color_index).
    """
    result = {}

    def walk(node_id, parent_translation, parent_rotation):
        node = nodes[node_id]

        if node["type"] == "nTRN":
            # Accumulate transform
            t = node["translation"]
            rot = decode_rotation(node.get("rotation"))
            # New translation = parent_rot * local_t + parent_t
            rt = apply_rotation(parent_rotation, t)
            new_t = (
                parent_translation[0] + rt[0],
                parent_translation[1] + rt[1],
                parent_translation[2] + rt[2],
            )
            new_r = mat_mul(parent_rotation, rot)
            walk(node["child_id"], new_t, new_r)

        elif node["type"] == "nGRP":
            for child_id in node["children"]:
                walk(child_id, parent_translation, parent_rotation)

        elif node["type"] == "nSHP":
            for mid in node["model_ids"]:
                model = models[mid]
                sx, sy, sz = model["size"]
                # Model center offset (MagicaVoxel centers models)
                cx = sx / 2.0
                cy = sy / 2.0
                cz = sz / 2.0

                # Find the name from the parent nTRN
                name = _find_parent_name(nodes, node_id)

                if name not in result:
                    result[name] = []

                for vx, vy, vz, ci in model["voxels"]:
                    # Local position relative to model center
                    lx = vx - cx + 0.5
                    ly = vy - cy + 0.5
                    lz = vz - cz + 0.5
                    # Apply accumulated rotation
                    rx, ry, rz = apply_rotation(parent_rotation, (lx, ly, lz))
                    # Apply accumulated translation
                    wx = parent_translation[0] + rx
                    wy = parent_translation[1] + ry
                    wz = parent_translation[2] + rz
                    result[name].append((wx, wy, wz, ci))

    identity = [[1, 0, 0], [0, 1, 0], [0, 0, 1]]
    walk(0, (0, 0, 0), identity)
    return result


def _find_parent_name(nodes, target_id):
    """Find the name of the nTRN node that references the given node as child."""
    for nid, node in nodes.items():
        if node["type"] == "nTRN" and node.get("child_id") == target_id:
            return node.get("name", f"model_{target_id}")
    return f"model_{target_id}"


# ─── Merge and remap ──────────────────────────────────────────────────────────

# Mapping from Sukuna model names to our pipeline parts (1-to-1, no merging)
MERGE_MAP = {
    "hip": ["Hip"],
    "belly": ["Belly"],
    "chest": ["Chest_A"],
    "head": ["Head_A"],
    "left_thigh": ["LeftThigh"],
    "left_leg": ["LeftLeg"],
    "left_foot": ["LeftFoot"],
    "right_thigh": ["RightThigh"],
    "right_leg": ["RightLeg"],
    "right_foot": ["RightFoot"],
    "left_arm": ["LeftArm"],
    "left_forearm": ["LeftForearm"],
    "left_hand": ["LeftHand"],
    "right_arm": ["RightArm"],
    "right_forearm": ["RightForearm"],
    "right_hand": ["RightHand"],
}

PIPELINE_NODE_NAMES = {
    "hip": "Hip",
    "belly": "Belly",
    "chest": "Chest",
    "head": "Head",
    "left_thigh": "LeftThigh",
    "left_leg": "LeftLeg",
    "left_foot": "LeftFoot",
    "right_thigh": "RightThigh",
    "right_leg": "RightLeg",
    "right_foot": "RightFoot",
    "left_arm": "LeftArm",
    "left_forearm": "LeftForearm",
    "left_hand": "LeftHand",
    "right_arm": "RightArm",
    "right_forearm": "RightForearm",
    "right_hand": "RightHand",
}

# Parts that pivot at their top (hang below the joint)
TOP_PIVOT_PARTS = {
    "left_thigh", "right_thigh", "left_leg", "right_leg",
    "left_arm", "right_arm", "left_forearm", "right_forearm",
}

# Parent hierarchy: child -> parent
PARENT_MAP = {
    "belly": "Hip",
    "chest": "Belly",
    "head": "Chest",
    "left_arm": "Chest",
    "right_arm": "Chest",
    "left_forearm": "LeftArm",
    "right_forearm": "RightArm",
    "left_hand": "LeftForearm",
    "right_hand": "RightForearm",
    "left_thigh": "Hip",
    "right_thigh": "Hip",
    "left_leg": "LeftThigh",
    "right_leg": "RightThigh",
    "left_foot": "LeftLeg",
    "right_foot": "RightLeg",
}


def merge_parts(world_voxels):
    """Map Sukuna model names to our 16-part format (1-to-1, no merging).

    Converts from MV coordinates (Z-up) to Godot coordinates (Y-up):
      MV(x, y, z) → Godot(x, z, -y)

    Returns dict: part_name -> {(gx, gy, gz): color_index}
    Voxels are in local space (zeroed to part's bounding box).
    Also returns the world-space bounding box center for each part (for pivots).
    """
    parts = {}
    part_centers = {}

    for part_name, source_names in MERGE_MAP.items():
        all_voxels = []
        for sname in source_names:
            if sname in world_voxels:
                all_voxels.extend(world_voxels[sname])

        if not all_voxels:
            print(f"  WARNING: No voxels found for {part_name} (sources: {source_names})")
            continue

        # Convert MV → Godot coords and discretize
        # MV: X=right, Y=depth(into screen), Z=up
        # Godot: X=right, Y=up, -Z=forward
        # Negate depth so face (low MV Y) maps to low Godot Z (forward/-Z)
        godot_voxels = {}
        for wx, wy, wz, ci in all_voxels:
            gx = int(math.floor(wx))
            gy = int(math.floor(wz))   # MV Z → Godot Y (height)
            gz = int(math.floor(-wy))  # MV Y → Godot -Z (negate for correct facing)
            godot_voxels[(gx, gy, gz)] = ci

        # Compute bounding box
        xs = [k[0] for k in godot_voxels]
        ys = [k[1] for k in godot_voxels]
        zs = [k[2] for k in godot_voxels]
        min_x, max_x = min(xs), max(xs)
        min_y, max_y = min(ys), max(ys)
        min_z, max_z = min(zs), max(zs)

        center_x = (min_x + max_x) / 2.0
        center_z = (min_z + max_z) / 2.0

        # top_pivot parts: pivot at the TOP (where they attach to parent)
        # bottom_pivot parts: pivot at the BOTTOM
        if part_name in TOP_PIVOT_PARTS:
            part_centers[part_name] = (center_x, max_y, center_z)
        else:
            part_centers[part_name] = (center_x, min_y, center_z)

        # Re-zero to local coordinates
        local_voxels = {}
        for (gx, gy, gz), ci in godot_voxels.items():
            local_voxels[(gx - min_x, gy - min_y, gz - min_z)] = ci

        parts[part_name] = local_voxels

    return parts, part_centers


# ─── VOX writer (single model) ───────────────────────────────────────────────

def write_single_vox(path, voxels, palette_rgba):
    """Write a single-model .vox file from a {(x,y,z): color_index} dict."""
    if not voxels:
        print(f"  SKIP {path}: no voxels")
        return

    keys = list(voxels.keys())
    max_x = max(k[0] for k in keys) + 1
    max_y = max(k[1] for k in keys) + 1
    max_z = max(k[2] for k in keys) + 1

    # Godot → MV: (x, y, z) → (x, z, y) for the SIZE/XYZI
    mv_sx = max_x
    mv_sy = max_z  # Godot Z → MV Y
    mv_sz = max_y  # Godot Y → MV Z

    size_data = struct.pack("<III", mv_sx, mv_sy, mv_sz)

    num = len(voxels)
    xyzi_data = struct.pack("<I", num)
    for (gx, gy, gz), ci in voxels.items():
        mv_x = gx
        mv_y = gz      # Godot Z → MV Y
        mv_z = gy      # Godot Y → MV Z
        xyzi_data += struct.pack("BBBB", mv_x & 0xFF, mv_y & 0xFF, mv_z & 0xFF, ci & 0xFF)

    # Palette
    rgba_data = b""
    for i in range(256):
        if palette_rgba and i < len(palette_rgba):
            r, g, b, a = palette_rgba[i]
            rgba_data += struct.pack("BBBB", r, g, b, a)
        else:
            rgba_data += struct.pack("BBBB", 0, 0, 0, 255)

    def chunk(cid, content, children=b""):
        return cid.encode() + struct.pack("<II", len(content), len(children)) + content + children

    children = chunk("SIZE", size_data) + chunk("XYZI", xyzi_data) + chunk("RGBA", rgba_data)
    main = chunk("MAIN", b"", children)

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(b"VOX " + struct.pack("<I", 150) + main)

    print(f"  OK  {path} ({num} voxels, {max_x}x{max_y}x{max_z})")


# ─── Assembly metadata ────────────────────────────────────────────────────────

def compute_assembly(part_centers, voxel_size):
    """Compute parts.json assembly metadata from world-space part centers."""
    # Hip is the root — use it as reference center
    hip_center = part_centers.get("hip", (0, 0, 0))

    # Find the absolute lowest point across all parts (ground level)
    all_ys = [c[1] for c in part_centers.values()]
    ground_y = min(all_ys)

    def root_pivot(part_name):
        """Pivot for root-level parts (relative to model origin at ground)."""
        if part_name not in part_centers:
            return [0, 0, 0]
        cx, cy, cz = part_centers[part_name]
        px = (cx - hip_center[0]) * voxel_size
        py = (cy - ground_y) * voxel_size
        pz = (cz - hip_center[2]) * voxel_size
        return [round(px, 3), round(py, 3), round(pz, 3)]

    def child_pivot(child_name, parent_name):
        """Pivot for child parts (relative to parent's pivot point)."""
        if child_name not in part_centers or parent_name not in part_centers:
            return [0, 0, 0]
        cc = part_centers[child_name]
        pc = part_centers[parent_name]
        dx = (cc[0] - pc[0]) * voxel_size
        dy = (cc[1] - pc[1]) * voxel_size
        dz = (cc[2] - pc[2]) * voxel_size
        return [round(dx, 3), round(dy, 3), round(dz, 3)]

    assembly = {"voxel_size": voxel_size}

    for part_name in MERGE_MAP:
        if part_name not in part_centers:
            continue

        node_name = PIPELINE_NODE_NAMES[part_name]
        top_pivot = part_name in TOP_PIVOT_PARTS

        # Root part (hip) uses absolute pivot; children use relative pivot
        parent_key = PARENT_MAP.get(part_name)
        if parent_key is None:
            # Hip — root part
            pv = root_pivot(part_name)
            assembly[part_name] = {
                "node_name": node_name, "pivot": pv, "top_pivot": top_pivot
            }
        else:
            # Find the parent's part_name key (reverse lookup from node_name)
            parent_part = None
            for pk, nn in PIPELINE_NODE_NAMES.items():
                if nn == parent_key:
                    parent_part = pk
                    break
            if parent_part:
                pv = child_pivot(part_name, parent_part)
            else:
                pv = root_pivot(part_name)
            assembly[part_name] = {
                "node_name": node_name, "pivot": pv, "top_pivot": top_pivot,
                "parent": parent_key
            }

    return assembly


# ─── Main ─────────────────────────────────────────────────────────────────────

def main():
    if len(sys.argv) < 3:
        print(__doc__)
        sys.exit(1)

    input_path = sys.argv[1]
    output_dir = sys.argv[2]
    voxel_size = float(sys.argv[3]) if len(sys.argv) > 3 else 0.03

    print(f"Parsing {input_path}...")
    models, palette, nodes = parse_vox(input_path)
    print(f"  Found {len(models)} models, {len(nodes)} scene nodes")

    print("Collecting world-space voxels...")
    world_voxels = collect_world_voxels(nodes, models)
    for name, voxels in sorted(world_voxels.items()):
        print(f"  {name}: {len(voxels)} voxels")

    print("Merging into pipeline parts...")
    parts, part_centers = merge_parts(world_voxels)

    print("Writing output files...")
    os.makedirs(output_dir, exist_ok=True)
    for part_name, voxels in parts.items():
        path = os.path.join(output_dir, f"{part_name}.vox")
        write_single_vox(path, voxels, palette)

    print("Computing assembly metadata...")
    assembly = compute_assembly(part_centers, voxel_size)
    meta_path = os.path.join(output_dir, "parts.json")
    with open(meta_path, "w") as f:
        json.dump(assembly, f, indent=2)
    print(f"  META {meta_path}")

    total_voxels = sum(len(v) for v in parts.values())
    print(f"\nDone! {len(parts)} parts, {total_voxels} total voxels")


if __name__ == "__main__":
    main()
