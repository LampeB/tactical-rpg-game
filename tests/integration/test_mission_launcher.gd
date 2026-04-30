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
