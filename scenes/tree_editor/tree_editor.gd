extends Control
## In-game skill tree editor. Load, edit, and save the unified PassiveTreeData.
## Accessible from the main menu — no game session required.

@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _save_btn: Button = $VBox/TopBar/SaveButton
@onready var _status_label: Label = $VBox/TopBar/StatusLabel
@onready var _editor_view: Control = $VBox/Content/TreePanel/TreeEditorView
@onready var _property_vbox: VBoxContainer = $VBox/Content/PropertyPanel/PropertyScroll/PropertyVBox
@onready var _hint_bar: Label = $VBox/HintBar

var _tree_data: PassiveTreeData = null
var _selected_node_id: String = ""

# Effect IDs for the dropdown
const EFFECT_IDS: Array = [
	"", "counter_attack", "lifesteal_5", "lifesteal_10",
	"start_shield", "thorns", "mana_regen", "evasion",
	"first_strike", "double_gold",
]


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_save_btn.pressed.connect(_on_save)

	# Load a duplicate of the tree so we don't mutate the live game data
	var source: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	if source:
		_tree_data = source.duplicate(true) as PassiveTreeData
	else:
		_tree_data = PassiveTreeData.new()
		_tree_data.display_name = "Skill Tree"

	_editor_view.setup_editor(_tree_data)

	# Wire editor view signals
	_editor_view.node_selected.connect(_on_node_selected)
	_editor_view.node_created.connect(_on_node_created)
	_editor_view.node_moved.connect(_on_node_moved)
	_editor_view.connection_toggled.connect(_on_connection_toggled)

	_update_hint_bar()
	DebugLogger.log_info("Tree editor ready (%d nodes)" % _tree_data.nodes.size(), "TreeEditor")


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_DELETE:
			if not _selected_node_id.is_empty():
				_on_node_deleted(_selected_node_id)
				get_viewport().set_input_as_handled()
		elif event.keycode == KEY_S and event.ctrl_pressed:
			_on_save()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


# === Node CRUD ===

func _on_node_selected(node_id: String) -> void:
	_selected_node_id = node_id
	if node_id.is_empty():
		_clear_property_panel()
	else:
		var node: PassiveNodeData = _tree_data.get_node_by_id(node_id)
		if node:
			_build_property_panel(node)
		else:
			_clear_property_panel()


func _on_node_created(position: Vector2) -> void:
	var new_node := PassiveNodeData.new()
	new_node.id = _generate_unique_id()
	new_node.display_name = "New Node"
	new_node.position = position
	new_node.gold_cost = 50
	_tree_data.nodes.append(new_node)

	# Auto-select the new node
	_selected_node_id = new_node.id
	_editor_view.set_selected(new_node.id)
	_editor_view.queue_redraw()
	_build_property_panel(new_node)
	_update_hint_bar()

	DebugLogger.log_info("Created node: %s at %s" % [new_node.id, str(position)], "TreeEditor")


func _on_node_deleted(node_id: String) -> void:
	var node: PassiveNodeData = _tree_data.get_node_by_id(node_id)
	if not node:
		return

	# Remove from tree
	_tree_data.nodes.erase(node)

	# Clean up: remove this ID from all other nodes' prerequisites
	for i in range(_tree_data.nodes.size()):
		var other: PassiveNodeData = _tree_data.nodes[i]
		if other and other.prerequisites.has(node_id):
			other.prerequisites.erase(node_id)

	_selected_node_id = ""
	_editor_view.set_selected("")
	_editor_view.queue_redraw()
	_clear_property_panel()
	_update_hint_bar()

	DebugLogger.log_info("Deleted node: %s" % node_id, "TreeEditor")


func _on_node_moved(node_id: String, new_position: Vector2) -> void:
	# Refresh property panel position display
	if _selected_node_id == node_id:
		var node: PassiveNodeData = _tree_data.get_node_by_id(node_id)
		if node:
			_build_property_panel(node)


func _on_connection_toggled(from_id: String, to_id: String) -> void:
	if from_id == to_id:
		return
	var node: PassiveNodeData = _tree_data.get_node_by_id(from_id)
	if not node:
		return

	if node.prerequisites.has(to_id):
		node.prerequisites.erase(to_id)
		DebugLogger.log_info("Removed connection: %s -> %s" % [to_id, from_id], "TreeEditor")
	else:
		node.prerequisites.append(to_id)
		DebugLogger.log_info("Added connection: %s -> %s" % [to_id, from_id], "TreeEditor")

	_editor_view.queue_redraw()

	# Refresh property panel if this node is selected
	if _selected_node_id == from_id:
		_build_property_panel(node)


# === Save / Back ===

