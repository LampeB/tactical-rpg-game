extends Control
## Map editor scene controller.
## Three-panel layout: map list (left) + canvas (center) + properties (right).

const DECORATION_SCENES_DIR := "res://scenes/world/objects/"

var _maps: Dictionary = {}         # id -> MapData (working copies)
var _selected_map_id: String = ""
var _selected_element_idx: int = -1
var _dirty_ids: Dictionary = {}    # id -> true

# UI references
var _bg: ColorRect
var _search_edit: LineEdit
var _map_list_vbox: VBoxContainer
var _viewport_3d: MapViewport3D
var _asset_palette: AssetPalette
var _property_vbox: VBoxContainer
var _status_label: Label
var _save_btn: Button
var _save_all_btn: Button
var _tool_buttons: Dictionary = {}  # Tool enum -> Button
var _terrain_palette: HBoxContainer
var _eraser_btn: Button
var _brush_controls: HBoxContainer
var _element_picker: OptionButton
var _place_options: HBoxContainer
var _place_scale_spin: SpinBox
var _place_random_rot_cb: CheckBox
var _place_random_scale_cb: CheckBox
var _place_random_scale_min_spin: SpinBox
var _place_random_scale_max_spin: SpinBox
var _coord_label: Label
var _unsaved_dialog: ConfirmationDialog

# Scatter tool UI
var _scatter_status_label: Label
var _scatter_seed_spin: SpinBox
var _scatter_count_spin: SpinBox
var _scatter_spacing_spin: SpinBox
var _scatter_asset_checkboxes: Dictionary = {}  # path -> CheckBox
var _scatter_asset_list_vbox: VBoxContainer
var _scatter_search_edit: LineEdit
var _scatter_generate_btn: Button
var _scatter_accept_btn: Button

# Cached decoration scene list
var _decoration_scene_names: Array[String] = []

# Undo / Redo
const MAX_UNDO := 50
var _undo_stack: Array[Dictionary] = []
var _redo_stack: Array[Dictionary] = []
var _current_paint_action: Dictionary = {}  # accumulates cells during a stroke
var _drag_original_pos: Vector3 = Vector3.ZERO
var _connection_drag_original_pos: Vector3 = Vector3.ZERO
var _selected_connection_idx: int = -1


func _ready() -> void:
	_scan_decoration_scenes()
	_load_all_maps()
	_build_ui()

	# Select first map if available
	var ids: Array = _maps.keys()
	if not ids.is_empty():
		ids.sort()
		_select_map(ids[0])


func _scan_decoration_scenes() -> void:
	var dir := DirAccess.open(DECORATION_SCENES_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tscn"):
			_decoration_scene_names.append(file_name.get_basename())
		file_name = dir.get_next()
	dir.list_dir_end()
	_decoration_scene_names.sort()


func _load_all_maps() -> void:
	_maps.clear()
	for map_data in MapDatabase.get_all_maps():
		var copy: MapData = map_data.duplicate(true) as MapData
		_maps[copy.id] = copy


func _build_ui() -> void:
	# Background
	_bg = ColorRect.new()
	_bg.color = UIColors.BG_MAP_EDITOR
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	UIThemes.set_margins(margin, 8, 8, 8, 8)
	add_child(margin)

	var main_vbox := VBoxContainer.new()
	main_vbox.add_theme_constant_override("separation", 4)
	margin.add_child(main_vbox)

	# === Top bar ===
	var top_bar := HBoxContainer.new()
	top_bar.add_theme_constant_override("separation", 8)
	main_vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_on_back)
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Map Editor"
	title.add_theme_font_size_override("font_size", 22)
	top_bar.add_child(title)

	_save_btn = Button.new()
	_save_btn.text = "Save Map"
	_save_btn.pressed.connect(_on_save_map)
	top_bar.add_child(_save_btn)

	_save_all_btn = Button.new()
	_save_all_btn.text = "Save All"
	_save_all_btn.pressed.connect(_on_save_all)
	top_bar.add_child(_save_all_btn)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	_status_label = Label.new()
	_status_label.add_theme_font_size_override("font_size", 14)
	top_bar.add_child(_status_label)

	# === Content (3 panels) ===
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 4)
	main_vbox.add_child(content)

	# Left panel: map list + element list
	_build_left_panel(content)

	# Center panel: toolbar + canvas + status bar
	_build_center_panel(content)

	# Right panel: properties
	_build_right_panel(content)

	# Hint bar
	var hint := Label.new()
	hint.text = "Left-click: Tool action | Right-drag: Orbit | Middle-drag: Pan | Scroll: Zoom | Del: Delete | Ctrl+Z/Y: Undo/Redo | Ctrl+S: Save | 1-5: Tools"
	hint.add_theme_font_size_override("font_size", 12)
	hint.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	main_vbox.add_child(hint)

	# Unsaved changes dialog
	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Unsaved Changes"
	_unsaved_dialog.dialog_text = "You have unsaved changes.\nWhat would you like to do?"
	_unsaved_dialog.ok_button_text = "Save All & Leave"
	@warning_ignore("return_value_discarded")
	_unsaved_dialog.add_button("Discard & Leave", true, "discard")
	_unsaved_dialog.confirmed.connect(_on_unsaved_save_and_leave)
	_unsaved_dialog.custom_action.connect(_on_unsaved_custom_action)
	add_child(_unsaved_dialog)


func _build_left_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 0.8
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 4)
	panel.add_child(vbox)

	# Section: Maps
	var maps_header := Label.new()
	maps_header.text = "Maps"
	maps_header.add_theme_font_size_override("font_size", 16)
	maps_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	vbox.add_child(maps_header)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_t: String) -> void: _rebuild_map_list())
	vbox.add_child(_search_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(scroll)

	_map_list_vbox = VBoxContainer.new()
	_map_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_map_list_vbox)

	# Buttons
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	vbox.add_child(btn_row)

	var new_btn := Button.new()
	new_btn.text = "+ New"
	new_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_btn.pressed.connect(_on_new_map)
	btn_row.add_child(new_btn)

	var dup_btn := Button.new()
	dup_btn.text = "Duplicate"
	dup_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dup_btn.pressed.connect(_on_duplicate_map)
	btn_row.add_child(dup_btn)

	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.pressed.connect(_on_delete_map)
	btn_row.add_child(del_btn)

	# Section separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	vbox.add_child(sep)

	# Section: Elements on current map
	var elem_header := Label.new()
	elem_header.text = "Elements"
	elem_header.add_theme_font_size_override("font_size", 16)
	elem_header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	vbox.add_child(elem_header)

	_rebuild_map_list()

	# Separator before asset palette
	var palette_sep := HSeparator.new()
	palette_sep.add_theme_constant_override("separation", 8)
	vbox.add_child(palette_sep)

	# Asset Palette
	_asset_palette = AssetPalette.new()
	_asset_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_asset_palette.asset_selected.connect(_on_asset_selected)
	vbox.add_child(_asset_palette)


