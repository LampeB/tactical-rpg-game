extends PanelContainer
## Action selection menu for player turns: Attack, Defend, Skills, Flee.
## Defend/Flee show a Confirm/Cancel step; Attack/Skills/Items go directly to targeting.

signal action_chosen(action_type: int, skill: SkillData, target_type: int, item: ItemData)

var _current_entity: CombatEntity
var _skill_buttons: Array = []
var _item_buttons: Array = []

# Confirm flow state (only used by Defend action)
var _confirm_action: int = -1
var _confirm_skill: SkillData = null
var _confirm_target_type: int = -1

# Flee dialog
var _flee_dialog: ConfirmationDialog = null

@onready var _main_buttons: VBoxContainer = $HBox/MainButtons
@onready var _attack_btn: Button = $HBox/MainButtons/AttackButton
@onready var _defend_btn: Button = $HBox/MainButtons/DefendButton
@onready var _skills_btn: Button = $HBox/MainButtons/SkillsButton
@onready var _items_btn: Button = $HBox/MainButtons/ItemsButton
@onready var _flee_btn: Button = $HBox/MainButtons/FleeButton
@onready var _skill_list_scroll: ScrollContainer = $HBox/SkillList
@onready var _skill_list: VBoxContainer = $HBox/SkillList/VBox
@onready var _item_list_scroll: ScrollContainer = $HBox/ItemList
@onready var _item_list: VBoxContainer = $HBox/ItemList/VBox
@onready var _skill_details: PanelContainer = $HBox/SkillDetails
@onready var _skill_details_name: Label = $HBox/SkillDetails/Margin/VBox/NameLabel
@onready var _skill_details_desc: Label = $HBox/SkillDetails/Margin/VBox/DescLabel
@onready var _item_details: PanelContainer = $HBox/ItemDetails
@onready var _item_details_name: Label = $HBox/ItemDetails/Margin/VBox/NameLabel
@onready var _item_details_desc: Label = $HBox/ItemDetails/Margin/VBox/DescLabel
@onready var _target_prompt: Label = $HBox/TargetPrompt
@onready var _confirm_bar: VBoxContainer = $HBox/ConfirmBar
@onready var _confirm_label: Label = $HBox/ConfirmBar/ConfirmLabel
@onready var _confirm_btn: Button = $HBox/ConfirmBar/ConfirmButtons/ConfirmButton
@onready var _cancel_btn: Button = $HBox/ConfirmBar/ConfirmButtons/CancelButton


func _ready() -> void:
	_attack_btn.pressed.connect(_on_attack)
	_defend_btn.pressed.connect(_on_defend)
	_skills_btn.pressed.connect(_on_skills_open)
	_items_btn.pressed.connect(_on_items_open)
	_flee_btn.pressed.connect(_on_flee)
	_confirm_btn.pressed.connect(_on_confirm)
	_cancel_btn.pressed.connect(_on_cancel)
	_skill_list_scroll.visible = false
	_item_list_scroll.visible = false
	_skill_details.visible = false
	_item_details.visible = false
	_target_prompt.visible = false
	_confirm_bar.visible = false

	# Create flee dialog
	_flee_dialog = ConfirmationDialog.new()
	_flee_dialog.title = "Flee Battle"
	_flee_dialog.dialog_text = "Attempt to flee from this battle?"
	_flee_dialog.confirmed.connect(_on_flee_confirmed)
	add_child(_flee_dialog)


func show_for_entity(entity: CombatEntity, can_flee: bool = true) -> void:
	_current_entity = entity
	_main_buttons.visible = true
	_skill_list_scroll.visible = false
	_item_list_scroll.visible = false
	_skill_details.visible = false
	_item_details.visible = false
	_target_prompt.visible = false
	_confirm_bar.visible = false
	_flee_btn.disabled = not can_flee

	# Disable skills button if no skills available
	var skills: Array = entity.get_available_skills()
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
	_skill_list_scroll.visible = false
	_item_list_scroll.visible = false
	_skill_details.visible = false
	_item_details.visible = false
	_target_prompt.visible = false
	_confirm_bar.visible = false


# === Main Actions ===

func _on_attack() -> void:
	# Show target prompt in second column, keep main buttons visible
	_skill_list_scroll.visible = false
	_skill_details.visible = false
	_item_list_scroll.visible = false
	_item_details.visible = false
	_confirm_bar.visible = false
	_target_prompt.visible = true
	# Still emit the action to trigger target selection in battle.gd
	action_chosen.emit(Enums.CombatAction.ATTACK, null, Enums.TargetType.SINGLE_ENEMY, null)


