extends Control
## Crafting station — 3-column layout: recipe list | craft area | source panel.

enum DragState  { IDLE, DRAGGING }
enum DragSource { NONE, PLAYER_GRID, STASH, CRAFT_SLOT, CRAFT_OUTPUT }

const RESULT_SZ := 60  ## px for shape/icon in the result card

# ── Node references ───────────────────────────────────────────────────────────
@onready var _station_header: VBoxContainer = $HLayout/LeftPanel/StationHeader
@onready var _recipe_list: VBoxContainer    = $HLayout/LeftPanel/RecipeScroll/RecipeList
@onready var _centre_panel: VBoxContainer   = $HLayout/CentreWrapper/CentrePanel
@onready var _source_row: HBoxContainer     = $HLayout/CharPanel/SourceRow
@onready var _filter_row: HBoxContainer     = $HLayout/CharPanel/FilterRow
@onready var _character_tabs                = $HLayout/CharPanel/CharacterTabs
@onready var _inv_header: HBoxContainer     = $HLayout/CharPanel/InvHeader
@onready var _player_grid_panel             = $HLayout/CharPanel/GridScroll/GridCentering/PlayerGridPanel
@onready var _stash_panel                   = $HLayout/StashColumn/StashPanel
@onready var _back_btn: Button              = $HLayout/LeftPanel/BackButton
@onready var _bottom_bar: HBoxContainer     = $BottomBar
@onready var _drag_preview                  = $DragLayer/DragPreview
@onready var _item_tooltip                  = $DragLayer/ItemTooltip

# ── Station / recipe state ────────────────────────────────────────────────────
var _station: CraftingStationData         = null
var _selected_recipe: CraftingRecipeData  = null
var _slot_nodes: Array[CraftingSlot]      = []
var _slot_origins: Dictionary             = {}
var _output_item: ItemData                = null
var _output_card: PanelContainer          = null
var _forge_btn: Button                    = null
var _autofill_btn: Button                 = null
var _need_label: Label                    = null
var _ready_need_label: Label              = null
var _player_grid_inventories: Dictionary  = {}
var _current_character_id: String         = ""

# ── Drag state ────────────────────────────────────────────────────────────────
var _drag_state: DragState    = DragState.IDLE
var _dragged_item: ItemData   = null
var _drag_source: DragSource  = DragSource.NONE
var _drag_rotation: int       = 0
var _drag_hover_pos: Vector2i = Vector2i(-1, -1)
var _drag_source_player_pos: Vector2i = Vector2i.ZERO
var _drag_source_player_rot: int      = 0
var _drag_source_stash_index: int     = -1
var _drag_source_slot_index: int      = -1

# ── Discard ───────────────────────────────────────────────────────────────────
var _discard_dialog: ConfirmationDialog = null
var _pending_discard_item: ItemData     = null
var _pending_discard_index: int         = -1
var _pending_discard_is_dragged: bool   = false


# ════════════════════════════════════════════════════════════════════════════
#  Setup
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_player_grid_panel.cell_clicked.connect(_on_player_cell_clicked)
	_player_grid_panel.cell_hovered.connect(_on_player_cell_hovered)
	_player_grid_panel.cell_exited.connect(_on_player_hover_exited)

	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(func(item: ItemData, pos: Vector2) -> void:
		_item_tooltip.show_for_item(item, null, null, pos))
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
	_item_tooltip.embedded = false

	_back_btn.pressed.connect(_on_close)

	_build_source_row()
	_build_filter_row()
	_build_bottom_bar()


func receive_data(data: Dictionary) -> void:
	var station_id: String = data.get("station_id", "")
	var path := "res://data/crafting/%s.tres" % station_id
	_station = load(path) as CraftingStationData
	if not _station:
		DebugLogger.log_warn("CraftingUI: station not found: %s" % path, "Crafting")
		SceneManager.pop_scene()
		return

	_build_station_header()
	_build_recipe_list()
	_refresh_stash()

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])


# ════════════════════════════════════════════════════════════════════════════
#  Left Panel — Station Header
# ════════════════════════════════════════════════════════════════════════════

