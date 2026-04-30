extends GutTest
## Unit tests for LootGenerator.
##
## Two systems live here:
## - Independent drop chance (per-entry probability)
## - Weighted random rolls (legacy)
##
## Plus guaranteed_drops which always come through.
##
## We exercise drop_chance=1.0 / 0.0 and verify guaranteed drops to keep
## tests deterministic — RNG-affected probabilities are smoke-tested.


func _make_item(id: String, item_id: String = "") -> ItemData:
	# Try ItemDatabase first, otherwise build a minimal stub.
	var resolved_id: String = item_id if item_id != "" else id
	var existing: ItemData = ItemDatabase.get_item(resolved_id)
	if existing:
		return existing
	var item := ItemData.new()
	item.id = id
	item.display_name = id
	return item


func _make_table(entries: Array, guaranteed: Array = []) -> LootTable:
	var t := LootTable.new()
	t.entries.assign(entries)
	t.guaranteed_drops.assign(guaranteed)
	return t


func _make_entry(item: ItemData, drop_chance: float = 0.0, weight: float = 1.0) -> LootEntry:
	var e := LootEntry.new()
	e.item = item
	e.drop_chance = drop_chance
	e.weight = weight
	return e


# === guaranteed_drops always come through ===

func test_guaranteed_drops_appear() -> void:
	var sword: ItemData = _make_item("sword_common")
	var dagger: ItemData = _make_item("dagger_common")
	var table: LootTable = _make_table([], [sword, dagger])
	var loot: Array = LootGenerator.roll_table(table)
	assert_eq(loot.size(), 2, "Both guaranteed drops should appear")
	assert_true(sword in loot)
	assert_true(dagger in loot)


func test_empty_table_returns_empty_array() -> void:
	var table: LootTable = _make_table([])
	var loot: Array = LootGenerator.roll_table(table)
	assert_eq(loot.size(), 0)


# === drop_chance: deterministic edges ===

func test_drop_chance_one_always_drops() -> void:
	var item: ItemData = _make_item("sword_common")
	var table: LootTable = _make_table([_make_entry(item, 1.0)])
	for trial in range(20):
		var loot: Array = LootGenerator.roll_table(table)
		assert_true(item in loot, "drop_chance=1.0 should drop every roll (trial %d)" % trial)


func test_drop_chance_zero_uses_weighted_path() -> void:
	# When all entries have drop_chance=0, the weighted path is used.
	# weight=1.0 + roll_count=1 → guaranteed to pick the only entry.
	var item: ItemData = _make_item("sword_common")
	var table: LootTable = _make_table([_make_entry(item, 0.0, 1.0)])
	table.roll_count = 1
	var loot: Array = LootGenerator.roll_table(table)
	assert_eq(loot.size(), 1, "Single-entry weighted table should drop exactly 1 item")
	assert_eq(loot[0], item)


# === Mixed: drop_chance + guaranteed ===

func test_guaranteed_plus_drop_chance_one_returns_both() -> void:
	var sword: ItemData = _make_item("sword_common")
	var dagger: ItemData = _make_item("dagger_common")
	var table: LootTable = _make_table([_make_entry(dagger, 1.0)], [sword])
	var loot: Array = LootGenerator.roll_table(table)
	assert_true(sword in loot, "Guaranteed sword should be there")
	assert_true(dagger in loot, "drop_chance=1.0 dagger should be there")


# === entries with null item are skipped ===

func test_null_item_entry_is_skipped() -> void:
	var entry := LootEntry.new()
	entry.item = null
	entry.drop_chance = 1.0
	var table: LootTable = _make_table([entry])
	var loot: Array = LootGenerator.roll_table(table)
	assert_eq(loot.size(), 0, "Entry with null item should not produce drops")


# === generate_loot via override_loot_table ===

func test_generate_loot_uses_override_table_when_set() -> void:
	var item: ItemData = _make_item("sword_common")
	var table: LootTable = _make_table([_make_entry(item, 1.0)])
	var encounter := EncounterData.new()
	encounter.override_loot_table = table

	var loot: Array = LootGenerator.generate_loot(encounter, [])
	assert_true(item in loot,
		"generate_loot should pull from override_loot_table when set")
