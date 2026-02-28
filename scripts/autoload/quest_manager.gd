extends Node
## Autoload that loads all quests, tracks active/completed state,
## auto-updates objective progress from EventBus signals, and awards rewards.
## All quest state lives in GameManager.story_flags (auto-persisted by SaveManager).

const QUEST_DIR := "res://data/quests/"

var _quests: Dictionary = {}  # quest_id -> QuestData


func _ready() -> void:
	_load_all_quests()
	_connect_signals()
	DebugLogger.log_info("Loaded %d quests" % _quests.size(), "QuestManager")


# === Loading ===

func _load_all_quests() -> void:
	var dir := DirAccess.open(QUEST_DIR)
	if not dir:
		DebugLogger.log_warn("Quest directory not found: %s" % QUEST_DIR, "QuestManager")
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := QUEST_DIR + file_name
			var quest := load(full_path) as QuestData
			if quest:
				if quest.id.is_empty():
					quest.id = file_name.get_basename()
				_register_quest(quest)
			else:
				DebugLogger.log_warn("Failed to load quest: %s" % full_path, "QuestManager")
		file_name = dir.get_next()
	dir.list_dir_end()


func _register_quest(quest: QuestData) -> void:
	if _quests.has(quest.id):
		DebugLogger.log_warn("Duplicate quest ID: %s" % quest.id, "QuestManager")
	_quests[quest.id] = quest


func reload() -> void:
	_quests.clear()
	_load_all_quests()
	DebugLogger.log_info("Reloaded %d quests" % _quests.size(), "QuestManager")


# === Lookup ===

func get_quest(quest_id: String) -> QuestData:
	if _quests.has(quest_id):
		return _quests[quest_id]
	DebugLogger.log_warn("Quest not found: %s" % quest_id, "QuestManager")
	return null


func get_all_quests() -> Array:
	return _quests.values()


func has_quest(quest_id: String) -> bool:
	return _quests.has(quest_id)


# === State Queries (via GameManager.story_flags) ===

func is_quest_active(quest_id: String) -> bool:
	var accepted: bool = GameManager.get_flag("quest_%s_accepted" % quest_id, false)
	var completed: bool = GameManager.get_flag("quest_%s_completed" % quest_id, false)
	return accepted and not completed


func is_quest_completed(quest_id: String) -> bool:
	return GameManager.get_flag("quest_%s_completed" % quest_id, false)


func is_quest_available(quest_id: String) -> bool:
	var quest: QuestData = get_quest(quest_id)
	if not quest:
		return false
	if GameManager.get_flag("quest_%s_accepted" % quest_id, false):
		return false
	if not quest.is_repeatable and GameManager.get_flag("quest_%s_completed" % quest_id, false):
		return false
	return _are_prerequisites_met(quest)


func get_active_quests() -> Array:
	var result: Array = []
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		if is_quest_active(quest_id):
			result.append(_quests[quest_id])
	return result


func get_completed_quests() -> Array:
	var result: Array = []
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		if is_quest_completed(quest_id):
			result.append(_quests[quest_id])
	return result


func get_available_quests() -> Array:
	var result: Array = []
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		if is_quest_available(quest_id):
			result.append(_quests[quest_id])
	return result


## Check if a quest's objectives are all complete (ready to turn in).
func is_quest_ready_to_complete(quest_id: String) -> bool:
	var quest: QuestData = get_quest(quest_id)
	if not quest or not is_quest_active(quest_id):
		return false
	return _are_all_objectives_complete(quest)


# === Actions ===

func accept_quest(quest_id: String) -> void:
	var quest: QuestData = get_quest(quest_id)
	if not quest:
		return
	if GameManager.get_flag("quest_%s_accepted" % quest_id, false):
		DebugLogger.log_warn("Quest already accepted: %s" % quest_id, "QuestManager")
		return

	GameManager.set_flag("quest_%s_accepted" % quest_id, true)

	# Initialize objective progress flags to 0
	for i in range(quest.objectives.size()):
		var obj: QuestObjective = quest.objectives[i]
		var flag := _objective_flag(quest_id, i)
		obj.progress_flag = flag
		GameManager.set_flag(flag, 0)

	DebugLogger.log_info("Quest accepted: %s" % quest.display_name, "QuestManager")
	EventBus.quest_accepted.emit(quest_id)


