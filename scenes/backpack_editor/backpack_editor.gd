extends Control
## In-game backpack tier editor. Paint tier assignments on a 25×25 master grid.
## Accessible from the main menu — no game session required.
## Left-click a cell to raise its tier, right-click to lower it.

const GRID_SIZE := 25
const CELL_PX := 36
const SYMBOLS: Array[String] = [
	"x", "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "a",
]
const SYMBOL_COLORS: Dictionary = {
	"x": Color(0.12, 0.12, 0.15, 0.4),
	"0": Color(0.2, 0.8, 0.3, 0.9),
	"1": Color(0.4, 0.7, 0.3, 0.9),
	"2": Color(0.9, 0.9, 0.2, 0.9),
	"3": Color(0.9, 0.7, 0.1, 0.9),
	"4": Color(0.9, 0.5, 0.1, 0.9),
	"5": Color(0.9, 0.3, 0.1, 0.9),
	"6": Color(0.8, 0.2, 0.2, 0.9),
	"7": Color(0.7, 0.1, 0.3, 0.9),
	"8": Color(0.6, 0.1, 0.5, 0.9),
	"9": Color(0.5, 0.1, 0.7, 0.9),
	"a": Color(0.3, 0.1, 0.8, 0.9),
}
const TIER_DIR := "res://data/backpack_tiers/"

var _matrix: Array = []  # Array[Array[String]] — 25x25
var _cell_panels: Dictionary = {}  # Vector2i -> PanelContainer
var _cell_labels: Dictionary = {}  # Vector2i -> Label
var _current_char_id: String = ""
var _char_buttons: Dictionary = {}  # char_id -> Button
var _dirty: bool = false
var _undo_stack: Array = []  # Array of {pos: Vector2i, old: String}

var _stats_label: Label
var _char_name_label: Label
var _status_label: Label
var _unsaved_dialog: ConfirmationDialog
var _grid_container: Control


func _ready() -> void:
	_build_ui()
	_init_matrix()
	_select_character("warrior")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.ctrl_pressed and event.keycode == KEY_Z:
			_undo()
			get_viewport().set_input_as_handled()


# ── UI Construction ──────────────────────────────────────────────────

