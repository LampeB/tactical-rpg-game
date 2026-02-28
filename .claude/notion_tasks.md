# Notion Tasks Map
<\!-- Auto-generated from Notion Tasks database (787232f1-3840-4c99-9f5b-a4e3da59293c) -->
<\!-- Data source (Claude AI connector): fe3e9c59-0d0b-4072-a5ee-96051dc534b9 -->
<\!-- Total tasks: 147 -->
<\!-- Last updated: 2026-02-28 -->

## Prerequisites

### Todo
| Name | Notion ID |
|---|---|
| Chest opened state persistence (story flags) | 3147700f-d0fb-8144-b4f2-c5a86a55c8d5 |
| Chest scene (Area2D, interact to open, animation) | 3147700f-d0fb-8155-a5c0-f76b87605bde |
| ChestData resource (id, loot_table, opened_flag, visual_type) | 3147700f-d0fb-816b-95d8-e0901308d9b7 |
| Connect chests to LootTable/LootGenerator systems | 3147700f-d0fb-81a2-88ae-e79c214e2564 |
| Create town area maps (starting town, cities, villages) | 3147700f-d0fb-813e-877a-d3243e44be13 |
| Design multi-floor dungeons (5-7 dungeons, 3-5 floors, bosses) | 3147700f-d0fb-81fa-83e2-f2424660f5ef |
| In-game shop editor (create/manage shops, define inventory and pricing) | 3147700f-d0fb-81ba-88fa-d2f169fb6a3b |
| Loot popup UI (show acquired items after opening chest) | 3147700f-d0fb-8183-99c5-d733d508be01 |
| Permanently remove items from shop stock when bought | 3147700f-d0fb-8195-9b19-fd4024d1ae34 |
| Quest EventBus integration (quest signals) | 3147700f-d0fb-81ec-8e9e-c87c73daa4e3 |
| Quest log UI (active/completed quests, tracking, rewards) | 3147700f-d0fb-81e1-b662-c547118990b5 |
| Quest marker visuals (icons above NPCs/locations) | 3147700f-d0fb-81e2-a100-da43c582626a |
| Quest story flag integration (set/check flags for map unlocking) | 3147700f-d0fb-8154-a271-f92bb5924b7c |
| QuestData resource (id, title, objectives, rewards, prerequisites) | 3147700f-d0fb-81af-9407-d357a359aec7 |
| QuestManager autoload (track quests, check objectives, award rewards) | 3147700f-d0fb-8192-861e-f99e647a1be0 |
| QuestObjective resource (kill, collect, talk_to, reach_location) | 3147700f-d0fb-81f2-b001-f59a8b365536 |

### Done
| Name | Notion ID |
|---|---|
| Connect shop to existing inventory system (GridInventory) | 3147700f-d0fb-81fa-9503-fb18c56790eb |
| Dialogue UI scene (portrait, text box, choices, typewriter effect) | 3147700f-d0fb-813d-8b3d-e60f4a0b60ab |
| Dialogue tree data structure (nodes, choices, conditions, outcomes) | 3147700f-d0fb-81c5-995c-de5acb39f78a |
| In-game NPC/dialogue editor | 3147700f-d0fb-818f-b549-c632838e7cff |
| NPC & dialogue system (NpcData, dialogue tree, dialogue UI, NPC markers) | 3147700f-d0fb-819d-a8db-ca9bd148bf24 |
| Npc scene (Area2D, triggers dialogue on interact) | 3147700f-d0fb-8164-8585-d9c32e8a8d9b |
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
| Implement defend action (damage reduction via shield/defense) | 3147700f-d0fb-81a3-853e-dd34af44a4d4 |
| In-game enemy editor (debug/dev tool) | 3147700f-d0fb-8107-bc59-e7045338d970 |
| Overworld encounter balancing (enemy count, spawn positions) | 3147700f-d0fb-819c-8b91-c1216a41e3db |
| Restrict roaming enemies from entering town/NPC areas | 3147700f-d0fb-81af-9c68-e10347a8d3e9 |

