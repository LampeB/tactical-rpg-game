# Architecture Overview
> Generated 2026-05-11 — Phase 1 codebase audit (read-only)

Godot 4.6 · GDScript · GL Compatibility · 1920×1080 · Main scene: `scenes/main_menu/main_menu.tscn`

---

## 1. Autoloads / Singletons

All 20 autoloads registered in `project.godot`. Load order matters — DebugLogger first, EventBus second.

| Name | File | Role | Key connections |
|------|------|------|----------------|
| **DebugLogger** | `scripts/autoload/debug_logger.gd` | Category-tagged logging to file + console | Used by every other system |
| **EventBus** | `scripts/autoload/event_bus.gd` | Global signal bus (26 signals) | Central hub; see §6 |
| **ItemDatabase** | `scripts/autoload/item_database.gd` | Loads + indexes all `ItemData` .tres from `data/items/`; `get_item(id)` | Emits `item_database_reloaded` on `reload()` |
| **CharacterDatabase** | `scripts/autoload/character_database.gd` | Loads `CharacterData` from `data/characters/` | Used by GameManager.new_game() |
| **PassiveTreeDatabase** | `scripts/autoload/passive_tree_database.gd` | Loads single `PassiveTreeData` from `data/passive_trees/` | Used by GameManager, battle, stats |
| **GameManager** | `scripts/autoload/game_manager.gd` | Party, gold, story_flags, completed_missions, preloaded battle bg | Connects: `item_database_reloaded`, `inventory_changed` |
| **SaveManager** | `scripts/autoload/save_manager.gd` | JSON save/load — v9 format, 5 slots + autosave, 5 history entries/slot | Emits `game_saved`, `game_loaded` |
| **SceneManager** | `scripts/autoload/scene_manager.gd` | push/pop/replace with fade overlay + scene stack; calls `receive_data(dict)` on new scenes | Used by everything for navigation |
| **InputManager** | `scripts/autoload/input_manager.gd` | Custom key rebinding; persisted to `user://input_bindings.json` | Used by TutorialManager keybind resolution |
| **UIColors** | `scripts/autoload/ui_colors.gd` | Named Color constants for all UI backgrounds | Used by all scenes (`UIColors.BG_*`) |
| **NpcDatabase** | `scripts/autoload/npc_database.gd` | Loads `NpcData` from `data/npcs/` | Used by dialogue_ui |
| **ShopDatabase** | `scripts/autoload/shop_database.gd` | Loads `ShopData` from `data/shops/` | Used by shop_ui |
| **ChestDatabase** | `scripts/autoload/chest_database.gd` | Loads `ChestData` from `data/chests/` | Used by loot/dialogue |
| **QuestManager** | `scripts/autoload/quest_manager.gd` | Quest state via `GameManager.story_flags`; auto-progresses objectives | Connects: `combat_ended`, `dialogue_ended`, `location_prompt_visible`, `inventory_changed`, `game_loaded` |
| **TutorialManager** | `scripts/autoload/tutorial_manager.gd` | First-encounter tooltip overlays; pauses `get_tree()` while shown | Connects: `combat_started`, `backpack_expanded`, `quest_accepted` |
| **DisplayManager** | `scripts/autoload/display_manager.gd` | Resolution, quality, debug-mode toggle; signal `graphics_changed` | Used by environment_3d, settings_menu |
| **DayNightCycle** | `scripts/autoload/day_night_cycle.gd` | Real-time 600s/cycle lighting simulation; paused during battle | Polled by environment_3d (`_process`), sampled by battle.gd on start |
| **AudioManager** | `scripts/autoload/audio_manager.gd` | Music + SFX playback; `play_music(key)` / `play_sfx(key)` | Used by battle, main_menu, hub |
| **LocaleManager** | `scripts/autoload/locale_manager.gd` | EN/FR i18n via Godot TranslationServer | Applied globally |
| **LiveTweaks** | `scripts/autoload/live_tweaks.gd` | Runtime debug variable tweaks; read/written by tweaks_editor | Debug mode only |

---

## 2. Major Scenes

### Core Navigation (Working)