func _on_defend() -> void:
	_show_confirm("Defend this turn?", Enums.CombatAction.DEFEND, null, Enums.TargetType.SELF)


func _on_flee() -> void:
	_flee_dialog.popup_centered()


func _on_flee_confirmed() -> void:
	action_chosen.emit(Enums.CombatAction.FLEE, null, Enums.TargetType.SELF, null)


func _on_skills_open() -> void:
	# Toggle skills list (close if already open, open if closed)
	if _skill_list_scroll.visible:
		_skill_list_scroll.visible = false
		_skill_details.visible = false
	else:
		_item_list_scroll.visible = false
		_item_details.visible = false
		_target_prompt.visible = false
		_confirm_bar.visible = false
		_skill_list_scroll.visible = true
		_build_skill_list()


func _on_items_open() -> void:
	# Toggle items list (close if already open, open if closed)
	if _item_list_scroll.visible:
		_item_list_scroll.visible = false
		_item_details.visible = false
	else:
		_skill_list_scroll.visible = false
		_skill_details.visible = false
		_target_prompt.visible = false
		_confirm_bar.visible = false
		_item_list_scroll.visible = true
		_build_item_list()


func _on_skill_selected(skill: SkillData) -> void:
	# All skills go directly to target selection - hover shows affected targets
	action_chosen.emit(Enums.CombatAction.SKILL, skill, skill.target_type, null)


func _on_item_selected(item: ItemData, placed: GridInventory.PlacedItem) -> void:
	var skill: SkillData = item.use_skill
	if not skill:
		return

	# Pass item to battle.gd for removal after successful use
	action_chosen.emit(Enums.CombatAction.ITEM, skill, skill.target_type, item)


# === Confirm/Cancel ===

func _show_confirm(text: String, action: int, skill: SkillData, target_type: int) -> void:
	_confirm_action = action
	_confirm_skill = skill
	_confirm_target_type = target_type
	_confirm_label.text = text
	_skill_list_scroll.visible = false
	_skill_details.visible = false
	_item_list_scroll.visible = false
	_item_details.visible = false
	_target_prompt.visible = false
	_confirm_bar.visible = true


func _on_confirm() -> void:
	var action := _confirm_action
	var skill := _confirm_skill
	var target_type := _confirm_target_type
	_clear_confirm()
	_confirm_bar.visible = false
	action_chosen.emit(action, skill, target_type, null)


func _on_cancel() -> void:
	_clear_confirm()
	_confirm_bar.visible = false
	_skill_list_scroll.visible = false
	_skill_details.visible = false
	_item_list_scroll.visible = false
	_item_details.visible = false
	_target_prompt.visible = false


func _clear_confirm() -> void:
	_confirm_action = -1
	_confirm_skill = null
	_confirm_target_type = -1


# === Skill List ===

func _build_skill_list() -> void:
	# Clear old skill buttons
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
		btn.mouse_entered.connect(_on_skill_hovered.bind(skill))
		btn.mouse_exited.connect(_on_skill_unhovered)
		_skill_list.add_child(btn)
		_skill_buttons.append(btn)


func _on_skill_hovered(skill: SkillData) -> void:
	_skill_details_name.text = skill.display_name
	var desc_parts: Array = []
	if skill.power > 0:
		desc_parts.append("Power: %d" % skill.power)
	if skill.mp_cost > 0:
		desc_parts.append("MP: %d" % skill.mp_cost)
	if skill.cooldown_turns > 0:
		desc_parts.append("Cooldown: %d turns" % skill.cooldown_turns)
	desc_parts.append(skill.description)
	_skill_details_desc.text = "\n".join(desc_parts)
	_skill_details.visible = true


func _on_skill_unhovered() -> void:
	_skill_details.visible = false


# === Item List ===

func _build_item_list() -> void:
	# Clear old item buttons
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
		btn.mouse_entered.connect(_on_item_hovered.bind(item))
		btn.mouse_exited.connect(_on_item_unhovered)
		_item_list.add_child(btn)
		_item_buttons.append(btn)


func _on_item_hovered(item: ItemData) -> void:
	_item_details_name.text = item.display_name
	var desc_parts: Array = []
	if item.use_skill:
		if item.use_skill.heal_amount > 0:
			desc_parts.append("Heals: %d HP" % item.use_skill.heal_amount)
		if item.use_skill.power > 0:
			desc_parts.append("Power: %d" % item.use_skill.power)
	desc_parts.append(item.description)
	_item_details_desc.text = "\n".join(desc_parts)
	_item_details.visible = true


func _on_item_unhovered() -> void:
	_item_details.visible = false
