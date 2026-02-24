@warning_ignore("unused_signal")
extends Node
## Global signal bus for decoupled cross-system communication.
## All systems emit/connect signals through this singleton.
## Note: Signals are emitted/connected from other files, so linter warnings are suppressed.

# === INVENTORY ===
signal item_placed(character_id: String, item: Resource, grid_pos: Vector2i)
signal item_removed(character_id: String, item: Resource, grid_pos: Vector2i)
signal item_rotated(character_id: String, item: Resource)
signal inventory_changed(character_id: String)
signal stash_changed()

# === COMBAT ===
signal combat_started(encounter: Resource)
signal combat_ended(victory: bool)

# === PASSIVES ===
signal passive_unlocked(character_id: String, node_id: String)

# === ECONOMY ===
signal gold_changed(new_amount: int)

# === LOOT ===
signal loot_screen_closed()

# === SAVE/LOAD ===
signal game_saved()
signal game_loaded()

# === OVERWORLD ===
signal location_prompt_visible(visible: bool, location_name: String)
signal show_message(message: String)

# === DIALOGUE ===
signal dialogue_started(npc_id: String)
signal dialogue_ended(npc_id: String)
