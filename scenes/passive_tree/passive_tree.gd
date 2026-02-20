extends Control
## Passive skill tree screen. Lets players spend gold to unlock passive bonuses
## for each character. Uses TreeView for rendering and CharacterTabs for switching.

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
@onready var _unlock_btn: Button = $VBox/Content/InfoPanel/MainVBox/NodeInfoVBox/UnlockButton

var _current_character_id: String = ""
var _selected_node_id: String = ""
var _current_tree: PassiveTreeData = null


func _ready() -> void:
	_back_btn.pressed.connect(_on_back)
	_unlock_btn.pressed.connect(_on_unlock)

	# Wire character tabs
	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	# Wire tree view signals
	_tree_view.node_selected.connect(_on_node_selected)
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
	_current_tree = PassiveTreeDatabase.get_passive_tree(character_id)
	_selected_node_id = ""
	_tree_view.set_selected("")

	if _current_tree:
		_title.text = _current_tree.display_name
		var unlocked: Array = GameManager.party.get_unlocked_passives(character_id)
		_tree_view.setup(_current_tree, unlocked)
	else:
		_title.text = "No Skill Tree"
		_tree_view.setup(null, [])

	# Hide node info and populate summary
	_node_info_vbox.visible = false
	_populate_summary.call_deferred()

	DebugLogger.log_info("Switched to character: %s" % character_id, "PassiveTree")


# === Node Interaction ===

func _on_node_selected(node_id: String) -> void:
	# Handle background clicks (empty string) or node clicks
	if node_id.is_empty():
		# Clicked background - deselect
		_selected_node_id = ""
		_tree_view.set_selected("")
		_hide_info_panel()
	elif _selected_node_id == node_id:
		# Clicked same node - deselect
		_selected_node_id = ""
		_tree_view.set_selected("")
		_hide_info_panel()
	else:
		# Clicked different node - select it
		_selected_node_id = node_id
		_tree_view.set_selected(node_id)
		_show_node_info(node_id)


func _on_node_hovered(node_id: String) -> void:
	if _selected_node_id.is_empty():
		_show_node_info(node_id)


func _on_node_exited() -> void:
	if _selected_node_id.is_empty():
		_hide_info_panel()


func _show_node_info(node_id: String) -> void:
	if not _current_tree:
		return
	var node: PassiveNodeData = _current_tree.get_node_by_id(node_id)
	if not node:
		return

	# Show node info below summary (both visible)
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

	# Cost
	var is_unlocked: bool = GameManager.party.is_passive_unlocked(_current_character_id, node_id)
	if is_unlocked:
		_node_cost_label.text = "UNLOCKED"
		_node_cost_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SUCCESS)
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
		_prereqs_label.text = "Requires: %s" % ", ".join(prereq_names)

	# Unlock button state
	_update_unlock_button(node, is_unlocked)


func _hide_info_panel() -> void:
	DebugLogger.log_info("Hiding node info panel", "PassiveTree")
	# Hide node info, keep summary visible
	_node_info_vbox.visible = false
	_selected_node_id = ""


func _populate_summary() -> void:
	DebugLogger.log_info("Populating summary for character: %s" % _current_character_id, "PassiveTree")

	# Safety check - ensure UI nodes are ready
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
		DebugLogger.log_warn("No tree or character ID", "PassiveTree")
		return

	# Get unlocked passives for current character
	var unlocked: Array = GameManager.party.get_unlocked_passives(_current_character_id)
	DebugLogger.log_info("Found %d unlocked passives: %s" % [unlocked.size(), str(unlocked)], "PassiveTree")

	if unlocked.is_empty():
		var label: Label = Label.new()
		label.text = "No passives unlocked yet"
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.modulate = Constants.COLOR_TEXT_SECONDARY
		_summary_list.add_child(label)
		return

	# Build summary for each unlocked passive
	for i in range(unlocked.size()):
		var node_id: String = unlocked[i]
		var node: PassiveNodeData = _current_tree.get_node_by_id(node_id)
		if not node:
			continue

		# Create row container
		var row: VBoxContainer = VBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		# Node name (bold/larger)
		var name_label: Label = Label.new()
		name_label.text = node.display_name
		name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_HEADER)
		name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_HEADER)
		row.add_child(name_label)

		# Effects description (same format as node info)
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

		# Separator
		var separator: HSeparator = HSeparator.new()
		separator.add_theme_constant_override("separation", 8)
		row.add_child(separator)

		_summary_list.add_child(row)
		DebugLogger.log_info("Added summary row for: %s" % node.display_name, "PassiveTree")


func _update_unlock_button(node: PassiveNodeData, is_unlocked: bool) -> void:
	if is_unlocked:
		_unlock_btn.text = "Unlocked"
		_unlock_btn.disabled = true
		return

	# Check prerequisites
	var prereqs_met: bool = true
	for i in range(node.prerequisites.size()):
		if not GameManager.party.is_passive_unlocked(_current_character_id, node.prerequisites[i]):
			prereqs_met = false
			break

	var can_afford: bool = GameManager.gold >= node.gold_cost

	if not prereqs_met:
		_unlock_btn.text = "Prerequisites not met"
		_unlock_btn.disabled = true
	elif not can_afford:
		_unlock_btn.text = "Not enough gold (%d)" % node.gold_cost
		_unlock_btn.disabled = true
	else:
		_unlock_btn.text = "Unlock (%d Gold)" % node.gold_cost
		_unlock_btn.disabled = false


# === Actions ===

func _on_unlock() -> void:
	if _selected_node_id.is_empty() or not _current_tree:
		return
	var node: PassiveNodeData = _current_tree.get_node_by_id(_selected_node_id)
	if not node:
		return

	if GameManager.party.is_passive_unlocked(_current_character_id, _selected_node_id):
		return

	if not GameManager.spend_gold(node.gold_cost):
		return

	GameManager.party.unlock_passive(_current_character_id, _selected_node_id)
	EventBus.passive_unlocked.emit(_current_character_id, _selected_node_id)

	# Refresh display
	var unlocked: Array = GameManager.party.get_unlocked_passives(_current_character_id)
	_tree_view.update_unlocked(unlocked)
	_update_gold_display()
	_show_node_info(_selected_node_id)
	# Also refresh summary in case user deselects the node
	_populate_summary.call_deferred()

	DebugLogger.log_info("Unlocked passive: %s for %s (cost: %d)" % [
		node.display_name, _current_character_id, node.gold_cost
	], "PassiveTree")


func _on_back() -> void:
	SceneManager.pop_scene()


func _on_gold_changed(new_gold: int) -> void:
	_update_gold_display()
	# Refresh unlock button if a node is selected
	if not _selected_node_id.is_empty() and _current_tree:
		var node: PassiveNodeData = _current_tree.get_node_by_id(_selected_node_id)
		if node:
			var is_unlocked: bool = GameManager.party.is_passive_unlocked(_current_character_id, _selected_node_id)
			_update_unlock_button(node, is_unlocked)


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
