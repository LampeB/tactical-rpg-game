extends CanvasLayer
## Unified game menu — sidebar navigation with embedded content views.
## Replaces pause_menu + character_hub. Opened with ESC or shortcut keys.

signal closed

enum Tab {
	INVENTORY,
	SKILLS,
	PASSIVES,
	STATS,
	MAP,
	QUESTS,
	GLOSSARY,
	OPTIONS,
}

## Tabs that show the character carousel
const CHARACTER_TABS: Array[int] = [Tab.INVENTORY, Tab.SKILLS, Tab.PASSIVES, Tab.STATS]

## Tab display names
const TAB_NAMES: Dictionary = {
	Tab.INVENTORY: "Inventory",
	Tab.SKILLS: "Skills",
	Tab.PASSIVES: "Passives",
	Tab.STATS: "Stats",
	Tab.MAP: "Map",
	Tab.QUESTS: "Quests",
	Tab.GLOSSARY: "Glossary",
	Tab.OPTIONS: "Options",
}

## Tab shortcut keys
const TAB_KEYS: Dictionary = {
	Tab.INVENTORY: KEY_I,
	Tab.SKILLS: KEY_K,
	Tab.PASSIVES: KEY_T,
	Tab.STATS: KEY_C,
	Tab.MAP: KEY_M,
	Tab.QUESTS: KEY_Q,
	Tab.GLOSSARY: KEY_G,
	Tab.OPTIONS: KEY_O,
}

var _current_tab: int = -1
var _current_character_id: String = ""
var _views: Dictionary = {}  # Tab → Control
var _tab_buttons: Dictionary = {}  # Tab → Button

# UI references
var _sidebar: VBoxContainer
var _content_area: Control
var _carousel: HBoxContainer
var _gold_label: Label
var _bg: ColorRect


func _ready() -> void:
	layer = 100

	# Set character before building UI so carousel highlights correctly
	if GameManager.party and not GameManager.party.squad.is_empty():
		_current_character_id = GameManager.party.squad[0]

	_build_ui()

	# Start paused
	get_tree().paused = true
	process_mode = Node.PROCESS_MODE_ALWAYS


func _build_ui() -> void:
	# Dark semi-transparent background
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.05, 0.08, 0.92)
	_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_bg)

	# Main layout: sidebar + content
	var main_hbox := HBoxContainer.new()
	main_hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	main_hbox.add_theme_constant_override("separation", 0)
	add_child(main_hbox)

	# === Sidebar ===
	var sidebar_panel := PanelContainer.new()
	sidebar_panel.custom_minimum_size = Vector2(180, 0)
	var sidebar_style := StyleBoxFlat.new()
	sidebar_style.bg_color = Color(0.08, 0.08, 0.12, 1.0)
	sidebar_style.border_color = Color(0.25, 0.22, 0.18, 1.0)
	sidebar_style.border_width_right = 2
	sidebar_panel.add_theme_stylebox_override("panel", sidebar_style)
	main_hbox.add_child(sidebar_panel)

	_sidebar = VBoxContainer.new()
	_sidebar.add_theme_constant_override("separation", 2)
	sidebar_panel.add_child(_sidebar)

	# Sidebar title
	var title := Label.new()
	title.text = "Menu"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	title.custom_minimum_size = Vector2(0, 40)
	_sidebar.add_child(title)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_sidebar.add_child(sep)

	# Tab buttons
	for tab_id in range(Tab.size()):
		var btn := Button.new()
		btn.text = "  %s" % TAB_NAMES[tab_id]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_tab_pressed.bind(tab_id))
		_sidebar.add_child(btn)
		_tab_buttons[tab_id] = btn

		# Add shortcut hint
		var key_name: String = ""
		if TAB_KEYS.has(tab_id):
			key_name = OS.get_keycode_string(TAB_KEYS[tab_id])
		if not key_name.is_empty():
			btn.text = "  %s  [%s]" % [TAB_NAMES[tab_id], key_name]

	# Spacer to push "Return to Game" to bottom
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_sidebar.add_child(spacer)

	# Return to Game button
	var sep2 := HSeparator.new()
	_sidebar.add_child(sep2)
	var return_btn := Button.new()
	return_btn.text = "  Return to Game  [Esc]"
	return_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	return_btn.custom_minimum_size = Vector2(0, 36)
	return_btn.add_theme_font_size_override("font_size", 16)
	return_btn.pressed.connect(_close)
	_sidebar.add_child(return_btn)

	# === Right side: carousel + content ===
	var right_vbox := VBoxContainer.new()
	right_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right_vbox.add_theme_constant_override("separation", 0)
	main_hbox.add_child(right_vbox)

	# Character carousel — shows all characters, selected one is bigger with glow
	_carousel = HBoxContainer.new()
	_carousel.custom_minimum_size = Vector2(0, 70)
	_carousel.alignment = BoxContainer.ALIGNMENT_CENTER
	_carousel.add_theme_constant_override("separation", 12)
	right_vbox.add_child(_carousel)

	_build_carousel()

	# Gold display (right-aligned, between carousel and content)
	_gold_label = Label.new()
	_gold_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_gold_label.add_theme_font_size_override("font_size", 18)
	_gold_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	_gold_label.custom_minimum_size = Vector2(0, 24)
	right_vbox.add_child(_gold_label)
	_update_gold()
	EventBus.gold_changed.connect(_on_gold_changed)

	# Content area
	_content_area = Control.new()
	_content_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_area.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_area.clip_contents = true
	right_vbox.add_child(_content_area)

	# Options sub-menu is created as a content view (like glossary)


