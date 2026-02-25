extends Node
## Handles serialization/deserialization of game state to/from JSON.
## Supports 5 manual save slots + 1 auto-save slot, each with a ring-buffer history.

const SAVE_VERSION := 5
const MAX_SLOTS := 5
const MAX_HISTORY := 5
const AUTO_HISTORY := 3
const SAVES_DIR := "user://saves/"
const LEGACY_SAVE_PATH := "user://save.json"

var _playtime_accumulator: float = 0.0
var _is_tracking_playtime: bool = false


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(SAVES_DIR)
	_migrate_legacy_save()
	DebugLogger.log_info("SaveManager ready", "SaveManager")


func _process(delta: float) -> void:
	if _is_tracking_playtime:
		_playtime_accumulator += delta


# === Public API ===

func start_playtime_tracking() -> void:
	_is_tracking_playtime = true

func stop_playtime_tracking() -> void:
	_is_tracking_playtime = false


## Save current game state to a manual slot (0-indexed).
func save_to_slot(slot_index: int) -> bool:
	if not GameManager.is_game_started:
		DebugLogger.log_warn("Cannot save — no game in progress", "SaveManager")
		return false
	return _save_to_dir(_slot_dir(slot_index), MAX_HISTORY)


## Save current game state to the auto-save slot.
func auto_save() -> bool:
	if not GameManager.is_game_started:
		return false
	return _save_to_dir(_auto_dir(), AUTO_HISTORY)


## Load from a manual slot. history_index -1 = latest; otherwise load that specific entry.
func load_from_slot(slot_index: int, history_index: int = -1) -> bool:
	return _load_from_dir(_slot_dir(slot_index), history_index)


## Load from the auto-save slot. history_index -1 = latest.
func load_auto_save(history_index: int = -1) -> bool:
	return _load_from_dir(_auto_dir(), history_index)


## Load the most recently saved file across all slots and the auto slot.
func load_most_recent() -> bool:
	var best_dir: String = ""
	var best_timestamp: String = ""

	for i in range(MAX_SLOTS):
		var meta := _read_meta(_slot_dir(i))
		if meta.is_empty() or meta.get("history_count", 0) == 0:
			continue
		var entries: Array = meta.get("entries", [])
		if entries.is_empty():
			continue
		var ts: String = entries[0].get("timestamp", "")
		if ts > best_timestamp:
			best_timestamp = ts
			best_dir = _slot_dir(i)

	var auto_meta := _read_meta(_auto_dir())
	if not auto_meta.is_empty() and auto_meta.get("history_count", 0) > 0:
		var entries: Array = auto_meta.get("entries", [])
		if not entries.is_empty():
			var ts: String = entries[0].get("timestamp", "")
			if ts > best_timestamp:
				best_timestamp = ts
				best_dir = _auto_dir()

	if best_dir.is_empty():
		DebugLogger.log_warn("No saves found for load_most_recent", "SaveManager")
		return false

	return _load_from_dir(best_dir, -1)


## Returns true if any save data exists (any slot or auto).
func has_any_save() -> bool:
	for i in range(MAX_SLOTS):
		var meta := _read_meta(_slot_dir(i))
		if not meta.is_empty() and meta.get("history_count", 0) > 0:
			return true
	var auto_meta := _read_meta(_auto_dir())
	return not auto_meta.is_empty() and auto_meta.get("history_count", 0) > 0


## Alias for backward compatibility.
func has_save() -> bool:
	return has_any_save()


## Returns metadata dict for a manual slot, or {} if empty.
func get_slot_meta(slot_index: int) -> Dictionary:
	return _read_meta(_slot_dir(slot_index))


## Returns array of MAX_SLOTS metadata dicts (empty dict {} for empty slots).
func get_all_slots_meta() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for i in range(MAX_SLOTS):
		result.append(_read_meta(_slot_dir(i)))
	return result


## Returns metadata dict for the auto-save slot, or {} if empty.
func get_auto_save_meta() -> Dictionary:
	return _read_meta(_auto_dir())


## Deletes all save files for a manual slot. Returns true on success.
func delete_slot(slot_index: int) -> bool:
	var dir_path := _slot_dir(slot_index)
	var dir := DirAccess.open(dir_path)
	if not dir:
		return true  # Already empty
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if not dir.current_is_dir():
			dir.remove(fname)
		fname = dir.get_next()
	dir.list_dir_end()
	DebugLogger.log_info("Deleted slot %d" % slot_index, "SaveManager")
	return true


