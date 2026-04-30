extends GutTest
## Integration test for GameManager.new_game().
## Verifies the starter state is correct: roster, squad, gold, stash.

const STARTING_GOLD_DEFAULT := 100  ## Sanity check fallback if Constants is unreachable


func before_each() -> void:
	# Reset to a known state. Each test gets a fresh game.
	GameManager.new_game()


func test_new_game_creates_party_with_three_starter_characters() -> void:
	assert_not_null(GameManager.party, "Party should exist after new_game")
	assert_eq(GameManager.party.roster.size(), 3, "Should have 3 starter characters")
	for expected_id in ["warrior", "mage", "rogue"]:
		assert_true(GameManager.party.roster.has(expected_id),
			"Roster missing expected character: %s" % expected_id)


func test_new_game_auto_adds_characters_to_squad() -> void:
	assert_eq(GameManager.party.squad.size(), 3,
		"Squad should auto-include all 3 starter characters")


func test_new_game_grants_starting_gold() -> void:
	assert_gt(GameManager.gold, 0, "Starting gold should be positive")


func test_new_game_populates_stash_with_starter_items() -> void:
	assert_gt(GameManager.party.stash.size(), 0,
		"Stash should contain starter items after new_game")


func test_new_game_creates_grid_inventory_per_character() -> void:
	for character_id in GameManager.party.roster.keys():
		assert_true(GameManager.party.grid_inventories.has(character_id),
			"Missing grid_inventory for character: %s" % character_id)
		var inv: GridInventory = GameManager.party.grid_inventories[character_id]
		assert_not_null(inv, "Grid inventory should not be null for %s" % character_id)


func test_new_game_marks_game_started() -> void:
	assert_true(GameManager.is_game_started, "is_game_started should be true after new_game")
