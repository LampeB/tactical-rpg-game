extends Control
## Crafting station screen. Modelled after shop_ui.gd.
##
## LEFT SIDE (LeftHalf):
##   - Icon list (narrow 72 px column): one square icon card per recipe.
##     Blue border = selected, green = craftable, grey = missing ingredients.
##   - Craft detail (expanding): ingredient slots ([icon|shape] each),
##     result info ([icon|shape] + labels), gold cost, Craft button, output zone.
##
## RIGHT SIDE (PlayerSide):
##   - Character tabs + grid panel + stash — drag items FROM here to ingredient slots.
##   - After crafting, drag the result FROM the output zone TO here.

enum DragState  { IDLE, DRAGGING }
enum DragSource { NONE, PLAYER_GRID, STASH, CRAFT_SLOT, CRAFT_OUTPUT }

const RESULT_SZ := 50   ## Canvas size for the shape+icon display in the result info row

@onready var _title_label: Label          = $VBox/TopBar/TitleLabel
@onready var _gold_label: Label           = $VBox/TopBar/GoldLabel
@onready var _close_btn: Button           = $VBox/BottomBar/CloseButton
@onready var _icon_list: VBoxContainer    = $VBox/Content/LeftHalf/IconScroll/IconList
@onready var _craft_detail: VBoxContainer = $VBox/Content/LeftHalf/CraftScroll/CraftDetail
@onready var _character_tabs              = $VBox/Content/PlayerSide/CharacterTabs
@onready var _player_grid_panel           = $VBox/Content/PlayerSide/GridCentering/PlayerGridPanel
@onready var _stash_panel                 = $VBox/Content/PlayerSide/StashPanel
@onready var _drag_preview                = $DragLayer/DragPreview
@onready var _item_tooltip                = $TooltipLayer/ItemTooltip

var _station: CraftingStationData         = null
var _selected_recipe: CraftingRecipeData  = null

## Ingredient slots for the selected recipe
var _slot_nodes: Array[CraftingSlot] = []

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
var _drag_source_player_pos: Vector2i = Vector2i.ZERO
var _drag_source_player_rot: int      = 0
var _drag_source_stash_index: int     = -1
var _drag_source_slot_index: int      = -1


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
		_item_tooltip.show_for_item(item, null, null, pos))
	_stash_panel.item_exited.connect(func() -> void: _item_tooltip.hide_tooltip())
	_stash_panel.set_label_prefix("Stash", false)

	if GameManager.party:
		_player_grid_inventories = GameManager.party.grid_inventories
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	_drag_preview.visible = false
	_item_tooltip.visible = false

	EventBus.gold_changed.connect(_update_gold_label)
	_update_gold_label(GameManager.gold)


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
	for recipe in _station.recipes:
		if not _is_recipe_unlocked(recipe):
			continue
		if _can_craft(recipe):
			craftable.append(recipe)
		else:
			not_craftable.append(recipe)

	var first_card: PanelContainer = null
	for recipe in craftable + not_craftable:
		var card := _build_icon_card(recipe)
		_icon_list.add_child(card)
		if first_card == null:
			first_card = card

	# Restore selection or auto-select first unlocked recipe
	if first_card:
		var reselected := false
		if _selected_recipe:
			for child in _icon_list.get_children():
				if child.get_meta("recipe_id", "") == _selected_recipe.id:
					_select_recipe(_selected_recipe)
					reselected = true
					break
		if not reselected:
			var first_unlocked: CraftingRecipeData = null
			for recipe in _station.recipes:
				if _is_recipe_unlocked(recipe):
					first_unlocked = recipe
					break
			_select_recipe(first_unlocked)
	else:
		_clear_craft_detail()


