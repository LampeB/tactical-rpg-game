extends Node
## Handles serialization/deserialization of game state to/from JSON.
## Single save slot at user://save.json.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 1

var _playtime_accumulator: float = 0.0
var _is_tracking_playtime: bool = false

func _ready():
	DebugLogger.log_info("SaveManager ready", "SaveManager")

func _process(delta: float):
	if _is_tracking_playtime:
		_playtime_accumulator += delta


# === Public API ===

func start_playtime_tracking():
	_is_tracking_playtime = true

func stop_playtime_tracking():
	_is_tracking_playtime = false

func save_game() -> bool:
	if not GameManager.is_game_started:
		DebugLogger.log_warning("Cannot save — no game in progress", "SaveManager")
		return false
	var data := _serialize()
	var json_string := JSON.stringify(data, "\t")
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		DebugLogger.log_error("Failed to open save file: %s" % SAVE_PATH, "SaveManager")
		return false
	file.store_string(json_string)
	file.close()
	EventBus.game_saved.emit()
	DebugLogger.log_info("Game saved — Gold: %d, Roster: %d, Stash: %d" % [
		GameManager.gold, GameManager.party.roster.size(), GameManager.party.stash.size()
	], "SaveManager")
	return true

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		DebugLogger.log_warning("No save file found", "SaveManager")
		return false
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		DebugLogger.log_error("Failed to open save file for reading", "SaveManager")
		return false
	var json_string := file.get_as_text()
	file.close()

	var json := JSON.new()
	var parse_result := json.parse(json_string)
	if parse_result != OK:
		DebugLogger.log_error("Failed to parse save JSON: %s" % json.get_error_message(), "SaveManager")
		return false

	var data: Dictionary = json.data
	if not _validate(data):
		return false

	_deserialize(data)
	EventBus.game_loaded.emit()
	DebugLogger.log_info("Game loaded — Gold: %d, Roster: %d, Stash: %d" % [
		GameManager.gold, GameManager.party.roster.size(), GameManager.party.stash.size()
	], "SaveManager")
	return true

func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)

func delete_save():
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
		DebugLogger.log_info("Save file deleted", "SaveManager")


# === Serialization ===

func _serialize() -> Dictionary:
	var party: Party = GameManager.party
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
	}

func _serialize_stash(stash: Array) -> Array:
	var result: Array = []
	for item in stash:
		result.append(item.id)
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
			})
		result[character_id] = placements
	return result


# === Deserialization ===

func _deserialize(data: Dictionary):
	# Reset GameManager state
	GameManager.gold = int(data.get("gold", 0))
	GameManager.story_flags = data.get("story_flags", {})
	GameManager.is_game_started = true
	_playtime_accumulator = data.get("playtime_seconds", 0.0)

	# Rebuild party
	var party := Party.new()
	GameManager.party = party

	# Roster: load CharacterData from CharacterDatabase
	var roster_ids: Array = data.get("roster", [])
	for char_id in roster_ids:
		var character: CharacterData = CharacterDatabase.get_character(str(char_id))
		if character:
			party.add_to_roster(character)
		else:
			DebugLogger.log_warning("Character not found: %s" % str(char_id), "SaveManager")

	# Squad (override what add_to_roster auto-set)
	var squad_ids: Array = data.get("squad", [])
	var typed_squad: Array[String] = []
	for sid in squad_ids:
		typed_squad.append(str(sid))
	party.squad = typed_squad

	# Stash
	var stash_ids: Array = data.get("stash", [])
	for item_id in stash_ids:
		var item: ItemData = ItemDatabase.get_item(str(item_id))
		if item:
			party.stash.append(item)
		else:
			DebugLogger.log_warning("Stash item not found: %s" % str(item_id), "SaveManager")

	# Grid inventories: place items to rebuild _cell_map
	var grid_data: Dictionary = data.get("grid_inventories", {})
	for char_id: String in grid_data:
		if not party.grid_inventories.has(char_id):
			DebugLogger.log_warning("No grid inventory for character: %s" % char_id, "SaveManager")
			continue
		var grid: GridInventory = party.grid_inventories[char_id]
		var placements: Array = grid_data[char_id]
		for entry in placements:
			var item: ItemData = ItemDatabase.get_item(str(entry.item_id))
			if not item:
				DebugLogger.log_warning("Grid item not found: %s" % str(entry.item_id), "SaveManager")
				continue
			var pos := Vector2i(int(entry.x), int(entry.y))
			var rot := int(entry.rotation)
			var placed := grid.place_item(item, pos, rot)
			if not placed:
				DebugLogger.log_warning("Failed to place %s at (%d,%d) rot %d for %s" % [
					str(entry.item_id), pos.x, pos.y, rot, char_id
				], "SaveManager")

	# Update UI
	EventBus.gold_changed.emit(GameManager.gold)


# === Validation ===

func _validate(data: Dictionary) -> bool:
	if not data.has("version"):
		DebugLogger.log_error("Save file missing version field", "SaveManager")
		return false
	if int(data.version) != SAVE_VERSION:
		DebugLogger.log_error("Save version mismatch: expected %d, got %s" % [
			SAVE_VERSION, str(data.version)
		], "SaveManager")
		return false
	return true