| Scene | Purpose | Notes |
|-------|---------|-------|
| `scenes/main_menu/main_menu.tscn` | Entry point | New Game / Load / Continue; editor buttons hidden behind `DisplayManager.debug_mode` |
| `scenes/hub/hub.tscn` | Out-of-battle hub | Mission Board, Party, Merchant, Blacksmith, Doctor (heals in-place), Quit |
| `scenes/hub/mission_board.tscn` | Mission list | Reads `data/missions/`; filters completed missions; pushes mission_briefing |
| `scenes/hub/mission_briefing.tscn` | Pre-battle briefing | Shows enemy roster + rewards; pre-loads forest_clearing as 3D bg; launches battle |
| `scenes/battle/battle.tscn` | Full combat | 2D UI overlay + 3D SubViewport; orchestrates CombatManager, animations, camera |

### Character Management (In-Transition)

| Scene | Purpose | Status |
|-------|---------|--------|
| `scenes/character_stats/character_stats.tscn` | Inventory grid + stats + skills + passives | **Active** — pushed by Hub's "Party" button |
| `scenes/character_hub/character_hub.tscn` | Unified Stats/Passives/Skills tabbed view | **In-progress** — not linked from hub yet; being built as replacement for character_stats |
| `scenes/menus/game_menu.tscn` | ESC-key overlay menu | **In-progress** — written but not instantiated anywhere; designed to replace pause_menu + character_hub |
| `scenes/character_skills/character_skills.tscn` | Character skill list | Active (embedded in character_hub and game_menu) |
| `scenes/passive_tree/passive_tree.tscn` | Passive skill tree | Active (embedded in character_hub and game_menu) |
| `scenes/party_management/party_management_ui.tscn` | Roster → squad management | Active; opened via NPC dialogue action `"open_party_management"` |
| `scenes/squad/squad.tscn` | Squad add/remove screen | Working but not exposed from hub (reachable via dialogue or direct push) |

### Economy & UI (Working)

| Scene | Purpose |
|-------|---------|
| `scenes/shop/shop_ui.tscn` | Buy/sell with drag-and-drop; buyback before leaving |
| `scenes/crafting/crafting_ui.tscn` | Crafting station; recipe grid |
| `scenes/loot/loot.tscn` | Post-battle loot screen; drag to backpack/stash |
| `scenes/dialogue/dialogue_ui.tscn` | NPC dialogue with branching choices + action hooks |
| `scenes/settings/settings_menu.tscn` | Display / audio / input settings |
| `scenes/menus/save_load_menu.tscn` | Save/load slot picker |
| `scenes/menus/quest_log_ui.tscn` | Quest log with objective progress |

### Battle UI Sub-scenes (Working)

All under `scenes/battle/ui/`: `action_menu`, `battle_log`, `battle_sprite`, `battle_vfx`, `damage_popup`, `entity_status_bar`, `turn_order_bar`

### Terrain / World (Mixed)

| Scene | Purpose | Status |
|-------|---------|--------|
| `scenes/maps/forest_clearing.tscn` | Procedurally generated forest battle arena | **Active** — loaded at runtime by mission_briefing, trees/water/props built via `_generate_all()` |
| `scenes/shared/environment_3d.tscn` | Day/night lighting bridge | Active (used by forest_clearing) |
| `scenes/shared/test_3d.tscn` | Developer 3D test scene | **Likely dead** |
| `scenes/maps/forest_clearing_ortho_test.tscn` | Ortho camera experiment | **Dead** — scrapped per git history (commit 94c11c59) |

### Editor/Debug Tools (Working, debug-mode only)

`scenes/tree_editor/`, `scenes/item_editor/`, `scenes/npc_editor/`, `scenes/backpack_editor/`, `scenes/debug/tweaks_editor.tscn`

---

## 3. Systems

### Combat System
**Files**: `scripts/systems/combat/`
- `combat_manager.gd` (class `CombatManager`) — ATB turn queue sorted by speed; runs `start_combat()` → `advance_turn()` loop; signals: `turn_ready`, `action_resolved`, `combat_finished`, `entity_died`, `log_message`, `status_ticked`
- `combat_entity.gd` (class `CombatEntity`) — Single combatant wrapping `CharacterData` or `EnemyData`; holds stats, grid inventory ref, active status effects, tool modifier states
- `damage_calculator.gd` (class `DamageCalculator`) — Damage formula: physical/magical scaling, element reactions, crit chance/damage, defense reduction, defend-stance halving
- `enemy_ai.gd` (class `EnemyAI`) — Static decision maker; 60% skill / 40% basic attack; returns `{action, skill, targets}` dict

**Depends on**: `CombatEntity`, `DamageCalculator`, `EnemyAI`, `PassiveEffects`, `SkillData`, `EnemyData`, `StatusEffect`, `StatusInteractionRule`
**Used by**: `scenes/battle/battle.gd`

