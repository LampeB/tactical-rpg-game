extends PanelContainer
## Displays equipment slot indicators (hands, armor, jewelry).

@onready var _hands_container: HBoxContainer = $VBox/Columns/LeftColumn/WeaponsSection/HandSlots
@onready var _helmet_indicator: Control = $VBox/Columns/LeftColumn/ArmorSection/HelmetBox/HelmetCenter/HelmetSlot
@onready var _chest_indicator: Control = $VBox/Columns/LeftColumn/ArmorSection/ChestGlovesRow/ChestBox/ChestCenter/ChestSlot
@onready var _gloves_indicator: Control = $VBox/Columns/LeftColumn/ArmorSection/ChestGlovesRow/GlovesBox/GlovesCenter/GlovesSlot
@onready var _legs_indicator: Control = $VBox/Columns/LeftColumn/ArmorSection/LegsBox/LegsCenter/LegsSlot
@onready var _boots_indicator: Control = $VBox/Columns/LeftColumn/ArmorSection/BootsBox/BootsCenter/BootsSlot
@onready var _necklace_indicator: Control = $VBox/Columns/RightColumn/JewelrySection/NecklaceBox/NecklaceCenter/NecklaceSlot
@onready var _left_rings_container: VBoxContainer = $VBox/Columns/RightColumn/JewelrySection/LeftRingSlots
@onready var _right_rings_container: VBoxContainer = $VBox/Columns/RightColumn/JewelrySection/RightRingSlots

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

	# Create circular dots for all available slots
	for i in range(available):
		var dot_container := Control.new()
		dot_container.custom_minimum_size = Vector2(24, 24)

		var dot := Panel.new()
		dot.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		# Make it circular using a StyleBoxFlat
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.8, 0.8, 0.8) if i < used else Color(0.3, 0.3, 0.3)
		style.corner_radius_top_left = 12
		style.corner_radius_top_right = 12
		style.corner_radius_bottom_left = 12
		style.corner_radius_bottom_right = 12
		dot.add_theme_stylebox_override("panel", style)

		dot_container.add_child(dot)
		_hands_container.add_child(dot_container)


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
	for child in _left_rings_container.get_children():
		child.queue_free()
	for child in _right_rings_container.get_children():
		child.queue_free()

	# Create 5 ring slots per hand (left and right)
	for hand in range(2):
		var container: VBoxContainer = _left_rings_container if hand == 0 else _right_rings_container
		var start_idx: int = hand * 5

		for i in range(5):
			var ring_container := CenterContainer.new()
			ring_container.custom_minimum_size = Vector2(0, 16)

			var ring_slot := Panel.new()
			ring_slot.custom_minimum_size = Vector2(14, 14)
			# Make it circular
			var style := StyleBoxFlat.new()
			# Color filled rings based on total count (first N rings are filled)
			var global_idx: int = start_idx + i
			style.bg_color = Color(0.8, 0.6, 0.2) if global_idx < ring_count else Color(0.3, 0.3, 0.3)
			style.corner_radius_top_left = 7
			style.corner_radius_top_right = 7
			style.corner_radius_bottom_left = 7
			style.corner_radius_bottom_right = 7
			ring_slot.add_theme_stylebox_override("panel", style)

			ring_container.add_child(ring_slot)
			container.add_child(ring_container)


func _set_slot_filled(slot: Control, filled: bool) -> void:
	if slot is Panel:
		# Update the panel's background color
		var style: StyleBoxFlat = slot.get_theme_stylebox("panel")
		if style:
			# Create new style to avoid modifying shared resource
			var new_style := StyleBoxFlat.new()
			new_style.bg_color = Color(0.2, 0.8, 0.3) if filled else Color(0.3, 0.3, 0.3)

			# Necklace is circular (radius 19), armor slots are square (radius 6)
			var radius: int = 19 if slot == _necklace_indicator else 6
			new_style.corner_radius_top_left = radius
			new_style.corner_radius_top_right = radius
			new_style.corner_radius_bottom_left = radius
			new_style.corner_radius_bottom_right = radius
			slot.add_theme_stylebox_override("panel", new_style)
	elif slot is ColorRect:
		slot.color = Color(0.2, 0.8, 0.3) if filled else Color(0.3, 0.3, 0.3)
