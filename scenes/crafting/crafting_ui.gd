extends Control
## Crafting station screen. Modelled after shop_ui.gd.
##
## LEFT SIDE (LeftHalf):
##   - Icon list (narrow 72 px column): one square icon card per recipe.
##     Blue border = selected, green = craftable, grey = missing ingredients.
##   - Craft detail (expanding): ingredient slots ([icon|shape] each),
##     result info ([icon|shape] + labels), Craft button, output zone.
##
## RIGHT SIDE (PlayerSide):
##   - Character tabs + grid panel + stash — drag items FROM here to ingredient slots.
##   - After crafting, drag the result FROM the output zone TO here.

enum DragState  { IDLE, DRAGGING }
enum DragSource { NONE, PLAYER_GRID, STASH, CRAFT_SLOT, CRAFT_OUTPUT }

const RESULT_SZ := 50   ## Canvas size for the shape+icon display in the result info row

@onready var _title_label: Label          = $VBox/TopBar/TitleLabel
@onready var _close_btn: Button           = $VBox/BottomBar/CloseButton
@onready var _icon_list: VBoxContainer    = $VBox/Content/LeftHalf/IconScroll/IconList
@onready var _craft_detail: VBoxContainer = $VBox/Content/LeftHalf/CraftScroll/CraftDetail
@onready var _character_tabs              = $VBox/Content/PlayerSide/CharacterTabs
@onready var _player_grid_panel           = $VBox/Content/PlayerSide/GridCentering/PlayerGridPanel
@onready var _stash_panel                 = $VBox/Content/RightPanel/StashPanel
@onready var _drag_preview                = $DragLayer/DragPreview
@onready var _item_tooltip                = $VBox/Content/RightPanel/ItemTooltip

var _station: CraftingStationData         = null
var _selected_recipe: CraftingRecipeData  = null

## Ingredient slots for the selected recipe
var _slot_nodes: Array[CraftingSlot] = []

## Tracks where each slot item came from so it can be returned on recipe change or close.
## Key = slot_index (int). Value = {source: DragSource, char_id, pos, rot} or {source: STASH}
var _slot_origins: Dictionary = {}

## Crafted item waiting to be dragged to inventory
var _output_item: ItemData  = null
var _output_zone: PanelContainer = null  # built in _select_recipe, persists until recipe changes

## Player inventory state
var _player_grid_inventories: Dictionary = {}
var _current_character_id: String = ""

## Drag state machine
var _drag_state:  DragState  = DragState.IDLE
var _dragged_item: ItemData  = null
var _drag_source: DragSource = DragSource.NONE
var _drag_rotation: int      = 0
var _drag_hover_pos: Vector2i = Vector2i(-1, -1)  ## Last grid cell hovered during drag
var _drag_source_player_pos: Vector2i = Vector2i.ZERO
var _drag_source_player_rot: int      = 0
var _drag_source_stash_index: int     = -1
var _drag_source_slot_index: int      = -1

# Discard confirmation
var _discard_dialog: ConfirmationDialog = null
var _pending_discard_item: ItemData = null
var _pending_discard_index: int = -1
var _pending_discard_is_dragged: bool = false


# ════════════════════════════════════════════════════════════════════════════
#  Setup
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_close_btn.pressed.connect(_on_close)

	_player_grid_panel.cell_clicked.connect(_on_player_cell_clicked)
	_player_grid_panel.cell_hovered.connect(_on_player_cell_hovered)
	_player_grid_panel.cell_exited.connect(_on_player_hover_exited)

	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(func(item: ItemData, pos: Vector2) -> void:
		var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
		_item_tooltip.show_for_item(item, null, inv, pos))
	_stash_panel.item_exited.connect(func() -> void: _item_tooltip.hide_tooltip())
	_stash_panel.item_discard_requested.connect(_on_stash_discard_requested)
	_stash_panel.set_label_prefix("Stash", false)

	_discard_dialog = ConfirmationDialog.new()
	_discard_dialog.title = "Discard Item"
	_discard_dialog.confirmed.connect(_on_discard_confirmed)
	add_child(_discard_dialog)

	if GameManager.party:
		_player_grid_inventories = GameManager.party.grid_inventories
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	_drag_preview.visible = false
	_item_tooltip.embedded = true
	_item_tooltip.show_empty_state()



