# Modifier Design Reference

## How Modifiers Work

Modifiers are items placed in the grid inventory that affect adjacent items based on:
- **Weapon subtype** (Sword, Dagger, Axe, Mace, Shield, Bow, Staff)
- **Armor slot** (Helmet, Chest, Legs, Boots, Gloves, Necklace)

Each modifier has 6 rarity tiers (Common to Unique) with scaling values.
Reach pattern expands with rarity (more cells affected at higher tiers).

### Two Categories

| Category | Inventory Shape | Identity | Examples |
|---|---|---|---|
| **Gems** | Always 1x1 | Simple, compact, stackable effects | Fire, Ice, Power, Precision, Fortify |
| **Enchanted Items** | 1x2, 2x2, or L-shape | Powerful, build-defining, takes grid space | Blood Pact Relic, Echo Stone, Phoenix Feather |

Enchanted items use the same MODIFIER `item_type` and reach system as gems —
they just occupy more inventory cells, creating a tradeoff: stronger effects at the cost of backpack space.

### Reach System

- **Default**: `modifier_reach = 1` → 4 orthogonal neighbors (diamond pattern)
- **Custom**: `modifier_reach_pattern: Array[Vector2i]` → exact cell offsets from gem position
- Custom pattern overrides the default diamond. Patterns rotate with the gem.

---

## Reach Pattern Catalogue

Each gem family has a unique shape theme that grows with rarity.
`G` = gem position, `·` = affected cell, `□` = empty.

### Fire Gem — Flame (vertical pillar rising upward) *(implemented)*

```
Common (1)    Uncommon (3)   Rare (4)       Elite (5)        Legendary (7)      Unique (10)
  □·□            □·□          □·□            □·□              □·□                □·□
  □G□            ·G·          □·□            □·□              ··□                ···
  □□□            □□□          ·G·            ·G·              ·G·                ·G·
                              □□□            □·□              □·□                ···
                                             □□□              □·□                □·□
                                                              □□□                □□□
```
Coords (already in .tres files):
- Common: `(0,-1)`
- Uncommon: `(0,-1), (-1,0), (1,0)`
- Rare: `(0,-2), (0,-1), (-1,0), (1,0)`
- Elite: `(0,-1), (-1,0), (1,0), (0,-2), (0,-3)`
- Legendary: `(0,-1), (-1,0), (-1,-1), (1,0), (1,-1), (0,-2), (0,-3)`
- Unique: `(0,-1), (0,1), (-1,-1), (-1,0), (-1,1), (1,1), (1,0), (1,-1), (0,-2), (0,-3)`

### Ice Gem — Frost Spread (horizontal line expanding outward)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (4)        Legendary (6)      Unique (9)
  □□□          □□□□□          □□□□□□□        □□□□□□□          □□□□□□□            □□□□□□□
  □G·          ·□G□·          ··□G□··        ··□G□··          ·····□·            ···□···
  □□□          □□□□□          □□□□□□□        □□·□·□□          ··□G□··            ···G···
                                             □□□□□□□          ·····□·            ···□···
                                                              □□□□□□□            ·····□·
                                                                                 □□□□□□□
```
Coords:
- Common: `(1,0)`
- Uncommon: `(-1,0), (1,0)`
- Rare: `(-2,0), (-1,0), (1,0)`
- Elite: `(-2,0), (-1,0), (1,0), (0,2)`
- Legendary: `(-2,0), (-1,0), (1,0), (2,0), (0,-1), (0,1)`
- Unique: `(-2,0), (-1,0), (1,0), (2,0), (0,-1), (0,1), (0,-2), (0,2), (-1,-1)`

### Thunder Gem — Lightning Bolt (diagonal zigzag)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (5)        Legendary (7)      Unique (9)
  □□□          □□·            □□·            □··              ·□·                ···
  □G□          □G□            □G□            □G□              □G□                □G□
  □□□          ·□□            ·□□            ·□□              ·□·                ···
                              □·□            □·□              □·□                □·□
                                             ··□              ··□                ··□
                                                              □□·                □□·
                                                                                 □·□
```
Coords:
- Common: `(1,-1)`
- Uncommon: `(1,-1), (-1,1)`
- Rare: `(1,-1), (-1,1), (0,1)`
- Elite: `(1,-1), (-1,1), (0,1), (-1,-1), (1,2)`
- Legendary: `(1,-1), (-1,1), (0,1), (-1,-1), (1,2), (0,-1), (0,2)`
- Unique: `(1,-1), (-1,1), (0,1), (-1,-1), (1,2), (0,-1), (0,2), (-1,0), (1,0)`