### Done
| Name | Notion ID |
|---|---|
| Dead characters persist death across battles (no auto-revive) | 3147700f-d0fb-81f1-8f45-fc6389364961 |
| EncounterZoneData for enemy spawn areas | 3147700f-d0fb-8166-8fcb-f55ede7b5342 |
| KO'd characters still play animations / act during battle | 3147700f-d0fb-8101-b64d-e663c1304ba2 |
| Persist HP/Mana after fights | 3147700f-d0fb-8119-8955-f25b43a7be3a |
| Runtime errors: typed array assignment from Variant | 3147700f-d0fb-81de-886d-db067f32a2a2 |
| Use skills/items outside of combat (healing) | 3147700f-d0fb-8171-8223-c3f36449a4f2 |
| Visible roaming enemies (Chrono Trigger style) | 3147700f-d0fb-8128-86b2-d501c34afda8 |

## Items

### Todo
| Name | Notion ID |
|---|---|
| Allow modifiers (gems) to affect armor items | 3147700f-d0fb-81d1-af2d-f10546c9ff49 |
| Balance item stats across all tiers | 3147700f-d0fb-81ab-9b39-f75c2f232060 |
| Create armor items with subtypes per slot (5 slots Ã— 4 weight classes) | 3147700f-d0fb-8159-a100-e41b635b055b |
| Create jewelry items (necklaces, rings with various effects) | 3147700f-d0fb-811c-90c9-f225ed1b7f0d |
| Design unique legendary items with special effects | 3147700f-d0fb-816e-a5dc-f950c0edc8c2 |
| Expand weapon variety (multiple tiers: iron â†’ steel â†’ mythril â†’ legendary) | 3147700f-d0fb-8180-9e85-e834807b386f |
| Inventory grid size upgrades (dedicated resource, not gold) | 3147700f-d0fb-81b6-8525-ff52bea333a2 |
| Item merging by superposing on inventory grid (same-family upgrade) | 3147700f-d0fb-8137-9f62-c46bd2a68bb7 |
| Loot screen item merging (combine adjacent-rarity items post-battle) | 3147700f-d0fb-8131-a045-de18285e13a5 |
| Remove gold cost from blacksmith recipes (ingredients only) | 3147700f-d0fb-8189-9733-c20b7f5cc375 |

### Done
| Name | Notion ID |
|---|---|
| Armor slot system (helmet, chestplate, gloves, legs, boots) | 3147700f-d0fb-8128-a032-dac89055321a |
| Backpack tier upgrade system (6 tiers, custom shapes, Weaver NPC) | 3147700f-d0fb-8144-8820-ec459d66c111 |
| Block percentage property for weapons | 3147700f-d0fb-81c7-950b-f01963d9df36 |
| Custom modifier reach patterns for gems | 3147700f-d0fb-818a-b7eb-e2ab083a4726 |
| Fire gem conditional modifier system | 3147700f-d0fb-81a8-b1ac-d16bb32fad6a |
| Hand slot restrictions and weapon hand requirements | 3147700f-d0fb-8129-9675-e03c4ec008bc |
| In-game item editor | 3147700f-d0fb-8155-ab6d-eab88cd8ed20 |
| Item and reach pattern rotation with sprite rotation | 3147700f-d0fb-81bd-8eeb-fc40ffd1e6e4 |
| Item crafting system (blacksmith, recipes, blueprints, crafting UI) | 3147700f-d0fb-81da-8598-ebb390809f59 |
| Item database with IDs instead of hardcoding | 3147700f-d0fb-814c-9916-ff72715f5626 |
| Item editor missing fields for innate status effect modifiers | 3147700f-d0fb-811c-bcf3-c99075f27515 |
| Items not picked up from loot panel are lost (no auto-stash) | 3147700f-d0fb-81e7-87d0-d940aaa6e299 |
| Jewelry system (1 necklace, up to 10 rings) | 3147700f-d0fb-81c2-860c-f8c2a1a93a80 |
| Loot grid shapes depend on the encounter | 3147700f-d0fb-8141-b6bf-d214ea169ddb |
| Replace loot screen items list with Tetris-style loot grid | 3147700f-d0fb-8131-ac33-c40d90865392 |
| Rotating an item does not rotate its reach shape | 3147700f-d0fb-8148-902e-e729f3b84bc8 |
| Shield system (ACTIVE_TOOL, 1 hand) | 3147700f-d0fb-8104-8f62-fd67ad3217bd |
| Skills determined by items | 3147700f-d0fb-8194-a085-e4f65c8b7154 |

