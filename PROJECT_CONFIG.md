# Project Config — Tactics-Hub RPG

> Read by all agents at the start of every session.
> Keep this file up to date when conventions or structure change.

## Project Identity
- Name: Tactics-Hub RPG
- Type: Game
- Engine/Framework: Godot 4.6, GL Compatibility renderer
- Language: GDScript
- Status: Active development — pivoting from open-world to tactics-hub (FFT-style)
- Viewport: 1920×1080

## How to Run the Project
Open in Godot 4.6 editor and press F5. No build step required for development.
Tests: run via GUT plugin in the editor (addons/gut).

## File Structure
```
tactical-rpg-game/
├── scenes/                  ← Scene files (.tscn) organized by feature
│   ├── battle/              ← 3D battle scene (working)
│   ├── character_hub/       ← Character management hub (working)
│   ├── character_stats/     ← Character stats screen (working)
│   ├── crafting/            ← Crafting UI (working)
│   ├── dialogue/            ← Dialogue system (working)
│   ├── hub/                 ← Main tactics hub — in progress
│   ├── inventory/           ← Grid inventory system (working)
│   ├── loot/                ← Loot screen (working)
│   ├── main_menu/           ← Main menu (working)
│   ├── menus/               ← Shared menu scenes
│   ├── party_management/    ← Party / squad management (working)
│   ├── passive_tree/        ← Passive skill tree (working)
│   ├── settings/            ← Settings screen (working)
│   ├── shop/                ← Shop UI (working)
│   ├── squad/               ← Squad selection (working)
│   ├── shared/              ← Reusable UI components
│   └── world/               ← LIKELY DEAD CODE — old open-world scenes
├── scripts/
│   ├── autoload/            ← Global singletons (see Autoloads section)
│   ├── models/              ← Data model classes (class_name resources)
│   ├── resources/           ← Resource wrappers
│   ├── systems/             ← Game logic systems (combat, inventory, etc.)
│   └── utils/               ← Utility scripts
├── data/                    ← .tres / .res resource files
│   ├── characters/          ← CharacterData resources
│   ├── enemies/             ← EnemyData resources
│   ├── items/               ← ItemData resources
│   ├── skills/              ← SkillData resources
│   ├── encounters/          ← EncounterData resources
│   └── shapes/              ← Item grid shape resources
├── assets/                  ← Art, audio, fonts
│   ├── sprites/items/       ← Item sprite sheets (64×64px per cell)
│   └── ui/theme/            ← UI theme files
├── tests/                   ← GUT unit/integration tests
├── tools/                   ← Editor tooling (Python scripts)
└── addons/                  ← Third-party Godot addons
```

## Naming Conventions
- Files: `snake_case.gd`, `snake_case.tscn`, `snake_case.tres`
- Classes (`class_name`): `PascalCase`
- Functions: `snake_case`
- Signals: `snake_case`, past tense — `quest_completed` not `on_quest_complete`
- Constants: `ALL_CAPS_SNAKE`
- Private members: prefixed with `_underscore`
- Unused parameters: prefixed with `_` (e.g. `_delta`)

## Global Systems / Autoloads
All autoloads registered in project.godot. Listed in approximate load order:

| Autoload | Path | Purpose |
|---|---|---|
| `Constants` | `scripts/autoload/constants.gd` | Global constants (stats caps, economy values, etc.) |
| `Enums` | `scripts/autoload/enums.gd` | All enum definitions shared across the project |
| `EventBus` | `scripts/autoload/event_bus.gd` | Global signal bus — all cross-system signals defined here |
| `DebugLogger` | `scripts/autoload/debug_logger.gd` | Structured logging; suppressed in release builds |
| `GameManager` | `scripts/autoload/game_manager.gd` | Party, gold, story flags, completed missions |
| `SceneManager` | `scripts/autoload/scene_manager.gd` | Scene stack with fade transitions |
| `SaveManager` | `scripts/autoload/save_manager.gd` | Save / load game state |
| `AudioManager` | `scripts/autoload/audio_manager.gd` | Music and SFX playback |
| `InputManager` | `scripts/autoload/input_manager.gd` | Input remapping and gamepad support |
| `DisplayManager` | `scripts/autoload/display_manager.gd` | Resolution, fullscreen, vsync |
| `LocaleManager` | `scripts/autoload/locale_manager.gd` | Localisation |
| `UIColors` | `scripts/autoload/ui_colors.gd` | Central color palette — use `UIColors.BG_*` constants |
| `CharacterDatabase` | `scripts/autoload/character_database.gd` | Indexes CharacterData .tres files |
| `ItemDatabase` | `scripts/autoload/item_database.gd` | Indexes ItemData .tres files |
| `NpcDatabase` | `scripts/autoload/npc_database.gd` | Indexes NPC .tres files |
| `ShopDatabase` | `scripts/autoload/shop_database.gd` | Indexes shop .tres files |
| `ChestDatabase` | `scripts/autoload/chest_database.gd` | Indexes chest .tres files |
| `PassiveTreeDatabase` | `scripts/autoload/passive_tree_database.gd` | Loads passive tree resource |
| `QuestManager` | `scripts/autoload/quest_manager.gd` | Tracks active quests and objectives |
| `TutorialManager` | `scripts/autoload/tutorial_manager.gd` | Tutorial step tracking |