func _build_station_header() -> void:
	for child in _station_header.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 12, 12, 10, 6)
	_station_header.add_child(margin)

	var vbox := VBoxContainer.new()
	UIThemes.set_separation(vbox, 2)
	margin.add_child(vbox)

	# Split "Aldric's Forge" → super="ALDRIC'S" + title="Forge"
	var parts: PackedStringArray = _station.display_name.split(" ")
	var super_text: String = " ".join(parts.slice(0, parts.size() - 1)).to_upper() if parts.size() > 1 else ""
	var title_text: String = parts[parts.size() - 1]

	if not super_text.is_empty():
		var super_lbl := Label.new()
		super_lbl.text = super_text
		UIThemes.style_label(super_lbl, 9, DesignTokens.INK_4)
		vbox.add_child(super_lbl)

	var title_row := HBoxContainer.new()
	UIThemes.set_separation(title_row, 8)
	vbox.add_child(title_row)

	var title_lbl := Label.new()
	title_lbl.text = title_text
	title_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.style_label(title_lbl, 18, DesignTokens.INK)
	title_row.add_child(title_lbl)

	_ready_need_label = Label.new()
	_ready_need_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIThemes.style_label(_ready_need_label, 9, DesignTokens.INK_4)
	title_row.add_child(_ready_need_label)

	_update_ready_need()


func _update_ready_need() -> void:
	if not _ready_need_label or not _station:
		return
	var ready_n := 0
	var need_n := 0
	for r in _station.recipes:
		if not CraftingSystem.is_recipe_unlocked(r, GameManager.story_flags):
			continue
		if CraftingSystem.can_craft(r, GameManager.party):
			ready_n += 1
		else:
			need_n += 1
	_ready_need_label.text = "%d READY  %d NEED" % [ready_n, need_n]


# ════════════════════════════════════════════════════════════════════════════
#  Left Panel — Recipe List
# ════════════════════════════════════════════════════════════════════════════

func _build_recipe_list() -> void:
	for child in _recipe_list.get_children():
		child.queue_free()

	var craftable: Array = []
	var not_craftable: Array = []
	for r in _station.recipes:
		if not CraftingSystem.is_recipe_unlocked(r, GameManager.story_flags):
			continue
		if CraftingSystem.can_craft(r, GameManager.party):
			craftable.append(r)
		else:
			not_craftable.append(r)

	for recipe in craftable + not_craftable:
		_recipe_list.add_child(_build_recipe_row(recipe))

	# Auto-select first unlocked recipe
	if _recipe_list.get_child_count() > 0:
		if _selected_recipe:
			for row in _recipe_list.get_children():
				if row.get_meta("recipe_id", "") == _selected_recipe.id:
					_select_recipe(_selected_recipe)
					return
		var first: CraftingRecipeData = (craftable + not_craftable)[0]
		_select_recipe(first)


func _build_recipe_row(recipe: CraftingRecipeData) -> Control:
	var is_craftable := CraftingSystem.can_craft(recipe, GameManager.party)
	var is_selected  := _selected_recipe != null and _selected_recipe.id == recipe.id
	var result_item  := ItemDatabase.get_item(recipe.result_item_id)

	var row := PanelContainer.new()
	row.set_meta("recipe_id", recipe.id)
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.custom_minimum_size = Vector2(0, 56)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = DesignTokens.INK if is_selected else DesignTokens.PAPER
	style.content_margin_left   = 12
	style.content_margin_right  = 10
	style.content_margin_top    = 8
	style.content_margin_bottom = 8
	if not is_selected:
		style.border_color        = DesignTokens.HAIRLINE
		style.border_width_bottom = 1
	row.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(hbox)

	# Item icon (32×32)
	if result_item and result_item.icon:
		var tex := TextureRect.new()
		tex.texture = result_item.icon
		tex.custom_minimum_size = Vector2(32, 32)
		tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.modulate     = Color.WHITE if is_craftable else Color(0.6, 0.55, 0.5)
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(tex)
	else:
		var ph := ColorRect.new()
		ph.custom_minimum_size = Vector2(32, 32)
		ph.color               = DesignTokens.PAPER_3 if not is_selected else DesignTokens.INK_2
		ph.mouse_filter        = Control.MOUSE_FILTER_IGNORE
		hbox.add_child(ph)

	# Name + ingredients
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.set_separation(text_col, 2)
	text_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(text_col)

	var name_lbl := Label.new()
	name_lbl.text = recipe.display_name
	var name_col: Color = DesignTokens.PAPER if is_selected else (DesignTokens.INK if is_craftable else DesignTokens.INK_3)
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_SMALL, name_col)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(name_lbl)

	var ingr_text := _ingredient_summary(recipe)
	var ingr_lbl := Label.new()
	ingr_lbl.text = ingr_text
	var ingr_col: Color = DesignTokens.INK_4 if is_selected else DesignTokens.INK_4
	UIThemes.style_label(ingr_lbl, 10, ingr_col)
	ingr_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text_col.add_child(ingr_lbl)

	# Craftable badge
	var badge := Label.new()
	badge.text = "●"
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIThemes.style_label(badge, 14, DesignTokens.MOSS if is_craftable else DesignTokens.INK_4)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(badge)

	row.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_recipe(recipe)
	)
	return row


