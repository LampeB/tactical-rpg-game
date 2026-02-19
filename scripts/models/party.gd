class_name Party
extends RefCounted
## Runtime party state: roster of characters, active squad, shared item stash.

signal squad_changed()
signal roster_changed()
signal stash_changed()
signal passives_changed(character_id: String)

## All recruited characters (by id -> CharacterData).
var roster: Dictionary = {}

## Active squad member IDs (up to MAX_SQUAD_SIZE).
var squad: Array[String] = []

## Shared item stash (items not equipped on any character).
var stash: Array = [] ## of ItemData

## Persistent grid inventories (character_id -> GridInventory).
var grid_inventories: Dictionary = {}

## Unlocked passive skill tree nodes (character_id -> Array[String] of node IDs).
var unlocked_passives: Dictionary = {}

func add_to_roster(character: CharacterData) -> bool:
	if roster.size() >= Constants.MAX_ROSTER_SIZE:
		return false
	if roster.has(character.id):
		return false
	roster[character.id] = character
	# Create persistent grid inventory for this character
	if character.grid_template and not grid_inventories.has(character.id):
		grid_inventories[character.id] = GridInventory.new(character.grid_template)
	roster_changed.emit()
	# Auto-add to squad if there's room
	if squad.size() < Constants.MAX_SQUAD_SIZE:
		squad.append(character.id)
		squad_changed.emit()
	return true

func remove_from_roster(character_id: String):
	roster.erase(character_id)
	squad.erase(character_id)
	grid_inventories.erase(character_id)
	roster_changed.emit()
	squad_changed.emit()

func set_squad(member_ids: Array[String]):
	squad = member_ids.slice(0, Constants.MAX_SQUAD_SIZE)
	squad_changed.emit()

func get_squad_members() -> Array:
	var members: Array = []
	for id in squad:
		if roster.has(id):
			members.append(roster[id])
	return members

func add_to_stash(item: ItemData) -> bool:
	if stash.size() >= Constants.MAX_STASH_SLOTS:
		return false
	stash.append(item)
	stash_changed.emit()
	return true

func remove_from_stash(item: ItemData):
	var idx := stash.find(item)
	if idx >= 0:
		stash.remove_at(idx)
		stash_changed.emit()

func get_stash_size() -> int:
	return stash.size()


# === Passive Skill Tree ===

func unlock_passive(character_id: String, node_id: String) -> void:
	if not unlocked_passives.has(character_id):
		unlocked_passives[character_id] = []
	var nodes: Array = unlocked_passives[character_id]
	if not nodes.has(node_id):
		nodes.append(node_id)
		passives_changed.emit(character_id)


func is_passive_unlocked(character_id: String, node_id: String) -> bool:
	if not unlocked_passives.has(character_id):
		return false
	return unlocked_passives[character_id].has(node_id)


func get_unlocked_passives(character_id: String) -> Array:
	if not unlocked_passives.has(character_id):
		return []
	return unlocked_passives[character_id]


## Compute passive bonuses for a character. Requires a PassiveTreeData
## (caller must look it up since Party can't reference autoloads).
func get_passive_bonuses(character_id: String, tree: PassiveTreeData) -> Dictionary:
	var stat_mods: Array = []
	var effects: Array = []
	if not tree:
		return {"stat_modifiers": stat_mods, "special_effects": effects}
	var unlocked: Array = get_unlocked_passives(character_id)
	for i in range(tree.nodes.size()):
		var node: PassiveNodeData = tree.nodes[i]
		if node and unlocked.has(node.id):
			stat_mods.append_array(node.stat_modifiers)
			if not node.special_effect_id.is_empty():
				effects.append(node.special_effect_id)
	return {"stat_modifiers": stat_mods, "special_effects": effects}
