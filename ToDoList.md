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
- [x] NPC & dialogue system (NpcData, dialogue tree, dialogue UI, NPC markers)
- [x] NpcDatabase autoload
- [x] Shop system (ShopData, shop UI, shopkeeper NPC integration)
- [x] Item crafting system (blacksmith, recipes, blueprints, crafting UI)
- [x] Multiple save slots with ring buffer history and auto-save (save system v5)
- [x] Pause menu (canvas overlay on overworld)
- [x] Backpack tier upgrade system (6 tiers per character, custom shapes, Weaver NPC)
- [x] Dead characters persist death across battles (no auto-revive on victory)
- [x] Full GDScript warning cleanup (~50+ warnings fixed: type annotations, return types, etc.)

---

## Bugs to Fix

- [x] Rotating an item does not rotate its reach shape — hover now shows rotated reach cells
- [x] KO'd characters still play their animations / act during battle
- [x] Tooltip doesn't disappear correctly when leaving items in the blacksmith interface
- [x] Item editor has no fields to edit innate status effect modifiers (poison, chill, etc.)
- [x] Runtime errors: typed array assignment from Variant (combat_entity, combat_manager)
- [x] Cascading parse error from misaligned indentation in item_tooltip.gd

---

## General Tasks

### UI & Polish
- [x] Loot screen "Use" button should show target selection popup (same as inventory right-click potion use)
- [x] Persistent party character cards on overworld HUD (portrait, HP, MP)
- [x] ESC should leave current interface/screen (except during battles)
- [ ] Limit the size of the stash (enforce MAX_STASH_SLOTS cap)
- [ ] Add a way to throw away / discard items (from stash and inventory)
- [ ] Stash sorting and filtering: primary + secondary sort order (e.g. by type then by rarity → all weapons sorted by rarity, then all armor sorted by rarity, etc.); available sort keys: alphabetical, item type, rarity; also support filtering by type
- [ ] Unified screen/menu presentation — rework all menus and screens to follow a single consistent pattern (no mix of floating overlays and full-screen panels; decide on one approach and apply it everywhere)
- [ ] Make it possible to use sprites for every UI element
- [ ] Damage numbers animation in combat
- [ ] Screen shake on critical hits
- [ ] Skill visual effects / particles
- [ ] Hover tooltip on skills in the stats screen (show skill details on mouseover)
- [ ] Show number of hands required on weapon card
- [ ] Reduce tooltip size and anchor it to a fixed area of the screen instead of floating at cursor position
- [ ] Add status effect proc roll results to the battle log (e.g. "Fire Gem rolled 18% vs 20% — no burn" / "rolled 8% vs 20% — BURN applied!")

### Items & Equipment
- [ ] Create armor items with subtypes per slot — each slot has 3–4 weight classes with different stat profiles:
  - **Head:** Hood (light), Helmet (medium), Great Helm (heavy), Crown (magic)
  - **Chest:** Robe (light), Hauberk (medium), Plate (heavy), Enchanted Vest (magic)
  - **Hands:** Wraps (light), Gloves (medium), Gauntlets (heavy), Arcane Gloves (magic)
  - **Legs:** Leggings (light), Chainlegs (medium), Greaves (heavy), Runic Leggings (magic)
  - **Feet:** Shoes (light), Boots (medium), Sabatons (heavy), Sandals (magic)
