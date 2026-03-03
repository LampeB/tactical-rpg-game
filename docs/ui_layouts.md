# UI Screen Layouts — Tactical RPG

Reference wireframes for every screen. Edit this file to communicate layout changes to Claude.

**FigJam navigation map**: [Screen Navigation Map](https://www.figma.com/online-whiteboard/create-diagram/89b313f6-ab37-41c9-96cf-f908bf3ae136)

---

## 1. Character Stats

3-column layout. Right panel top slot toggles between passives list and embedded tooltip on hover.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]           Character              Gold: 181                  │
├──────────────────────────────────────────────────────────────────────┤
│ [Kael] [Lyra] [Vex]                        (character tabs)          │
├──────────────────┬─────────────────────┬─────────────────────────────┤
│  LEFT (1.0)      │  CENTER (1.2)       │  RIGHT (1.0)                │
│                  │                     │                             │
│  Kael            │  "Inventory"        │  ┌─ TopSlot ──────────────┐ │
│  Warrior Lv.5    │                     │  │ Unlocked Passives      │ │
│  description...  │  ┌───────────────┐  │  │ ─────────────────      │ │
│                  │  │               │  │  │ +2 STR                 │ │
│  HP: 90/90 ████  │  │  Grid Panel   │  │  │ +5% Crit               │ │
│  MP: 26/30 ███░  │  │  (inventory)  │  │  │ ...                    │ │
│                  │  │               │  │  │                        │ │
│  ───────────     │  │               │  │  │ (OR: Item Tooltip      │ │
│  Skills          │  └───────────────┘  │  │  when hovering)        │ │
│  - Slash         │                     │  └────────────────────────┘ │
│  - Shield Bash   │                     │  ─────────────────────────  │
│  ───────────     │                     │  ┌─ Stash ────────────────┐ │
│  STR: 12         │                     │  │ Stash (3/100)          │ │
│  DEX: 8          │                     │  │ [Tools][Gear][Gems]    │ │
│  INT: 5          │                     │  │ [Sort: Name|Type|Rar]  │ │
│  ...             │                     │  │ item list...           │ │
│                  │                     │  └────────────────────────┘ │
│  [Advanced Stats]│                     │                             │
└──────────────────┴─────────────────────┴─────────────────────────────┘
```

**Scene**: `scenes/character_stats/character_stats.tscn`
**Components**: character_tabs, grid_panel, item_tooltip (embedded), stash_panel, drag_preview


---

## 2. Loot Screen

3-column layout. Right panel has always-visible embedded tooltip (empty state placeholder when nothing hovered) + stash.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Loot                                            +150 Gold            │
├──────────────────┬─────────────────────┬─────────────────────────────┤
│  LOOT (1.0)      │  GRID (1.2)         │  RIGHT (0.8)                │
│                  │                     │                             │
│  "Loot"          │  [Kael] [Lyra] [Vex]│  ┌─ Item Tooltip ─────────┐ │
│                  │                     │  │                        │ │
│  ┌────────────┐  │  ┌───────────────┐  │  │ Hover an item to       │ │
│  │            │  │  │               │  │  │ see details            │ │
│  │ Loot Grid  │  │  │  Grid Panel   │  │  │                        │ │
│  │ (8x5)      │  │  │  (inventory)  │  │  │ (shows item info       │ │
│  │            │  │  │               │  │  │  when hovering)        │ │
│  │            │  │  │               │  │  │                        │ │
│  └────────────┘  │  └───────────────┘  │  └────────────────────────┘ │
│                  │                     │  ─────────────────────────  │
│  2 item(s)       │  ┌───────────────┐  │  ┌─ Stash ────────────────┐ │
│  remaining       │  │ ✕ Discard    │  │  │ Stash (3/100)          │ │
│                  │  └───────────────┘  │  │ item list...           │ │
│                  │                     │  └────────────────────────┘ │
├──────────────────┴─────────────────────┴─────────────────────────────┤
│                        2 item(s) remaining            [Continue]     │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/loot/loot.tscn`
**Components**: character_tabs, grid_panel (x2), item_tooltip (embedded), stash_panel, drag_preview


---

## 3. Shop

2-column layout. Floating tooltip (CanvasLayer). Stash under player grid.