func open_tab(tab: int) -> void:
	if tab == _current_tab:
		return

	# Hide current view
	if _views.has(_current_tab):
		_views[_current_tab].visible = false

	_current_tab = tab

	# Update button highlights
	for tab_id in _tab_buttons:
		var btn: Button = _tab_buttons[tab_id]
		btn.disabled = (tab_id == tab)

	# Show/hide carousel and gold
	_carousel.visible = tab in CHARACTER_TABS
	_gold_label.visible = tab in [Tab.INVENTORY, Tab.PASSIVES]
	_update_gold()

	# Create or show view
	if not _views.has(tab):
		_views[tab] = _create_view(tab)
	_views[tab].visible = true


func _create_view(tab: int) -> Control:
	var view: Control = null
	match tab:
		Tab.INVENTORY:
			view = load("res://scenes/character_stats/character_stats.tscn").instantiate()
			_content_area.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			view.setup_embedded(_current_character_id, view.EmbedMode.INVENTORY_ONLY)
		Tab.SKILLS:
			view = load("res://scenes/character_skills/character_skills.tscn").instantiate()
			_content_area.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if view.has_method("setup_embedded"):
				view.setup_embedded(_current_character_id)
		Tab.PASSIVES:
			view = load("res://scenes/passive_tree/passive_tree.tscn").instantiate()
			_content_area.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			if view.has_method("setup_embedded"):
				view.setup_embedded(_current_character_id)
		Tab.STATS:
			view = load("res://scenes/character_stats/character_stats.tscn").instantiate()
			_content_area.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
			view.setup_embedded(_current_character_id, view.EmbedMode.STATS_ONLY)
		Tab.MAP:
			view = _create_placeholder("World Map", "Map coming soon...")
		Tab.QUESTS:
			view = load("res://scenes/menus/quest_log_ui.tscn").instantiate()
			_content_area.add_child(view)
			view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		Tab.GLOSSARY:
			view = _create_glossary_placeholder()
		Tab.OPTIONS:
			view = _create_options_view()
		_:
			view = _create_placeholder("Unknown", "")
	return view


