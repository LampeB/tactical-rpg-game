extends GutTest
## Tests for MissionData resources in data/missions/.
## Verifies all missions load + have required fields populated.

const MISSIONS_DIR := "res://data/missions/"


func test_all_missions_load() -> void:
	var missions: Array = _load_all_missions()
	assert_gt(missions.size(), 0, "Expected at least one mission in data/missions/")


func test_each_mission_has_required_fields() -> void:
	var missions: Array = _load_all_missions()
	for mission in missions:
		assert_ne(mission.id, "", "Mission id should not be empty")
		assert_ne(mission.display_name, "", "Mission '%s' has no display_name" % mission.id)
		assert_gt(mission.enemy_count_min, 0, "Mission '%s' enemy_count_min should be > 0" % mission.id)
		assert_gte(mission.enemy_count_max, mission.enemy_count_min,
			"Mission '%s' enemy_count_max < min" % mission.id)


func test_missions_have_unique_ids() -> void:
	var missions: Array = _load_all_missions()
	var seen: Dictionary = {}
	for mission in missions:
		assert_false(seen.has(mission.id), "Duplicate mission id: %s" % mission.id)
		seen[mission.id] = true


func _load_all_missions() -> Array:
	var result: Array = []
	var dir := DirAccess.open(MISSIONS_DIR)
	if not dir:
		return result
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".tres"):
			var resource: Resource = load(MISSIONS_DIR + entry)
			if resource is MissionData:
				result.append(resource)
		entry = dir.get_next()
	dir.list_dir_end()
	return result
