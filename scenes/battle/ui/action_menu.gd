extends PanelContainer
## Action selection menu for player turns: Attack, Defend, Skills, Flee.
## Actions that don't require target selection show a Confirm/Cancel step.

signal action_chosen(action_type: int, skill: SkillData, target_type: int)

var _current_entity: CombatEntity
var _skill_buttons: Array = []

# Pending action awaiting confirmation
var _pending_action: int = -1
var _pending_skill: SkillData = null
var _pending_target_type: int = -1

@onready var _main_buttons: HBoxContainer = $VBox/MainButtons
@onready var _attack_btn: Button = $VBox/MainButtons/AttackButton
@onready var _defend_btn: Button = $VBox/MainButtons/DefendButton
@onready var _skills_btn: Button = $VBox/MainButtons/SkillsButton
@onready var _flee_btn: Button = $VBox/MainButtons/FleeButton
@onready var _skill_list: VBoxContainer = $VBox/SkillList
@onready var _back_btn: Button = $VBox/SkillList/BackButton
@onready var _confirm_bar: VBoxContainer = $VBox/ConfirmBar
@onready var _confirm_label: Label = $VBox/ConfirmBar/ConfirmLabel
@onready var _confirm_btn: Button = $VBox/ConfirmBar/ConfirmButtons/ConfirmButton
@onready var _cancel_btn: Button = $VBox/ConfirmBar/ConfirmButtons/CancelButton


func _ready() -> void:
	_attack_btn.pressed.connect(_on_attack)
	_defend_btn.pressed.connect(_on_defend)
	_skills_btn.pressed.connect(_on_skills_open)
	_flee_btn.pressed.connect(_on_flee)
	_back_btn.pressed.connect(_on_skills_close)
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	_skill_list.visible = false
	_confirm_bar.visible = false


func show_for_entity(entity: CombatEntity, can_flee: bool = true) -> void:
	_current_entity = entity
	_main_buttons.visible = true
	_skill_list.visible = false
	_confirm_bar.visible = false
	_flee_btn.disabled = not can_flee

	# Check if entity has any usable skills
	var skills: Array = entity.get_available_skills()
	var _has_usable: bool = false
	for i in range(skills.size()):
		var skill: SkillData = skills[i]
		if entity.can_use_skill(skill):
			_has_usable = true
			break
	_skills_btn.disabled = skills.is_empty()
	visible = true


func hide_menu() -> void:
	visible = false
	_skill_list.visible = false
	_confirm_bar.visible = false


# === Main Actions ===

func _on_attack() -> void:
	# Attack always needs target selection, so emit directly (no confirm needed)
	action_chosen.emit(Enums.CombatAction.ATTACK, null, Enums.TargetType.SINGLE_ENEMY)


func _on_defend() -> void:
	_show_confirm("Defend this turn?", Enums.CombatAction.DEFEND, null, Enums.TargetType.SELF)


func _on_flee() -> void:
	_show_confirm("Attempt to flee?", Enums.CombatAction.FLEE, null, Enums.TargetType.SELF)


func _on_skills_open() -> void:
	_main_buttons.visible = false
	_skill_list.visible = true
	_build_skill_list()


func _on_skills_close() -> void:
	_main_buttons.visible = true
	_skill_list.visible = false


func _on_skill_selected(skill: SkillData) -> void:
	# Single-target skills go to target selection (no confirm needed, target click = confirm)
	if skill.target_type == Enums.TargetType.SINGLE_ENEMY or skill.target_type == Enums.TargetType.SINGLE_ALLY:
		action_chosen.emit(Enums.CombatAction.SKILL, skill, skill.target_type)
	else:
		# Self/AoE skills need confirmation
		var label: String = "Use %s?" % skill.display_name
		if skill.mp_cost > 0:
			label = "Use %s (%d MP)?" % [skill.display_name, skill.mp_cost]
		_show_confirm(label, Enums.CombatAction.SKILL, skill, skill.target_type)


# === Confirm/Cancel ===

func _show_confirm(text: String, action: int, skill: SkillData, target_type: int) -> void:
	_pending_action = action
	_pending_skill = skill
	_pending_target_type = target_type
	_confirm_label.text = text
	_main_buttons.visible = false
	_skill_list.visible = false
	_confirm_bar.visible = true


func _on_confirm() -> void:
	var action := _pending_action
	var skill := _pending_skill
	var target_type := _pending_target_type
	_clear_pending()
	_confirm_bar.visible = false
	action_chosen.emit(action, skill, target_type)


func _on_cancel() -> void:
	_clear_pending()
	_confirm_bar.visible = false
	_main_buttons.visible = true
	_skill_list.visible = false


func _clear_pending() -> void:
	_pending_action = -1
	_pending_skill = null
	_pending_target_type = -1


# === Skill List ===

func _build_skill_list() -> void:
	# Clear old skill buttons (keep BackButton)
	for btn in _skill_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_skill_buttons.clear()

	if not _current_entity:
		return

	var skills: Array = _current_entity.get_available_skills()
	for i in range(skills.size()):
		var skill: SkillData = skills[i]
		var btn: Button = Button.new()
		var can_use: bool = _current_entity.can_use_skill(skill)
		var mp_text: String = " (%d MP)" % skill.mp_cost if skill.mp_cost > 0 else ""
		btn.text = "%s%s" % [skill.display_name, mp_text]
		btn.disabled = not can_use
		btn.pressed.connect(_on_skill_selected.bind(skill))
		# Insert before the back button
		_skill_list.add_child(btn)
		_skill_list.move_child(btn, _skill_list.get_child_count() - 2)
		_skill_buttons.append(btn)
