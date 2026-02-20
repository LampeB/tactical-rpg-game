# Godot Enums Quick Reference

This file provides quick lookup for enum values used in `.tres` resource files.
When editing `.tres` files in a text editor, refer to this guide.

## EquipmentCategory
**Used for:** `category` and `armor_slot` fields

### Weapons (Active/Modifiable)
```
0  = SWORD
1  = MACE
2  = BOW
3  = STAFF
4  = DAGGER
5  = SHIELD
6  = AXE
```

### Armor (Passive/Unmodifiable)
```
7  = HELMET
8  = CHESTPLATE
9  = GLOVES
10 = LEGS
11 = BOOTS
12 = NECKLACE
13 = RING
```

---

## ItemType
**Used for:** `item_type` field

```
0 = ACTIVE_TOOL    # Weapons/tools that can be modified by gems
1 = PASSIVE_GEAR   # Armor/accessories providing passive effects
2 = MODIFIER       # Gems that enhance adjacent active tools
3 = CONSUMABLE     # Single-use items (potions, scrolls)
4 = MATERIAL       # Crafting materials
```

---

## Rarity
**Used for:** `rarity` field

```
0 = COMMON         # White - T1
1 = UNCOMMON       # Blue - T2
2 = RARE           # Gold - T3
3 = ELITE          # Orange - T4
4 = LEGENDARY      # Crimson - T5
5 = UNIQUE         # Purple - T6
```

---

## DamageType
**Used for:** `damage_type` field

```
0 = PHYSICAL
1 = FIRE
2 = ICE
3 = THUNDER
4 = POISON
5 = WATER
6 = EARTH
7 = WIND
8 = SPIRIT
```

---

## Stat
**Used in:** StatModifier resources

```
0 = MAX_HP
1 = MAX_MP
2 = SPEED
3 = LUCK
4 = PHYSICAL_ATTACK
5 = PHYSICAL_DEFENSE
6 = SPECIAL_ATTACK
7 = SPECIAL_DEFENSE
8 = CRITICAL_RATE
9 = CRITICAL_DAMAGE
```

---

## ModifierType
**Used in:** StatModifier resources

```
0 = FLAT           # Added directly to stat
1 = PERCENT        # Multiplied after flat bonuses
```

---

## Quick Item Examples

### Weapon Example
```gdscript
item_type = 0        # ACTIVE_TOOL
category = 0         # SWORD
rarity = 0           # COMMON
damage_type = 0      # PHYSICAL
```

### Armor Example
```gdscript
item_type = 1        # PASSIVE_GEAR
category = 7         # HELMET
rarity = 1           # UNCOMMON
armor_slot = 7       # HELMET
```

### Gem/Modifier Example
```gdscript
item_type = 2        # MODIFIER
category = 0         # (not used for modifiers)
rarity = 2           # RARE
```

---

## Pro Tip

**For the Godot Editor:**
- Double-click any `.tres` file in the FileSystem panel
- The Inspector will show dropdown menus with enum names
- Much easier for creating/editing items visually!

**For Text Editing:**
- Keep this file open in a second tab
- Use Ctrl+F to quickly find enum values
- Remember: Comments in `.tres` files will be stripped by Godot