### Inventory System
**Files**: `scripts/systems/inventory/`
- `grid_inventory.gd` (class `GridInventory`) — Tetris-style placement with rotation, overlap detection, template masking; inner class `PlacedItem`; emits `EventBus.item_placed/removed/inventory_changed`
- `inventory_undo.gd` (class `InventoryUndo`) — Undo/redo stack for drag operations
- `tool_modifier_state.gd` (class `ToolModifierState`) — Per-item gem-slot activation state

**Depends on**: `ItemData`, `ItemShape`, `GridTemplate`
**Used by**: `Party`, `GameManager`, `battle.gd`, `character_stats`, all inventory UI scenes

### Loot System
**Files**: `scripts/systems/loot/loot_generator.gd` (class `LootGenerator`)
Generates `Array[ItemData]` from `LootTable` resources, weighted random selection.
**Depends on**: `LootTable`, `LootEntry`, `ItemDatabase`
**Used by**: `battle.gd` after victory

### Camera System
**Files**: `scripts/systems/camera/`
- `orbit_camera.gd` (class `OrbitCamera`) — 3D orbital camera; used in overworld/test scenes
- `camera_occlusion.gd` (class `CameraOcclusion`) — Makes meshes transparent when between camera and player

**Status**: Overworld camera likely unused (no overworld); battle has its own inline camera logic.

### Terrain System
**Files**: `scripts/terrain/` (35 files)

Active (still used by `forest_clearing.tscn`):
- `forest_clearing_generator.gd` — `@tool`; generates trees, water, props, battle arena at runtime; called by `mission_briefing._run_forest_generator()`
- `heightmap_terrain_3d.gd`, `heightmap_chunk.gd`, `heightmap_data.gd` — Heightmap mesh builder
- `battle_area_3d.gd` — Marks battle arena zone; exposes center + rotation for camera/entity placement
- `prop_scatter.gd`, `prop_scatter_zone_3d.gd`, `prop_definition.gd`, `prop_registry.gd` — Forest prop placement via Poisson disk
- `structure_manager.gd`, `structure_piece.gd`, `structure_registry.gd`, `placed_structure.gd` — Modular building placement
- `water_zone.gd`, `water_body.gd`, `river_path.gd`, `river_body.gd`, `river_generator_local.gd` — Water/river rendering within forest clearing
- `map_particle_emitter.gd`, `wind_applicator.gd`, `poisson_disk.gd`, `map_gen_utils.gd`, `editor_gizmo_builder.gd` — Utility helpers

Dead (overworld was scrapped):
`terrain_manager.gd`, `overworld_heightmap_generator.gd`, `biome_heightmap_generator.gd`, `test_heightmap_generator.gd`, `road_generator.gd`, `town_layout_generator.gd`, `poi_generator.gd`, `overworld_prop_registry.gd`, `river_generator.gd` (top-level), `terrain_erosion.gd`, `encounter_zone_3d.gd`, `terrain_texture_layer.gd`

### Data Model
**Files**: `scripts/resources/` (41 files), `scripts/models/party.gd`
All extend `Resource` (serializable). Key types:
- `ItemData` — shape, type, rarity, stats, gem slots, effects
- `CharacterData` — base stats, skills, backpack tier config
- `EnemyData` — enemy stats, skills, loot table
- `EncounterData` — enemy roster, flee flag, loot grid template, gold reward
- `MissionData` — encounter path, enemy count range, rewards, prerequisites
- `QuestData` + `QuestObjective` — quest objectives, rewards, NPC references
- `Party` (RefCounted, not Resource) — roster dict, squad array, vitals dict, grid inventories dict, stash array, backpack states

