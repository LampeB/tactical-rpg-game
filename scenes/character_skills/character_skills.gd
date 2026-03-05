extends Control
## Abilities screen showing all available and locked skills for a character.
## Displays element points from equipped gems and the skills they unlock.

@onready var _bg: ColorRect = $BG
@onready var _element_bar: HBoxContainer = $VBox/ElementBar
@onready var _skill_list: VBoxContainer = $VBox/Content/LeftPanel/ScrollContainer/SkillList
@onready var _detail_header: HBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader
@onready var _detail_icon: TextureRect = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader/DetailIcon
@onready var _detail_name: Label = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader/DetailName
@onready var _detail_stats: VBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailStats
@onready var _detail_desc: Label = $VBox/Content/RightPanel/Margin/DetailVBox/DetailDesc
@onready var _detail_requirements: VBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailRequirements
@onready var _left_panel: PanelContainer = $VBox/Content/LeftPanel
@onready var _right_panel: PanelContainer = $VBox/Content/RightPanel

var _selected_skill: SkillData = null
var _selected_entry: ElementSkillEntry = null
var _selected_unlocked: bool = false


func _ready() -> void:
	_style_panels()
	_show_empty_detail()


func setup_embedded(character_id: String) -> void:
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var element_points: Dictionary = inv.get_element_points() if inv else {}

	_update_element_bar(element_points)
	_update_skill_list(char_data, element_points)
	_selected_skill = null
	_selected_entry = null
	_show_empty_detail()


# === Element Points Bar ===

