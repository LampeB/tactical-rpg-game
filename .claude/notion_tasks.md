# Notion Tasks Map
<\!-- Auto-generated from Notion Tasks database (787232f1-3840-4c99-9f5b-a4e3da59293c) -->
<\!-- Data source (Claude AI connector): fe3e9c59-0d0b-4072-a5ee-96051dc534b9 -->
<\!-- Total tasks: 226 -->
<\!-- Last updated: 2026-03-09 -->

## Prerequisites

### Todo
| Name | Notion ID |
|---|---|
| Create town area maps (starting town, cities, villages) | 3147700f-d0fb-813e-877a-d3243e44be13 |
| Design multi-floor dungeons (5-7 dungeons, 3-5 floors, bosses) | 3147700f-d0fb-81fa-83e2-f2424660f5ef |
| In-game shop editor (create/manage shops, define inventory and pricing) | 3147700f-d0fb-81ba-88fa-d2f169fb6a3b |

### Done
| Name | Notion ID |
|---|---|
| Chest opened state persistence (story flags) | 3147700f-d0fb-8144-b4f2-c5a86a55c8d5 |
| Quest EventBus integration (quest signals) | 3147700f-d0fb-81ec-8e9e-c87c73daa4e3 |
| Quest log UI (active/completed quests, tracking, rewards) | 3147700f-d0fb-81e1-b662-c547118990b5 |
| Quest marker visuals (icons above NPCs/locations) | 3147700f-d0fb-81e2-a100-da43c582626a |
| Quest story flag integration (set/check flags for map unlocking) | 3147700f-d0fb-8154-a271-f92bb5924b7c |
| QuestData resource (id, title, objectives, rewards, prerequisites) | 3147700f-d0fb-81af-9407-d357a359aec7 |
| QuestManager autoload (track quests, check objectives, award rewards) | 3147700f-d0fb-8192-861e-f99e647a1be0 |
| QuestObjective resource (kill, collect, talk_to, reach_location) | 3147700f-d0fb-81f2-b001-f59a8b365536 |
| Chest scene (Area3D, interact to open, animation) | 3147700f-d0fb-8155-a5c0-f76b87605bde |
| ChestData resource (id, loot_table, opened_flag, visual_type) | 3147700f-d0fb-816b-95d8-e0901308d9b7 |
| Connect chests to LootTable/LootGenerator systems | 3147700f-d0fb-81a2-88ae-e79c214e2564 |
| Loot popup UI (skip — loot screen used directly) | 3147700f-d0fb-8183-99c5-d733d508be01 |
| Connect shop to existing inventory system (GridInventory) | 3147700f-d0fb-81fa-9503-fb18c56790eb |
| Dialogue UI scene (portrait, text box, choices, typewriter effect) | 3147700f-d0fb-813d-8b3d-e60f4a0b60ab |
| Dialogue tree data structure (nodes, choices, conditions, outcomes) | 3147700f-d0fb-81c5-995c-de5acb39f78a |
| In-game NPC/dialogue editor | 3147700f-d0fb-818f-b549-c632838e7cff |
| NPC & dialogue system (NpcData, dialogue tree, dialogue UI, NPC markers) | 3147700f-d0fb-819d-a8db-ca9bd148bf24 |
| Npc scene (Area2D, triggers dialogue on interact) | 3147700f-d0fb-8164-8585-d9c32e8a8d9b |
| Permanently remove items from shop stock when bought | 3147700f-d0fb-8195-9b19-fd4024d1ae34 |
| NpcData resource (id, display_name, portrait, dialogue_tree, role) | 3147700f-d0fb-8158-b647-d1675a82f68e |
| NpcDatabase autoload | 3147700f-d0fb-8169-9066-d2da0150ab94 |
| Shop UI scene (buy/sell panels, item grid, gold, confirmation) | 3147700f-d0fb-8122-a35d-de6c9db96e18 |
| Shop system (ShopData, shop UI, shopkeeper NPC integration) | 3147700f-d0fb-81ac-857e-c3c3ca83503a |
| ShopData resource (id, display_name, inventory, pricing, restock) | 3147700f-d0fb-814d-8a17-e7d93f9f66d2 |
| ShopDatabase autoload (scans data/shops/) | 3147700f-d0fb-81be-889e-da2f2de6d12d |
| Shopkeeper NPC integration (role=merchant opens shop UI) | 3147700f-d0fb-8106-b4f3-ff384d6a4415 |