func receive_data(data: Dictionary) -> void:
	var station_id: String = data.get("station_id", "")
	var path := "res://data/crafting/%s.tres" % station_id
	_station = load(path) as CraftingStationData
	if not _station:
		DebugLogger.log_warn("CraftingUI: station not found: %s" % path, "Crafting")
		SceneManager.pop_scene()
		return

	_title_label.text = _station.display_name
	_build_icon_list()
	_refresh_stash()

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])


# ════════════════════════════════════════════════════════════════════════════
#  Icon List (left narrow column)
# ════════════════════════════════════════════════════════════════════════════

func _build_icon_list() -> void:
	for child in _icon_list.get_children():
		child.queue_free()

	# Sort: craftable first, then not-craftable (truly locked recipes hidden)
	var craftable: Array = []
	var not_craftable: Array = []
	for r in _station.recipes:
		if not CraftingSystem.is_recipe_unlocked(r, GameManager.story_flags):
			continue
		if CraftingSystem.can_craft(r, GameManager.party):
			craftable.append(r)
		else:
			not_craftable.append(r)

	var first_card: PanelContainer = null
	for sorted_recipe in craftable + not_craftable:
		var card := _build_icon_card(sorted_recipe)
		_icon_list.add_child(card)
		if first_card == null:
			first_card = card

	# Restore selection or auto-select first unlocked recipe
	if first_card:
		var reselected := false
		if _selected_recipe:
			for card_node in _icon_list.get_children():
				if card_node.get_meta("recipe_id", "") == _selected_recipe.id:
					_select_recipe(_selected_recipe)
					reselected = true
					break
		if not reselected:
			var first_unlocked: CraftingRecipeData = null
			for avail_recipe in _station.recipes:
				if CraftingSystem.is_recipe_unlocked(avail_recipe, GameManager.story_flags):
					first_unlocked = avail_recipe
					break
			_select_recipe(first_unlocked)
	else:
		_clear_craft_detail()


func _build_icon_card(recipe: CraftingRecipeData) -> PanelContainer:
	var is_craftable := CraftingSystem.can_craft(recipe, GameManager.party)
	var is_selected  := _selected_recipe != null and _selected_recipe.id == recipe.id
	var result_item  := ItemDatabase.get_item(recipe.result_item_id)

	var card := PanelContainer.new()
	card.set_meta("recipe_id", recipe.id)
	card.custom_minimum_size = Vector2(0, 64)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	style.bg_color = Color(0.13, 0.16, 0.22)
	if is_selected:
		style.border_color        = Color(0.5, 0.7, 1.0)
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
	elif is_craftable:
		style.border_color        = Color(0.3, 0.8, 0.3)
		style.border_width_left   = 2
		style.border_width_right  = 2
		style.border_width_top    = 2
		style.border_width_bottom = 2
	else:
		style.border_color        = Color(0.25, 0.28, 0.35)
		style.border_width_left   = 1
		style.border_width_right  = 1
		style.border_width_top    = 1
		style.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", style)

	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(center)

	if result_item and result_item.icon:
		var icon := TextureRect.new()
		icon.texture = result_item.icon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.modulate = Color.WHITE if is_craftable else Color(0.45, 0.45, 0.45)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(icon)
	else:
		var ph := ColorRect.new()
		ph.custom_minimum_size = Vector2(48, 48)
		ph.color = Color(0.2, 0.2, 0.25)
		ph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		center.add_child(ph)

	# Craftability indicator badge (bottom-right corner)
	var indicator := Label.new()
	indicator.text = "✓" if is_craftable else "✗"
	UIThemes.set_font_size(indicator, 14)
	indicator.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if is_craftable else Color(0.7, 0.3, 0.3))
	indicator.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	indicator.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	indicator.anchors_preset = Control.PRESET_BOTTOM_RIGHT
	indicator.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	indicator.grow_vertical = Control.GROW_DIRECTION_BEGIN
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(indicator)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_recipe(recipe)
	)
	return card


