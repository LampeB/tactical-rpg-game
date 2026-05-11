extends Node
## Autoload that loads and indexes all MissionData resources at startup.
## Access missions by ID: MissionDatabase.get_mission("mission_easy_01")

const _Loader = preload("res://scripts/utils/resource_loader_helper.gd")

var _missions: Dictionary = {}  # id -> MissionData

const MISSION_DIR := "res://data/missions/"


func _ready() -> void:
	_load_all_missions()
	DebugLogger.log_info("Loaded %d missions" % _missions.size(), "MissionDatabase")


func _load_all_missions() -> void:
	_missions = _Loader.load_dir(MISSION_DIR, "MissionDatabase")


func get_mission(id: String) -> MissionData:
	if _missions.has(id):
		return _missions[id]
	DebugLogger.log_warn("Mission not found: %s" % id, "MissionDatabase")
	return null


func get_all() -> Array:
	return _missions.values()


# NOTE: Full unlock-condition filtering (chapter gates, story flags) is a separate task.
# This only excludes missions already completed by the player.
func get_available(completed_ids: Array[String]) -> Array:
	var result: Array = []
	var all_missions: Array = _missions.values()
	for i: int in range(all_missions.size()):
		var mission: MissionData = all_missions[i]
		if not completed_ids.has(mission.id):
			result.append(mission)
	return result


func has_mission(id: String) -> bool:
	return _missions.has(id)


func reload() -> void:
	_missions.clear()
	_load_all_missions()
	DebugLogger.log_info("Reloaded %d missions" % _missions.size(), "MissionDatabase")