func complete_quest(quest_id: String) -> void:
	var quest: QuestData = get_quest(quest_id)
	if not quest:
		return
	if not is_quest_active(quest_id):
		DebugLogger.log_warn("Cannot complete quest (not active): %s" % quest_id, "QuestManager")
		return
	if not _are_all_objectives_complete(quest):
		DebugLogger.log_warn("Cannot complete quest (objectives incomplete): %s" % quest_id, "QuestManager")
		return

	# Award rewards
	if quest.reward_gold > 0:
		GameManager.add_gold(quest.reward_gold)
	for i in range(quest.reward_items.size()):
		var item: ItemData = quest.reward_items[i]
		GameManager.party.add_to_stash(item)
	# XP reward — TODO: implement XP system, for now just store as flag
	if quest.reward_xp > 0:
		GameManager.set_flag("quest_%s_xp_awarded" % quest_id, quest.reward_xp)

	GameManager.set_flag("quest_%s_completed" % quest_id, true)
	DebugLogger.log_info("Quest completed: %s (gold: %d, items: %d)" % [
		quest.display_name, quest.reward_gold, quest.reward_items.size()
	], "QuestManager")
	EventBus.quest_completed.emit(quest_id)

	# Reset repeatable quests so they can be accepted again
	if quest.is_repeatable:
		GameManager.set_flag("quest_%s_accepted" % quest_id, false)
		GameManager.set_flag("quest_%s_completed" % quest_id, false)
		for i in range(quest.objectives.size()):
			var flag := _objective_flag(quest_id, i)
			GameManager.set_flag(flag, 0)
		DebugLogger.log_info("Repeatable quest reset: %s" % quest_id, "QuestManager")

	# Check if completing this quest makes new quests available
	_check_newly_available_quests()


func update_objective_progress(quest_id: String, obj_index: int, value: int) -> void:
	var quest: QuestData = get_quest(quest_id)
	if not quest or obj_index < 0 or obj_index >= quest.objectives.size():
		return

	var obj: QuestObjective = quest.objectives[obj_index]
	var flag := _objective_flag(quest_id, obj_index)
	var old_value: int = GameManager.get_flag(flag, 0)
	if value <= old_value:
		return

	var clamped: int = mini(value, obj.target_count)
	GameManager.set_flag(flag, clamped)
	EventBus.quest_progressed.emit(quest_id, obj_index, clamped, obj.target_count)
	DebugLogger.log_info("Quest progress: %s obj %d — %d/%d" % [
		quest_id, obj_index, clamped, obj.target_count
	], "QuestManager")

	# Auto-complete if no turn-in NPC required and all objectives done
	if quest.turn_in_npc_id.is_empty() and _are_all_objectives_complete(quest):
		complete_quest(quest_id)


# === Signal Connections ===

func _connect_signals() -> void:
	EventBus.combat_ended.connect(_on_combat_ended)
	EventBus.dialogue_ended.connect(_on_dialogue_ended)
	EventBus.location_prompt_visible.connect(_on_location_prompt)
	EventBus.inventory_changed.connect(_on_inventory_changed)
	EventBus.game_loaded.connect(_on_game_loaded)


func _on_combat_ended(victory: bool, defeated_enemy_ids: Array) -> void:
	if not victory or defeated_enemy_ids.is_empty():
		return

	var active: Array = get_active_quests()
	for qi in range(active.size()):
		var quest: QuestData = active[qi]
		for oi in range(quest.objectives.size()):
			var obj: QuestObjective = quest.objectives[oi]
			if obj.objective_type == QuestObjective.ObjectiveType.KILL or obj.objective_type == QuestObjective.ObjectiveType.DEFEAT_BOSS:
				var flag := _objective_flag(quest.id, oi)
				var progress: int = GameManager.get_flag(flag, 0)
				if progress >= obj.target_count:
					continue
				# Count how many defeated enemies match the target
				var count: int = 0
				for ei in range(defeated_enemy_ids.size()):
					var enemy_id: String = defeated_enemy_ids[ei]
					if enemy_id == obj.target_id:
						count += 1
				if count > 0:
					update_objective_progress(quest.id, oi, progress + count)


func _on_dialogue_ended(npc_id: String) -> void:
	var active: Array = get_active_quests()
	for qi in range(active.size()):
		var quest: QuestData = active[qi]
		for oi in range(quest.objectives.size()):
			var obj: QuestObjective = quest.objectives[oi]
			if obj.objective_type == QuestObjective.ObjectiveType.TALK_TO and obj.target_id == npc_id:
				update_objective_progress(quest.id, oi, 1)