# === Path Helpers ===

func _slot_dir(slot_index: int) -> String:
	return SAVES_DIR + "slot_%d/" % slot_index

func _auto_dir() -> String:
	return SAVES_DIR + "auto/"

func _meta_path(dir: String) -> String:
	return dir + "meta.json"

func _save_path(dir: String, index: int) -> String:
	return dir + "save_%d.json" % index


# === Core Save/Load ===

func _save_to_dir(dir: String, max_history: int) -> bool:
	DirAccess.make_dir_recursive_absolute(dir)

	var meta := _read_meta(dir)
	if meta.is_empty():
		meta = {"current_index": -1, "history_count": 0, "entries": []}

	var new_index: int = (int(meta.get("current_index", -1)) + 1) % max_history
	var data := _serialize()

	if not _write_json(_save_path(dir, new_index), data):
		return false

	# Build and prepend metadata entry
	var squad_names: Array = []
	if GameManager.party:
		for char_id in GameManager.party.squad:
			var char_data: CharacterData = GameManager.party.roster.get(char_id)
			if char_data:
				squad_names.append(char_data.display_name)

	var entry := {
		"save_index": new_index,
		"timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": _playtime_accumulator,
		"gold": GameManager.gold,
		"location": GameManager.current_location_name,
		"squad_names": squad_names,
	}

	var entries: Array = meta.get("entries", [])
	entries.push_front(entry)
	if entries.size() > max_history:
		entries.resize(max_history)

	meta["current_index"] = new_index
	meta["history_count"] = mini(int(meta.get("history_count", 0)) + 1, max_history)
	meta["entries"] = entries

	_write_meta(dir, meta)
	EventBus.game_saved.emit()
	DebugLogger.log_info("Saved to %s — Gold: %d, Roster: %d, Stash: %d" % [
		dir, GameManager.gold, GameManager.party.roster.size(), GameManager.party.stash.size()
	], "SaveManager")
	return true


func _load_from_dir(dir: String, history_index: int) -> bool:
	var meta := _read_meta(dir)
	if meta.is_empty() or meta.get("history_count", 0) == 0:
		DebugLogger.log_warn("No save data in: %s" % dir, "SaveManager")
		return false

	# Resolve which save_N.json to load
	var file_index: int
	if history_index == -1:
		file_index = int(meta.get("current_index", 0))
	else:
		# history_index is an index into meta.entries (0 = newest)
		var entries: Array = meta.get("entries", [])
		if history_index >= entries.size():
			DebugLogger.log_warn("History index %d out of range (%d entries)" % [history_index, entries.size()], "SaveManager")
			return false
		file_index = int(entries[history_index].get("save_index", 0))

	var path := _save_path(dir, file_index)
	var data := _read_json(path)
	if data.is_empty():
		DebugLogger.log_error("Failed to read save file: %s" % path, "SaveManager")
		return false

	if not _validate(data):
		return false

	_deserialize(data)
	EventBus.game_loaded.emit()
	DebugLogger.log_info("Loaded from %s (file index %d) — Gold: %d, Roster: %d, Stash: %d" % [
		dir, file_index, GameManager.gold, GameManager.party.roster.size(), GameManager.party.stash.size()
	], "SaveManager")
	return true


# === Meta I/O ===

func _read_meta(dir: String) -> Dictionary:
	var path := _meta_path(dir)
	if not FileAccess.file_exists(path):
		return {}
	return _read_json(path)

func _write_meta(dir: String, meta: Dictionary) -> void:
	_write_json(_meta_path(dir), meta)


# === JSON I/O ===