func _ingredient_summary(recipe: CraftingRecipeData) -> String:
	var parts: Array[String] = []
	for ingr in recipe.ingredients:
		var family: String = ingr.item_family.replace("_", " ").capitalize()
		var qty_prefix: String = "%d× " % ingr.quantity if ingr.quantity > 1 else ""
		parts.append(qty_prefix + family)
	return " + ".join(parts)


func _refresh_recipe_list_styles() -> void:
	for row in _recipe_list.get_children():
		if not row is PanelContainer:
			continue
		var recipe_id: String = row.get_meta("recipe_id", "")
		var recipe: CraftingRecipeData = _find_recipe_by_id(recipe_id)
		var is_selected  := _selected_recipe != null and _selected_recipe.id == recipe_id
		var is_craftable := recipe != null and CraftingSystem.can_craft(recipe, GameManager.party)

		var style := row.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			continue
		style.bg_color = DesignTokens.INK if is_selected else DesignTokens.PAPER
		style.border_width_bottom = 0 if is_selected else 1

		var hbox := row.get_child(0) as HBoxContainer
		if not hbox:
			continue
		# tex / ph
		var tex_or_ph: Control = hbox.get_child(0)
		if tex_or_ph is TextureRect:
			tex_or_ph.modulate = Color.WHITE if is_craftable else Color(0.6, 0.55, 0.5)
		elif tex_or_ph is ColorRect:
			tex_or_ph.color = DesignTokens.PAPER_3 if not is_selected else DesignTokens.INK_2
		# text col
		var text_col: VBoxContainer = hbox.get_child(1)
		if text_col:
			var name_col: Color = DesignTokens.PAPER if is_selected else (DesignTokens.INK if is_craftable else DesignTokens.INK_3)
			var name_lbl := text_col.get_child(0) as Label
			if name_lbl:
				name_lbl.add_theme_color_override("font_color", name_col)
		# badge
		var badge := hbox.get_child(2) as Label
		if badge:
			badge.add_theme_color_override("font_color", DesignTokens.MOSS if is_craftable else DesignTokens.INK_4)


func _find_recipe_by_id(recipe_id: String) -> CraftingRecipeData:
	if not _station:
		return null
	for recipe in _station.recipes:
		if recipe.id == recipe_id:
			return recipe
	return null


# ════════════════════════════════════════════════════════════════════════════
#  Centre Panel — Recipe Detail
# ════════════════════════════════════════════════════════════════════════════

func _select_recipe(recipe: CraftingRecipeData) -> void:
	if not recipe:
		return
	_return_all_slot_items()
	_selected_recipe = recipe
	_slot_nodes.clear()
	_slot_origins.clear()
	_output_item  = null
	_output_card  = null
	_forge_btn    = null
	_autofill_btn = null
	_need_label   = null

	for child in _centre_panel.get_children():
		child.queue_free()

	_build_centre_header(recipe)

	var sep := HSeparator.new()
	_centre_panel.add_child(sep)

	_add_vspace(20)
	_build_slot_area(recipe)
	_build_produces_row()

	var result_item := ItemDatabase.get_item(recipe.result_item_id)
	_build_result_card(result_item)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_centre_panel.add_child(spacer)

	_build_action_row()
	_refresh_recipe_list_styles()
	_update_need_indicator()


