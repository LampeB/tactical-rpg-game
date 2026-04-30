extends GutTest
## Integration tests for QuestManager accept → progress → complete flow.
##
## Uses the real `doctors_supplies` quest if present, otherwise falls back
## to whatever quest is registered first. State is reset via new_game().


var _quest: QuestData


func before_each() -> void:
	GameManager.new_game()
	_quest = QuestManager.get_quest("doctors_supplies")
	if _quest == null:
		var all: Array = QuestManager.get_all_quests()
		if not all.is_empty():
			_quest = all[0]


# === Accept ===

func test_accept_quest_marks_active() -> void:
	if _quest == null:
		pending("No quest registered to test against")
		return
	assert_false(QuestManager.is_quest_active(_quest.id),
		"Sanity: quest should not be active before accept")
	QuestManager.accept_quest(_quest.id)
	assert_true(QuestManager.is_quest_active(_quest.id),
		"Quest should be active after accept_quest")


func test_accept_quest_appears_in_active_list() -> void:
	if _quest == null:
		pending("No quest registered")
		return
	QuestManager.accept_quest(_quest.id)
	var active: Array = QuestManager.get_active_quests()
	var ids: Array = active.map(func(q: QuestData) -> String: return q.id)
	assert_true(_quest.id in ids, "Accepted quest should appear in active list")


func test_accept_unknown_quest_does_nothing() -> void:
	# Should not crash, should not add anything to active list
	var before: int = QuestManager.get_active_quests().size()
	QuestManager.accept_quest("nonexistent_xyz")
	var after: int = QuestManager.get_active_quests().size()
	assert_eq(before, after,
		"Accepting an unknown quest should not change active count")


func test_double_accept_is_idempotent() -> void:
	# Accepting the same quest twice should not duplicate state
	if _quest == null:
		pending("No quest registered")
		return
	QuestManager.accept_quest(_quest.id)
	var first_count: int = QuestManager.get_active_quests().size()
	QuestManager.accept_quest(_quest.id)
	var second_count: int = QuestManager.get_active_quests().size()
	assert_eq(first_count, second_count,
		"Double accept should not duplicate active entries")


# === Complete ===

func test_complete_unaccepted_quest_does_nothing() -> void:
	if _quest == null:
		pending("No quest registered")
		return
	QuestManager.complete_quest(_quest.id)
	assert_false(QuestManager.is_quest_completed(_quest.id),
		"Complete on unaccepted quest should not mark it completed")


func test_complete_with_unfinished_objectives_does_nothing() -> void:
	# Real quests usually have objectives, so completing right after accept
	# should fail (objectives are at progress 0).
	if _quest == null or _quest.objectives.is_empty():
		pending("No quest with objectives registered")
		return
	QuestManager.accept_quest(_quest.id)
	QuestManager.complete_quest(_quest.id)
	# Either complete is a no-op (preferred) or the test pends.
	# is_quest_completed should be false because objectives weren't done.
	assert_false(QuestManager.is_quest_completed(_quest.id),
		"Quest should NOT complete with unfinished objectives")


func test_complete_after_objectives_done_awards_gold() -> void:
	if _quest == null:
		pending("No quest registered")
		return
	if _quest.reward_gold <= 0:
		pending("Quest %s has no gold reward; can't test gold award" % _quest.id)
		return

	QuestManager.accept_quest(_quest.id)
	# Force-complete every objective by setting progress to its target
	for i in range(_quest.objectives.size()):
		var obj: QuestObjective = _quest.objectives[i]
		QuestManager.update_objective_progress(_quest.id, i, obj.target_count)

	var gold_before: int = GameManager.gold
	QuestManager.complete_quest(_quest.id)
	assert_true(QuestManager.is_quest_completed(_quest.id),
		"Quest with all objectives done should complete")
	assert_eq(GameManager.gold, gold_before + _quest.reward_gold,
		"Completing quest should add reward_gold to GameManager.gold")