## Combat

### Todo
| Name | Notion ID |
|---|---|
| Create enemy variety (15-20 types with unique skills, bosses) | 3147700f-d0fb-81f8-add1-c877a64ed3ec |
| Refactor: Battle highlight logic duplication (_clear/_update target highlights) | 31e7700f-d0fb-8198-8198-df9480a240af |
| Dynamic spell lighting (temporary lights on fireballs, explosions, healing) | 31a7700f-d0fb-81d9-b5fd-dad335dd6b8e |
| In-game enemy editor (debug/dev tool) | 3147700f-d0fb-8107-bc59-e7045338d970 |
| Overworld encounter balancing (enemy count, spawn positions) | 3147700f-d0fb-819c-8b91-c1216a41e3db |
| Procedural cast/spell animations (channel, release, recoil) | 3167700f-d0fb-81fb-a067-c9a60e934df5 |

### Done
| Name | Notion ID |
|---|---|
| 3D damage popup positioning (Camera3D.unproject_position) | 3157700f-d0fb-81ce-a429-c4b709ed7255 |
| Battle backgrounds from map areas (editor tool + runtime rendering) | 31d7700f-d0fb-8135-b97a-e4a8d1f2eb4c |
| Dead characters persist death across battles (no auto-revive) | 3147700f-d0fb-81f1-8f45-fc6389364961 |
| EncounterZoneData for enemy spawn areas | 3147700f-d0fb-8166-8fcb-f55ede7b5342 |
| Implement defend action (damage reduction via shield/defense) | 3147700f-d0fb-81a3-853e-dd34af44a4d4 |
| KO'd characters still play animations / act during battle | 3147700f-d0fb-8101-b64d-e663c1304ba2 |
| Persist HP/Mana after fights | 3147700f-d0fb-8119-8955-f25b43a7be3a |
| Procedural attack animations (slash, thrust, bash per weapon type) | 3167700f-d0fb-81eb-ac24-c3a121c9bc8f |
| Restrict roaming enemies from entering town/NPC areas | 3147700f-d0fb-81af-9c68-e10347a8d3e9 |
| Runtime errors: typed array assignment from Variant | 3147700f-d0fb-81de-886d-db067f32a2a2 |
| Use skills/items outside of combat (healing) | 3147700f-d0fb-8171-8223-c3f36449a4f2 |
| Visible roaming enemies (Chrono Trigger style) | 3147700f-d0fb-8128-86b2-d501c34afda8 |

## Items

### Todo
| Name | Notion ID |
|---|---|
| Refactor: Type placed_items array in GridInventory (Array[PlacedItem]) | 31e7700f-d0fb-814e-8edd-c03bb81edf39 |

