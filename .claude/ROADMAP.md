# Tactical RPG - Development Roadmap

## 🎮 Game Vision

**Core Inspiration**: Final Fantasy 6 (preset characters, overworld), Path of Exile (giant skill tree, gem system)
**Genre**: Single-player tactical RPG with grid-based inventory
**Scope**: Hand-crafted content, old-school design philosophy
**Target**: Medium-length RPG (40-60 hours) with deep character customization

---

## 📋 Priority Tasks (Organized by Category)

### 🗡️ Items & Equipment (High Priority - Foundation for Economy)

#### Phase 1: Core Item Creation
- [ ] **Create armor items**
  - Helmets (light/medium/heavy variants)
  - Chestplates (cloth/leather/plate variants)
  - Gloves (various stat focuses)
  - Leg armor (pants/greaves)
  - Boots (speed vs defense trade-offs)

- [ ] **Create jewelry items**
  - Necklaces (1 slot, powerful unique effects)
  - Rings (10 slots, smaller bonuses, stackable effects)

- [ ] **Expand weapon variety**
  - Multiple tiers of each weapon type (iron → steel → mythril → legendary)
  - Swords (one-handed, various speeds/damages)
  - Maces (high damage, slower)
  - Daggers (fast, crit-focused)
  - Staves (two-handed, magic damage)
  - Bows (ranged physical, introduce range mechanics)
  - Axes, spears, etc. (new weapon categories)

#### Phase 2: Item Progression
- [ ] Create item rarity tiers with meaningful differences
- [ ] Design unique legendary items with special effects
- [ ] Balance item stats across all tiers

---

### ⚔️ Combat Enhancements (High Priority - Core Gameplay)

- [ ] **Implement defend action with block %**
  - Use weapon/shield block_percentage for damage reduction
  - Balance block values across weapon types
  - Add visual feedback for blocked damage

- [ ] **Create enemy variety**
  - Design 15-20 unique enemy types
  - Each enemy type has unique skills/behaviors
  - Enemy compositions (melee, ranged, support)
  - Boss enemies with special mechanics

- [ ] **Combat polish**
  - Damage numbers animation
  - Screen shake on critical hits
  - Skill visual effects
  - Victory fanfare and improved rewards screen

---

### 🏙️ World & NPCs (Medium Priority - Content Expansion)

#### Phase 1: NPC System Design
- [ ] **Design NPC types and roles**
  - **Blacksmith**: Weapon/armor purchasing, equipment upgrades
  - **Priest**: Healing, resurrection, buff items
  - **Merchant**: General goods, consumables
  - **Innkeeper**: Rest/heal party, save point
  - **Couturier/Tailor**: Cloth armor, appearance customization
  - **Quest Givers**: Story and side quests
  - **Trainers**: Teach new skills or unlock passive nodes

#### Phase 2: Town Implementation
- [ ] **Create town area maps**
  - Starting town (tutorial NPCs, basic shops)
  - Major cities (multiple NPCs, quest hubs)
  - Smaller villages (1-2 unique NPCs or shops)
  - Town interiors (homes, shops, guild halls)

- [ ] **Implement shop system**
  - Buy/sell interface with item comparison
  - Shop inventory based on story progression
  - Price scaling (buy high, sell low)
  - Rare rotating stock

#### Phase 3: Dungeons
- [ ] **Design multi-floor dungeons**
  - 5-7 main dungeons with unique themes
  - Each dungeon: 3-5 floors with increasing difficulty
  - Environmental hazards and puzzles
  - Boss encounter at the end
  - Unique loot tables per dungeon

---

### 📜 Progression Systems (Medium Priority - Long-term Engagement)

- [ ] **Expand passive skill tree (PoE-style)**
  - Design giant shared tree (~150-300 nodes)
  - Each character starts at different position
  - Mix of small stat nodes and major keystone abilities
  - Pathing choices create build diversity
  - Visual tree UI (zoom, pan, connections)

- [ ] **Quest system**
  - Quest data structure (objectives, rewards, flags)
  - Quest log UI (active, completed, failed)
  - Objective tracking on HUD
  - Quest chains and branching outcomes
  - Side quests for exploration rewards

