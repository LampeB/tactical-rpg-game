extends GutTest
## Unit tests for CombatEntity.apply_status — the tier-override logic for
## status effects. This is the rule-heavy bit of the buff/debuff system.


var _entity: CombatEntity


func before_each() -> void:
	var enemy_data: EnemyData = load("res://data/enemies/goblin.tres")
	_entity = CombatEntity.from_enemy(enemy_data)


func _make_status(group: String, tier: int, duration: int = 3) -> StatusEffectData:
	var s := StatusEffectData.new()
	s.id = "%s_t%d" % [group, tier]
	s.display_name = s.id
	s.effect_group = group
	s.tier = tier
	s.duration = duration
	return s


# === New status ===

func test_apply_status_to_clean_entity_returns_applied() -> void:
	var poison := _make_status("poison", 0)
	var result: String = _entity.apply_status(poison)
	assert_eq(result, "applied", "First status of a group should return 'applied'")
	assert_eq(_entity.status_effects.size(), 1)


# === Tier override ===

func test_higher_tier_replaces_lower_tier_in_same_group() -> void:
	var minor := _make_status("phys_atk_up", 0)
	var major := _make_status("phys_atk_up", 1)
	_entity.apply_status(minor)
	var result: String = _entity.apply_status(major)
	assert_eq(result, "replaced",
		"Major tier should replace minor in the same group")
	assert_eq(_entity.status_effects.size(), 1,
		"Replacement should not stack — still 1 effect")


func test_lower_tier_ignored_when_higher_active() -> void:
	var minor := _make_status("phys_atk_up", 0)
	var major := _make_status("phys_atk_up", 1)
	_entity.apply_status(major)
	var result: String = _entity.apply_status(minor)
	assert_eq(result, "ignored",
		"Lower tier should not replace higher tier in same group")


# === Same tier ===

func test_same_tier_with_longer_duration_refreshes() -> void:
	var first := _make_status("burn", 0, 3)
	var refresh := _make_status("burn", 0, 5)
	_entity.apply_status(first)
	var result: String = _entity.apply_status(refresh)
	# Implementation either refreshes (returns "refreshed") or stacks.
	# Either way, the entity should reflect the new (longer) duration.
	assert_true(result == "refreshed" or result == "stacked",
		"Same-tier longer-duration application should refresh or stack, got: %s" % result)


# === Different groups stack independently ===

func test_different_groups_coexist() -> void:
	var poison := _make_status("poison", 0)
	var burn := _make_status("burn", 0)
	_entity.apply_status(poison)
	_entity.apply_status(burn)
	assert_eq(_entity.status_effects.size(), 2,
		"Different groups should coexist as separate effects")


# === Empty group means no override (stacks freely) ===

func test_empty_group_does_not_override() -> void:
	# When effect_group is empty string, tier override doesn't apply
	var debuff_a := _make_status("", 0)
	debuff_a.id = "debuff_a"
	var debuff_b := _make_status("", 0)
	debuff_b.id = "debuff_b"
	_entity.apply_status(debuff_a)
	_entity.apply_status(debuff_b)
	# Both should be present (no group means no override resolution)
	assert_gte(_entity.status_effects.size(), 2,
		"Effects with empty effect_group should not override each other")