func _build_center_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 3.0
	parent.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Toolbar
	var toolbar := HBoxContainer.new()
	toolbar.add_theme_constant_override("separation", 4)
	vbox.add_child(toolbar)

	# Tool buttons
	var tools_info: Array[Dictionary] = [
		{"name": "Select", "tool": MapViewport3D.Tool.SELECT},
		{"name": "Paint", "tool": MapViewport3D.Tool.PAINT},
		{"name": "Place", "tool": MapViewport3D.Tool.PLACE},
		{"name": "Scatter", "tool": MapViewport3D.Tool.SCATTER},
		{"name": "Connect", "tool": MapViewport3D.Tool.CONNECTION},
		{"name": "Battle", "tool": MapViewport3D.Tool.BATTLE_AREA},
	]
	for info in tools_info:
		var btn := Button.new()
		btn.text = info["name"]
		btn.toggle_mode = true
		btn.button_pressed = info["tool"] == MapViewport3D.Tool.SELECT
		var tool_val: int = info["tool"]
		btn.pressed.connect(func() -> void: _set_active_tool(tool_val))
		toolbar.add_child(btn)
		_tool_buttons[info["tool"]] = btn

	var tool_sep := VSeparator.new()
	toolbar.add_child(tool_sep)

	# Terrain palette (visible when Paint tool active)
	_terrain_palette = HBoxContainer.new()
	_terrain_palette.add_theme_constant_override("separation", 2)
	_terrain_palette.visible = false
	toolbar.add_child(_terrain_palette)

	var palette_label := Label.new()
	palette_label.text = "Block:"
	palette_label.add_theme_font_size_override("font_size", 13)
	_terrain_palette.add_child(palette_label)

	# Eraser button
	_eraser_btn = Button.new()
	_eraser_btn.text = "X"
	_eraser_btn.tooltip_text = "Eraser (remove terrain)"
	_eraser_btn.custom_minimum_size = Vector2(28, 28)
	_eraser_btn.toggle_mode = true
	var eraser_style := StyleBoxFlat.new()
	eraser_style.bg_color = Color(0.3, 0.15, 0.15)
	eraser_style.set_corner_radius_all(4)
	eraser_style.set_content_margin_all(0)
	_eraser_btn.add_theme_stylebox_override("normal", eraser_style)
	var eraser_pressed := StyleBoxFlat.new()
	eraser_pressed.bg_color = Color(0.5, 0.15, 0.15)
	eraser_pressed.set_corner_radius_all(4)
	eraser_pressed.set_content_margin_all(0)
	eraser_pressed.border_color = Color.WHITE
	eraser_pressed.set_border_width_all(3)
	_eraser_btn.add_theme_stylebox_override("pressed", eraser_pressed)
	_eraser_btn.pressed.connect(func() -> void: _set_paint_block(-1))
	_terrain_palette.add_child(_eraser_btn)

	# Block color buttons
	for i in range(MapLoader.BLOCK_COLORS.size()):
		var color_btn := Button.new()
		color_btn.custom_minimum_size = Vector2(28, 28)
		color_btn.tooltip_text = MapLoader.BLOCK_NAMES[i]
		var style := StyleBoxFlat.new()
		style.bg_color = MapLoader.BLOCK_COLORS[i]
		style.set_corner_radius_all(4)
		style.set_content_margin_all(0)
		color_btn.add_theme_stylebox_override("normal", style)
		var pressed_style := StyleBoxFlat.new()
		pressed_style.bg_color = MapLoader.BLOCK_COLORS[i]
		pressed_style.set_corner_radius_all(4)
		pressed_style.set_content_margin_all(0)
		pressed_style.border_color = Color.WHITE
		pressed_style.set_border_width_all(3)
		color_btn.add_theme_stylebox_override("pressed", pressed_style)
		color_btn.toggle_mode = true
		color_btn.button_pressed = (i == 0)
		var block_idx: int = i
		color_btn.pressed.connect(func() -> void: _set_paint_block(block_idx))
		_terrain_palette.add_child(color_btn)

	# Brush controls (size + shape)
	_brush_controls = HBoxContainer.new()
	_brush_controls.add_theme_constant_override("separation", 4)
	_brush_controls.visible = false
	toolbar.add_child(_brush_controls)

	var size_label := Label.new()
	size_label.text = "Size:"
	size_label.add_theme_font_size_override("font_size", 13)
	_brush_controls.add_child(size_label)

	var size_spin := SpinBox.new()
	size_spin.min_value = 1
	size_spin.max_value = 5
	size_spin.step = 1
	size_spin.value = 1
	size_spin.custom_minimum_size.x = 60
	size_spin.value_changed.connect(func(val: float) -> void:
		_viewport_3d.brush_size = int(val)
	)
	_brush_controls.add_child(size_spin)

	var shape_label := Label.new()
	shape_label.text = "Shape:"
	shape_label.add_theme_font_size_override("font_size", 13)
	_brush_controls.add_child(shape_label)

	var shape_picker := OptionButton.new()
	shape_picker.add_item("Square")
	shape_picker.add_item("Circle")
	shape_picker.item_selected.connect(func(idx: int) -> void:
		_viewport_3d.brush_shape = idx as MapViewport3D.BrushShape
	)
	_brush_controls.add_child(shape_picker)

	# Element picker (visible when Place tool active)
	_element_picker = OptionButton.new()
	_element_picker.visible = false
	for type_name in MapElement.ElementType.keys():
		_element_picker.add_item(type_name.capitalize().replace("_", " "))
	_element_picker.item_selected.connect(func(idx: int) -> void:
		_viewport_3d.place_element_type = idx
	)
	toolbar.add_child(_element_picker)

	# Placement options (visible when Place tool active)
	_place_options = HBoxContainer.new()
	_place_options.add_theme_constant_override("separation", 4)
	_place_options.visible = false
	toolbar.add_child(_place_options)

	var pscale_label := Label.new()
	pscale_label.text = "Scale:"
	pscale_label.add_theme_font_size_override("font_size", 13)
	_place_options.add_child(pscale_label)

	_place_scale_spin = SpinBox.new()
	_place_scale_spin.min_value = 0.01
	_place_scale_spin.max_value = 10.0
	_place_scale_spin.step = 0.01
	_place_scale_spin.value = 1.0
	_place_scale_spin.custom_minimum_size.x = 70
	_place_scale_spin.value_changed.connect(func(val: float) -> void:
		_viewport_3d._place_scale = val
		_viewport_3d._apply_ghost_scale()
	)
	_place_options.add_child(_place_scale_spin)

	_place_random_rot_cb = CheckBox.new()
	_place_random_rot_cb.text = "Rand Rot"
	_place_random_rot_cb.add_theme_font_size_override("font_size", 12)
	_place_random_rot_cb.toggled.connect(func(pressed: bool) -> void:
		_viewport_3d._place_random_rotation = pressed
	)
	_place_options.add_child(_place_random_rot_cb)

	_place_random_scale_cb = CheckBox.new()
	_place_random_scale_cb.text = "Rand Scale"
	_place_random_scale_cb.add_theme_font_size_override("font_size", 12)
	_place_random_scale_cb.toggled.connect(func(pressed: bool) -> void:
		_viewport_3d._place_random_scale = pressed
		_place_random_scale_min_spin.visible = pressed
		_place_random_scale_max_spin.visible = pressed
	)
	_place_options.add_child(_place_random_scale_cb)

	_place_random_scale_min_spin = SpinBox.new()
	_place_random_scale_min_spin.min_value = 0.01
	_place_random_scale_min_spin.max_value = 10.0
	_place_random_scale_min_spin.step = 0.01
	_place_random_scale_min_spin.value = 0.5
	_place_random_scale_min_spin.custom_minimum_size.x = 70
	_place_random_scale_min_spin.tooltip_text = "Min scale"
	_place_random_scale_min_spin.visible = false
	_place_random_scale_min_spin.value_changed.connect(func(val: float) -> void:
		_viewport_3d._place_random_scale_min = val
	)
	_place_options.add_child(_place_random_scale_min_spin)

	_place_random_scale_max_spin = SpinBox.new()
	_place_random_scale_max_spin.min_value = 0.01
	_place_random_scale_max_spin.max_value = 10.0
	_place_random_scale_max_spin.step = 0.01
	_place_random_scale_max_spin.value = 1.5
	_place_random_scale_max_spin.custom_minimum_size.x = 70
	_place_random_scale_max_spin.tooltip_text = "Max scale"
	_place_random_scale_max_spin.visible = false
	_place_random_scale_max_spin.value_changed.connect(func(val: float) -> void:
		_viewport_3d._place_random_scale_max = val
	)
	_place_options.add_child(_place_random_scale_max_spin)

	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	# 3D Viewport (replaces old 2D MapCanvas)
	_viewport_3d = MapViewport3D.new()
	vbox.add_child(_viewport_3d)

	# Connect viewport signals
	_viewport_3d.cell_painted.connect(_on_cell_painted)
	_viewport_3d.element_clicked.connect(_on_element_clicked)
	_viewport_3d.element_moved.connect(_on_element_moved)
	_viewport_3d.element_rotated.connect(_on_element_rotated)
	_viewport_3d.element_placed.connect(_on_element_placed)
	_viewport_3d.hover_changed.connect(_on_hover_changed)
	_viewport_3d.paint_stroke_ended.connect(_on_paint_stroke_ended)
	_viewport_3d.drag_started.connect(_on_drag_started)
	_viewport_3d.drag_ended.connect(_on_drag_ended)
	_viewport_3d.scatter_zone_drawn.connect(_on_scatter_zone_drawn)
	_viewport_3d.battle_area_placed.connect(_on_battle_area_placed)
	_viewport_3d.battle_area_clicked.connect(_on_battle_area_clicked)
	_viewport_3d.battle_area_moved.connect(_on_battle_area_moved)
	_viewport_3d.battle_area_drag_ended.connect(_on_battle_area_drag_ended)
	_viewport_3d.battle_area_rotated.connect(_on_battle_area_rotated)
	_viewport_3d.connection_placed.connect(_on_connection_placed)
	_viewport_3d.connection_clicked.connect(_on_connection_clicked)
	_viewport_3d.connection_moved.connect(_on_connection_moved)
	_viewport_3d.connection_drag_ended.connect(_on_connection_drag_ended)

	# Status bar
	_coord_label = Label.new()
	_coord_label.text = "X: -- Z: --"
	_coord_label.add_theme_font_size_override("font_size", 13)
	_coord_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(_coord_label)


func _build_right_panel(parent: HBoxContainer) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.0
	parent.add_child(panel)

	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)

	_property_vbox = VBoxContainer.new()
	_property_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_vbox.add_theme_constant_override("separation", 4)
	scroll.add_child(_property_vbox)

	_build_map_properties()


# === Map List ===

func _rebuild_map_list() -> void:
	for child in _map_list_vbox.get_children():
		child.queue_free()

	var search_text: String = _search_edit.text.strip_edges().to_lower() if _search_edit else ""
	var ids: Array = _maps.keys()
	ids.sort()

	for map_id in ids:
		var map: MapData = _maps[map_id]
		var display: String = map.display_name if not map.display_name.is_empty() else map.id
		if not search_text.is_empty() and search_text not in map.id.to_lower() and search_text not in display.to_lower():
			continue

		var label_text: String = display
		if _dirty_ids.has(map_id):
			label_text = "* " + label_text

		var btn := Button.new()
		btn.text = "  " + label_text
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		if map_id == _selected_map_id:
			btn.add_theme_color_override("font_color", Color.WHITE)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.5, 0.7, 0.5)
			style.set_content_margin_all(2)
			btn.add_theme_stylebox_override("normal", style)
		else:
			btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

		var captured_id: String = map_id
		btn.pressed.connect(func() -> void: _select_map(captured_id))
		_map_list_vbox.add_child(btn)


