extends Control
## In-game NPC/dialogue editor. Create, edit, and save NpcData resources.
## Accessible from the main menu — no game session required.

const NPC_DIR := "res://data/npcs/"
const SPRITE_DIR := "res://assets/sprites/characters/"

const ROLE_NAMES: Array[String] = ["Generic", "Shopkeeper", "Quest Giver", "Craftsman"]
const ACTION_OPTIONS: Array[String] = [
	"(none)", "end", "heal_party", "resurrect_party",
	"unlock_backpack_tier", "open_shop:", "open_crafting:",
]

# === NPC data ===
var _npcs: Dictionary = {}         # id -> NpcData (working copies)
var _selected_id: String = ""
var _dirty_ids: Dictionary = {}

# === Texture cache ===
var _sprite_paths: Array[String] = []
var _sprite_textures: Array[Texture2D] = []

# === Unsaved-changes dialog ===
var _unsaved_dialog: ConfirmationDialog

# === Node references ===
@onready var _bg: ColorRect = $BG
@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _save_btn: Button = $VBox/TopBar/SaveButton
@onready var _save_all_btn: Button = $VBox/TopBar/SaveAllButton
@onready var _status_label: Label = $VBox/TopBar/StatusLabel
@onready var _title_label: Label = $VBox/TopBar/Title
@onready var _search_edit: LineEdit = $VBox/Content/ListPanel/ListVBox/SearchEdit
@onready var _npc_list_vbox: VBoxContainer = $VBox/Content/ListPanel/ListVBox/NpcListScroll/NpcListVBox
@onready var _new_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/NewButton
@onready var _duplicate_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/DuplicateButton
@onready var _delete_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/DeleteButton
@onready var _property_vbox: VBoxContainer = $VBox/Content/PropertyPanel/PropertyScroll/PropertyVBox
@onready var _hint_bar: Label = $VBox/HintBar


func _ready() -> void:
	_bg.color = UIColors.BG_NPC_EDITOR
	_title_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_HEADER)

	_back_btn.pressed.connect(_on_back)
	_save_btn.pressed.connect(_on_save_npc)
	_save_all_btn.pressed.connect(_on_save_all)
	_new_btn.pressed.connect(_on_new_npc)
	_duplicate_btn.pressed.connect(_on_duplicate_npc)
	_delete_btn.pressed.connect(_on_delete_npc)
	_search_edit.text_changed.connect(func(_t: String) -> void: _rebuild_npc_list())

	_unsaved_dialog = ConfirmationDialog.new()
	_unsaved_dialog.title = "Unsaved Changes"
	_unsaved_dialog.dialog_text = "You have unsaved changes.\nWhat would you like to do?"
	_unsaved_dialog.ok_button_text = "Save All & Leave"
	_unsaved_dialog.add_button("Discard & Leave", true, "discard")
	_unsaved_dialog.confirmed.connect(_on_unsaved_save_and_leave)
	_unsaved_dialog.custom_action.connect(_on_unsaved_custom_action)
	add_child(_unsaved_dialog)

	_load_sprites()

	for npc in NpcDatabase.get_all_npcs():
		var copy: NpcData = npc.duplicate(true) as NpcData
		_npcs[copy.id] = copy

	_rebuild_npc_list()
	_clear_property_panel()
	_update_hint_bar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_npc()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


# =========================================================================
# Resource scanning
# =========================================================================

func _load_sprites() -> void:
	var dir := DirAccess.open(SPRITE_DIR)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and (file_name.ends_with(".png") or file_name.ends_with(".jpg")):
			var path: String = SPRITE_DIR + file_name
			var tex: Texture2D = load(path) as Texture2D
			if tex:
				_sprite_paths.append(path)
				_sprite_textures.append(tex)
		file_name = dir.get_next()
	dir.list_dir_end()


# =========================================================================
# NPC list (left panel)
# =========================================================================

