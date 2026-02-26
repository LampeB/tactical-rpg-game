# Tactical RPG — ToDoList

## Completed
- [x] Item database with IDs instead of hardcoding
- [x] Character database
- [x] Skills determined by items
- [x] Save/load system
- [x] Passive skills summary on skill tab
- [x] Active skills summary on inventory tab
- [x] Passive + active skills summary on stat tab
- [x] Persist HP/Mana after fights
- [x] Use skills/items outside of combat (healing)
- [x] Lake location debug heal (full HP/MP)
- [x] Passive skill tree (gold-based unlocks)
- [x] Stat screen per character
- [x] Squad composition management
- [x] Squad screen navigation fix
- [x] Post-battle loot screen with drag-and-drop
- [x] Custom modifier reach patterns for gems
- [x] Item and reach pattern rotation with sprite rotation
- [x] Hand slot restrictions and weapon hand requirements
- [x] Shield system (ACTIVE_TOOL, 1 hand)
- [x] Armor slot system (helmet, chestplate, gloves, legs, boots)
- [x] Jewelry system (1 necklace, up to 10 rings)
- [x] Equipment slots indicator panel in inventory UI
- [x] Fire gem conditional modifier system
- [x] Block percentage property for weapons
- [x] FF6-style overworld with WASD movement and camera follow
- [x] LocationData system with unlock flags and fast travel
- [x] Visible roaming enemies (Chrono Trigger style)
- [x] EncounterZoneData for enemy spawn areas
- [x] Settings menu with keyboard rebinding
- [x] In-game skill tree editor
- [x] In-game item editor

---

## General Tasks

### UI & Polish
- [ ] Unified screen/menu presentation — rework all menus and screens to follow a single consistent pattern (no mix of floating overlays and full-screen panels; decide on one approach and apply it everywhere)
- [ ] Make it possible to use sprites for every UI element
- [ ] Damage numbers animation in combat
- [ ] Screen shake on critical hits
- [ ] Skill visual effects / particles
- [ ] Hover tooltip on skills in the stats screen (show skill details on mouseover)
- [ ] Show number of hands required on weapon card

### Items & Equipment
- [ ] Create armor items (helmets, chestplates, gloves, legs, boots — multiple tiers)
- [ ] Create jewelry items (necklaces, rings with various effects)
- [ ] Expand weapon variety (multiple tiers per type: iron → steel → mythril → legendary)
- [ ] Design unique legendary items with special effects
- [ ] Balance item stats across all tiers
- [ ] Item crafting system — combine items to create new ones, recipes in a database, crafting UI
- [ ] Inventory grid size upgrades (at shops)

### Combat
- [ ] Implement defend action (damage reduction via shield/defense stats)
- [ ] Create enemy variety (15-20 types with unique skills/behaviors, bosses)
- [ ] In-game enemy editor — debug/dev tool for enemy definitions
- [ ] Overworld encounter balancing (enemy count, spawn positions)

### World & Progression
- [ ] Add mechanic to block parts of the map if conditions aren't met
- [ ] Expand passive skill tree (PoE-style, 150-300 nodes, characters start at different positions)
- [ ] Make skill tree connections non-directional — adjacency should be symmetric (having skill A unlocks skill B, and vice versa), regardless of which node was defined first
- [ ] Fixed map system — easily editable, different placeable elements stored in a DB

### Audio
- [ ] Background music for each scene (main menu, overworld, battle, menus)
- [ ] Sound effects for UI interactions (button clicks, menu navigation, drag & drop)
- [ ] Sound effects for combat (attacks, skills, hits, misses, crits, status effects)
- [ ] Sound effects for events (gold earned, item pickup, passive unlocked)
- [ ] Victory and defeat jingles
- [ ] Ambient/environmental sounds on overworld
- [ ] Audio settings (master, music, SFX volume) in settings menu
- [ ] Smooth music transitions when switching scenes (crossfade)

### Story & Narrative
- [ ] Story mode with cutscenes (dialogue boxes, portraits, basic animations)
- [ ] Character development (unique abilities, recruitment through story)
- [ ] Multiple endings based on choices

### Quality of Life
- [ ] Multiple save slots (5-10) with metadata (playtime, location, party level)
- [ ] Item sorting and filtering in inventory
- [ ] Equipment comparison tooltips
- [ ] Batch sell items
- [ ] Equipment loadout presets
- [ ] Battle speed controls
- [ ] Tutorial / onboarding for new mechanics