## Rebuild icon card styles without rebuilding the whole list (avoids scroll position reset).
func _refresh_icon_list_styles() -> void:
	for child in _icon_list.get_children():
		if not child is PanelContainer:
			continue
		var recipe_id: String = child.get_meta("recipe_id", "")
		var is_selected := _selected_recipe != null and _selected_recipe.id == recipe_id
		var recipe: CraftingRecipeData = _find_recipe_by_id(recipe_id)
		var is_craftable := recipe != null and CraftingSystem.can_craft(recipe, GameManager.party)
		var style := child.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			continue
		if is_selected:
			style.bg_color            = Color(0.2, 0.25, 0.35)
			style.border_color        = Color(0.5, 0.7, 1.0)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
		elif is_craftable:
			style.bg_color            = Color(0.13, 0.16, 0.22)
			style.border_color        = Color(0.3, 0.8, 0.3)
			style.border_width_left   = 2
			style.border_width_right  = 2
			style.border_width_top    = 2
			style.border_width_bottom = 2
		else:
			style.bg_color            = Color(0.13, 0.16, 0.22)
			style.border_color        = Color(0.25, 0.28, 0.35)
			style.border_width_left   = 1
			style.border_width_right  = 1
			style.border_width_top    = 1
			style.border_width_bottom = 1
		# Update indicator badge and icon dimming
		for sub in child.get_children():
			if sub is Label:
				sub.text = "✓" if is_craftable else "✗"
				sub.add_theme_color_override("font_color", Color(0.3, 1.0, 0.3) if is_craftable else Color(0.7, 0.3, 0.3))
			elif sub is CenterContainer:
				for icon_child in sub.get_children():
					if icon_child is TextureRect:
						icon_child.modulate = Color.WHITE if is_craftable else Color(0.45, 0.45, 0.45)


func _find_recipe_by_id(recipe_id: String) -> CraftingRecipeData:
	if not _station:
		return null
	for recipe in _station.recipes:
		if recipe.id == recipe_id:
			return recipe
	return null


# ════════════════════════════════════════════════════════════════════════════
#  Craft Detail Panel
# ════════════════════════════════════════════════════════════════════════════

func _select_recipe(recipe: CraftingRecipeData) -> void:
	if not recipe:
		return

	_return_all_slot_items()

	_selected_recipe = recipe
	_slot_nodes.clear()
	_slot_origins.clear()
	_output_item = null
	_output_zone = null
	_clear_craft_detail()

	# Description
	if not recipe.description.is_empty():
		var desc := Label.new()
		desc.text = recipe.description
		UIThemes.style_label(desc, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_craft_detail.add_child(desc)
		_craft_detail.add_child(HSeparator.new())

	# Ingredient slots
	var ingr_lbl := Label.new()
	ingr_lbl.text = "Ingredients:"
	UIThemes.style_label(ingr_lbl, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
	_craft_detail.add_child(ingr_lbl)

	var slots_hbox := HBoxContainer.new()
	UIThemes.set_separation(slots_hbox, 10)
	slots_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_craft_detail.add_child(slots_hbox)

	var slot_idx := 0
	for ingredient in recipe.ingredients:
		for _i in range(ingredient.quantity):
			var slot := CraftingSlot.new()
			slot.setup(slot_idx, ingredient)
			slot.clicked.connect(_on_slot_clicked)
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_idx))
			slot.mouse_exited.connect(_on_slot_mouse_exited)
			slots_hbox.add_child(slot)
			_slot_nodes.append(slot)
			slot_idx += 1

	_craft_detail.add_child(HSeparator.new())

	# Result info
	var result_lbl := Label.new()
	result_lbl.text = "Creates:"
	UIThemes.style_label(result_lbl, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
	_craft_detail.add_child(result_lbl)

	var result_item := ItemDatabase.get_item(recipe.result_item_id)
	if result_item:
		_craft_detail.add_child(_build_result_info(result_item))

	_craft_detail.add_child(HSeparator.new())

	# Gold cost + Craft button
	var bottom_row := HBoxContainer.new()
	UIThemes.set_separation(bottom_row, 12)
	_craft_detail.add_child(bottom_row)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

	var autofill_btn := Button.new()
	autofill_btn.name = "AutoFillButton"
	autofill_btn.text = "Auto-fill"
	autofill_btn.pressed.connect(_on_autofill_pressed)
	bottom_row.add_child(autofill_btn)

	var craft_btn := Button.new()
	craft_btn.name     = "CraftButton"
	craft_btn.text     = "Craft"
	craft_btn.disabled = true
	craft_btn.pressed.connect(_on_craft_pressed)
	bottom_row.add_child(craft_btn)

	# Output zone (hidden until item is crafted)
	_output_zone = PanelContainer.new()
	_output_zone.name         = "OutputZone"
	_output_zone.visible      = false
	_output_zone.mouse_filter = Control.MOUSE_FILTER_STOP
	_output_zone.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and _drag_state == DragState.IDLE and _output_item:
			_start_drag_from_output()
			get_viewport().set_input_as_handled()
	)
	_craft_detail.add_child(_output_zone)

	# Refresh icon list to update selection highlight
	_refresh_icon_list_styles()