## UI

### Todo
| Name | Notion ID |
|---|---|
| Add a way to throw away / discard items (from stash and inventory) | 3147700f-d0fb-815a-bdd9-e2e7a8b905ef |
| Add status effect proc roll results to battle log | 3147700f-d0fb-8185-87e1-f4c60ca022cd |
| Damage numbers animation in combat | 3147700f-d0fb-818f-ba77-c458d030d861 |
| Hover tooltip on skills in the stats screen | 3147700f-d0fb-81ad-af11-d4c89a122b55 |
| Limit the size of the stash (enforce MAX_STASH_SLOTS cap) | 3147700f-d0fb-81ca-bb5f-ca52d08ffe82 |
| Make it possible to use sprites for every UI element | 3147700f-d0fb-8125-924b-dd89c0d6c368 |
| Reduce tooltip size and anchor to fixed screen area | 3147700f-d0fb-8115-aa38-c13daf38af9f |
| Screen shake on critical hits | 3147700f-d0fb-81a2-aec3-c2ce33493ba1 |
| Show number of hands required on weapon card | 3147700f-d0fb-812e-af35-da5c79b9e2b9 |
| Skill visual effects / particles | 3147700f-d0fb-81ca-b249-d2ef0b18fe13 |
| Stash sorting and filtering (by type, rarity; primary + secondary sort) | 3147700f-d0fb-8177-b8a8-f2c7956f3ad3 |
| Unified screen/menu presentation (consistent pattern for all menus) | 3147700f-d0fb-81f2-bd15-d73a21e44b32 |

### Done
| Name | Notion ID |
|---|---|
| Active skills summary on inventory tab | 3147700f-d0fb-8114-988a-fc8f39722d9f |
| Cascading parse error from misaligned indentation in item_ | 3147700f-d0fb-81da-a238-da97d9ce20ed |
| ESC should leave current interface/screen (except battles) | 3147700f-d0fb-8161-93a5-ff4492e35669 |
| Equipment slots indicator panel in inventory UI | 3147700f-d0fb-81fa-a966-f0c1c065485b |
| Loot screen Use button should show target selection popup | 3147700f-d0fb-81f0-bb82-d3b6b4bbe982 |
| Passive + active skills summary on stat tab | 3147700f-d0fb-8164-a2cf-f1e040d541f2 |
| Passive skills summary on skill tab | 3147700f-d0fb-81a8-ac83-ecb3e75d9b71 |
| Pause menu (canvas overlay on overworld) | 3147700f-d0fb-811b-b66e-dfc7febb13eb |
| Persistent party character cards on overworld HUD | 3147700f-d0fb-8110-b6a0-fd11955a5120 |
| Post-battle loot screen with drag-and-drop | 3147700f-d0fb-81c2-89f5-d71b3757d61c |
| Settings menu with keyboard rebinding | 3147700f-d0fb-8118-a2d7-da6aba515db9 |
| Squad composition management | 3147700f-d0fb-8102-b0f6-ca4b09adefda |
| Squad screen navigation fix | 3147700f-d0fb-81ff-8966-da551579994a |
| Stat screen per character | 3147700f-d0fb-81fd-8c8c-c66fcafd3574 |
| Tooltip doesn't disappear in blacksmith interface | 3147700f-d0fb-8122-8a64-da9a1102d7fe |

## World

### Todo
| Name | Notion ID |
|---|---|
| Add mechanic to block parts of the map if conditions aren't met | 3147700f-d0fb-8175-a151-f28116c4da26 |
| Expand passive skill tree (PoE-style, 1000-1500 nodes) | 3147700f-d0fb-8186-a0b1-d7f151d23b39 |
| Fixed map system (editable, different placeable elements from DB) | 3147700f-d0fb-81e1-bb8b-efcc06f8f395 |
| Make skill tree connections non-directional (symmetric adjacency) | 3147700f-d0fb-81f1-97ef-fdb331aa69c6 |
| Party management NPC/location (recruit, dismiss, swap roster) | 3147700f-d0fb-8187-8530-dd486e9eac4b |
| Replace fixed skill tree gold cost with formula based on total unlocked | 3147700f-d0fb-814a-b361-e4cf3a502314 |