func _build_centre_header(recipe: CraftingRecipeData) -> void:
	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 12)
	_centre_panel.add_child(hbox)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.set_separation(left, 4)
	hbox.add_child(left)

	var title := Label.new()
	title.text = recipe.display_name
	UIThemes.style_label(title, Constants.FONT_SIZE_TITLE, DesignTokens.INK)
	left.add_child(title)

	if not recipe.description.is_empty():
		var desc := Label.new()
		desc.text = recipe.description
		UIThemes.style_label(desc, Constants.FONT_SIZE_SMALL, DesignTokens.INK_3)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		left.add_child(desc)

	_need_label = Label.new()
	_need_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_need_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UIThemes.style_label(_need_label, Constants.FONT_SIZE_SMALL, DesignTokens.EMBER)
	hbox.add_child(_need_label)


func _build_slot_area(recipe: CraftingRecipeData) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre_panel.add_child(center)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 20)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(hbox)

	var slot_idx := 0
	for ingredient in recipe.ingredients:
		for _i in range(ingredient.quantity):
			if slot_idx > 0:
				var plus := Label.new()
				plus.text = "+"
				plus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				UIThemes.style_label(plus, Constants.FONT_SIZE_TITLE, DesignTokens.INK_3)
				hbox.add_child(plus)
			var slot := CraftingSlot.new()
			slot.setup(slot_idx, ingredient)
			slot.clicked.connect(_on_slot_clicked)
			slot.mouse_entered.connect(_on_slot_mouse_entered.bind(slot_idx))
			slot.mouse_exited.connect(_on_slot_mouse_exited)
			hbox.add_child(slot)
			_slot_nodes.append(slot)
			slot_idx += 1


func _build_produces_row() -> void:
	_add_vspace(8)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre_panel.add_child(center)

	var vbox := VBoxContainer.new()
	UIThemes.set_separation(vbox, 0)
	center.add_child(vbox)

	for _i in range(3):
		var dot := Label.new()
		dot.text = "│"
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		UIThemes.style_label(dot, 11, DesignTokens.INK_4)
		vbox.add_child(dot)

	var produces := Label.new()
	produces.text = "PRODUCES"
	produces.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.style_label(produces, 9, DesignTokens.INK_4)
	vbox.add_child(produces)

	var arrow := Label.new()
	arrow.text = "↓"
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.style_label(arrow, 16, DesignTokens.INK_4)
	vbox.add_child(arrow)
	_add_vspace(8)


func _build_result_card(item: ItemData) -> void:
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_centre_panel.add_child(center)

	_output_card = PanelContainer.new()
	_output_card.custom_minimum_size = Vector2(500, 0)
	_output_card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_output_card.add_theme_stylebox_override("panel", DesignTokens.make_paper_panel(16, 1))
	_output_card.mouse_filter = Control.MOUSE_FILTER_STOP
	_output_card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_LEFT \
				and _drag_state == DragState.IDLE and _output_item:
			_start_drag_from_output()
			get_viewport().set_input_as_handled()
	)
	center.add_child(_output_card)

	_refresh_output_zone(item)


