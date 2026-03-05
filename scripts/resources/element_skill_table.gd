class_name ElementSkillTable
extends Resource
## Central table that maps element point thresholds to unlocked skills.
## Shared across all characters — the same thresholds apply to everyone.

@export var entries: Array[ElementSkillEntry] = []


func get_unlocked_skills(current_points: Dictionary) -> Array[SkillData]:
	var unlocked: Array[SkillData] = []
	for entry in entries:
		if _meets_requirements(current_points, entry.required_points):
			unlocked.append(entry.skill)
	return unlocked


func _meets_requirements(current: Dictionary, required: Dictionary) -> bool:
	for elem_key in required:
		var needed: int = required[elem_key]
		var have: int = current.get(elem_key, 0)
		if have < needed:
			return false
	return true