```
┌────────────────────────────────────────────────────────────────────────────────┐
│ Loot                                                      +150 Gold            │
├────────────────────────────┬─────────────────────┬─────────────────────────────┤
│  LOOT (1.0)                │  GRID (1.2)         │  RIGHT (0.8)                │
│                            │                     │                             │
│  "Loot"                    │  [Kael] [Lyra] [Vex]│  ┌─ Item Tooltip ─────────┐ │
│                            │                     │  │                        │ │
│  ┌──────────────────────┐  │  ┌───────────────┐  │  │ Hover an item to       │ │
│  │                      │  │  │               │  │  │ see details            │ │
│  │    Merchant          │  │  │  Grid Panel   │  │  │                        │ │
│  │    Grid              │  │  │  (inventory)  │  │  │ (shows item info       │ │
│  │     (8x5)            │  │  │               │  │  │  when hovering)        │ │
│  │                      │  │  │               │  │  │                        │ │
│  └──────────────────────┘  │  │               │  │  └────────────────────────┘ │
│                            │  │               │  │  ─────────────────────────  │
|  ┌─ Sold Panel ──────────┐ │  │               │  │  ┌─ Stash ──────────────┐   |
|  │ Sold this session     │ │  │               │  │  | Stash (3/100)        |   |
|  │ - Iron Sword  +50g    │ │  │               │  │  │ item list...         │   |
|  │ - Health Potion +10g  │ │  │               │  │  │ .....                │   |
|  │ Total received: +60g  │ │  │               │  │  │ .....                │   |
|  └───────────────────────┘ │  └───────────────┘  │  │ .....                │   |
|                            |                     │  │ .....                │   |
│  2 item(s) remaining       │  ┌───────────────┐  │  │ .....                |   |
│  remaining                 │  │ ✕ Discard     │  │  │ .....                │  │
│                            │  └───────────────┘  │  │ .....                │   │
│                            │                     │  └──────────────────────┘   │
├────────────────────────────┴─────────────────────┴─────────────────────────────┤
│                               2 item(s) remaining               [Continue]     │
└────────────────────────────────────────────────────────────────────────────────┘

**Scene**: `scenes/shop/shop_ui.tscn`
**Components**: character_tabs, grid_panel (x2), stash_panel, item_tooltip (floating), drag_preview


---

## 4. Crafting

2-column layout. Left half split between recipe icons + detail. Floating tooltip (CanvasLayer). Stash under player grid.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│ Forge                                                                           │
├─────────────────────────────┬─────────────────────┬─────────────────────────────┤
│  LEFT HALF (1.0)            │  CENTER (1.2)       │  RIGHT (1.0)                │
│                             │ [Kael] [Lyra] [Vex] │                             │
│  ┌────┬──────────────────┐  │                     │  ┌───────────────────────┐  │
│  │Icon│                  │  │                     │  │ ITEM TOOLTIP          │  │
│  │List│  Craft Detail    │  │  ┌───────────────┐  │  │───────────────────────│  │
│  │    │                  │  │  │               │  │  │ +2 STR                │  │
│  │ 🗡 │  Iron Sword      │  │  │  Grid Panel   │  │  │ +5% Crit              │  │
│  │ 🛡 │  Requires:       │  │  │  (inventory)  │  │  │ ...                   │  │
│  │ 💎 │  - 2x Iron Bar  │  │  │               │  │  │                       │  │
│  │    │  - 1x Leather    │  │  │               │  │  │ (OR: Item Tooltip     │  │
│  │    │  Cost: 50g       │  │  └───────────────┘  │  │  when hovering)       │  │
│  │    │                  │  │                     │  └───────────────────────┘  │
│  │    │  [Craft]         │  │                     │─────────────────────────────│
│  │    │                  │  │                     │  ┌─ Stash ──────────────┐   │
│  └────┴──────────────────┘  │                     │  │ Stash (3/100)        │   │
│                             │                     │  │ [Tools][Gear][Gems]  │   │
│                             |                     │  │ [Sort: Name|Type|Rar]│   │
│                             |                     │  │ item list...         │   │
├─────────────────────────────┴───────────────────────────────────────────────────│
|                                                                         [Close] │
└─────────────────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/crafting/crafting_ui.tscn`
**Components**: character_tabs, grid_panel, stash_panel, item_tooltip (floating), drag_preview


---

## 5. Battle