- [ ] Allow modifiers (gems) to affect armor items — loosen the ACTIVE_TOOL-only gate in grid_inventory.gd so gems placed adjacent to armor also apply their modifier_bonuses
- [ ] Create jewelry items (necklaces, rings with various effects)
- [ ] Expand weapon variety (multiple tiers per type: iron → steel → mythril → legendary)
- [ ] Design unique legendary items with special effects
- [ ] Balance item stats across all tiers
- [x] Item crafting system — combine items to create new ones, recipes in a database, crafting UI
- [ ] Remove gold cost from blacksmith recipes (crafting cost should be ingredients only, no gold)
- [ ] Inventory grid size upgrades: use a dedicated resource (not gold, not an inventory item) tracked globally like gold — earned through gameplay and spent to unlock additional grid cells
- [ ] Item merging by superposing on inventory grid — combine same-family items to upgrade rarity tier
- [ ] Loot screen item merging — allow combining two identical items (same family, adjacent rarity) to upgrade them to the next rarity tier directly on the post-battle loot screen
- [x] Items not picked up from the loot panel are lost once the screen is closed (no auto-stash)
- [x] Replace loot screen items list with inventory grids — place items one by one from highest rarity to lowest; items that can't be placed are discarded
- [x] Loot grid shapes depend on the encounter (different encounters yield different-shaped loot grids)

### Combat
- [ ] Implement defend action (damage reduction via shield/defense stats)
- [ ] Create enemy variety (15-20 types with unique skills/behaviors, bosses)
- [ ] In-game enemy editor — debug/dev tool for enemy definitions
- [ ] Overworld encounter balancing (enemy count, spawn positions)
- [ ] Restrict roaming enemies from entering town/NPC areas — define exclusion zones (per LocationData or a new repel_radius) that enemies cannot pathfind into, so players feel safe near towns

### World & Progression
- [ ] Party management NPC/location — add or remove party members (recruit, dismiss, swap roster)
- [ ] Add mechanic to block parts of the map if conditions aren't met
- [ ] Expand passive skill tree (PoE-style, 1000-1500 nodes, characters start at different positions)
- [ ] Replace fixed per-node gold cost in skill tree with a formula based on total nodes already unlocked (cost scales up the more nodes a character has)
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

### Gamepad & Steam Deck
- [ ] Full gamepad support — all menus, combat, overworld, and inventory navigable with controller; remap actions to gamepad buttons in the existing keybinding system
- [ ] Inventory/stash cursor navigation with left stick or d-pad (move cell-by-cell, pick up/place items with a button)
- [ ] On-screen button prompts that switch between keyboard and gamepad glyphs automatically based on last input device
- [ ] Steam Deck compatibility — verify 16:10 layout (1280×800), touch input passthrough, and Steam Input profile; submit to Steam Deck Verified checklist

### Localisation
- [ ] Integrate Godot's built-in TranslationServer — extract all displayed strings into CSV/PO translation files
- [ ] Language selector in settings menu; persist chosen language across sessions
- [ ] Initial languages: English + French (at minimum); structure to make adding more languages straightforward

### Quality of Life
- [x] Multiple save slots (5-10) with metadata (playtime, location, party level)
- [ ] Item sorting and filtering in inventory
- [ ] Equipment comparison tooltips
- [ ] Batch sell items
- [ ] Equipment loadout presets
- [ ] Battle speed controls
- [ ] Tutorial / onboarding for new mechanics

---

## Map Editor Prerequisites (implement before map editor)

### NPCs & Dialogue System
- [x] `NpcData` resource — id, display_name, portrait, dialogue_tree, role (merchant/quest_giver/craftsman/generic)
- [x] Dialogue tree data structure — nodes with text, choices, conditions, outcomes
- [x] Dialogue UI scene — portrait, text box, choice buttons, typewriter effect
- [x] `Npc` scene (Area2D) — placed on maps, triggers dialogue on interact
- [x] NpcDatabase autoload — scans `data/npcs/` for .tres files
- [x] In-game NPC/dialogue editor

### Shop System
- [x] `ShopData` resource — id, display_name, inventory (Array[ItemData]), pricing rules, restock behavior
- [x] Shop UI scene — buy/sell panels, item grid, gold display, confirmation
- [x] Shopkeeper NPC integration — NPC with role=merchant opens shop UI
- [x] ShopDatabase autoload — scans `data/shops/` for .tres files (created but unused; shop_ui loads directly)
- [x] Connect to existing inventory system (GridInventory) for player items
- [ ] In-game shop editor — create/manage shops, define inventory and pricing
- [ ] Permanently remove items from shop stock when bought by the player

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
