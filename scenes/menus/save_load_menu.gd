extends Control
## Save/Load slot selection screen.
## Receives {"mode": "save"} or {"mode": "load"} via receive_data().

@onready var _title_label: Label = $VBox/TopBar/TitleLabel
@onready var _close_button: Button = $VBox/TopBar/CloseButton
@onready var _slot_list: VBoxContainer = $VBox/ScrollContainer/SlotList

var _mode: String = "load"  # "save" or "load"


func _ready() -> void:
	_close_button.pressed.connect(_on_close)
	_build_slots()


func receive_data(data: Dictionary) -> void:
	_mode = data.get("mode", "load")
	_title_label.text = "Save Game" if _mode == "save" else "Load Game"
	_build_slots()


# === Slot Card Builder ===

func _build_slots() -> void:
	for child in _slot_list.get_children():
		child.queue_free()

	# Auto-save card first
	var auto_meta := SaveManager.get_auto_save_meta()
	_slot_list.add_child(_build_card("Auto-Save", -1, auto_meta, true))

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_slot_list.add_child(sep)

	# Manual slots
	var all_meta := SaveManager.get_all_slots_meta()
	for i in range(SaveManager.MAX_SLOTS):
		var card := _build_card("Slot %d" % (i + 1), i, all_meta[i], false)
		_slot_list.add_child(card)