func _build_icon_card(recipe: CraftingRecipeData) -> PanelContainer:
	var is_craftable := _can_craft(recipe)
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
		var is_craftable := recipe != null and _can_craft(recipe)
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

	# Return any items currently assigned to slots back to the stash
	for slot in _slot_nodes:
		if slot.assigned_item:
			GameManager.party.add_to_stash(slot.assigned_item)
	if not _slot_nodes.is_empty():
		EventBus.stash_changed.emit()
		_refresh_stash()

	# Return output item (crafted but not yet picked up) to the stash
	if _output_item:
		GameManager.party.add_to_stash(_output_item)
		EventBus.stash_changed.emit()
		_refresh_stash()

	_selected_recipe = recipe
	_slot_nodes.clear()
	_output_item = null
	_output_zone = null
	_clear_craft_detail()

	# Description
	if not recipe.description.is_empty():
		var desc := Label.new()
		desc.text = recipe.description
		desc.add_theme_font_size_override("font_size", 13)
		desc.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_craft_detail.add_child(desc)
		_craft_detail.add_child(HSeparator.new())

	# Ingredient slots
	var ingr_lbl := Label.new()
	ingr_lbl.text = "Ingredients:"
	ingr_lbl.add_theme_font_size_override("font_size", 14)
	ingr_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_craft_detail.add_child(ingr_lbl)

	var slots_hbox := HBoxContainer.new()
	slots_hbox.add_theme_constant_override("separation", 10)
	slots_hbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_craft_detail.add_child(slots_hbox)

	var slot_idx := 0
	for ingredient in recipe.ingredients:
		for _i in range(ingredient.quantity):
			var slot := CraftingSlot.new()
			slot.setup(slot_idx, ingredient)
			slot.clicked.connect(_on_slot_clicked)
			slots_hbox.add_child(slot)
			_slot_nodes.append(slot)
			slot_idx += 1

	_craft_detail.add_child(HSeparator.new())

	# Result info
	var result_lbl := Label.new()
	result_lbl.text = "Creates:"
	result_lbl.add_theme_font_size_override("font_size", 14)
	result_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	_craft_detail.add_child(result_lbl)

	var result_item := ItemDatabase.get_item(recipe.result_item_id)
	if result_item:
		_craft_detail.add_child(_build_result_info(result_item))

	_craft_detail.add_child(HSeparator.new())

	# Gold cost + Craft button
	var bottom_row := HBoxContainer.new()
	bottom_row.add_theme_constant_override("separation", 12)
	_craft_detail.add_child(bottom_row)

	if recipe.gold_cost > 0:
		var cost_lbl := Label.new()
		cost_lbl.text = "Cost: %dg" % recipe.gold_cost
		cost_lbl.add_theme_font_size_override("font_size", 15)
		cost_lbl.add_theme_color_override("font_color",
			Color(1.0, 0.84, 0.0) if GameManager.gold >= recipe.gold_cost else Color(1.0, 0.3, 0.3))
		bottom_row.add_child(cost_lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom_row.add_child(spacer)

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
	row.add_theme_constant_override("separation", 12)

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
	name_lbl.add_theme_font_size_override("font_size", 16)
	var name_col: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	name_lbl.add_theme_color_override("font_color", name_col)
	info.add_child(name_lbl)

	var rarity_name: String = Constants.RARITY_NAMES.get(item.rarity, "Common")
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity_name
	rarity_lbl.add_theme_font_size_override("font_size", 12)
	var rarity_col: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	rarity_lbl.add_theme_color_override("font_color", rarity_col)
	info.add_child(rarity_lbl)

	if not item.description.is_empty():
		var desc := Label.new()
		desc.text = item.description
		desc.add_theme_font_size_override("font_size", 11)
		desc.add_theme_color_override("font_color", Color(0.65, 0.65, 0.65))
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
	margin.add_theme_constant_override("margin_left",   10)
	margin.add_theme_constant_override("margin_right",  10)
	margin.add_theme_constant_override("margin_top",    8)
	margin.add_theme_constant_override("margin_bottom", 8)
	_output_zone.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	margin.add_child(vbox)

	var title := Label.new()
	title.text = "✓ Crafted — click to drag to inventory or stash"
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Color(0.4, 0.9, 0.5))
	vbox.add_child(title)

	var item_row := HBoxContainer.new()
	item_row.add_theme_constant_override("separation", 10)
	vbox.add_child(item_row)

	if _output_item.icon:
		var icon := TextureRect.new()
		icon.texture = _output_item.icon
		icon.custom_minimum_size = Vector2(48, 48)
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		item_row.add_child(icon)

	var name_lbl := Label.new()
	name_lbl.text = _output_item.display_name
	name_lbl.add_theme_font_size_override("font_size", 14)
	var out_col: Color = Constants.RARITY_COLORS.get(_output_item.rarity, Color.WHITE)
	name_lbl.add_theme_color_override("font_color", out_col)
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


func _highlight_valid_slots(item: ItemData) -> void:
	for slot in _slot_nodes:
		if not slot.assigned_item and _item_matches(item, slot.ingredient):
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
		match _drag_source:
			DragSource.CRAFT_SLOT, DragSource.CRAFT_OUTPUT:
				_complete_drop_to_player_grid(grid_pos, inv)
			DragSource.PLAYER_GRID:
				_complete_move_within_grid(grid_pos, inv)
			DragSource.STASH:
				_complete_move_stash_to_grid(grid_pos, inv)
		return

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_start_drag_from_player_grid(placed, inv)


func _on_player_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_player_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
		_drag_preview.set_valid(inv.can_place(_dragged_item, grid_pos, _drag_rotation))
		return

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_item_tooltip.show_for_item(placed.item_data, placed, inv, get_global_mouse_position())
	else:
		_item_tooltip.hide_tooltip()


