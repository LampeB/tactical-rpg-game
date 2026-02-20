extends PanelContainer
## Displays equipment slot indicators (hands, armor, jewelry).

@onready var _hands_container: HBoxContainer = $VBox/HandsRow/HandSlots
@onready var _helmet_indicator: Control = $VBox/ArmorRow/HelmetSlot
@onready var _chest_indicator: Control = $VBox/ArmorRow/ChestSlot
@onready var _gloves_indicator: Control = $VBox/ArmorRow/GlovesSlot
@onready var _legs_indicator: Control = $VBox/ArmorRow/LegsSlot
@onready var _boots_indicator: Control = $VBox/ArmorRow/BootsSlot
@onready var _necklace_indicator: Control = $VBox/JewelryRow/NecklaceSlot
@onready var _rings_container: HBoxContainer = $VBox/JewelryRow/RingSlots

var _current_inventory: GridInventory = null


func setup(inventory: GridInventory) -> void:
	_current_inventory = inventory
	refresh()


func refresh() -> void:
	if not _current_inventory:
		return

	_update_hand_slots()
	_update_armor_slots()
	_update_jewelry_slots()


func _update_hand_slots() -> void:
	var available := _current_inventory.get_available_hand_slots()
	var used := _current_inventory.get_used_hand_slots()

	# Clear existing dots
	for child in _hands_container.get_children():
		child.queue_free()

	# Create dots for all available slots
	for i in range(available):
		var dot := ColorRect.new()
		dot.custom_minimum_size = Vector2(16, 16)
		dot.color = Color(0.8, 0.8, 0.8) if i < used else Color(0.3, 0.3, 0.3)
		_hands_container.add_child(dot)


func _update_armor_slots() -> void:
	var equipped_armor := _current_inventory.get_equipped_armor_slots()

	_set_slot_filled(_helmet_indicator, equipped_armor.has(Enums.EquipmentCategory.HELMET))
	_set_slot_filled(_chest_indicator, equipped_armor.has(Enums.EquipmentCategory.CHESTPLATE))
	_set_slot_filled(_gloves_indicator, equipped_armor.has(Enums.EquipmentCategory.GLOVES))
	_set_slot_filled(_legs_indicator, equipped_armor.has(Enums.EquipmentCategory.LEGS))
	_set_slot_filled(_boots_indicator, equipped_armor.has(Enums.EquipmentCategory.BOOTS))


func _update_jewelry_slots() -> void:
	var equipped_armor := _current_inventory.get_equipped_armor_slots()

	# Necklace
	_set_slot_filled(_necklace_indicator, equipped_armor.has(Enums.EquipmentCategory.NECKLACE))

	# Rings - count how many are equipped
	var ring_count := 0
	for i in range(_current_inventory.placed_items.size()):
		var placed: GridInventory.PlacedItem = _current_inventory.placed_items[i]
		if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR and placed.item_data.armor_slot == Enums.EquipmentCategory.RING:
			ring_count += 1

	# Clear existing ring slots
	for child in _rings_container.get_children():
		child.queue_free()

	# Create 10 ring slot indicators
	for i in range(10):
		var ring_slot := ColorRect.new()
		ring_slot.custom_minimum_size = Vector2(12, 12)
		ring_slot.color = Color(0.8, 0.6, 0.2) if i < ring_count else Color(0.3, 0.3, 0.3)
		_rings_container.add_child(ring_slot)


func _set_slot_filled(slot: Control, filled: bool) -> void:
	if slot is ColorRect:
		slot.color = Color(0.2, 0.8, 0.3) if filled else Color(0.3, 0.3, 0.3)