func _build_ui() -> void:
	# Background
	var bg := ColorRect.new()
	bg.color = UIColors.BG_BACKPACK_EDITOR
	bg.set_anchors_preset(PRESET_FULL_RECT)
	add_child(bg)

	# Main VBox
	var main_vbox := VBoxContainer.new()
	main_vbox.set_anchors_preset(PRESET_FULL_RECT)
	main_vbox.offset_left = 10.0
	main_vbox.offset_top = 10.0
	main_vbox.offset_right = -10.0
	main_vbox.offset_bottom = -10.0
	UIThemes.set_separation(main_vbox, 8)
	add_child(main_vbox)

	# Top bar
	var top_bar := HBoxContainer.new()
	UIThemes.set_separation(top_bar, 12)
	main_vbox.add_child(top_bar)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.pressed.connect(_on_back)
	top_bar.add_child(back_btn)

	var title := Label.new()
	title.text = "Backpack Tier Editor"
	UIThemes.style_label(title, Constants.FONT_SIZE_HEADER, Constants.COLOR_TEXT_HEADER)
	top_bar.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_bar.add_child(spacer)

	var save_btn := Button.new()
	save_btn.text = "Save"
	save_btn.pressed.connect(_on_save)
	top_bar.add_child(save_btn)

	_status_label = Label.new()
	UIThemes.style_label(_status_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SUCCESS)
	top_bar.add_child(_status_label)

	# Content area
	var content := HBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	UIThemes.set_separation(content, 8)
	main_vbox.add_child(content)

	# Left panel — character list
	var left_panel := PanelContainer.new()
	content.add_child(left_panel)

	var left_vbox := VBoxContainer.new()
	UIThemes.set_separation(left_vbox, 6)
	left_panel.add_child(left_vbox)

	var char_header := Label.new()
	char_header.text = "Characters"
	UIThemes.style_label(char_header, Constants.FONT_SIZE_NORMAL, Constants.COLOR_TEXT_HEADER)
	left_vbox.add_child(char_header)

	var characters: Array = CharacterDatabase.get_all_characters()
	characters.sort_custom(func(a_char: CharacterData, b_char: CharacterData) -> bool:
		return a_char.display_name < b_char.display_name
	)
	for character: CharacterData in characters:
		if not character.backpack_data:
			continue
		var btn := Button.new()
		btn.text = character.display_name
		btn.pressed.connect(_on_character_selected.bind(character.id))
		left_vbox.add_child(btn)
		_char_buttons[character.id] = btn

	# Right panel — grid editor
	var right_panel := PanelContainer.new()
	right_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_panel.size_flags_stretch_ratio = 3.0
	content.add_child(right_panel)

	var right_vbox := VBoxContainer.new()
	UIThemes.set_separation(right_vbox, 6)
	right_panel.add_child(right_vbox)

	# Info bar
	var info_bar := HBoxContainer.new()
	UIThemes.set_separation(info_bar, 12)
	right_vbox.add_child(info_bar)

	_char_name_label = Label.new()
	UIThemes.style_label(_char_name_label, Constants.FONT_SIZE_HEADER, Constants.COLOR_TEXT_HEADER)
	info_bar.add_child(_char_name_label)

	_stats_label = Label.new()
	_stats_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UIThemes.style_label(_stats_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
	info_bar.add_child(_stats_label)

	# Grid scroll
	var grid_scroll := ScrollContainer.new()
	grid_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	grid_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	grid_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	right_vbox.add_child(grid_scroll)

	_grid_container = Control.new()
	_grid_container.custom_minimum_size = Vector2(GRID_SIZE * CELL_PX, GRID_SIZE * CELL_PX)
	grid_scroll.add_child(_grid_container)

	_build_grid_cells()

	# Legend
	var legend := HBoxContainer.new()
	UIThemes.set_separation(legend, 4)
	right_vbox.add_child(legend)

	var legend_label := Label.new()
	legend_label.text = "Legend:"
	UIThemes.style_label(legend_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
	legend.add_child(legend_label)

	for sym in SYMBOLS:
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = Vector2(14, 14)
		swatch.color = SYMBOL_COLORS[sym]
		legend.add_child(swatch)

		var sym_lbl := Label.new()
		var display_text: String = sym
		if sym == "x":
			display_text = "x:void"
		elif sym == "0":
			display_text = "0:free"
		elif sym == "a":
			display_text = "a:T10"
		else:
			display_text = "%s:T%s" % [sym, sym]
		sym_lbl.text = display_text
		UIThemes.style_label(sym_lbl, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
		legend.add_child(sym_lbl)

	# Hint bar
	var hint := Label.new()
	hint.text = "Left-click: raise tier  |  Right-click: lower tier  |  Ctrl+Z: undo"
	UIThemes.style_label(hint, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
	main_vbox.add_child(hint)

	# Unsaved changes dialog
	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Unsaved Changes"
	_unsaved_dialog.dialog_text = "You have unsaved changes.\nWhat would you like to do?"
	_unsaved_dialog.ok_button_text = "Save & Leave"
	_unsaved_dialog.add_button("Discard & Leave", true, "discard")
	_unsaved_dialog.confirmed.connect(_save_and_leave)
	_unsaved_dialog.custom_action.connect(_on_unsaved_action)
	add_child(_unsaved_dialog)


func _build_grid_cells() -> void:
	for child in _grid_container.get_children():
		child.queue_free()
	_cell_panels.clear()
	_cell_labels.clear()

	for grid_y in range(GRID_SIZE):
		for grid_x in range(GRID_SIZE):
			var pos := Vector2i(grid_x, grid_y)
			var panel := PanelContainer.new()
			panel.custom_minimum_size = Vector2(CELL_PX, CELL_PX)
			panel.position = Vector2(grid_x * CELL_PX, grid_y * CELL_PX)
			panel.size = Vector2(CELL_PX, CELL_PX)
			panel.clip_contents = true
			panel.mouse_filter = Control.MOUSE_FILTER_STOP

			var style := StyleBoxFlat.new()
			style.bg_color = SYMBOL_COLORS["x"]
			style.set_border_width_all(1)
			style.border_color = Color(0.3, 0.3, 0.3, 0.3)
			style.set_content_margin_all(0)
			panel.add_theme_stylebox_override("panel", style)

			var lbl := Label.new()
			lbl.text = "x"
			lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lbl.anchors_preset = Control.PRESET_FULL_RECT
			lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			lbl.add_theme_font_size_override("font_size", 9)
			lbl.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
			panel.add_child(lbl)

			panel.gui_input.connect(_on_cell_input.bind(pos))

			_grid_container.add_child(panel)
			_cell_panels[pos] = panel
			_cell_labels[pos] = lbl


# ── Matrix Logic ─────────────────────────────────────────────────────

func _init_matrix() -> void:
	_matrix.clear()
	for _y in range(GRID_SIZE):
		var row: Array = []
		for _x in range(GRID_SIZE):
			row.append("x")
		_matrix.append(row)


func _load_from_character(char_id: String) -> void:
	var character: CharacterData = CharacterDatabase.get_character(char_id)
	if not character or not character.backpack_data:
		_init_matrix()
		_refresh_all_cells()
		_update_stats()
		return
	_init_matrix()
	var bd: BackpackData = character.backpack_data
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var val: int = bd.cell_tiers[y * GRID_SIZE + x]
			if val >= 0 and val < SYMBOLS.size() - 1:
				_matrix[y][x] = SYMBOLS[val + 1]  # 0→"0", 1→"1", ..., 10→"a"
			else:
				_matrix[y][x] = "x"
	_refresh_all_cells()
	_update_stats()


func _refresh_all_cells() -> void:
	for grid_y in range(GRID_SIZE):
		for grid_x in range(GRID_SIZE):
			var pos := Vector2i(grid_x, grid_y)
			var sym: String = _matrix[grid_y][grid_x]
			_update_cell_visual(pos, sym)


func _update_cell_visual(pos: Vector2i, sym: String) -> void:
	var panel: PanelContainer = _cell_panels[pos]
	var lbl: Label = _cell_labels[pos]
	var style: StyleBoxFlat = panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.bg_color = SYMBOL_COLORS.get(sym, SYMBOL_COLORS["x"])
	lbl.text = sym


func _update_stats() -> void:
	var counts: Dictionary = {}
	for s in SYMBOLS:
		counts[s] = 0
	var total := 0
	for row_y in range(GRID_SIZE):
		for col_x in range(GRID_SIZE):
			var cell_sym: String = _matrix[row_y][col_x]
			counts[cell_sym] = counts[cell_sym] + 1
			if cell_sym != "x":
				total += 1

	var parts: Array[String] = []
	parts.append("Total: %d" % total)
	parts.append("Free: %d" % counts["0"])
	parts.append("T1: %d" % (counts["0"] + counts["1"]))
	for tier_num in range(2, 10):
		var tier_sym: String = str(tier_num)
		if counts[tier_sym] > 0:
			parts.append("T%d: +%d" % [tier_num, counts[tier_sym]])
	if counts["a"] > 0:
		parts.append("T10: +%d" % counts["a"])
	_stats_label.text = "  |  ".join(parts)


# ── Cell Interaction ─────────────────────────────────────────────────

func _on_cell_input(event: InputEvent, pos: Vector2i) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return
	var mb: InputEventMouseButton = event
	if mb.button_index == MOUSE_BUTTON_LEFT:
		_cycle_cell(pos, 1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		_cycle_cell(pos, -1)


func _cycle_cell(pos: Vector2i, direction: int) -> void:
	var old_sym: String = _matrix[pos.y][pos.x]
	var idx: int = SYMBOLS.find(old_sym)
	if idx < 0:
		idx = 0
	var new_idx: int = (idx + direction) % SYMBOLS.size()
	if new_idx < 0:
		new_idx += SYMBOLS.size()
	var new_sym: String = SYMBOLS[new_idx]
	_matrix[pos.y][pos.x] = new_sym
	_update_cell_visual(pos, new_sym)
	_undo_stack.append({"pos": pos, "old": old_sym})
	_dirty = true
	_update_stats()


func _undo() -> void:
	if _undo_stack.is_empty():
		return
	var entry: Dictionary = _undo_stack.pop_back()
	var pos: Vector2i = entry["pos"]
	var old_sym: String = entry["old"]
	_matrix[pos.y][pos.x] = old_sym
	_update_cell_visual(pos, old_sym)
	_update_stats()


# ── Character Selection ──────────────────────────────────────────────

func _select_character(char_id: String) -> void:
	if _dirty and _current_char_id != "":
		# Auto-save is too aggressive; just warn via status
		_status_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_IMPORTANT)
		_status_label.text = "Unsaved changes for %s!" % _current_char_id
	_current_char_id = char_id
	_dirty = false
	_undo_stack.clear()
	_status_label.text = ""

	var character: CharacterData = CharacterDatabase.get_character(char_id)
	if character:
		_char_name_label.text = character.display_name
	else:
		_char_name_label.text = char_id

	# Highlight active button
	for cid: String in _char_buttons:
		var btn: Button = _char_buttons[cid]
		btn.disabled = (cid == char_id)

	_load_from_character(char_id)


func _on_character_selected(char_id: String) -> void:
	if char_id == _current_char_id:
		return
	_select_character(char_id)


# ── Save ─────────────────────────────────────────────────────────────

func _on_save() -> void:
	if _current_char_id.is_empty():
		return
	_save_character(_current_char_id)
	_dirty = false
	_status_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
	_status_label.text = "Saved %s!" % _current_char_id


func _save_character(char_id: String) -> void:
	var character: CharacterData = CharacterDatabase.get_character(char_id)
	if not character:
		return

	# Build or update BackpackData
	var bd: BackpackData = character.backpack_data
	if not bd:
		bd = BackpackData.new()
		character.backpack_data = bd

	# Write the grid from matrix
	var grid := PackedInt32Array()
	grid.resize(GRID_SIZE * GRID_SIZE)
	for y in range(GRID_SIZE):
		for x in range(GRID_SIZE):
			var sym: String = _matrix[y][x]
			var sym_idx: int = SYMBOLS.find(sym)
			if sym_idx <= 0:
				grid[y * GRID_SIZE + x] = -1  # "x" or unknown → void
			else:
				grid[y * GRID_SIZE + x] = sym_idx - 1  # "0"→0, "1"→1, ..., "a"→10
	bd.cell_tiers = grid

	# Preserve existing tier metadata; fill defaults for missing tiers
	var names := PackedStringArray()
	var gold := PackedInt32Array()
	var runes := PackedInt32Array()
	var costs: Array = []
	for tier_idx in range(10):
		if tier_idx < bd.tier_names.size():
			names.append(bd.tier_names[tier_idx])
		else:
			names.append("Tier %d" % (tier_idx + 1))
		if tier_idx < bd.tier_unlock_gold.size():
			gold.append(bd.tier_unlock_gold[tier_idx])
		else:
			gold.append(0)
		if tier_idx < bd.tier_unlock_runes.size():
			runes.append(bd.tier_unlock_runes[tier_idx])
		else:
			runes.append(tier_idx)

		# Count purchasable cells for this tier to maintain cell_costs length
		var purchasable_count := 0
		for y in range(GRID_SIZE):
			for x in range(GRID_SIZE):
				var val: int = grid[y * GRID_SIZE + x]
				if tier_idx == 0:
					if val == 1:
						purchasable_count += 1
				else:
					if val == tier_idx + 1:
						purchasable_count += 1

		var old_costs: Array[int] = []
		if tier_idx < bd.tier_cell_costs.size():
			old_costs.assign(bd.tier_cell_costs[tier_idx])
		var new_costs: Array[int] = []
		for ci in range(purchasable_count):
			if ci < old_costs.size():
				new_costs.append(old_costs[ci])
			elif not old_costs.is_empty():
				new_costs.append(old_costs[old_costs.size() - 1])
			else:
				new_costs.append(50)
		costs.append(new_costs)

	bd.tier_names = names
	bd.tier_unlock_gold = gold
	bd.tier_unlock_runes = runes
	bd.tier_cell_costs = costs
	bd.invalidate_cache()

	# Save the single BackpackData file
	var save_path: String = TIER_DIR + char_id + ".tres"
	var err: int = ResourceSaver.save(bd, save_path)
	if err != OK:
		push_warning("Failed to save %s (error %d)" % [save_path, err])


# ── Navigation ───────────────────────────────────────────────────────

func _on_back() -> void:
	if _dirty:
		_unsaved_dialog.popup_centered()
		return
	SceneManager.pop_scene()


func _save_and_leave() -> void:
	_on_save()
	SceneManager.pop_scene()


func _on_unsaved_action(action: StringName) -> void:
	if action == &"discard":
		_unsaved_dialog.hide()
		_dirty = false
		SceneManager.pop_scene()