### Poison Gem — Seeping (diagonal spread, creeping outward)

```
Common (1)    Uncommon (2)   Rare (4)       Elite (5)        Legendary (7)      Unique (9)
  □□□          □□□            ·□□            ·□□              ·□·                ···
  □G□          □G□            □G□            □G□              □G□                □G□
  □·□          ·□·            ·□·            ·□·              ·□·                ···
                              □□□            □□·              □□·                □□·
                                                              □□·                □□·
```
Coords:
- Common: `(0,1)`
- Uncommon: `(-1,1), (1,1)`
- Rare: `(-1,1), (1,1), (-1,-1), (1,-1)`
- Elite: `(-1,1), (1,1), (-1,-1), (1,-1), (1,2)`
- Legendary: `(-1,1), (1,1), (-1,-1), (1,-1), (1,2), (0,-1), (0,1)`
- Unique: `(-1,1), (1,1), (-1,-1), (1,-1), (1,2), (0,-1), (0,1), (-1,0), (1,0)`

### Power / Mystic / Precision / Devastation — Diamond (standard expanding diamond)

These simple stat gems share the same shape: growing diamond.

```
Common (1)    Uncommon (2)   Rare (4)       Elite (5)        Legendary (8)      Unique (12)
  □·□          □□·□□          □□·□□          □□·□□            □□□·□□□            □□□·□□□
  ·G·          □·□·□          □···□          □···□            □□···□□            □□···□□
  □·□          □□·□□          □□·□□          ·····            □·····□            □·······□
  □□□          □□□□□          □□□□□          □···□            □□···□□            □□·····□□
                                             □□·□□            □□···□□            □·······□
                                                              □□□·□□□            □□·····□□
                                                                                 □□···□□
                                                                                 □□□·□□□
```
Coords:
- Common: `(0,-1), (0,1), (-1,0), (1,0)` (4 — standard cross)
- Uncommon: `(0,-1), (0,1), (-1,0), (1,0), (0,-2), (0,2)` (6)
- Rare: `(0,-1), (0,1), (-1,0), (1,0), (0,-2), (1,-1), (-1,-1), (1,1)` (8)
- Elite: uses `modifier_reach = 2` (full diamond, 12 cells)
- Legendary: uses `modifier_reach = 3` (full diamond, 24 cells)
- Unique: uses `modifier_reach = 3` + custom extensions

### Swift Gem — Arrow (forward-pointing wedge)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (5)        Legendary (7)      Unique (9)
  □·□          □·□            □·□            □·□              □□·□□              □□·□□
  □G□          □G□            ·G·            ·G·              □·□·□              □·□·□
  □□□          □·□            □·□            □·□              □·G·□              ·□G□·
                              □□□            □·□              □·□·□              □·□·□
                                             □□□              □□·□□              □□·□□
                                                                                 □□·□□
```
Coords:
- Common: `(0,-1)`
- Uncommon: `(0,-1), (0,1)`
- Rare: `(0,-1), (-1,0), (1,0)`
- Elite: `(0,-1), (-1,0), (1,0), (0,1), (0,-2)`
- Legendary: `(0,-1), (-1,0), (1,0), (0,1), (0,-2), (-1,-1), (1,-1)`
- Unique: `(0,-1), (-1,0), (1,0), (0,1), (0,-2), (-1,-1), (1,-1), (0,2), (-1,1)`

### MeGummy *(2x2 enchanted item)* — Full 3×3 (always max area) *(implemented)*

All rarities use the same 8-cell ring (the item's AoE identity):
```
All tiers (8)
  ···
  ·G·
  ···
```
Coords: `(-1,-1), (0,-1), (1,-1), (-1,0), (1,0), (-1,1), (0,1), (1,1)`

### Fortify / Vitality / Arcane / Lucky — Compact Cross (tight expansion)

Simple defensive/utility gems use a compact shape.

```
Common (2)    Uncommon (3)   Rare (4)       Elite (5)        Legendary (6)      Unique (8)
  □·□          □·□            □·□            ·□·              ·□·                ···
  ·G□          ·G·            ·G·            □G□              ·G·                ·G·
  □□□          □·□            ·□·            ·□·              ·□·                ···
                              □□□            □□□              □□□                □□□
