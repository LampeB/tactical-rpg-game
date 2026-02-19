extends Node
## Global signal bus for decoupled cross-system communication.
## All systems emit/connect signals through this singleton.

# === SCENE MANAGEMENT ===
signal scene_change_requested(scene_path: String, data: Dictionary)
signal scene_ready(scene_name: String)

# === INVENTORY ===
signal item_placed(character_id: String, item: Resource, grid_pos: Vector2i)
signal item_removed(character_id: String, item: Resource, grid_pos: Vector2i)
signal item_rotated(character_id: String, item: Resource)
signal inventory_changed(character_id: String)
signal stash_changed()
signal item_picked_up(item: Resource)

# === COMBAT ===
signal combat_started(encounter: Resource)
signal combat_ended(victory: bool)
signal turn_started(entity: RefCounted)
signal turn_ended(entity: RefCounted)
signal action_selected(action: RefCounted)
signal action_executed(action: RefCounted, results: Dictionary)
signal damage_dealt(source: RefCounted, target: RefCounted, amount: int, damage_type: int)
signal entity_died(entity: RefCounted)
signal status_applied(target: RefCounted, status: Resource)
signal status_removed(target: RefCounted, status: Resource)
signal combat_state_changed(new_state: int)

# === PARTY ===
signal party_member_added(character: RefCounted)
signal party_member_removed(character: RefCounted)
signal squad_changed()
signal active_character_changed(character: RefCounted)

# === PASSIVES ===
signal passive_unlocked(character_id: String, node_id: String)

# === ECONOMY ===
signal gold_changed(new_amount: int)
signal item_purchased(item: Resource, price: int)
signal item_sold(item: Resource, price: int)

# === LOOT ===
signal loot_generated(items: Array)
signal loot_collected(item: Resource)
signal loot_screen_closed()

# === WORLD ===
signal interaction_available(interactable: Node)
signal interaction_unavailable()
signal chest_opened(chest: Node)
signal encounter_triggered(encounter: Resource)

# === UI ===
signal tooltip_requested(item: Resource, position: Vector2)
signal tooltip_hidden()

# === SAVE/LOAD ===
signal game_saved()
signal game_loaded()