func _build_result_info(item: ItemData) -> HBoxContainer:
	var row := HBoxContainer.new()
	UIThemes.set_separation(row, 12)

	# Shape + icon display centered in RESULT_SZ × RESULT_SZ box
	var center := CenterContainer.new()
	center.custom_minimum_size = Vector2(RESULT_SZ, RESULT_SZ)
	row.add_child(center)

	if item.shape:
		center.add_child(_make_shape_display(item, 1.0))
	elif item.icon:
		var icon := TextureRect.new()
		icon.custom_minimum_size = Vector2(RESULT_SZ, RESULT_SZ)
		icon.expand_mode         = TextureRect.EXPAND_IGNORE_SIZE
		icon.texture             = item.icon
		icon.stretch_mode        = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		center.add_child(icon)

	var info := VBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = item.display_name
	var name_col: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_DETAIL, name_col)
	info.add_child(name_lbl)

	var rarity_name: String = Constants.RARITY_NAMES.get(item.rarity, "Common")
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity_name
	var rarity_col: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	UIThemes.style_label(rarity_lbl, Constants.FONT_SIZE_TINY, rarity_col)
	info.add_child(rarity_lbl)

	if not item.description.is_empty():
		var desc := Label.new()
		desc.text = item.description
		UIThemes.style_label(desc, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)

	return row


func _clear_craft_detail() -> void:
	for child in _craft_detail.get_children():
		child.queue_free()


## Builds a Control sized to the item's shape bounding box, with shape cells
## drawn as ColorRects and the icon overlaid on top. Used in the result info row.
func _make_shape_display(item: ItemData, alpha: float) -> Control:
	var w         := item.shape.get_width()
	var h         := item.shape.get_height()
	var max_cell  := 14
	var cell_size := mini(max_cell, RESULT_SZ / maxi(w, h))

	var container := Control.new()
	container.custom_minimum_size = Vector2(w * cell_size, h * cell_size)

	for cell in item.shape.cells:
		var rect := ColorRect.new()
		rect.position = Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
		rect.size     = Vector2(cell_size - 2, cell_size - 2)
		rect.color    = Color(0.28, 0.32, 0.42, alpha)
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


# ════════════════════════════════════════════════════════════════════════════
#  Output Zone
# ════════════════════════════════════════════════════════════════════════════

func _refresh_output_zone() -> void:
	if not _output_zone:
		return
	for child in _output_zone.get_children():
		child.queue_free()

	_output_zone.visible = _output_item != null
	if not _output_item:
		return

	# Green border style
	var style := StyleBoxFlat.new()
	style.bg_color            = Color(0.08, 0.18, 0.10)
	style.border_color        = Color(0.25, 0.75, 0.3)
	style.border_width_left   = 2
	style.border_width_right  = 2
	style.border_width_top    = 2
	style.border_width_bottom = 2
	style.corner_radius_top_left     = 4
	style.corner_radius_top_right    = 4
	style.corner_radius_bottom_left  = 4
	style.corner_radius_bottom_right = 4
	_output_zone.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 10, 10, 8, 8)
	_output_zone.add_child(margin)

	var vbox := VBoxContainer.new()
	UIThemes.set_separation(vbox, 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "✓ Crafted — click to drag to inventory or stash"
	UIThemes.style_label(title, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SUCCESS)
	vbox.add_child(title)

	var item_row := HBoxContainer.new()
	UIThemes.set_separation(item_row, 10)
	vbox.add_child(item_row)

	if _output_item.icon:
		var icon := TextureRect.new()
		icon.texture = _output_item.icon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = _output_item.display_name
	var out_col: Color = Constants.RARITY_COLORS.get(_output_item.rarity, Color.WHITE)
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_SMALL, out_col)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	item_row.add_child(name_lbl)


# ════════════════════════════════════════════════════════════════════════════
#  Slot Interaction
# ════════════════════════════════════════════════════════════════════════════

func _on_slot_clicked(slot_idx: int) -> void:
	var slot := _slot_nodes[slot_idx]
	if not slot.assigned_item:
		return
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
		return
	_drag_source_slot_index = slot_idx
	_start_drag_from_slot(slot_idx)


