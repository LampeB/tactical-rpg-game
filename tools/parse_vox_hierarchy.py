"""
Parse a MagicaVoxel .vox file and dump the complete scene hierarchy.

Outputs:
- All models (SIZE/XYZI): index, dimensions, voxel count
- All nTRN nodes: id, name, child_node_id, translation
- All nGRP nodes: id, list of child_node_ids
- All nSHP nodes: id, model_id
- RGBA palette (256 entries)

Usage:
    python tools/parse_vox_hierarchy.py <path_to_vox_file>
"""
import struct
import sys
import os


def read_int32(f):
    data = f.read(4)
    if len(data) < 4:
        return None
    return struct.unpack('<i', data)[0]


def read_uint32(f):
    data = f.read(4)
    if len(data) < 4:
        return None
    return struct.unpack('<I', data)[0]


def read_string(f):
    """Read a length-prefixed string."""
    length = read_int32(f)
    if length is None or length == 0:
        return ""
    return f.read(length).decode('utf-8', errors='replace')


def read_dict(f):
    """Read a VOX DICT (n_pairs, then n key-value string pairs)."""
    n_pairs = read_int32(f)
    if n_pairs is None:
        return {}
    d = {}
    for _ in range(n_pairs):
        key = read_string(f)
        value = read_string(f)
        d[key] = value
    return d


