extends GutTest
## Tests for RandomEncounterGenerator.
## Verifies: count is within bounds, all enemies are valid EnemyData,
## missions with min==max produce exact count, encounter has all required fields.


func test_generates_within_min_max_range() -> void:
	for trial in range(20):
		var enc: EncounterData = RandomEncounterGenerator.generate(2, 4, "Test", 0)
		assert_not_null(enc, "Encounter should be generated")
		assert_between(enc.enemies.size(), 2, 4, "Enemy count out of range")


func test_min_equals_max_produces_exact_count() -> void:
	var enc: EncounterData = RandomEncounterGenerator.generate(3, 3, "Test", 0)
	assert_not_null(enc)
	assert_eq(enc.enemies.size(), 3, "Should always produce exactly 3 enemies")


func test_all_enemies_are_valid_enemydata() -> void:
	var enc: EncounterData = RandomEncounterGenerator.generate(1, 5, "Test", 0)
	assert_not_null(enc)
	for i in range(enc.enemies.size()):
		var enemy = enc.enemies[i]
		assert_true(enemy is EnemyData, "Entry %d is not EnemyData" % i)
		assert_ne(enemy.id, "", "Enemy at index %d has empty id" % i)


func test_encounter_has_display_name_and_bonus_gold() -> void:
	var enc: EncounterData = RandomEncounterGenerator.generate(1, 1, "Wolves at the Edge", 25)
	assert_not_null(enc)
	assert_eq(enc.display_name, "Wolves at the Edge")
	assert_eq(enc.bonus_gold, 25)
	assert_true(enc.can_flee, "can_flee should default true")


func test_invalid_range_clamps_to_one() -> void:
	# min=0 max=0 → at least 1 enemy
	var enc: EncounterData = RandomEncounterGenerator.generate(0, 0, "Test", 0)
	assert_not_null(enc)
	assert_gt(enc.enemies.size(), 0, "Should have at least 1 enemy even with min=0")