func _select_map(map_id: String) -> void:
	_selected_map_id = map_id
	_selected_element_idx = -1
	_undo_stack.clear()
	_redo_stack.clear()
	_current_paint_action = {}
	var map: MapData = _maps.get(map_id)
	if map:
		_viewport_3d.set_map(map)
		_viewport_3d.selected_element_index = -1
	_rebuild_map_list()
	if _viewport_3d.active_tool == MapViewport3D.Tool.SCATTER:
		_build_scatter_panel()
	elif _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
		_build_connection_list_panel()
	elif _viewport_3d.active_tool == MapViewport3D.Tool.BATTLE_AREA:
		_build_battle_area_panel()
	else:
		_build_map_properties()


func _mark_dirty() -> void:
	if not _selected_map_id.is_empty():
		_dirty_ids[_selected_map_id] = true
		_rebuild_map_list()


# === Tool switching ===

func _set_active_tool(tool_type: int) -> void:
	# Capture previous tool state before switching
	var was_scatter: bool = _viewport_3d.active_tool == MapViewport3D.Tool.SCATTER
	var was_connection: bool = _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION
	var was_battle_area: bool = _viewport_3d.active_tool == MapViewport3D.Tool.BATTLE_AREA

	# Clean up when leaving scatter mode
	if was_scatter and tool_type != MapViewport3D.Tool.SCATTER:
		_viewport_3d.clear_scatter_zone()
	# Clean up when leaving connection mode
	if was_connection and tool_type != MapViewport3D.Tool.CONNECTION:
		_viewport_3d.selected_connection_index = -1
	# Clean up when leaving battle area mode
	if was_battle_area and tool_type != MapViewport3D.Tool.BATTLE_AREA:
		_viewport_3d.selected_battle_area_index = -1

	_viewport_3d.active_tool = tool_type as MapViewport3D.Tool
	for t_key in _tool_buttons:
		var btn: Button = _tool_buttons[t_key]
		btn.button_pressed = (t_key == tool_type)
	var is_paint: bool = (tool_type == MapViewport3D.Tool.PAINT)
	_terrain_palette.visible = is_paint
	_brush_controls.visible = is_paint
	var is_place: bool = (tool_type == MapViewport3D.Tool.PLACE)
	_element_picker.visible = is_place
	_place_options.visible = is_place
	# Show/hide ghost previews based on tool
	_viewport_3d.update_ghost_visibility()
	_viewport_3d.update_connection_ghost_visibility()
	_viewport_3d.update_battle_area_ghost_visibility()
	# Show appropriate panel
	if tool_type == MapViewport3D.Tool.SCATTER:
		_build_scatter_panel()
	elif tool_type == MapViewport3D.Tool.CONNECTION:
		_build_connection_list_panel()
	elif tool_type == MapViewport3D.Tool.BATTLE_AREA:
		_build_battle_area_panel()
	elif was_scatter or was_connection or was_battle_area:
		_build_map_properties()


func _set_paint_block(block_idx: int) -> void:
	_viewport_3d.paint_block = block_idx
	# Update eraser toggle
	_eraser_btn.button_pressed = (block_idx == -1)
	# Update block color button states (children after label + eraser = offset 2)
	var buttons: Array[Node] = _terrain_palette.get_children()
	for i in range(buttons.size()):
		if buttons[i] is Button and buttons[i] != _eraser_btn:
			var btn: Button = buttons[i]
			btn.button_pressed = (i - 2 == block_idx)  # -2 for label + eraser


func _on_asset_selected(path: String, is_vox: bool) -> void:
	_viewport_3d.set_place_asset(path, is_vox)
	_set_active_tool(MapViewport3D.Tool.PLACE)
	# Auto-set element type based on asset
	var inferred_type: int = _infer_element_type(path)
	_viewport_3d.place_element_type = inferred_type
	_element_picker.select(inferred_type)


static func _infer_element_type(path: String) -> int:
	## Infers the MapElement.ElementType from a resource path.
	var fname: String = path.get_file().get_basename()
	if fname == "sign":
		return MapElement.ElementType.SIGN
	if fname == "fence":
		return MapElement.ElementType.FENCE
	if path.ends_with(".tscn") or path.ends_with(".vox"):
		return MapElement.ElementType.DECORATION
	return MapElement.ElementType.NPC


# === Viewport callbacks ===

func _on_cell_painted(grid_pos: Vector2i, block_type: int) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	# Record old value for undo (only first time this cell is painted in this stroke)
	var key: String = "%d,%d" % [grid_pos.x, grid_pos.y]
	if not _current_paint_action.has("cells"):
		_current_paint_action = { "type": "paint", "cells": {} }
	if not _current_paint_action["cells"].has(key):
		var old_val: int = map.get_terrain_at(grid_pos.x, grid_pos.y)
		_current_paint_action["cells"][key] = { "pos": grid_pos, "old": old_val, "new": block_type }
	else:
		_current_paint_action["cells"][key]["new"] = block_type
	map.set_terrain_at(grid_pos.x, grid_pos.y, block_type)
	_mark_dirty()


func _on_element_clicked(element_index: int) -> void:
	_selected_element_idx = element_index
	if element_index >= 0:
		_build_element_properties(element_index)
	else:
		_build_map_properties()


func _on_element_moved(element_index: int, new_pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and element_index >= 0 and element_index < map.elements.size():
		map.elements[element_index].position = new_pos


func _on_element_rotated(element_index: int, new_rotation_y: float) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and element_index >= 0 and element_index < map.elements.size():
		var old_rotation: float = map.elements[element_index].rotation_y
		map.elements[element_index].rotation_y = new_rotation_y
		_mark_dirty()
		if _selected_element_idx == element_index:
			_build_element_properties(element_index)
		# Batch consecutive rotations on the same element into one undo action
		if not _undo_stack.is_empty():
			var last: Dictionary = _undo_stack.back()
			if last.get("type") == "rotate" and last.get("element_index") == element_index:
				last["new_rotation"] = new_rotation_y
				_redo_stack.clear()
				return
		if old_rotation != new_rotation_y:
			_push_undo({
				"type": "rotate",
				"element_index": element_index,
				"old_rotation": old_rotation,
				"new_rotation": new_rotation_y,
			})


func _on_element_placed(world_pos: Vector2) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	var elem := MapElement.new()
	elem.element_type = _viewport_3d.place_element_type as MapElement.ElementType
	elem.position = Vector3(snappedf(world_pos.x, 0.5), 0, snappedf(world_pos.y, 0.5))

	# Rotation: random or manual
	if _viewport_3d._place_random_rotation:
		elem.rotation_y = _viewport_3d._rng.randf_range(0, TAU)
	else:
		elem.rotation_y = _viewport_3d._place_rotation

	# Scale: random between min/max or fixed
	if _viewport_3d._place_random_scale:
		elem.scale_factor = _viewport_3d._rng.randf_range(
			_viewport_3d._place_random_scale_min,
			_viewport_3d._place_random_scale_max
		)
	else:
		elem.scale_factor = _viewport_3d._place_scale

	# Use selected asset from palette if available
	var palette_path: String = _asset_palette.get_selected_path()
	if not palette_path.is_empty():
		elem.resource_id = palette_path
		# Ensure element type matches asset (safety net)
		if elem.element_type == MapElement.ElementType.NPC and (palette_path.ends_with(".tscn") or palette_path.ends_with(".vox")):
			elem.element_type = _infer_element_type(palette_path) as MapElement.ElementType
	else:
		# Fallback defaults
		match elem.element_type:
			MapElement.ElementType.SIGN:
				elem.resource_id = "res://scenes/world/objects/sign.tscn"
			MapElement.ElementType.FENCE:
				elem.resource_id = "res://scenes/world/objects/fence.tscn"
			MapElement.ElementType.DECORATION:
				if not _decoration_scene_names.is_empty():
					elem.resource_id = DECORATION_SCENES_DIR + _decoration_scene_names[0] + ".tscn"

	map.elements.append(elem)
	_mark_dirty()
	var new_idx: int = map.elements.size() - 1
	_viewport_3d.add_element_visual(elem, new_idx)
	_viewport_3d.selected_element_index = new_idx
	_selected_element_idx = new_idx
	_build_element_properties(_selected_element_idx)
	_push_undo({
		"type": "place",
		"element_index": new_idx,
		"element_data": elem.duplicate(),
	})


func _on_paint_stroke_ended() -> void:
	if _current_paint_action.has("cells") and not _current_paint_action["cells"].is_empty():
		var cells_dict: Dictionary = _current_paint_action["cells"]
		var cells_array: Array = cells_dict.values()
		_push_undo({ "type": "paint", "cells": cells_array })
	_current_paint_action = {}


func _on_drag_started(_element_index: int, start_pos: Vector3) -> void:
	_drag_original_pos = start_pos


func _on_drag_ended(element_index: int, end_pos: Vector3) -> void:
	if _drag_original_pos != end_pos:
		_push_undo({
			"type": "move",
			"element_index": element_index,
			"old_pos": _drag_original_pos,
			"new_pos": end_pos,
		})
		_mark_dirty()


func _on_hover_changed(grid_pos: Vector2i) -> void:
	if grid_pos.x >= 0 and grid_pos.y >= 0:
		var map: MapData = _maps.get(_selected_map_id)
		if map and grid_pos.x < map.grid_width and grid_pos.y < map.grid_height:
			var block: int = map.get_terrain_at(grid_pos.x, grid_pos.y)
			var block_name: String = MapLoader.BLOCK_NAMES[block] if block < MapLoader.BLOCK_NAMES.size() else "?"
			_coord_label.text = "X: %d  Z: %d  [%s]" % [grid_pos.x, grid_pos.y, block_name]
		else:
			_coord_label.text = "X: %d  Z: %d  [out of bounds]" % [grid_pos.x, grid_pos.y]
	else:
		_coord_label.text = "X: --  Z: --"


# === Property Panel ===

func _clear_property_panel() -> void:
	for child in _property_vbox.get_children():
		_property_vbox.remove_child(child)
		child.queue_free()


func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_property_vbox.add_child(label)


func _add_label(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	_property_vbox.add_child(label)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_property_vbox.add_child(sep)


func _build_map_properties() -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		_add_label("Select a map from the list.")
		return

	_add_section_header("Map Properties")

	_add_label("ID:")
	var id_edit := LineEdit.new()
	id_edit.text = map.id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.editable = false  # ID is immutable after creation
	_property_vbox.add_child(id_edit)

	_add_label("Display Name:")
	var name_edit := LineEdit.new()
	name_edit.text = map.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text: String) -> void:
		map.display_name = new_text
		_mark_dirty()
		_rebuild_map_list()
	)
	_property_vbox.add_child(name_edit)

	_add_separator()
	_add_label("Grid Size: %d x %d" % [map.grid_width, map.grid_height])

	_add_separator()
	_add_section_header("Player Spawn")

	var spawn_hbox := HBoxContainer.new()
	spawn_hbox.add_theme_constant_override("separation", 4)
	_property_vbox.add_child(spawn_hbox)

	_add_label("X:")
	var spawn_x := SpinBox.new()
	spawn_x.min_value = 0
	spawn_x.max_value = map.grid_width
	spawn_x.step = 0.5
	spawn_x.value = map.player_spawn.x
	spawn_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_x.value_changed.connect(func(val: float) -> void:
		map.player_spawn.x = val
		_mark_dirty()
	)
	_property_vbox.add_child(spawn_x)

	_add_label("Z:")
	var spawn_z := SpinBox.new()
	spawn_z.min_value = 0
	spawn_z.max_value = map.grid_height
	spawn_z.step = 0.5
	spawn_z.value = map.player_spawn.z
	spawn_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_z.value_changed.connect(func(val: float) -> void:
		map.player_spawn.z = val
		_mark_dirty()
	)
	_property_vbox.add_child(spawn_z)

	_add_separator()
	_add_section_header("Statistics")
	_add_label("Elements: %d" % map.elements.size())
	_add_label("Decoration Zones: %d" % map.decoration_zones.size())
	_add_label("Safe Zones: %d" % map.enemy_safe_zones.size())
	_add_label("Connections: %d" % map.connections.size())


