import os, re
from collections import defaultdict

items_dir = 'data/items'
shapes_dir = 'data/shapes'

# Parse all shapes
shapes = {}
for f in os.listdir(shapes_dir):
    if not f.endswith('.tres'):
        continue
    content = open(os.path.join(shapes_dir, f), 'r', encoding='utf-8').read()
    shape_id = f.replace('.tres', '')
    m_cells = re.search(r'cells = Array\[Vector2i\]\(\[([^\]]+)\]\)', content)
    if not m_cells:
        continue
    cells = []
    for m in re.finditer(r'Vector2i\((\d+),\s*(\d+)\)', m_cells.group(1)):
        cells.append((int(m.group(1)), int(m.group(2))))
    shapes[shape_id] = cells

def render_shape(cells):
    if not cells:
        return '```\nX\n```'
    max_x = max(c[0] for c in cells)
    max_y = max(c[1] for c in cells)
    grid = []
    for y in range(max_y + 1):
        row = []
        for x in range(max_x + 1):
            row.append('X' if (x, y) in cells else '.')
        grid.append(' '.join(row))
    return '```\n' + '\n'.join(grid) + '\n```'

def pixel_size(cells):
    if not cells:
        return '64x64'
    max_x = max(c[0] for c in cells) + 1
    max_y = max(c[1] for c in cells) + 1
    return f'{max_x * 64}x{max_y * 64}'

# Parse all items, deduplicate by base
base_items = {}
for root, dirs, files in os.walk(items_dir):
    for f in sorted(files):
        if not f.endswith('.tres'):
            continue
        path = os.path.join(root, f)
        content = open(path, 'r', encoding='utf-8').read()

        m_id = re.search(r'^id = "(.+?)"', content, re.MULTILINE)
        if not m_id:
            continue
        item_id = m_id.group(1)

        m_name = re.search(r'^display_name = "(.+?)"', content, re.MULTILINE)
        name = m_name.group(1) if m_name else item_id

        m_desc = re.search(r'^description = "(.+?)"', content, re.MULTILINE)
        desc = m_desc.group(1) if m_desc else ''

        m_shape = re.search(r'path="res://data/shapes/([^"]+)\.tres"', content)
        shape_id = m_shape.group(1) if m_shape else 'shape_1x1'

        m_type = re.search(r'^item_type = (\d+)', content, re.MULTILINE)
        item_type = int(m_type.group(1)) if m_type else 0

        m_cat = re.search(r'^category = (\d+)', content, re.MULTILINE)
        cat = int(m_cat.group(1)) if m_cat else -1

        base = re.sub(r'_(common|uncommon|rare|elite|legendary|unique)$', '', item_id)

        if base not in base_items:
            base_items[base] = {
                'name': name,
                'desc': desc,
                'shape_id': shape_id,
                'item_type': item_type,
                'category': cat,
                'base': base,
            }

type_names = {0: 'Active Tool (Weapon)', 1: 'Passive Gear (Armor/Jewelry)', 2: 'Modifier (Gem)', 3: 'Consumable', 4: 'Material', 5: 'Blueprint'}
cat_names = {0: 'Sword', 1: 'Mace', 2: 'Bow', 3: 'Staff', 4: 'Dagger', 5: 'Shield', 6: 'Axe',
             7: 'Helmet', 8: 'Chestplate', 9: 'Gloves', 10: 'Legs', 11: 'Boots', 12: 'Necklace', 13: 'Ring'}

# Group by type then category
grouped = defaultdict(lambda: defaultdict(list))
for base, info in sorted(base_items.items(), key=lambda x: x[1]['name']):
    t = info['item_type']
    c = info['category']
    grouped[t][c].append(info)

lines = []
lines.append('# Item Sprite Generation Checklist')
lines.append('')
lines.append('For each item: generate a sprite at the specified pixel size, matching the grid shape.')
lines.append('Style: **fantasy pixel art, top-down view, transparent background, warm palette, clean edges.**')
lines.append('')
lines.append('---')
lines.append('')

for t in sorted(grouped.keys()):
    lines.append(f'## {type_names.get(t, f"Type {t}")}')
    lines.append('')
    for c in sorted(grouped[t].keys()):
        cat_label = cat_names.get(c, '')
        if cat_label:
            lines.append(f'### {cat_label}')
            lines.append('')
        for info in grouped[t][c]:
            cells = shapes.get(info['shape_id'], [(0,0)])
            size = pixel_size(cells)
            shape_visual = render_shape(cells)

            name = info['name']
            desc = info['desc']
            shape_name = info['shape_id'].replace('shape_', '').replace('_', ' ')

            prompt_parts = [
                f'Pixel art icon of a "{name}"',
            ]
            if desc:
                prompt_parts.append(f'({desc})')
            prompt_parts.append(f'for a tactical RPG inventory grid.')
            prompt_parts.append(f'Top-down view, transparent background, fantasy style.')
            prompt_parts.append(f'Image size: {size} pixels.')
            prompt_parts.append(f'The sprite must fill a {shape_name} grid pattern where each cell is 64x64px.')
            prompt_parts.append(f'Only draw within the filled cells, leave empty cells transparent.')
            prompt_parts.append(f'Clean pixel art with visible outlines, warm color palette.')

            prompt = ' '.join(prompt_parts)

            lines.append(f'- [ ] **{name}** (`{info["base"]}.png` | {size})')
            lines.append(f'  - Shape: `{info["shape_id"]}` ({len(cells)} cells)')
            lines.append(f'  {shape_visual}')
            if desc:
                lines.append(f'  - *{desc}*')
            lines.append(f'  - **Prompt:** {prompt}')
            lines.append('')
    lines.append('---')
    lines.append('')

with open('data/SPRITE_GENERATION_CHECKLIST.md', 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))

print(f'Written {len(base_items)} items to data/SPRITE_GENERATION_CHECKLIST.md')