func _build_card(label_text: String, slot_index: int, meta: Dictionary, is_auto: bool) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 12, 12, 8, 8)
	card.add_child(margin)

	var inner_vbox := VBoxContainer.new()
	UIThemes.set_separation(inner_vbox, 6)
	margin.add_child(inner_vbox)

	var history_count: int = meta.get("history_count", 0)
	var has_data := history_count > 0
	var entries: Array = meta.get("entries", [])

	# --- Header row ---
	var header := HBoxContainer.new()
	inner_vbox.add_child(header)

	var slot_label := Label.new()
	slot_label.text = label_text
	UIThemes.style_label(slot_label, Constants.FONT_SIZE_DETAIL, Constants.COLOR_TEXT_HEADER)
	slot_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(slot_label)

	# Delete button (manual slots only, when occupied)
	if not is_auto and has_data:
		var del_btn := Button.new()
		del_btn.text = "Delete"
		del_btn.add_theme_color_override("font_color", Constants.COLOR_DAMAGE)
		del_btn.pressed.connect(_on_delete_slot.bind(slot_index))
		header.add_child(del_btn)

	# --- Info row (if data exists) ---
	if has_data and not entries.is_empty():
		var newest: Dictionary = entries[0]
		var info_row := HBoxContainer.new()
		UIThemes.set_separation(info_row, 16)
		inner_vbox.add_child(info_row)

		var ts_label := Label.new()
		ts_label.text = _format_timestamp(newest.get("timestamp", ""))
		UIThemes.style_label(ts_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
		info_row.add_child(ts_label)

		var pt_label := Label.new()
		pt_label.text = _format_playtime(newest.get("playtime_seconds", 0.0))
		UIThemes.style_label(pt_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
		info_row.add_child(pt_label)

		var gold_label := Label.new()
		gold_label.text = "%dg" % int(newest.get("gold", 0))
		UIThemes.style_label(gold_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_CRIT)
		info_row.add_child(gold_label)

		var squad: Array = newest.get("squad_names", [])
		if not squad.is_empty():
			var squad_label := Label.new()
			squad_label.text = "  |  " + ", ".join(squad)
			UIThemes.style_label(squad_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_EMPHASIS)
			info_row.add_child(squad_label)

		var location_label := Label.new()
		location_label.text = newest.get("location", "Overworld")
		UIThemes.style_label(location_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SKILL)
		location_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		location_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		info_row.add_child(location_label)

	elif not has_data:
		var empty_label := Label.new()
		empty_label.text = "Empty"
		UIThemes.style_label(empty_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
		inner_vbox.add_child(empty_label)

	# --- Action row ---
	var action_row := HBoxContainer.new()
	UIThemes.set_separation(action_row, 8)
	inner_vbox.add_child(action_row)

	if _mode == "save":
		# Save button — always shown for manual slots; hidden for auto
		if not is_auto:
			var save_btn := Button.new()
			save_btn.text = "Save Here"
			save_btn.pressed.connect(_on_save_to_slot.bind(slot_index))
			action_row.add_child(save_btn)
	else:
		# Load button — shown only when slot has data
		if has_data:
			var load_btn := Button.new()
			load_btn.text = "Load Latest"
			load_btn.pressed.connect(_on_load_slot.bind(slot_index, is_auto, -1))
			action_row.add_child(load_btn)

	# History toggle button (shown when more than 1 entry)
	if has_data and history_count > 1 and _mode == "load":
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		action_row.add_child(spacer)

		var hist_btn := Button.new()
		hist_btn.text = "▼ %d older" % (history_count - 1)
		hist_btn.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TINY)

		# History panel (collapsed by default)
		var hist_panel := VBoxContainer.new()
		UIThemes.set_separation(hist_panel, 4)
		hist_panel.visible = false
		inner_vbox.add_child(hist_panel)

		for h in range(1, entries.size()):
			var entry: Dictionary = entries[h]
			var row := _build_history_row(entry, h, slot_index, is_auto)
			hist_panel.add_child(row)

		hist_btn.pressed.connect(func() -> void:
			hist_panel.visible = not hist_panel.visible
			hist_btn.text = ("▲ hide" if hist_panel.visible else "▼ %d older" % (history_count - 1))
		)
		action_row.add_child(hist_btn)

	return card


func _build_history_row(entry: Dictionary, history_index: int, slot_index: int, is_auto: bool) -> HBoxContainer:
	var row := HBoxContainer.new()
	UIThemes.set_separation(row, 12)

	var ts := Label.new()
	ts.text = _format_timestamp(entry.get("timestamp", ""))
	UIThemes.style_label(ts, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
	row.add_child(ts)

	var pt := Label.new()
	pt.text = _format_playtime(entry.get("playtime_seconds", 0.0))
	UIThemes.style_label(pt, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
	row.add_child(pt)

	var gold := Label.new()
	gold.text = "%dg" % int(entry.get("gold", 0))
	UIThemes.style_label(gold, Constants.FONT_SIZE_TINY, Constants.COLOR_CRIT)
	gold.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(gold)

	var btn := Button.new()
	btn.text = "Load"
	btn.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TINY)
	btn.pressed.connect(_on_load_slot.bind(slot_index, is_auto, history_index))
	row.add_child(btn)

	return row


# === Formatting Helpers ===

func _format_timestamp(ts: String) -> String:
	if ts.is_empty():
		return "Unknown"
	# ts format: "2024-01-15T14:32:00" → "Jan 15  14:32"
	var parts := ts.split("T")
	if parts.size() < 2:
		return ts
	var date_parts := parts[0].split("-")
	var time_parts := parts[1].split(":")
	if date_parts.size() < 3 or time_parts.size() < 2:
		return ts
	var months: Array[String] = ["Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"]
	var month_idx := int(date_parts[1]) - 1
	var month_str: String = months[clampi(month_idx, 0, 11)]
	return "%s %s  %s:%s" % [month_str, date_parts[2], time_parts[0], time_parts[1]]


func _format_playtime(seconds: float) -> String:
	var total_minutes := int(seconds / 60.0)
	@warning_ignore("integer_division")
	var hours := total_minutes / 60
	var minutes := total_minutes % 60
	if hours > 0:
		return "%dh %dm" % [hours, minutes]
	return "%dm" % minutes


# === Actions ===

func _on_save_to_slot(slot_index: int) -> void:
	SaveManager.save_to_slot(slot_index)
	SceneManager.pop_scene()


func _on_load_slot(slot_index: int, is_auto: bool, history_index: int) -> void:
	var ok: bool
	if is_auto:
		ok = SaveManager.load_auto_save(history_index)
	else:
		ok = SaveManager.load_from_slot(slot_index, history_index)
	if ok:
		SaveManager.start_playtime_tracking()
		SceneManager.clear_stack()
		SceneManager.replace_scene("res://scenes/world/overworld.tscn")


func _on_delete_slot(slot_index: int) -> void:
	SaveManager.delete_slot(slot_index)
	_build_slots()


func _on_close() -> void:
	SceneManager.pop_scene()
