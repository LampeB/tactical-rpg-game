extends Node
## Handles serialization/deserialization of game state to/from JSON.
## Single save slot at user://save.json.

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 3

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
		DebugLogger.log_warn("Cannot save — no game in progress", "SaveManager")
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
		DebugLogger.log_warn("No save file found", "SaveManager")
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
		"unlocked_passives": _serialize_passives(party.unlocked_passives),
		"character_vitals": party.character_vitals.duplicate(true),
		"overworld_position": {"x": overworld_pos.x, "y": overworld_pos.y},
		"player_step_count": GameManager.get_flag("player_step_count", 0),
	}

func _serialize_stash(stash: Array) -> Array:
	var result: Array = []
	for item in stash:
		result.append({
			"item_id": item.id,
			"rarity": item.rarity,  # Save rarity to restore upgrades
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
				"rarity": placed.item_data.rarity,  # Save rarity to restore upgrades
			})
		result[character_id] = placements
	return result

func _serialize_passives(passives: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for character_id: String in passives:
		result[character_id] = Array(passives[character_id])
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
			DebugLogger.log_warn("Character not found: %s" % str(char_id), "SaveManager")

	# Squad (override what add_to_roster auto-set)
	var squad_ids: Array = data.get("squad", [])
	var typed_squad: Array[String] = []
	for sid in squad_ids:
		typed_squad.append(str(sid))
	party.squad = typed_squad

	# Stash
	var stash_data: Array = data.get("stash", [])
	for entry in stash_data:
		var item_id: String
		var saved_rarity: int

		# Support old save format (just ID string) and new format (object with rarity)
		if entry is String:
			item_id = str(entry)
			saved_rarity = -1  # Unknown, use database default
		else:
			item_id = str(entry.get("item_id", ""))
			saved_rarity = int(entry.get("rarity", -1))

		var item: ItemData = ItemDatabase.get_item(item_id)
		if not item:
			DebugLogger.log_warn("Stash item not found: %s" % item_id, "SaveManager")
			continue

		# Restore upgraded rarity if item was upgraded
		if saved_rarity >= 0:
			while item.rarity < saved_rarity:
				item = ItemUpgradeSystem.create_upgraded_item(item)
				if item.rarity == saved_rarity:
					break
				if item.rarity == Enums.Rarity.UNIQUE:
					break  # Max rarity reached

		party.stash.append(item)

	# Grid inventories: place items to rebuild _cell_map
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

			# Restore upgraded rarity if item was upgraded
			var saved_rarity: int = int(entry.get("rarity", item.rarity))
			while item.rarity < saved_rarity:
				item = ItemUpgradeSystem.create_upgraded_item(item)
				if item.rarity == saved_rarity:
					break
				if item.rarity == Enums.Rarity.UNIQUE:
					break  # Max rarity reached

			var pos := Vector2i(int(entry.x), int(entry.y))
			var rot := int(entry.rotation)
			var placed := grid.place_item(item, pos, rot)
			if not placed:
				DebugLogger.log_warn("Failed to place %s at (%d,%d) rot %d for %s" % [
					str(entry.item_id), pos.x, pos.y, rot, char_id
				], "SaveManager")

	# Unlocked passives
	var passives_data: Dictionary = data.get("unlocked_passives", {})
	for char_id: String in passives_data:
		var node_ids: Array = passives_data[char_id]
		var typed_ids: Array[String] = []
		for nid in node_ids:
			typed_ids.append(str(nid))
		party.unlocked_passives[char_id] = typed_ids

	# Character vitals (HP/MP)
	var vitals_data: Dictionary = data.get("character_vitals", {})
	for char_id: String in vitals_data:
		var vitals: Dictionary = vitals_data[char_id]
		party.character_vitals[char_id] = {
			"current_hp": int(vitals.get("current_hp", 0)),
			"current_mp": int(vitals.get("current_mp", 0))
		}

	# Overworld position
	var pos_data: Dictionary = data.get("overworld_position", {})
	var overworld_pos := Vector2(pos_data.get("x", 0.0), pos_data.get("y", 0.0))
	GameManager.set_flag("overworld_position", overworld_pos)

	# Player step count
	var step_count: int = data.get("player_step_count", 0)
	GameManager.set_flag("player_step_count", step_count)

	# Initialize vitals for any characters without saved data
	for char_id: String in party.roster:
		if not party.character_vitals.has(char_id):
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
			party.initialize_vitals(char_id, tree)
			DebugLogger.log_info("Initialized vitals for character without saved data: %s" % char_id, "SaveManager")

	# Update UI
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
