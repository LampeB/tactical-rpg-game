extends Control
## Abilities screen showing all available and locked skills for a character.
## Displays element points from equipped gems and the skills they unlock.
## Includes filter bar, selection highlighting, and element requirement squares.

@warning_ignore("unused_private_class_variable")
@onready var _bg: ColorRect = $BG
@onready var _element_bar: HBoxContainer = $VBox/ElementBar
@onready var _filter_bar: HBoxContainer = $VBox/Content/LeftPanel/LeftVBox/FilterBar
@onready var _skill_list: VBoxContainer = $VBox/Content/LeftPanel/LeftVBox/ScrollContainer/SkillList
@warning_ignore("unused_private_class_variable")
@onready var _detail_header: HBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader
@onready var _detail_icon: TextureRect = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader/DetailIcon
@onready var _detail_name: Label = $VBox/Content/RightPanel/Margin/DetailVBox/DetailHeader/DetailName
@onready var _detail_stats: VBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailStats
@onready var _detail_desc: Label = $VBox/Content/RightPanel/Margin/DetailVBox/DetailDesc
@onready var _detail_requirements: VBoxContainer = $VBox/Content/RightPanel/Margin/DetailVBox/DetailRequirements
@onready var _left_panel: PanelContainer = $VBox/Content/LeftPanel
@onready var _right_panel: PanelContainer = $VBox/Content/RightPanel

# Filter state
enum FilterState { NEUTRAL, INCLUDE, EXCLUDE }
var _element_filters: Array = []
var _filter_squares: Array = []

# Selection state
var _selected_skill: SkillData = null
var _selected_entry: ElementSkillEntry = null
var _selected_unlocked: bool = false

# Cached data for rebuilding
var _cached_char_data: CharacterData = null
var _cached_element_points: Dictionary = {}


func _ready() -> void:
	_style_panels()
	_show_empty_detail()

	# Initialize filters
	_element_filters.resize(7)
	for fi in range(7):
		_element_filters[fi] = FilterState.NEUTRAL
	_build_filter_bar()


func setup_embedded(character_id: String) -> void:
	var char_data: CharacterData = GameManager.party.roster.get(character_id)
	if not char_data:
		return
	var inv: GridInventory = GameManager.party.grid_inventories.get(character_id)
	var element_points: Dictionary = inv.get_element_points() if inv else {}

	_cached_char_data = char_data
	_cached_element_points = element_points

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


# === Filter Bar ===

func _build_filter_bar() -> void:
	_filter_squares.clear()
	for fi in range(7):
		var elem: int = fi
		var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)
		var elem_name: String = Enums.get_element_name(elem as Enums.Element)

		var square := PanelContainer.new()
		square.custom_minimum_size = Vector2(24, 24)
		square.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		square.tooltip_text = elem_name
		_update_filter_square_style(square, elem_color, FilterState.NEUTRAL)

		var lbl := Label.new()
		lbl.text = elem_name.left(2)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		UIThemes.style_label(lbl, 10, elem_color)
		square.add_child(lbl)

		square.gui_input.connect(_on_filter_square_input.bind(fi))
		_filter_bar.add_child(square)
		_filter_squares.append(square)


func _on_filter_square_input(event: InputEvent, elem_idx: int) -> void:
	if not (event is InputEventMouseButton and event.pressed):
		return

	var current: int = _element_filters[elem_idx]

	if event.button_index == MOUSE_BUTTON_LEFT:
		if current == FilterState.INCLUDE:
			_element_filters[elem_idx] = FilterState.NEUTRAL
		else:
			_element_filters[elem_idx] = FilterState.INCLUDE
	elif event.button_index == MOUSE_BUTTON_RIGHT:
		if current == FilterState.EXCLUDE:
			_element_filters[elem_idx] = FilterState.NEUTRAL
		else:
			_element_filters[elem_idx] = FilterState.EXCLUDE

	# Update visual state of all filter squares
	for fi in range(7):
		var elem_color: Color = Constants.ELEMENT_COLORS.get(fi, Color.WHITE)
		_update_filter_square_style(_filter_squares[fi], elem_color, _element_filters[fi] as FilterState)

	# Rebuild skill list with new filters
	if _cached_char_data:
		_update_skill_list(_cached_char_data, _cached_element_points)