func _build_action_row() -> void:
	var sep := HSeparator.new()
	_centre_panel.add_child(sep)
	_add_vspace(12)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 10)
	_centre_panel.add_child(hbox)

	var left_spacer := Control.new()
	left_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(left_spacer)

	var clear_btn := Button.new()
	clear_btn.text = "CLEAR"
	clear_btn.custom_minimum_size = Vector2(90, 34)
	var clear_normal := StyleBoxFlat.new()
	clear_normal.bg_color = DesignTokens.PAPER
	clear_normal.border_color = DesignTokens.INK_3
	clear_normal.set_border_width_all(1)
	clear_normal.set_content_margin_all(8)
	var clear_hover := clear_normal.duplicate() as StyleBoxFlat
	clear_hover.bg_color = DesignTokens.PAPER_2
	clear_btn.add_theme_stylebox_override("normal", clear_normal)
	clear_btn.add_theme_stylebox_override("hover", clear_hover)
	clear_btn.add_theme_stylebox_override("pressed", clear_hover)
	clear_btn.add_theme_color_override("font_color", DesignTokens.INK_2)
	clear_btn.add_theme_font_size_override("font_size", UIThemes.scaled_font_size(Constants.FONT_SIZE_SMALL))
	clear_btn.pressed.connect(_on_clear_pressed)
	hbox.add_child(clear_btn)

	_autofill_btn = Button.new()
	_autofill_btn.name = "AutoFillButton"
	_autofill_btn.text = "AUTO-FILL  [Y]"
	_autofill_btn.custom_minimum_size = Vector2(130, 34)
	_autofill_btn.add_theme_stylebox_override("normal", _make_dark_btn_style())
	_autofill_btn.add_theme_stylebox_override("hover", _make_dark_btn_style(true))
	_autofill_btn.add_theme_stylebox_override("pressed", _make_dark_btn_style(true))
	_autofill_btn.add_theme_color_override("font_color", DesignTokens.PAPER)
	_autofill_btn.add_theme_font_size_override("font_size", UIThemes.scaled_font_size(Constants.FONT_SIZE_SMALL))
	_autofill_btn.pressed.connect(_on_autofill_pressed)
	hbox.add_child(_autofill_btn)

	_forge_btn = Button.new()
	_forge_btn.name = "CraftButton"
	_forge_btn.text = "FORGE IT  [A]"
	_forge_btn.custom_minimum_size = Vector2(130, 34)
	_forge_btn.disabled = true
	_forge_btn.add_theme_stylebox_override("normal", _make_dark_btn_style())
	_forge_btn.add_theme_stylebox_override("hover", _make_dark_btn_style(true))
	_forge_btn.add_theme_stylebox_override("pressed", _make_dark_btn_style(true))
	_forge_btn.add_theme_color_override("font_color", DesignTokens.PAPER)
	_forge_btn.add_theme_font_size_override("font_size", UIThemes.scaled_font_size(Constants.FONT_SIZE_SMALL))
	_forge_btn.pressed.connect(_on_craft_pressed)
	hbox.add_child(_forge_btn)
	_add_vspace(4)


func _make_dark_btn_style(lighter: bool = false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = DesignTokens.INK_2 if lighter else DesignTokens.INK
	sb.set_content_margin_all(8)
	return sb


func _add_vspace(px: int) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, px)
	_centre_panel.add_child(s)


# ════════════════════════════════════════════════════════════════════════════
#  Output Zone (inside result card)
# ════════════════════════════════════════════════════════════════════════════