### Done
| Name | Notion ID |
|---|---|
| Fix: InventoryUndo doesn't store to_rotation on move (undo restores wrong rotation) | 31e7700f-d0fb-81e1-adc8-d2f1d325ecbd |
| Allow modifiers (gems) to affect armor items | 3147700f-d0fb-81d1-af2d-f10546c9ff49 |
| Design unique legendary items with special effects | 3147700f-d0fb-816e-a5dc-f950c0edc8c2 |
| Armor slot system (helmet, chestplate, gloves, legs, boots) | 3147700f-d0fb-8128-a032-dac89055321a |
| Create jewelry items (necklaces, rings with various effects) | 3147700f-d0fb-811c-90c9-f225ed1b7f0d |
| Backpack tier upgrade system (6 tiers, custom shapes, Weaver NPC) | 3147700f-d0fb-8144-8820-ec459d66c111 |
| Backpack upgrade feedback prompt (success/failure message) | 3197700f-d0fb-81dc-af51-d998b928d381 |
| Create armor items with subtypes per slot (5 slots × 4 weight classes) | 3147700f-d0fb-8159-a100-e41b635b055b |
| Display current backpack tier on inventory screen | 3197700f-d0fb-8178-a211-efdfadb30b57 |
| Escalating Spatial Rune cost per backpack tier | 3197700f-d0fb-81a9-b074-eb3cd5e7da38 |
| Expand backpack tiers to 10 with growing shapes | 3197700f-d0fb-815f-b03e-c9829e725cee |
| In-game backpack tier editor (visual grid editor for designers) | 3197700f-d0fb-8124-9842-e3065f25a15f |
| Balance item stats across all tiers | 3147700f-d0fb-81ab-9b39-f75c2f232060 |
| Block percentage property for weapons | 3147700f-d0fb-81c7-950b-f01963d9df36 |
| Custom modifier reach patterns for gems | 3147700f-d0fb-818a-b7eb-e2ab083a4726 |
| Expand weapon variety (new types, innate effects, custom shapes) | 3147700f-d0fb-8180-9e85-e834807b386f |
| Fire gem conditional modifier system | 3147700f-d0fb-81a8-b1ac-d16bb32fad6a |
| Gem design document with reach patterns and tradeoff gems | 31a7700f-d0fb-81f2-871e-c8cc5bd4db83 |
| Hand slot restrictions and weapon hand requirements | 3147700f-d0fb-8129-9675-e03c4ec008bc |
| In-game item editor | 3147700f-d0fb-8155-ab6d-eab88cd8ed20 |
| Inventory grid size upgrades (dedicated resource, not gold) | 3147700f-d0fb-81b6-8525-ff52bea333a2 |
| Item and reach pattern rotation with sprite rotation | 3147700f-d0fb-81bd-8eeb-fc40ffd1e6e4 |
| Item merging by superposing on inventory grid (same-family upgrade) | 3147700f-d0fb-8137-9f62-c46bd2a68bb7 |
| Loot screen item merging (combine adjacent-rarity items post-battle) | 3147700f-d0fb-8131-a045-de18285e13a5 |
| Item crafting system (blacksmith, recipes, blueprints, crafting UI) | 3147700f-d0fb-81da-8598-ebb390809f59 |
| Item database with IDs instead of hardcoding | 3147700f-d0fb-814c-9916-ff72715f5626 |
| Item editor missing fields for innate status effect modifiers | 3147700f-d0fb-811c-bcf3-c99075f27515 |
| Items not picked up from loot panel are lost (no auto-stash) | 3147700f-d0fb-81e7-87d0-d940aaa6e299 |
| Jewelry system (1 necklace, up to 10 rings) | 3147700f-d0fb-81c2-860c-f8c2a1a93a80 |
| Per-character backpack tier selection via Weaver | 3197700f-d0fb-81fa-9239-dd21c31aec28 |
| Loot grid shapes depend on the encounter | 3147700f-d0fb-8141-b6bf-d214ea169ddb |
| Remove gold cost from blacksmith recipes (ingredients only) | 3147700f-d0fb-8189-9733-c20b7f5cc375 |
| Replace loot screen items list with Tetris-style loot grid | 3147700f-d0fb-8131-ac33-c40d90865392 |
| Rotating an item does not rotate its reach shape | 3147700f-d0fb-8148-902e-e729f3b84bc8 |
| Shield system (ACTIVE_TOOL, 1 hand) | 3147700f-d0fb-8104-8f62-fd67ad3217bd |
| Skills determined by items | 3147700f-d0fb-8194-a085-e4f65c8b7154 |