### Done
| Name | Notion ID |
|---|---|
| Character database | 3147700f-d0fb-8131-889b-f4923fdd4e7f |
| FF6-style overworld with WASD movement and camera follow | 3147700f-d0fb-8199-84ab-fd7b81806a26 |
| In-game skill tree editor | 3147700f-d0fb-81e3-9f0b-d127387d464f |
| Lake location debug heal (full HP/MP) | 3147700f-d0fb-81a7-acd5-d6fc7fbd5cb6 |
| LocationData system with unlock flags and fast travel | 3147700f-d0fb-8163-9df0-efa02f183795 |
| Multiple save slots with ring buffer history and auto-save (v5) | 3147700f-d0fb-8193-8014-e7962d0b616b |
| Passive skill tree (gold-based unlocks) | 3147700f-d0fb-8193-aa88-c621abf57896 |
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
| Batch sell items | 3147700f-d0fb-8156-8cd8-e5ddc36aaa8a |
| Battle speed controls | 3147700f-d0fb-81c4-b2e5-d61ae1108830 |
| Equipment comparison tooltips | 3147700f-d0fb-81af-9b15-f99954c257eb |
| Equipment loadout presets | 3147700f-d0fb-81f3-847b-fb6e0c531b16 |
| Item sorting and filtering in inventory | 3147700f-d0fb-8104-915f-f271f0b0994f |
| Tutorial / onboarding for new mechanics | 3147700f-d0fb-8135-a266-d09ba2607b2a |

### Done
| Name | Notion ID |
|---|---|
| Full GDScript warning cleanup (~50+ warnings fixed) | 3147700f-d0fb-8176-bc39-ee92449e85f4 |
| Multiple save slots (5-10) with metadata | 3147700f-d0fb-81a1-a075-f7cb35bbae6f |

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

## 3D Migration

### Todo
| Name | Notion ID |
|---|---|
| 3D project foundation (WorldEnvironment, lighting, renderer, physics layers) | 3157700f-d0fb-81ad-8a3f-d70c0325f9f4 |
| Free-rotating orbit camera system (Camera3D, orbit, zoom, pan) | 3157700f-d0fb-813b-8b8a-ff8a95e0b5ad |
| CSG character model factory (humanoid primitives, color tinting) | 3157700f-d0fb-81ae-a9b9-eee898a9b5d2 |
| Add model_scene field to CharacterData, EnemyData, NpcData | 3157700f-d0fb-81fc-919d-ddeb8e113937 |
| Port overworld to 3D (Node3D, GridMap, CharacterBody3D) | 3157700f-d0fb-8103-997e-f8eba4f96720 |
| Port markers to 3D (location, NPC, enemy, encounter zones) | 3157700f-d0fb-81fb-adc8-f1ecc9017a4d |
| Replace 2D world objects with 3D CSG meshes (trees, rocks, bushes) | 3157700f-d0fb-81d6-9716-f728b10176d4 |
| Create GridMap terrain MeshLibrary (grass, dirt, stone, water blocks) | 3157700f-d0fb-813d-8fea-d3c5a0983843 |
| Port battle scene to 3D (Node3D BattleWorld, Camera3D, CSG models) | 3157700f-d0fb-816a-9d4f-e013c03f2468 |
| 3D damage popup positioning (Camera3D.unproject_position) | 3157700f-d0fb-81ce-a429-c4b709ed7255 |
| MagicaVoxel import pipeline (.vox models, replace CSG placeholders) | 3157700f-d0fb-810a-88ca-d26a22f357fe |
| Visual equipment system (3D character appearance changes with gear) | 3157700f-d0fb-81e0-8c8b-e175caafef03 |
| 3D equipment models (CSG then voxel for weapons, armor, accessories) | 3157700f-d0fb-8123-8cfc-e54ef7f3c76f |
| Create voxel models for all game objects (characters, enemies, items, world) | 3157700f-d0fb-8109-bb44-c2759d60ceeb |
