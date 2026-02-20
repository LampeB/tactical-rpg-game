extends PanelContainer
## Action selection menu for player turns: Attack, Defend, Skills, Flee.
## Actions that don't require target selection show a Confirm/Cancel step.

signal action_chosen(action_type: int, skill: SkillData, target_type: int)

var _current_entity: CombatEntity
var _skill_buttons: Array = []
var _item_buttons: Array = []

# Pending action awaiting confirmation
var _pending_action: int = -1
var _pending_skill: SkillData = null
var _pending_item: ItemData = null
var _pending_target_type: int = -1

@onready var _main_buttons: HBoxContainer = $VBox/MainButtons
@onready var _attack_btn: Button = $VBox/MainButtons/AttackButton
@onready var _defend_btn: Button = $VBox/MainButtons/DefendButton
@onready var _skills_btn: Button = $VBox/MainButtons/SkillsButton
@onready var _items_btn: Button = $VBox/MainButtons/ItemsButton
@onready var _flee_btn: Button = $VBox/MainButtons/FleeButton
@onready var _skill_list: VBoxContainer = $VBox/SkillList
@onready var _skill_back_btn: Button = $VBox/SkillList/BackButton
@onready var _item_list: VBoxContainer = $VBox/ItemList
@onready var _item_back_btn: Button = $VBox/ItemList/BackButton
@onready var _confirm_bar: VBoxContainer = $VBox/ConfirmBar
@onready var _confirm_label: Label = $VBox/ConfirmBar/ConfirmLabel
@onready var _confirm_btn: Button = $VBox/ConfirmBar/ConfirmButtons/ConfirmButton
@onready var _cancel_btn: Button = $VBox/ConfirmBar/ConfirmButtons/CancelButton


func _ready() -> void:
	_attack_btn.pressed.connect(_on_attack)
	_defend_btn.pressed.connect(_on_defend)
	_skills_btn.pressed.connect(_on_skills_open)
	_items_btn.pressed.connect(_on_items_open)
	_flee_btn.pressed.connect(_on_flee)
	_skill_back_btn.pressed.connect(_on_skills_close)
	_item_back_btn.pressed.connect(_on_items_close)
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	_skill_list.visible = false
	_item_list.visible = false
	_confirm_bar.visible = false


func show_for_entity(entity: CombatEntity, can_flee: bool = true) -> void:
	_current_entity = entity
	_main_buttons.visible = true
	_skill_list.visible = false
	_item_list.visible = false
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

	# Check if entity has any usable combat items
	var has_combat_items: bool = false
	if entity.grid_inventory:
		var placed_items: Array = entity.grid_inventory.get_all_placed_items()
		for i in range(placed_items.size()):
			var placed: GridInventory.PlacedItem = placed_items[i]
			var item: ItemData = placed.item_data
			if item.item_type == Enums.ItemType.CONSUMABLE and item.use_skill:
				if item.use_skill.usage == Enums.SkillUsage.COMBAT or item.use_skill.usage == Enums.SkillUsage.BOTH:
					has_combat_items = true
					break
	_items_btn.disabled = not has_combat_items

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


func _on_items_open() -> void:
	_main_buttons.visible = false
	_item_list.visible = true
	_build_item_list()


func _on_items_close() -> void:
	_main_buttons.visible = true
	_item_list.visible = false


func _on_skill_selected(skill: SkillData) -> void:
	# All skills go directly to target selection - hover shows affected targets
	action_chosen.emit(Enums.CombatAction.SKILL, skill, skill.target_type)


func _on_item_selected(item: ItemData, placed: GridInventory.PlacedItem) -> void:
	var skill: SkillData = item.use_skill
	if not skill:
		return

	# Store the item for later removal after successful use
	_pending_item = item

	# All items go directly to target selection - hover shows affected targets
	action_chosen.emit(Enums.CombatAction.ITEM, skill, skill.target_type)


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


# === Item List ===

func _build_item_list() -> void:
	# Clear old item buttons (keep BackButton)
	for btn in _item_buttons:
		if is_instance_valid(btn):
			btn.queue_free()
	_item_buttons.clear()

	if not _current_entity:
		return

	# Get grid inventory for this character
	var inv: GridInventory = _current_entity.grid_inventory
	if not inv:
		return

	# Get all placed consumables that can be used in combat
	var placed_items: Array = inv.get_all_placed_items()
	for i in range(placed_items.size()):
		var placed: GridInventory.PlacedItem = placed_items[i]
		var item: ItemData = placed.item_data

		# Filter: must be consumable with use_skill that's usable in combat
		if item.item_type != Enums.ItemType.CONSUMABLE:
			continue
		if not item.use_skill:
			continue
		if item.use_skill.usage != Enums.SkillUsage.COMBAT and item.use_skill.usage != Enums.SkillUsage.BOTH:
			continue

		var btn: Button = Button.new()
		btn.text = item.display_name
		btn.pressed.connect(_on_item_selected.bind(item, placed))
		# Insert before the back button
		_item_list.add_child(btn)
		_item_list.move_child(btn, _item_list.get_child_count() - 2)
		_item_buttons.append(btn)