Vertical stack: top bar, turn order, 3D viewport with overlays, bottom action bar.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Battle                                              Round 1          │
├──────────────────────────────────────────────────────────────────────┤
│ [Turn Order Bar: portrait1 > portrait2 > portrait3 > ...]            │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│                                                    ┌──────────┐      │
│           3D Battle Viewport                       │ Enemy 1  │      │
│           (SubViewportContainer)                   │ HP ████  │      │
│                                                    ├──────────┤      │
│                                                    │ Enemy 2  │      │
│                                                    │ HP ███░  │      │
│              ┌─────────┬─────────┬─────────┐       └──────────┘      │
│              │ Kael    │ Lyra    │ Vex     │                         │
│              │ HP ████ │ HP ███░ │ HP ████ │                         │
│              │ MP ██░░ │ MP ████ │ MP █░░░ │                         │
│              └─────────┴─────────┴─────────┘                         │
├──────────────────────────────────────────────────────────────────────┤
│              [Select a target...]                                    │
│  ┌─ Action Menu ──────┐                    ┌─ Log Section ────────┐  │
│  │ [Attack]           │                    │ [Battle Log toggle]  │  │
│  │ [Skills >]         │                    │ log entries...       │  │
│  │ [Items >]          │                    │                      │  │ 
│  │ [Defend]           │                    └──────────────────────┘  │ 
│  └────────────────────┘                                              │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/battle/battle.tscn`
**Components**: turn_order_bar, action_menu, battle_log, damage_popup (CanvasLayer 10)


---

## 6. Passive Skill Tree

2-column layout. Large tree graph on left, info panel on right.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]           Skill Tree               Gold: 0                  │
├──────────────────────────────────────────────────────────────────────┤
│ [Kael] [Lyra] [Vex]                                                  │
├──────────────────────────────────────────┬───────────────────────────┤
│  TREE PANEL (3.0)                        │  INFO PANEL (1.0)         │
│                                          │                           │
│                                          │  Unlocked Passives        │
│       ┌───┐                              │  ─────────────            │
│       │ A │──────┐                       │  +2 STR                   │
│       └───┘      │                       │  +5% Crit                 │
│          ┌───┐ ┌─┴─┐                     │                           │
│          │ B │ │ C │                     │  ─────────────            │
│          └───┘ └───┘                     │  Node: Power Strike       │
│            │                             │  Desc: +10% phys dmg      │
│          ┌─┴─┐                           │  Cost: 100 Gold           │
│          │ D │                           │  Prereqs: Node A          │
│          └───┘                           │                           │
│                                          │  ─────────────            │
│  (pan & zoom interactive tree)           │  Pending Unlocks          │
│                                          │  - Power Strike           │
│                                          │  Total: 100 Gold          │
│                                          │  [Confirm] [Cancel]       │
└──────────────────────────────────────────┴───────────────────────────┘
```

**Scene**: `scenes/passive_tree/passive_tree.tscn`
**Components**: character_tabs, tree_view


---

## 7. Dialogue

Bottom-anchored overlay (320px tall). Not full-screen — overlays the current scene.

```


         (current scene visible above)


┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│  [Portrait]  Speaker Name                                            │
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ "Welcome, traveler! I have fine wares for you today.           │  │
│  │  Take a look around."                                          │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
│  > Buy something                                                     │
│  > Ask about rumors                                                  │
│  > Leave                                                             │
│                                                                      │
│                                            [E] / Click to continue   │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/dialogue/dialogue_ui.tscn`
**Components**: none (all inline)


---

## 8. Overworld (3D + HUD)

3D world with CanvasLayer HUD overlay. Fast travel modal popup.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Gold: 181           "Press E to interact"                            │
│                                                                      │
│                                                                      │
│              3D World                                                │
│              (terrain, NPCs, enemies, chests)                        │
│                                                                      │
│                                                                      │
│                    ┌─ Fast Travel (modal) ─┐                         │
│                    │ Fast Travel            │                        │
│                    │ [ ] Starting Town      │                        │
│                    │ [ ] Dark Cave          │                        │
│                    │ [Travel] [Cancel]      │                        │
│                    └────────────────────────┘                        │
│                                                                      │
│                       "Starting Town"                                │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/world/overworld.tscn`
**Components**: location_marker, roaming_enemy, npc_marker, chest_marker, environment_3d


---

## 9. Quest Log

2-column split. Tab bar for filtering.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [Active] [Completed] [Available]     Quest Log              [X]      │
├───────────────────────┬──────────────────────────────────────────────┤
│  QUEST LIST (280px)   │  DETAIL PANEL (expand)                       │
│                       │                                              │
│  > Main Quest 1       │  Main Quest 1                                │
│    Main Quest 2       │  ─────────────                               │
│    Side Quest A       │  Description text here...                    │
│    Side Quest B       │                                              │
│                       │  Objectives:                                 │
│                       │  [x] Talk to the blacksmith                  │
│                       │  [ ] Collect 5 iron bars                     │
│                       │  [ ] Return to quest giver                   │
│                       │                                              │
│                       │  Rewards:                                    │
│                       │  - 200 Gold                                  │
│                       │  - Iron Sword                                │
└───────────────────────┴──────────────────────────────────────────────┘
```