func _read_json(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if not file:
		DebugLogger.log_error("Failed to open for reading: %s" % path, "SaveManager")
		return {}
	var text := file.get_as_text()
	file.close()
	var json := JSON.new()
	if json.parse(text) != OK:
		DebugLogger.log_error("Failed to parse JSON: %s — %s" % [path, json.get_error_message()], "SaveManager")
		return {}
	return json.data

func _write_json(path: String, data: Dictionary) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		DebugLogger.log_error("Failed to open for writing: %s" % path, "SaveManager")
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	return true


# === Legacy Migration ===

func _migrate_legacy_save() -> void:
	if not FileAccess.file_exists(LEGACY_SAVE_PATH):
		return
	# Only migrate if no manual slot has data yet
	for i in range(MAX_SLOTS):
		var m := _read_meta(_slot_dir(i))
		if not m.is_empty() and m.get("history_count", 0) > 0:
			return  # Migration already done or slots already used

	DebugLogger.log_info("Migrating legacy save.json to slot_0", "SaveManager")
	var data := _read_json(LEGACY_SAVE_PATH)
	if data.is_empty() or not _validate(data):
		return

	var slot_dir := _slot_dir(0)
	DirAccess.make_dir_recursive_absolute(slot_dir)

	if not _write_json(_save_path(slot_dir, 0), data):
		return

	# Build metadata from legacy save data
	var squad_names: Array = []
	var roster_ids: Array = data.get("roster", [])
	var squad_ids: Array = data.get("squad", [])
	for sid in squad_ids:
		var char_data: CharacterData = CharacterDatabase.get_character(str(sid))
		if char_data:
			squad_names.append(char_data.display_name)

	var meta := {
		"current_index": 0,
		"history_count": 1,
		"entries": [{
			"save_index": 0,
			"timestamp": data.get("save_timestamp", Time.get_datetime_string_from_system()),
			"playtime_seconds": data.get("playtime_seconds", 0.0),
			"gold": data.get("gold", 0),
			"location": "Overworld",
			"squad_names": squad_names,
		}]
	}
	_write_meta(slot_dir, meta)
	DirAccess.remove_absolute(LEGACY_SAVE_PATH)
	DebugLogger.log_info("Migration complete — old save.json removed", "SaveManager")


# === Serialization ===

func _serialize() -> Dictionary:
	var party: Party = GameManager.party
	var overworld_pos: Vector2 = GameManager.get_flag("overworld_position", Vector2.ZERO)
	return {
		"version": SAVE_VERSION,
		"save_timestamp": Time.get_datetime_string_from_system(),
		"playtime_seconds": _playtime_accumulator,
		"gold": GameManager.gold,
		"story_flags": GameManager.story_flags.duplicate(),
		"roster": party.roster.keys(),
		"squad": Array(party.squad),
		"stash": _serialize_stash(party.stash),
		"grid_inventories": _serialize_grid_inventories(party.grid_inventories),
		"backpack_states": _serialize_backpack_states(party.backpack_states),
		"unlocked_passives": _serialize_passives(party.unlocked_passives),
		"character_vitals": party.character_vitals.duplicate(true),
		"overworld_position": {"x": overworld_pos.x, "y": overworld_pos.y},
		"player_step_count": GameManager.get_flag("player_step_count", 0),
		"location": GameManager.current_location_name,
	}

func _serialize_stash(stash: Array) -> Array:
	var result: Array = []
	for item in stash:
		result.append({
			"item_id": item.id,
			"rarity": item.rarity,
		})
	return result

func _serialize_grid_inventories(grids: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for character_id: String in grids:
		var grid: GridInventory = grids[character_id]
		var placements: Array = []
		for placed in grid.placed_items:
			placements.append({
				"item_id": placed.item_data.id,
				"x": placed.grid_position.x,
				"y": placed.grid_position.y,
				"rotation": placed.rotation,
				"rarity": placed.item_data.rarity,
			})
		result[character_id] = placements
	return result

func _serialize_passives(passives: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for character_id: String in passives:
		result[character_id] = Array(passives[character_id])
	return result

func _serialize_backpack_states(states: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for char_id: String in states:
		var s: Dictionary = states[char_id]
		var cells_raw: Array = []
		for cell in s.get("purchased_cells", []):
			var v: Vector2i = cell if cell is Vector2i else Vector2i(int(cell[0]), int(cell[1]))
			cells_raw.append([v.x, v.y])
		result[char_id] = {
			"tier": s.get("tier", 0),
			"purchased_cells": cells_raw,
		}
	return result


# === Deserialization ===

func _deserialize(data: Dictionary) -> void:
	GameManager.gold = int(data.get("gold", 0))
	GameManager.story_flags = data.get("story_flags", {})
	GameManager.is_game_started = true
	GameManager.current_location_name = data.get("location", "Overworld")
	_playtime_accumulator = data.get("playtime_seconds", 0.0)

	var party := Party.new()
	GameManager.party = party

	# Backpack states must be restored BEFORE add_to_roster so the correct grid
	# template is used when each character's GridInventory is created.
	var bp_data: Dictionary = data.get("backpack_states", {})
	for char_id: String in bp_data:
		var s: Dictionary = bp_data[char_id]
		var cells: Array = []
		for raw in s.get("purchased_cells", []):
			cells.append(Vector2i(int(raw[0]), int(raw[1])))
		party.backpack_states[char_id] = {
			"tier": int(s.get("tier", 0)),
			"purchased_cells": cells,
		}

	var roster_ids: Array = data.get("roster", [])
	for char_id in roster_ids:
		var character: CharacterData = CharacterDatabase.get_character(str(char_id))
		if character:
			party.add_to_roster(character)
		else:
			DebugLogger.log_warn("Character not found: %s" % str(char_id), "SaveManager")

	var squad_ids: Array = data.get("squad", [])
	var typed_squad: Array[String] = []
	for sid in squad_ids:
		typed_squad.append(str(sid))
	party.squad = typed_squad

	var stash_data: Array = data.get("stash", [])
	for entry in stash_data:
		var item_id: String
		var saved_rarity: int
		if entry is String:
			item_id = str(entry)
			saved_rarity = -1
		else:
			item_id = str(entry.get("item_id", ""))
			saved_rarity = int(entry.get("rarity", -1))

		var item: ItemData = ItemDatabase.get_item(item_id)
		if not item:
			DebugLogger.log_warn("Stash item not found: %s" % item_id, "SaveManager")
			continue

		if saved_rarity >= 0:
			while item.rarity < saved_rarity:
				item = ItemUpgradeSystem.create_upgraded_item(item)
				if item.rarity == saved_rarity:
					break
				if item.rarity == Enums.Rarity.UNIQUE:
					break

		party.stash.append(item)

	var grid_data: Dictionary = data.get("grid_inventories", {})
	for char_id: String in grid_data:
		if not party.grid_inventories.has(char_id):
			DebugLogger.log_warn("No grid inventory for character: %s" % char_id, "SaveManager")
			continue
		var grid: GridInventory = party.grid_inventories[char_id]
		var placements: Array = grid_data[char_id]
		for entry in placements:
			var item: ItemData = ItemDatabase.get_item(str(entry.item_id))
			if not item:
				DebugLogger.log_warn("Grid item not found: %s" % str(entry.item_id), "SaveManager")
				continue

			var saved_rarity: int = int(entry.get("rarity", item.rarity))
			while item.rarity < saved_rarity:
				item = ItemUpgradeSystem.create_upgraded_item(item)
				if item.rarity == saved_rarity:
					break
				if item.rarity == Enums.Rarity.UNIQUE:
					break

			var pos := Vector2i(int(entry.x), int(entry.y))
			var rot := int(entry.rotation)
			var placed := grid.place_item(item, pos, rot)
			if not placed:
				DebugLogger.log_warn("Failed to place %s at (%d,%d) rot %d for %s — moved to stash" % [
					str(entry.item_id), pos.x, pos.y, rot, char_id
				], "SaveManager")
				party.stash.append(item)

	var passives_data: Dictionary = data.get("unlocked_passives", {})
	for char_id: String in passives_data:
		var node_ids: Array = passives_data[char_id]
		var typed_ids: Array[String] = []
		for nid in node_ids:
			typed_ids.append(str(nid))
		party.unlocked_passives[char_id] = typed_ids

	var vitals_data: Dictionary = data.get("character_vitals", {})
	for char_id: String in vitals_data:
		var vitals: Dictionary = vitals_data[char_id]
		party.character_vitals[char_id] = {
			"current_hp": int(vitals.get("current_hp", 0)),
			"current_mp": int(vitals.get("current_mp", 0))
		}

	var pos_data: Dictionary = data.get("overworld_position", {})
	var overworld_pos := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
	GameManager.set_flag("overworld_position", overworld_pos)

	var step_count: int = data.get("player_step_count", 0)
	GameManager.set_flag("player_step_count", step_count)

	for char_id: String in party.roster:
		if not party.character_vitals.has(char_id):
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
			party.initialize_vitals(char_id, tree)
			DebugLogger.log_info("Initialized vitals for character without saved data: %s" % char_id, "SaveManager")

	EventBus.gold_changed.emit(GameManager.gold)


# === Validation ===

func _validate(data: Dictionary) -> bool:
	if not data.has("version"):
		DebugLogger.log_error("Save file missing version field", "SaveManager")
		return false
	var version: int = int(data.version)
	if version < 1 or version > SAVE_VERSION:
		DebugLogger.log_error("Save version unsupported: expected 1-%d, got %d" % [
			SAVE_VERSION, version
		], "SaveManager")
		return false
	return true