func _rebuild_npc_list() -> void:
	for child in _npc_list_vbox.get_children():
		child.queue_free()

	var search_text: String = _search_edit.text.strip_edges().to_lower()

	# Group by role
	var grouped: Dictionary = {}
	for npc_id in _npcs:
		var npc: NpcData = _npcs[npc_id]
		if not search_text.is_empty():
			if search_text not in npc.id.to_lower() and search_text not in npc.display_name.to_lower():
				continue
		var role_idx: int = npc.role as int
		if not grouped.has(role_idx):
			grouped[role_idx] = []
		grouped[role_idx].append(npc)

	var role_order: Array[int] = [
		NpcData.NpcRole.GENERIC as int,
		NpcData.NpcRole.SHOPKEEPER as int,
		NpcData.NpcRole.QUEST_GIVER as int,
		NpcData.NpcRole.CRAFTSMAN as int,
	]

	for role_idx in role_order:
		if not grouped.has(role_idx):
			continue
		var npcs_in_role: Array = grouped[role_idx]
		npcs_in_role.sort_custom(func(a: NpcData, b: NpcData) -> bool: return a.id < b.id)

		# Role section header
		var section_label := Label.new()
		section_label.text = ROLE_NAMES[role_idx] if role_idx < ROLE_NAMES.size() else "Unknown"
		section_label.add_theme_font_size_override("font_size", 15)
		section_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		_npc_list_vbox.add_child(section_label)

		for npc in npcs_in_role:
			var btn := Button.new()
			var label_text: String = npc.display_name if not npc.display_name.is_empty() else npc.id
			if _dirty_ids.has(npc.id):
				label_text = "* " + label_text
			btn.text = "  " + label_text
			btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

			if npc.id == _selected_id:
				btn.add_theme_color_override("font_color", Color.WHITE)
				var style := StyleBoxFlat.new()
				style.bg_color = Color(0.3, 0.5, 0.7, 0.5)
				style.content_margin_left = 4
				style.content_margin_right = 4
				style.content_margin_top = 2
				style.content_margin_bottom = 2
				btn.add_theme_stylebox_override("normal", style)
			else:
				btn.add_theme_color_override("font_color", Color(0.85, 0.85, 0.85))

			var npc_id: String = npc.id
			btn.pressed.connect(func() -> void: _select_npc(npc_id))
			_npc_list_vbox.add_child(btn)


func _select_npc(npc_id: String) -> void:
	_selected_id = npc_id
	_rebuild_npc_list()
	_rebuild_property_panel()


# =========================================================================
# CRUD
# =========================================================================

func _on_new_npc() -> void:
	var new_id: String = "npc_%d" % Time.get_ticks_msec()
	var npc := NpcData.new()
	npc.id = new_id
	npc.display_name = "New NPC"
	npc.role = NpcData.NpcRole.GENERIC
	_npcs[new_id] = npc
	_dirty_ids[new_id] = true
	_select_npc(new_id)
	_update_hint_bar()


func _on_duplicate_npc() -> void:
	if _selected_id.is_empty():
		return
	var source: NpcData = _npcs.get(_selected_id)
	if not source:
		return
	var copy: NpcData = source.duplicate(true) as NpcData
	copy.id = source.id + "_copy"
	while _npcs.has(copy.id):
		copy.id += "_"
	_npcs[copy.id] = copy
	_dirty_ids[copy.id] = true
	_select_npc(copy.id)
	_update_hint_bar()


func _on_delete_npc() -> void:
	if _selected_id.is_empty():
		return
	# Delete file on disk
	var file_path: String = NPC_DIR + _selected_id + ".tres"
	if FileAccess.file_exists(file_path):
		@warning_ignore("return_value_discarded")
		DirAccess.remove_absolute(file_path)
	_npcs.erase(_selected_id)
	_dirty_ids.erase(_selected_id)
	_selected_id = ""
	_rebuild_npc_list()
	_clear_property_panel()
	_update_hint_bar()
	NpcDatabase.reload()


# =========================================================================
# Save
# =========================================================================

func _save_single_npc(npc: NpcData) -> bool:
	@warning_ignore("return_value_discarded")
	DirAccess.make_dir_recursive_absolute(NPC_DIR)

	# If the id changed, remove the old file
	var old_path: String = NPC_DIR + npc.id + ".tres"
	# Clean up any stale file with old id (handled by caller if id changed)

	var file_path: String = NPC_DIR + npc.id + ".tres"
	var err := ResourceSaver.save(npc, file_path)
	return err == OK


