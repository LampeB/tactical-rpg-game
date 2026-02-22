extends Control
## Passive skill tree screen. Lets players spend gold to unlock passive bonuses
## for each character. Double-click nodes to queue them, then confirm to batch unlock.

@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/GoldLabel
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs
@onready var _tree_view: Control = $VBox/Content/TreePanel/TreeView
@onready var _info_panel: PanelContainer = $VBox/Content/InfoPanel
@onready var _summary_vbox: VBoxContainer = $VBox/Content/InfoPanel/MainVBox/SummaryVBox
@onready var _summary_list: VBoxContainer = $VBox/Content/InfoPanel/MainVBox/SummaryVBox/SummaryScroll/SummaryList
@onready var _node_info_vbox: VBoxContainer = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox
@onready var _node_name_label: Label = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox/NodeName
@onready var _node_desc_label: Label = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox/Description
@onready var _node_cost_label: Label = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox/CostLabel
@onready var _prereqs_label: Label = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox/PrereqsLabel
@onready var _pending_vbox: VBoxContainer = $VBox/Content/InfoPanel/MainVBox/PendingVBox
@onready var _pending_list_label: Label = $VBox/Content/InfoPanel/MainVBox/PendingVBox/PendingList
@onready var _pending_cost_label: Label = $VBox/Content/InfoPanel/MainVBox/PendingVBox/PendingCostLabel
@onready var _confirm_btn: Button = $VBox/Content/InfoPanel/MainVBox/PendingVBox/ConfirmBtn
@onready var _cancel_btn: Button = $VBox/Content/InfoPanel/MainVBox/PendingVBox/CancelBtn

var _current_character_id: String = ""
var _selected_node_id: String = ""
var _current_tree: PassiveTreeData = null
var _pending_unlocks: Array = []
var _pending_total_cost: int = 0


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_confirm_btn.pressed.connect(_on_confirm_unlocks)
	_cancel_btn.pressed.connect(_on_cancel_unlocks)

	# Wire character tabs
	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	# Wire tree view signals
	_tree_view.node_selected.connect(_on_node_selected)
	_tree_view.node_double_clicked.connect(_on_node_double_clicked)
	_tree_view.node_hovered.connect(_on_node_hovered)
	_tree_view.node_exited.connect(_on_node_exited)

	# Listen for gold changes
	EventBus.gold_changed.connect(_on_gold_changed)

	# Select first squad member
	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])

	_update_gold_display()
	# Ensure panels are in correct initial state
	_info_panel.visible = true
	_summary_vbox.visible = true
	_node_info_vbox.visible = false
	_pending_vbox.visible = false
	DebugLogger.log_info("Passive tree scene ready", "PassiveTree")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


var _embedded: bool = false

func setup_embedded(character_id: String) -> void:
	_embedded = true
	$VBox/TopBar.visible = false
	$VBox/CharacterTabs.visible = false
	_on_character_selected(character_id)


# === Character Switching ===

func _on_character_selected(character_id: String) -> void:
	_current_character_id = character_id
	_current_tree = PassiveTreeDatabase.get_passive_tree()
	_selected_node_id = ""
	_tree_view.set_selected("")

	# Clear pending unlocks when switching characters
	_pending_unlocks.clear()
	_pending_total_cost = 0

	if _current_tree:
		_title.text = _current_tree.display_name
		var unlocked: Array = GameManager.party.get_unlocked_passives(character_id)
		var starting_nodes: Array = _get_starting_nodes(character_id)
		_tree_view.setup(_current_tree, unlocked, starting_nodes)
	else:
		_title.text = "No Skill Tree"
		_tree_view.setup(null, [], [])

	# Hide node info and pending, populate summary
	_node_info_vbox.visible = false
	_pending_vbox.visible = false
	_populate_summary.call_deferred()

	DebugLogger.log_info("Switched to character: %s" % character_id, "PassiveTree")


# === Node Interaction ===

func _on_node_selected(node_id: String) -> void:
	if node_id.is_empty():
		_selected_node_id = ""
		_tree_view.set_selected("")
		_hide_info_panel()
	elif _selected_node_id == node_id:
		_selected_node_id = ""
		_tree_view.set_selected("")
		_hide_info_panel()
	else:
		_selected_node_id = node_id
		_tree_view.set_selected(node_id)
		_show_node_info(node_id)


func _on_node_double_clicked(node_id: String) -> void:
	if not _current_tree or _current_character_id.is_empty():
		return

	# Already unlocked — ignore
	if GameManager.party.is_passive_unlocked(_current_character_id, node_id):
		return

	# Already pending — toggle off (and remove dependents)
	if _pending_unlocks.has(node_id):
		_remove_pending_with_dependents(node_id)
		_recalculate_pending_cost()
		_tree_view.set_pending(_pending_unlocks)
		_update_pending_ui()
		# Refresh node info if this node is selected
		if _selected_node_id == node_id:
			_show_node_info(node_id)
		return

	# Check if node is available (considering pending as unlocked)
	var node: PassiveNodeData = _current_tree.get_node_by_id(node_id)
	if not node:
		return

	if not _is_node_available(node):
		return

	# Add to pending
	_pending_unlocks.append(node_id)
	_recalculate_pending_cost()
	_tree_view.set_pending(_pending_unlocks)
	_update_pending_ui()

	# Refresh node info if this node is selected
	if _selected_node_id == node_id:
		_show_node_info(node_id)

	DebugLogger.log_info("Queued passive for unlock: %s" % node_id, "PassiveTree")