func _on_location_prompt(visible: bool, location_name: String) -> void:
	if not visible:
		return
	var active: Array = get_active_quests()
	for qi in range(active.size()):
		var quest: QuestData = active[qi]
		for oi in range(quest.objectives.size()):
			var obj: QuestObjective = quest.objectives[oi]
			if obj.objective_type == QuestObjective.ObjectiveType.REACH_LOCATION and obj.target_id == location_name:
				update_objective_progress(quest.id, oi, 1)


func _on_inventory_changed(_character_id: String) -> void:
	var active: Array = get_active_quests()
	for qi in range(active.size()):
		var quest: QuestData = active[qi]
		for oi in range(quest.objectives.size()):
			var obj: QuestObjective = quest.objectives[oi]
			if obj.objective_type == QuestObjective.ObjectiveType.COLLECT:
				var count: int = _count_items_in_party(obj.target_id)
				update_objective_progress(quest.id, oi, count)


func _on_game_loaded() -> void:
	# Restore progress_flag fields on objectives for active quests
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		if is_quest_active(quest_id):
			var quest: QuestData = _quests[quest_id]
			for oi in range(quest.objectives.size()):
				quest.objectives[oi].progress_flag = _objective_flag(quest_id, oi)

	# Check if any new quests became available
	_check_newly_available_quests()


# === Helpers ===

func _objective_flag(quest_id: String, obj_index: int) -> String:
	return "quest_%s_obj_%d" % [quest_id, obj_index]


func _are_prerequisites_met(quest: QuestData) -> bool:
	# Check required story flags
	for i in range(quest.required_flags.size()):
		var flag: String = quest.required_flags[i]
		if not GameManager.get_flag(flag, false):
			return false
	# Check prerequisite quests
	for i in range(quest.prerequisite_quest_ids.size()):
		var prereq_id: String = quest.prerequisite_quest_ids[i]
		if not GameManager.get_flag("quest_%s_completed" % prereq_id, false):
			return false
	# Check level requirement (if we ever add levels — skip for now if 0)
	return true


func _are_all_objectives_complete(quest: QuestData) -> bool:
	for i in range(quest.objectives.size()):
		var obj: QuestObjective = quest.objectives[i]
		var flag := _objective_flag(quest.id, i)
		var progress: int = GameManager.get_flag(flag, 0)
		if progress < obj.target_count:
			return false
	return true


func _count_items_in_party(item_id: String) -> int:
	var count: int = 0
	if not GameManager.party:
		return 0
	# Count in stash
	for i in range(GameManager.party.stash.size()):
		var item: ItemData = GameManager.party.stash[i]
		if item.id == item_id:
			count += 1
	# Count in all character grid inventories
	var char_ids: Array = GameManager.party.grid_inventories.keys()
	for ci in range(char_ids.size()):
		var char_id: String = char_ids[ci]
		var grid: GridInventory = GameManager.party.grid_inventories[char_id]
		for pi in range(grid.placed_items.size()):
			var placed: GridInventory.PlacedItem = grid.placed_items[pi]
			if placed.item_data.id == item_id:
				count += 1
	return count


## Returns true if this NPC has any quest available to offer.
func npc_has_available_quest(npc_id: String) -> bool:
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		var quest: QuestData = _quests[quest_id]
		if quest.quest_giver_npc_id == npc_id and is_quest_available(quest_id):
			return true
	return false


## Returns true if this NPC has any quest ready to turn in.
func npc_has_turn_in_quest(npc_id: String) -> bool:
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		var quest: QuestData = _quests[quest_id]
		if quest.turn_in_npc_id == npc_id and is_quest_ready_to_complete(quest_id):
			return true
	return false


## Returns true if this NPC has any active (in-progress) quest.
func npc_has_active_quest(npc_id: String) -> bool:
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		var quest: QuestData = _quests[quest_id]
		var is_giver := quest.quest_giver_npc_id == npc_id
		var is_turn_in := quest.turn_in_npc_id == npc_id
		if (is_giver or is_turn_in) and is_quest_active(quest_id) and not is_quest_ready_to_complete(quest_id):
			return true
	return false


func _check_newly_available_quests() -> void:
	var keys: Array = _quests.keys()
	for i in range(keys.size()):
		var quest_id: String = keys[i]
		if is_quest_available(quest_id):
			EventBus.quest_available.emit(quest_id)