func _on_save_npc() -> void:
	if _selected_id.is_empty():
		_show_status("No NPC selected", Color(0.9, 0.7, 0.3))
		return
	var npc: NpcData = _npcs.get(_selected_id)
	if not npc:
		return
	if _save_single_npc(npc):
		_dirty_ids.erase(_selected_id)
		_rebuild_npc_list()
		_show_status("Saved: %s" % npc.id, Color(0.2, 0.8, 0.3))
		NpcDatabase.reload()
	else:
		_show_status("Save failed: %s" % npc.id, Color(0.9, 0.3, 0.3))


func _on_save_all() -> void:
	var success_count: int = 0
	var fail_count: int = 0
	for npc in _npcs.values():
		if _save_single_npc(npc):
			success_count += 1
		else:
			fail_count += 1
	_dirty_ids.clear()
	_rebuild_npc_list()
	NpcDatabase.reload()
	if fail_count == 0:
		_show_status("Saved all %d NPCs" % success_count, Color(0.2, 0.8, 0.3))
	else:
		_show_status("Saved %d, failed %d" % [success_count, fail_count], Color(0.9, 0.7, 0.3))


func _show_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		_status_label.text = ""


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


# =========================================================================
# Property panel (right side)
# =========================================================================

func _clear_property_panel() -> void:
	for child in _property_vbox.get_children():
		child.queue_free()


func _rebuild_property_panel() -> void:
	_clear_property_panel()
	if _selected_id.is_empty():
		return
	var npc: NpcData = _npcs.get(_selected_id)
	if not npc:
		return

	_build_identity_section(npc)
	_add_separator()
	_build_conversations_section(npc)


func _mark_dirty(npc_id: String) -> void:
	_dirty_ids[npc_id] = true
	_rebuild_npc_list()


# ── Identity section ──────────────────────────────────────────────────

func _build_identity_section(npc: NpcData) -> void:
	_add_section_header("Identity")

	# ID
	_add_label_row("ID")
	var id_edit := LineEdit.new()
	id_edit.text = npc.id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(func(new_text: String) -> void:
		var old_id: String = npc.id
		npc.id = new_text
		# Update our dictionary key
		if old_id != new_text:
			_npcs.erase(old_id)
			_npcs[new_text] = npc
			_dirty_ids.erase(old_id)
			_selected_id = new_text
			_mark_dirty(new_text)
	)
	_property_vbox.add_child(id_edit)

	# Display name
	_add_label_row("Display Name")
	var name_edit := LineEdit.new()
	name_edit.text = npc.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text: String) -> void:
		npc.display_name = new_text
		_mark_dirty(npc.id)
	)
	_property_vbox.add_child(name_edit)

	# Role
	_add_label_row("Role")
	var role_btn := OptionButton.new()
	for i in range(ROLE_NAMES.size()):
		role_btn.add_item(ROLE_NAMES[i], i)
	role_btn.selected = npc.role as int
	role_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	role_btn.item_selected.connect(func(idx: int) -> void:
		npc.role = idx as NpcData.NpcRole
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	_property_vbox.add_child(role_btn)

	# Shop ID (only for shopkeepers)
	if npc.role == NpcData.NpcRole.SHOPKEEPER:
		_add_label_row("Shop ID")
		var shop_edit := LineEdit.new()
		shop_edit.text = npc.shop_id
		shop_edit.placeholder_text = "e.g. merchant_general"
		shop_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_edit.text_changed.connect(func(new_text: String) -> void:
			npc.shop_id = new_text
			_mark_dirty(npc.id)
		)
		_property_vbox.add_child(shop_edit)

	# Crafting Station ID (only for craftsmen)
	if npc.role == NpcData.NpcRole.CRAFTSMAN:
		_add_label_row("Crafting Station ID")
		var craft_edit := LineEdit.new()
		craft_edit.text = npc.crafting_station_id
		craft_edit.placeholder_text = "e.g. blacksmith"
		craft_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		craft_edit.text_changed.connect(func(new_text: String) -> void:
			npc.crafting_station_id = new_text
			_mark_dirty(npc.id)
		)
		_property_vbox.add_child(craft_edit)

	# Sprite
	_add_label_row("Sprite")
	_build_texture_picker(npc, "sprite")

	# Portrait
	_add_label_row("Portrait")
	_build_texture_picker(npc, "portrait")


func _build_texture_picker(npc: NpcData, field: String) -> void:
	var hbox := HBoxContainer.new()
	hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var current_tex: Texture2D = npc.get(field)

	# Preview
	var preview := TextureRect.new()
	preview.custom_minimum_size = Vector2(32, 32)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.texture = current_tex
	hbox.add_child(preview)

	# OptionButton with sprite options
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	opt.add_item("(none)", 0)
	var selected_idx: int = 0
	for i in range(_sprite_paths.size()):
		opt.add_item(_sprite_paths[i].get_file(), i + 1)
		if current_tex and current_tex == _sprite_textures[i]:
			selected_idx = i + 1
	opt.selected = selected_idx

	opt.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			npc.set(field, null)
			preview.texture = null
		else:
			var tex: Texture2D = _sprite_textures[idx - 1]
			npc.set(field, tex)
			preview.texture = tex
		_mark_dirty(npc.id)
	)
	hbox.add_child(opt)

	_property_vbox.add_child(hbox)