## UI

### Todo
| Name | Notion ID |
|---|---|
| Fix: Shop purchase tracking uses object references instead of item IDs | 31e7700f-d0fb-81dc-9d04-e4b01724e57f |
| Make it possible to use sprites for every UI element | 3147700f-d0fb-8125-924b-dd89c0d6c368 |
| Perf: Shop per-frame highlight checks during drag (only update on state change) | 31e7700f-d0fb-810a-bcf7-fe5be67bfc9c |
| Refactor: Shop drag start duplication (4 identical _start_drag_from_* methods) | 31e7700f-d0fb-8109-be01-ed664bdeaaed |
| Skill visual effects / particles | 3147700f-d0fb-81ca-b249-d2ef0b18fe13 |

### Done
| Name | Notion ID |
|---|---|
| Active skills summary on inventory tab | 3147700f-d0fb-8114-988a-fc8f39722d9f |
| Add status effect proc roll results to battle log | 3147700f-d0fb-8185-87e1-f4c60ca022cd |
| Brightness/gamma setting in graphics options | 31a7700f-d0fb-81bd-97d2-c12bd9665a8e |
| Font size accessibility setting (global scaling) | 31d7700f-d0fb-81ff-b44d-cbeffb97162f |
| Hover tooltip on skills in the stats screen | 3147700f-d0fb-81ad-af11-d4c89a122b55 |
| Auto-fill ingredients in crafting recipes | 3187700f-d0fb-81df-bb9d-f87b59bec21c |
| Highlight matching inventory/stash items when hovering a recipe ingredient | 3187700f-d0fb-814c-b7b4-c76366ceb13c |
| Quick indicator showing if player can craft a recipe (has all ingredients) | 3187700f-d0fb-810f-bea5-f407af15a305 |
| Scale inventory grid UI to support 25x25 backpack sizes | 3197700f-d0fb-81d7-ab44-f163e6492f40 |
| Add a way to throw away / discard items (from stash and inventory) | 3147700f-d0fb-815a-bdd9-e2e7a8b905ef |
| Add stash button to loot screen | 3157700f-d0fb-8144-8b98-dce78dd6206c |
| Cascading parse error from misaligned indentation in item_ | 3147700f-d0fb-81da-a238-da97d9ce20ed |
| Click-relative drag anchor | 3167700f-d0fb-81dd-95c8-ecad0569141c |
| Click-to-inspect vs hold-to-drag item interaction | 3167700f-d0fb-818d-8ea1-c4a76ff6f301 |
| ESC should leave current interface/screen (except battles) | 3147700f-d0fb-8161-93a5-ff4492e35669 |
| Equipment slots indicator panel in inventory UI | 3147700f-d0fb-81fa-a966-f0c1c065485b |
| Limit the size of the stash (enforce MAX_STASH_SLOTS cap) | 3147700f-d0fb-81ca-bb5f-ca52d08ffe82 |
| Loot screen Use button should show target selection popup | 3147700f-d0fb-81f0-bb82-d3b6b4bbe982 |
| Passive + active skills summary on stat tab | 3147700f-d0fb-8164-a2cf-f1e040d541f2 |
| Passive skills summary on skill tab | 3147700f-d0fb-81a8-ac83-ecb3e75d9b71 |
| Pause menu (canvas overlay on overworld) | 3147700f-d0fb-811b-b66e-dfc7febb13eb |
| Persistent party character cards on overworld HUD | 3147700f-d0fb-8110-b6a0-fd11955a5120 |
| Post-battle loot screen with drag-and-drop | 3147700f-d0fb-81c2-89f5-d71b3757d61c |
| Reduce tooltip size and anchor to fixed screen area | 3147700f-d0fb-8115-aa38-c13daf38af9f |
| Settings menu with keyboard rebinding | 3147700f-d0fb-8118-a2d7-da6aba515db9 |
| Squad composition management | 3147700f-d0fb-8102-b0f6-ca4b09adefda |
| Squad screen navigation fix | 3147700f-d0fb-81ff-8966-da551579994a |
| Stash sorting and filtering (by type, rarity; primary + secondary sort) | 3147700f-d0fb-8177-b8a8-f2c7956f3ad3 |
| Take All button on loot screen (enabled when items fit in stash) | 31c7700f-d0fb-8129-8021-cdc40ee4a0c3 |
| Stat screen per character | 3147700f-d0fb-81fd-8c8c-c66fcafd3574 |
| Tooltip doesn't disappear in blacksmith interface | 3147700f-d0fb-8122-8a64-da9a1102d7fe |
| Shadow quality setting in graphics options (off/low/medium/high) | 31a7700f-d0fb-81e6-8234-ffbe8e29cc12 |
| Show number of hands required on weapon card | 3147700f-d0fb-812e-af35-da5c79b9e2b9 |
| UI scale option in settings | 31a7700f-d0fb-8119-8d48-fe49d5aa3000 |
| Unified screen/menu presentation (consistent pattern for all menus) | 3147700f-d0fb-81f2-bd15-d73a21e44b32 |
| Display settings (fullscreen/borderless/windowed + resolution picker) | 31a7700f-d0fb-81fb-b2bb-f1070815de55 |