```
Coords:
- Common: `(0,-1), (-1,0)`
- Uncommon: `(0,-1), (-1,0), (1,0)`
- Rare: `(0,-1), (-1,0), (1,0), (0,1)`
- Elite: `(0,-1), (-1,0), (1,0), (0,1), (-1,-1)`
- Legendary: `(0,-1), (-1,0), (1,0), (0,1), (-1,-1), (1,-1)`
- Unique: `(0,-1), (-1,0), (1,0), (0,1), (-1,-1), (1,-1), (-1,1), (1,1)`

### Berserker Fang *(1x2 enchanted item)* — Cleave (wide frontal arc)

```
Common (1)    Uncommon (3)   Rare (5)       Elite (6)        Legendary (8)      Unique (10)
  □□□          ···            ···            ···              ·····              ·····
  □G□          □G□            □G□            □G□              □□G□□              □□G□□
  □·□          □□□            □·□            □·□              □□·□□              ·····
                                             □□□              □□□□□              □□□□□
```
Coords:
- Common: `(0,1)`
- Uncommon: `(-1,-1), (0,-1), (1,-1)`
- Rare: `(-1,-1), (0,-1), (1,-1), (0,1), (0,-2)`
- Elite: `(-1,-1), (0,-1), (1,-1), (0,1), (-1,0), (1,0)`
- Legendary: `(-1,-1), (0,-1), (1,-1), (0,1), (-1,0), (1,0), (-2,-1), (2,-1)`
- Unique: `(-1,-1), (0,-1), (1,-1), (0,1), (-1,0), (1,0), (-2,-1), (2,-1), (-2,0), (2,0)`

### Vampiric Fang *(1x2 enchanted item)* — Fangs (two prongs extending)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (5)        Legendary (7)      Unique (9)
  □·□          ·□·            ·□·            ·□·              ·□·                ·□·
  □G□          □G□            □G□            □G□              ·G·                ·G·
  □□□          □□□            □·□            ·□·              ·□·                ·□·
                                             □□□              ·□·                ·□·
                                                              □□□                ·□·
```
Coords:
- Common: `(0,-1)`
- Uncommon: `(-1,-1), (1,-1)`
- Rare: `(-1,-1), (1,-1), (0,1)`
- Elite: `(-1,-1), (1,-1), (0,1), (-1,1), (1,1)`
- Legendary: `(-1,-1), (1,-1), (0,1), (-1,1), (1,1), (-1,0), (1,0)`
- Unique: `(-1,-1), (1,-1), (0,1), (-1,1), (1,1), (-1,0), (1,0), (0,-1), (0,2)`

### Echo Stone *(L-shape enchanted item)* — Echo (stacked horizontal lines)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (5)        Legendary (7)      Unique (8)
  □□□          □□□            □□□            ···              ···                ···
  □G□          ·G□            ·G·            □G□              ·G·                ·G·
  □·□          □·□            □·□            ···              ···                ···
                                             □□□              □□□                □□□
```
Coords:
- Common: `(0,1)`
- Uncommon: `(-1,0), (0,1)`
- Rare: `(-1,0), (1,0), (0,1)`
- Elite: `(-1,0), (1,0), (-1,-1), (0,-1), (1,-1)`
- Legendary: `(-1,0), (1,0), (-1,-1), (0,-1), (1,-1), (-1,1), (1,1)`
- Unique: `(-1,0), (1,0), (-1,-1), (0,-1), (1,-1), (-1,1), (0,1), (1,1)`

### Lucky Bounce Gem — Ricochet (scattered distant cells)

```
Common (1)    Uncommon (2)   Rare (3)       Elite (4)        Legendary (6)      Unique (8)
  □□□□□        □□□□□          □□·□□          □□·□□            □·□·□              □·□·□
  □□G□□        □□G□□          □□G□□          □□G□□            □□G□□              □□G□□
  □□·□□        □·□·□          □·□·□          □·□·□            □·□·□              □·□·□
                                             □□□□□            □□·□□              □□·□□
                                                                                 □□□□□