func _refresh_output_zone(preview_item: ItemData = null) -> void:
	if not _output_card:
		return
	for child in _output_card.get_children():
		child.queue_free()

	var display_item: ItemData = _output_item if _output_item else preview_item
	var is_crafted: bool = _output_item != null

	# Card style
	if is_crafted:
		var crafted_style := StyleBoxFlat.new()
		crafted_style.bg_color = DesignTokens.PAPER_2
		crafted_style.border_color = DesignTokens.MOSS
		crafted_style.set_border_width_all(2)
		crafted_style.set_content_margin_all(16)
		_output_card.add_theme_stylebox_override("panel", crafted_style)
	else:
		_output_card.add_theme_stylebox_override("panel", DesignTokens.make_paper_panel(16, 1))

	var vbox := VBoxContainer.new()
	UIThemes.set_separation(vbox, 8)
	_output_card.add_child(vbox)

	# Header row
	var header_lbl := Label.new()
	if is_crafted:
		header_lbl.text = "✓  CRAFTED  —  click to drag to inventory or stash"
		UIThemes.style_label(header_lbl, 9, DesignTokens.MOSS)
	else:
		header_lbl.text = "RESULT"
		UIThemes.style_label(header_lbl, 9, DesignTokens.INK_4)
	vbox.add_child(header_lbl)

	if not display_item:
		return

	# Item row
	var row := HBoxContainer.new()
	UIThemes.set_separation(row, 16)
	vbox.add_child(row)

	# Shape / icon
	var icon_center := CenterContainer.new()
	icon_center.custom_minimum_size = Vector2(RESULT_SZ, RESULT_SZ)
	row.add_child(icon_center)

	if display_item.shape:
		icon_center.add_child(_make_shape_display(display_item, 1.0))
	elif display_item.icon:
		var tex := TextureRect.new()
		tex.texture      = display_item.icon
		tex.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.custom_minimum_size = Vector2(RESULT_SZ, RESULT_SZ)
		icon_center.add_child(tex)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	UIThemes.set_separation(info, 4)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = display_item.display_name
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_HEADER, DesignTokens.INK)
	info.add_child(name_lbl)

	var rarity_name: String = Constants.RARITY_NAMES.get(display_item.rarity, "Common")
	var rarity_lbl := Label.new()
	rarity_lbl.text = rarity_name.to_upper()
	UIThemes.style_label(rarity_lbl, Constants.FONT_SIZE_SMALL, Constants.get_rarity_color(display_item.rarity))
	info.add_child(rarity_lbl)

	if not display_item.description.is_empty():
		var desc := Label.new()
		desc.text = display_item.description
		UIThemes.style_label(desc, Constants.FONT_SIZE_SMALL, DesignTokens.INK_3)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		info.add_child(desc)


func _make_shape_display(item: ItemData, alpha: float) -> Control:
	var w         := item.shape.get_width()
	var h         := item.shape.get_height()
	var max_cell  := 16
	@warning_ignore("integer_division")
	var cell_size := mini(max_cell, RESULT_SZ / maxi(w, h))

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


# ════════════════════════════════════════════════════════════════════════════
#  Right Panel — Source Header, Filter, Inventory Header, Bottom Bar
# ════════════════════════════════════════════════════════════════════════════

func _build_source_row() -> void:
	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 12, 12, 10, 6)
	_source_row.add_child(margin)

	var inner := HBoxContainer.new()
	UIThemes.set_separation(inner, 8)
	margin.add_child(inner)

	var title := Label.new()
	title.text = "Source"
	UIThemes.style_label(title, 18, DesignTokens.INK)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(title)

	# Filter tabs [ALL | WEAPONS | ARMOR | GEMS]
	for tab_name in ["ALL", "WEAPONS", "ARMOR", "GEMS"]:
		var btn := Button.new()
		btn.text = tab_name
		btn.custom_minimum_size = Vector2(0, 24)
		var selected: bool = tab_name == "ALL"
		var tab_style := StyleBoxFlat.new()
		tab_style.bg_color = DesignTokens.INK if selected else Color(0, 0, 0, 0)
		tab_style.set_content_margin_all(6)
		btn.add_theme_stylebox_override("normal", tab_style)
		btn.add_theme_stylebox_override("hover", tab_style)
		btn.add_theme_stylebox_override("pressed", tab_style)
		btn.add_theme_color_override("font_color", DesignTokens.PAPER if selected else DesignTokens.INK_3)
		btn.add_theme_font_size_override("font_size", UIThemes.scaled_font_size(10))
		inner.add_child(btn)


func _build_filter_row() -> void:
	# Visual spacer below source row — intentionally left empty for now
	var sep := HSeparator.new()
	_filter_row.add_child(sep)


func _refresh_inv_header() -> void:
	for child in _inv_header.get_children():
		child.queue_free()

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 12, 12, 6, 4)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inv_header.add_child(margin)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 8)
	margin.add_child(hbox)

	var char_name: String = _current_character_id.capitalize() + "'s Inventory"
	var name_lbl := Label.new()
	name_lbl.text = char_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.style_label(name_lbl, Constants.FONT_SIZE_SMALL, DesignTokens.INK_2)
	hbox.add_child(name_lbl)

	# VANGUARD N badge
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	var count: int = inv.get_all_placed_items().size() if inv else 0
	var badge := _make_badge("VANGUARD  %d" % count)
	hbox.add_child(badge)


