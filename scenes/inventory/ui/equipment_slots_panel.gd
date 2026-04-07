extends PanelContainer
## Displays equipment slot indicators using Runewood slot sprites.
## Layout: 2-column (Weapons + Armor on left, Jewelry + Rings on right).

const _SlotTex := preload("res://assets/sprites/ui/theme/slot.png")

var _current_inventory: GridInventory = null
@onready var _root: VBoxContainer = $VBox


func setup(inventory: GridInventory) -> void:
	_current_inventory = inventory
	refresh()


func refresh() -> void:
	if not _current_inventory or not _root:
		return

	# Clear previous content (keep title + separator)
	for child in _root.get_children():
		if child.name in ["Title", "HSeparator"]:
			continue
		child.queue_free()

	var equipped_armor: Dictionary = _current_inventory.get_equipped_armor_slots()
	var used_hands: int = _current_inventory.get_used_hand_slots()
	var available_hands: int = _current_inventory.get_available_hand_slots()

	# Two-column layout
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 12)
	columns.alignment = BoxContainer.ALIGNMENT_CENTER
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root.add_child(columns)

	# === LEFT COLUMN: Weapons + Armor ===
	var left_col := VBoxContainer.new()
	left_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left_col.add_theme_constant_override("separation", 8)
	columns.add_child(left_col)

	_add_section_label(left_col, "WEAPONS")
	var weapons_row := HBoxContainer.new()
	weapons_row.alignment = BoxContainer.ALIGNMENT_CENTER
	weapons_row.add_theme_constant_override("separation", 6)
	for i in range(available_hands):
		weapons_row.add_child(_make_slot_icon(i < used_hands, 36))
	left_col.add_child(weapons_row)

	left_col.add_child(HSeparator.new())

	_add_section_label(left_col, "ARMOR")
	_add_slot_with_label(left_col, "Helmet", equipped_armor.has(Enums.EquipmentCategory.HELMET))

	var chest_gloves_row := HBoxContainer.new()
	chest_gloves_row.alignment = BoxContainer.ALIGNMENT_CENTER
	chest_gloves_row.add_theme_constant_override("separation", 16)
	chest_gloves_row.add_child(_make_labeled_slot("Chest", equipped_armor.has(Enums.EquipmentCategory.CHESTPLATE)))
	chest_gloves_row.add_child(_make_labeled_slot("Gloves", equipped_armor.has(Enums.EquipmentCategory.GLOVES)))
	left_col.add_child(chest_gloves_row)

	_add_slot_with_label(left_col, "Legs", equipped_armor.has(Enums.EquipmentCategory.LEGS))
	_add_slot_with_label(left_col, "Boots", equipped_armor.has(Enums.EquipmentCategory.BOOTS))

	# === RIGHT COLUMN: Jewelry + Rings ===
	var right_col := VBoxContainer.new()
	right_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_col.add_theme_constant_override("separation", 6)
	columns.add_child(right_col)

	_add_section_label(right_col, "JEWELRY")
	_add_slot_with_label(right_col, "Necklace", equipped_armor.has(Enums.EquipmentCategory.NECKLACE))

	right_col.add_child(HSeparator.new())

	# Count equipped rings
	var ring_count: int = 0
	for pi_idx in range(_current_inventory.placed_items.size()):
		var placed: GridInventory.PlacedItem = _current_inventory.placed_items[pi_idx]
		if placed.item_data.item_type == Enums.ItemType.PASSIVE_GEAR and placed.item_data.armor_slot == Enums.EquipmentCategory.RING:
			ring_count += 1

	var rings_label := Label.new()
	rings_label.text = "Rings"
	rings_label.add_theme_font_size_override("font_size", 12)
	rings_label.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	rings_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_col.add_child(rings_label)

	var ring_columns := HBoxContainer.new()
	ring_columns.alignment = BoxContainer.ALIGNMENT_CENTER
	ring_columns.add_theme_constant_override("separation", 12)
	right_col.add_child(ring_columns)

	# Left rings (5)
	var left_rings := VBoxContainer.new()
	left_rings.add_theme_constant_override("separation", 4)
	left_rings.alignment = BoxContainer.ALIGNMENT_CENTER
	var l_label := Label.new()
	l_label.text = "Left"
	l_label.add_theme_font_size_override("font_size", 11)
	l_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	l_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	left_rings.add_child(l_label)
	for i in range(5):
		left_rings.add_child(_make_slot_icon(i < ring_count, 22))
	ring_columns.add_child(left_rings)

	# Right rings (5)
	var right_rings := VBoxContainer.new()
	right_rings.add_theme_constant_override("separation", 4)
	right_rings.alignment = BoxContainer.ALIGNMENT_CENTER
	var r_label := Label.new()
	r_label.text = "Right"
	r_label.add_theme_font_size_override("font_size", 11)
	r_label.add_theme_color_override("font_color", Color(0.5, 0.45, 0.4))
	r_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	right_rings.add_child(r_label)
	for i in range(5):
		right_rings.add_child(_make_slot_icon((i + 5) < ring_count, 22))
	ring_columns.add_child(right_rings)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 13)
	lbl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.58))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(lbl)


func _add_slot_with_label(parent: VBoxContainer, slot_name: String, filled: bool) -> void:
	parent.add_child(_make_labeled_slot(slot_name, filled))


func _make_labeled_slot(slot_name: String, filled: bool) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 2)
	var lbl := Label.new()
	lbl.text = slot_name
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(0.55, 0.5, 0.45))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(lbl)
	var center := CenterContainer.new()
	center.add_child(_make_slot_icon(filled, 36))
	box.add_child(center)
	return box


func _make_slot_icon(filled: bool, icon_size: int = 28) -> TextureRect:
	var tex_rect := TextureRect.new()
	tex_rect.texture = _SlotTex
	tex_rect.custom_minimum_size = Vector2(icon_size, icon_size)
	tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if filled:
		tex_rect.modulate = Color(1.4, 1.2, 0.6, 1.0)
	else:
		tex_rect.modulate = Color(0.55, 0.5, 0.45, 0.7)
	return tex_rect
