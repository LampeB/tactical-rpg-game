extends Control
## Quest log screen. Shows active, completed, and available quests.
## Left panel: quest list. Right panel: quest detail with objectives, rewards, actions.

enum QuestTab { ACTIVE, COMPLETED, AVAILABLE }

@onready var _bg: ColorRect = $BG
@onready var _title_label: Label = $VBox/TopBar/TitleLabel
@onready var _close_btn: Button = $VBox/TopBar/CloseButton
@onready var _tab_active: Button = $VBox/TopBar/TabActive
@onready var _tab_completed: Button = $VBox/TopBar/TabCompleted
@onready var _tab_available: Button = $VBox/TopBar/TabAvailable
@onready var _quest_list: VBoxContainer = $VBox/Content/LeftPanel/QuestScroll/QuestList
@onready var _detail_panel: VBoxContainer = $VBox/Content/RightPanel/DetailScroll/DetailContent

var _current_tab: QuestTab = QuestTab.ACTIVE
var _selected_quest: QuestData = null


func _ready() -> void:
	_bg.color = Color(0.08, 0.10, 0.16, 1.0)
	_close_btn.pressed.connect(_on_close)
	_tab_active.pressed.connect(func() -> void: _switch_tab(QuestTab.ACTIVE))
	_tab_completed.pressed.connect(func() -> void: _switch_tab(QuestTab.COMPLETED))
	_tab_available.pressed.connect(func() -> void: _switch_tab(QuestTab.AVAILABLE))

	EventBus.quest_progressed.connect(_on_quest_progressed)
	EventBus.quest_completed.connect(_on_quest_completed)
	EventBus.quest_accepted.connect(_on_quest_accepted)

	# Initialize list (receive_data only called when data is non-empty)
	_refresh_quest_list()
	_update_tab_styles()


func receive_data(data: Dictionary) -> void:
	var highlight_id: String = data.get("highlight_quest_id", "")
	_refresh_quest_list()
	_update_tab_styles()
	if not highlight_id.is_empty():
		var quest: QuestData = QuestManager.get_quest(highlight_id)
		if quest:
			_select_quest(quest)


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_close()
		get_viewport().set_input_as_handled()


# === Tabs ===

func _switch_tab(tab: QuestTab) -> void:
	_current_tab = tab
	_selected_quest = null
	_refresh_quest_list()
	_clear_detail()
	_update_tab_styles()


func _update_tab_styles() -> void:
	_tab_active.flat = _current_tab != QuestTab.ACTIVE
	_tab_completed.flat = _current_tab != QuestTab.COMPLETED
	_tab_available.flat = _current_tab != QuestTab.AVAILABLE


# === Quest List ===

func _refresh_quest_list() -> void:
	for child in _quest_list.get_children():
		child.queue_free()

	var quests: Array = []
	match _current_tab:
		QuestTab.ACTIVE:
			quests = QuestManager.get_active_quests()
		QuestTab.COMPLETED:
			quests = QuestManager.get_completed_quests()
		QuestTab.AVAILABLE:
			quests = QuestManager.get_available_quests()

	if quests.is_empty():
		var empty_label := Label.new()
		match _current_tab:
			QuestTab.ACTIVE:
				empty_label.text = "No active quests."
			QuestTab.COMPLETED:
				empty_label.text = "No completed quests."
			QuestTab.AVAILABLE:
				empty_label.text = "No available quests."
		UIThemes.style_label(empty_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
		_quest_list.add_child(empty_label)
		return

	for i in range(quests.size()):
		var quest: QuestData = quests[i]
		var row := _build_quest_row(quest)
		_quest_list.add_child(row)

	# Auto-select first quest if nothing selected
	if _selected_quest == null and not quests.is_empty():
		_select_quest(quests[0])


func _build_quest_row(quest: QuestData) -> PanelContainer:
	var is_selected := _selected_quest != null and _selected_quest.id == quest.id
	var is_completable := _current_tab == QuestTab.ACTIVE and QuestManager.is_quest_ready_to_complete(quest.id)

	var card := PanelContainer.new()
	card.set_meta("quest_id", quest.id)
	card.custom_minimum_size = Vector2(0, 48)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	if is_selected:
		style.bg_color = Color(0.2, 0.25, 0.35)
		style.border_color = Color(0.5, 0.7, 1.0)
		style.border_width_left = 2
		style.border_width_right = 2
		style.border_width_top = 2
		style.border_width_bottom = 2
	else:
		style.bg_color = Color(0.13, 0.16, 0.22)
		style.border_color = Color(0.25, 0.28, 0.35)
		style.border_width_left = 1
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	card.add_theme_stylebox_override("panel", style)

	var margin := MarginContainer.new()
	UIThemes.set_margins(margin, 10, 10, 6, 6)
	card.add_child(margin)

	var hbox := HBoxContainer.new()
	UIThemes.set_separation(hbox, 8)
	margin.add_child(hbox)

	# Quest type indicator
	var type_label := Label.new()
	if quest.is_main_quest:
		type_label.text = "[M]"
		UIThemes.style_label(type_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_IMPORTANT)
	else:
		type_label.text = "   "
	hbox.add_child(type_label)

	# Quest name
	var name_label := Label.new()
	name_label.text = quest.display_name
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var name_color := Color.WHITE
	if is_completable:
		name_color = Constants.COLOR_TEXT_SUCCESS
	elif _current_tab == QuestTab.AVAILABLE:
		name_color = Constants.COLOR_TEXT_IMPORTANT
	UIThemes.style_label(name_label, Constants.FONT_SIZE_SMALL, name_color)
	hbox.add_child(name_label)

	# Progress summary for active quests
	if _current_tab == QuestTab.ACTIVE:
		var progress_label := Label.new()
		var done_count: int = 0
		for oi in range(quest.objectives.size()):
			var flag := "quest_%s_obj_%d" % [quest.id, oi]
			var progress: int = GameManager.get_flag(flag, 0)
			if progress >= quest.objectives[oi].target_count:
				done_count += 1
		progress_label.text = "%d/%d" % [done_count, quest.objectives.size()]
		var prog_color := Constants.COLOR_TEXT_SUCCESS if done_count >= quest.objectives.size() else Constants.COLOR_TEXT_SECONDARY
		UIThemes.style_label(progress_label, Constants.FONT_SIZE_SMALL, prog_color)
		hbox.add_child(progress_label)

	card.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_select_quest(quest)
	)
	return card