func _build_element_properties(idx: int) -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.elements.size():
		_build_map_properties()
		return

	var elem: MapElement = map.elements[idx]
	_add_section_header("Element #%d" % idx)

	# Type (read-only)
	_add_label("Type: %s" % MapElement.ElementType.keys()[elem.element_type])

	_add_separator()
	_add_section_header("Position")

	_add_label("X:")
	var pos_x := SpinBox.new()
	pos_x.min_value = -10
	pos_x.max_value = 200
	pos_x.step = 0.5
	pos_x.value = elem.position.x
	pos_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var captured_idx: int = idx
	pos_x.value_changed.connect(func(val: float) -> void:
		elem.position.x = val
		_mark_dirty()
		if captured_idx < _viewport_3d._element_nodes.size():
			_viewport_3d._element_nodes[captured_idx].position.x = val
	)
	_property_vbox.add_child(pos_x)

	_add_label("Z:")
	var pos_z := SpinBox.new()
	pos_z.min_value = -10
	pos_z.max_value = 200
	pos_z.step = 0.5
	pos_z.value = elem.position.z
	pos_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pos_z.value_changed.connect(func(val: float) -> void:
		elem.position.z = val
		_mark_dirty()
		if captured_idx < _viewport_3d._element_nodes.size():
			_viewport_3d._element_nodes[captured_idx].position.z = val
	)
	_property_vbox.add_child(pos_z)

	_add_label("Rotation Y:")
	var rot_spin := SpinBox.new()
	rot_spin.min_value = -6.3
	rot_spin.max_value = 6.3
	rot_spin.step = 0.1
	rot_spin.value = elem.rotation_y
	rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_spin.value_changed.connect(func(val: float) -> void:
		elem.rotation_y = val
		_mark_dirty()
		if captured_idx < _viewport_3d._element_nodes.size():
			_viewport_3d._element_nodes[captured_idx].rotation.y = val
	)
	_property_vbox.add_child(rot_spin)

	_add_label("Scale:")
	var scale_spin := SpinBox.new()
	scale_spin.min_value = 0.1
	scale_spin.max_value = 10.0
	scale_spin.step = 0.1
	scale_spin.value = elem.scale_factor
	scale_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scale_spin.value_changed.connect(func(val: float) -> void:
		elem.scale_factor = val
		_mark_dirty()
		if captured_idx < _viewport_3d._element_nodes.size():
			_viewport_3d._element_nodes[captured_idx].scale = Vector3.ONE * val
	)
	_property_vbox.add_child(scale_spin)

	_add_separator()
	_add_section_header("Reference")

	# Type-specific reference picker
	match elem.element_type:
		MapElement.ElementType.NPC:
			_build_npc_picker(elem)
		MapElement.ElementType.ENEMY:
			_build_enemy_properties(elem)
		MapElement.ElementType.CHEST:
			_build_chest_picker(elem)
		MapElement.ElementType.LOCATION:
			_build_location_picker(elem)
		MapElement.ElementType.DECORATION:
			_build_decoration_picker(elem)
		MapElement.ElementType.SIGN:
			_add_label("Sign Label:")
			var sign_edit := LineEdit.new()
			sign_edit.text = elem.sign_label
			sign_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sign_edit.text_changed.connect(func(new_text: String) -> void:
				elem.sign_label = new_text
				_mark_dirty()
			)
			_property_vbox.add_child(sign_edit)
		MapElement.ElementType.FENCE:
			_add_label("(No additional properties)")

	_add_separator()

	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "Delete Element"
	delete_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	var del_idx: int = idx
	delete_btn.pressed.connect(func() -> void: _delete_element(del_idx))
	_property_vbox.add_child(delete_btn)


func _build_npc_picker(elem: MapElement) -> void:
	_add_label("NPC ID:")
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var npcs: Array = NpcDatabase.get_all_npcs()
	var selected_idx: int = 0
	for i in range(npcs.size()):
		var npc: NpcData = npcs[i]
		picker.add_item(npc.display_name if not npc.display_name.is_empty() else npc.id)
		if npc.id == elem.resource_id:
			selected_idx = i
	picker.selected = selected_idx
	picker.item_selected.connect(func(idx: int) -> void:
		if idx < npcs.size():
			elem.resource_id = npcs[idx].id
			_mark_dirty()
	)
	_property_vbox.add_child(picker)


func _build_enemy_properties(elem: MapElement) -> void:
	_add_label("Encounter Data:")
	var path_edit := LineEdit.new()
	path_edit.text = elem.resource_id
	path_edit.placeholder_text = "res://data/encounters/..."
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_changed.connect(func(new_text: String) -> void:
		elem.resource_id = new_text
		_mark_dirty()
	)
	_property_vbox.add_child(path_edit)

	# Scan available encounters for a quick picker
	var encounter_dir := DirAccess.open("res://data/encounters/")
	if encounter_dir:
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var enc_files: Array[String] = []
		encounter_dir.list_dir_begin()
		var fname := encounter_dir.get_next()
		while fname != "":
			if not encounter_dir.current_is_dir() and fname.ends_with(".tres"):
				enc_files.append(fname)
			fname = encounter_dir.get_next()
		encounter_dir.list_dir_end()
		enc_files.sort()

		var sel_idx: int = 0
		for i in range(enc_files.size()):
			var full_path: String = "res://data/encounters/" + enc_files[i]
			picker.add_item(enc_files[i].get_basename())
			if full_path == elem.resource_id:
				sel_idx = i
		picker.selected = sel_idx
		picker.item_selected.connect(func(idx: int) -> void:
			if idx < enc_files.size():
				elem.resource_id = "res://data/encounters/" + enc_files[idx]
				path_edit.text = elem.resource_id
				_mark_dirty()
		)
		_property_vbox.add_child(picker)

	_add_separator()
	_add_label("Patrol Distance:")
	var patrol_spin := SpinBox.new()
	patrol_spin.min_value = 0
	patrol_spin.max_value = 20
	patrol_spin.step = 0.5
	patrol_spin.value = elem.patrol_distance
	patrol_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	patrol_spin.value_changed.connect(func(val: float) -> void:
		elem.patrol_distance = val
		_mark_dirty()
	)
	_property_vbox.add_child(patrol_spin)