func _make_badge(text: String) -> PanelContainer:
	var badge := PanelContainer.new()
	var badge_style := StyleBoxFlat.new()
	badge_style.bg_color = DesignTokens.INK
	badge_style.corner_radius_top_left     = 3
	badge_style.corner_radius_top_right    = 3
	badge_style.corner_radius_bottom_left  = 3
	badge_style.corner_radius_bottom_right = 3
	badge_style.set_content_margin_all(4)
	badge_style.content_margin_left  = 6
	badge_style.content_margin_right = 6
	badge.add_theme_stylebox_override("panel", badge_style)

	var lbl := Label.new()
	lbl.text = text
	UIThemes.style_label(lbl, 9, DesignTokens.PAPER)
	badge.add_child(lbl)
	return badge


func _build_bottom_bar() -> void:
	var bg := StyleBoxFlat.new()
	bg.bg_color = DesignTokens.INK
	_bottom_bar.add_theme_stylebox_override("panel", bg)
	_bottom_bar.add_theme_constant_override("separation", 0)

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 16, 16, 0, 0)
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bottom_bar.add_child(margin)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 24)
	margin.add_child(hbox)

	var hints: Array[String] = ["[←→] MOVE", "[A] PICK/PLACE", "[R] ROTATE", "[Y] AUTO-FILL", "[LB/RB] SWITCH"]
	for hint in hints:
		var lbl := Label.new()
		lbl.text = hint
		UIThemes.style_label(lbl, 10, DesignTokens.INK_3)
		hbox.add_child(lbl)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer)

	var nav := Label.new()
	nav.text = "[←→] MOVE  ·  [A] PICK  ·  [R] ROTATE  ·  [ESC] BACK"
	UIThemes.style_label(nav, 10, DesignTokens.INK_3)
	hbox.add_child(nav)


# ════════════════════════════════════════════════════════════════════════════
#  Need Indicator & Craft Button
# ════════════════════════════════════════════════════════════════════════════

func _update_need_indicator() -> void:
	if not _need_label:
		return
	var unfilled := 0
	for slot in _slot_nodes:
		if not slot.assigned_item:
			unfilled += 1
	if unfilled > 0:
		_need_label.text = "●  NEED %d MORE" % unfilled
	else:
		_need_label.text = ""


func _update_craft_button() -> void:
	if _forge_btn:
		_forge_btn.disabled = not _all_slots_filled()
	if _autofill_btn:
		_autofill_btn.disabled = _all_slots_filled()
	_update_need_indicator()


func _all_slots_filled() -> bool:
	if _slot_nodes.is_empty():
		return false
	for slot in _slot_nodes:
		if not slot.assigned_item:
			return false
	return true


func _on_clear_pressed() -> void:
	_return_all_slot_items()
	_update_craft_button()
	_refresh_recipe_list_styles()


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
			slot.set_highlight(DesignTokens.MOSS)
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
	_refresh_inv_header()


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
#  Input
# ════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _drag_state != DragState.DRAGGING:
		if event.is_action_pressed("escape"):
			_on_close()
			get_viewport().set_input_as_handled()
		return

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _dragged_item and _dragged_item.shape:
			_drag_rotation = (_drag_rotation + 1) % 4
			_drag_preview.rotate_cw()
			if _drag_hover_pos != Vector2i(-1, -1):
				_on_player_cell_hovered(_drag_hover_pos)
		get_viewport().set_input_as_handled()
		return

	if event.is_action_pressed("escape"):
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_DELETE:
		_request_discard_dragged()
		get_viewport().set_input_as_handled()
		return

	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var mouse := get_global_mouse_position()

	if _drag_source in [DragSource.PLAYER_GRID, DragSource.STASH]:
		for i in range(_slot_nodes.size()):
			if _slot_nodes[i].get_global_rect().has_point(mouse):
				_complete_drop_on_slot(i)
				get_viewport().set_input_as_handled()
				return

	if _drag_source in [DragSource.CRAFT_SLOT, DragSource.CRAFT_OUTPUT]:
		if _stash_panel.is_mouse_over():
			_complete_drop_to_stash()
			get_viewport().set_input_as_handled()
			return