### Utility Systems
| File | Class | Role |
|------|-------|------|
| `scripts/utils/constants.gd` | Constants | All numeric game constants (not autoload — referenced as `Constants.*`) |
| `scripts/utils/enums.gd` | Enums | All enum types (ItemType, Rarity, Stat, Element, DamageType, etc.) |
| `scripts/utils/passive_effects.gd` | PassiveEffects | Maps passive node IDs → stat modifier dicts; class_name, not autoload |
| `scripts/utils/backpack_upgrade_system.gd` | BackpackUpgradeSystem | Cell purchase + tier unlock logic; called by GameManager |
| `scripts/utils/crafting_system.gd` | CraftingSystem | Recipe validation + ingredient consumption |
| `scripts/utils/shop_system.gd` | ShopSystem | Purchase/sell price calculations |
| `scripts/utils/item_upgrade_system.gd` | ItemUpgradeSystem | Item tier upgrade logic |
| `scripts/utils/element_skill_system.gd` | ElementSkillSystem | Element damage modifiers + combo reactions |
| `scripts/utils/mission_launcher.gd` | MissionLauncher | Pure helpers: `build_battle_data()`, `resolve_encounter()`, `compute_battle_outcome()` |
| `scripts/utils/random_encounter_generator.gd` | RandomEncounterGenerator | Generates random `EncounterData` from `data/enemies/` pool |
| `scripts/utils/resource_loader_helper.gd` | ResourceLoaderHelper | Recursive .tres directory loader; preloaded as `const _Loader` in all 6 database autoloads |
| `scripts/utils/ui_themes.gd` | UIThemes | Programmatic UI styling helpers (font sizes, button styles, margins) |
| `scripts/utils/design_tokens.gd` | DesignTokens | NEW (untracked) — design system values being introduced |

---

## 4. Dead Code

Files and systems that appear to serve no living code path.

### Terrain (overworld was scrapped — 12 files)
- `scripts/terrain/terrain_manager.gd` — Overworld terrain coordinator; no overworld
- `scripts/terrain/overworld_heightmap_generator.gd` — Overworld heightmap
- `scripts/terrain/biome_heightmap_generator.gd` — Biome variation
- `scripts/terrain/test_heightmap_generator.gd` — Dev test generator
- `scripts/terrain/road_generator.gd` — Road placement
- `scripts/terrain/town_layout_generator.gd` — Town/settlement layouts
- `scripts/terrain/poi_generator.gd` — Points of interest
- `scripts/terrain/overworld_prop_registry.gd` — Overworld-scale prop registry
- `scripts/terrain/river_generator.gd` — Global-scale river tracer (the local variant is still active)
- `scripts/terrain/terrain_erosion.gd` — Heightmap pre-processing tool
- `scripts/terrain/encounter_zone_3d.gd` — Overworld random encounter zones
- `scripts/terrain/terrain_texture_layer.gd` — Terrain shader layer helper

### Scenes
- `scenes/shared/test_3d.tscn` + `test_3d.gd` — Dev 3D render test
- `scenes/maps/forest_clearing_ortho_test.tscn` — Ortho camera experiment (commit 94c11c59)
- `scenes/menus/pause_menu.tscn` + `pause_menu.gd` — Was for old overworld ("instantiated directly by overworld"); superseded by `game_menu`

### EventBus signals (defined but never emitted or never connected)
- `location_prompt_visible` — connected only by QuestManager; **never emitted** (overworld dead)
- `show_message` — **emitted** by character_stats, loot, shop, dialogue, inventory, crafting; **never connected** (game_menu not wired → all toast messages silently dropped)
- `quest_failed` — **never emitted** anywhere in codebase
- `dialogue_started` — emitted by dialogue_ui; **never connected**
- `passive_unlocked` — emitted by passive_tree; **never connected**
- `loot_screen_closed` — emitted by loot.gd; **never connected**
- `game_saved` — emitted by SaveManager; **never connected**

---

## 5. Hardcoded / POC Glue

Connections that bypass proper data flow — likely to break or need rework when the project scales.

| Location | Glue | Risk |
|----------|------|------|
| `hub.gd:_ensure_party_initialized()` + `_auto_equip_starter_weapons()` | Auto-inits a new game + equips weapons when hub is launched via F6 with no party | Hides bugs: items can be double-added (placed + left in stash) |
| `game_manager.gd:preloaded_battle_bg` / `preloaded_battle_arena_center` / `preloaded_battle_arena_rotation` | Raw `Node3D` passed via GameManager mutation instead of SceneManager data dict | Node is consumed once and cleared; if battle is pushed twice without briefing the second gets no background |
| `mission_launcher.gd:BATTLE_MAP_ID = "forest_clearing"` | Only one battle map supported | All missions fight in the same forest |
| `mission_launcher.gd:BATTLE_ARENA_CENTER = Vector3(128.0, 3.0, 145.0)` | Arena position hardcoded to match forest_clearing terrain | Will misalign if terrain generation changes |
| `game_manager.gd:current_map_id = "forest_clearing"` | Fallback map ID hardcoded | Masking: if map_id is never set, battle still "works" but with wrong context |
| `game_manager.gd:new_game()` starter item list | ~30 item IDs hardcoded in array literals | No data-driven new-game config; easy to break if item IDs change |
| `hub.gd:SHOP_ID = "merchant_general"` / `STATION_ID = "blacksmith"` | Single fixed shop/crafting station for the POC hub | Multi-hub would need dynamic assignment |
| `main_menu.gd` line 42: `MapEditorButton.visible = false` | Dead button hardcoded hidden with TODO to delete it from .tscn | Visual clutter in scene tree |
| `scenes/menus/game_menu.gd` | Fully written but not instantiated anywhere — no scene or script calls it | All ESC-key character access is currently dead |
| `hub.gd:_on_party_pressed()` | Pushes `character_stats.tscn` directly instead of the new `character_hub.tscn` | character_hub in-progress but not wired |

