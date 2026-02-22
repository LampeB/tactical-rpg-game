# Tactical RPG - Game Design & Technical Architecture

## Table of Contents
1. [Game Overview](#game-overview)
2. [Technical Architecture](#technical-architecture)
3. [Project Structure](#project-structure)
4. [Data Architecture](#data-architecture)
5. [Core Systems](#core-systems)
6. [Enums & Constants](#enums--constants)
7. [Content Summary](#content-summary)
8. [Known Constraints & Patterns](#known-constraints--patterns)

---

## Game Overview

### Core Concept
A tactical RPG inspired by classic JRPGs, featuring:
- **Exploration:** Overworld map with explorable locations and progressive unlocks
- **Combat:** Frequency-based turn system (ATB-style) with speed-driven turn order
- **Character Building:** Tetris-style grid inventory with gem modifiers and passive skill trees
- **Party Management:** Roster of characters with active squad selection

### Technical Scope
- **Engine:** Godot 4.6
- **Language:** GDScript
- **Renderer:** GL Compatibility
- **Resolution:** 1920x1080 (canvas stretch mode)
- **Platform:** PC (single-player, offline)

---

## Technical Architecture

### Autoload Singletons (9)

The game uses Godot's autoload system for global managers. These are registered in `project.godot` and live in `scripts/autoload/`.

| Autoload | File | Purpose |
|----------|------|---------|
| **DebugLogger** | `debug_logger.gd` | Runtime logging to `debug_log.txt` (max 200 lines, rolling) |
| **EventBus** | `event_bus.gd` | Global signal bus for decoupled communication between systems |
| **ItemDatabase** | `item_database.gd` | Loads and indexes all ItemData from `data/items/` subdirectories |
| **CharacterDatabase** | `character_database.gd` | Loads and indexes CharacterData from `data/characters/` |
| **PassiveTreeDatabase** | `passive_tree_database.gd` | Loads PassiveTreeData from `data/passive_trees/` |
| **GameManager** | `game_manager.gd` | Game state: party, gold, story flags. Handles `new_game()` initialization |
| **SaveManager** | `save_manager.gd` | Save/load to `user://save.json`. Tracks playtime |
| **SceneManager** | `scene_manager.gd` | Scene transitions with fade effects, history stack, data passing |
| **InputManager** | `input_manager.gd` | Custom input bindings persisted to `user://input_bindings.json` |

### Scene Management Pattern

SceneManager provides navigation with data passing:
- `push_scene(path, data)` - Navigate forward (adds to history stack)
- `pop_scene(data)` - Go back
- `replace_scene(path, data)` - Replace current scene
- Target scene receives data via `receive_data(data: Dictionary)` after initialization
- Transitions use a 0.3s fade overlay on CanvasLayer 100

### Signal Architecture (EventBus)

EventBus provides decoupled communication. Key signal categories:

**Inventory:** `item_placed`, `item_removed`, `item_rotated`, `inventory_changed`, `stash_changed`
**Combat:** `combat_started`, `combat_ended`
**Progression:** `passive_unlocked`, `gold_changed`
**Loot:** `loot_screen_closed`
**Save/Load:** `game_saved`, `game_loaded`
**Overworld:** `location_prompt_visible`, `show_message`

### class_name vs Autoload Constraint

**Critical pattern:** Scripts with `class_name` compile at engine startup BEFORE autoloads are registered. This means:
- class_name scripts (CombatManager, CombatEntity, LootGenerator, GridInventory, etc.) **cannot** reference autoloads (EventBus, GameManager, Constants, etc.)
- Scene scripts bridge autoload calls via signals or pass data directly
- PassiveEffects (class_name, NOT autoload) CAN be referenced by other class_name scripts

---

## Project Structure

```
tactical-rpg-game/
├── project.godot                  # Engine config (autoloads, input, display)
├── ToDoList.md                    # Feature tracking
├── GameDesignDocumentationAndTechnicalArchitecture.md
├── GameDevelopmentRoadmap.md
│
├── scripts/
│   ├── autoload/                  # 9 singleton managers (see above)
│   ├── systems/
│   │   ├── combat/
│   │   │   ├── combat_manager.gd  # CombatManager - turn order, action execution
│   │   │   ├── combat_entity.gd   # CombatEntity - runtime entity state
│   │   │   ├── damage_calculator.gd # DamageCalculator - damage formulas
│   │   │   └── enemy_ai.gd       # EnemyAI - enemy turn decisions
│   │   ├── inventory/
│   │   │   ├── grid_inventory.gd  # GridInventory - tetris placement logic
│   │   │   ├── inventory_undo.gd  # InventoryUndo - undo/redo system
│   │   │   └── tool_modifier_state.gd # ToolModifierState - gem effect cache
│   │   └── loot/
│   │       └── loot_generator.gd  # LootGenerator - loot rolling from tables
│   ├── resources/                 # Resource class definitions (extends Resource)
│   │   ├── character_data.gd      # CharacterData
│   │   ├── item_data.gd           # ItemData
│   │   ├── skill_data.gd          # SkillData
│   │   ├── enemy_data.gd          # EnemyData
│   │   ├── encounter_data.gd      # EncounterData
│   │   ├── encounter_zone_data.gd # EncounterZoneData
│   │   ├── location_data.gd       # LocationData
│   │   ├── loot_table.gd          # LootTable
│   │   ├── loot_entry.gd          # LootEntry
│   │   ├── grid_template.gd       # GridTemplate
│   │   ├── item_shape.gd          # ItemShape
│   │   ├── status_effect_data.gd  # StatusEffectData
│   │   ├── passive_tree_data.gd   # PassiveTreeData
│   │   ├── passive_node_data.gd   # PassiveNodeData
│   │   ├── stat_modifier.gd       # StatModifier
│   │   ├── conditional_modifier_rule.gd
│   │   ├── status_interaction_rule.gd
│   │   ├── shop_data.gd           # ShopData
│   │   └── save_data.gd           # SaveData
│   ├── models/
│   │   └── party.gd               # Party - roster, squad, stash, vitals, passives
│   └── utils/
│       ├── constants.gd           # Constants - magic numbers, colors, sizes
│       ├── enums.gd               # Enums - all game enumerations
│       ├── passive_effects.gd     # PassiveEffects - effect ID constants
│       └── item_upgrade_system.gd # Item upgrade/enchantment utilities
│
├── scenes/
│   ├── main_menu/
│   │   └── main_menu.tscn         # Game entry (New Game / Load)
│   ├── battle/
│   │   ├── battle.tscn            # Main battle scene controller
│   │   └── ui/
│   │       ├── action_menu.tscn   # Combat action selection (2-column)
│   │       ├── battle_log.tscn    # Combat message log
│   │       ├── battle_sprite.tscn # Entity sprite with animations
│   │       ├── damage_popup.tscn  # Floating damage numbers
│   │       ├── entity_status_bar.tscn # HP/MP bars with portrait
│   │       └── turn_order_bar.tscn # Visual turn order display
│   ├── inventory/
│   │   ├── inventory.tscn         # Main inventory interface
│   │   └── ui/
│   │       ├── character_tabs.tscn
│   │       ├── drag_preview.tscn
│   │       ├── equipment_slots_panel.tscn
│   │       ├── grid_cell.tscn
│   │       ├── grid_panel.tscn
│   │       ├── item_tooltip.tscn
│   │       ├── stash_panel.tscn
│   │       └── stash_slot.tscn
│   ├── loot/
│   │   └── loot.tscn              # Post-battle loot distribution
│   ├── character_hub/
│   │   └── character_hub.tscn     # Character management hub
│   ├── character_stats/
│   │   └── character_stats.tscn   # Detailed stat view
│   ├── passive_tree/
│   │   ├── passive_tree.tscn      # Skill tree interface
│   │   └── ui/tree_view.tscn
│   ├── squad/
│   │   └── squad.tscn             # Active party selection
│   ├── settings/
│   │   └── settings_menu.tscn     # Game settings
│   └── world/
│       ├── world.tscn             # World map container
│       ├── overworld.tscn         # Playable overworld
│       ├── encounter_zone.tscn    # Random encounter trigger
│       ├── roaming_enemy.tscn     # Overworld enemy
│       ├── location_marker.tscn   # POI marker
│       └── objects/               # Decorative world objects (bush, tree, rock, etc.)
│
├── data/                          # All .tres resource files
│   ├── characters/                # CharacterData (warrior, mage, rogue)
│   ├── enemies/                   # EnemyData (goblin, slime)
│   ├── encounters/                # EncounterData (goblins, slimes, bandits)
│   ├── encounter_zones/           # EncounterZoneData (grasslands, forest)
│   ├── skills/                    # SkillData (slash, fire_bolt, heal_minor, etc.)
│   ├── status_effects/            # StatusEffectData (burn, poisoned, chilled, shocked)
│   ├── items/
│   │   ├── weapons/               # 9 weapons (swords, daggers, maces, staves, bows, axes)
│   │   ├── armor/                 # 7 armor pieces (helmet, chestplate, gloves, legs, boots, shield)
│   │   ├── consumables/           # Potions
│   │   └── modifiers/             # 15 gems (fire, ice, thunder, power, precision, etc.)
│   ├── shapes/                    # ItemShape (1x1, 1x2, L, T, bow, etc.)
│   ├── grid_templates/            # GridTemplate per character class
│   ├── locations/                 # LocationData (towns, caves, lake)
│   ├── loot_tables/               # LootTable (per-enemy and generic)
│   └── passive_trees/             # PassiveTreeData per character class
│
├── assets/
│   ├── sprites/                   # Character, enemy, and object sprites
│   ├── themes/                    # UI themes
│   └── tilesets/                  # Map tilesets
│
└── tests/                         # Test scripts and scenes
```

---

## Data Architecture

All game content is defined as Godot Resource files (`.tres`) in the `data/` directory. Database autoloads scan their directories at startup and index resources by ID.

### Resource Types

#### Character & Enemy
- **CharacterData** - Display name, class, portrait, sprite, 8 base stats, grid_template, innate_skills
- **EnemyData** - Display name, sprite, stats, damage_type, skills, gold_reward, loot_table

#### Items
- **ItemData** - Name, icon, type (ACTIVE_TOOL/PASSIVE_GEAR/MODIFIER/CONSUMABLE/MATERIAL), rarity, shape, equipment category, stat_modifiers, combat stats (damage_type, base_power, magical_power, granted_skills), modifier stats (reach, bonuses, conditional_rules), consumable (use_skill), base_price
- **ItemShape** - Cells array (Vector2i offsets), rotation_states (1/2/4)
- **StatModifier** - Stat enum, modifier_type (FLAT/PERCENT), value

#### Combat
- **SkillData** - Name, icon, usage (COMBAT/MENU/BOTH), MP cost, cooldown, target_type, damage (type + power + scaling), healing (amount + percent), applied_statuses
- **StatusEffectData** - Category, duration, tick_damage, stat_modifiers, speed/damage multipliers, action/skill restrictions, stacking rules
- **StatusInteractionRule** - How status effects interact (cancel, amplify, transform, trigger, immunity)

#### World
- **EncounterData** - Enemy list, can_flee, bonus_gold, override_loot_table
- **EncounterZoneData** - Encounter pool with weights, base encounter chance, steps between checks
- **LocationData** - Name, scene_path, entrance_position, unlock_flag, type (TOWN/DUNGEON/LANDMARK/SHOP/INN/LAKE/CAVE), fast_travel settings
- **LootTable** - Entries (LootEntry[]), roll_count, guaranteed_drops
- **LootEntry** - Item reference, drop_chance (0-1), weight

#### Progression
- **PassiveTreeData** - Character ID, nodes array
- **PassiveNodeData** - Stat modifiers, special_effect_id, gold_cost, prerequisites (node IDs), UI position
- **GridTemplate** - Inventory grid dimensions (width, height), active cells

#### Persistence
- **SaveData** - Party data, stash items, gold, story flags, world state, playtime, timestamp

### Database Loading Pattern

Each database autoload scans a directory, loads `.tres` files, and indexes them:
```
ItemDatabase     → data/items/**/*.tres    → lookup by ID, type, rarity
CharacterDatabase → data/characters/*.tres → lookup by character ID
PassiveTreeDatabase → data/passive_trees/*.tres → lookup by character ID
```
IDs are auto-assigned from filename if not set in the resource.

---

## Core Systems

### 1. Combat System

**Files:** `scripts/systems/combat/combat_manager.gd`, `combat_entity.gd`, `damage_calculator.gd`, `enemy_ai.gd`

#### Turn Order (Frequency-Based ATB)
- Each entity has `time_until_turn` calculated from speed: `100.0 / speed`
- Entity with lowest `time_until_turn` acts next
- After acting, timer increments by speed-based formula
- First round: FIRST_STRIKE passive grants immediate turn (0.0 delay)
- Turn order simulated 10 turns ahead for UI display

#### Combat Flow
1. `start_combat()` initializes all entities, applies start-of-battle passives (e.g., START_SHIELD)
2. `advance_turn()` finds next entity, ticks status effects, checks can_act()
3. Player selects action via UI / EnemyAI decides automatically
4. `execute_action()` processes damage, status effects, death
5. `combat_finished` signal on victory (all enemies dead) or defeat (all players dead)

#### Actions
- **Attack** - Hybrid damage: `(atk * scaling + power) - def * 0.5`, minimum 1
- **Defend** - Reduces incoming damage by 50% for 1 turn
- **Skill** - Uses MP, has cooldown, can damage/heal/apply status effects
- **Flee** - Instant exit if `encounter.can_flee == true`

#### Damage Calculation
- Crit chance: `5% + luck * 0.1% + stat bonus` (capped at 95%)
- Crit multiplier: `150% + stat bonus`
- Status effect damage multiplier applied to final damage
- Defend reduces damage by 50%

#### Passive Abilities (from Skill Trees)
- **COUNTER_ATTACK** (15% chance) - Reflect attack back
- **LIFESTEAL_5 / LIFESTEAL_10** - Heal 5%/10% of damage dealt
- **START_SHIELD** - 15 HP shield at battle start
- **THORNS** - Reflect 5 flat damage when hit
- **MANA_REGEN** - Restore 3 MP at turn start
- **EVASION** (10% chance) - Dodge attack entirely
- **FIRST_STRIKE** - +50 speed in round 1
- **DOUBLE_GOLD** - Double gold earned from battle

#### Status Effects
- **Burn / Poisoned** - Tick damage each turn
- **Chilled** - Speed reduction
- **Shocked** - Chance to skip turn
- Applied by skills or gem modifiers (chance-based on hit)
- Duration decrements each turn, removed when expired

#### Battle Sprites
- Characters and enemies display sprites with tween-based animations
- Animations: attack (lunge forward), hurt (flash + shake), death (fade out)

---

### 2. Inventory System

**Files:** `scripts/systems/inventory/grid_inventory.gd`, `inventory_undo.gd`, `tool_modifier_state.gd`

#### Grid-Based Placement
- Tetris-style grid per character (max 12x12, defined by GridTemplate)
- Items have shapes (1x1, 1x2, L-shaped, T-shaped, etc.) with rotation support
- Placement validation: all cells must be in active grid area, no overlap
- Drag-and-drop with immediate placement preview and shape-aware outlines

#### Item Types
- **ACTIVE_TOOL (Weapons)** - Base power, granted skills, accepts gem modifiers, requires hand slots (1-2)
- **PASSIVE_GEAR (Armor)** - Flat stat bonuses, armor slot restriction (1 per slot type, rings up to 10)
- **MODIFIER (Gems)** - 1x1 shape, enhance adjacent weapons within Manhattan distance reach
- **CONSUMABLE** - Single-use, triggers `use_skill` (e.g., healing potion)
- **MATERIAL** - Crafting materials (framework exists)

#### Gem Modifier System
- Gems affect weapons within `modifier_reach` cells (Manhattan distance = cross/diamond pattern)
- Bonuses: stat modifiers, magical damage, status effect chance
- Conditional rules: match weapon type (MELEE/RANGED/MAGIC) for specific bonuses
- Visual preview: drag gem to see highlighted affected weapon cells (magenta)
- `ToolModifierState` aggregates all modifier effects on a weapon

#### Equipment Slots
- **Hands:** Base 2 + bonus_hand_slots from items (1-2 handed weapons)
- **Armor:** Helmet, Chestplate, Gloves, Legs, Boots (1 each)
- **Accessories:** Necklace (max 1), Rings (max 10)

#### Stat Computation
- `get_computed_stats()` aggregates all placed items
- Flat bonuses applied first, then percent: `final = flat * (1 + pct%)`
- Includes tool+modifier cross-referencing

#### Upgrade System
- Same items combine to upgrade rarity: Common → Uncommon → Rare → Elite → Legendary → Unique
- Each tier: stats × 1.5, price × 1.5
- Tier base power: [5, 8, 13, 21, 35, 50]

#### UX Features
- Undo/redo for placement operations
- Hold T key to temporarily hide tooltips
- Immediate drag preview on pickup
- Shape-aware per-cell outlines for non-rectangular items
- Stash panel for shared item storage (max 100 slots)

---

### 3. Passive Skill Trees

**Files:** `scripts/resources/passive_tree_data.gd`, `passive_node_data.gd`, `scenes/passive_tree/`

#### Structure
- Each character class has a unique PassiveTreeData with interconnected nodes
- Nodes provide stat bonuses (flat/percent) and/or a special effect ID
- Nodes have gold cost and prerequisite node IDs

#### Unlocking
- Player spends gold to unlock nodes
- Prerequisites must be unlocked first
- Unlocked nodes stored in `Party.unlocked_passives[character_id]`

#### Effect Application
- `Party.get_passive_bonuses()` collects all unlocked node bonuses
- `CombatEntity.from_character()` applies passive bonuses to effective stats
- CombatManager checks `passive_special_effects` for combat abilities

---

### 4. Characters & Party

**Files:** `scripts/resources/character_data.gd`, `scripts/models/party.gd`

#### Character Definition
- ID, display name, class (Warrior/Mage/Rogue)
- 8 base stats: MAX_HP, MAX_MP, SPEED, LUCK, PHYSICAL_ATTACK, PHYSICAL_DEFENSE, SPECIAL_ATTACK, SPECIAL_DEFENSE
- Grid template (unique inventory layout)
- Portrait and sprite references
- Innate skills (not from equipment)

#### Party Management
- **Roster:** Up to 12 characters total
- **Squad:** Up to 4 active members (participate in combat)
- **Stash:** Shared item storage (100 slots)
- **Vitals:** Per-character HP/MP state persisted between battles
- **Grid Inventories:** Per-character tetris inventory

#### Starter Party
- GameManager.new_game() creates 3 characters (Warrior, Mage, Rogue)
- Distributes ~25+ starter items (weapons, armor, gems, consumables)
- Starting gold: 100

---

### 5. Overworld & Exploration

**Files:** `scenes/world/overworld.gd`, `scenes/world/roaming_enemy.gd`, `scenes/world/location_marker.gd`

#### Movement
- WASD controls, 200 pixels/second
- Camera follows player smoothly
- Position saved and restored on scene transitions

#### Locations
- Defined by LocationData: name, scene path, entrance position, unlock flag
- Types: TOWN, DUNGEON, LANDMARK, SHOP, INN, LAKE, CAVE
- Some locked until story flags are set
- Fast travel available for visited locations

#### Encounters
- **Roaming Enemies:** Visible on overworld, trigger battle on collision
- **Encounter Zones:** Area-based random encounters with configurable rates
- 3-second battle cooldown after combat ends (prevents re-engagement)

#### World Objects
- Decorative: bush, flower, tree, rock, grass tuft, sign, fence
- Various sizes (small/medium/large for trees and rocks)

---

### 6. Loot System

**Files:** `scripts/systems/loot/loot_generator.gd`, `scripts/resources/loot_table.gd`

#### Loot Generation
Two systems available per LootTable:

1. **Drop Chance System** (primary) - Each entry rolled independently: `randf() <= drop_chance`
2. **Weighted Random System** (legacy) - Roll `roll_count` times, pick weighted randomly

Guaranteed drops always included regardless of rolls.

#### Post-Battle Flow
1. Combat victory → gold earned + loot generated
2. Loot screen displays items for distribution
3. Player drags items to character inventories or stash
4. Remaining items can be sold

---

### 7. Save/Load System

**Files:** `scripts/autoload/save_manager.gd`, `scripts/resources/save_data.gd`

- Single save slot at `user://save.json` (version 3)
- Serialized data: party (roster, squad, grid inventories, vitals, unlocked passives), stash, gold, story flags, overworld position, playtime
- Items saved with rarity level, restored with stat scaling on load
- Playtime tracked via delta accumulator
- Signals: `game_saved`, `game_loaded` via EventBus

---

### 8. Shop System

**Files:** `scripts/resources/shop_data.gd`

- Framework defined: ShopData with type, pricing, stock, buy/sell multipliers
- Shop types: GENERAL_GOODS, EQUIPMENT, BLUEPRINTS, GRID_UPGRADES, SPECIAL
- Pricing types: FIXED, TIER_BASED, DYNAMIC, NEGOTIABLE
- Items have `base_price` and `get_sell_price()` (50% of base)
- **Status:** Framework exists, full UI/logic not yet implemented

---

## Enums & Constants

### Key Enums (`scripts/utils/enums.gd`)

| Enum | Values |
|------|--------|
| **ItemType** | ACTIVE_TOOL, PASSIVE_GEAR, MODIFIER, CONSUMABLE, MATERIAL |
| **Rarity** | COMMON, UNCOMMON, RARE, ELITE, LEGENDARY, UNIQUE |
| **EquipmentCategory** | SWORD, MACE, BOW, STAFF, DAGGER, SHIELD, AXE, HELMET, CHESTPLATE, GLOVES, LEGS, BOOTS, NECKLACE, RING |
| **WeaponType** | MELEE, RANGED, MAGIC |
| **Stat** | MAX_HP, MAX_MP, SPEED, LUCK, PHYSICAL_ATTACK, PHYSICAL_DEFENSE, SPECIAL_ATTACK, MAGICAL_DEFENSE, CRITICAL_RATE, CRITICAL_DAMAGE |
| **ModifierType** | FLAT, PERCENT |
| **DamageType** | PHYSICAL, MAGICAL |
| **CombatAction** | ATTACK, DEFEND, SKILL, ITEM, FLEE |
| **TargetType** | SELF, SINGLE_ALLY, SINGLE_ENEMY, ALL_ALLIES, ALL_ENEMIES, ALL |
| **CombatState** | INIT, TURN_START, ACTION_SELECT, ACTION_EXECUTE, TURN_END, VICTORY, DEFEAT |
| **StatusEffectType** | BURN, POISONED, CHILLED, SHOCKED |
| **SkillUsage** | COMBAT, MENU, BOTH |
| **InteractableType** | CHEST, NPC, DOOR, ENEMY_ENCOUNTER, SHOP |

### Key Constants (`scripts/utils/constants.gd`)

| Category | Constant | Value |
|----------|----------|-------|
| **Grid** | GRID_CELL_SIZE | 48px |
| **Grid** | GRID_MAX_WIDTH/HEIGHT | 12 |
| **Combat** | BASE_CRITICAL_RATE | 5% |
| **Combat** | BASE_CRITICAL_DAMAGE | 150% |
| **Combat** | MAX_CRITICAL_RATE | 95% |
| **Combat** | LUCK_CRIT_SCALING | 0.1% per luck |
| **Combat** | DEFEND_DAMAGE_REDUCTION | 50% |
| **Economy** | STARTING_GOLD | 100 |
| **Party** | MAX_SQUAD_SIZE | 4 |
| **Party** | MAX_ROSTER_SIZE | 12 |
| **Party** | MAX_STASH_SLOTS | 100 |
| **World** | PLAYER_SPEED | 200 px/s |
| **World** | INTERACTION_RANGE | 48 px |
| **Tiers** | TIER_BASE_POWER | [5, 8, 13, 21, 35, 50] |

### Rarity Colors
- Common: White
- Uncommon: Blue
- Rare: Gold
- Elite: Orange
- Legendary: Crimson
- Unique: Purple

---

## Content Summary

| Category | Count | Details |
|----------|-------|---------|
| **Characters** | 3 | Warrior (Kael), Mage, Rogue |
| **Enemies** | 2 | Goblin, Slime |
| **Skills** | 8 | Slash, Power Strike, Shield Bash, Backstab, Fire Bolt, Ice Shard, Thunder Bolt, Heal Minor |
| **Weapons** | 9 | Swords (2), Daggers (2), Mace, Staves (2), Bow, Axe |
| **Armor** | 7 | Helmet, Chestplate, Gloves, Legs, Boots, Shield, Skeleton Arm |
| **Gems** | 15 | Fire (3 rarities), Ice, Thunder, Power, Precision, Swift, Vampiric, Devastation, Ripple (2), Mystic, Poison, Megummy |
| **Consumables** | 1 | Common Potion |
| **Shapes** | 8 | 1x1, 1x2, 1x3, 1x4, 2x2, L, Axe (T), Bow (zigzag) |
| **Status Effects** | 4 | Burn, Poisoned, Chilled, Shocked |
| **Encounters** | 3 | Goblins, Slimes, Bandits |
| **Encounter Zones** | 2 | Grasslands, Forest |
| **Locations** | 6 | Starting Town, North Town, Cave, Lake, Dungeon Cave, Town |
| **Loot Tables** | 4 | Per-enemy (goblin, slime) + basic + example |
| **Passive Trees** | 3 | Warrior, Mage, Rogue |
| **Grid Templates** | 3 | Per character class |
| **Scenes** | 40+ | Battle (7), Inventory (9), World (14+), Menus (6), Other (5+) |
| **Autoloads** | 9 | DebugLogger, EventBus, 3 Databases, GameManager, SaveManager, SceneManager, InputManager |

---

## Known Constraints & Patterns

### GDScript Typed Loop Gotcha
Typed for-in loops over untyped collections cause **silent parse errors** in Godot 4.6:
```gdscript
# BAD - script fails to load entirely:
for entity: CombatEntity in untyped_array:

# GOOD - index-based loop:
for i in range(array.size()):
    var entity: CombatEntity = array[i]

# OK - untyped loop variable:
for entity in array:
```

### class_name Cannot Reference Autoloads
Scripts with `class_name` compile before autoloads are registered. Use scene scripts to bridge autoload calls, or use inline literals instead of Constants.

### PanelContainer Layout
Children of PanelContainer MUST have `layout_mode = 2` for proper sizing.

### TextureRect for Oversized Sprites
Use `EXPAND_IGNORE_SIZE` expand mode + parent `clip_contents = true`.

### Physics Layers
- Layer 1: "world" (terrain, obstacles)
- Layer 2: "player"
- Layer 3: "enemies"
- Layer 4: "interactables" (chests, NPCs, doors)

### Pure Logic vs UI Separation
- CombatManager, GridInventory, LootGenerator are pure logic (no UI dependencies)
- Scene scripts handle rendering and bridge to autoloads via signals
- Party model is RefCounted (not Node) for data portability

### Input Actions
- Movement: WASD / Arrow Keys
- Interact: E
- Open Inventory: I
- Escape: ESC
- Rotate Item: R
- Fast Travel: T