func _on_slot_mouse_entered(slot_idx: int) -> void:
	if _drag_state != DragState.IDLE:
		return
	var slot := _slot_nodes[slot_idx]
	if slot.assigned_item:
		_item_tooltip.show_for_item(slot.assigned_item, null, null, get_global_mouse_position())
	else:
		_player_grid_panel.highlight_matching_ingredient(slot.ingredient)
		_stash_panel.highlight_matching_ingredient(slot.ingredient)


func _on_slot_mouse_exited() -> void:
	_item_tooltip.hide_tooltip()
	_player_grid_panel.clear_ingredient_highlights()
	_stash_panel.clear_ingredient_highlights()


func _highlight_valid_slots(item: ItemData) -> void:
	for slot in _slot_nodes:
		if not slot.assigned_item and CraftingSystem.item_matches(item, slot.ingredient):
			slot.set_highlight(Color(0.3, 1.0, 0.3))
		else:
			slot.clear_highlight()


func _clear_slot_highlights() -> void:
	for slot in _slot_nodes:
		slot.clear_highlight()


# ════════════════════════════════════════════════════════════════════════════
#  Character Switching
# ════════════════════════════════════════════════════════════════════════════

func _on_character_selected(character_id: String) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_current_character_id = character_id
	var inv: GridInventory = _player_grid_inventories.get(character_id)
	if inv:
		_player_grid_panel.setup(inv)
	_item_tooltip.hide_tooltip()


# ════════════════════════════════════════════════════════════════════════════
#  Player Grid Handlers
# ════════════════════════════════════════════════════════════════════════════

func _on_player_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		match _drag_source:
			DragSource.CRAFT_SLOT, DragSource.CRAFT_OUTPUT:
				_complete_drop_to_player_grid(adjusted_pos, inv)
			DragSource.PLAYER_GRID:
				_complete_move_within_grid(adjusted_pos, inv)
			DragSource.STASH:
				_complete_move_stash_to_grid(adjusted_pos, inv)
		return

	if _drag_state == DragState.IDLE:
		var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
		if placed:
			_start_drag_from_player_grid(placed, inv, grid_pos)


func _on_player_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_drag_hover_pos = grid_pos
		var adjusted_pos: Vector2i = grid_pos - _drag_preview.get_center_cell_offset()
		_player_grid_panel.show_placement_preview(_dragged_item, adjusted_pos, _drag_rotation)
		_drag_preview.set_valid(inv.can_place(_dragged_item, adjusted_pos, _drag_rotation))
		return

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
	else:
		_item_tooltip.hide_tooltip()


func _on_player_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
	_drag_hover_pos = Vector2i(-1, -1)
	_player_grid_panel.clear_placement_preview()


# ════════════════════════════════════════════════════════════════════════════
#  Stash Handlers
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
		return
	_start_drag_from_stash(item, index)


# ════════════════════════════════════════════════════════════════════════════
#  Input — drops on slots / stash
# ════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _drag_state != DragState.DRAGGING:
		if event.is_action_pressed("escape"):
			_on_close()
			get_viewport().set_input_as_handled()
		return

	# Rotate (right-click)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _dragged_item and _dragged_item.shape:
			_drag_rotation = (_drag_rotation + 1) % 4
			_drag_preview.rotate_cw()
			if _drag_hover_pos != Vector2i(-1, -1):
				_on_player_cell_hovered(_drag_hover_pos)
		get_viewport().set_input_as_handled()
		return

	# Cancel
	if event.is_action_pressed("escape"):
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return

	# Discard (Delete key)
	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_request_discard_dragged()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mouse := get_global_mouse_position()

	# PLAYER_GRID / STASH → ingredient slot
	if _drag_source in [DragSource.PLAYER_GRID, DragSource.STASH]:
		for i in range(_slot_nodes.size()):
			if _slot_nodes[i].get_global_rect().has_point(mouse):
				_complete_drop_on_slot(i)
				get_viewport().set_input_as_handled()
				return

	# CRAFT_SLOT / CRAFT_OUTPUT → stash
	if _drag_source in [DragSource.CRAFT_SLOT, DragSource.CRAFT_OUTPUT]:
		if _stash_panel.is_mouse_over():
			_complete_drop_to_stash()
			get_viewport().set_input_as_handled()
			return


# ════════════════════════════════════════════════════════════════════════════
#  Drag Start
# ════════════════════════════════════════════════════════════════════════════