**Scene**: `scenes/menus/quest_log_ui.tscn`
**Components**: none (all inline)


---

## 10. Squad Management

2-column layout. Click to move between panels.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Squad Management              Squad: 3/4              [Back]         │
├─────────────────────────────────┬────────────────────────────────────┤
│  ACTIVE SQUAD                   │  BENCH                             │
│                                 │                                    │
│  "Click a member to move        │  "Click a character to add         │
│   them to the bench"            │   them to the squad"               │
│                                 │                                    │
│  ┌───────────────────────────┐  │  ┌──────────────────────────────┐  │
│  │ Kael    Warrior  Lv.5     │  │  │ Finn    Ranger   Lv.3        │  │
│  ├───────────────────────────┤  │  └──────────────────────────────┘  │
│  │ Lyra    Mage     Lv.5     │  │                                    │
│  ├───────────────────────────┤  │                                    │
│  │ Vex     Rogue    Lv.4     │  │                                    │
│  └───────────────────────────┘  │                                    │
│                                 │                                    │
│                                 │                                    │
└─────────────────────────────────┴────────────────────────────────────┘
```

**Scene**: `scenes/squad/squad.tscn`
**Components**: none (all inline)


---

## 11. Main Menu

Centered button stack.

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│                                                                      │
│                         TACTICAL RPG                                 │
│                                                                      │
│                         [Continue]                                   │
│                         [Load Game]                                  │
│                         [New Game]                                   │
│                         ─────────                                    │
│                         [Inventory]  (dev)                           │
│                         [Squad]      (dev)                           │
│                         [Tree Editor](dev)                           │
│                         [Item Editor](dev)                           │
│                         [NPC Editor] (dev)                           │
│                         ─────────                                    │
│                         [Settings]                                   │
│                         [Quit]                                       │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/main_menu/main_menu.tscn`
**Components**: none


---

## 12. Pause Menu

Centered modal over semi-transparent blocker.

```
┌──────────────────────────────────────────────────────────────────────┐
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░┌─────────────────────┐░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│       Paused        │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│                     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│     [Resume]        │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│     [Save Game]     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│     [Load Game]     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│     [Quest Log]     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│     [Main Menu]     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░│                     │░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░└─────────────────────┘░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
│░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░│
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/menus/pause_menu.tscn`
**Components**: none (overlay, not pushed via SceneManager)


---

## 13. Save/Load Menu

Scrollable slot list.

```
┌──────────────────────────────────────────────────────────────────────┐
│ Load Game                                                     [X]    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌────────────────────────────────────────────────────────────────┐  │
│  │ Slot 1 — Kael Lv.5  |  Starting Town  |  2h 15m  |  Mar 2      │  │
│  │   [save_0] [save_1] [save_2]                                   │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │ Slot 2 — Kael Lv.3  |  Dark Cave      |  1h 02m  |  Mar 1      │  │
│  │   [save_0] [save_1]                                            │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │ Slot 3 — Empty                                                 │  │
│  ├────────────────────────────────────────────────────────────────┤  │
│  │ Auto-Save — Kael Lv.5  |  Starting Town  |  2h 14m             │  │
│  │   [auto_0] [auto_1] [auto_2]                                   │  │
│  └────────────────────────────────────────────────────────────────┘  │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/menus/save_load_menu.tscn`
**Components**: none (slots generated dynamically)


---

## 14. Settings

Centered modal with keybind list.