func _update_filter_square_style(square: PanelContainer, color: Color, state: FilterState) -> void:
	var sq_style := StyleBoxFlat.new()
	sq_style.corner_radius_top_left = 3
	sq_style.corner_radius_top_right = 3
	sq_style.corner_radius_bottom_left = 3
	sq_style.corner_radius_bottom_right = 3

	match state:
		FilterState.NEUTRAL:
			sq_style.bg_color = color.darkened(0.7)
			sq_style.border_color = color.darkened(0.3)
			sq_style.border_width_left = 1
			sq_style.border_width_right = 1
			sq_style.border_width_top = 1
			sq_style.border_width_bottom = 1
		FilterState.INCLUDE:
			sq_style.bg_color = color.darkened(0.3)
			sq_style.border_color = color
			sq_style.border_width_left = 2
			sq_style.border_width_right = 2
			sq_style.border_width_top = 2
			sq_style.border_width_bottom = 2
		FilterState.EXCLUDE:
			sq_style.bg_color = Color(0.1, 0.1, 0.1, 0.8)
			sq_style.border_color = Color(0.4, 0.2, 0.2)
			sq_style.border_width_left = 1
			sq_style.border_width_right = 1
			sq_style.border_width_top = 1
			sq_style.border_width_bottom = 1

	square.add_theme_stylebox_override("panel", sq_style)


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
		var innate_ids: Array[String] = []
		for skill in innate_skills:
			innate_ids.append(skill.id)
		for entry in table.entries:
			if entry.skill == null:
				continue
			if entry.skill.id in innate_ids:
				continue
			if table._meets_requirements(element_points, entry.required_points):
				unlocked_entries.append(entry)
			else:
				locked_entries.append(entry)

	# Apply element filters to element skills
	var filtered_unlocked: Array[ElementSkillEntry] = _apply_filter(unlocked_entries)
	var filtered_locked: Array[ElementSkillEntry] = _apply_filter(locked_entries)

	# --- Innate Section ---
	if not innate_skills.is_empty():
		_add_section_header("Innate Skills")
		for skill in innate_skills:
			var row: PanelContainer = _build_skill_row(skill, true, true, null)
			_skill_list.add_child(row)

	# --- Unlocked Section ---
	if not filtered_unlocked.is_empty():
		_add_section_header("Unlocked Skills")
		for entry in filtered_unlocked:
			var row: PanelContainer = _build_skill_row(entry.skill, true, false, entry)
			_skill_list.add_child(row)

	# --- Locked Section ---
	if not filtered_locked.is_empty():
		_add_section_header("Locked Skills")
		for entry in filtered_locked:
			var row: PanelContainer = _build_skill_row(entry.skill, false, false, entry)
			_skill_list.add_child(row)


func _apply_filter(entries: Array[ElementSkillEntry]) -> Array[ElementSkillEntry]:
	var has_include: bool = false
	for fi in range(7):
		if _element_filters[fi] == FilterState.INCLUDE:
			has_include = true
			break

	var result: Array[ElementSkillEntry] = []
	for entry in entries:
		var dominated_by_exclude: bool = false
		var matches_include: bool = false

		for elem_key in entry.required_points:
			var elem: int = elem_key
			if elem >= 0 and elem < 7:
				if _element_filters[elem] == FilterState.EXCLUDE:
					dominated_by_exclude = true
					break
				if _element_filters[elem] == FilterState.INCLUDE:
					matches_include = true

		if dominated_by_exclude:
			continue
		if has_include and not matches_include:
			continue
		result.append(entry)
	return result


func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	UIThemes.style_label(label, Constants.FONT_SIZE_DETAIL, Constants.COLOR_TEXT_HEADER)
	_skill_list.add_child(label)


