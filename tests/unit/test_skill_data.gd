extends GutTest
## Unit tests for SkillData.
## Pure data resource — only one method (has_damage) but its outcome
## drives a lot of combat branching, so it's worth pinning.


func _make_skill(phys: float = 0.0, mag: float = 0.0, use_all: bool = false, mp_ratio: float = 0.0) -> SkillData:
	var s := SkillData.new()
	s.physical_scaling = phys
	s.magical_scaling = mag
	s.use_all_mp = use_all
	s.mp_damage_ratio = mp_ratio
	return s


func test_has_damage_true_when_physical_scaling_set() -> void:
	assert_true(_make_skill(1.5, 0.0).has_damage(),
		"Skill with physical_scaling > 0 should have damage")


func test_has_damage_true_when_magical_scaling_set() -> void:
	assert_true(_make_skill(0.0, 2.0).has_damage(),
		"Skill with magical_scaling > 0 should have damage")


func test_has_damage_true_when_both_scalings_set() -> void:
	assert_true(_make_skill(1.0, 1.0).has_damage())


func test_has_damage_false_when_no_scaling_and_no_mp_burn() -> void:
	# Pure heal / buff skills should report no damage
	assert_false(_make_skill(0.0, 0.0).has_damage(),
		"Skill with all-zero scaling and no use_all_mp should have no damage")


func test_has_damage_true_when_use_all_mp_with_ratio() -> void:
	# Mana burn skills: use_all_mp=true + mp_damage_ratio>0 → damage
	assert_true(_make_skill(0.0, 0.0, true, 0.5).has_damage(),
		"use_all_mp=true with positive mp_damage_ratio should have damage")


func test_has_damage_false_when_use_all_mp_but_zero_ratio() -> void:
	# Edge case: use_all_mp=true but ratio=0 → not actually doing damage
	assert_false(_make_skill(0.0, 0.0, true, 0.0).has_damage(),
		"use_all_mp=true with mp_damage_ratio=0 should NOT count as damage")


func test_default_skill_has_no_damage() -> void:
	# Fresh SkillData with all defaults should not be a damage skill
	var s := SkillData.new()
	assert_false(s.has_damage(),
		"Fresh SkillData should default to no damage (heals/buffs are the default)")