func _start_drag_from_player_grid(placed: GridInventory.PlacedItem, inv: GridInventory, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	_dragged_item            = placed.item_data
	_drag_source_player_pos  = placed.grid_position
	_drag_source_player_rot  = placed.rotation
	_drag_rotation           = placed.rotation
	_drag_source             = DragSource.PLAYER_GRID
	_drag_state              = DragState.DRAGGING

	inv.remove_item(placed)
	_player_grid_panel.refresh()
	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.cell_size = _player_grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation, anchor)
	_highlight_valid_slots(_dragged_item)


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_dragged_item            = item
	_drag_source_stash_index = index
	_drag_rotation           = 0
	_drag_source             = DragSource.STASH
	_drag_state              = DragState.DRAGGING

	GameManager.party.stash.remove_at(index)
	EventBus.stash_changed.emit()
	_refresh_stash()
	_item_tooltip.hide_tooltip()
	_drag_preview.cell_size = _player_grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation)
	_highlight_valid_slots(_dragged_item)


func _start_drag_from_slot(slot_idx: int) -> void:
	var slot         := _slot_nodes[slot_idx]
	_dragged_item    = slot.assigned_item
	_drag_source_slot_index = slot_idx
	_drag_rotation   = 0
	_drag_source     = DragSource.CRAFT_SLOT
	_drag_state      = DragState.DRAGGING

	slot.clear()
	_update_craft_button()
	_item_tooltip.hide_tooltip()
	_drag_preview.cell_size = _player_grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation)
	_clear_slot_highlights()


func _start_drag_from_output() -> void:
	_dragged_item  = _output_item
	_drag_rotation = 0
	_drag_source   = DragSource.CRAFT_OUTPUT
	_drag_state    = DragState.DRAGGING

	_output_item = null
	_refresh_output_zone()
	_item_tooltip.hide_tooltip()
	_drag_preview.cell_size = _player_grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation)


# ════════════════════════════════════════════════════════════════════════════
#  Drop Completions
# ════════════════════════════════════════════════════════════════════════════

func _complete_drop_on_slot(slot_idx: int) -> void:
	var slot := _slot_nodes[slot_idx]
	if not CraftingSystem.item_matches(_dragged_item, slot.ingredient):
		_cancel_drag()
		return

	# Return previously assigned item to its origin before overwriting
	if slot.assigned_item:
		_return_slot_item_to_origin(slot_idx, slot.assigned_item)

	# Record where this incoming item came from
	match _drag_source:
		DragSource.PLAYER_GRID:
			_slot_origins[slot_idx] = {
				"source": DragSource.PLAYER_GRID,
				"char_id": _current_character_id,
				"pos": _drag_source_player_pos,
				"rot": _drag_source_player_rot
			}
		DragSource.CRAFT_SLOT:
			# Carry over the origin from the source slot
			if _slot_origins.has(_drag_source_slot_index):
				_slot_origins[slot_idx] = _slot_origins[_drag_source_slot_index].duplicate()
				if slot_idx != _drag_source_slot_index:
					_slot_origins.erase(_drag_source_slot_index)
			else:
				_slot_origins[slot_idx] = {"source": DragSource.STASH}
		_:
			_slot_origins[slot_idx] = {"source": DragSource.STASH}

	slot.assign(_dragged_item)
	_end_drag()
	_clear_slot_highlights()
	_update_craft_button()


func _complete_drop_to_player_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_end_drag()


func _complete_move_within_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_end_drag()


func _complete_move_stash_to_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_end_drag()


func _complete_drop_to_stash() -> void:
	if not GameManager.party.add_to_stash(_dragged_item):
		EventBus.show_message.emit("Stash is full!")
		return
	EventBus.stash_changed.emit()
	_refresh_stash()
	_end_drag()


# ════════════════════════════════════════════════════════════════════════════
#  Cancel / End Drag
# ════════════════════════════════════════════════════════════════════════════

