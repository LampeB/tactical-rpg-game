extends Node
## Shows first-encounter tutorial tooltips. Each tutorial displays once per save
## file, tracked via GameManager flags. Pauses the game tree while displayed.

const FLAG_PREFIX := "tutorial_"

const TUTORIALS: Dictionary = {
	"first_battle": {
		"title": "Combat Basics",
		"body": "Each combatant takes turns based on speed. Choose [b]Attack[/b], [b]Defend[/b], [b]Skill[/b], or [b]Item[/b] when it's your turn.\n\nDefending halves incoming damage until your next turn.",
	},
	"first_inventory": {
		"title": "Grid Inventory",
		"body": "Each character has a grid backpack. Drag items from the stash on the right into the grid.\n\nPress [b]{action:rotate_item}[/b] to rotate items while dragging.",
	},
	"first_loot": {
		"title": "Loot Screen",
		"body": "Drag items from the loot grid into your characters' backpacks or the stash.\n\n[b]Warning:[/b] Items left on the loot grid when you press Continue are lost forever!",
	},
	"first_shop": {
		"title": "Shop",
		"body": "Drag items from the merchant's grid to your inventory to buy them. Drag your items onto the merchant's grid to sell.\n\nYou can buy back sold items before leaving.",
	},
	"first_skill_tree": {
		"title": "Passive Skill Tree",
		"body": "Click nodes to queue them, then press [b]Confirm[/b] to unlock the batch. Each node costs gold.\n\nNodes must be connected to an already-unlocked path.",
	},
	"first_backpack_expand": {
		"title": "Backpack Expansion",
		"body": "Click a greyed-out cell adjacent to your active cells to purchase more space.\n\nVisit the [b]Weaver[/b] NPC to unlock the next backpack tier with new shapes and more cells!",
	},
	"first_quest": {
		"title": "Quests",
		"body": "You've accepted a quest! Press [b]{action:open_quest_log}[/b] to open the Quest Log and track your objectives.\n\nReturn to the quest giver when all objectives are complete.",
	},
}

var _canvas: CanvasLayer
var _dimmer: ColorRect
var _panel: PanelContainer
var _title_label: Label
var _body_label: RichTextLabel
var _dismiss_btn: Button
var _is_showing: bool = false
var _current_id: String = ""
var _queue: Array[String] = []


func _ready() -> void:
	_build_ui()
	_canvas.visible = false

	# Connect EventBus signals for auto-triggered tutorials
	EventBus.combat_started.connect(_on_combat_started)
	EventBus.backpack_expanded.connect(_on_backpack_expanded)
	EventBus.quest_accepted.connect(_on_quest_accepted)


## Show a tutorial tooltip if it hasn't been shown before.
## Safe to call multiple times — duplicates and already-shown tutorials are ignored.
func show_tutorial(tutorial_id: String) -> void:
	if not TUTORIALS.has(tutorial_id):
		push_warning("TutorialManager: Unknown tutorial '%s'" % tutorial_id)
		return
	if GameManager.has_flag(FLAG_PREFIX + tutorial_id):
		return
	if _current_id == tutorial_id:
		return
	if _queue.has(tutorial_id):
		return
	if _is_showing:
		_queue.append(tutorial_id)
		return
	_display(tutorial_id)


func _display(tutorial_id: String) -> void:
	var data: Dictionary = TUTORIALS[tutorial_id]
	_current_id = tutorial_id
	_is_showing = true

	_title_label.text = data["title"]
	_body_label.text = ""
	_body_label.append_text(_resolve_keybinds(str(data["body"])))

	# Size the body label to fit content
	_body_label.custom_minimum_size.y = 0
	_body_label.fit_content = true

	_canvas.visible = true
	get_tree().paused = true


func _dismiss() -> void:
	if not _is_showing:
		return
	_canvas.visible = false
	_is_showing = false

	# Mark as shown
	GameManager.set_flag(FLAG_PREFIX + _current_id)
	_current_id = ""

	# Process queue before unpausing
	if not _queue.is_empty():
		var next_id: String = _queue.pop_front()
		_display(next_id)
		return

	get_tree().paused = false


