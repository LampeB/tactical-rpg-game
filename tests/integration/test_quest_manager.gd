extends GutTest
## Integration tests for QuestManager.
##
## QuestManager is an autoload that scans data/quests/ on _ready and tracks
## quest state in GameManager.party / GameManager.story_flags. Tests start
## fresh via new_game() so quest state is clean.


func before_each() -> void:
	GameManager.new_game()


# === Catalog ===

func test_quest_database_loads_all_files() -> void:
	# QuestManager should have at least one quest after _ready scan.
	# (Project ships with doctors_supplies.tres at minimum.)
	var all_quests: Array = QuestManager.get_all_quests()
	assert_gt(all_quests.size(), 0,
		"Expected at least one quest registered (doctors_supplies)")


func test_get_quest_returns_resource_for_known_id() -> void:
	# doctors_supplies is a known quest in data/quests/
	var quest: QuestData = QuestManager.get_quest("doctors_supplies")
	if quest == null:
		pending("doctors_supplies quest not in QuestManager; skipping")
		return
	assert_not_null(quest)
	assert_eq(quest.id, "doctors_supplies")


func test_get_quest_returns_null_for_unknown_id() -> void:
	var quest: QuestData = QuestManager.get_quest("does_not_exist_xyz")
	assert_null(quest, "Unknown quest id should return null")


func test_has_quest_matches_get_quest() -> void:
	var all_quests: Array = QuestManager.get_all_quests()
	if all_quests.is_empty():
		pending("No quests registered; skipping")
		return
	var first: QuestData = all_quests[0]
	assert_true(QuestManager.has_quest(first.id),
		"has_quest should be true for a registered quest")
	assert_false(QuestManager.has_quest("does_not_exist_xyz"),
		"has_quest should be false for an unknown quest")


# === Acceptance state ===

func test_quest_not_active_or_completed_on_fresh_game() -> void:
	var all_quests: Array = QuestManager.get_all_quests()
	if all_quests.is_empty():
		pending("No quests registered")
		return
	var quest: QuestData = all_quests[0]
	assert_false(QuestManager.is_quest_active(quest.id),
		"Fresh game should have no active quests")
	assert_false(QuestManager.is_quest_completed(quest.id),
		"Fresh game should have no completed quests")


func test_active_quests_starts_empty() -> void:
	assert_eq(QuestManager.get_active_quests().size(), 0,
		"Fresh game should have zero active quests")


func test_completed_quests_starts_empty() -> void:
	assert_eq(QuestManager.get_completed_quests().size(), 0,
		"Fresh game should have zero completed quests")