func _cancel_drag() -> void:
	if not _dragged_item:
		_end_drag()
		return

	match _drag_source:
		DragSource.PLAYER_GRID:
			var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
			if inv:
				if not inv.place_item(_dragged_item, _drag_source_player_pos, _drag_source_player_rot):
					GameManager.party.force_add_to_stash(_dragged_item)
					EventBus.stash_changed.emit()
					_refresh_stash()
				else:
					_player_grid_panel.refresh()
		DragSource.STASH:
			GameManager.party.stash.insert(_drag_source_stash_index, _dragged_item)
			EventBus.stash_changed.emit()
			_refresh_stash()
		DragSource.CRAFT_SLOT:
			if _drag_source_slot_index >= 0 and _drag_source_slot_index < _slot_nodes.size():
				_slot_nodes[_drag_source_slot_index].assign(_dragged_item)
				_update_craft_button()
		DragSource.CRAFT_OUTPUT:
			_output_item = _dragged_item
			_refresh_output_zone()

	_end_drag()
	_clear_slot_highlights()


func _end_drag() -> void:
	_drag_state              = DragState.IDLE
	_dragged_item            = null
	_drag_source             = DragSource.NONE
	_drag_source_stash_index = -1
	_drag_source_slot_index  = -1
	_drag_preview.hide_preview()
	_player_grid_panel.clear_placement_preview()


# ════════════════════════════════════════════════════════════════════════════
#  Craft Button
# ════════════════════════════════════════════════════════════════════════════

func _update_craft_button() -> void:
	var btn := _craft_detail.find_child("CraftButton", true, false) as Button
	if btn:
		btn.disabled = not _all_slots_filled()
	var autofill_btn := _craft_detail.find_child("AutoFillButton", true, false) as Button
	if autofill_btn:
		autofill_btn.disabled = _all_slots_filled()


func _all_slots_filled() -> bool:
	if _slot_nodes.is_empty():
		return false
	for slot in _slot_nodes:
		if not slot.assigned_item:
			return false
	return true


# ════════════════════════════════════════════════════════════════════════════
#  Auto-fill
# ════════════════════════════════════════════════════════════════════════════

func _on_autofill_pressed() -> void:
	if not _selected_recipe:
		return
	var used_items: Array = []
	for slot in _slot_nodes:
		if slot.assigned_item:
			used_items.append(slot.assigned_item)
	for i in range(_slot_nodes.size()):
		var slot := _slot_nodes[i]
		if slot.assigned_item:
			continue
		var found := _find_best_match(slot.ingredient, used_items)
		if found.get("item"):
			_autofill_slot(i, found)
			used_items.append(found.item)
	_update_craft_button()
	_refresh_icon_list_styles()


## Find the best matching item for an ingredient, preferring lowest rarity.
## Search order: current character grid → other characters → stash.
func _find_best_match(ingredient: CraftingIngredient, exclude: Array) -> Dictionary:
	var char_order: Array = [_current_character_id]
	for cid: String in _player_grid_inventories:
		if cid != _current_character_id:
			char_order.append(cid)
	for cid in char_order:
		var inv: GridInventory = _player_grid_inventories.get(cid)
		if not inv:
			continue
		var best_placed: GridInventory.PlacedItem = null
		for placed in inv.get_all_placed_items():
			if exclude.has(placed.item_data):
				continue
			if CraftingSystem.item_matches(placed.item_data, ingredient):
				if not best_placed or int(placed.item_data.rarity) < int(best_placed.item_data.rarity):
					best_placed = placed
		if best_placed:
			return {"item": best_placed.item_data, "source": DragSource.PLAYER_GRID,
					"char_id": cid, "placed": best_placed}
	var best_idx := -1
	var best_rarity := 999
	for idx in range(GameManager.party.stash.size()):
		var stash_item: ItemData = GameManager.party.stash[idx]
		if exclude.has(stash_item):
			continue
		if CraftingSystem.item_matches(stash_item, ingredient):
			if int(stash_item.rarity) < best_rarity:
				best_rarity = int(stash_item.rarity)
				best_idx = idx
	if best_idx >= 0:
		return {"item": GameManager.party.stash[best_idx], "source": DragSource.STASH,
				"stash_idx": best_idx}
	return {}


func _autofill_slot(slot_idx: int, found: Dictionary) -> void:
	var item: ItemData = found.item
	if found.source == DragSource.PLAYER_GRID:
		var placed: GridInventory.PlacedItem = found.placed
		var inv: GridInventory = _player_grid_inventories.get(found.char_id)
		_slot_origins[slot_idx] = {
			"source": DragSource.PLAYER_GRID,
			"char_id": found.char_id,
			"pos": placed.grid_position,
			"rot": placed.rotation
		}
		inv.remove_item(placed)
		EventBus.inventory_changed.emit(found.char_id)
	else:
		var stash_idx: int = found.stash_idx
		_slot_origins[slot_idx] = {"source": DragSource.STASH}
		GameManager.party.stash.remove_at(stash_idx)
		EventBus.stash_changed.emit()
	_slot_nodes[slot_idx].assign(item)
	_player_grid_panel.refresh()
	_refresh_stash()


