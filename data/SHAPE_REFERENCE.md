# Shape Visual Reference

All grid shapes used by items in the inventory system.
Coordinates are (x, y) where x = column, y = row. Each `X` = one cell (64x64 px).

---

## Simple Shapes

### shape_1x1 — Single (1 cell)
```
X
```

### shape_1x2 — Vertical Bar (2 cells)
```
X
X
```

### shape_1x3 — Long Bar (3 cells)
```
X
X
X
```

### shape_1x4 — Long Staff (4 cells)
```
X
X
X
X
```

### shape_2x2 — Square (4 cells)
```
X X
X X
```

### shape_2x3 — 2x3 Rectangle (6 cells)
```
X X
X X
X X
```

---

## L-Shapes

### shape_l — L-Shape (4 cells)
```
X .
X .
X X
```

### shape_reverse_l — Reverse L-Shape (4 cells)
```
X X
X .
X .
```

---

## Weapon Shapes

### shape_axe — Axe / T-Shape (5 cells)
```
X X X
. X .
. X .
```

### shape_great_axe — Great Axe (6 cells)
```
X X X
. X .
. X .
. X .
```

### shape_bow — Bow Shape (6 cells)
```
X X
X .
X .
X X
```

### shape_shortbow — Short Bow (4 cells)
```
. X
X .
X .
. X
```

### shape_longbow — Long Bow (5 cells)
```
. X
X .
X .
X .
. X
```

### shape_great_crossbow — Great Crossbow (8 cells)
```
. X X X .
X . X . X
. . X . .
. . X . .
```

### shape_double_scythe — Double Scythe (6 cells)
```
X X .
. X .
. X .
. X X
```

---

## Special Shapes

### shape_cross — Cross / Plus (5 cells)
```
. X .
X X X
. X .
```

### shape_x — X-Shape (5 cells)
```
X . X
. X .
X . X
```

### shape_u — U-Shape (7 cells)
```
X . X
X . X
X X X
```

### shape_bold_u — Bold U-Shape (8 cells)
```
X . X
X X X
X X X
```

### shape_double_l — Double L (8 cells)
```
. X X
. . X
X . X
X . .
X X .
```

---

## Custom Shapes

### shape_custom_212525 — Oak Staff (6 cells)
```
X X
. X
. X
. X
. X
```

### shape_custom_176317 — Skeleton Arm (6 cells)
```
X .
X .
X X
. X
. X
```

---

## Summary Table

| Shape                 | Cells | Size  | Rotations | Used By                          |
|-----------------------|-------|-------|-----------|----------------------------------|
| shape_1x1             | 1     | 1x1   | 1         | Daggers, gems, rings, wands      |
| shape_1x2             | 2     | 1x2   | 2         | Swords, armor, crossbows         |
| shape_1x3             | 3     | 1x3   | 2         | Claymores, mauls, chain legs     |
| shape_1x4             | 4     | 1x4   | 2         | Staves, halberds, frostspire     |
| shape_2x2             | 4     | 2x2   | 1         | Maces, shields, grimoires        |
| shape_2x3             | 6     | 2x3   | 2         | Plate cuirass                    |
| shape_l               | 4     | 2x3   | 4         | Broadsword, hooked dagger, plate |
| shape_reverse_l       | 4     | 2x3   | 4         | (available)                      |
| shape_axe             | 5     | 3x3   | 4         | Axes, war hammers                |
| shape_great_axe       | 6     | 3x4   | 4         | Vampiric halberd                 |
| shape_bow             | 6     | 2x4   | 4         | All standard bows                |
| shape_shortbow        | 4     | 2x4   | 4         | Stormstring                      |
| shape_longbow         | 5     | 2x5   | 4         | Whispering Bow                   |
| shape_great_crossbow  | 8     | 5x4   | 4         | (available)                      |
| shape_double_scythe   | 6     | 3x4   | 4         | Harvester's Scythe               |
| shape_cross           | 5     | 3x3   | 1         | (available)                      |
| shape_x               | 5     | 3x3   | 1         | (available)                      |
| shape_u               | 7     | 3x3   | 4         | (available)                      |
| shape_bold_u          | 8     | 3x3   | 4         | Worldsplitter                    |
| shape_double_l        | 8     | 3x5   | 4         | (available)                      |
| shape_custom_212525   | 6     | 2x5   | 4         | Staff (oak)                      |
| shape_custom_176317   | 6     | 2x5   | 4         | Skeletal Arm (common)            |
