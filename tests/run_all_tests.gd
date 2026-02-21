extends Node
## Master test runner - runs all test suites.

func _repeat_char(ch: String, count: int) -> String:
	var result := ""
	for i in range(count):
		result += ch
	return result

func _ready() -> void:
	var separator := _repeat_char("=", 60)
	var divider := _repeat_char("-", 60)

	print("\n" + separator)
	print(" TACTICAL RPG - AUTOMATED TEST SUITE")
	print(separator + "\n")

	# Run unit tests
	var unit_tests := preload("res://tests/test_hybrid_damage_system.gd").new()
	add_child(unit_tests)
	await get_tree().process_frame
	var unit_results := unit_tests.get_test_summary()
	unit_tests.queue_free()

	print("\n" + divider + "\n")

	# Run integration tests
	var integration_tests := preload("res://tests/test_integration_combat.gd").new()
	add_child(integration_tests)
	await get_tree().process_frame
	integration_tests.queue_free()

	print("\n" + separator)
	print(" FINAL SUMMARY")
	print(separator)
	print("Unit Tests:        %d passed, %d failed" % [unit_results.passed, unit_results.failed])
	print("Integration Tests: Check above")
	print(separator + "\n")

	# Exit after tests complete (useful for CI/CD)
	get_tree().quit()