func _update_element_bar(element_points: Dictionary) -> void:
	for child in _element_bar.get_children():
		child.queue_free()

	for elem_idx in range(7):
		var elem: int = elem_idx
		var pts: int = element_points.get(elem, 0)
		var elem_name: String = Enums.get_element_name(elem as Enums.Element)
		var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)

		var container := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		style.border_color = elem_color.darkened(0.4)
		style.border_width_bottom = 2
		style.content_margin_left = 8
		style.content_margin_right = 8
		style.content_margin_top = 4
		style.content_margin_bottom = 4
		container.add_theme_stylebox_override("panel", style)
		container.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var label := Label.new()
		label.text = "%s: %d" % [elem_name, pts]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if pts > 0:
			UIThemes.style_label(label, Constants.FONT_SIZE_SMALL, elem_color)
		else:
			UIThemes.style_label(label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
		container.add_child(label)
		_element_bar.add_child(container)


# === Skill List ===

func _update_skill_list(char_data: CharacterData, element_points: Dictionary) -> void:
	for child in _skill_list.get_children():
		child.queue_free()

	var table: ElementSkillTable = ElementSkillSystem.get_table()

	# Collect innate skills
	var innate_skills: Array[SkillData] = []
	for skill in char_data.innate_skills:
		if skill is SkillData:
			innate_skills.append(skill)

	# Collect unlocked and locked element skills
	var unlocked_entries: Array[ElementSkillEntry] = []
	var locked_entries: Array[ElementSkillEntry] = []
	if table:
		for entry in table.entries:
			if entry.skill == null:
				continue
			if table._meets_requirements(element_points, entry.required_points):
				unlocked_entries.append(entry)
			else:
				locked_entries.append(entry)

	# Remove innate duplicates from unlocked (innate takes priority)
	var innate_ids: Array[String] = []
	for skill in innate_skills:
		innate_ids.append(skill.id)

	# --- Innate Section ---
	if not innate_skills.is_empty():
		_add_section_header("Innate Skills")
		for skill in innate_skills:
			var row: PanelContainer = _build_skill_row(skill, true, true, null)
			_skill_list.add_child(row)

	# --- Unlocked Section ---
	var filtered_unlocked: Array[ElementSkillEntry] = []
	for entry in unlocked_entries:
		if entry.skill.id not in innate_ids:
			filtered_unlocked.append(entry)

	if not filtered_unlocked.is_empty():
		_add_section_header("Unlocked Skills")
		for entry in filtered_unlocked:
			var row: PanelContainer = _build_skill_row(entry.skill, true, false, entry)
			_skill_list.add_child(row)

	# --- Locked Section ---
	if not locked_entries.is_empty():
		_add_section_header("Locked Skills")
		for entry in locked_entries:
			if entry.skill.id not in innate_ids:
				var row: PanelContainer = _build_skill_row(entry.skill, false, false, entry)
				_skill_list.add_child(row)


func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	UIThemes.style_label(label, Constants.FONT_SIZE_DETAIL, Constants.COLOR_TEXT_HEADER)
	_skill_list.add_child(label)


func _build_skill_row(skill: SkillData, is_unlocked: bool, is_innate: bool, entry: ElementSkillEntry) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 36)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18, 0.9) if is_unlocked else Color(0.08, 0.08, 0.12, 0.7)
	style.corner_radius_top_left = 3
	style.corner_radius_top_right = 3
	style.corner_radius_bottom_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 4
	style.content_margin_bottom = 4

	# Left border color: element color for element skills, blue for innate
	if is_innate:
		style.border_color = Constants.COLOR_TEXT_EMPHASIS
		style.border_width_left = 3
	elif is_unlocked and entry:
		# Use the primary element color
		var primary_elem: int = _get_primary_element(entry)
		var border_col: Color = Constants.ELEMENT_COLORS.get(primary_elem, Color.WHITE)
		style.border_color = border_col
		style.border_width_left = 3
	else:
		style.border_color = Color(0.3, 0.3, 0.35)
		style.border_width_left = 2

	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 8)

	# Skill icon (small)
	if skill.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = skill.icon
		icon_rect.custom_minimum_size = Vector2(24, 24)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not is_unlocked:
			icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.6)
		hbox.add_child(icon_rect)

	# Skill name
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_innate:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_EMPHASIS)
	elif is_unlocked:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_PRIMARY)
	else:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
	hbox.add_child(name_label)

	# MP cost or lock indicator
	var info_label := Label.new()
	if is_unlocked:
		info_label.text = "%d MP" % skill.mp_cost if skill.mp_cost > 0 else ""
		UIThemes.style_label(info_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
	else:
		info_label.text = "Locked"
		UIThemes.style_label(info_label, Constants.FONT_SIZE_TINY, Color(0.6, 0.3, 0.3))
	hbox.add_child(info_label)

	card.add_child(hbox)

	# Click handler
	card.gui_input.connect(_on_skill_row_input.bind(skill, entry, is_unlocked))

	return card


func _on_skill_row_input(event: InputEvent, skill: SkillData, entry: ElementSkillEntry, is_unlocked: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_skill = skill
		_selected_entry = entry
		_selected_unlocked = is_unlocked
		_update_detail_panel(skill, entry, is_unlocked)


# === Detail Panel ===

func _show_empty_detail() -> void:
	_detail_icon.texture = null
	_detail_icon.visible = false
	_detail_name.text = "Select a skill"
	UIThemes.style_label(_detail_name, Constants.FONT_SIZE_HEADER, Constants.COLOR_TEXT_FADED)
	_clear_container(_detail_stats)
	_detail_desc.text = "Click on a skill in the list to see its details."
	_detail_desc.add_theme_color_override("font_color", Constants.COLOR_TEXT_FADED)
	_clear_container(_detail_requirements)


func _update_detail_panel(skill: SkillData, entry: ElementSkillEntry, is_unlocked: bool) -> void:
	# Header
	if skill.icon:
		_detail_icon.texture = skill.icon
		_detail_icon.visible = true
		if not is_unlocked:
			_detail_icon.modulate = Color(0.5, 0.5, 0.5, 0.6)
		else:
			_detail_icon.modulate = Color.WHITE
	else:
		_detail_icon.visible = false

	_detail_name.text = skill.display_name
	var name_color: Color = Constants.COLOR_TEXT_PRIMARY if is_unlocked else Constants.COLOR_TEXT_FADED
	UIThemes.style_label(_detail_name, Constants.FONT_SIZE_HEADER, name_color)

	# Stats
	_clear_container(_detail_stats)

	# Usage
	var usage_label := Label.new()
	usage_label.text = "Usage: %s" % Enums.get_skill_usage_name(skill.usage)
	UIThemes.style_label(usage_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
	_detail_stats.add_child(usage_label)

	# MP cost
	if skill.mp_cost > 0:
		var mp_label := Label.new()
		mp_label.text = "MP Cost: %d" % skill.mp_cost
		UIThemes.style_label(mp_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_MP)
		_detail_stats.add_child(mp_label)
	elif skill.use_all_mp:
		var mp_label := Label.new()
		mp_label.text = "MP Cost: All remaining MP"
		UIThemes.style_label(mp_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_MP)
		_detail_stats.add_child(mp_label)

	# Cooldown
	if skill.cooldown_turns > 0:
		var cd_label := Label.new()
		cd_label.text = "Cooldown: %d turn(s)" % skill.cooldown_turns
		UIThemes.style_label(cd_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
		_detail_stats.add_child(cd_label)

	# Target
	var target_label := Label.new()
	target_label.text = "Target: %s" % Enums.get_target_type_name(skill.target_type)
	UIThemes.style_label(target_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_SECONDARY)
	_detail_stats.add_child(target_label)

	# Damage scaling
	if skill.has_damage():
		if skill.physical_scaling > 0.0:
			var phys_label := Label.new()
			phys_label.text = "Physical Scaling: %.1fx" % skill.physical_scaling
			UIThemes.style_label(phys_label, Constants.FONT_SIZE_SMALL, Color(1.0, 0.7, 0.4))
			_detail_stats.add_child(phys_label)
		if skill.magical_scaling > 0.0:
			var mag_label := Label.new()
			mag_label.text = "Magical Scaling: %.1fx" % skill.magical_scaling
			UIThemes.style_label(mag_label, Constants.FONT_SIZE_SMALL, Color(0.6, 0.7, 1.0))
			_detail_stats.add_child(mag_label)
		if skill.use_all_mp and skill.mp_damage_ratio > 0.0:
			var ratio_label := Label.new()
			ratio_label.text = "MP Damage Ratio: %.1fx per MP" % skill.mp_damage_ratio
			UIThemes.style_label(ratio_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_MP)
			_detail_stats.add_child(ratio_label)

	# Healing
	if skill.heal_amount > 0:
		var heal_label := Label.new()
		heal_label.text = "Heals: %d HP" % skill.heal_amount
		UIThemes.style_label(heal_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_HEAL)
		_detail_stats.add_child(heal_label)
	if skill.heal_percent > 0.0:
		var heal_pct_label := Label.new()
		heal_pct_label.text = "Heals: %d%% of max HP" % int(skill.heal_percent * 100)
		UIThemes.style_label(heal_pct_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_HEAL)
		_detail_stats.add_child(heal_pct_label)

	# Status effects
	if not skill.applied_statuses.is_empty():
		for status in skill.applied_statuses:
			if status:
				var status_label := Label.new()
				status_label.text = "Applies: %s" % status.display_name
				UIThemes.style_label(status_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_LOG_STATUS)
				_detail_stats.add_child(status_label)

	# Description
	_detail_desc.text = skill.description if not skill.description.is_empty() else "No description."
	var desc_color: Color = Constants.COLOR_TEXT_PRIMARY if is_unlocked else Constants.COLOR_TEXT_FADED
	_detail_desc.add_theme_color_override("font_color", desc_color)

	# Requirements
	_clear_container(_detail_requirements)
	if entry and not entry.required_points.is_empty():
		var req_header := Label.new()
		req_header.text = "Element Requirements:"
		UIThemes.style_label(req_header, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_HEADER)
		_detail_requirements.add_child(req_header)

		for elem_key in entry.required_points:
			var elem: int = elem_key
			var needed: int = entry.required_points[elem_key]
			var elem_name: String = Enums.get_element_name(elem as Enums.Element)
			var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)

			var req_label := Label.new()
			req_label.text = "  %s: %d" % [elem_name, needed]
			if is_unlocked:
				UIThemes.style_label(req_label, Constants.FONT_SIZE_SMALL, elem_color)
			else:
				UIThemes.style_label(req_label, Constants.FONT_SIZE_SMALL, elem_color.darkened(0.4))
			_detail_requirements.add_child(req_label)
	elif entry == null:
		# Innate skill — no element requirements
		var innate_label := Label.new()
		innate_label.text = "Innate skill — always available"
		UIThemes.style_label(innate_label, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_EMPHASIS)
		_detail_requirements.add_child(innate_label)


# === Helpers ===

func _get_primary_element(entry: ElementSkillEntry) -> int:
	var max_pts: int = 0
	var primary: int = 0
	for elem_key in entry.required_points:
		var pts: int = entry.required_points[elem_key]
		if pts > max_pts:
			max_pts = pts
			primary = elem_key
	return primary


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()


func _style_panels() -> void:
	# Left panel
	var left_style := StyleBoxFlat.new()
	left_style.bg_color = Color(0.1, 0.08, 0.16, 0.9)
	left_style.corner_radius_top_left = 4
	left_style.corner_radius_bottom_left = 4
	left_style.content_margin_left = 8
	left_style.content_margin_right = 8
	left_style.content_margin_top = 8
	left_style.content_margin_bottom = 8
	_left_panel.add_theme_stylebox_override("panel", left_style)

	# Right panel
	var right_style := StyleBoxFlat.new()
	right_style.bg_color = Color(0.08, 0.08, 0.14, 0.9)
	right_style.corner_radius_top_right = 4
	right_style.corner_radius_bottom_right = 4
	_right_panel.add_theme_stylebox_override("panel", right_style)