### Canceled
| Name | Notion ID |
|---|---|
| Damage numbers animation in combat | 3147700f-d0fb-818f-ba77-c458d030d861 |
| Fix: Dialogue typewriter timer not stopped on ESC close | 31e7700f-d0fb-81af-a03a-e0fb18a9d030 |
| Fix: Empty squad crash risk in character hub (no bounds check on squad[0]) | 31e7700f-d0fb-8126-910c-f31a784b563e |
| Screen shake on critical hits | 3147700f-d0fb-81a2-aec3-c2ce33493ba1 |

## World

### Todo
| Name | Notion ID |
|---|---|
| 3D lighting system (DirectionalLight, ambient, per-zone lighting profiles) | 31a7700f-d0fb-8145-a7c2-ef8d8cde6072 |
| Perf: MapCache O(n) eviction on every insertion (use LRU or track oldest) | 31e7700f-d0fb-8133-8cbf-df15c2ba40a6 |
| Perf: Overworld enemy group queries not cached (get_nodes_in_group called repeatedly) | 31e7700f-d0fb-81ca-bfff-df054cac4183 |
| Refactor: Replace magic integers in MapData terrain and PassiveNodeData prerequisite_mode with enums | 31e7700f-d0fb-8196-b221-e966fc7f5a49 |
| Add mechanic to block parts of the map if conditions aren't met | 3147700f-d0fb-8175-a151-f28116c4da26 |
| Expand passive skill tree (PoE-style, 1000-1500 nodes) | 3147700f-d0fb-8186-a0b1-d7f151d23b39 |
| Fixed map system (editable, different placeable elements from DB) | 3147700f-d0fb-81e1-bb8b-efcc06f8f395 |
| Hide and confine mouse cursor during right-click camera orbit | 31d7700f-d0fb-8176-81e6-d3457debd704 |
| Make skill tree connections non-directional (symmetric adjacency) | 3147700f-d0fb-81f1-97ef-fdb331aa69c6 |
| Party management NPC/location (recruit, dismiss, swap roster) | 3147700f-d0fb-8187-8530-dd486e9eac4b |
| Torch and point light sources for caves/dungeons (OmniLight3D with flicker) | 31a7700f-d0fb-8124-97da-dfb58099b239 |