func _create_placeholder(title_text: String, description: String) -> Control:
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(container)

	var vbox := VBoxContainer.new()
	vbox.set_anchors_preset(Control.PRESET_CENTER)
	vbox.custom_minimum_size = Vector2(400, 200)
	vbox.position = Vector2(-200, -100)
	container.add_child(vbox)

	var lbl_title := Label.new()
	lbl_title.text = title_text
	lbl_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_title.add_theme_font_size_override("font_size", 28)
	lbl_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	vbox.add_child(lbl_title)

	var lbl_desc := Label.new()
	lbl_desc.text = description
	lbl_desc.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl_desc.add_theme_font_size_override("font_size", 16)
	lbl_desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	lbl_desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	vbox.add_child(lbl_desc)

	return container


func _create_glossary_placeholder() -> Control:
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(container)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)

	# Category list
	var cat_list := VBoxContainer.new()
	cat_list.custom_minimum_size = Vector2(160, 0)
	hbox.add_child(cat_list)

	var cat_title := Label.new()
	cat_title.text = "Categories"
	cat_title.add_theme_font_size_override("font_size", 18)
	cat_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	cat_list.add_child(cat_title)

	for cat in ["Items", "Enemies", "Mechanics", "Lore", "Elements"]:
		var btn := Button.new()
		btn.text = cat
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		cat_list.add_child(btn)

	# Content
	var content := Label.new()
	content.text = "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat.\n\nDuis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."
	content.autowrap_mode = TextServer.AUTOWRAP_WORD
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_font_size_override("font_size", 14)
	content.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(content)

	return container


# ---------------------------------------------------------------------------
# Character Carousel
# ---------------------------------------------------------------------------

var _char_cards: Dictionary = {}  # character_id → PanelContainer
var _char_glow_tweens: Dictionary = {}  # character_id → Tween


func _build_carousel() -> void:
	## Builds character cards for all squad members.
	for child in _carousel.get_children():
		child.queue_free()
	_char_cards.clear()
	_char_glow_tweens.clear()

	if not GameManager.party or GameManager.party.squad.is_empty():
		return

	for char_id in GameManager.party.squad:
		var char_data: CharacterData = GameManager.party.roster.get(char_id)
		if not char_data:
			continue

		var card := PanelContainer.new()
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.gui_input.connect(_on_char_card_input.bind(char_id))

		var card_vbox := VBoxContainer.new()
		card_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		card_vbox.add_theme_constant_override("separation", 2)
		card_vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(card_vbox)

		var name_label := Label.new()
		name_label.text = char_data.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(name_label)

		var class_label := Label.new()
		class_label.text = char_data.character_class
		class_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		class_label.add_theme_font_size_override("font_size", 12)
		class_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		class_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card_vbox.add_child(class_label)

		_carousel.add_child(card)
		_char_cards[char_id] = card

	_update_carousel_highlight()


func _update_carousel_highlight() -> void:
	## Updates card sizes and glow to reflect the selected character.
	for char_id in _char_cards:
		var card: PanelContainer = _char_cards[char_id]
		var is_selected: bool = (char_id == _current_character_id)

		# Size
		if is_selected:
			card.custom_minimum_size = Vector2(120, 60)
		else:
			card.custom_minimum_size = Vector2(90, 45)

		# Style
		var style := StyleBoxFlat.new()
		if is_selected:
			style.bg_color = Color(0.15, 0.15, 0.22, 1.0)
			style.border_color = Color(1.0, 0.85, 0.2, 1.0)
			style.set_border_width_all(2)
		else:
			style.bg_color = Color(0.1, 0.1, 0.14, 1.0)
			style.border_color = Color(0.3, 0.3, 0.35, 1.0)
			style.set_border_width_all(1)
		style.set_corner_radius_all(4)
		style.set_content_margin_all(6)
		card.add_theme_stylebox_override("panel", style)

		# Font sizes
		var name_label: Label = card.get_child(0).get_child(0)
		var class_label: Label = card.get_child(0).get_child(1)
		name_label.add_theme_font_size_override("font_size", 16 if is_selected else 13)
		name_label.add_theme_color_override("font_color", Color(0.95, 0.9, 0.75) if is_selected else Color(0.7, 0.7, 0.7))
		class_label.visible = is_selected

		# Glow animation on selected
		if _char_glow_tweens.has(char_id) and _char_glow_tweens[char_id]:
			_char_glow_tweens[char_id].kill()
			_char_glow_tweens[char_id] = null

		if is_selected:
			var tween := card.create_tween().set_loops()
			tween.tween_property(style, "border_color", Color(1.0, 0.85, 0.2, 1.0), 0.5)
			tween.tween_property(style, "border_color", Color(1.0, 0.55, 0.0, 1.0), 0.5)
			_char_glow_tweens[char_id] = tween