- [ ] **Item crafting system**
  - Material items (ores, herbs, monster drops)
  - Recipe system (discovered through gameplay)
  - Crafting UI (select recipe, check materials, craft)
  - Crafted items can rival found gear
  - Unique crafting-only items

---

### 📖 Story & Narrative (Lower Priority - Content Polish)

- [ ] **Story mode with cutscenes**
  - Main story beats (intro, major events, finale)
  - Character-focused side stories (FF6 style)
  - Cutscene system (dialogue boxes, portraits, basic animations)
  - Player choices affecting outcomes
  - Multiple endings based on decisions

- [ ] **Character development**
  - Preset cast of characters (FF6 inspiration)
  - Each character has unique abilities/skills
  - Character recruitment through story
  - Character-specific story arcs and quests

---

### 💾 Systems & Quality of Life (As Needed)

- [ ] **Save slot system**
  - Multiple save files (5-10 slots)
  - Save file metadata (playtime, location, party level)
  - Delete/copy save files
  - Auto-save with manual save option
  - Save file browser UI

- [ ] **Quality of life improvements**
  - Item sorting and filtering in inventory
  - Equipment comparison tooltips
  - Batch sell items
  - Equipment loadout presets
  - Battle speed controls
  - Skip cutscenes (after first viewing)

---

## 🚫 Explicitly Out of Scope

- ❌ Multiplayer/Co-op (single-player focus)
- ❌ Procedural generation (hand-crafted content only)
- ❌ Class change system (preset characters with fixed roles)
- ❌ Live service/updates (complete game at launch)

---

## 🎯 Next Immediate Steps

### Sprint 1: Item Foundation (1-2 weeks)
1. Create 5 helmets (1 per tier: common → legendary)
2. Create 5 chestplates (matching tiers)
3. Create 5 pairs of gloves, legs, boots
4. Create 3 necklaces (rare drops)
5. Create 10 rings (various effects)
6. Create 3-4 variants of each weapon type

**Why this first?** Items are the foundation of the economy, loot system, and player progression. Having variety makes combat rewards meaningful.

### Sprint 2: Combat Refinement (1 week)
1. Implement defend action with block %
2. Create 5 new enemy types
3. Add damage number animations
4. Polish battle feedback (shake, effects)

**Why this second?** Combat is core gameplay loop. Better combat = more engaging moment-to-moment play.

### Sprint 3: World Building (2-3 weeks)
1. Design NPC system and data structure
2. Create first town with 3-4 NPCs
3. Implement basic shop (buy/sell)
4. Create first dungeon (3 floors + boss)

**Why this third?** Gives context to exploration and provides goals for player.

---

## 📊 Milestone Goals

### Milestone 1: "Gameplay Loop Complete" (Current + 4-6 weeks)
- ✅ Items: 50+ items across all types
- ✅ Combat: 10+ enemy types, defend action works
- ✅ World: 1 town, 1 dungeon, basic shops
- ✅ Progression: Expanded skill tree (50+ nodes)
- **Result**: Core loop of explore → fight → loot → upgrade is satisfying

### Milestone 2: "Content Alpha" (Milestone 1 + 8-10 weeks)
- ✅ Items: 100+ items, crafting system
- ✅ Combat: 20+ enemy types, 5+ bosses
- ✅ World: 3 towns, 3 dungeons, quest system
- ✅ Progression: Full skill tree (150+ nodes), quest rewards
- **Result**: 10-15 hours of playable content

### Milestone 3: "Story Complete" (Milestone 2 + 12-15 weeks)
- ✅ Story: Full narrative with cutscenes
- ✅ Content: 5 towns, 7 dungeons, full cast of characters
- ✅ Polish: All systems refined, QoL features added
- **Result**: 40-60 hour complete game ready for release

---

## 💭 Design Philosophy

**Player Agency**: Choices matter (builds, quests, story)
**Respect Player Time**: No grind, meaningful progression
**Depth Over Breadth**: Fewer systems, deeply interconnected
**Hand-Crafted**: Every item, enemy, location intentionally designed
**Old-School**: Classic JRPG feel with modern QoL