def parse_vox(filepath):
    models = []        # list of (sx, sy, sz, voxels_list)
    trn_nodes = []     # nTRN
    grp_nodes = []     # nGRP
    shp_nodes = []     # nSHP
    palette = None
    layr_nodes = []    # LAYR

    with open(filepath, 'rb') as f:
        # Header: "VOX " + version
        magic = f.read(4)
        if magic != b'VOX ':
            print(f"ERROR: Not a VOX file (magic={magic})")
            return
        version = read_int32(f)
        print(f"VOX file version: {version}")

        # MAIN chunk
        main_id = f.read(4)
        if main_id != b'MAIN':
            print(f"ERROR: Expected MAIN chunk, got {main_id}")
            return
        main_content_size = read_int32(f)
        main_children_size = read_int32(f)
        print(f"MAIN chunk: content_size={main_content_size}, children_size={main_children_size}")

        # Current model being built (SIZE sets dimensions, XYZI fills voxels)
        current_size = None

        # Read child chunks
        end_pos = f.tell() + main_children_size
        while f.tell() < end_pos:
            chunk_id_bytes = f.read(4)
            if len(chunk_id_bytes) < 4:
                break
            chunk_id = chunk_id_bytes.decode('ascii', errors='replace')
            content_size = read_int32(f)
            children_size = read_int32(f)
            chunk_start = f.tell()

            if chunk_id == 'SIZE':
                sx = read_int32(f)
                sy = read_int32(f)
                sz = read_int32(f)
                current_size = (sx, sy, sz)

            elif chunk_id == 'XYZI':
                num_voxels = read_int32(f)
                voxels = []
                for _ in range(num_voxels):
                    data = f.read(4)
                    x, y, z, i = struct.unpack('BBBB', data)
                    voxels.append((x, y, z, i))
                if current_size:
                    models.append((current_size[0], current_size[1], current_size[2], voxels))
                else:
                    models.append((0, 0, 0, voxels))
                current_size = None

            elif chunk_id == 'nTRN':
                node_id = read_int32(f)
                node_attrs = read_dict(f)
                child_node_id = read_int32(f)
                reserved_id = read_int32(f)
                layer_id = read_int32(f)
                num_frames = read_int32(f)
                frames = []
                for _ in range(num_frames):
                    frame_dict = read_dict(f)
                    frames.append(frame_dict)
                trn_nodes.append({
                    'node_id': node_id,
                    'attrs': node_attrs,
                    'child_node_id': child_node_id,
                    'reserved_id': reserved_id,
                    'layer_id': layer_id,
                    'num_frames': num_frames,
                    'frames': frames,
                })

            elif chunk_id == 'nGRP':
                node_id = read_int32(f)
                node_attrs = read_dict(f)
                num_children = read_int32(f)
                child_ids = []
                for _ in range(num_children):
                    child_ids.append(read_int32(f))
                grp_nodes.append({
                    'node_id': node_id,
                    'attrs': node_attrs,
                    'num_children': num_children,
                    'child_ids': child_ids,
                })

            elif chunk_id == 'nSHP':
                node_id = read_int32(f)
                node_attrs = read_dict(f)
                num_models = read_int32(f)
                model_refs = []
                for _ in range(num_models):
                    model_id = read_int32(f)
                    model_attrs = read_dict(f)
                    model_refs.append({
                        'model_id': model_id,
                        'attrs': model_attrs,
                    })
                shp_nodes.append({
                    'node_id': node_id,
                    'attrs': node_attrs,
                    'num_models': num_models,
                    'models': model_refs,
                })

            elif chunk_id == 'RGBA':
                palette = []
                for _ in range(256):
                    data = f.read(4)
                    r, g, b, a = struct.unpack('BBBB', data)
                    palette.append((r, g, b, a))

            elif chunk_id == 'LAYR':
                layer_id = read_int32(f)
                layer_attrs = read_dict(f)
                reserved = read_int32(f)
                layr_nodes.append({
                    'layer_id': layer_id,
                    'attrs': layer_attrs,
                    'reserved': reserved,
                })

            # Skip to end of chunk content (in case we didn't read it all)
            f.seek(chunk_start + content_size + children_size)

    # === Print results ===

    print(f"\n{'='*60}")
    print(f"MODELS ({len(models)} total)")
    print(f"{'='*60}")
    for idx, (sx, sy, sz, voxels) in enumerate(models):
        print(f"  Model #{idx}: size=({sx}, {sy}, {sz}), voxels={len(voxels)}")
        # Show bounding box of actual voxels
        if voxels:
            xs = [v[0] for v in voxels]
            ys = [v[1] for v in voxels]
            zs = [v[2] for v in voxels]
            print(f"    voxel bbox: x=[{min(xs)},{max(xs)}] y=[{min(ys)},{max(ys)}] z=[{min(zs)},{max(zs)}]")
            # Count unique color indices
            colors = set(v[3] for v in voxels)
            print(f"    color indices used: {sorted(colors)}")

    print(f"\n{'='*60}")
    print(f"nTRN NODES ({len(trn_nodes)} total)")
    print(f"{'='*60}")
    for trn in trn_nodes:
        name = trn['attrs'].get('_name', '(unnamed)')
        hidden = trn['attrs'].get('_hidden', None)
        print(f"  nTRN id={trn['node_id']}: name=\"{name}\", child_node_id={trn['child_node_id']}, layer_id={trn['layer_id']}")
        if hidden:
            print(f"    _hidden={hidden}")
        for attr_key, attr_val in trn['attrs'].items():
            if attr_key not in ('_name', '_hidden'):
                print(f"    attr: {attr_key}={attr_val}")
        for fi, frame in enumerate(trn['frames']):
            if frame:
                print(f"    frame[{fi}]: {frame}")

    print(f"\n{'='*60}")
    print(f"nGRP NODES ({len(grp_nodes)} total)")
    print(f"{'='*60}")
    for grp in grp_nodes:
        print(f"  nGRP id={grp['node_id']}: children({grp['num_children']})={grp['child_ids']}")
        if grp['attrs']:
            print(f"    attrs: {grp['attrs']}")

    print(f"\n{'='*60}")
    print(f"nSHP NODES ({len(shp_nodes)} total)")
    print(f"{'='*60}")
    for shp in shp_nodes:
        for mref in shp['models']:
            print(f"  nSHP id={shp['node_id']}: model_id={mref['model_id']}")
            if mref['attrs']:
                print(f"    model_attrs: {mref['attrs']}")
        if shp['attrs']:
            print(f"    attrs: {shp['attrs']}")

    print(f"\n{'='*60}")
    print(f"LAYERS ({len(layr_nodes)} total)")
    print(f"{'='*60}")
    for layr in layr_nodes:
        name = layr['attrs'].get('_name', '(unnamed)')
        hidden = layr['attrs'].get('_hidden', '0')
        print(f"  Layer id={layr['layer_id']}: name=\"{name}\", hidden={hidden}")
        for k, v in layr['attrs'].items():
            if k not in ('_name', '_hidden'):
                print(f"    {k}={v}")

    if palette:
        print(f"\n{'='*60}")
        print(f"PALETTE (256 entries, showing non-zero)")
        print(f"{'='*60}")
        for idx, (r, g, b, a) in enumerate(palette):
            if r > 0 or g > 0 or b > 0:
                # Palette index in .vox is 1-based (index+1 matches color index in voxels)
                print(f"  [{idx+1:3d}] = ({r:3d}, {g:3d}, {b:3d}, {a:3d})  #{r:02X}{g:02X}{b:02X}")
    else:
        print("\n  No RGBA palette found (using default)")

    # === Build and print hierarchy tree ===
    print(f"\n{'='*60}")
    print(f"HIERARCHY TREE")
    print(f"{'='*60}")

    # Build lookup maps
    trn_map = {t['node_id']: t for t in trn_nodes}
    grp_map = {g['node_id']: g for g in grp_nodes}
    shp_map = {s['node_id']: s for s in shp_nodes}

    def print_tree(node_id, indent=0):
        prefix = "  " * indent
        if node_id in trn_map:
            trn = trn_map[node_id]
            name = trn['attrs'].get('_name', '(unnamed)')
            translation = None
            if trn['frames']:
                translation = trn['frames'][0].get('_t', None)
            trans_str = f", translation={translation}" if translation else ""
            print(f"{prefix}TRN[{node_id}] \"{name}\"{trans_str} -> child={trn['child_node_id']}")
            print_tree(trn['child_node_id'], indent + 1)
        elif node_id in grp_map:
            grp = grp_map[node_id]
            print(f"{prefix}GRP[{node_id}] children={grp['child_ids']}")
            for child_id in grp['child_ids']:
                print_tree(child_id, indent + 1)
        elif node_id in shp_map:
            shp = shp_map[node_id]
            for mref in shp['models']:
                model = models[mref['model_id']] if mref['model_id'] < len(models) else None
                if model:
                    sx, sy, sz, voxels = model
                    print(f"{prefix}SHP[{node_id}] -> model #{mref['model_id']} (size={sx}x{sy}x{sz}, {len(voxels)} voxels)")
                else:
                    print(f"{prefix}SHP[{node_id}] -> model #{mref['model_id']} (NOT FOUND)")
        else:
            print(f"{prefix}UNKNOWN[{node_id}]")

    # Root is always node 0
    if trn_nodes:
        print_tree(0)
    else:
        print("  No hierarchy nodes found (single-model file)")


if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: python parse_vox_hierarchy.py <path_to_vox_file>")
        sys.exit(1)
    filepath = sys.argv[1]
    if not os.path.exists(filepath):
        print(f"File not found: {filepath}")
        sys.exit(1)
    print(f"Parsing: {filepath}")
    print(f"File size: {os.path.getsize(filepath)} bytes")
    parse_vox(filepath)