func _build_chest_picker(elem: MapElement) -> void:
	_add_label("Chest ID:")
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var chests: Array = ChestDatabase.get_all_chests()
	var selected_idx: int = 0
	for i in range(chests.size()):
		var chest: ChestData = chests[i]
		picker.add_item(chest.id)
		if chest.id == elem.resource_id:
			selected_idx = i
	picker.selected = selected_idx
	picker.item_selected.connect(func(idx: int) -> void:
		if idx < chests.size():
			elem.resource_id = chests[idx].id
			_mark_dirty()
	)
	_property_vbox.add_child(picker)


func _build_location_picker(elem: MapElement) -> void:
	_add_label("Location Data:")
	var path_edit := LineEdit.new()
	path_edit.text = elem.resource_id
	path_edit.placeholder_text = "res://data/locations/..."
	path_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	path_edit.text_changed.connect(func(new_text: String) -> void:
		elem.resource_id = new_text
		_mark_dirty()
	)
	_property_vbox.add_child(path_edit)

	# Quick picker from directory
	var loc_dir := DirAccess.open("res://data/locations/")
	if loc_dir:
		var picker := OptionButton.new()
		picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var loc_files: Array[String] = []
		loc_dir.list_dir_begin()
		var fname := loc_dir.get_next()
		while fname != "":
			if not loc_dir.current_is_dir() and fname.ends_with(".tres"):
				loc_files.append(fname)
			fname = loc_dir.get_next()
		loc_dir.list_dir_end()
		loc_files.sort()

		var sel_idx: int = 0
		for i in range(loc_files.size()):
			var full_path: String = "res://data/locations/" + loc_files[i]
			picker.add_item(loc_files[i].get_basename())
			if full_path == elem.resource_id:
				sel_idx = i
		picker.selected = sel_idx
		picker.item_selected.connect(func(idx: int) -> void:
			if idx < loc_files.size():
				elem.resource_id = "res://data/locations/" + loc_files[idx]
				path_edit.text = elem.resource_id
				_mark_dirty()
		)
		_property_vbox.add_child(picker)


func _build_decoration_picker(elem: MapElement) -> void:
	_add_label("Decoration Scene:")
	var picker := OptionButton.new()
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sel_idx: int = 0
	for i in range(_decoration_scene_names.size()):
		picker.add_item(_decoration_scene_names[i])
		var full_path: String = DECORATION_SCENES_DIR + _decoration_scene_names[i] + ".tscn"
		if full_path == elem.resource_id:
			sel_idx = i
	picker.selected = sel_idx
	picker.item_selected.connect(func(idx: int) -> void:
		if idx < _decoration_scene_names.size():
			elem.resource_id = DECORATION_SCENES_DIR + _decoration_scene_names[idx] + ".tscn"
			_mark_dirty()
	)
	_property_vbox.add_child(picker)


# === Scatter Tool ===

func _build_scatter_panel() -> void:
	_clear_property_panel()
	_add_section_header("Scatter Tool")

	# Status / instructions
	_scatter_status_label = Label.new()
	_scatter_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_scatter_status_label.add_theme_font_size_override("font_size", 13)
	_property_vbox.add_child(_scatter_status_label)
	_update_scatter_status()

	_add_separator()
	_add_section_header("Parameters")

	# Seed row
	var seed_hbox := HBoxContainer.new()
	seed_hbox.add_theme_constant_override("separation", 4)
	_property_vbox.add_child(seed_hbox)

	var seed_label := Label.new()
	seed_label.text = "Seed:"
	seed_label.add_theme_font_size_override("font_size", 13)
	seed_hbox.add_child(seed_label)

	_scatter_seed_spin = SpinBox.new()
	_scatter_seed_spin.min_value = 0
	_scatter_seed_spin.max_value = 999999
	_scatter_seed_spin.step = 1
	_scatter_seed_spin.value = 42
	_scatter_seed_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_hbox.add_child(_scatter_seed_spin)

	var randomize_btn := Button.new()
	randomize_btn.text = "Rand"
	randomize_btn.tooltip_text = "Randomize seed"
	randomize_btn.pressed.connect(func() -> void:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		_scatter_seed_spin.value = rng.randi_range(0, 999999)
	)
	seed_hbox.add_child(randomize_btn)

	# Count
	_add_label("Count:")
	_scatter_count_spin = SpinBox.new()
	_scatter_count_spin.min_value = 1
	_scatter_count_spin.max_value = 500
	_scatter_count_spin.step = 1
	_scatter_count_spin.value = 20
	_scatter_count_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_vbox.add_child(_scatter_count_spin)

	# Min spacing
	_add_label("Min Spacing:")
	_scatter_spacing_spin = SpinBox.new()
	_scatter_spacing_spin.min_value = 0.5
	_scatter_spacing_spin.max_value = 10.0
	_scatter_spacing_spin.step = 0.5
	_scatter_spacing_spin.value = 2.0
	_scatter_spacing_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_property_vbox.add_child(_scatter_spacing_spin)

	_add_separator()
	_add_section_header("Assets to Scatter")

	# Search filter
	_scatter_search_edit = LineEdit.new()
	_scatter_search_edit.placeholder_text = "Filter assets..."
	_scatter_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_search_edit.text_changed.connect(func(_t: String) -> void:
		_rebuild_scatter_asset_list()
	)
	_property_vbox.add_child(_scatter_search_edit)

	# Select All / Deselect All
	var sel_hbox := HBoxContainer.new()
	sel_hbox.add_theme_constant_override("separation", 4)
	_property_vbox.add_child(sel_hbox)

	var select_all_btn := Button.new()
	select_all_btn.text = "Select All"
	select_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	select_all_btn.pressed.connect(func() -> void:
		for cb_key in _scatter_asset_checkboxes:
			(_scatter_asset_checkboxes[cb_key] as CheckBox).button_pressed = true
	)
	sel_hbox.add_child(select_all_btn)

	var deselect_all_btn := Button.new()
	deselect_all_btn.text = "Deselect All"
	deselect_all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	deselect_all_btn.pressed.connect(func() -> void:
		for cb_key in _scatter_asset_checkboxes:
			(_scatter_asset_checkboxes[cb_key] as CheckBox).button_pressed = false
	)
	sel_hbox.add_child(deselect_all_btn)

	# Scrollable asset checkbox list
	var asset_scroll := ScrollContainer.new()
	asset_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	asset_scroll.custom_minimum_size.y = 150
	asset_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_property_vbox.add_child(asset_scroll)

	_scatter_asset_list_vbox = VBoxContainer.new()
	_scatter_asset_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_asset_list_vbox.add_theme_constant_override("separation", 1)
	asset_scroll.add_child(_scatter_asset_list_vbox)

	_rebuild_scatter_asset_list()

	_add_separator()

	# Action buttons
	_scatter_generate_btn = Button.new()
	_scatter_generate_btn.text = "Generate Preview"
	_scatter_generate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_generate_btn.pressed.connect(_on_scatter_generate)
	_property_vbox.add_child(_scatter_generate_btn)

	var action_hbox := HBoxContainer.new()
	action_hbox.add_theme_constant_override("separation", 4)
	_property_vbox.add_child(action_hbox)

	_scatter_accept_btn = Button.new()
	_scatter_accept_btn.text = "Accept"
	_scatter_accept_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scatter_accept_btn.add_theme_color_override("font_color", Color(0.3, 0.9, 0.3))
	_scatter_accept_btn.pressed.connect(_on_scatter_accept)
	_scatter_accept_btn.disabled = true
	action_hbox.add_child(_scatter_accept_btn)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	cancel_btn.pressed.connect(_on_scatter_cancel)
	action_hbox.add_child(cancel_btn)

	var clear_zone_btn := Button.new()
	clear_zone_btn.text = "Clear Zone"
	clear_zone_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clear_zone_btn.pressed.connect(func() -> void:
		_viewport_3d.clear_scatter_zone()
		_update_scatter_status()
		_scatter_accept_btn.disabled = true
	)
	_property_vbox.add_child(clear_zone_btn)


@warning_ignore("confusable_local_declaration")
func _rebuild_scatter_asset_list() -> void:
	# Preserve checked state
	var was_checked: Dictionary = {}
	for cb_path in _scatter_asset_checkboxes:
		was_checked[cb_path] = (_scatter_asset_checkboxes[cb_path] as CheckBox).button_pressed

	for child in _scatter_asset_list_vbox.get_children():
		child.queue_free()
	_scatter_asset_checkboxes.clear()

	var filter_text: String = ""
	if _scatter_search_edit:
		filter_text = _scatter_search_edit.text.strip_edges().to_lower()

	var assets: Array[Dictionary] = _get_scatter_assets()
	for asset in assets:
		var asset_name: String = asset["name"]
		if not filter_text.is_empty() and filter_text not in asset_name.to_lower():
			continue
		var cb := CheckBox.new()
		cb.text = asset_name
		cb.add_theme_font_size_override("font_size", 12)
		cb.button_pressed = was_checked.get(asset["path"], false)
		_scatter_asset_list_vbox.add_child(cb)
		_scatter_asset_checkboxes[asset["path"]] = cb


