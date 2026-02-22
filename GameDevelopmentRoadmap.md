# Tactical RPG - Development Roadmap

## Engine & Stack
- **Engine:** Godot 4.6
- **Language:** GDScript
- **Renderer:** GL Compatibility
- **Resolution:** 1920x1080

---

## Phase 1: Core Foundation (COMPLETED)

### Project Setup
- [x] Godot 4.6 project with GL Compatibility renderer
- [x] Directory structure: scenes/, scripts/, data/, assets/
- [x] Autoload singletons: DebugLogger, EventBus, GameManager, SceneManager, SaveManager, InputManager
- [x] Database autoloads: ItemDatabase, CharacterDatabase, PassiveTreeDatabase

### Data Architecture
- [x] Resource-based data system (.tres files in data/)
- [x] Character, Enemy, Item, Skill, Status Effect data classes
- [x] Item shapes with rotation support (1x1, 1x2, L, T, etc.)
- [x] Grid templates per character class
- [x] Encounter and loot table resources

### Grid-Based Inventory
- [x] Tetris-style item placement with collision detection
- [x] Drag-and-drop with placement preview
- [x] Item rotation (R key)
- [x] Equipment slot enforcement (hand slots, armor slots)
- [x] Stash panel for shared storage (100 slots)
- [x] Item tooltips with stat display

### Character System
- [x] 3 starter characters (Warrior, Mage, Rogue)
- [x] 8 base stats per character
- [x] Character-specific grid templates
- [x] Party model with roster/squad management

### Combat System
- [x] Frequency-based ATB turn system (speed-driven)
- [x] Basic actions: Attack, Defend, Skill, Flee
- [x] Hybrid damage calculation (physical + magical)
- [x] Critical hit system with luck scaling
- [x] Turn order simulation and UI display
- [x] Enemy AI for turn decisions

### Status Effects
- [x] 4 status types: Burn, Poisoned, Chilled, Shocked
- [x] Tick damage, speed reduction, turn skip mechanics
- [x] Status interaction rules (cancel, amplify, transform)
- [x] Duration tracking and expiration

### Save System
- [x] JSON save/load at user://save.json
- [x] Party, inventory, gold, story flags persistence
- [x] Playtime tracking
- [x] Save version migration (v1 → v3)

### Scene Management
- [x] Push/pop/replace scene navigation with fade transitions
- [x] Data passing between scenes via receive_data()
- [x] Main menu with New Game / Continue

### Overworld
- [x] Player movement with WASD (200 px/s)
- [x] Location markers with interaction prompts
- [x] Roaming enemies that trigger battles
- [x] Encounter zones with configurable rates
- [x] Decorative world objects (trees, rocks, bushes, etc.)
- [x] Position persistence across scene transitions

### Passive Skill Trees
- [x] Per-character skill tree with prerequisite nodes
- [x] Gold-cost unlocking
- [x] Stat bonuses (flat/percent) + special effect IDs
- [x] Visual tree UI with node connections

---

## Phase 2: Advanced Systems (COMPLETED)

### Inventory Enhancements
- [x] Gem modifier system (Manhattan distance reach, cross/diamond pattern)
- [x] Conditional modifier rules (match weapon type: melee/ranged/magic)
- [x] Tool modifier state aggregation
- [x] Item upgrade system (combine same items → higher rarity)
- [x] Undo/redo for inventory operations
- [x] Shape-aware per-cell outlines for non-rectangular items
- [x] Modifier connection highlighting during gem drag
- [x] Immediate drag preview on pickup
- [x] Hold T key to temporarily hide tooltips

### Combat Enhancements
- [x] Passive abilities in combat (counter, lifesteal, thorns, evasion, etc.)
- [x] Start-of-battle effects (shield, first strike)
- [x] Gem-based status effect application (chance on hit)
- [x] Battle sprites with attack/hurt/death animations
- [x] Damage popup numbers (normal + critical)
- [x] Battle log with colored messages
- [x] Turn order bar visualization

### Loot & Rewards
- [x] Loot generation from tables (drop chance + weighted systems)
- [x] Post-battle loot screen with drag-and-drop distribution
- [x] Per-enemy and encounter override loot tables
- [x] Gold rewards with DOUBLE_GOLD passive support

### Party & Progression
- [x] Squad composition management (4 active from 12 roster)
- [x] HP/MP persistence between battles
- [x] Consumable usage outside combat (inventory menu)
- [x] Lake location for full heal/mana regen (debug tool)
- [x] Character stats screen with equipment overview
- [x] Active/passive skill summaries on multiple tabs

### UI Polish
- [x] Wider action menu columns (250px) for readability
- [x] Wider battle log (500px minimum)
- [x] Consistent font sizes across all UI (12-56px range)
- [x] Rarity-colored item borders and text
- [x] Equipment slots panel showing weapon/armor/accessory layout

---

## Phase 3: Planned Features

### Inventory & Items
- [ ] Increase inventory grid size (purchasable at shop)
- [ ] Custom modifier reach patterns (cross-shaped, diamond, L-shaped instead of simple radius)
- [ ] More item shapes and item variety

### World & Exploration
- [ ] Map area blocking based on story conditions
- [ ] Chest IDs for specific loot per chest
- [ ] Fixed, editable maps with DB-based placeable elements
- [ ] More locations and dungeon variety

### Shop System
- [ ] Full shop UI implementation (buy/sell interface)
- [ ] Multiple shop types (equipment, upgrades, special)
- [ ] Grid upgrade purchasing
- [ ] Dynamic pricing and restocking

### Visual
- [ ] Sprites for all UI elements
- [ ] 3D voxel graphics (future consideration, larger effort)

---

## Phase 4: Content & Polish

### Content Expansion
- [ ] More characters and classes
- [ ] More enemies with varied mechanics
- [ ] More skills and status effects
- [ ] More encounters and encounter zones
- [ ] More items at all rarity tiers
- [ ] Story progression with flags and gating

### Audio
- [ ] Background music per location/battle
- [ ] Sound effects for combat actions
- [ ] UI interaction sounds

### Balance & Testing
- [ ] Combat balance tuning
- [ ] Economy balance (gold rewards, shop prices, upgrade costs)
- [ ] Power progression curves per character class
- [ ] Automated balance testing framework

### Quality of Life
- [ ] Auto-sort inventory
- [ ] Item comparison tooltips
- [ ] Tutorial/onboarding system
- [ ] Settings menu expansion (audio, controls, display)
- [ ] Controller support

### Performance
- [ ] Scene optimization
- [ ] Resource loading optimization
- [ ] Memory management for large inventories