### Done
| Name | Notion ID |
|---|---|
| Character database | 3147700f-d0fb-8131-889b-f4923fdd4e7f |
| Day/night cycle with sun/moon discs, stars, and moon phases | 31d7700f-d0fb-81ca-8369-d82f8404b36c |
| Sun and global light sources (DirectionalLight3D, day/night feel) | 31c7700f-d0fb-813c-9c09-ea2db648611b |
| Fix NPC/enemy ground positioning (auto-grounding + terrain offset) | 31c7700f-d0fb-81a9-8a92-eb792748e73e |
| FF6-style overworld with WASD movement and camera follow | 3147700f-d0fb-8199-84ab-fd7b81806a26 |
| In-game skill tree editor | 3147700f-d0fb-81e3-9f0b-d127387d464f |
| Lake location debug heal (full HP/MP) | 3147700f-d0fb-81a7-acd5-d6fc7fbd5cb6 |
| LocationData system with unlock flags and fast travel | 3147700f-d0fb-8163-9df0-efa02f183795 |
| Multi-part voxel models (split humanoids into articulated limbs with joint pivots) | 3167700f-d0fb-814d-8751-f83f9be095ad |
| Multiple save slots with ring buffer history and auto-save (v5) | 3147700f-d0fb-8193-8014-e7962d0b616b |
| Passive skill tree (gold-based unlocks) | 3147700f-d0fb-8193-aa88-c621abf57896 |
| Procedural walk/idle animations (ModelAnimator) | 3167700f-d0fb-81c4-9b93-d8fa5e1062a5 |
| Replace fixed skill tree gold cost with formula based on total unlocked | 3147700f-d0fb-814a-b361-e4cf3a502314 |
| Camera occlusion system (fade objects blocking player view) | 31d7700f-d0fb-813f-abf0-fc09537f2b9e |
| Save/load system | 3147700f-d0fb-81da-b76d-df2d3a042f5f |

## Audio

### Todo
| Name | Notion ID |
|---|---|
| Ambient/environmental sounds on overworld | 3147700f-d0fb-81b4-a552-ddbe7cc4a6bd |
| Audio settings (master, music, SFX volume) in settings menu | 3147700f-d0fb-8120-b141-c71105c35878 |
| Background music for each scene (menu, overworld, battle, menus) | 3147700f-d0fb-815c-9201-ea3e1510d788 |
| Smooth music transitions when switching scenes (crossfade) | 3147700f-d0fb-818f-9658-da34eecfe665 |
| Sound effects for UI interactions (clicks, navigation, drag & drop) | 3147700f-d0fb-819d-841c-c48673a23278 |
| Sound effects for combat (attacks, skills, hits, misses, crits) | 3147700f-d0fb-8139-9a2e-d717663bc021 |
| Sound effects for events (gold earned, item pickup, passive unlocked) | 3147700f-d0fb-814b-9aeb-eaa923296267 |
| Victory and defeat jingles | 3147700f-d0fb-810e-b701-f87c98675251 |

## Story

### Todo
| Name | Notion ID |
|---|---|
| Character development (unique abilities, recruitment through story) | 3147700f-d0fb-8117-9a63-d0229a710e9e |
| Multiple endings based on choices | 3147700f-d0fb-810a-a46f-f7665b9547fb |
| Cinematic animation system (cutscene keyframes, emotes, camera) | 3167700f-d0fb-8100-81ba-ca342993e653 |
| Story mode with cutscenes (dialogue boxes, portraits, animations) | 3147700f-d0fb-81e4-ab7f-db0be244f117 |

## Gamepad

### Todo
| Name | Notion ID |
|---|---|
| Full gamepad support (all menus, combat, overworld, inventory) | 3147700f-d0fb-8186-8a07-dc1d01cb7b13 |
| Inventory/stash cursor navigation with stick or d-pad | 3147700f-d0fb-8174-b620-fed634211481 |
| On-screen button prompts (auto-switch keyboard/gamepad glyphs) | 3147700f-d0fb-81a5-b5aa-d3da863465d7 |
| Steam Deck compatibility (16:10, touch input, Steam Input profile) | 3147700f-d0fb-8153-8191-e352b4bd66ba |

## Localisation

