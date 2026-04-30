extends GutTest
## Unit tests for GridInventory.
## Covers placement / removal / collision, hand-slot accounting, and the
## armor-slot uniqueness rules. Game-balance properties (modifier
## affect-radius, computed_stats) are integration territory — covered
## elsewhere or as the inventory refactor proceeds.


var _template: GridTemplate
var _inv: GridInventory


func before_each() -> void:
	_template = GridTemplate.new()
	_template.width = 6
	_template.height = 6
	# active_cells empty → all 36 cells usable
	_inv = GridInventory.new(_template)


# === place / remove round trip ===

func test_can_place_on_empty_grid() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	assert_true(_inv.can_place(sword, Vector2i(0, 0), 0),
		"Empty grid should accept a sword at (0, 0)")


func test_place_item_returns_placement() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	var placed: GridInventory.PlacedItem = _inv.place_item(sword, Vector2i(0, 0), 0)
	assert_not_null(placed, "place_item should return a PlacedItem on success")
	assert_eq(placed.item_data, sword)
	assert_eq(placed.grid_position, Vector2i(0, 0))


func test_place_item_appears_in_get_all_placed_items() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	_inv.place_item(sword, Vector2i(0, 0), 0)
	var items: Array = _inv.get_all_placed_items()
	assert_eq(items.size(), 1)
	assert_eq(items[0].item_data, sword)


func test_remove_item_clears_placement() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	var placed: GridInventory.PlacedItem = _inv.place_item(sword, Vector2i(0, 0), 0)
	_inv.remove_item(placed)
	assert_eq(_inv.get_all_placed_items().size(), 0,
		"After remove_item, placed_items should be empty")
	assert_true(_inv.can_place(sword, Vector2i(0, 0), 0),
		"Removed cells should free up for re-placement")


func test_clear_removes_everything() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	var dagger: ItemData = ItemDatabase.get_item("dagger_common")
	_inv.place_item(sword, Vector2i(0, 0), 0)
	_inv.place_item(dagger, Vector2i(3, 0), 0)
	_inv.clear()
	assert_eq(_inv.get_all_placed_items().size(), 0)


# === Collision detection ===

func test_cannot_place_on_occupied_cells() -> void:
	# Without skip_equipment_checks, a second sword may fail for either
	# collision OR hand-slot reasons. To isolate collision, use skip flag
	# and place two dagger_common (1x1). Daggers don't share cells.
	_inv.skip_equipment_checks = true
	var dagger: ItemData = ItemDatabase.get_item("dagger_common")
	_inv.place_item(dagger, Vector2i(0, 0), 0)
	assert_false(_inv.can_place(dagger, Vector2i(0, 0), 0),
		"Should not be able to place on top of an existing item")


func test_cannot_place_out_of_bounds() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	# 6×6 grid, sword is 1×2; placing it at (5, 5) extends to (5, 6) — out of bounds
	assert_false(_inv.can_place(sword, Vector2i(5, 5), 0),
		"Sword should not fit when its second cell exceeds grid height")


func test_get_item_at_returns_placed_item() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	_inv.place_item(sword, Vector2i(2, 1), 0)
	# sword_common is 1x2, occupies (2,1) and (2,2)
	var got: GridInventory.PlacedItem = _inv.get_item_at(Vector2i(2, 1))
	assert_not_null(got)
	assert_eq(got.item_data, sword)


# === Hand-slot accounting ===

func test_hand_slot_used_slots_starts_at_zero() -> void:
	assert_eq(_inv.get_used_hand_slots(), 0,
		"Empty inventory should have 0 used hand slots")


func test_one_handed_weapon_uses_one_hand_slot() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	# sword_common is 1H per the project's data
	assert_eq(sword.hand_slots_required, 1,
		"Test assumes sword_common is 1H — adjust if data changed")
	_inv.place_item(sword, Vector2i(0, 0), 0)
	assert_eq(_inv.get_used_hand_slots(), 1)


func test_two_handed_weapon_uses_two_hand_slots() -> void:
	var staff: ItemData = ItemDatabase.get_item("staff_common")
	# staff_common is 2H per the project's data
	assert_eq(staff.hand_slots_required, 2,
		"Test assumes staff_common is 2H — adjust if data changed")
	_inv.place_item(staff, Vector2i(0, 0), 0)
	assert_eq(_inv.get_used_hand_slots(), 2)


func test_cannot_place_third_one_handed_weapon() -> void:
	# Default 2 hand slots → 2× 1H weapons fits, third should fail.
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	var dagger: ItemData = ItemDatabase.get_item("dagger_common")
	# Place two weapons at non-overlapping cells
	assert_not_null(_inv.place_item(sword, Vector2i(0, 0), 0), "First sword should fit")
	assert_not_null(_inv.place_item(dagger, Vector2i(3, 0), 0), "Dagger should fit")
	var second_dagger: ItemData = ItemDatabase.get_item("dagger_common")
	assert_false(_inv.can_place(second_dagger, Vector2i(5, 0), 0),
		"Third 1H weapon should not fit (only 2 hand slots)")


# === Armor slot uniqueness ===

func test_cannot_place_two_helmets() -> void:
	var helmet: ItemData = ItemDatabase.get_item("cloth_helmet_common")
	if helmet == null:
		pending("cloth_helmet_common not in ItemDatabase; skipping")
		return
	_inv.place_item(helmet, Vector2i(0, 0), 0)
	assert_false(_inv.can_place(helmet, Vector2i(2, 0), 0),
		"Only one helmet allowed; second should be rejected")


# === skip_equipment_checks (loot grids) ===

func test_skip_equipment_checks_bypasses_slot_rules() -> void:
	# Loot grids use skip_equipment_checks to allow stacking of items
	# regardless of hand slots / armor slot uniqueness.
	_inv.skip_equipment_checks = true
	var helmet: ItemData = ItemDatabase.get_item("cloth_helmet_common")
	if helmet == null:
		pending("cloth_helmet_common not in ItemDatabase; skipping")
		return
	_inv.place_item(helmet, Vector2i(0, 0), 0)
	assert_true(_inv.can_place(helmet, Vector2i(2, 0), 0),
		"With skip_equipment_checks=true, second helmet should be allowed")
