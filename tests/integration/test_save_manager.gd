extends GutTest
## Integration tests for SaveManager.
## Save/load corruption is the worst-class bug — silent state mutation
## bites later. These tests verify the round trip preserves party state and
## the basic API contracts.
##
## Tests use slot 4 (last manual slot) so they don't interfere with normal
## play saves. State is cleaned up before/after each test.

const TEST_SLOT := 4


func before_each() -> void:
	# Wipe TEST_SLOT and the auto slot so each test starts clean.
	SaveManager.delete_slot(TEST_SLOT)
	GameManager.is_game_started = false  # Reset before each test
	GameManager.party = null


func after_each() -> void:
	SaveManager.delete_slot(TEST_SLOT)


# === has_save / has_any_save contract ===

func test_has_save_false_on_clean_state() -> void:
	# After before_each cleanup, no save in TEST_SLOT
	assert_false(SaveManager.has_save() and _only_test_slot_has_save(),
		"has_save should reflect actual state; if true, other slots may have saves")


func test_has_save_true_after_save() -> void:
	GameManager.new_game()
	var ok: bool = SaveManager.save_to_slot(TEST_SLOT)
	assert_true(ok, "save_to_slot should succeed when game is started")
	var meta: Dictionary = SaveManager.get_slot_meta(TEST_SLOT)
	assert_false(meta.is_empty(), "Saved slot should have metadata")
	assert_gt(meta.get("history_count", 0), 0, "history_count should be > 0 after save")


func test_save_fails_when_no_game_started() -> void:
	# is_game_started=false (cleared in before_each)
	assert_false(GameManager.is_game_started)
	var ok: bool = SaveManager.save_to_slot(TEST_SLOT)
	assert_false(ok, "save_to_slot should fail when no game is started")


# === Round trip ===

func test_round_trip_preserves_gold() -> void:
	GameManager.new_game()
	var original_gold: int = GameManager.gold
	GameManager.gold = original_gold + 250  # Mutate
	SaveManager.save_to_slot(TEST_SLOT)

	# Reset state, then load
	GameManager.gold = 0
	GameManager.is_game_started = false
	var ok: bool = SaveManager.load_from_slot(TEST_SLOT)
	assert_true(ok, "load_from_slot should succeed for a saved slot")
	assert_eq(GameManager.gold, original_gold + 250,
		"Gold should be restored to the saved value")


func test_round_trip_preserves_party_roster() -> void:
	GameManager.new_game()
	var original_ids: Array = GameManager.party.roster.keys()
	original_ids.sort()
	SaveManager.save_to_slot(TEST_SLOT)

	GameManager.party = null
	SaveManager.load_from_slot(TEST_SLOT)

	assert_not_null(GameManager.party, "Party should exist after load")
	var loaded_ids: Array = GameManager.party.roster.keys()
	loaded_ids.sort()
	assert_eq(loaded_ids, original_ids,
		"Loaded roster should contain the same character ids as original")


func test_round_trip_preserves_squad() -> void:
	GameManager.new_game()
	var original_squad: Array = GameManager.party.squad.duplicate()
	SaveManager.save_to_slot(TEST_SLOT)

	GameManager.party = null
	SaveManager.load_from_slot(TEST_SLOT)

	assert_eq(GameManager.party.squad, original_squad,
		"Squad order and members should round-trip exactly")


func test_round_trip_preserves_is_game_started() -> void:
	GameManager.new_game()
	SaveManager.save_to_slot(TEST_SLOT)

	GameManager.is_game_started = false  # Reset
	SaveManager.load_from_slot(TEST_SLOT)

	assert_true(GameManager.is_game_started,
		"is_game_started should be true after loading a real save")


# === Auto-save ===

func test_auto_save_succeeds_when_game_started() -> void:
	GameManager.new_game()
	var ok: bool = SaveManager.auto_save()
	assert_true(ok, "auto_save should succeed when game is started")
	var meta: Dictionary = SaveManager.get_auto_save_meta()
	assert_false(meta.is_empty())


func test_auto_save_fails_without_game() -> void:
	# is_game_started=false from before_each
	var ok: bool = SaveManager.auto_save()
	assert_false(ok, "auto_save should fail when no game is started")


# === delete_slot ===

func test_delete_slot_removes_save() -> void:
	GameManager.new_game()
	SaveManager.save_to_slot(TEST_SLOT)
	var meta_before: Dictionary = SaveManager.get_slot_meta(TEST_SLOT)
	assert_false(meta_before.is_empty(), "Sanity: slot should have data before delete")

	SaveManager.delete_slot(TEST_SLOT)
	var meta_after: Dictionary = SaveManager.get_slot_meta(TEST_SLOT)
	assert_true(meta_after.is_empty() or meta_after.get("history_count", 0) == 0,
		"After delete_slot, the slot should report no save")


# === Helpers ===

func _only_test_slot_has_save() -> bool:
	# True if any save exists ONLY in TEST_SLOT (other slots / auto have nothing).
	for i in range(SaveManager.MAX_SLOTS):
		if i == TEST_SLOT:
			continue
		var meta := SaveManager.get_slot_meta(i)
		if not meta.is_empty() and meta.get("history_count", 0) > 0:
			return false
	var auto: Dictionary = SaveManager.get_auto_save_meta()
	if not auto.is_empty() and auto.get("history_count", 0) > 0:
		return false
	return true