### Todo
| Name | Notion ID |
|---|---|
| Initial languages: English + French | 3147700f-d0fb-810c-94aa-d524fe8067f5 |
| Integrate Godot TranslationServer (CSV/PO translation files) | 3147700f-d0fb-81c0-ac58-e8680c955a0f |
| Language selector in settings menu (persist across sessions) | 3147700f-d0fb-81dc-b6b5-f6cfe10825c3 |

## QoL

### Todo
| Name | Notion ID |
|---|---|
| Colorblind-friendly item rarity palette (alternate color scheme in settings) | 31a7700f-d0fb-81eb-b63a-eb24fa14c8ab |
| Fix: TutorialManager global pause can break in-progress UI state (use process_mode isolation) | 31e7700f-d0fb-8192-958c-f2bf8c1e8a83 |
| Perf: DisplayManager font rescaling fires on every Control node add (use theme-level scaling) | 31e7700f-d0fb-8162-99a5-fcacb779cade |
| Perf: QuestManager iterates all quests on every inventory change (cache by objective type) | 31e7700f-d0fb-8182-be76-e7b1cf2233ea |
| Refactor: Extract generic database loader helper (deduplicate 6 database autoloads) | 31e7700f-d0fb-812a-8a3b-f4aab2cbb191 |
| Refactor: Move NpcRole enum from npc_data.gd to central Enums.gd | 31e7700f-d0fb-811c-af42-e77b2ce2c5fd |
| Refactor: QuestManager verbose dictionary iteration pattern (unnecessary array copies) | 31e7700f-d0fb-8134-9dff-f377b9855f12 |
| Equipment loadout presets | 3147700f-d0fb-81f3-847b-fb6e0c531b16 |
| In-game constants/variables editor (live UI tweaking without restart) | 31a7700f-d0fb-811c-892d-de28e42a725f |

### Done
| Name | Notion ID |
|---|---|
| Batch sell items | 3147700f-d0fb-8156-8cd8-e5ddc36aaa8a |
| Font size accessibility option in settings | 31a7700f-d0fb-819a-a559-e03b7a9161b8 |
| Battle speed controls | 3147700f-d0fb-81c4-b2e5-d61ae1108830 |
| Equipment comparison tooltips | 3147700f-d0fb-81af-9b15-f99954c257eb |
| Full GDScript warning cleanup (~50+ warnings fixed) | 3147700f-d0fb-8176-bc39-ee92449e85f4 |
| Item sorting and filtering in inventory | 3147700f-d0fb-8104-915f-f271f0b0994f |
| Multiple save slots (5-10) with metadata | 3147700f-d0fb-81a1-a075-f7cb35bbae6f |
| Fix: SaveManager vitals re-clamping uses fragile heuristic (add save version flag) | 31e7700f-d0fb-8107-baaf-d39753948616 |
| Scene stashing and terrain cache for faster transitions | 31d7700f-d0fb-81c9-8e90-cd1dd0ff7d24 |
| Tutorial / onboarding for new mechanics | 3147700f-d0fb-8135-a266-d09ba2607b2a |

### Canceled
| Name | Notion ID |
|---|---|
| Fix: Missing FileAccess error handling in autoloads (debug_logger, input_manager, display_manager) | 31e7700f-d0fb-81c0-8d5a-c79c08b113ac |

## Map Editor