```
┌──────────────────────────────────────────────────────────────────────┐
│                                                                      │
│          ┌────────────────────────────────────────────────┐          │
│          │               Settings                         │          │
│          │ ──────────────────────────────────────         │          │
│          │ Keyboard Shortcuts                             │          │
│          │                                                │          │
│          │  Move Up .............. W                      │          │
│          │  Move Down ............ S                      │          │
│          │  Move Left ............ A                      │          │
│          │  Move Right ........... D                      │          │
│          │  Interact ............. E                      │          │
│          │  Inventory ............ I                      │          │
│          │  ...                                           │          │
│          │ ──────────────────────────────────────         │          │
│          │      [Reset All to Defaults]  [Back]           │          │
│          └────────────────────────────────────────────────┘          │
│                                                                      │
│          ┌─ Rebind Popup (overlay) ──┐                               │
│          │     Press a key...        │                               │
│          │         [W]               │                               │
│          └───────────────────────────┘                               │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/settings/settings_menu.tscn`
**Components**: none


---

## 15. Character Hub

Tab-switching container. Loads Stats or Skills view dynamically.

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]           Character              Gold: 0                    │
├──────────────────────────────────────────────────────────────────────┤
│ [Kael] [Lyra] [Vex]                                                  │
├──────────────────────────────────────────────────────────────────────┤
│ [Stats]  [Skills]                                                    │
├──────────────────────────────────────────────────────────────────────┤
│                                                                      │
│              (ViewContainer — loads CharacterStats                   │
│               or SkillsView based on selected tab)                   │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                                      │
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/character_hub/character_hub.tscn`
**Components**: character_tabs


---

## Dev Tools

### 16. Item Editor

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]  Item Editor  [Save Item] [Save All]     status msg         │
├───────────────────────────┬──────────────────────────────────────────┤
│  LIST PANEL               │  PROPERTY PANEL                          │
│                           │                                          │
│  [Search: ________]       │  id: iron_sword                          │
│  [New] [Duplicate] [Del]  │  display_name: Iron Sword                │
│                           │  item_type: [ACTIVE_TOOL v]              │
│  > iron_sword             │  rarity: [COMMON v]                      │
│    health_potion          │  shape: [2x1 v]                          │
│    leather_armor          │  stat_modifiers: [...]                   │
│    fire_gem               │  ...                                     │
│    ...                    │                                          │
├───────────────────────────┴──────────────────────────────────────────┤
│ hint bar                                                             │
└──────────────────────────────────────────────────────────────────────┘
```

### 17. NPC Editor

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]  NPC Editor  [Save NPC] [Save All]       status msg         │
├───────────────────────────┬──────────────────────────────────────────┤
│  LIST PANEL               │  PROPERTY PANEL                          │
│                           │                                          │
│  [Search: ________]       │  id: blacksmith                          │
│  [New] [Duplicate] [Del]  │  display_name: Blacksmith                │
│                           │  role: [CRAFTSMAN v]                     │
│  > blacksmith             │  dialogue_id: blacksmith_intro           │
│    merchant               │  crafting_station_id: forge              │
│    weaver                 │  ...                                     │
│    doctor                 │                                          │
├───────────────────────────┴──────────────────────────────────────────┤
│ hint bar                                                             │
└──────────────────────────────────────────────────────────────────────┘
```

### 18. Tree Editor

```
┌──────────────────────────────────────────────────────────────────────┐
│ [< Back]  Skill Tree Editor  [Save]               status msg         │
├──────────────────────────────────────────┬───────────────────────────┤
│  TREE PANEL                              │  PROPERTY PANEL           │
│                                          │                           │
│       ┌───┐                              │  Node: power_strike       │
│       │ A │──────┐                       │  Name: Power Strike       │
│       └───┘      │                       │  Description: ...         │
│          ┌───┐ ┌─┴─┐                     │  Cost: 100                │
│          │ B │ │ C │                     │  Modifiers:               │
│          └───┘ └───┘                     │  - +10% phys damage       │
│            │                             │  Prerequisites:           │
│          ┌─┴─┐                           │  - Node A                 │
│          │ D │                           │                           │
│          └───┘                           │                           │
│                                          │                           │
│  (interactive drag-to-connect editor)    │                           │
├──────────────────────────────────────────┴───────────────────────────┤
│ [N] New node  [Del] Delete  [Drag] Connect  [Scroll] Zoom            │
└──────────────────────────────────────────────────────────────────────┘
```

**Scene**: `scenes/tree_editor/tree_editor.tscn`
**Components**: tree_editor_view