func _build_skill_row(skill: SkillData, is_unlocked: bool, is_innate: bool, entry: ElementSkillEntry) -> PanelContainer:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 28)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var is_selected: bool = (_selected_skill != null and skill.id == _selected_skill.id)

	var style := StyleBoxFlat.new()
	if is_selected:
		style.bg_color = Color(0.2, 0.25, 0.4, 0.95)
		style.border_color = Color(0.5, 0.7, 1.0)
		style.border_width_left = 3
		style.border_width_right = 1
		style.border_width_top = 1
		style.border_width_bottom = 1
	elif is_innate:
		style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		style.border_color = Constants.COLOR_TEXT_EMPHASIS
		style.border_width_left = 3
	elif is_unlocked:
		var primary_elem: int = _get_primary_element(entry) if entry else 0
		var border_col: Color = Constants.ELEMENT_COLORS.get(primary_elem, Color.WHITE)
		style.bg_color = Color(0.12, 0.12, 0.18, 0.9)
		style.border_color = border_col
		style.border_width_left = 3
	else:
		style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
		style.border_color = Color(0.3, 0.3, 0.35)
		style.border_width_left = 2

	style.corner_radius_top_left = 2
	style.corner_radius_top_right = 2
	style.corner_radius_bottom_left = 2
	style.corner_radius_bottom_right = 2
	style.content_margin_left = 6
	style.content_margin_right = 6
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	card.add_theme_stylebox_override("panel", style)

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 4)

	# Skill icon (small)
	if skill.icon:
		var icon_rect := TextureRect.new()
		icon_rect.texture = skill.icon
		icon_rect.custom_minimum_size = Vector2(20, 20)
		icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		if not is_unlocked:
			icon_rect.modulate = Color(0.5, 0.5, 0.5, 0.6)
		hbox.add_child(icon_rect)

	# Skill name
	var name_label := Label.new()
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if is_innate:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_EMPHASIS)
	elif is_unlocked:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_PRIMARY)
	else:
		name_label.text = skill.display_name
		UIThemes.style_label(name_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_FADED)
	hbox.add_child(name_label)

	# Element requirement squares (for non-innate skills)
	if entry and not entry.required_points.is_empty():
		for elem_key in entry.required_points:
			var elem: int = elem_key
			var pts: int = entry.required_points[elem_key]
			var elem_color: Color = Constants.ELEMENT_COLORS.get(elem, Color.WHITE)
			hbox.add_child(_make_element_square(pts, elem_color, is_unlocked))
	elif is_innate:
		var tag := Label.new()
		tag.text = "innate"
		UIThemes.style_label(tag, 10, Color(0.5, 0.7, 1.0, 0.7))
		hbox.add_child(tag)

	# MP cost
	if is_unlocked and skill.mp_cost > 0:
		var mp_label := Label.new()
		mp_label.text = "%d MP" % skill.mp_cost
		UIThemes.style_label(mp_label, Constants.FONT_SIZE_TINY, Constants.COLOR_TEXT_SECONDARY)
		hbox.add_child(mp_label)
	elif not is_unlocked:
		var lock_label := Label.new()
		lock_label.text = "Locked"
		UIThemes.style_label(lock_label, Constants.FONT_SIZE_TINY, Color(0.6, 0.3, 0.3))
		hbox.add_child(lock_label)

	card.add_child(hbox)

	# Click handler
	card.gui_input.connect(_on_skill_row_input.bind(skill, entry, is_unlocked))

	return card


func _make_element_square(pts: int, color: Color, is_unlocked: bool) -> PanelContainer:
	var square := PanelContainer.new()
	square.custom_minimum_size = Vector2(20, 20)
	var sq_style := StyleBoxFlat.new()
	if is_unlocked:
		sq_style.bg_color = color.darkened(0.5)
		sq_style.border_color = color
	else:
		sq_style.bg_color = color.darkened(0.7)
		sq_style.border_color = color.darkened(0.4)
	sq_style.border_width_left = 1
	sq_style.border_width_right = 1
	sq_style.border_width_top = 1
	sq_style.border_width_bottom = 1
	sq_style.corner_radius_top_left = 2
	sq_style.corner_radius_top_right = 2
	sq_style.corner_radius_bottom_left = 2
	sq_style.corner_radius_bottom_right = 2
	square.add_theme_stylebox_override("panel", sq_style)
	var lbl := Label.new()
	lbl.text = str(pts)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if is_unlocked:
		UIThemes.style_label(lbl, 10, color)
	else:
		UIThemes.style_label(lbl, 10, color.darkened(0.3))
	square.add_child(lbl)
	return square


func _on_skill_row_input(event: InputEvent, skill: SkillData, entry: ElementSkillEntry, is_unlocked: bool) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if _selected_skill != null and _selected_skill.id == skill.id:
			# Deselect
			_selected_skill = null
			_selected_entry = null
			_show_empty_detail()
		else:
			_selected_skill = skill
			_selected_entry = entry
			_selected_unlocked = is_unlocked
			_update_detail_panel(skill, entry, is_unlocked)

		# Rebuild list to update highlight
		if _cached_char_data:
			_update_skill_list(_cached_char_data, _cached_element_points)


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
