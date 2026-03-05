class_name ElementSkillSystem
## Static utility for element-based skill unlocking.
## Lazy-loads the central ElementSkillTable and provides skill lookups.

static var _table: ElementSkillTable = null


static func get_table() -> ElementSkillTable:
	if _table == null:
		_table = load("res://data/element_skill_table.tres") as ElementSkillTable
	return _table


static func get_unlocked_skills(element_points: Dictionary) -> Array[SkillData]:
	var table: ElementSkillTable = get_table()
	if table == null:
		return []
	return table.get_unlocked_skills(element_points)