---

## 6. EventBus Signal Map

| Signal | Signature | Emitted by | Connected by |
|--------|-----------|-----------|-------------|
| `item_placed` | `(char_id: String, item: Resource, pos: Vector2i)` | `GridInventory`, `grid_panel.gd` | *(none found)* |
| `item_removed` | `(char_id: String, item: Resource, pos: Vector2i)` | `GridInventory`, `battle.gd` (item consumption) | *(none found)* |
| `item_rotated` | `(char_id: String, item: Resource)` | `grid_panel.gd` | *(none found)* |
| `inventory_changed` | `(char_id: String)` | `GridInventory`, `battle.gd` | `GameManager`, `QuestManager` |
| `stash_changed` | `()` | `GameManager` (after DB reload) | `stash_panel.gd` (likely) |
| `combat_started` | `(encounter: Resource)` | `battle.gd` | `TutorialManager` |
| `combat_ended` | `(victory: bool, defeated_ids: Array)` | `battle.gd` | `QuestManager` |
| `passive_unlocked` | `(char_id: String, node_id: String)` | `passive_tree.gd` | **DEAD** — nothing connects |
| `gold_changed` | `(new_amount: int)` | `GameManager` (add/spend/new_game/restore) | `shop_ui.gd`, hub gold label (via receive_data) |
| `loot_screen_closed` | `()` | `loot.gd` | **DEAD** — nothing connects |
| `game_saved` | `()` | `SaveManager` | **DEAD** — nothing connects |
| `game_loaded` | `()` | `SaveManager` | `QuestManager` |
| `location_prompt_visible` | `(visible: bool, name: String)` | **DEAD** — never emitted | `QuestManager` |
| `show_message` | `(message: String)` | `character_stats`, `loot`, `shop_ui`, `dialogue_ui`, `inventory_panel`, `crafting_ui` | **DEAD** — nothing connects (game_menu not wired) |
| `dialogue_started` | `(npc_id: String)` | `dialogue_ui.gd` | **DEAD** — nothing connects |
| `dialogue_ended` | `(npc_id: String)` | `dialogue_ui.gd` | `QuestManager` |
| `inventory_expanded` | `()` | `GameManager` (backpack expand/tier unlock) | Inventory panels (likely connected in grid_panel or inventory_panel) |
| `backpack_expanded` | `(char_id: String, cells: int)` | `GameManager` | `TutorialManager` |
| `backpack_tier_unlocked` | `(char_id: String, tier: int)` | `GameManager` | *(none found)* |
| `quest_accepted` | `(quest_id: String)` | `QuestManager` | `TutorialManager`, `quest_log_ui` |
| `quest_progressed` | `(id, obj_idx, cur, tgt: int)` | `QuestManager` | `quest_log_ui` |
| `quest_completed` | `(quest_id: String)` | `QuestManager` | `quest_log_ui` |
| `quest_failed` | `(quest_id: String)` | **DEAD** — never emitted | `quest_log_ui` |
| `quest_available` | `(quest_id: String)` | `QuestManager` | *(none found)* |
| `item_database_reloaded` | `()` | `ItemDatabase.reload()` | `GameManager` |

---

## Appendix: Scene Navigation Flow

```
main_menu.tscn
  └─ replace → hub.tscn                         (New Game / Continue)
       ├─ push  → mission_board.tscn
       │    └─ push → mission_briefing.tscn
       │              └─ push → battle.tscn
       │                   └─ replace → loot.tscn
       │                        └─ pop  → (hub)
       ├─ push  → character_stats.tscn           (Party button — current)
       │    [character_hub.tscn planned replacement]
       ├─ push  → shop_ui.tscn
       ├─ push  → crafting_ui.tscn
       └─ replace → main_menu.tscn              (Quit)

[ESC anywhere] → game_menu (CanvasLayer overlay) — NOT YET WIRED
```

AUDIT COMPLETE