```
Coords:
- Common: `(0,2)`
- Uncommon: `(-1,1), (1,1)`
- Rare: `(-1,1), (1,1), (0,-2)`
- Elite: `(-1,1), (1,1), (0,-2), (0,2)`
- Legendary: `(-1,1), (1,1), (0,-2), (0,2), (-1,-1), (1,-1)`
- Unique: `(-1,1), (1,1), (0,-2), (0,2), (-1,-1), (1,-1), (-1,-2), (1,-2)`

### Healing Gem *(1x1 gem)* — Radiance (plus sign expanding)

```
Common (1)    Uncommon (2)   Rare (4)       Elite (5)        Legendary (8)      Unique (12)
  □·□          □·□            □·□            □□·□□            □□·□□              □□□·□□□
  □G□          □G□            ·G·            □·G·□            □·G·□              □□·G·□□
  □□□          □·□            □·□            □□·□□            □·□·□              □·□□□·□
                              □□□            □□□□□            □□·□□              □□·G·□□
                                                              □□□□□              □□□·□□□
```
Coords:
- Common: `(0,-1)`
- Uncommon: `(0,-1), (0,1)`
- Rare: `(0,-1), (0,1), (-1,0), (1,0)`
- Elite: `(0,-1), (0,1), (-1,0), (1,0), (0,-2)`
- Legendary: `(0,-1), (0,1), (-1,0), (1,0), (0,-2), (0,2), (-2,0), (2,0)`
- Unique: uses `modifier_reach = 2` (full diamond, 12 cells)

### Thorns Mail *(1x2 enchanted item)* — Spikes (star pattern, pointy)

```
Common (1)    Uncommon (2)   Rare (4)       Elite (6)        Legendary (8)      Unique (10)
  □□□          □·□            ·□·            ·□·              ·□·                ·□□□·
  □G□          □G□            □G□            ·G·              ·G·                □·G·□
  □·□          □·□            ·□·            ·□·              ·□·                ·□□□·
                                             □□□              ·□·                ·□·□·
                                                              □□□                □□□□□
```
Coords:
- Common: `(0,1)`
- Uncommon: `(0,-1), (0,1)`
- Rare: `(-1,-1), (1,-1), (-1,1), (1,1)`
- Elite: `(-1,-1), (1,-1), (-1,1), (1,1), (-1,0), (1,0)`
- Legendary: `(-1,-1), (1,-1), (-1,1), (1,1), (-1,0), (1,0), (0,-1), (0,1)`
- Unique: `(-1,-1), (1,-1), (-1,1), (1,1), (-1,0), (1,0), (0,-1), (0,1), (-2,-2), (2,-2)`

### Silence Rune *(1x2)* / Cleanse Gem *(1x1)* / Phoenix Feather *(2x2)* — Aura (ring expanding outward)

Status-effect modifiers share a ring reach pattern (inventory shape differs per item).

```
Common (1)    Uncommon (2)   Rare (4)       Elite (6)        Legendary (8)      Unique (12)
  □·□          □·□            □·□            ·□·              ···                ·····
  □G□          ·G□            ·G·            □G□              ·G·                ··G··
  □□□          □□□            □·□            ·□·              ···                ·····
```
Coords:
- Common: `(0,-1)`
- Uncommon: `(0,-1), (-1,0)`
- Rare: `(0,-1), (-1,0), (1,0), (0,1)` (full cross)
- Elite: `(-1,-1), (1,-1), (-1,0), (1,0), (-1,1), (1,1)` (6 — ring minus top/bottom)
- Legendary: full 8-cell ring (all adjacent)
- Unique: uses `modifier_reach = 2` (full diamond, 12 cells)

### Tradeoff Enchanted Items (Blood Pact Relic, Phantom Shard, Oath Seal, Hunger Maw, Chaos Orb, Mirror Fragment)

Tradeoff items are powerful and complex — their reach starts small and grows slowly.

```
Common (1)    Uncommon (1)   Rare (2)       Elite (3)        Legendary (4)      Unique (6)
  □□□          □·□            □·□            □·□              ·□·                ·□·
  □G□          □G□            ·G□            ·G·              □G□                ·G·
  □·□          □□□            □□□            □·□              ·□·                ·□·
