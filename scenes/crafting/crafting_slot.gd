class_name CraftingSlot
extends PanelContainer
## Visual display for a single ingredient slot in the crafting UI.
## Shows the item's shape grid with the icon overlaid on top.
## All DnD logic is handled by CraftingUI — this node only emits clicked().

signal clicked(slot_index: int)

const DISPLAY_SZ := 50   ## Canvas size for the shape+icon display (px)
const MAX_CELL   := 14   ## Maximum cell size before shrinking to fit DISPLAY_SZ

var slot_index: int = 0
var ingredient: CraftingIngredient = null
var assigned_item: ItemData = null

var _style: StyleBoxFlat = null
var _content: VBoxContainer = null
var _representative: ItemData = null   ## example item used in empty-state display


func setup(idx: int, ingr: CraftingIngredient) -> void:
	slot_index = idx
	ingredient  = ingr
	custom_minimum_size = Vector2(66, 100)
	mouse_filter = Control.MOUSE_FILTER_STOP

	_style = StyleBoxFlat.new()
	_style.bg_color = Color(0.10, 0.12, 0.17)
	_style.corner_radius_top_left    = 5
	_style.corner_radius_top_right   = 5
	_style.corner_radius_bottom_left = 5
	_style.corner_radius_bottom_right = 5
	add_theme_stylebox_override("panel", _style)
	var setup_border_col: Color = Constants.RARITY_COLORS.get(ingredient.min_rarity, Color.WHITE)
	_set_border(setup_border_col, 2)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left",   6)
	margin.add_theme_constant_override("margin_right",  6)
	margin.add_theme_constant_override("margin_top",    6)
	margin.add_theme_constant_override("margin_bottom", 6)
	add_child(margin)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	_content.alignment = BoxContainer.ALIGNMENT_CENTER
	margin.add_child(_content)

	_representative = _find_representative()
	_refresh()


func assign(item: ItemData) -> void:
	assigned_item = item
	var assign_border_col: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	_set_border(assign_border_col, 2)
	_refresh()


func clear() -> void:
	assigned_item = null
	var clear_border_col: Color = Constants.RARITY_COLORS.get(ingredient.min_rarity, Color.WHITE)
	_set_border(clear_border_col, 2)
	_refresh()


func set_highlight(color: Color) -> void:
	_set_border(color, 3)


func clear_highlight() -> void:
	var rarity := assigned_item.rarity if assigned_item else ingredient.min_rarity
	var col: Color = Constants.RARITY_COLORS.get(rarity, Color.WHITE)
	_set_border(col, 2)


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

	var display_item := assigned_item if assigned_item else _representative
	var alpha        := 1.0 if assigned_item else 0.28

	# Shape + icon display centered in DISPLAY_SZ × DISPLAY_SZ box
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(DISPLAY_SZ, DISPLAY_SZ)
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
		ph.color = Color(0.1, 0.1, 0.15)
		center.add_child(ph)

	# Name label
	var name_lbl := Label.new()
	name_lbl.add_theme_font_size_override("font_size", 10)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if assigned_item:
		name_lbl.text = assigned_item.display_name
		var name_col: Color = Constants.RARITY_COLORS.get(assigned_item.rarity, Color.WHITE)
		name_lbl.add_theme_color_override("font_color", name_col)
	else:
		name_lbl.text = ingredient.item_family.replace("_", " ").capitalize()
		name_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
	_content.add_child(name_lbl)

	# Rarity label
	var rarity_lbl := Label.new()
	rarity_lbl.add_theme_font_size_override("font_size", 9)
	rarity_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if assigned_item:
		var rarity_name: String = Constants.RARITY_NAMES.get(assigned_item.rarity, "Common")
		rarity_lbl.text = rarity_name
		var rarity_col: Color = Constants.RARITY_COLORS.get(assigned_item.rarity, Color.WHITE)
		rarity_lbl.add_theme_color_override("font_color", rarity_col)
	else:
		var rarity_name: String = Constants.RARITY_NAMES.get(ingredient.min_rarity, "Common")
		rarity_lbl.text = rarity_name + "+"
		var rarity_col: Color = Constants.RARITY_COLORS.get(ingredient.min_rarity, Color.WHITE)
		rarity_lbl.add_theme_color_override("font_color", rarity_col)
	_content.add_child(rarity_lbl)


## Builds a Control sized to the item's shape bounding box, with shape cells
## drawn as ColorRects and the icon overlaid on top.
func _build_shape_display(item: ItemData, alpha: float) -> Control:
	var w         := item.shape.get_width()
	var h         := item.shape.get_height()
	var cell_size := mini(MAX_CELL, DISPLAY_SZ / maxi(w, h))

	var container := Control.new()
	container.custom_minimum_size = Vector2(w * cell_size, h * cell_size)

	# Shape cells
	for cell in item.shape.cells:
		var rect := ColorRect.new()
		rect.position = Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
		rect.size     = Vector2(cell_size - 2, cell_size - 2)
		rect.color    = Color(0.28, 0.32, 0.42, alpha)
		container.add_child(rect)

	# Icon overlay — inset by 1px to match the cell border gaps
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
	# Prefer exact min_rarity match
	for item in ItemDatabase.get_all_items():
		if item.id.begins_with(ingredient.item_family) and item.rarity == ingredient.min_rarity:
			return item
	# Fallback: any matching family
	for item in ItemDatabase.get_all_items():
		if item.id.begins_with(ingredient.item_family):
			return item
	return null
