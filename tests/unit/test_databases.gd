extends GutTest
## Unit tests for the data-source autoloads (Shop, Npc, Item, Character).
## All follow the same pattern: scan a directory of .tres on _ready, expose
## get/has/get_all API. Tests verify catalog loaded + lookup contracts.
##
## Crafting station data is per-station-loaded directly by crafting_ui (no
## autoload), so it's covered by the resource_integrity test instead.


# === ShopDatabase ===

func test_shop_database_has_at_least_one_shop() -> void:
	var shops: Array = ShopDatabase.get_all_shops()
	assert_gt(shops.size(), 0, "Expected at least one shop registered")


func test_shop_database_get_shop_for_known_id() -> void:
	var shop: ShopData = ShopDatabase.get_shop("merchant_general")
	if shop == null:
		pending("merchant_general not in ShopDatabase; skipping")
		return
	assert_eq(shop.id, "merchant_general")
	assert_ne(shop.display_name, "", "Shop should have a display_name")


func test_shop_database_unknown_returns_null() -> void:
	var shop: ShopData = ShopDatabase.get_shop("nonexistent_xyz")
	assert_null(shop)


func test_shop_database_has_shop_matches_lookup() -> void:
	var all_shops: Array = ShopDatabase.get_all_shops()
	if all_shops.is_empty():
		pending("No shops registered")
		return
	var first_id: String = all_shops[0].id
	assert_true(ShopDatabase.has_shop(first_id))
	assert_false(ShopDatabase.has_shop("nonexistent_xyz"))


# === NpcDatabase ===

func test_npc_database_has_npcs() -> void:
	var npcs: Array = NpcDatabase.get_all_npcs()
	assert_gt(npcs.size(), 0, "Expected at least one NPC registered")


func test_npc_database_known_id() -> void:
	# Project ships with merchant, blacksmith, doctor, weaver, hunter
	var merchant: NpcData = NpcDatabase.get_npc("merchant")
	if merchant == null:
		pending("merchant NPC not found; skipping")
		return
	assert_eq(merchant.id, "merchant")
	assert_ne(merchant.display_name, "")


func test_npc_database_unknown_returns_null() -> void:
	assert_null(NpcDatabase.get_npc("nonexistent_xyz"))


# === ItemDatabase ===

func test_item_database_has_items() -> void:
	var sword: ItemData = ItemDatabase.get_item("sword_common")
	assert_not_null(sword, "ItemDatabase should expose sword_common")
	assert_eq(sword.id, "sword_common")


func test_item_database_unknown_returns_null() -> void:
	# Use a clearly-fake id
	var item: ItemData = ItemDatabase.get_item("totally_fake_item_xyz")
	assert_null(item)


# === CharacterDatabase ===

func test_character_database_has_starter_classes() -> void:
	for char_id in ["warrior", "mage", "rogue"]:
		var c: CharacterData = CharacterDatabase.get_character(char_id)
		assert_not_null(c, "Starter character missing: %s" % char_id)
		assert_eq(c.id, char_id)


func test_character_database_unknown_returns_null() -> void:
	assert_null(CharacterDatabase.get_character("nonexistent_xyz"))


# === Cross-DB consistency: NPC role wiring ===

func test_shopkeeper_npcs_reference_existing_shops() -> void:
	# NPCs with role=SHOPKEEPER must reference a real shop_id.
	# Catches typos / renamed shop ids.
	for npc in NpcDatabase.get_all_npcs():
		if npc.role == Enums.NpcRole.SHOPKEEPER and npc.shop_id != "":
			assert_true(ShopDatabase.has_shop(npc.shop_id),
				"NPC '%s' references unknown shop_id '%s'" % [npc.id, npc.shop_id])