func _on_player_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
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
		return

	# Rotate
	if event is InputEventKey and event.pressed and event.keycode == KEY_R:
		if _dragged_item and _dragged_item.shape:
			_drag_rotation = (_drag_rotation + 1) % _dragged_item.shape.rotation_states
			_drag_preview.rotate_cw()
		get_viewport().set_input_as_handled()
		return

	# Cancel
	if event.is_action_pressed("escape") or \
			(event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		_cancel_drag()
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

func _start_drag_from_player_grid(placed: GridInventory.PlacedItem, inv: GridInventory) -> void:
	_dragged_item            = placed.item_data
	_drag_source_player_pos  = placed.grid_position
	_drag_source_player_rot  = placed.rotation
	_drag_rotation           = placed.rotation
	_drag_source             = DragSource.PLAYER_GRID
	_drag_state              = DragState.DRAGGING

	inv.remove_item(placed)
	_player_grid_panel.refresh()
	_item_tooltip.hide_tooltip()
	_drag_preview.setup(_dragged_item, _drag_rotation)
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
	_drag_preview.setup(_dragged_item, _drag_rotation)


# ════════════════════════════════════════════════════════════════════════════
#  Drop Completions
# ════════════════════════════════════════════════════════════════════════════

func _complete_drop_on_slot(slot_idx: int) -> void:
	var slot := _slot_nodes[slot_idx]
	if not _item_matches(_dragged_item, slot.ingredient):
		_cancel_drag()
		return

	# Return previously assigned item to stash
	if slot.assigned_item:
		GameManager.party.add_to_stash(slot.assigned_item)
		EventBus.stash_changed.emit()
		_refresh_stash()

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
	GameManager.party.add_to_stash(_dragged_item)
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
					GameManager.party.add_to_stash(_dragged_item)
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
		btn.disabled = not _all_slots_filled() or \
			(_selected_recipe != null and GameManager.gold < _selected_recipe.gold_cost)


func _all_slots_filled() -> bool:
	if _slot_nodes.is_empty():
		return false
	for slot in _slot_nodes:
		if not slot.assigned_item:
			return false
	return true


# ════════════════════════════════════════════════════════════════════════════
#  Crafting
# ════════════════════════════════════════════════════════════════════════════

func _on_craft_pressed() -> void:
	if not _selected_recipe or not _all_slots_filled():
		return
	if GameManager.gold < _selected_recipe.gold_cost:
		return

	GameManager.spend_gold(_selected_recipe.gold_cost)
	_consume_ingredients_from_slots()

	var result_item := ItemDatabase.get_item(_selected_recipe.result_item_id)
	if result_item:
		_output_item = result_item
		_refresh_output_zone()
		EventBus.gold_changed.emit(GameManager.gold)
		_build_icon_list()  # refresh craftability indicators
		DebugLogger.log_info("Crafted: %s" % result_item.display_name, "Crafting")
	else:
		DebugLogger.log_warn("Craft result not found: %s" % _selected_recipe.result_item_id, "Crafting")


func _consume_ingredients_from_slots() -> void:
	for slot in _slot_nodes:
		if not slot.assigned_item:
			continue
		var item    := slot.assigned_item
		var removed := false

		for stash_item in GameManager.party.stash:
			if is_same(stash_item, item):
				GameManager.party.remove_from_stash(item)
				removed = true
				break

		if not removed:
			for char_id in GameManager.party.grid_inventories:
				if removed:
					break
				var grid: GridInventory = GameManager.party.grid_inventories[char_id]
				for placed in grid.placed_items:
					if is_same(placed.item_data, item):
						grid.remove_item(placed)
						EventBus.inventory_changed.emit(char_id)
						removed = true
						break

		slot.clear()

	_refresh_stash()
	_player_grid_panel.refresh()


# ════════════════════════════════════════════════════════════════════════════
#  Crafting Logic Helpers
# ════════════════════════════════════════════════════════════════════════════

func _is_recipe_unlocked(recipe: CraftingRecipeData) -> bool:
	return recipe.unlock_flag.is_empty() or GameManager.get_flag(recipe.unlock_flag) == true


func _item_matches(item: ItemData, ingredient: CraftingIngredient) -> bool:
	return item.id.begins_with(ingredient.item_family) \
		and int(item.rarity) >= int(ingredient.min_rarity)


func _can_craft(recipe: CraftingRecipeData) -> bool:
	if GameManager.gold < recipe.gold_cost:
		return false
	var pool: Array[ItemData] = []
	for item in GameManager.party.stash:
		pool.append(item)
	for char_id in GameManager.party.grid_inventories:
		var grid: GridInventory = GameManager.party.grid_inventories[char_id]
		for placed in grid.placed_items:
			pool.append(placed.item_data)
	for ingredient in recipe.ingredients:
		var matched  := 0
		var remaining: Array[ItemData] = []
		for item in pool:
			if matched < ingredient.quantity and _item_matches(item, ingredient):
				matched += 1
			else:
				remaining.append(item)
		pool = remaining
		if matched < ingredient.quantity:
			return false
	return true


# ════════════════════════════════════════════════════════════════════════════
#  UI Helpers
# ════════════════════════════════════════════════════════════════════════════

func _refresh_stash() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


func _update_gold_label(gold: int) -> void:
	_gold_label.text = "%d g" % gold


func _on_close() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	SceneManager.pop_scene()