func _on_node_hovered(node_id: String) -> void:
	if _selected_node_id.is_empty():
		_show_node_info(node_id)


func _on_node_exited() -> void:
	if _selected_node_id.is_empty():
		_hide_info_panel()


func _is_node_available(node: PassiveNodeData) -> bool:
	## Check if a node can be queued, treating unlocked + pending as resolved.
	var resolved: Array = GameManager.party.get_unlocked_passives(_current_character_id).duplicate()
	resolved.append_array(_pending_unlocks)

	if node.prerequisites.is_empty():
		# Root node — must be in this character's starting nodes
		var starting_nodes: Array = _get_starting_nodes(_current_character_id)
		return starting_nodes.has(node.id)

	if node.prerequisite_mode == 1:
		# ANY mode
		for i in range(node.prerequisites.size()):
			if resolved.has(node.prerequisites[i]):
				return true
		return false
	else:
		# ALL mode
		for i in range(node.prerequisites.size()):
			if not resolved.has(node.prerequisites[i]):
				return false
		return true


func _remove_pending_with_dependents(node_id: String) -> void:
	## Remove a node from pending and also remove any pending nodes
	## that depend on it (would lose their prerequisites).
	_pending_unlocks.erase(node_id)

	# Iteratively remove nodes whose prerequisites are no longer met
	var changed: bool = true
	while changed:
		changed = false
		var to_remove: Array = []
		for i in range(_pending_unlocks.size()):
			var pid: String = _pending_unlocks[i]
			var pnode: PassiveNodeData = _current_tree.get_node_by_id(pid)
			if pnode and not _is_node_available(pnode):
				to_remove.append(pid)
				changed = true
		for rid in to_remove:
			_pending_unlocks.erase(rid)


func _recalculate_pending_cost() -> void:
	_pending_total_cost = 0
	for i in range(_pending_unlocks.size()):
		var node: PassiveNodeData = _current_tree.get_node_by_id(_pending_unlocks[i])
		if node:
			_pending_total_cost += node.gold_cost


func _show_node_info(node_id: String) -> void:
	if not _current_tree:
		return
	var node: PassiveNodeData = _current_tree.get_node_by_id(node_id)
	if not node:
		return

	_node_info_vbox.visible = true
	_info_panel.visible = true
	_node_name_label.text = node.display_name

	# Build description from stat modifiers and special effects
	var desc_parts: Array = []
	for i in range(node.stat_modifiers.size()):
		var mod: StatModifier = node.stat_modifiers[i]
		var stat_name: String = Enums.Stat.keys()[mod.stat].capitalize().replace("_", " ")
		if mod.modifier_type == Enums.ModifierType.FLAT:
			desc_parts.append("+%d %s" % [int(mod.value), stat_name])
		else:
			desc_parts.append("+%.0f%% %s" % [mod.value, stat_name])

	if not node.special_effect_id.is_empty():
		desc_parts.append(PassiveEffects.get_description(node.special_effect_id))

	if not node.description.is_empty():
		desc_parts.append(node.description)

	_node_desc_label.text = "\n".join(desc_parts) if not desc_parts.is_empty() else "No bonuses"

	# Cost / status
	var is_unlocked: bool = GameManager.party.is_passive_unlocked(_current_character_id, node_id)
	var is_pending: bool = _pending_unlocks.has(node_id)
	if is_unlocked:
		_node_cost_label.text = "UNLOCKED"
		_node_cost_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
	elif is_pending:
		_node_cost_label.text = "PENDING (%d Gold)" % node.gold_cost
		_node_cost_label.add_theme_color_override("font_color", Color(0.3, 0.7, 1.0))
	else:
		_node_cost_label.text = "Cost: %d Gold" % node.gold_cost
		_node_cost_label.remove_theme_color_override("font_color")

	# Prerequisites
	if node.prerequisites.is_empty():
		_prereqs_label.text = ""
	else:
		var prereq_names: Array = []
		for j in range(node.prerequisites.size()):
			var prereq: PassiveNodeData = _current_tree.get_node_by_id(node.prerequisites[j])
			if prereq:
				prereq_names.append(prereq.display_name)
		var join_word: String = " or " if node.prerequisite_mode == 1 else ", "
		_prereqs_label.text = "Requires: %s" % join_word.join(prereq_names)


func _hide_info_panel() -> void:
	_node_info_vbox.visible = false
	_selected_node_id = ""