# ════════════════════════════════════════════════════════════════════════════
#  Crafting
# ════════════════════════════════════════════════════════════════════════════

func _on_craft_pressed() -> void:
	if not _selected_recipe or not _all_slots_filled():
		return

	var slot_items: Array[ItemData] = []
	for slot in _slot_nodes:
		if slot.assigned_item:
			slot_items.append(slot.assigned_item)
	var changed_chars: Array[String] = CraftingSystem.consume_ingredients(slot_items, GameManager.party)
	for char_id in changed_chars:
		EventBus.inventory_changed.emit(char_id)
	for slot in _slot_nodes:
		slot.clear()
	EventBus.stash_changed.emit()
	_refresh_stash()
	_player_grid_panel.refresh()

	var result_item := ItemDatabase.get_item(_selected_recipe.result_item_id)
	if result_item:
		_output_item = result_item
		_refresh_output_zone()
		EventBus.gold_changed.emit(GameManager.gold)
		_build_icon_list()  # refresh craftability indicators
		DebugLogger.log_info("Crafted: %s" % result_item.display_name, "Crafting")
	else:
		DebugLogger.log_warn("Craft result not found: %s" % _selected_recipe.result_item_id, "Crafting")


# ════════════════════════════════════════════════════════════════════════════
#  Discard
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_discard_requested(item: ItemData, index: int) -> void:
	_pending_discard_item = item
	_pending_discard_index = index
	_pending_discard_is_dragged = false
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % item.display_name
	_discard_dialog.popup_centered()


func _request_discard_dragged() -> void:
	if not _dragged_item:
		return
	_pending_discard_item = _dragged_item
	_pending_discard_index = -1
	_pending_discard_is_dragged = true
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % _dragged_item.display_name
	_discard_dialog.popup_centered()


func _on_discard_confirmed() -> void:
	if not _pending_discard_item:
		return
	if _pending_discard_is_dragged:
		_end_drag()
		_clear_slot_highlights()
	else:
		if _pending_discard_index >= 0 and _pending_discard_index < GameManager.party.stash.size():
			GameManager.party.stash.remove_at(_pending_discard_index)
			_refresh_stash()
			EventBus.stash_changed.emit()
	DebugLogger.log_info("Discarded: %s" % _pending_discard_item.display_name, "Crafting")
	_pending_discard_item = null
	_pending_discard_index = -1
	_pending_discard_is_dragged = false


# ════════════════════════════════════════════════════════════════════════════
#  UI Helpers
# ════════════════════════════════════════════════════════════════════════════

## Returns all items currently in slots (and uncollected output) to their origins.
func _return_all_slot_items() -> void:
	for i in range(_slot_nodes.size()):
		var slot := _slot_nodes[i]
		if slot.assigned_item:
			_return_slot_item_to_origin(i, slot.assigned_item)
	if _output_item:
		GameManager.party.force_add_to_stash(_output_item)
		EventBus.stash_changed.emit()
		_refresh_stash()
		_output_item = null


## Returns a single slot item to where it originally came from.
## Falls back to stash if the original grid position is now occupied.
func _return_slot_item_to_origin(slot_idx: int, item: ItemData) -> void:
	var returned := false
	if _slot_origins.has(slot_idx):
		var origin: Dictionary = _slot_origins[slot_idx]
		if origin.get("source") == DragSource.PLAYER_GRID:
			var char_id: String = origin.get("char_id", "")
			var pos: Vector2i = origin.get("pos", Vector2i.ZERO)
			var rot: int = origin.get("rot", 0)
			var inv: GridInventory = _player_grid_inventories.get(char_id)
			if inv and inv.can_place(item, pos, rot):
				inv.place_item(item, pos, rot)
				EventBus.inventory_changed.emit(char_id)
				_player_grid_panel.refresh()
				returned = true
		_slot_origins.erase(slot_idx)
	if not returned:
		GameManager.party.force_add_to_stash(item)
		EventBus.stash_changed.emit()
		_refresh_stash()


func _refresh_stash() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


func _on_close() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_return_all_slot_items()
	SceneManager.pop_scene()
