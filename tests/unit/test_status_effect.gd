extends GutTest
## Unit tests for StatusEffect resource.
## Verifies create_instance() copies all fields and produces a fresh instance,
## so applying a template to multiple targets doesn't share mutable state.


func _make_template() -> StatusEffect:
	var t := StatusEffect.new()
	t.effect_type = Enums.StatusEffectType.BURN
	t.duration_turns = 5
	t.tick_damage = 7
	t.max_tick_damage = 21
	t.skip_turn_chance = 0.25
	# stat_modifier left null intentionally; covered separately
	return t


func test_create_instance_copies_all_scalar_fields() -> void:
	var template: StatusEffect = _make_template()
	var copy: StatusEffect = template.create_instance()
	assert_eq(copy.effect_type, template.effect_type, "effect_type should match")
	assert_eq(copy.duration_turns, template.duration_turns, "duration_turns should match")
	assert_eq(copy.tick_damage, template.tick_damage, "tick_damage should match")
	assert_eq(copy.max_tick_damage, template.max_tick_damage, "max_tick_damage should match")
	assert_eq(copy.skip_turn_chance, template.skip_turn_chance, "skip_turn_chance should match")


func test_create_instance_returns_distinct_object() -> void:
	var template: StatusEffect = _make_template()
	var copy: StatusEffect = template.create_instance()
	# Mutating the copy must not mutate the template
	copy.duration_turns = 999
	assert_ne(template.duration_turns, copy.duration_turns,
		"Mutating instance should not affect template (need different objects)")


func test_create_instance_preserves_stat_modifier_reference() -> void:
	# stat_modifier is shared by reference, not deep-copied.
	# Document the intent: chilled effects share a single StatModifier resource.
	var template: StatusEffect = _make_template()
	var mod := StatModifier.new()
	template.stat_modifier = mod
	var copy: StatusEffect = template.create_instance()
	assert_eq(copy.stat_modifier, template.stat_modifier,
		"stat_modifier reference should pass through (shared resource)")


func test_default_values_are_safe() -> void:
	# Fresh StatusEffect with no exports set should have defaults that don't crash
	# the combat loop (e.g., 0 tick damage, 0 skip chance, finite duration).
	var fresh := StatusEffect.new()
	assert_gt(fresh.duration_turns, 0, "duration_turns default should be positive")
	assert_eq(fresh.tick_damage, 0, "tick_damage default should be 0")
	assert_eq(fresh.skip_turn_chance, 0.0, "skip_turn_chance default should be 0")