### Todo
| Name | Notion ID |
|---|---|
| Canvas interaction (select, place, drag, delete) | 3147700f-d0fb-8193-af8b-fdbfba5c26ef |
| Canvas rendering (grid, elements by type, spawn marker) | 3147700f-d0fb-8188-b1f9-cc2fec86fa6b |
| Default overworld map (export current overworld to MapData) | 3147700f-d0fb-813a-ac29-f0090ea6d61b |
| Main menu button integration for map editor | 3147700f-d0fb-81e1-93d6-ecc0151abd58 |
| Map editor save/load (ResourceSaver, MapDatabase.reload()) | 3147700f-d0fb-8139-ad92-ef4e504e0dcf |
| Map editor scene layout (.tscn) | 3147700f-d0fb-8132-a958-fa6c3c4904c7 |
| Map list panel (CRUD, search, dirty tracking) | 3147700f-d0fb-8185-baad-fc2ffe8645d7 |
| MapData, MapElement, MapConnection resource scripts | 3147700f-d0fb-8141-ac6e-ee067a9e7bc3 |
| MapDatabase autoload | 3147700f-d0fb-81ab-a6f4-ea9947b348ff |
| MapLoader runtime (convert MapData to playable scenes) | 3147700f-d0fb-81e7-b2c8-f73d0a9e46fc |
| Property panel (map properties + per-element-type sections) | 3147700f-d0fb-8136-a690-d3203f860d02 |

### Done
| Name | Notion ID |
|---|---|
| Map-to-map transitions (ConnectionMarker, editor tool, save/load) | 31d7700f-d0fb-814c-8757-e57a39153512 |

## 3D Migration

### Todo
| Name | Notion ID |
|---|---|
| 3D equipment models (CSG then voxel for weapons, armor, accessories) | 3157700f-d0fb-8123-8cfc-e54ef7f3c76f |
| Cinematic animation system (cutscene keyframes, emotes, camera) | 3167700f-d0fb-8100-81ba-ca342993e653 |
| Procedural cast/spell animations (channel, release, recoil) | 3167700f-d0fb-81fb-a067-c9a60e934df5 |
| Visual equipment system (3D character appearance changes with gear) | 3157700f-d0fb-81e0-8c8b-e175caafef03 |

### Done
| Name | Notion ID |
|---|---|
| 3D damage popup positioning (Camera3D.unproject_position) | 3157700f-d0fb-81ce-a429-c4b709ed7255 |
| 3D project foundation (WorldEnvironment, lighting, renderer, physics layers) | 3157700f-d0fb-81ad-8a3f-d70c0325f9f4 |
| Add model_scene field to CharacterData, EnemyData, NpcData | 3157700f-d0fb-81fc-919d-ddeb8e113937 |
| Create GridMap terrain MeshLibrary (grass, dirt, stone, water blocks) | 3157700f-d0fb-813d-8fea-d3c5a0983843 |
| CSG character model factory (humanoid primitives, color tinting) | 3157700f-d0fb-81ae-a9b9-eee898a9b5d2 |
| Create voxel models for all game objects (characters, enemies, items, world) | 3157700f-d0fb-8109-bb44-c2759d60ceeb |
| Free-rotating orbit camera system (Camera3D, orbit, zoom, pan) | 3157700f-d0fb-813b-8b8a-ff8a95e0b5ad |
| MagicaVoxel import pipeline (.vox models, replace CSG placeholders) | 3157700f-d0fb-810a-88ca-d26a22f357fe |
| Multi-part voxel models (split humanoids into articulated limbs with joint pivots) | 3167700f-d0fb-814d-8751-f83f9be095ad |
| Procedural attack animations (slash, thrust, bash per weapon type) | 3167700f-d0fb-81eb-ac24-c3a121c9bc8f |
| Procedural walk/idle animations (ModelAnimator) | 3167700f-d0fb-81c4-9b93-d8fa5e1062a5 |
| Port battle scene to 3D (Node3D BattleWorld, Camera3D, CSG models) | 3157700f-d0fb-816a-9d4f-e013c03f2468 |
| Port markers to 3D (location, NPC, enemy, encounter zones) | 3157700f-d0fb-81fb-adc8-f1ecc9017a4d |
| Port overworld to 3D (Node3D, GridMap, CharacterBody3D) | 3157700f-d0fb-8103-997e-f8eba4f96720 |
| Replace 2D world objects with 3D CSG meshes (trees, rocks, bushes) | 3157700f-d0fb-81d6-9716-f728b10176d4 |