```
Coords:
- Common: `(0,1)`
- Uncommon: `(0,-1)`
- Rare: `(0,-1), (-1,0)`
- Elite: `(0,-1), (-1,0), (1,0)`
- Legendary: `(-1,-1), (1,-1), (-1,1), (1,1)` (diagonals only — unique visual)
- Unique: `(-1,-1), (1,-1), (-1,1), (1,1), (-1,0), (1,0)` (ring without top/bottom)

---

## Existing Gems (Implemented)

### Fire Gem
*"A shard of captured flame, eager to ignite."*

| Adjacent To | Effect |
|---|---|
| Melee | +Magical ATK, Burn chance |
| Ranged | +Magical ATK, Burn chance |
| Magic | +Magical ATK, Burn chance, grants **Fire Bolt** skill |

### Ice Gem
*"Frozen essence that numbs the body and slows the mind."*

| Adjacent To | Effect |
|---|---|
| Melee | +Magical ATK, Chilled chance (speed reduction) |
| Ranged | +Magical ATK, Chilled chance |
| Magic | +Magical ATK, Chilled chance, grants **Ice Shard** skill |

### Thunder Gem
*"A crackling core of bottled lightning."*

| Adjacent To | Effect |
|---|---|
| Melee | +Magical ATK, Shocked chance (skip turn) |
| Ranged | +Magical ATK, Shocked chance |
| Magic | +Magical ATK, Shocked chance, grants **Thunder Bolt** skill |

### Poison Gem
*"A toxic crystal that seeps venom into every strike."*

| Adjacent To | Effect |
|---|---|
| Melee | +Magical ATK, Poisoned chance (DoT) |
| Ranged | +Magical ATK, Poisoned chance |
| Magic | +Magical ATK, Poisoned chance |

### Power Gem
*"Raw physical force condensed into crystal form."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Physical ATK % |

### Mystic Gem
*"Arcane energy made tangible."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Magical ATK % |

### Precision Gem
*"A perfectly cut gem that guides the hand to weak points."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Crit Rate + Crit Damage |

### Devastation Gem
*"Amplifies the destructive force of critical strikes."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Crit Damage % |

### Swift Gem
*"A weightless stone that quickens reflexes."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Speed (flat) |
| Armor (planned) | +Dodge chance |

### MeGummy *(enchanted item — 2x2)*
*"All attacks become AoE. WARNING: Melee attacks cost 10 HP per use."*

| Adjacent To | Effect |
|---|---|
| Melee/Ranged | +Magical ATK, **force AoE**, 10 HP cost per attack |
| Magic | +Magical ATK, **force AoE**, grants **Explosion** skill (no HP cost) |

---

## Existing Modifiers to Rework

### Vampiric Fang *(enchanted item — 1x2)* (currently: Vampiric Gem, +Phys ATK flat placeholder)
*"It drinks deep from every wound you inflict."*

| Adjacent To | Effect |
|---|---|
| All weapons | Lifesteal: heal X% of damage dealt on hit |

Scaling: Common 5% -> Legendary 20% lifesteal.

### Echo Stone *(enchanted item — L-shape)* (currently: Ripple Gem)
*"The stone resonates with each swing, echoing the strike."*

| Adjacent To | Effect |
|---|---|
| All weapons | Chance for extra attacks. Each extra attack = full proc rolls + full damage (to enemy AND self) |

Scaling:
- Common: 10% chance for 1 extra attack
- Uncommon: 20% chance for 1 extra attack
- Rare: 35% chance for 1 extra attack
- Elite: 50% chance for 1 extra attack
- Legendary: 100% chance for 1 extra attack
- Unique: 2 extra attacks guaranteed

---

## New Simple Gems (1x1, data only, no code changes)

### Fortify Gem
*"A dense mineral that hardens everything around it."*

| Adjacent To | Effect |
|---|---|
| All weapons/armor | +Physical DEF + Magical DEF |

### Vitality Gem
*"Pulses with the rhythm of a living heart."*

| Adjacent To | Effect |
|---|---|
| All weapons/armor | +Max HP (flat/%) |

### Arcane Gem
*"A reservoir of magical potential."*

| Adjacent To | Effect |
|---|---|
| All weapons/armor | +Max MP (flat/%) |

### Lucky Gem
*"Fortune favors whoever carries this improbable stone."*

| Adjacent To | Effect |
|---|---|
| All weapons/armor | +Luck (feeds crit via LUCK_CRIT_SCALING) |

### Berserker Fang *(enchanted item — 1x2)*
*"Rage made solid. It demands blood — yours or theirs."*

| Adjacent To | Effect |
|---|---|
| All weapons | +Huge Physical ATK, HP cost per attack |

Physical MeGummy — big damage, self-harm, no AoE.

---

## New Mechanic Modifiers (need code changes)

### Lucky Bounce Gem
*"The stone skips fate like a pebble on still water."*

| Adjacent To | Effect |
|---|---|
| All weapons | Chance to chain attack to a different enemy after hitting |

Scaling: Common 10% -> Legendary 40% bounce chance.

### Healing Gem
*"Warm light radiates from within, mending flesh and spirit."*

| Adjacent To | Effect |
|---|---|
| Weapons | Heal self X HP on hit |
| Armor | Passive HP regen per turn |

### Cleanse Gem
*"Pure water crystallized. It washes away corruption."*

| Adjacent To | Effect |
|---|---|
| Weapons | Chance to remove 1 debuff from self on hit |
| Armor | Chance to resist new debuffs |

### Phoenix Feather *(enchanted item — 2x2)*
*"Death is merely a door, and this feather holds the key."*

| Adjacent To | Effect |
|---|---|
| Armor only | Auto-revive once per battle at X% HP when KO'd |

### Thorns Mail *(enchanted item — 1x2)*
*"A jagged relic that punishes those who dare strike."*

| Adjacent To | Effect |
|---|---|
| Armor only | Reflect X damage when hit |

---

## Tradeoff Enchanted Items (different behavior per equipment slot)

These enchanted items change behavior depending on what they're adjacent to.
Every effect has a meaningful tradeoff — power at a cost.
All tradeoff modifiers are enchanted items (larger inventory shapes) due to their build-defining power.

### Silence Rune *(enchanted item — 1x2)*
*"The silence sharpens your senses. You hear the breath of a beetle, the heartbeat of a butterfly."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Proc Silenced on enemy (can't use skills) | — |
| **Dagger** | Proc Silenced on enemy (can't use skills) | — |
| **Bow** | Proc Silenced on enemy (can't use skills) | — |
| **Staff** | Proc Silenced on enemy (can't use skills) | — |
| **Helmet** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |
| **Chest** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |
| **Legs** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |
| **Boots** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |
| **Gloves** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |
| **Necklace** | +huge Crit Rate, +huge Dodge | Self-silenced (can't use skills) |

### Blood Pact Relic *(enchanted item — 2x2)*
*"A crimson relic that feeds on its bearer's vitality."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | +massive Phys ATK | 5% max HP lost per turn |
| **Dagger** | Attacks apply Bleed (stacking DoT) | You also bleed (1 stack per attack on self) |
| **Bow** | Lifesteal 15% of damage dealt | -30% Max HP while equipped |
| **Staff** | Drain — steal MP on hit | Healing spells deal damage instead of healing |
| **Helmet** | Blood Sight — +Crit Rate | -15% Max HP |
| **Chest** | Blood Armor — thorns (reflect damage) | Healing received halved |
| **Legs** | Blood Rush — +Speed when below 50% HP | -Speed when above 50% HP |
| **Boots** | Blood Trail — 2% HP regen when moving/attacking | Lose 2% HP per turn when defending |
| **Gloves** | Blood Grip — +Phys ATK scaling per missing HP% | -Phys ATK at full HP |
| **Necklace** | Blood Bond — link HP with ally, share damage 50/50 | Both take damage when one is hit |

### Phantom Shard *(enchanted item — 1x2)*
*"Phasing between worlds, it grants power at the cost of presence."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Phantom Slash — bypass 50% enemy DEF | Your own DEF drops to 0 |
| **Dagger** | Phase Strike — 30% dodge after attacking | -20% damage |
| **Bow** | Ghost Arrow — attacks never miss | Attacks can never crit |
| **Staff** | Spirit Channel — skills cost 0 MP | Skill damage halved |
| **Helmet** | Ethereal Mind — immune to Silence + Shocked | -50% Magical DEF |
| **Chest** | Phase Body — 25% dodge chance | Take double damage when hit |
| **Legs** | Phase Walk — immune to slow effects | Can't benefit from Speed buffs |
| **Boots** | Ghost Step — always act first on turn 1 | -20% Speed rest of battle |
| **Gloves** | Phantom Hands — attacks ignore shields | Can't gain shields yourself |
| **Necklace** | Fade — 15% chance enemies skip you as target | Can't taunt or guard allies |

### Oath Seal *(enchanted item — L-shape)*
*"Swear an oath. Break it, and pay the price."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Sworn Enemy — +50% damage to first target | Must kill it before switching (reduced damage to others) |
| **Dagger** | First Blood — guaranteed crit on 1st attack | -Crit Rate rest of battle |
| **Bow** | Hunter's Mark — +damage grows per consecutive hit on same target | Resets on target switch |
| **Staff** | Healer's Oath — +100% healing power | Can't deal direct damage |
| **Helmet** | Iron Will — immune to all debuffs | Can't receive buffs either |
| **Chest** | Guardian — adjacent ally takes 30% less damage | You take that 30% instead |
| **Legs** | Stalwart — can't be knocked below 1 HP once per battle | After trigger, -50% DEF rest of battle |
| **Boots** | Rooted — +huge DEF while defending | -DEF when attacking |
| **Gloves** | Duelist — +damage in 1v1 (one enemy alive) | -damage when multiple enemies alive |
| **Necklace** | Martyr's Chain — revive an ally once at your HP cost | You lose the HP they gain |

### Hunger Maw *(enchanted item — 2x2)*
*"It feeds. It grows. It is never satisfied."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Feast — +3 ATK per kill (stacks all battle) | Start battle with -5 ATK |
| **Dagger** | Predator — +1 Speed per kill (stacks) | -3 Speed at battle start |
| **Bow** | +2% Crit Rate per kill (stacks) | -5% Crit Rate at start |
| **Staff** | Soul Harvest — each kill restores 25% MP | Spells cost +50% MP |
| **Helmet** | Glutton — absorb +1 random stat from killed enemies | -10% all stats at start |
| **Chest** | Insatiable — gain shield = 10% of damage dealt | Can't be healed |
| **Legs** | +1% dodge per turn survived (stacks) | 0% dodge on turn 1 |
| **Boots** | +Speed each turn (accelerating) | Start at -20% Speed |
| **Gloves** | Attacks gain +2 flat damage per hit landed (resets per battle) | First hit deals -5 damage |
| **Necklace** | +3% lifesteal per kill (stacks) | 0% lifesteal until first kill |

### Chaos Orb *(enchanted item — L-shape)*
*"Order is an illusion. Embrace the beautiful randomness."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Damage range 50%-200% (avg higher than normal) | Unpredictable |
| **Dagger** | 25% chance triple damage | 25% chance zero damage |
| **Bow** | Scatter Shot — hits all enemies | At 40% damage each |
| **Staff** | Spells gain random 0-100% bonus power | 10% chance to hit an ally instead |
| **Helmet** | +huge Crit Damage | Crits against you also deal bonus damage |
| **Chest** | 50% negate damage completely | 50% take 1.5x damage |
| **Legs** | Random turn order each round (might go first or last) | Uncontrollable |
| **Boots** | Dodge one attack per battle automatically | Can't dodge otherwise |
| **Gloves** | Each attack randomly picks a stat to scale from (ATK/MAG/SPD/LCK) | Might scale from worst stat |
| **Necklace** | At battle start: randomly double one stat, halve another | Pure gamble |

### Mirror Fragment *(enchanted item — 1x2)*
*"What you give, you receive. What you receive, you give."*

| Adjacent To | Effect | Tradeoff |
|---|---|---|
| **Sword** | Copy last debuff on you onto the enemy you hit | You keep the debuff too |
| **Dagger** | If enemy attacked you last turn, next hit +50% damage | If they didn't, -25% damage |
| **Bow** | Missed attacks bounce to random enemy at half damage | No bonus on hit |
| **Staff** | 20% chance to reflect enemy skill back at them | 10% chance to reflect your own spell onto yourself |
| **Helmet** | Enemy that debuffs you gets the same debuff | You still get debuffed |
| **Chest** | Return 30% of damage taken as magic damage to attacker | -15% DEF |
| **Legs** | Counter-kick — 20% chance to counterattack melee hits | Take +10% melee damage |
| **Boots** | Mirrored Step — match speed of fastest enemy | No benefit if already faster |
| **Gloves** | Echo — basic attacks hit twice at 60% each (120% total) | No single big hits possible |
| **Necklace** | Symmetry — your buffs also apply to your current target | Enemies benefit from your buffs |

---

## New Status Effects Needed

| Status | Mechanic | Used By |
|---|---|---|
| **Silenced** | Can't use skills, basic attack only | Silence Rune |
| **Bleeding** | Physical DoT, scales with damage dealt | Blood Pact Relic |

---

## Implementation Requirements

### Enum Expansion
- `WeaponType`: SWORD, DAGGER, AXE, MACE, SHIELD, BOW, STAFF (replace MELEE/RANGED/MAGIC)
- `StatusEffectType`: add SILENCED, BLEEDING

### ConditionalModifierRule Expansion
- Add `target_armor_slot: Enums.ArmorSlot` for armor-specific rules
- Add `target_weapon_subtype: Enums.WeaponType` for subtype matching

### New Fields on ConditionalModifierRule
- `lifesteal_percent: float` — heal % of damage dealt
- `extra_attack_chance: float` — chance for additional attack
- `extra_attack_count: int` — max extra attacks
- `bounce_chance: float` — chain to another enemy
- `def_bypass_percent: float` — ignore % of target DEF
- `reflect_damage: int` — flat damage reflected when hit
- `heal_on_hit: int` — heal self on hit
- `hp_regen_per_turn: int` — passive HP regen
- `dodge_chance: float` — evasion chance
- `debuff_resist_chance: float` — resist incoming debuffs
- `auto_revive: bool` — revive once per battle
- `revive_hp_percent: float` — HP% on revive
- `self_silence: bool` — can't use skills (Silence Rune on armor)
- `damage_variance_min: float` — min damage multiplier (Chaos)
- `damage_variance_max: float` — max damage multiplier (Chaos)
- `stacking_stat_on_kill: Enums.Stat` — stat that grows per kill (Hunger)
- `stacking_stat_value: float` — amount per stack
- `start_penalty_stat: Enums.Stat` — stat reduced at battle start (Hunger tradeoff)
- `start_penalty_value: float` — penalty amount

### Combat System Changes
- `_apply_extra_attacks()` — re-run attack with full proc rolls (Multiple Strike)
- `_apply_bounce()` — pick random other enemy, run attack (Lucky Bounce)
- `_apply_lifesteal()` — heal source after damage (Vampiric)
- `_check_auto_revive()` — on KO, check for resurrect gem
- `_check_silence()` — prevent skill use if silenced
- Stacking buff tracking per battle (Hunger Maw)
- Conditional stat modifiers (below 50% HP, defending, etc.)

---

## Implementation Priority

1. **Batch 1 — Data only (gems)**: Fortify, Vitality, Arcane, Lucky (1x1 gems)
2. **Batch 2 — Rework existing**: Vampiric Fang (1x2, lifesteal), Echo Stone (L, extra attacks), Swift (dodge on armor), Berserker Fang (1x2), MeGummy (2x2)
3. **Batch 3 — New status + mechanics**: Silence Rune (1x2), Thorns Mail (1x2), Lucky Bounce Gem (1x1), Healing Gem (1x1), Cleanse Gem (1x1), Phoenix Feather (2x2)
4. **Batch 4 — Tradeoff enchanted items**: Blood Pact Relic (2x2), Phantom Shard (1x2), Oath Seal (L), Hunger Maw (2x2), Chaos Orb (L), Mirror Fragment (1x2) — need WeaponType expansion + armor slot rules

---

## Inventory Shape Reference

| Shape | Size | File | Used By |
|---|---|---|---|
| 1x1 | 1 cell | `shape_1x1.tres` | All gems |
| 1x2 | 2 cells | `shape_1x2.tres` | Vampiric Fang, Berserker Fang, Silence Rune, Phantom Shard, Mirror Fragment, Thorns Mail |
| 2x2 | 4 cells | `shape_2x2.tres` | MeGummy, Blood Pact Relic, Hunger Maw, Phoenix Feather |
| L-shape | 3 cells | `shape_l.tres` | Echo Stone, Oath Seal, Chaos Orb |