func _unhandled_input(event: InputEvent) -> void:
	if not _is_showing:
		return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_SPACE, KEY_ENTER, KEY_ESCAPE]:
			get_viewport().set_input_as_handled()
			_dismiss()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		_dismiss()


# === UI Construction ===

func _build_ui() -> void:
	_canvas = CanvasLayer.new()
	_canvas.layer = 99
	_canvas.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_canvas)

	# Dimmer
	_dimmer = ColorRect.new()
	_dimmer.color = Color(0.0, 0.0, 0.0, 0.5)
	_dimmer.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dimmer.mouse_filter = Control.MOUSE_FILTER_STOP
	_canvas.add_child(_dimmer)

	# Center container
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.add_child(center)

	# Panel
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(500, 0)
	_panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color(0.10, 0.12, 0.20, 0.95)
	panel_style.border_color = Color(0.4, 0.5, 0.7, 0.6)
	panel_style.set_border_width_all(1)
	panel_style.set_corner_radius_all(6)
	panel_style.set_content_margin_all(0)
	_panel.add_theme_stylebox_override("panel", panel_style)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	center.add_child(_panel)

	# Margin
	var margin := MarginContainer.new()
	UIThemes.set_uniform_margins(margin, 20)
	_panel.add_child(margin)

	# VBox
	var vbox := VBoxContainer.new()
	UIThemes.set_separation(vbox, 12)
	margin.add_child(vbox)

	# Title
	_title_label = Label.new()
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.style_label(_title_label, Constants.FONT_SIZE_TITLE, Constants.COLOR_TEXT_HEADER)
	vbox.add_child(_title_label)

	# Separator
	var sep := HSeparator.new()
	vbox.add_child(sep)

	# Body (RichTextLabel for bbcode)
	_body_label = RichTextLabel.new()
	_body_label.bbcode_enabled = true
	_body_label.fit_content = true
	_body_label.scroll_active = false
	_body_label.custom_minimum_size = Vector2(460, 60)
	_body_label.set_meta("_base_normal_font_size", Constants.FONT_SIZE_NORMAL)
	_body_label.add_theme_font_size_override("normal_font_size", UIThemes.scaled_font_size(Constants.FONT_SIZE_NORMAL))
	_body_label.set_meta("_base_bold_font_size", Constants.FONT_SIZE_NORMAL)
	_body_label.add_theme_font_size_override("bold_font_size", UIThemes.scaled_font_size(Constants.FONT_SIZE_NORMAL))
	_body_label.add_theme_color_override("default_color", Constants.COLOR_TEXT_PRIMARY)
	_body_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(_body_label)

	# Dismiss button
	_dismiss_btn = Button.new()
	_dismiss_btn.text = "Got it"
	_dismiss_btn.custom_minimum_size = Vector2(120, 36)
	_dismiss_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UIThemes.style_button(_dismiss_btn, Constants.FONT_SIZE_NORMAL, Constants.COLOR_TEXT_PRIMARY)
	_dismiss_btn.pressed.connect(_dismiss)
	vbox.add_child(_dismiss_btn)

	# Hint label
	var hint := Label.new()
	hint.text = "Click anywhere or press Space to dismiss"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UIThemes.style_label(hint, Constants.FONT_SIZE_SMALL, Constants.COLOR_TEXT_FADED)
	vbox.add_child(hint)


# === Keybind Resolution ===

## Replaces {action:action_name} placeholders with the current key name from InputManager.
static func _resolve_keybinds(text: String) -> String:
	var result := text
	var regex := RegEx.new()
	regex.compile("\\{action:(\\w+)\\}")
	for m in regex.search_all(text):
		var action_name: String = m.get_string(1)
		var key_name: String = InputManager.get_action_key_name(action_name)
		result = result.replace(m.get_string(0), key_name)
	return result


# === Signal Handlers ===

func _on_combat_started(_encounter: Resource) -> void:
	show_tutorial("first_battle")


func _on_backpack_expanded(_character_id: String, _unlocked_cells: int) -> void:
	show_tutorial("first_backpack_expand")


func _on_quest_accepted(_quest_id: String) -> void:
	show_tutorial("first_quest")