---

## Map Editor Prerequisites (implement before map editor)

### NPCs & Dialogue System
- [ ] `NpcData` resource — id, display_name, portrait, dialogue_tree, role (merchant/quest_giver/generic)
- [ ] Dialogue tree data structure — nodes with text, choices, conditions, outcomes
- [ ] Dialogue UI scene — portrait, text box, choice buttons, typewriter effect
- [ ] `Npc` scene (Area2D) — placed on maps, triggers dialogue on interact
- [ ] NpcDatabase autoload — scans `data/npcs/` for .tres files
- [ ] In-game NPC/dialogue editor (optional, or hand-edit .tres)

### Shop System
- [ ] `ShopData` resource — id, display_name, inventory (Array[ItemData]), pricing rules, restock behavior
- [ ] Shop UI scene — buy/sell panels, item grid, gold display, confirmation
- [ ] Shopkeeper NPC integration — NPC with role=merchant opens shop UI
- [ ] ShopDatabase autoload — scans `data/shops/` for .tres files
- [ ] Connect to existing inventory system (GridInventory) for player items

### Quest System
- [ ] `QuestData` resource — id, title, description, objectives (Array[QuestObjective]), rewards, prerequisite quests
- [ ] `QuestObjective` resource — type (kill, collect, talk_to, reach_location), target_id, required_count
- [ ] Quest log UI — active/completed quests, objective tracking, rewards display
- [ ] Quest marker visuals — icons above NPCs/locations with active quests
- [ ] QuestManager autoload — tracks active/completed quests, checks objectives, awards rewards
- [ ] Integration with EventBus — quest_started, quest_completed, objective_progressed signals
- [ ] Story flag integration — quests can set/check flags for map unlocking

### Chests & Loot Containers
- [ ] `ChestData` resource — id, loot_table or fixed items, opened_flag, visual_type (wood/gold/locked)
- [ ] Chest scene (Area2D) — placed on maps, interact to open, plays animation
- [ ] Loot popup UI — shows acquired items after opening
- [ ] Opened state persistence — uses GameManager story flags (e.g., "chest_{id}_opened")
- [ ] Connect to existing LootTable/LootGenerator systems

### Town & Dungeon Content
- [ ] Create town area maps (starting town with tutorial NPCs, major cities, small villages)
- [ ] Design multi-floor dungeons (5-7 main dungeons, 3-5 floors each, unique themes, boss at end)

---

## Map Editor (after prerequisites above)

### Architecture
- **Three-panel layout**: Map list (left) + Visual canvas (center) + Property panel (right) + toolbar (top)
- **Data-driven**: Each map = `MapData` resource (.tres) in `data/maps/`
- **Runtime loader**: `MapLoader` converts MapData into playable Node2D scenes
- Follows existing editor patterns (item editor list/properties + tree editor canvas)

### Placeable Element Types
| Type | Data Reference | Visual |
|------|---------------|--------|
| Location | LocationData | Icon + label |
| Encounter Zone | EncounterZoneData | Semi-transparent rectangle |
| Roaming Enemy | EncounterData | Red circle + name |
| Decorative Object | scene path | Small icon |
| NPC | NpcData | Portrait icon + name |
| Shop | ShopData (via NPC) | Merchant icon |
| Quest Marker | QuestData | Exclamation icon |
| Chest | ChestData | Chest icon |
| Map Connection | target map + spawn | Portal icon |

### Implementation Steps
- [ ] Resource scripts (MapData, MapElement, MapConnection)
- [ ] MapDatabase autoload
- [ ] Editor scene layout (.tscn)
- [ ] Map list panel (CRUD, search, dirty tracking)
- [ ] Canvas rendering (grid, elements by type, spawn marker)
- [ ] Canvas interaction (select, place, drag, delete)
- [ ] Property panel (map properties + per-element-type sections)
- [ ] Save/load (ResourceSaver, MapDatabase.reload())
- [ ] Main menu button integration
- [ ] Default overworld map (export current overworld to MapData)
- [ ] MapLoader runtime (convert MapData to playable scenes)

---

## Out of Scope
- Multiplayer/Co-op (single-player focus)
- Procedural generation (hand-crafted content only)
- Class change system (preset characters with fixed roles)
- Live service/updates (complete game at launch)