func _on_save() -> void:
	var err := ResourceSaver.save(_tree_data, PassiveTreeDatabase.TREE_PATH)
	if err == OK:
		_status_label.text = "Saved!"
		_status_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
		# Reload in PassiveTreeDatabase so the game picks up changes
		PassiveTreeDatabase._tree = _tree_data.duplicate(true) as PassiveTreeData
		DebugLogger.log_info("Saved passive tree (%d nodes)" % _tree_data.nodes.size(), "TreeEditor")
	else:
		_status_label.text = "Save failed!"
		_status_label.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
		DebugLogger.log_error("Failed to save passive tree: %d" % err, "TreeEditor")

	# Clear status after 2 seconds
	await get_tree().create_timer(2.0).timeout
	if is_inside_tree():
		_status_label.text = ""


func _on_back() -> void:
	SceneManager.pop_scene()


# === Property Panel ===

func _clear_property_panel() -> void:
	for child in _property_vbox.get_children():
		_property_vbox.remove_child(child)
		child.queue_free()

	var label: Label = Label.new()
	label.text = "Click a node to edit its properties.\nDouble-click empty space to add a node."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_property_vbox.add_child(label)


func _build_property_panel(node: PassiveNodeData) -> void:
	# Clear existing content
	for child in _property_vbox.get_children():
		_property_vbox.remove_child(child)
		child.queue_free()

	# === Identity ===
	_add_section_header("Identity")

	_add_label_row("ID:")
	var id_edit: LineEdit = LineEdit.new()
	id_edit.text = node.id
	id_edit.placeholder_text = "unique_id"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_submitted.connect(func(new_text: String) -> void:
		var old_id: String = node.id
		var trimmed: String = new_text.strip_edges().replace(" ", "_")
		if trimmed.is_empty() or (trimmed != old_id and _tree_data.get_node_by_id(trimmed)):
			id_edit.text = old_id  # Revert invalid/duplicate
			return
		# Update ID in all prerequisite references
		for i in range(_tree_data.nodes.size()):
			var other: PassiveNodeData = _tree_data.nodes[i]
			if other:
				for j in range(other.prerequisites.size()):
					if other.prerequisites[j] == old_id:
						other.prerequisites[j] = trimmed
		node.id = trimmed
		_selected_node_id = trimmed
		_editor_view.set_selected(trimmed)
		_editor_view.queue_redraw()
	)
	_property_vbox.add_child(id_edit)

	_add_label_row("Name:")
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = node.display_name
	name_edit.placeholder_text = "Display Name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text: String) -> void:
		node.display_name = new_text
		_editor_view.queue_redraw()
	)
	_property_vbox.add_child(name_edit)

	_add_label_row("Description:")
	var desc_edit: TextEdit = TextEdit.new()
	desc_edit.text = node.description
	desc_edit.custom_minimum_size = Vector2(0, 60)
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.text_changed.connect(func() -> void:
		node.description = desc_edit.text
	)
	_property_vbox.add_child(desc_edit)

	_add_separator()

	# === Cost ===
	_add_section_header("Cost")
	var cost_hbox: HBoxContainer = HBoxContainer.new()
	var cost_label: Label = Label.new()
	cost_label.text = "Gold:"
	cost_hbox.add_child(cost_label)
	var cost_spin: SpinBox = SpinBox.new()
	cost_spin.min_value = 0
	cost_spin.max_value = 9999
	cost_spin.step = 25
	cost_spin.value = node.gold_cost
	cost_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cost_spin.value_changed.connect(func(val: float) -> void:
		node.gold_cost = int(val)
	)
	cost_hbox.add_child(cost_spin)
	_property_vbox.add_child(cost_hbox)

	_add_separator()

	# === Position (read-only) ===
	_add_label_row("Position: (%d, %d)" % [int(node.position.x), int(node.position.y)])

	_add_separator()

	# === Prerequisites ===
	_add_section_header("Prerequisites")

	var mode_hbox: HBoxContainer = HBoxContainer.new()
	var mode_label: Label = Label.new()
	mode_label.text = "Mode:"
	mode_hbox.add_child(mode_label)
	var mode_btn: OptionButton = OptionButton.new()
	mode_btn.add_item("ALL (default)", 0)
	mode_btn.add_item("ANY", 1)
	mode_btn.selected = node.prerequisite_mode
	mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mode_btn.item_selected.connect(func(idx: int) -> void:
		node.prerequisite_mode = idx
	)
	mode_hbox.add_child(mode_btn)
	_property_vbox.add_child(mode_hbox)

	if node.prerequisites.is_empty():
		var no_prereqs: Label = Label.new()
		no_prereqs.text = "No prerequisites (root node)"
		no_prereqs.modulate = Color(0.7, 0.7, 0.7)
		_property_vbox.add_child(no_prereqs)
	else:
		for j in range(node.prerequisites.size()):
			var prereq_id: String = node.prerequisites[j]
			var prereq_node: PassiveNodeData = _tree_data.get_node_by_id(prereq_id)
			var prereq_row: HBoxContainer = HBoxContainer.new()
			var prereq_label: Label = Label.new()
			prereq_label.text = prereq_id
			if prereq_node:
				prereq_label.text += " (%s)" % prereq_node.display_name
			prereq_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			prereq_row.add_child(prereq_label)
			var remove_btn: Button = Button.new()
			remove_btn.text = "X"
			var captured_id: String = prereq_id
			remove_btn.pressed.connect(func() -> void:
				node.prerequisites.erase(captured_id)
				_editor_view.queue_redraw()
				_build_property_panel(node)
			)
			prereq_row.add_child(remove_btn)
			_property_vbox.add_child(prereq_row)

	var link_hint: Label = Label.new()
	link_hint.text = "Shift+click on canvas to link"
	link_hint.modulate = Color(0.6, 0.6, 0.6)
	link_hint.add_theme_font_size_override("font_size", 12)
	_property_vbox.add_child(link_hint)

	_add_separator()

	# === Stat Modifiers ===
	_add_section_header("Stat Modifiers")

	for j in range(node.stat_modifiers.size()):
		var mod: StatModifier = node.stat_modifiers[j]
		_add_modifier_row(node, mod, j)

	var add_mod_btn: Button = Button.new()
	add_mod_btn.text = "+ Add Modifier"
	add_mod_btn.pressed.connect(func() -> void:
		var new_mod: StatModifier = StatModifier.new()
		new_mod.stat = Enums.Stat.MAX_HP
		new_mod.modifier_type = Enums.ModifierType.FLAT
		new_mod.value = 5.0
		node.stat_modifiers.append(new_mod)
		_build_property_panel(node)
	)
	_property_vbox.add_child(add_mod_btn)

	_add_separator()

	# === Special Effect ===
	_add_section_header("Special Effect")

	var effect_btn: OptionButton = OptionButton.new()
	effect_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for j in range(EFFECT_IDS.size()):
		var eid: String = EFFECT_IDS[j]
		if eid.is_empty():
			effect_btn.add_item("(none)", j)
		else:
			var desc: String = PassiveEffects.get_description(eid)
			effect_btn.add_item("%s — %s" % [eid, desc], j)
	# Select current
	var current_idx: int = 0
	for j in range(EFFECT_IDS.size()):
		if EFFECT_IDS[j] == node.special_effect_id:
			current_idx = j
			break
	effect_btn.selected = current_idx
	effect_btn.item_selected.connect(func(idx: int) -> void:
		node.special_effect_id = EFFECT_IDS[idx]
	)
	_property_vbox.add_child(effect_btn)

	_add_separator()

	# === Delete Button ===
	var delete_btn: Button = Button.new()
	delete_btn.text = "Delete Node"
	delete_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	delete_btn.pressed.connect(func() -> void:
		_on_node_deleted(node.id)
	)
	_property_vbox.add_child(delete_btn)