func _on_char_card_input(event: InputEvent, char_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_select_character(char_id)


func _select_character(char_id: String) -> void:
	if char_id == _current_character_id:
		return
	_current_character_id = char_id
	_update_carousel_highlight()
	# Refresh current view with new character — pass correct embed mode
	if _current_tab in CHARACTER_TABS and _views.has(_current_tab):
		var view: Control = _views[_current_tab]
		if view.has_method("setup_embedded"):
			if _current_tab == Tab.INVENTORY and view.get("EmbedMode"):
				view.setup_embedded(_current_character_id, view.EmbedMode.INVENTORY_ONLY)
			elif _current_tab == Tab.STATS and view.get("EmbedMode"):
				view.setup_embedded(_current_character_id, view.EmbedMode.STATS_ONLY)
			else:
				view.setup_embedded(_current_character_id)


func _create_options_view() -> Control:
	var container := Control.new()
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_content_area.add_child(container)

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 8)
	container.add_child(hbox)

	# Options buttons list (like glossary categories)
	var opt_list := VBoxContainer.new()
	opt_list.custom_minimum_size = Vector2(180, 0)
	opt_list.add_theme_constant_override("separation", 4)
	hbox.add_child(opt_list)

	var opt_title := Label.new()
	opt_title.text = "Options"
	opt_title.add_theme_font_size_override("font_size", 20)
	opt_title.add_theme_color_override("font_color", Color(0.9, 0.85, 0.7))
	opt_list.add_child(opt_title)

	var sep := HSeparator.new()
	opt_list.add_child(sep)

	for opt in [["Save", "save"], ["Load", "load"], ["Settings", "settings"], ["Quit to Menu", "quit"]]:
		var btn := Button.new()
		btn.text = opt[0]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.custom_minimum_size = Vector2(0, 36)
		btn.add_theme_font_size_override("font_size", 16)
		btn.pressed.connect(_on_option_pressed.bind(opt[1]))
		opt_list.add_child(btn)

	# Right side placeholder
	var info := Label.new()
	info.text = "Select an option from the list."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_font_size_override("font_size", 16)
	info.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hbox.add_child(info)

	return container


func _on_option_pressed(option: String) -> void:
	match option:
		"save":
			_close()
			SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "save"})
		"load":
			_close()
			SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})
		"settings":
			_close()
			SceneManager.push_scene("res://scenes/settings/settings_menu.tscn")
		"quit":
			_close()
			SceneManager.clear_stack()
			SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")


# ---------------------------------------------------------------------------
# Input
# ---------------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		# ESC closes menu
		if event.keycode == KEY_ESCAPE:
			_close()
			get_viewport().set_input_as_handled()
			return

		# Tab shortcuts — same key toggles closed if already on that tab
		for tab_id in TAB_KEYS:
			if event.keycode == TAB_KEYS[tab_id]:
				if _current_tab == tab_id:
					_close()
				else:
					open_tab(tab_id)
				get_viewport().set_input_as_handled()
				return


func _on_tab_pressed(tab_id: int) -> void:
	open_tab(tab_id)


func _update_gold() -> void:
	if _gold_label:
		_gold_label.text = "Gold: %d" % GameManager.gold


func _on_gold_changed(_amount: int) -> void:
	_update_gold()


func _close() -> void:
	get_tree().paused = false
	if EventBus.gold_changed.is_connected(_on_gold_changed):
		EventBus.gold_changed.disconnect(_on_gold_changed)
	closed.emit()
	queue_free()