# === Quest Detail ===

func _select_quest(quest: QuestData) -> void:
	_selected_quest = quest
	_refresh_detail()
	_refresh_list_styles()


func _refresh_list_styles() -> void:
	for child in _quest_list.get_children():
		if not child is PanelContainer:
			continue
		var quest_id: String = child.get_meta("quest_id", "")
		var is_selected := _selected_quest != null and _selected_quest.id == quest_id
		var style := child.get_theme_stylebox("panel") as StyleBoxFlat
		if not style:
			continue
		if is_selected:
			style.bg_color = Color(0.2, 0.25, 0.35)
			style.border_color = Color(0.5, 0.7, 1.0)
			style.border_width_left = 2
			style.border_width_right = 2
			style.border_width_top = 2
			style.border_width_bottom = 2
		else:
			style.bg_color = Color(0.13, 0.16, 0.22)
			style.border_color = Color(0.25, 0.28, 0.35)
			style.border_width_left = 1
			style.border_width_right = 1
			style.border_width_top = 1
			style.border_width_bottom = 1


func _refresh_detail() -> void:
	_clear_detail()
	if not _selected_quest:
		return

	var quest := _selected_quest

	# Title
	var title := Label.new()
	title.text = quest.display_name
	UIThemes.style_label(title, Constants.FONT_SIZE_HEADER, Constants.COLOR_TEXT_HEADER)
	_detail_panel.add_child(title)

	# Main quest badge
	if quest.is_main_quest:
		var badge := Label.new()
		badge.text = "Main Quest"
		UIThemes.style_label(badge, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_IMPORTANT)
		_detail_panel.add_child(badge)

	# Description
	if not quest.description.is_empty():
		var desc := Label.new()
		desc.text = quest.description
		UIThemes.style_label(desc, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_detail_panel.add_child(desc)

	_detail_panel.add_child(HSeparator.new())

	# Objectives
	var obj_header := Label.new()
	obj_header.text = "Objectives"
	UIThemes.style_label(obj_header, Constants.FONT_SIZE_NORMAL, Constants.COLOR_TEXT_HEADER)
	_detail_panel.add_child(obj_header)

	for oi in range(quest.objectives.size()):
		var obj: QuestObjective = quest.objectives[oi]
		var flag := "quest_%s_obj_%d" % [quest.id, oi]
		var progress: int = GameManager.get_flag(flag, 0)
		var is_done := progress >= obj.target_count

		var obj_row := HBoxContainer.new()
		UIThemes.set_separation(obj_row, 6)
		_detail_panel.add_child(obj_row)

		# Checkbox
		var check := Label.new()
		check.text = "[x]" if is_done else "[ ]"
		var check_color := Constants.COLOR_TEXT_SUCCESS if is_done else Constants.COLOR_TEXT_FADED
		UIThemes.style_label(check, Constants.FONT_SIZE_SMALL, check_color)
		obj_row.add_child(check)

		# Description
		var obj_desc := Label.new()
		var desc_text := obj.description if not obj.description.is_empty() else _default_objective_text(obj)
		if obj.target_count > 1:
			desc_text += " (%d/%d)" % [mini(progress, obj.target_count), obj.target_count]
		obj_desc.text = desc_text
		obj_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var obj_color := Constants.COLOR_TEXT_SUCCESS if is_done else Constants.COLOR_TEXT_PRIMARY
		UIThemes.style_label(obj_desc, Constants.FONT_SIZE_SMALL, obj_color)
		obj_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		obj_row.add_child(obj_desc)

	_detail_panel.add_child(HSeparator.new())

	# Rewards
	if quest.reward_gold > 0 or not quest.reward_items.is_empty() or quest.reward_xp > 0:
		var rew_header := Label.new()
		rew_header.text = "Rewards"
		UIThemes.style_label(rew_header, Constants.FONT_SIZE_NORMAL, Constants.COLOR_TEXT_HEADER)
		_detail_panel.add_child(rew_header)

		if quest.reward_gold > 0:
			var gold_label := Label.new()
			gold_label.text = "%d Gold" % quest.reward_gold
			UIThemes.style_label(gold_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_IMPORTANT)
			_detail_panel.add_child(gold_label)

		if quest.reward_xp > 0:
			var xp_label := Label.new()
			xp_label.text = "%d XP" % quest.reward_xp
			UIThemes.style_label(xp_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_EMPHASIS)
			_detail_panel.add_child(xp_label)

		for ri in range(quest.reward_items.size()):
			var item: ItemData = quest.reward_items[ri]
			var item_row := HBoxContainer.new()
			UIThemes.set_separation(item_row, 6)
			_detail_panel.add_child(item_row)

			if item.icon:
				var icon := TextureRect.new()
				icon.texture = item.icon
				icon.custom_minimum_size = Vector2(24, 24)
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				item_row.add_child(icon)

			var item_name := Label.new()
			item_name.text = item.display_name
			var item_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
			UIThemes.style_label(item_name, Constants.FONT_SIZE_SMALL, item_color)
			item_row.add_child(item_name)

		_detail_panel.add_child(HSeparator.new())

	# Action buttons
	var btn_row := HBoxContainer.new()
	UIThemes.set_separation(btn_row, 10)
	_detail_panel.add_child(btn_row)

	if _current_tab == QuestTab.ACTIVE and QuestManager.is_quest_ready_to_complete(quest.id):
		if quest.turn_in_npc_id.is_empty():
			# Auto-completable (no NPC required)
			var complete_btn := Button.new()
			complete_btn.text = "Complete"
			complete_btn.pressed.connect(func() -> void:
				QuestManager.complete_quest(quest.id)
			)
			btn_row.add_child(complete_btn)
		else:
			var turn_in_label := Label.new()
			var npc: NpcData = NpcDatabase.get_npc(quest.turn_in_npc_id)
			var npc_name := npc.display_name if npc else quest.turn_in_npc_id
			turn_in_label.text = "Turn in at: %s" % npc_name
			UIThemes.style_label(turn_in_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_EMPHASIS)
			btn_row.add_child(turn_in_label)

	if _current_tab == QuestTab.AVAILABLE:
		var accept_btn := Button.new()
		accept_btn.text = "Accept"
		accept_btn.pressed.connect(func() -> void:
			QuestManager.accept_quest(quest.id)
		)
		btn_row.add_child(accept_btn)


func _clear_detail() -> void:
	for child in _detail_panel.get_children():
		child.queue_free()


func _default_objective_text(obj: QuestObjective) -> String:
	match obj.objective_type:
		QuestObjective.ObjectiveType.KILL:
			return "Defeat %s" % obj.target_id
		QuestObjective.ObjectiveType.COLLECT:
			return "Collect %s" % obj.target_id
		QuestObjective.ObjectiveType.TALK_TO:
			return "Talk to %s" % obj.target_id
		QuestObjective.ObjectiveType.REACH_LOCATION:
			return "Reach %s" % obj.target_id
		QuestObjective.ObjectiveType.DEFEAT_BOSS:
			return "Defeat %s" % obj.target_id
		QuestObjective.ObjectiveType.SET_FLAG:
			return "Complete task"
	return obj.target_id


# === Signal Handlers ===

func _on_quest_progressed(_quest_id: String, _obj_index: int, _current: int, _target: int) -> void:
	if _current_tab == QuestTab.ACTIVE:
		_refresh_quest_list()
		if _selected_quest:
			_refresh_detail()


func _on_quest_completed(_quest_id: String) -> void:
	_refresh_quest_list()
	if _selected_quest and _selected_quest.id == _quest_id:
		_selected_quest = null
		_clear_detail()


func _on_quest_accepted(_quest_id: String) -> void:
	if _current_tab == QuestTab.AVAILABLE:
		_refresh_quest_list()
		_selected_quest = null
		_clear_detail()


func _on_close() -> void:
	SceneManager.pop_scene()
