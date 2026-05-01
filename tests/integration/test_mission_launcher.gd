extends GutTest
## Integration test for _MissionLauncher.build_battle_data.
##
## This is the regression test for the 2026-04-30 bug where mission_board.gd
## inline-built the scene-data dict and forgot the "grid_inventories" key,
## causing battle to receive empty player inventories (no equipped weapons).
##
## Asserts that build_battle_data produces every key battle.gd reads from
## scene data. If you add a new field battle reads, add it here too.

# preload instead of relying on class_name registry — avoids "Parse error"
# when Godot hasn't reimported and the class_name isn't globally known yet.
const _MissionLauncher = preload("res://scripts/utils/mission_launcher.gd")

const REQUIRED_KEYS := ["encounter", "map_id", "fight_position", "grid_inventories"]

var _mission: MissionData
var _encounter: EncounterData


func before_each() -> void:
	GameManager.new_game()
	_mission = preload("res://data/missions/mission_easy_01.tres")
	_encounter = RandomEncounterGenerator.generate(1, 2, _mission.display_name, _mission.gold_reward)


func test_build_battle_data_has_all_required_keys() -> void:
	var data: Dictionary = _MissionLauncher.build_battle_data(
		_mission, _encounter, GameManager.party.grid_inventories
	)
	for key in REQUIRED_KEYS:
		assert_true(data.has(key), "Missing required scene-data key: %s" % key)


func test_grid_inventories_passes_through_party_data() -> void:
	var party_inv: Dictionary = GameManager.party.grid_inventories
	var data: Dictionary = _MissionLauncher.build_battle_data(_mission, _encounter, party_inv)
	assert_eq(data["grid_inventories"], party_inv,
		"grid_inventories should be the same dict reference passed in")
	# Spot-check: starter characters' inventories must be present so battle
	# can build their CombatEntity with equipped weapons.
	for char_id in ["warrior", "mage", "rogue"]:
		assert_true(data["grid_inventories"].has(char_id),
			"Missing grid_inventory for character: %s" % char_id)


func test_encounter_passes_through_unchanged() -> void:
	var data: Dictionary = _MissionLauncher.build_battle_data(
		_mission, _encounter, GameManager.party.grid_inventories
	)
	assert_eq(data["encounter"], _encounter,
		"Encounter reference should pass through build_battle_data unchanged")


func test_map_id_is_non_empty() -> void:
	# battle.gd skips background setup entirely if _map_id is empty, so this
	# must not regress to "".
	var data: Dictionary = _MissionLauncher.build_battle_data(
		_mission, _encounter, GameManager.party.grid_inventories
	)
	assert_ne(data["map_id"], "", "map_id must not be empty")


func test_fight_position_is_a_valid_vector3() -> void:
	var data: Dictionary = _MissionLauncher.build_battle_data(
		_mission, _encounter, GameManager.party.grid_inventories
	)
	assert_true(data["fight_position"] is Vector3,
		"fight_position must be Vector3 (battle.gd uses it as arena center)")


func test_handles_missing_party_with_empty_dict() -> void:
	# Edge case: hub auto-inits a party, but defensive code may pass {}.
	# build_battle_data should still produce a structurally complete dict.
	var data: Dictionary = _MissionLauncher.build_battle_data(_mission, _encounter, {})
	for key in REQUIRED_KEYS:
		assert_true(data.has(key), "Missing key %s when party_grid_inventories is empty" % key)
	assert_eq(data["grid_inventories"], {},
		"Empty inventories dict should pass through (battle handles missing player gear)")


# === compute_battle_outcome ===

func test_outcome_victory_first_time_marks_complete_and_awards_xp() -> void:
	var outcome: Dictionary = _MissionLauncher.compute_battle_outcome(_mission, true, [])
	assert_true(outcome.complete, "First-time victory should mark complete=true")
	assert_eq(outcome.xp_awarded, _mission.xp_reward, "XP awarded should equal mission.xp_reward")


func test_outcome_defeat_returns_no_completion() -> void:
	var outcome: Dictionary = _MissionLauncher.compute_battle_outcome(_mission, false, [])
	assert_false(outcome.complete, "Defeat should not mark mission complete")
	assert_eq(outcome.xp_awarded, 0, "Defeat should award 0 XP")


func test_outcome_already_completed_no_op() -> void:
	# Replaying a finished mission shouldn't re-mark it or re-award XP.
	var outcome: Dictionary = _MissionLauncher.compute_battle_outcome(
		_mission, true, [_mission.id]
	)
	assert_false(outcome.complete, "Already-completed mission should not complete again")
	assert_eq(outcome.xp_awarded, 0, "Already-completed mission should not re-award XP")


func test_outcome_null_mission_returns_no_op() -> void:
	# Defensive: if somehow called with no mission, must not crash.
	var outcome: Dictionary = _MissionLauncher.compute_battle_outcome(null, true, [])
	assert_false(outcome.complete)
	assert_eq(outcome.xp_awarded, 0)


func test_outcome_handles_missions_in_array_with_other_ids() -> void:
	# already_completed contains other ids — the test mission should still complete.
	var outcome: Dictionary = _MissionLauncher.compute_battle_outcome(
		_mission, true, ["other_mission_a", "other_mission_b"]
	)
	assert_true(outcome.complete,
		"Mission not in already_completed should still complete on victory")


# === resolve_encounter ===

func test_resolve_encounter_uses_fixed_path_when_set() -> void:
	# mission_easy_01 ships with encounter_path set to the wolves encounter.
	var encounter: EncounterData = _MissionLauncher.resolve_encounter(_mission)
	assert_not_null(encounter)
	assert_eq(encounter.id, "encounter_wolves",
		"resolve_encounter should return the exact EncounterData referenced by mission.encounter_path")
	# Wolf encounter has 2 wolves
	assert_eq(encounter.enemies.size(), 2,
		"Wolf encounter should have exactly 2 wolves — no random count")


func test_resolve_encounter_falls_back_to_random_when_path_empty() -> void:
	# Construct a mission with no encounter_path → must use random generator.
	var m := MissionData.new()
	m.id = "test_random_fallback"
	m.display_name = "Test Random"
	m.encounter_path = ""  # explicit empty
	m.enemy_count_min = 2
	m.enemy_count_max = 2
	m.gold_reward = 0
	m.xp_reward = 0
	var enc: EncounterData = _MissionLauncher.resolve_encounter(m)
	assert_not_null(enc, "Random fallback should produce an encounter")
	assert_eq(enc.enemies.size(), 2,
		"Random fallback must respect enemy_count_min == max")


func test_resolve_encounter_returns_null_for_null_mission() -> void:
	assert_null(_MissionLauncher.resolve_encounter(null),
		"resolve_encounter(null) must not crash; should return null")


func test_resolve_encounter_falls_back_when_path_invalid() -> void:
	# encounter_path points at a nonexistent file → fall back to random generator
	# rather than crashing the mission.
	var m := MissionData.new()
	m.id = "test_invalid_path"
	m.display_name = "Test Invalid"
	m.encounter_path = "res://data/encounters/this_file_does_not_exist.tres"
	m.enemy_count_min = 1
	m.enemy_count_max = 1
	var enc: EncounterData = _MissionLauncher.resolve_encounter(m)
	assert_not_null(enc, "Invalid path should fall through to random, not crash")
	assert_gt(enc.enemies.size(), 0)
