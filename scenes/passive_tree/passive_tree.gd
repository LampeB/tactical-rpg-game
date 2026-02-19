extends Control
## Passive skill tree screen. Lets players spend gold to unlock passive bonuses
## for each character. Uses TreeView for rendering and CharacterTabs for switching.

@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _title: Label = $VBox/TopBar/Title
@onready var _gold_label: Label = $VBox/TopBar/GoldLabel
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs
@onready var _tree_view: Control = $VBox/Content/TreePanel/TreeView
@onready var _info_panel: PanelContainer = $VBox/Content/InfoPanel
@onready var _node_name_label: Label = $VBox/Content/InfoPanel/VBox/NodeName
@onready var _node_desc_label: Label = $VBox/Content/InfoPanel/VBox/Description
@onready var _node_cost_label: Label = $VBox/Content/InfoPanel/VBox/CostLabel
@onready var _prereqs_label: Label = $VBox/Content/InfoPanel/VBox/PrereqsLabel
@onready var _unlock_btn: Button = $VBox/Content/InfoPanel/VBox/UnlockButton

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
	_hide_info_panel()
	DebugLogger.log_info("Passive tree scene ready", "PassiveTree")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


# === Character Switching ===

func _on_character_selected(character_id: String) -> void:
	_current_character_id = character_id
	_current_tree = PassiveTreeDatabase.get_passive_tree(character_id)
	_selected_node_id = ""
	_hide_info_panel()

	if _current_tree:
		_title.text = _current_tree.display_name
		var unlocked: Array = GameManager.party.get_unlocked_passives(character_id)
		_tree_view.setup(_current_tree, unlocked)
	else:
		_title.text = "No Skill Tree"
		_tree_view.setup(null, [])

	DebugLogger.log_info("Switched to character: %s" % character_id, "PassiveTree")


# === Node Interaction ===

func _on_node_selected(node_id: String) -> void:
	_selected_node_id = node_id
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
		desc_parts.append(_get_effect_description(node.special_effect_id))

	if not node.description.is_empty():
		desc_parts.append(node.description)

	_node_desc_label.text = "\n".join(desc_parts) if not desc_parts.is_empty() else "No bonuses"

	# Cost
	var is_unlocked: bool = GameManager.party.is_passive_unlocked(_current_character_id, node_id)
	if is_unlocked:
		_node_cost_label.text = "UNLOCKED"
		_node_cost_label.add_theme_color_override("font_color", Color(0.2, 0.8, 0.3))
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
	_info_panel.visible = false
	_selected_node_id = ""


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


func _get_effect_description(effect_id: String) -> String:
	match effect_id:
		PassiveEffects.COUNTER_ATTACK:
			return "15% chance to counter-attack"
		PassiveEffects.LIFESTEAL_5:
			return "Heal 5% of damage dealt"
		PassiveEffects.LIFESTEAL_10:
			return "Heal 10% of damage dealt"
		PassiveEffects.START_SHIELD:
			return "Gain 15 HP shield at battle start"
		PassiveEffects.THORNS:
			return "Reflect 5 damage when hit"
		PassiveEffects.MANA_REGEN:
			return "Restore 3 MP each turn"
		PassiveEffects.EVASION:
			return "10% chance to dodge attacks"
		PassiveEffects.FIRST_STRIKE:
			return "+50 Speed in round 1"
		PassiveEffects.DOUBLE_GOLD:
			return "Double gold earned from battles"
		_:
			return effect_id
