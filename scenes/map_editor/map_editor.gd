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
var _canvas: MapCanvas
var _property_vbox: VBoxContainer
var _status_label: Label
var _save_btn: Button
var _save_all_btn: Button
var _tool_buttons: Dictionary = {}  # Tool enum -> Button
var _terrain_palette: HBoxContainer
var _element_picker: OptionButton
var _zoom_label: Label
var _coord_label: Label
var _unsaved_dialog: ConfirmationDialog

# Cached decoration scene list
var _decoration_scene_names: Array[String] = []


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
	hint.text = "Middle-click: Pan | Scroll: Zoom | Left-click: Paint/Select/Place | Del: Delete element | Ctrl+S: Save"
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
		{"name": "Select", "tool": MapCanvas.Tool.SELECT},
		{"name": "Paint", "tool": MapCanvas.Tool.PAINT},
		{"name": "Place", "tool": MapCanvas.Tool.PLACE},
	]
	for info in tools_info:
		var btn := Button.new()
		btn.text = info["name"]
		btn.toggle_mode = true
		btn.button_pressed = info["tool"] == MapCanvas.Tool.SELECT
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

	# Element picker (visible when Place tool active)
	_element_picker = OptionButton.new()
	_element_picker.visible = false
	for type_name in MapElement.ElementType.keys():
		_element_picker.add_item(type_name.capitalize().replace("_", " "))
	_element_picker.item_selected.connect(func(idx: int) -> void:
		_canvas.place_element_type = idx
	)
	toolbar.add_child(_element_picker)

	var toolbar_spacer := Control.new()
	toolbar_spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	toolbar.add_child(toolbar_spacer)

	_zoom_label = Label.new()
	_zoom_label.text = "Zoom: 50%"
	_zoom_label.add_theme_font_size_override("font_size", 13)
	toolbar.add_child(_zoom_label)

	# Canvas
	_canvas = MapCanvas.new()
	_canvas.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_canvas.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_child(_canvas)

	# Connect canvas signals
	_canvas.cell_painted.connect(_on_cell_painted)
	_canvas.element_clicked.connect(_on_element_clicked)
	_canvas.element_moved.connect(_on_element_moved)
	_canvas.element_placed.connect(_on_element_placed)
	_canvas.hover_changed.connect(_on_hover_changed)
	_canvas.zoom_changed.connect(_on_zoom_changed)

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
	var map: MapData = _maps.get(map_id)
	if map:
		_canvas.set_map(map)
		_canvas.selected_element_index = -1
	_rebuild_map_list()
	_build_map_properties()


func _mark_dirty() -> void:
	if not _selected_map_id.is_empty():
		_dirty_ids[_selected_map_id] = true
		_rebuild_map_list()


# === Tool switching ===

func _set_active_tool(tool_type: int) -> void:
	_canvas.active_tool = tool_type as MapCanvas.Tool
	for t_key in _tool_buttons:
		var btn: Button = _tool_buttons[t_key]
		btn.button_pressed = (t_key == tool_type)
	_terrain_palette.visible = (tool_type == MapCanvas.Tool.PAINT)
	_element_picker.visible = (tool_type == MapCanvas.Tool.PLACE)


func _set_paint_block(block_idx: int) -> void:
	_canvas.paint_block = block_idx
	# Update palette button states
	var buttons: Array[Node] = _terrain_palette.get_children()
	for i in range(buttons.size()):
		if buttons[i] is Button:
			var btn: Button = buttons[i]
			btn.button_pressed = (i - 1 == block_idx)  # -1 because label is first child


# === Canvas callbacks ===

func _on_cell_painted(grid_pos: Vector2i, block_type: int) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if map:
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
		_mark_dirty()
		if _selected_element_idx == element_index:
			_build_element_properties(element_index)


func _on_element_placed(world_pos: Vector2) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map:
		return
	var elem := MapElement.new()
	elem.element_type = _canvas.place_element_type as MapElement.ElementType
	elem.position = Vector3(snappedf(world_pos.x, 0.5), 0, snappedf(world_pos.y, 0.5))

	# Set default resource_id based on type
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
	_canvas.selected_element_index = map.elements.size() - 1
	_selected_element_idx = map.elements.size() - 1
	_build_element_properties(_selected_element_idx)
	_canvas.queue_redraw()


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


func _on_zoom_changed(zoom_level: float) -> void:
	_zoom_label.text = "Zoom: %d%%" % int(zoom_level * 100)


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
		_canvas.queue_redraw()
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
		_canvas.queue_redraw()
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
	pos_x.value_changed.connect(func(val: float) -> void:
		elem.position.x = val
		_mark_dirty()
		_canvas.queue_redraw()
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
		_canvas.queue_redraw()
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
	)
	_property_vbox.add_child(rot_spin)

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
	var captured_idx: int = idx
	delete_btn.pressed.connect(func() -> void: _delete_element(captured_idx))
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


# === Element operations ===

func _delete_element(idx: int) -> void:
	var map: MapData = _maps.get(_selected_map_id)
	if not map or idx < 0 or idx >= map.elements.size():
		return
	map.elements.remove_at(idx)
	_selected_element_idx = -1
	_canvas.selected_element_index = -1
	_mark_dirty()
	_canvas.queue_redraw()
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
	_canvas.set_map(null)
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
		if event.ctrl_pressed and event.keycode == KEY_S:
			_on_save_map()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_DELETE:
			if _selected_element_idx >= 0:
				_delete_element(_selected_element_idx)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_1:
			_set_active_tool(MapCanvas.Tool.SELECT)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_2:
			_set_active_tool(MapCanvas.Tool.PAINT)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_3:
			_set_active_tool(MapCanvas.Tool.PLACE)
			get_viewport().set_input_as_handled()