# ════════════════════════════════════════════════════════════════════════════
#  Drag Start
# ════════════════════════════════════════════════════════════════════════════

func _start_drag_from_player_grid(placed: GridInventory.PlacedItem, inv: GridInventory, clicked_pos: Vector2i = Vector2i(-1, -1)) -> void:
	_dragged_item           = placed.item_data
	_drag_source_player_pos = placed.grid_position
	_drag_source_player_rot = placed.rotation
	_drag_rotation          = placed.rotation
	_drag_source            = DragSource.PLAYER_GRID
	_drag_state             = DragState.DRAGGING

	inv.remove_item(placed)
	_player_grid_panel.refresh()
	var anchor: Vector2i = Vector2i(-1, -1)
	if clicked_pos != Vector2i(-1, -1):
		anchor = clicked_pos - placed.grid_position
	_drag_preview.cell_size = _player_grid_panel.cell_size
	_drag_preview.setup(_dragged_item, _drag_rotation, anchor)
	_highlight_valid_slots(_dragged_item)
	_refresh_inv_header()


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
	var slot        := _slot_nodes[slot_idx]
	_dragged_item   = slot.assigned_item
	_drag_rotation  = 0
	_drag_source    = DragSource.CRAFT_SLOT
	_drag_state     = DragState.DRAGGING

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
	var preview := ItemDatabase.get_item(_selected_recipe.result_item_id) if _selected_recipe else null
	_refresh_output_zone(preview)
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

	if slot.assigned_item:
		_return_slot_item_to_origin(slot_idx, slot.assigned_item)

	match _drag_source:
		DragSource.PLAYER_GRID:
			_slot_origins[slot_idx] = {
				"source": DragSource.PLAYER_GRID,
				"char_id": _current_character_id,
				"pos": _drag_source_player_pos,
				"rot": _drag_source_player_rot
			}
		DragSource.CRAFT_SLOT:
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
	_refresh_inv_header()
	_end_drag()


func _complete_move_within_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_refresh_inv_header()
	_end_drag()


func _complete_move_stash_to_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_refresh_inv_header()
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
					_refresh_inv_header()
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
			var preview := ItemDatabase.get_item(_selected_recipe.result_item_id) if _selected_recipe else null
			_refresh_output_zone(preview)

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
	_refresh_recipe_list_styles()


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
	_refresh_inv_header()


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
	_refresh_inv_header()

	var result_item := ItemDatabase.get_item(_selected_recipe.result_item_id)
	if result_item:
		_output_item = result_item
		_refresh_output_zone(result_item)
		EventBus.gold_changed.emit(GameManager.gold)
		_update_craft_button()
		_update_ready_need()
		_refresh_recipe_list_styles()
		DebugLogger.log_info("Crafted: %s" % result_item.display_name, "Crafting")
	else:
		DebugLogger.log_warn("Craft result not found: %s" % _selected_recipe.result_item_id, "Crafting")


# ════════════════════════════════════════════════════════════════════════════
#  Discard
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_discard_requested(item: ItemData, index: int) -> void:
	_pending_discard_item       = item
	_pending_discard_index      = index
	_pending_discard_is_dragged = false
	_discard_dialog.dialog_text = "Discard %s? This cannot be undone." % item.display_name
	_discard_dialog.popup_centered()


func _request_discard_dragged() -> void:
	if not _dragged_item:
		return
	_pending_discard_item       = _dragged_item
	_pending_discard_index      = -1
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
	_pending_discard_item       = null
	_pending_discard_index      = -1
	_pending_discard_is_dragged = false


# ════════════════════════════════════════════════════════════════════════════
#  Helpers
# ════════════════════════════════════════════════════════════════════════════

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


func _return_slot_item_to_origin(slot_idx: int, item: ItemData) -> void:
	var returned := false
	if _slot_origins.has(slot_idx):
		var origin: Dictionary = _slot_origins[slot_idx]
		if origin.get("source") == DragSource.PLAYER_GRID:
			var char_id: String  = origin.get("char_id", "")
			var pos: Vector2i    = origin.get("pos", Vector2i.ZERO)
			var rot: int         = origin.get("rot", 0)
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