func _update_pending_ui() -> void:
	if _pending_unlocks.is_empty():
		_pending_vbox.visible = false
		return

	_pending_vbox.visible = true

	# Build list of queued node names
	var names: Array = []
	for i in range(_pending_unlocks.size()):
		var node: PassiveNodeData = _current_tree.get_node_by_id(_pending_unlocks[i])
		if node:
			names.append("• %s (%d g)" % [node.display_name, node.gold_cost])
	_pending_list_label.text = "\n".join(names)

	_pending_cost_label.text = "Total: %d Gold" % _pending_total_cost

	# Enable/disable confirm based on gold
	var can_afford: bool = GameManager.gold >= _pending_total_cost
	_confirm_btn.disabled = not can_afford
	if can_afford:
		_confirm_btn.text = "Confirm Unlocks (%d Gold)" % _pending_total_cost
	else:
		_confirm_btn.text = "Not enough gold (%d/%d)" % [GameManager.gold, _pending_total_cost]


func _populate_summary() -> void:
	DebugLogger.log_info("Populating summary for character: %s" % _current_character_id, "PassiveTree")

	if not _summary_list or not is_inside_tree():
		DebugLogger.log_warn("Summary list not ready, deferring", "PassiveTree")
		_populate_summary.call_deferred()
		return

	# Clear existing summary items
	for child in _summary_list.get_children():
		_summary_list.remove_child(child)
		child.queue_free()

	if not _current_tree or _current_character_id.is_empty():
		var label: Label = Label.new()
		label.text = "No character selected"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD
		_summary_list.add_child(label)
		return

	var unlocked: Array = GameManager.party.get_unlocked_passives(_current_character_id)

	if unlocked.is_empty():
		var label: Label = Label.new()
		label.text = "No passives unlocked yet"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Constants.COLOR_TEXT_SECONDARY
		_summary_list.add_child(label)
		return

	for i in range(unlocked.size()):
		var node_id: String = unlocked[i]
		var node: PassiveNodeData = _current_tree.get_node_by_id(node_id)
		if not node:
			continue

		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var name_label: Label = Label.new()
		name_label.text = node.display_name
		name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_HEADER)
		name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_HEADER)
		row.add_child(name_label)

		var desc_parts: Array = []
		for j in range(node.stat_modifiers.size()):
			var mod: StatModifier = node.stat_modifiers[j]
			var stat_name: String = Enums.Stat.keys()[mod.stat].capitalize().replace("_", " ")
			if mod.modifier_type == Enums.ModifierType.FLAT:
				desc_parts.append("+%d %s" % [int(mod.value), stat_name])
			else:
				desc_parts.append("+%.0f%% %s" % [mod.value, stat_name])

		if not node.special_effect_id.is_empty():
			desc_parts.append(PassiveEffects.get_description(node.special_effect_id))

		var desc_label: Label = Label.new()
		desc_label.text = " • " + "\n • ".join(desc_parts) if not desc_parts.is_empty() else " • No bonuses"
		desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD
		desc_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_PRIMARY)
		row.add_child(desc_label)

		var separator: HSeparator = HSeparator.new()
		separator.add_theme_constant_override("separation", 8)
		row.add_child(separator)

		_summary_list.add_child(row)


# === Actions ===

func _on_confirm_unlocks() -> void:
	if _pending_unlocks.is_empty() or not _current_tree:
		return

	if not GameManager.spend_gold(_pending_total_cost):
		DebugLogger.log_warn("Cannot afford pending unlocks: %d gold needed" % _pending_total_cost, "PassiveTree")
		return

	# Unlock all pending nodes
	for i in range(_pending_unlocks.size()):
		var node_id: String = _pending_unlocks[i]
		GameManager.party.unlock_passive(_current_character_id, node_id)
		EventBus.passive_unlocked.emit(_current_character_id, node_id)

	var count: int = _pending_unlocks.size()
	var cost: int = _pending_total_cost

	# Clear pending state
	_pending_unlocks.clear()
	_pending_total_cost = 0

	# Refresh display
	var unlocked: Array = GameManager.party.get_unlocked_passives(_current_character_id)
	_tree_view.update_unlocked(unlocked)
	_tree_view.set_pending([])
	_update_gold_display()
	_update_pending_ui()
	_populate_summary.call_deferred()

	# Refresh selected node info if any
	if not _selected_node_id.is_empty():
		_show_node_info(_selected_node_id)

	DebugLogger.log_info("Confirmed %d passive unlocks for %s (cost: %d)" % [
		count, _current_character_id, cost
	], "PassiveTree")


func _on_cancel_unlocks() -> void:
	_pending_unlocks.clear()
	_pending_total_cost = 0
	_tree_view.set_pending([])
	_update_pending_ui()

	# Refresh selected node info if any
	if not _selected_node_id.is_empty():
		_show_node_info(_selected_node_id)

	DebugLogger.log_info("Cancelled pending unlocks", "PassiveTree")


func _on_back() -> void:
	SceneManager.pop_scene()


func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()
	_update_pending_ui()
	# Refresh node info if a node is selected
	if not _selected_node_id.is_empty() and _current_tree:
		_show_node_info(_selected_node_id)


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold


func _get_starting_nodes(character_id: String) -> Array:
	if not GameManager.party or not GameManager.party.roster.has(character_id):
		return []
	var char_data: CharacterData = GameManager.party.roster[character_id]
	return char_data.starting_passive_nodes