## EventBus Signals
```
# Inventory
item_placed(character_id: String, item: Resource, grid_pos: Vector2i)
item_removed(character_id: String, item: Resource, grid_pos: Vector2i)
item_rotated(character_id: String, item: Resource)
inventory_changed(character_id: String)
stash_changed()
inventory_expanded()
backpack_expanded(character_id: String, unlocked_cells: int)
backpack_tier_unlocked(character_id: String, new_tier: int)

# Combat
combat_started(encounter: Resource)
combat_ended(victory: bool, defeated_enemy_ids: Array)

# Economy
gold_changed(new_amount: int)

# Loot
loot_screen_closed()

# Save/Load
game_saved()
game_loaded()

# Dialogue
dialogue_started(npc_id: String)
dialogue_ended(npc_id: String)

# Quests
quest_accepted(quest_id: String)
quest_progressed(quest_id: String, objective_index: int, current: int, target: int)
quest_completed(quest_id: String)
quest_failed(quest_id: String)
quest_available(quest_id: String)

# Overworld (may be dead — tied to old direction)
location_prompt_visible(visible: bool, location_name: String)
show_message(message: String)

# Database
item_database_reloaded()

# Passives
passive_unlocked(character_id: String, node_id: String)
```

## Key Design Patterns
- **Scene navigation**: `SceneManager.push_scene(path, data)` to navigate forward. The destination scene receives `receive_data(data: Dictionary)` one frame after loading. Use `SceneManager.pop_scene()` to go back. Use `SceneManager.replace_scene(path, data)` when back-navigation is not needed.
- **Cross-system events**: All cross-system signals defined in `EventBus` and emitted/connected through it only. Never emit signals directly between unrelated nodes.
- **Data resources**: Game data lives in `.tres` files under `data/`. Loaded at startup by database autoloads. Access via `ItemDatabase.get_item(id)` etc. — never `load()` data files directly in game code.
- **UI colors**: All scene backgrounds use `UIColors.BG_*` constants on the root ColorRect. Never hardcode `Color(...)` values in scenes.
- **Autoload preloading in autoloads**: When an autoload script needs a `class_name` type, use `const _Alias = preload("res://scripts/...")` — never rely on global class names in autoload context.
- **Typed arrays from Dictionary.get()**: Use `.assign()` — `var arr: Array[int] = []; arr.assign(dict.get("key", []))`.
- **Enum casting**: Always cast int to enum explicitly — `item.rarity = idx as Enums.Rarity`.

## Forbidden Patterns
- `for entity: TypeName in untyped_array:` — typed for-in loops over untyped collections cause silent script parse failures in Godot 4.6. Use index loops: `for i in range(arr.size()): var entity: Type = arr[i]`.
- `class_name` scripts referencing autoloads directly — they compile before autoloads register. Pass values via parameters or use preload aliases.
- Chained assignment: `a = b = value` — not supported in GDScript.
- `:=` when the right-hand side returns `Variant` — use explicit type annotation: `var x: int = some_func()`.
- `get_node()` with hardcoded string paths — use `@onready var` instead.
- Connecting signals using string names — use Callable: `.connect(_on_signal)` not `.connect("_on_signal")`.
- Hardcoded `Color(...)` values in UI scenes — use `UIColors.*` constants.
- Shadowing global identifiers (`sign`, `clamp`, `lerp`, `min`, `max`, `abs`, `floor`, `ceil`, `round`) as variable names.
- Never use `get_node()` with absolute paths from root in scene scripts.

## UI Conventions
- Scene backgrounds: set `UIColors.BG_*` on the root `ColorRect`.
- `PanelContainer` children must have `layout_mode = 2` for proper sizing.
- `TextureRect` for item sprites: use `EXPAND_IGNORE_SIZE` + parent `clip_contents = true` for oversized sprites.
- Full-screen transitions and popups: always use `SceneManager.push_scene()` / `pop_scene()` — never `add_child()` for full-screen content.

## What "Done" Looks Like
- [ ] Code runs without errors in the Godot editor
- [ ] No GDScript errors or warnings in the Output panel
- [ ] Follows all naming conventions above
- [ ] No forbidden patterns introduced
- [ ] All new signals defined in EventBus
- [ ] Git committed with correct agent commit format
- [ ] Notion task updated to Done with Resolution filled in

## Known Technical Debt
- World navigation is POC glue — the old 2D overworld is bypassed but the menu-hub replacement is not fully built.
- `scenes/world/` and parts of `scenes/maps/` are likely dead code from the old open-world direction.
- `day_night_cycle.gd` autoload is likely dead — was tied to the old overworld.
- `location_prompt_visible` and `show_message` signals in EventBus may be dead — were for the overworld.
- The `hub/` scene is the new tactics hub entry point but is early-stage.
