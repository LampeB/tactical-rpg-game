extends GutTest
## Unit tests for DamageCalculator.
##
## - calculate_healing: pure function, tested exhaustively
## - calculate_damage / calculate_basic_attack: smoke-tested with built entities
##   to verify the minimum-damage clamp and no-crash on edge cases. The damage
##   formula itself isn't pinned down to specific numbers because crit is
##   stochastic; we test invariants instead.


# === calculate_healing — pure math ===

func test_healing_flat_only() -> void:
	assert_eq(DamageCalculator.calculate_healing(50, 0.0, 100), 50)


func test_healing_percent_only() -> void:
	assert_eq(DamageCalculator.calculate_healing(0, 0.5, 100), 50)


func test_healing_flat_plus_percent() -> void:
	assert_eq(DamageCalculator.calculate_healing(10, 0.5, 100), 60)


func test_healing_clamps_to_zero_when_negative() -> void:
	assert_eq(DamageCalculator.calculate_healing(-50, 0.0, 100), 0,
		"Negative heal amount should clamp to 0 (no damage from heal)")


func test_healing_zero_max_hp_works() -> void:
	# Edge case: dead entity with max_hp=0 shouldn't crash
	assert_eq(DamageCalculator.calculate_healing(25, 0.5, 0), 25,
		"Healing should still apply flat amount when max_hp is 0")


# === calculate_damage — smoke tests with real entities ===
# We assert invariants, not exact damage numbers, because crit is stochastic.

func _make_player_entity() -> CombatEntity:
	GameManager.new_game()
	var char_id: String = "warrior"
	var char_data: CharacterData = GameManager.party.roster[char_id]
	var inv: GridInventory = GameManager.party.grid_inventories[char_id]
	return CombatEntity.from_character(char_data, inv, {})


func _make_enemy_entity(enemy_id: String = "goblin") -> CombatEntity:
	var enemy: EnemyData = load("res://data/enemies/%s.tres" % enemy_id)
	return CombatEntity.from_enemy(enemy)


func test_basic_attack_returns_dict_with_required_keys() -> void:
	var src: CombatEntity = _make_player_entity()
	var tgt: CombatEntity = _make_enemy_entity()
	var result: Dictionary = DamageCalculator.calculate_basic_attack(src, tgt)
	for key in ["amount", "is_crit", "defended", "damage_type", "phys_amount", "mag_amount"]:
		assert_true(result.has(key), "Missing key in damage result: %s" % key)


func test_damage_is_at_least_one() -> void:
	# Even with zero scaling, the formula clamps to a 1-damage minimum.
	var src: CombatEntity = _make_player_entity()
	var tgt: CombatEntity = _make_enemy_entity()
	var result: Dictionary = DamageCalculator.calculate_damage(src, tgt, 0.0, 0.0)
	assert_gte(result.amount, 1, "Damage should never be below 1 (minimum-damage clamp)")


func test_damage_components_split_to_phys_and_mag() -> void:
	# phys_amount + mag_amount should approximately equal the dominant total
	# (after defense + status mults). Exact equality may not hold if crit fires,
	# so we just verify both components are non-negative.
	var src: CombatEntity = _make_player_entity()
	var tgt: CombatEntity = _make_enemy_entity()
	var result: Dictionary = DamageCalculator.calculate_damage(src, tgt, 1.0, 1.0)
	assert_gte(result.phys_amount, 0, "phys_amount should be non-negative")
	assert_gte(result.mag_amount, 0, "mag_amount should be non-negative")


func test_skill_damage_uses_skill_scaling() -> void:
	var src: CombatEntity = _make_player_entity()
	var tgt: CombatEntity = _make_enemy_entity()
	var skill := SkillData.new()
	skill.physical_scaling = 2.0
	skill.magical_scaling = 0.0
	var skill_result: Dictionary = DamageCalculator.calculate_skill_damage(src, tgt, skill)
	assert_gte(skill_result.amount, 1, "Skill damage should respect minimum-damage clamp")


func test_basic_attack_for_player_uses_full_scaling() -> void:
	# Player basic attack uses 1.0 phys + 1.0 mag scaling.
	# Enemy basic attack uses single damage type by enemy_data.damage_type.
	var src: CombatEntity = _make_player_entity()
	var tgt: CombatEntity = _make_enemy_entity()
	var direct: Dictionary = DamageCalculator.calculate_damage(src, tgt, 1.0, 1.0)
	var basic: Dictionary = DamageCalculator.calculate_basic_attack(src, tgt)
	# Both go through the same pipeline; structure should match.
	assert_eq(direct.keys().size(), basic.keys().size(),
		"basic_attack and calculate_damage(1,1) should return dicts with the same keys")
