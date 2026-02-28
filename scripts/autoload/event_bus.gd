extends Node
## Global signal bus for decoupled cross-system communication.
## All systems emit/connect signals through this singleton.
## Note: Signals are emitted/connected from other files, so linter warnings are suppressed.

# === INVENTORY ===
@warning_ignore("unused_signal")
signal item_placed(character_id: String, item: Resource, grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal item_removed(character_id: String, item: Resource, grid_pos: Vector2i)
@warning_ignore("unused_signal")
signal item_rotated(character_id: String, item: Resource)
@warning_ignore("unused_signal")
signal inventory_changed(character_id: String)
@warning_ignore("unused_signal")
signal stash_changed()

# === COMBAT ===
@warning_ignore("unused_signal")
signal combat_started(encounter: Resource)
@warning_ignore("unused_signal")
signal combat_ended(victory: bool, defeated_enemy_ids: Array)

# === PASSIVES ===
@warning_ignore("unused_signal")
signal passive_unlocked(character_id: String, node_id: String)

# === ECONOMY ===
@warning_ignore("unused_signal")
signal gold_changed(new_amount: int)

# === LOOT ===
@warning_ignore("unused_signal")
signal loot_screen_closed()

# === SAVE/LOAD ===
@warning_ignore("unused_signal")
signal game_saved()
@warning_ignore("unused_signal")
signal game_loaded()

# === OVERWORLD ===
@warning_ignore("unused_signal")
signal location_prompt_visible(visible: bool, location_name: String)
@warning_ignore("unused_signal")
signal show_message(message: String)

# === DIALOGUE ===
@warning_ignore("unused_signal")
signal dialogue_started(npc_id: String)
@warning_ignore("unused_signal")
signal dialogue_ended(npc_id: String)

# === INVENTORY UPGRADES ===
@warning_ignore("unused_signal")
signal inventory_expanded()
@warning_ignore("unused_signal")
signal backpack_expanded(character_id: String, unlocked_cells: int)
@warning_ignore("unused_signal")
signal backpack_tier_unlocked(character_id: String, new_tier: int)

# === QUESTS ===
@warning_ignore("unused_signal")
signal quest_accepted(quest_id: String)
@warning_ignore("unused_signal")
signal quest_progressed(quest_id: String, objective_index: int, current: int, target: int)
@warning_ignore("unused_signal")
signal quest_completed(quest_id: String)
@warning_ignore("unused_signal")
signal quest_failed(quest_id: String)
@warning_ignore("unused_signal")
signal quest_available(quest_id: String)

# === DATABASE ===
@warning_ignore("unused_signal")
signal item_database_reloaded()
