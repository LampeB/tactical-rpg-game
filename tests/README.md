# Hybrid Damage System Tests

Automated test suite for validating the damage system refactoring.

## 🎯 Test Types

### 1. **Unit Tests** (`test_hybrid_damage_system.gd`)
- Tests individual systems in isolation
- Fast, reliable, no dependencies
- Validates enums, classes, and pure functions

### 2. **Integration Tests** (`test_integration_combat.gd`)
- Tests systems working together
- Simulates combat scenarios
- Validates game logic flow

### 3. **UI Testing** (Future)
Godot supports UI testing through:
- **GUT addon** (Godot Unit Test) - full testing framework
- **Input simulation** - programmatic button clicks
- **Visual regression** - screenshot comparison

## 🚀 Running Tests

### Quick Start - Run All Tests
```bash
# From Godot Editor: Open and run test_all.tscn (F6)

# From Command Line (headless):
godot --headless tests/test_all.tscn
```

### Option 1: From Godot Editor
1. Open the project in Godot
2. Open `tests/test_all.tscn` (runs all suites)
3. Press F6 to run
4. Check the Output console for results

### Option 2: From Command Line
```bash
# Run all tests
godot --headless tests/test_all.tscn

# Run specific test suite
godot --headless --script tests/test_hybrid_damage_system.gd
godot --headless --script tests/test_integration_combat.gd
```

### Option 3: CI/CD Integration
```yaml
# GitHub Actions example
- name: Run Tests
  run: godot --headless tests/test_all.tscn
```

### Option 3: In Code
```gdscript
var test_suite = load("res://tests/test_hybrid_damage_system.gd").new()
test_suite.run_all_tests()
var results = test_suite.get_test_summary()
print("Passed: %d / %d" % [results.passed, results.total])
```

## 📊 Test Coverage

### Unit Tests (14 tests)
**Phase 1: Enums & Core Type System**
- ✅ WeaponType enum (MELEE, RANGED, MAGIC)
- ✅ DamageType simplified (PHYSICAL, MAGICAL)
- ✅ StatusEffectType enum (BURN, POISONED, CHILLED, SHOCKED)
- ✅ MAGICAL_DEFENSE renamed from SPECIAL_DEFENSE

**Phase 2: Hybrid Damage System**
- ✅ ItemData has magical_power field
- ✅ Weapon type classification (get_weapon_type)
- ✅ ToolModifierState new structure
- ✅ ConditionalModifierRule weapon types

**Phase 3: Status Effects**
- ✅ StatusEffect resource class
- ✅ Status effect data files

**Phase 4: Damage Calculation**
- ✅ Hybrid damage calculation
- ✅ Basic attacks use hybrid

**Phase 5: Integration**
- ✅ CombatEntity weapon power methods
- ✅ Gem magical damage stacking

### Integration Tests (5 tests)
- ✅ Combat entity creation from character data
- ✅ Hybrid damage in combat scenarios
- ✅ Gems add magical damage bonuses
- ✅ Status effects apply and tick
- ✅ Weapon types affect damage correctly

**Total: 19 automated tests**

## 📝 Expected Output

```
============================================================
 TACTICAL RPG - AUTOMATED TEST SUITE
============================================================

=== Hybrid Damage System Test Suite ===

[✓] WeaponType enum exists with 3 values
[✓] DamageType enum simplified to 2 values
[✓] StatusEffectType enum exists with 4 values
[✓] SPECIAL_DEFENSE renamed to MAGICAL_DEFENSE
[✓] ItemData has magical_power field
[✓] ItemData.get_weapon_type() classifies weapons correctly
[✓] ToolModifierState has new hybrid damage fields
[✓] ConditionalModifierRule has new weapon type structure
[✓] StatusEffect resource class exists
[✓] Status effect data files exist
[✓] Hybrid damage calculation works correctly
[✓] Basic attack uses hybrid damage for players
[✓] CombatEntity weapon power methods return correct values
[✓] Gem magical damage stacks correctly

=== Test Results ===
Passed: 14
Failed: 0
Total:  14

✅ All tests passed!

------------------------------------------------------------

=== Combat Integration Tests ===

[✓] Combat entity creates from character data
[✓] Hybrid damage calculation in combat scenario
[✓] Gems add magical damage to weapons
[✓] Status effects can be created and applied
[✓] Different weapon types calculate damage correctly

=== Test Results ===
Passed: 5
Failed: 0
Total:  5

✅ All integration tests passed!

============================================================
 FINAL SUMMARY
============================================================
Unit Tests:        14 passed, 0 failed
Integration Tests: 5 passed, 0 failed
============================================================
```

## ➕ Adding New Tests

To add new tests, create a new function following the pattern:

```gdscript
func test_your_feature() -> void:
	var test_name := "Description of what is being tested"

	# Your test logic here
	if condition_fails:
		add_failure(test_name, "Reason for failure")
		return

	add_success(test_name)
```

Then add it to `run_all_tests()`.

## 🎮 UI Testing in Godot

While I can't run the tests myself, here's how **automated UI testing** works in game development:

### Approaches

**1. Unit Tests** (What we have)
- Test logic without UI
- Fast and reliable
- ✅ Created: 19 tests

**2. Integration Tests** (What we have)
- Simulate gameplay programmatically
- Test systems working together
- ✅ Created: Combat scenarios

**3. Input Simulation** (Future)
```gdscript
# Simulate button click
var button = $MainMenu/StartButton
button.emit_signal("pressed")

# Simulate mouse click at position
var event = InputEventMouseButton.new()
event.position = Vector2(100, 100)
event.pressed = true
Input.parse_input_event(event)
```

**4. Visual Regression** (Advanced)
```gdscript
# Take screenshot
var img = get_viewport().get_texture().get_image()
img.save_png("res://tests/screenshots/test_scene.png")

# Compare with baseline
# Use external tools or custom comparison
```

**5. GUT Addon** (Full Framework)
- Install: https://github.com/bitwes/Gut
- Provides test runner, assertions, mocks
- Industry standard for Godot testing

### Running Tests Automatically

**Local Development:**
```bash
# Watch mode (re-run on file changes)
while inotifywait -e modify scripts/**/*.gd; do
  godot --headless tests/test_all.tscn
done
```

**CI/CD (GitHub Actions):**
```yaml
name: Run Tests
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Setup Godot
        uses: chickensoft-games/setup-godot@v1
      - name: Run Tests
        run: godot --headless tests/test_all.tscn
```