@warning_ignore("confusable_local_declaration")
func _get_scatter_assets() -> Array[Dictionary]:
	var assets: Array[Dictionary] = []
	# Scan scenes
	var scene_dir := DirAccess.open(DECORATION_SCENES_DIR)
	if scene_dir:
		scene_dir.list_dir_begin()
		var fname := scene_dir.get_next()
		while fname != "":
			if not scene_dir.current_is_dir() and fname.ends_with(".tscn"):
				assets.append({"name": fname.get_basename(), "path": DECORATION_SCENES_DIR + fname})
			fname = scene_dir.get_next()
		scene_dir.list_dir_end()
	# Scan voxels
	var vox_dir := DirAccess.open(AssetPalette.VOXELS_DIR)
	if vox_dir:
		vox_dir.list_dir_begin()
		var fname := vox_dir.get_next()
		while fname != "":
			if not vox_dir.current_is_dir() and fname.ends_with(".vox"):
				assets.append({"name": fname.get_basename() + " (vox)", "path": AssetPalette.VOXELS_DIR + fname})
			fname = vox_dir.get_next()
		vox_dir.list_dir_end()
	assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].naturalcasecmp_to(b["name"]) < 0
	)
	return assets


func _update_scatter_status() -> void:
	if not _scatter_status_label:
		return
	if not _viewport_3d._scatter_zone_defined:
		_scatter_status_label.text = "Click and drag on the map to draw a scatter zone."
		_scatter_status_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	elif _viewport_3d._scatter_has_preview:
		var item_count: int = _viewport_3d.get_scatter_preview_items().size()
		_scatter_status_label.text = "Preview: %d items. Accept or Cancel." % item_count
		_scatter_status_label.add_theme_color_override("font_color", Color(0.3, 0.9, 0.6))
	else:
		var r: Rect2 = _viewport_3d._scatter_zone_rect
		_scatter_status_label.text = "Zone: %.1f x %.1f\nSelect assets and click Generate." % [r.size.x, r.size.y]
		_scatter_status_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))


func _on_scatter_zone_drawn(_rect: Rect2) -> void:
	_update_scatter_status()


func _on_scatter_generate() -> void:
	if not _viewport_3d._scatter_zone_defined:
		_show_status("Draw a zone first!", Color(0.9, 0.7, 0.3))
		return

	var selected_paths: Array[String] = []
	for asset_path in _scatter_asset_checkboxes:
		var cb: CheckBox = _scatter_asset_checkboxes[asset_path]
		if cb.button_pressed:
			selected_paths.append(asset_path)

	if selected_paths.is_empty():
		_show_status("Select at least one asset!", Color(0.9, 0.7, 0.3))
		return

	var seed_val: int = int(_scatter_seed_spin.value)
	var count_val: int = int(_scatter_count_spin.value)
	var spacing_val: float = _scatter_spacing_spin.value

	var items: Array[Dictionary] = _viewport_3d.generate_scatter_preview(
		seed_val, count_val, spacing_val, selected_paths
	)

	_scatter_accept_btn.disabled = items.is_empty()
	_update_scatter_status()
	_show_status("Generated %d preview items" % items.size(), Color(0.2, 0.8, 0.3))


func _on_scatter_accept() -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return

	var items: Array[Dictionary] = _viewport_3d.get_scatter_preview_items()
	if items.is_empty():
		return

	# Convert each preview item to a permanent MapElement
	var start_idx: int = map.elements.size()
	var stored_items: Array[Dictionary] = []

	for item_data in items:
		var elem := MapElement.new()
		elem.element_type = MapElement.ElementType.DECORATION
		elem.position = item_data["position"]
		elem.rotation_y = item_data["rotation_y"]
		elem.resource_id = item_data["asset_path"]
		map.elements.append(elem)
		stored_items.append(item_data.duplicate())

	# Push batch undo action
	_push_undo({
		"type": "scatter",
		"start_index": start_idx,
		"count": stored_items.size(),
		"elements": stored_items,
	})

	# Clear preview and zone, rebuild element visuals
	_viewport_3d.clear_scatter_zone()
	_viewport_3d.refresh_elements()
	_mark_dirty()
	_build_scatter_panel()
	_show_status("Placed %d scatter items" % stored_items.size(), Color(0.2, 0.8, 0.3))


func _on_scatter_cancel() -> void:
	_viewport_3d.clear_scatter_preview()
	_update_scatter_status()
	if _scatter_accept_btn:
		_scatter_accept_btn.disabled = true


# === Battle Area tool ===

func _build_battle_area_panel() -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		_add_label("Select a map first.")
		return
	_add_section_header("Battle Areas")
	_add_label("Click map to place a battle area.\nDrag markers to reposition.")
	_add_separator()

	if map.battle_areas.is_empty():
		_add_label("(no battle areas)")
	else:
		for bi in range(map.battle_areas.size()):
			var area: BattleAreaData = map.battle_areas[bi]
			var btn := Button.new()
			var label_text: String = area.area_name if not area.area_name.is_empty() else "(unnamed)"
			label_text += " (%.0f, %.0f)" % [area.position.x, area.position.z]
			btn.text = "%d. %s" % [bi + 1, label_text]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_bi: int = bi
			btn.pressed.connect(func() -> void:
				_viewport_3d.selected_battle_area_index = captured_bi
				_build_battle_area_properties(captured_bi)
			)
			_property_vbox.add_child(btn)


func _build_battle_area_properties(idx: int) -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.battle_areas.size():
		_build_battle_area_panel()
		return
	var area: BattleAreaData = map.battle_areas[idx]
	_add_section_header("Battle Area #%d" % (idx + 1))
	_add_separator()

	# Name
	_add_label("Name:")
	var name_edit := LineEdit.new()
	name_edit.text = area.area_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "e.g. Forest Clearing"
	var captured_idx: int = idx
	name_edit.text_changed.connect(func(new_text: String) -> void:
		area.area_name = new_text
		_mark_dirty()
		_viewport_3d.refresh_battle_areas()
		_viewport_3d.selected_battle_area_index = captured_idx
	)
	_property_vbox.add_child(name_edit)

	# Position info (read-only)
	_add_label("Position: (%.1f, %.1f)" % [area.position.x, area.position.z])
	_add_label("Rotation: %.0f°" % rad_to_deg(area.rotation_y))
	_add_label("Arena radius: %.1f" % BattleAreaData.ARENA_RADIUS)
	_add_label("Ctrl+Scroll to rotate.")

	_add_separator()

	# Back button
	var back_btn := Button.new()
	back_btn.text = "Back to list"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		_viewport_3d.selected_battle_area_index = -1
		_build_battle_area_panel()
	)
	_property_vbox.add_child(back_btn)

	# Delete button
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	del_btn.add_theme_color_override("font_color", Color(1.0, 0.4, 0.4))
	del_btn.pressed.connect(func() -> void:
		map.battle_areas.remove_at(captured_idx)
		_mark_dirty()
		_viewport_3d.refresh_battle_areas()
		_build_battle_area_panel()
	)
	_property_vbox.add_child(del_btn)


