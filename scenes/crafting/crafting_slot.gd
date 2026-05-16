class_name CraftingSlot
extends PanelContainer
## Visual display for a single ingredient slot in the crafting UI.
## Shows a rarity badge header, item shape/icon display, and ingredient label.
## All DnD logic is handled by CraftingUI — this node only emits clicked().

signal clicked(slot_index: int)

const DISPLAY_SZ := 70   ## Canvas size for the shape+icon display (px)
const MAX_CELL   := 18   ## Maximum cell size before shrinking to fit DISPLAY_SZ

var slot_index: int = 0
var ingredient: CraftingIngredient = null
var assigned_item: ItemData = null

var _style: StyleBoxFlat = null
var _content: VBoxContainer = null
var _representative: ItemData = null


func setup(idx: int, ingr: CraftingIngredient) -> void:
	slot_index = idx
	ingredient  = ingr
	custom_minimum_size = Vector2(150, 170)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = DesignTokens.PAPER_2
	_style.corner_radius_top_left    = 6
	_style.corner_radius_top_right   = 6
	_style.corner_radius_bottom_left = 6
	_style.corner_radius_bottom_right = 6
	add_theme_stylebox_override("panel", _style)
	_set_border(Constants.get_rarity_color(ingredient.min_rarity), 2)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 10)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 6)
	margin.add_child(_content)

	_representative = _find_representative()
	_refresh()


func assign(item: ItemData) -> void:
	assigned_item = item
	_set_border(Constants.get_rarity_color(item.rarity), 2)
	_refresh()


func clear() -> void:
	assigned_item = null
	_set_border(Constants.get_rarity_color(ingredient.min_rarity), 2)
	_refresh()


func set_highlight(color: Color) -> void:
	_set_border(color, 3)


func clear_highlight() -> void:
	var rarity := assigned_item.rarity if assigned_item else ingredient.min_rarity
	_set_border(Constants.get_rarity_color(rarity), 2)


func _set_border(color: Color, width: int) -> void:
	if not _style:
		return
	_style.border_color        = color
	_style.border_width_left   = width
	_style.border_width_right  = width
	_style.border_width_top    = width
	_style.border_width_bottom = width


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(slot_index)


# ── Refresh display ──────────────────────────────────────────────────────────

func _refresh() -> void:
	if not _content:
		return
	for child in _content.get_children():
		child.free()

	_build_header_row()

	var display_item := assigned_item if assigned_item else _representative
	var alpha        := 1.0 if assigned_item else 0.25

	# Shape + icon display — expands to fill remaining vertical space
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(DISPLAY_SZ, DISPLAY_SZ)
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_child(center)

	if display_item and display_item.shape:
		center.add_child(_build_shape_display(display_item, alpha))
	elif display_item and display_item.icon:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(DISPLAY_SZ, DISPLAY_SZ)
		icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture             = display_item.icon
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate            = Color(1, 1, 1, alpha)
		center.add_child(icon)
	else:
		var ph := ColorRect.new()
		ph.custom_minimum_size = Vector2(DISPLAY_SZ, DISPLAY_SZ)
		ph.color = Color(DesignTokens.PAPER_3.r, DesignTokens.PAPER_3.g, DesignTokens.PAPER_3.b, alpha)
		center.add_child(ph)

	_build_footer_label()


func _build_header_row() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	_content.add_child(row)

	var slot_lbl := Label.new()
	UIThemes.set_font_size(slot_lbl, 9)
	slot_lbl.text = "SLOT"
	slot_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	row.add_child(slot_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	var rarity: int
	var pill_text: String
	if assigned_item:
		rarity = assigned_item.rarity
		var rname: String = Constants.RARITY_NAMES.get(rarity, "Common")
		pill_text = rname.left(3).to_upper()
	else:
		rarity = ingredient.min_rarity
		var rname: String = Constants.RARITY_NAMES.get(rarity, "Common")
		pill_text = rname.left(3).to_upper() + "+"

	row.add_child(_make_rarity_pill(pill_text, Constants.get_rarity_color(rarity)))


func _build_footer_label() -> void:
	var lbl := Label.new()
	UIThemes.set_font_size(lbl, 10)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if assigned_item:
		lbl.text = assigned_item.display_name
		lbl.add_theme_color_override("font_color", Constants.get_rarity_color(assigned_item.rarity))
	else:
		lbl.text = ingredient.item_family.replace("_", " ").capitalize()
		lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	_content.add_child(lbl)


func _make_rarity_pill(text: String, color: Color) -> PanelContainer:
	var pill := PanelContainer.new()
	var s := StyleBoxFlat.new()
	s.bg_color = Color(color.r, color.g, color.b, 0.15)
	s.border_color = color
	s.border_width_left   = 1
	s.border_width_right  = 1
	s.border_width_top    = 1
	s.border_width_bottom = 1
	s.corner_radius_top_left    = 3
	s.corner_radius_top_right   = 3
	s.corner_radius_bottom_left = 3
	s.corner_radius_bottom_right = 3
	s.content_margin_left   = 4
	s.content_margin_right  = 4
	s.content_margin_top    = 1
	s.content_margin_bottom = 1
	pill.add_theme_stylebox_override("panel", s)

	var lbl := Label.new()
	UIThemes.set_font_size(lbl, 8)
	lbl.text = text
	lbl.add_theme_color_override("font_color", color)
	pill.add_child(lbl)
	return pill


func _build_shape_display(item: ItemData, alpha: float) -> Control:
	var w         := item.shape.get_width()
	var h         := item.shape.get_height()
	@warning_ignore("integer_division")
	var cell_size := mini(MAX_CELL, DISPLAY_SZ / maxi(w, h))

	var container := Control.new()
	container.custom_minimum_size = Vector2(w * cell_size, h * cell_size)

	for cell in item.shape.cells:
		var rect := ColorRect.new()
		rect.position = Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
		rect.size     = Vector2(cell_size - 2, cell_size - 2)
		rect.color    = Color(DesignTokens.PAPER_3.r, DesignTokens.PAPER_3.g, DesignTokens.PAPER_3.b, alpha)
		container.add_child(rect)

	if item.icon:
		var tex := TextureRect.new()
		tex.position     = Vector2(1, 1)
		tex.size         = Vector2(w * cell_size - 2, h * cell_size - 2)
		tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex.texture      = item.icon
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.modulate     = Color(1, 1, 1, alpha)
		container.add_child(tex)

	return container


func _find_representative() -> ItemData:
	if not ingredient:
		return null
	for item in ItemDatabase.get_all_items():
		if item.id.begins_with(ingredient.item_family) and item.rarity == ingredient.min_rarity:
			return item
	for item in ItemDatabase.get_all_items():
		if item.id.begins_with(ingredient.item_family):
			return item
	return null