func _add_modifier_row(node: PassiveNodeData, mod: StatModifier, index: int) -> void:
	var row: VBoxContainer = VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top_row: HBoxContainer = HBoxContainer.new()

	# Stat dropdown
	var stat_btn: OptionButton = OptionButton.new()
	var stat_keys: PackedStringArray = Enums.Stat.keys()
	for k in range(stat_keys.size()):
		stat_btn.add_item(stat_keys[k].capitalize().replace("_", " "), k)
	stat_btn.selected = mod.stat
	stat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_btn.item_selected.connect(func(idx: int) -> void:
		mod.stat = idx
		_editor_view.queue_redraw()
	)
	top_row.add_child(stat_btn)

	# Remove button
	var remove_btn: Button = Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func() -> void:
		node.stat_modifiers.erase(mod)
		_build_property_panel(node)
		_editor_view.queue_redraw()
	)
	top_row.add_child(remove_btn)
	row.add_child(top_row)

	var bottom_row: HBoxContainer = HBoxContainer.new()

	# Type dropdown
	var type_btn: OptionButton = OptionButton.new()
	type_btn.add_item("Flat", 0)
	type_btn.add_item("Percent", 1)
	type_btn.selected = mod.modifier_type
	type_btn.item_selected.connect(func(idx: int) -> void:
		mod.modifier_type = idx
		_editor_view.queue_redraw()
	)
	bottom_row.add_child(type_btn)

	# Value spinbox
	var val_spin: SpinBox = SpinBox.new()
	val_spin.min_value = -999
	val_spin.max_value = 999
	val_spin.step = 1
	val_spin.value = mod.value
	val_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_spin.value_changed.connect(func(val: float) -> void:
		mod.value = val
		_editor_view.queue_redraw()
	)
	bottom_row.add_child(val_spin)
	row.add_child(bottom_row)

	_property_vbox.add_child(row)


# === Helpers ===

func _add_section_header(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_property_vbox.add_child(label)


func _add_label_row(text: String) -> void:
	var label: Label = Label.new()
	label.text = text
	_property_vbox.add_child(label)


func _add_separator() -> void:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_property_vbox.add_child(sep)


func _generate_unique_id() -> String:
	var base: String = "node_%d" % Time.get_ticks_msec()
	# Ensure uniqueness
	while _tree_data.get_node_by_id(base):
		base += "_"
	return base


func _update_hint_bar() -> void:
	_hint_bar.text = "Nodes: %d | Dbl-click: add | Del: delete | Shift+click: link/unlink | Drag: move" % _tree_data.nodes.size()