func _on_battle_area_placed(pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	var area := BattleAreaData.new()
	area.area_name = "Battle Area %d" % (map.battle_areas.size() + 1)
	area.position = pos
	map.battle_areas.append(area)
	_mark_dirty()
	_viewport_3d.refresh_battle_areas()
	_build_battle_area_panel()
	_show_status("Placed battle area at (%.0f, %.0f)" % [pos.x, pos.z], Color(0.2, 0.8, 0.3))


func _on_battle_area_clicked(area_index: int) -> void:
	_viewport_3d.selected_battle_area_index = area_index
	_build_battle_area_properties(area_index)


func _on_battle_area_moved(area_index: int, new_pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and area_index >= 0 and area_index < map.battle_areas.size():
		map.battle_areas[area_index].position = new_pos
		_mark_dirty()


func _on_battle_area_drag_ended(area_index: int, end_pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and area_index >= 0 and area_index < map.battle_areas.size():
		map.battle_areas[area_index].position = end_pos
		_mark_dirty()
		_build_battle_area_properties(area_index)


func _on_battle_area_rotated(area_index: int, new_rotation_y: float) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and area_index >= 0 and area_index < map.battle_areas.size():
		map.battle_areas[area_index].rotation_y = new_rotation_y
		_mark_dirty()
		_build_battle_area_properties(area_index)


# === Connection tool ===

func _build_connection_list_panel() -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		_add_label("Select a map first.")
		return
	_add_section_header("Connections")
	_add_label("Click map to place a connection point.")
	_add_separator()
	if map.connections.is_empty():
		_add_label("(no connections)")
	else:
		for ci in range(map.connections.size()):
			var conn: MapConnection = map.connections[ci]
			var btn := Button.new()
			var label_text: String = conn.display_name if not conn.display_name.is_empty() else "(unnamed)"
			if not conn.target_map_id.is_empty():
				label_text += " → " + conn.target_map_id
			btn.text = "%d. %s" % [ci + 1, label_text]
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var captured_ci: int = ci
			btn.pressed.connect(func() -> void:
				_viewport_3d.selected_connection_index = captured_ci
				_selected_connection_idx = captured_ci
				_build_connection_properties(captured_ci)
			)
			_property_vbox.add_child(btn)


func _build_connection_properties(idx: int) -> void:
	_clear_property_panel()
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.connections.size():
		_build_connection_list_panel()
		return
	var conn: MapConnection = map.connections[idx]
	_add_section_header("Connection #%d" % idx)
	_add_separator()

	# Display Name
	_add_label("Display Name:")
	var name_edit := LineEdit.new()
	name_edit.text = conn.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.placeholder_text = "e.g. Enter Dark Cave"
	var captured_idx: int = idx
	name_edit.text_changed.connect(func(new_text: String) -> void:
		conn.display_name = new_text
		_mark_dirty()
		_viewport_3d.refresh_connections()
		_viewport_3d.selected_connection_index = captured_idx
	)
	_property_vbox.add_child(name_edit)

	# Target Map
	_add_label("Target Map:")
	var map_picker := OptionButton.new()
	map_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_picker.add_item("(none)")
	var all_map_ids: Array = _maps.keys()
	all_map_ids.sort()
	var selected_map_idx: int = 0
	for mi in range(all_map_ids.size()):
		var mid: String = all_map_ids[mi]
		map_picker.add_item(mid)
		if mid == conn.target_map_id:
			selected_map_idx = mi + 1  # +1 for "(none)" at index 0
	map_picker.select(selected_map_idx)
	map_picker.item_selected.connect(func(sel_idx: int) -> void:
		if sel_idx == 0:
			conn.target_map_id = ""
		else:
			conn.target_map_id = all_map_ids[sel_idx - 1]
		_mark_dirty()
		_viewport_3d.refresh_connections()
		_viewport_3d.selected_connection_index = captured_idx
	)
	_property_vbox.add_child(map_picker)

	_add_separator()
	_add_section_header("Target Spawn")

	_add_label("X:")
	var spawn_x := SpinBox.new()
	spawn_x.min_value = -10
	spawn_x.max_value = 200
	spawn_x.step = 0.5
	spawn_x.value = conn.target_spawn.x
	spawn_x.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_x.value_changed.connect(func(val: float) -> void:
		conn.target_spawn.x = val
		_mark_dirty()
	)
	_property_vbox.add_child(spawn_x)

	_add_label("Z:")
	var spawn_z := SpinBox.new()
	spawn_z.min_value = -10
	spawn_z.max_value = 200
	spawn_z.step = 0.5
	spawn_z.value = conn.target_spawn.z
	spawn_z.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spawn_z.value_changed.connect(func(val: float) -> void:
		conn.target_spawn.z = val
		_mark_dirty()
	)
	_property_vbox.add_child(spawn_z)

	_add_separator()
	_add_section_header("Unlock")

	_add_label("Unlock Flag:")
	var flag_edit := LineEdit.new()
	flag_edit.text = conn.unlock_flag
	flag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_edit.placeholder_text = "empty = always open"
	flag_edit.text_changed.connect(func(new_text: String) -> void:
		conn.unlock_flag = new_text
		_mark_dirty()
	)
	_property_vbox.add_child(flag_edit)

	_add_separator()
	_add_section_header("Position")
	_add_label("X: %.1f  Z: %.1f" % [conn.position.x, conn.position.z])

	_add_separator()
	# Delete button
	var delete_btn := Button.new()
	delete_btn.text = "Delete Connection"
	delete_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	delete_btn.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	delete_btn.pressed.connect(func() -> void: _delete_connection(captured_idx))
	_property_vbox.add_child(delete_btn)

	# Back to list button
	var back_btn := Button.new()
	back_btn.text = "Back to List"
	back_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_btn.pressed.connect(func() -> void:
		_viewport_3d.selected_connection_index = -1
		_selected_connection_idx = -1
		_build_connection_list_panel()
	)
	_property_vbox.add_child(back_btn)


func _on_connection_placed(pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	var conn := MapConnection.new()
	conn.position = pos
	conn.display_name = "Connection"
	map.connections.append(conn)
	var new_idx: int = map.connections.size() - 1
	_mark_dirty()
	_viewport_3d.refresh_connections()
	_viewport_3d.selected_connection_index = new_idx
	_selected_connection_idx = new_idx
	_build_connection_properties(new_idx)
	_push_undo({
		"type": "add_connection",
		"index": new_idx,
		"connection_data": {
			"position": conn.position,
			"target_map_id": conn.target_map_id,
			"target_spawn": conn.target_spawn,
			"display_name": conn.display_name,
			"unlock_flag": conn.unlock_flag,
		},
	})


func _on_connection_clicked(conn_index: int) -> void:
	_selected_connection_idx = conn_index
	if conn_index >= 0:
		_build_connection_properties(conn_index)
		_connection_drag_original_pos = _viewport_3d._connection_nodes[conn_index].position
	else:
		_build_connection_list_panel()


func _on_connection_moved(conn_index: int, new_pos: Vector3) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map and conn_index >= 0 and conn_index < map.connections.size():
		map.connections[conn_index].position = new_pos


func _on_connection_drag_ended(conn_index: int, end_pos: Vector3) -> void:
	if _connection_drag_original_pos != end_pos:
		_push_undo({
			"type": "move_connection",
			"index": conn_index,
			"old_pos": _connection_drag_original_pos,
			"new_pos": end_pos,
		})
		var map: MapData = _maps.get(_selected_map_id)
		if map and conn_index >= 0 and conn_index < map.connections.size():
			map.connections[conn_index].position = end_pos
		_mark_dirty()
		if _selected_connection_idx == conn_index:
			_build_connection_properties(conn_index)


func _delete_connection(idx: int) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.connections.size():
		return
	var conn: MapConnection = map.connections[idx]
	_push_undo({
		"type": "delete_connection",
		"index": idx,
		"connection_data": {
			"position": conn.position,
			"target_map_id": conn.target_map_id,
			"target_spawn": conn.target_spawn,
			"display_name": conn.display_name,
			"unlock_flag": conn.unlock_flag,
		},
	})
	map.connections.remove_at(idx)
	_selected_connection_idx = -1
	_viewport_3d.selected_connection_index = -1
	_mark_dirty()
	_viewport_3d.refresh_connections()
	_build_connection_list_panel()


# === Undo / Redo ===

func _push_undo(action: Dictionary) -> void:
	_undo_stack.append(action)
	if _undo_stack.size() > MAX_UNDO:
		_undo_stack.pop_front()
	_redo_stack.clear()


func _undo() -> void:
	if _undo_stack.is_empty():
		return
	var action: Dictionary = _undo_stack.pop_back()
	_apply_action(action, true)
	_redo_stack.append(action)


func _redo() -> void:
	if _redo_stack.is_empty():
		return
	var action: Dictionary = _redo_stack.pop_back()
	_apply_action(action, false)
	_undo_stack.append(action)


@warning_ignore("confusable_local_declaration")
func _apply_action(action: Dictionary, is_undo: bool) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	var action_type: String = action.get("type", "")
	match action_type:
		"paint":
			var cells: Array = action["cells"]
			for cell_data in cells:
				var pos: Vector2i = cell_data["pos"]
				var val: int
				if is_undo:
					val = cell_data["old"]
				else:
					val = cell_data["new"]
				map.set_terrain_at(pos.x, pos.y, val)
				_viewport_3d.set_terrain_cell(pos, val)
		"move":
			var elem_idx: int = action["element_index"]
			var target_pos: Vector3
			if is_undo:
				target_pos = action["old_pos"]
			else:
				target_pos = action["new_pos"]
			if elem_idx >= 0 and elem_idx < map.elements.size():
				map.elements[elem_idx].position = target_pos
				if elem_idx < _viewport_3d._element_nodes.size():
					_viewport_3d._element_nodes[elem_idx].position = target_pos
				if _selected_element_idx == elem_idx:
					_build_element_properties(elem_idx)
		"rotate":
			var elem_idx: int = action["element_index"]
			var target_rot: float
			if is_undo:
				target_rot = action["old_rotation"]
			else:
				target_rot = action["new_rotation"]
			if elem_idx >= 0 and elem_idx < map.elements.size():
				map.elements[elem_idx].rotation_y = target_rot
				if elem_idx < _viewport_3d._element_nodes.size():
					_viewport_3d._element_nodes[elem_idx].rotation.y = target_rot
				if _selected_element_idx == elem_idx:
					_build_element_properties(elem_idx)
		"place":
			var elem_idx: int = action["element_index"]
			if is_undo:
				if elem_idx >= 0 and elem_idx < map.elements.size():
					map.elements.remove_at(elem_idx)
					_selected_element_idx = -1
					_viewport_3d.selected_element_index = -1
					_viewport_3d.refresh_elements()
					_build_map_properties()
			else:
				var elem: MapElement = action["element_data"].duplicate()
				if elem_idx <= map.elements.size():
					map.elements.insert(elem_idx, elem)
				else:
					map.elements.append(elem)
				_viewport_3d.refresh_elements()
				_viewport_3d.selected_element_index = elem_idx
				_selected_element_idx = elem_idx
				_build_element_properties(elem_idx)
		"delete":
			var elem_idx: int = action["element_index"]
			if is_undo:
				var elem: MapElement = action["element_data"].duplicate()
				if elem_idx <= map.elements.size():
					map.elements.insert(elem_idx, elem)
				else:
					map.elements.append(elem)
				_viewport_3d.refresh_elements()
				_viewport_3d.selected_element_index = elem_idx
				_selected_element_idx = elem_idx
				_build_element_properties(elem_idx)
			else:
				if elem_idx >= 0 and elem_idx < map.elements.size():
					map.elements.remove_at(elem_idx)
					_selected_element_idx = -1
					_viewport_3d.selected_element_index = -1
					_viewport_3d.refresh_elements()
					_build_map_properties()
		"scatter":
			var start_idx: int = action["start_index"]
			var count_val: int = action["count"]
			if is_undo:
				# Remove the batch (backwards to preserve indices)
				for i in range(count_val):
					var remove_idx: int = start_idx + count_val - 1 - i
					if remove_idx >= 0 and remove_idx < map.elements.size():
						map.elements.remove_at(remove_idx)
				_selected_element_idx = -1
				_viewport_3d.selected_element_index = -1
				_viewport_3d.refresh_elements()
				if _viewport_3d.active_tool == MapViewport3D.Tool.SCATTER:
					_build_scatter_panel()
				else:
					_build_map_properties()
			else:
				# Re-insert the elements
				var elements_data: Array = action["elements"]
				for i in range(elements_data.size()):
					var item_data: Dictionary = elements_data[i]
					var elem := MapElement.new()
					elem.element_type = MapElement.ElementType.DECORATION
					elem.position = item_data["position"]
					elem.rotation_y = item_data["rotation_y"]
					elem.resource_id = item_data["asset_path"]
					if start_idx + i <= map.elements.size():
						map.elements.insert(start_idx + i, elem)
					else:
						map.elements.append(elem)
				_viewport_3d.refresh_elements()
		"add_connection":
			var conn_idx: int = action["index"]
			if is_undo:
				if conn_idx >= 0 and conn_idx < map.connections.size():
					map.connections.remove_at(conn_idx)
				_selected_connection_idx = -1
				_viewport_3d.selected_connection_index = -1
				_viewport_3d.refresh_connections()
				if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
					_build_connection_list_panel()
			else:
				var conn_data: Dictionary = action["connection_data"]
				var conn := MapConnection.new()
				conn.position = conn_data["position"]
				conn.target_map_id = conn_data["target_map_id"]
				conn.target_spawn = conn_data["target_spawn"]
				conn.display_name = conn_data["display_name"]
				conn.unlock_flag = conn_data["unlock_flag"]
				if conn_idx <= map.connections.size():
					map.connections.insert(conn_idx, conn)
				else:
					map.connections.append(conn)
				_viewport_3d.refresh_connections()
				_viewport_3d.selected_connection_index = conn_idx
				_selected_connection_idx = conn_idx
				if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
					_build_connection_properties(conn_idx)
		"delete_connection":
			var conn_idx: int = action["index"]
			if is_undo:
				var conn_data: Dictionary = action["connection_data"]
				var conn := MapConnection.new()
				conn.position = conn_data["position"]
				conn.target_map_id = conn_data["target_map_id"]
				conn.target_spawn = conn_data["target_spawn"]
				conn.display_name = conn_data["display_name"]
				conn.unlock_flag = conn_data["unlock_flag"]
				if conn_idx <= map.connections.size():
					map.connections.insert(conn_idx, conn)
				else:
					map.connections.append(conn)
				_viewport_3d.refresh_connections()
				_viewport_3d.selected_connection_index = conn_idx
				_selected_connection_idx = conn_idx
				if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
					_build_connection_properties(conn_idx)
			else:
				if conn_idx >= 0 and conn_idx < map.connections.size():
					map.connections.remove_at(conn_idx)
				_selected_connection_idx = -1
				_viewport_3d.selected_connection_index = -1
				_viewport_3d.refresh_connections()
				if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
					_build_connection_list_panel()
		"move_connection":
			var conn_idx: int = action["index"]
			var target_pos: Vector3
			if is_undo:
				target_pos = action["old_pos"]
			else:
				target_pos = action["new_pos"]
			if conn_idx >= 0 and conn_idx < map.connections.size():
				map.connections[conn_idx].position = target_pos
				_viewport_3d.refresh_connections()
				_viewport_3d.selected_connection_index = conn_idx
				if _selected_connection_idx == conn_idx:
					_build_connection_properties(conn_idx)
	_mark_dirty()


# === Element operations ===

func _delete_element(idx: int) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.elements.size():
		return
	var deleted_elem: MapElement = map.elements[idx].duplicate()
	_push_undo({
		"type": "delete",
		"element_index": idx,
		"element_data": deleted_elem,
	})
	map.elements.remove_at(idx)
	_selected_element_idx = -1
	_viewport_3d.selected_element_index = -1
	_mark_dirty()
	_viewport_3d.refresh_elements()
	_build_map_properties()


# === Map CRUD ===

func _on_new_map() -> void:
	var new_id: String = "new_map_%d" % Time.get_ticks_msec()
	var map := MapData.new()
	map.id = new_id
	map.display_name = "New Map"
	map.grid_width = 40
	map.grid_height = 30
	map.initialize_terrain(0)
	map.player_spawn = Vector3(20, 0, 15)
	_maps[new_id] = map
	_dirty_ids[new_id] = true
	_select_map(new_id)


func _on_duplicate_map() -> void:
	if _selected_map_id.is_empty():
		return
	var source: MapData = _maps.get(_selected_map_id)
	if not source:
		return
	var copy: MapData = source.duplicate(true) as MapData
	copy.id = source.id + "_copy"
	copy.display_name = source.display_name + " (Copy)"
	_maps[copy.id] = copy
	_dirty_ids[copy.id] = true
	_select_map(copy.id)


func _on_delete_map() -> void:
	if _selected_map_id.is_empty():
		return
	_maps.erase(_selected_map_id)
	_dirty_ids.erase(_selected_map_id)
	_selected_map_id = ""
	_viewport_3d.set_map(null)
	_rebuild_map_list()
	_build_map_properties()


# === Save / Load ===

func _on_save_map() -> void:
	if _selected_map_id.is_empty():
		_show_status("No map selected", Color(0.9, 0.7, 0.3))
		return
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	if _save_single_map(map):
		_dirty_ids.erase(_selected_map_id)
		_show_status("Saved: %s" % map.id, Color(0.2, 0.8, 0.3))
		_rebuild_map_list()
	else:
		_show_status("Save failed: %s" % map.id, Color(0.9, 0.3, 0.3))


func _on_save_all() -> void:
	var success_count: int = 0
	var fail_count: int = 0
	for map_key in _maps:
		var map: MapData = _maps[map_key]
		if _save_single_map(map):
			success_count += 1
		else:
			fail_count += 1
	_dirty_ids.clear()
	_rebuild_map_list()
	if fail_count == 0:
		_show_status("Saved all %d maps" % success_count, Color(0.2, 0.8, 0.3))
	else:
		_show_status("Saved %d, failed %d" % [success_count, fail_count], Color(0.9, 0.7, 0.3))


func _save_single_map(map: MapData) -> bool:
	@warning_ignore("return_value_discarded")
	DirAccess.make_dir_recursive_absolute("res://data/maps/")
	var file_path: String = "res://data/maps/" + map.id + ".tres"
	var err := ResourceSaver.save(map, file_path)
	if err == OK:
		MapDatabase.reload()
		return true
	return false


# === Navigation ===

func _on_back() -> void:
	if not _dirty_ids.is_empty():
		_unsaved_dialog.popup_centered()
		return
	SceneManager.pop_scene()


func _on_unsaved_save_and_leave() -> void:
	_on_save_all()
	SceneManager.pop_scene()


func _on_unsaved_custom_action(action: StringName) -> void:
	if action == "discard":
		_unsaved_dialog.hide()
		SceneManager.pop_scene()


func _show_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	# Auto-clear after 3 seconds
	var timer := get_tree().create_timer(3.0)
	await timer.timeout
	if is_inside_tree():
		_status_label.text = ""


# === Keyboard shortcuts ===

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_undo()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_Y:
			_redo()
			get_viewport().set_input_as_handled()
		elif event.ctrl_pressed and event.keycode == KEY_S:
			_on_save_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION and _selected_connection_idx >= 0:
				_delete_connection(_selected_connection_idx)
				get_viewport().set_input_as_handled()
			elif _selected_element_idx >= 0:
				_delete_element(_selected_element_idx)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_1:
			_set_active_tool(MapViewport3D.Tool.SELECT)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			_set_active_tool(MapViewport3D.Tool.PAINT)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			_set_active_tool(MapViewport3D.Tool.PLACE)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_4:
			_set_active_tool(MapViewport3D.Tool.SCATTER)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_5:
			_set_active_tool(MapViewport3D.Tool.CONNECTION)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_6:
			_set_active_tool(MapViewport3D.Tool.BATTLE_AREA)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_ESCAPE:
			if _viewport_3d.active_tool == MapViewport3D.Tool.CONNECTION:
				_viewport_3d.selected_connection_index = -1
				_selected_connection_idx = -1
				_build_connection_list_panel()
				get_viewport().set_input_as_handled()
			elif _viewport_3d.active_tool == MapViewport3D.Tool.SCATTER:
				_viewport_3d.clear_scatter_zone()
				_update_scatter_status()
				if _scatter_accept_btn:
					_scatter_accept_btn.disabled = true
				get_viewport().set_input_as_handled()
