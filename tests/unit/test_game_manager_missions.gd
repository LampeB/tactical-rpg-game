extends GutTest
## Unit tests for GameManager mission-completion API:
## mark_mission_complete + is_mission_complete + idempotency.


func before_each() -> void:
	GameManager.new_game()


func test_completed_missions_starts_empty() -> void:
	assert_eq(GameManager.completed_missions.size(), 0,
		"Fresh game should have no completed missions")


func test_mark_mission_complete_appends_id() -> void:
	GameManager.mark_mission_complete("mission_easy_01")
	assert_eq(GameManager.completed_missions, ["mission_easy_01"])
	assert_true(GameManager.is_mission_complete("mission_easy_01"))


func test_is_mission_complete_false_for_uncompleted() -> void:
	assert_false(GameManager.is_mission_complete("never_done"),
		"Should report uncompleted mission as incomplete")


func test_mark_mission_complete_is_idempotent() -> void:
	GameManager.mark_mission_complete("mission_easy_01")
	GameManager.mark_mission_complete("mission_easy_01")
	GameManager.mark_mission_complete("mission_easy_01")
	assert_eq(GameManager.completed_missions.size(), 1,
		"Repeated marks should not duplicate the entry")


func test_mark_mission_complete_with_empty_id_is_noop() -> void:
	GameManager.mark_mission_complete("")
	assert_eq(GameManager.completed_missions.size(), 0,
		"Empty id should be ignored, not stored")


func test_multiple_missions_complete_independently() -> void:
	GameManager.mark_mission_complete("a")
	GameManager.mark_mission_complete("b")
	GameManager.mark_mission_complete("c")
	assert_eq(GameManager.completed_missions.size(), 3)
	for m in ["a", "b", "c"]:
		assert_true(GameManager.is_mission_complete(m), "Should track %s as complete" % m)


func test_new_game_resets_completed_missions() -> void:
	GameManager.mark_mission_complete("stale")
	GameManager.new_game()
	assert_eq(GameManager.completed_missions.size(), 0,
		"new_game should clear completed_missions")