# ── Conversations section ─────────────────────────────────────────────

func _build_conversations_section(npc: NpcData) -> void:
	_add_section_header("Conversations")

	for conv_idx in range(npc.conversations.size()):
		var conv: DialogueConversation = npc.conversations[conv_idx]
		_build_conversation_card(npc, conv, conv_idx)

	# Add conversation button
	var add_btn := Button.new()
	add_btn.text = "+ Add Conversation"
	add_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_btn.pressed.connect(func() -> void:
		var new_conv := DialogueConversation.new()
		new_conv.id = "conv_%d" % npc.conversations.size()
		npc.conversations.append(new_conv)
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	_property_vbox.add_child(add_btn)


func _build_conversation_card(npc: NpcData, conv: DialogueConversation, conv_idx: int) -> void:
	# Card container with background
	var card := PanelContainer.new()
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.15, 0.18, 0.25, 0.8)
	card_style.border_color = Color(0.3, 0.4, 0.5, 0.5)
	card_style.border_width_left = 1
	card_style.border_width_right = 1
	card_style.border_width_top = 1
	card_style.border_width_bottom = 1
	card_style.content_margin_left = 8
	card_style.content_margin_right = 8
	card_style.content_margin_top = 6
	card_style.content_margin_bottom = 6
	card_style.corner_radius_top_left = 4
	card_style.corner_radius_top_right = 4
	card_style.corner_radius_bottom_left = 4
	card_style.corner_radius_bottom_right = 4
	card.add_theme_stylebox_override("panel", card_style)
	_property_vbox.add_child(card)

	var card_vbox := VBoxContainer.new()
	card_vbox.add_theme_constant_override("separation", 4)
	card.add_child(card_vbox)

	# Header row
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 8)
	card_vbox.add_child(header)

	var conv_label := Label.new()
	conv_label.text = conv.id if not conv.id.is_empty() else "(unnamed)"
	conv_label.add_theme_font_size_override("font_size", 15)
	conv_label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	conv_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(conv_label)

	# Move up
	if conv_idx > 0:
		var up_btn := Button.new()
		up_btn.text = "Up"
		up_btn.pressed.connect(func() -> void:
			var temp: DialogueConversation = npc.conversations[conv_idx - 1]
			npc.conversations[conv_idx - 1] = npc.conversations[conv_idx]
			npc.conversations[conv_idx] = temp
			_mark_dirty(npc.id)
			_rebuild_property_panel()
		)
		header.add_child(up_btn)

	# Move down
	if conv_idx < npc.conversations.size() - 1:
		var down_btn := Button.new()
		down_btn.text = "Down"
		down_btn.pressed.connect(func() -> void:
			var temp: DialogueConversation = npc.conversations[conv_idx + 1]
			npc.conversations[conv_idx + 1] = npc.conversations[conv_idx]
			npc.conversations[conv_idx] = temp
			_mark_dirty(npc.id)
			_rebuild_property_panel()
		)
		header.add_child(down_btn)

	# Delete conversation
	var del_btn := Button.new()
	del_btn.text = "Delete"
	del_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	del_btn.pressed.connect(func() -> void:
		npc.conversations.remove_at(conv_idx)
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	header.add_child(del_btn)

	# Conversation ID
	var id_row := HBoxContainer.new()
	card_vbox.add_child(id_row)
	var id_label := Label.new()
	id_label.text = "ID:"
	id_label.custom_minimum_size.x = 100
	id_row.add_child(id_label)
	var id_edit := LineEdit.new()
	id_edit.text = conv.id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_changed.connect(func(new_text: String) -> void:
		conv.id = new_text
		conv_label.text = new_text if not new_text.is_empty() else "(unnamed)"
		_mark_dirty(npc.id)
	)
	id_row.add_child(id_edit)

	# Condition flag
	var cond_row := HBoxContainer.new()
	card_vbox.add_child(cond_row)
	var cond_label := Label.new()
	cond_label.text = "Condition Flag:"
	cond_label.custom_minimum_size.x = 100
	cond_row.add_child(cond_label)
	var cond_edit := LineEdit.new()
	cond_edit.text = conv.condition_flag
	cond_edit.placeholder_text = "(always show)"
	cond_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cond_edit.text_changed.connect(func(new_text: String) -> void:
		conv.condition_flag = new_text
		_mark_dirty(npc.id)
	)
	cond_row.add_child(cond_edit)

	# Condition value
	var cval_row := HBoxContainer.new()
	card_vbox.add_child(cval_row)
	var cval_label := Label.new()
	cval_label.text = "Condition Value:"
	cval_label.custom_minimum_size.x = 100
	cval_row.add_child(cval_label)
	var cval_edit := LineEdit.new()
	cval_edit.text = str(conv.condition_value)
	cval_edit.placeholder_text = "true"
	cval_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cval_edit.text_changed.connect(func(new_text: String) -> void:
		if new_text == "true":
			conv.condition_value = true
		elif new_text == "false":
			conv.condition_value = false
		elif new_text.is_valid_int():
			conv.condition_value = new_text.to_int()
		else:
			conv.condition_value = new_text
		_mark_dirty(npc.id)
	)
	cval_row.add_child(cval_edit)

	# Auto next ID
	var auto_row := HBoxContainer.new()
	card_vbox.add_child(auto_row)
	var auto_label := Label.new()
	auto_label.text = "Auto Next ID:"
	auto_label.custom_minimum_size.x = 100
	auto_row.add_child(auto_label)
	var auto_edit := LineEdit.new()
	auto_edit.text = conv.auto_next_id
	auto_edit.placeholder_text = "(end dialogue)"
	auto_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_edit.text_changed.connect(func(new_text: String) -> void:
		conv.auto_next_id = new_text
		_mark_dirty(npc.id)
	)
	auto_row.add_child(auto_edit)

	# Lines sub-section
	var lines_sep := HSeparator.new()
	lines_sep.add_theme_constant_override("separation", 4)
	card_vbox.add_child(lines_sep)

	var lines_header := Label.new()
	lines_header.text = "Lines"
	lines_header.add_theme_font_size_override("font_size", 14)
	lines_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	card_vbox.add_child(lines_header)

	for line_idx in range(conv.lines.size()):
		_build_line_editor(npc, conv, line_idx, card_vbox)

	var add_line_btn := Button.new()
	add_line_btn.text = "+ Add Line"
	add_line_btn.pressed.connect(func() -> void:
		conv.lines.append("New dialogue line...")
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	card_vbox.add_child(add_line_btn)

	# Choices sub-section
	var choices_sep := HSeparator.new()
	choices_sep.add_theme_constant_override("separation", 4)
	card_vbox.add_child(choices_sep)

	var choices_header := Label.new()
	choices_header.text = "Choices"
	choices_header.add_theme_font_size_override("font_size", 14)
	choices_header.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
	card_vbox.add_child(choices_header)

	for choice_idx in range(conv.choices.size()):
		_build_choice_editor(npc, conv, choice_idx, card_vbox)

	var add_choice_btn := Button.new()
	add_choice_btn.text = "+ Add Choice"
	add_choice_btn.pressed.connect(func() -> void:
		var new_choice := DialogueChoice.new()
		new_choice.text = "New choice..."
		conv.choices.append(new_choice)
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	card_vbox.add_child(add_choice_btn)


func _build_line_editor(npc: NpcData, conv: DialogueConversation, line_idx: int, parent: VBoxContainer) -> void:
	var line_row := HBoxContainer.new()
	line_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(line_row)

	var line_num := Label.new()
	line_num.text = "%d." % (line_idx + 1)
	line_num.custom_minimum_size.x = 24
	line_row.add_child(line_num)

	var text_edit := TextEdit.new()
	text_edit.text = conv.lines[line_idx]
	text_edit.custom_minimum_size.y = 50
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.text_changed.connect(func() -> void:
		conv.lines[line_idx] = text_edit.text
		_mark_dirty(npc.id)
	)
	line_row.add_child(text_edit)

	var del_btn := Button.new()
	del_btn.text = "X"
	del_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	del_btn.pressed.connect(func() -> void:
		conv.lines.remove_at(line_idx)
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	line_row.add_child(del_btn)


func _build_choice_editor(npc: NpcData, conv: DialogueConversation, choice_idx: int, parent: VBoxContainer) -> void:
	var choice: DialogueChoice = conv.choices[choice_idx]

	var choice_card := PanelContainer.new()
	var choice_style := StyleBoxFlat.new()
	choice_style.bg_color = Color(0.12, 0.14, 0.20, 0.6)
	choice_style.content_margin_left = 6
	choice_style.content_margin_right = 6
	choice_style.content_margin_top = 4
	choice_style.content_margin_bottom = 4
	choice_style.corner_radius_top_left = 3
	choice_style.corner_radius_top_right = 3
	choice_style.corner_radius_bottom_left = 3
	choice_style.corner_radius_bottom_right = 3
	choice_card.add_theme_stylebox_override("panel", choice_style)
	parent.add_child(choice_card)

	var choice_vbox := VBoxContainer.new()
	choice_vbox.add_theme_constant_override("separation", 3)
	choice_card.add_child(choice_vbox)

	# Choice header with delete
	var choice_header := HBoxContainer.new()
	choice_vbox.add_child(choice_header)

	var choice_label := Label.new()
	choice_label.text = "Choice %d" % (choice_idx + 1)
	choice_label.add_theme_font_size_override("font_size", 13)
	choice_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_header.add_child(choice_label)

	var del_choice_btn := Button.new()
	del_choice_btn.text = "X"
	del_choice_btn.add_theme_color_override("font_color", Color(1, 0.4, 0.4))
	del_choice_btn.pressed.connect(func() -> void:
		conv.choices.remove_at(choice_idx)
		_mark_dirty(npc.id)
		_rebuild_property_panel()
	)
	choice_header.add_child(del_choice_btn)

	# Text
	var text_row := HBoxContainer.new()
	choice_vbox.add_child(text_row)
	var text_label := Label.new()
	text_label.text = "Text:"
	text_label.custom_minimum_size.x = 100
	text_row.add_child(text_label)
	var text_edit := LineEdit.new()
	text_edit.text = choice.text
	text_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_edit.text_changed.connect(func(new_text: String) -> void:
		choice.text = new_text
		_mark_dirty(npc.id)
	)
	text_row.add_child(text_edit)

	# Next conversation ID
	var next_row := HBoxContainer.new()
	choice_vbox.add_child(next_row)
	var next_label := Label.new()
	next_label.text = "Next Conv:"
	next_label.custom_minimum_size.x = 100
	next_row.add_child(next_label)
	var next_edit := LineEdit.new()
	next_edit.text = choice.next_conversation_id
	next_edit.placeholder_text = "(end dialogue)"
	next_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	next_edit.text_changed.connect(func(new_text: String) -> void:
		choice.next_conversation_id = new_text
		_mark_dirty(npc.id)
	)
	next_row.add_child(next_edit)

	# Action
	var action_row := HBoxContainer.new()
	choice_vbox.add_child(action_row)
	var action_label := Label.new()
	action_label.text = "Action:"
	action_label.custom_minimum_size.x = 100
	action_row.add_child(action_label)

	var action_opt := OptionButton.new()
	action_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_action_idx: int = 0
	for i in range(ACTION_OPTIONS.size()):
		action_opt.add_item(ACTION_OPTIONS[i], i)
		if choice.action == ACTION_OPTIONS[i]:
			current_action_idx = i
		elif ACTION_OPTIONS[i].ends_with(":") and choice.action.begins_with(ACTION_OPTIONS[i]):
			current_action_idx = i
	action_opt.selected = current_action_idx
	action_row.add_child(action_opt)

	# Action parameter (for open_shop: and open_crafting:)
	var param_edit := LineEdit.new()
	param_edit.placeholder_text = "parameter"
	param_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var current_action: String = ACTION_OPTIONS[current_action_idx] if current_action_idx < ACTION_OPTIONS.size() else ""
	if current_action.ends_with(":") and choice.action.begins_with(current_action):
		param_edit.text = choice.action.substr(current_action.length())
	param_edit.visible = current_action.ends_with(":")
	action_row.add_child(param_edit)

	# Wire action changes
	action_opt.item_selected.connect(func(idx: int) -> void:
		var action_str: String = ACTION_OPTIONS[idx] if idx < ACTION_OPTIONS.size() else ""
		if action_str == "(none)":
			choice.action = ""
		elif action_str.ends_with(":"):
			choice.action = action_str + param_edit.text
			param_edit.visible = true
		else:
			choice.action = action_str
			param_edit.visible = false
		_mark_dirty(npc.id)
	)

	param_edit.text_changed.connect(func(new_text: String) -> void:
		var action_str: String = ACTION_OPTIONS[action_opt.selected] if action_opt.selected < ACTION_OPTIONS.size() else ""
		if action_str.ends_with(":"):
			choice.action = action_str + new_text
		_mark_dirty(npc.id)
	)

	# Set flag
	var flag_row := HBoxContainer.new()
	choice_vbox.add_child(flag_row)
	var flag_label := Label.new()
	flag_label.text = "Set Flag:"
	flag_label.custom_minimum_size.x = 100
	flag_row.add_child(flag_label)
	var flag_edit := LineEdit.new()
	flag_edit.text = choice.set_flag
	flag_edit.placeholder_text = "(none)"
	flag_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flag_edit.text_changed.connect(func(new_text: String) -> void:
		choice.set_flag = new_text
		_mark_dirty(npc.id)
	)
	flag_row.add_child(flag_edit)

	# Set flag value
	var fval_row := HBoxContainer.new()
	choice_vbox.add_child(fval_row)
	var fval_label := Label.new()
	fval_label.text = "Flag Value:"
	fval_label.custom_minimum_size.x = 100
	fval_row.add_child(fval_label)
	var fval_edit := LineEdit.new()
	fval_edit.text = str(choice.set_flag_value)
	fval_edit.placeholder_text = "true"
	fval_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fval_edit.text_changed.connect(func(new_text: String) -> void:
		if new_text == "true":
			choice.set_flag_value = true
		elif new_text == "false":
			choice.set_flag_value = false
		elif new_text.is_valid_int():
			choice.set_flag_value = new_text.to_int()
		else:
			choice.set_flag_value = new_text
		_mark_dirty(npc.id)
	)
	fval_row.add_child(fval_edit)


# =========================================================================
# UI Helpers
# =========================================================================

func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_property_vbox.add_child(label)


func _add_label_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	_property_vbox.add_child(label)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_property_vbox.add_child(sep)


func _update_hint_bar() -> void:
	_hint_bar.text = "NPCs: %d | Ctrl+S: save | Esc: back" % _npcs.size()
