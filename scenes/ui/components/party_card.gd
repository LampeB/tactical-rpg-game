class_name PartyCard
extends Button
## A single party member's card: monogram tile + name + role/level + HP/MP bars.
## Use as a toggle button — active state gets paper bg + ink border + offset shadow.
##
## Build via `setup(char_id, char_data, hp_cur, mp_cur)` from a parent component.
## Stays a pure view; the owning rail handles selection and emits the actual
## "this character is now active" signal.

signal card_pressed(character_id: String)

const MONO_SIZE := Vector2(48, 48)
const CARD_HEIGHT := 100

var character_id: String = ""

var _mono_lbl: Label
var _name_lbl: Label
var _role_lbl: Label
var _hp_fill: ColorRect
var _hp_value: Label
var _mp_fill: ColorRect
var _mp_value: Label

var _hp_max: int = 1
var _mp_max: int = 1


func _init() -> void:
	toggle_mode = true
	text = ""
	custom_minimum_size = Vector2(0, CARD_HEIGHT)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_apply_styleboxes()
	_build()
	pressed.connect(func(): card_pressed.emit(character_id))


func setup(char_id: String, char_data: CharacterData, hp_cur: int = -1, mp_cur: int = -1) -> void:
	character_id = char_id
	if not _mono_lbl:
		_build()
	var disp: String = char_data.display_name
	_mono_lbl.text = (disp.substr(0, 1) if not disp.is_empty() else "?").to_upper()
	_name_lbl.text = disp
	var role: String = char_data.character_class.to_upper()
	if role.is_empty():
		role = "—"
	_role_lbl.text = "%s · LV 1" % role
	_hp_max = max(1, char_data.max_hp)
	_mp_max = max(1, char_data.max_mp)
	set_hp(hp_cur if hp_cur >= 0 else char_data.max_hp)
	set_mp(mp_cur if mp_cur >= 0 else char_data.max_mp)


func set_hp(value: int) -> void:
	_hp_fill.anchor_right = clampf(float(value) / float(_hp_max), 0.0, 1.0)
	_hp_value.text = str(value)


func set_mp(value: int) -> void:
	_mp_fill.anchor_right = clampf(float(value) / float(_mp_max), 0.0, 1.0)
	_mp_value.text = str(value)


func _build() -> void:
	if _mono_lbl:
		return
	var hbox := HBoxContainer.new()
	hbox.set_anchors_preset(Control.PRESET_FULL_RECT)
	hbox.offset_left = 10
	hbox.offset_top = 10
	hbox.offset_right = -10
	hbox.offset_bottom = -14
	hbox.add_theme_constant_override("separation", 10)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hbox)

	# Monogram tile
	var mono_box := PanelContainer.new()
	mono_box.custom_minimum_size = MONO_SIZE
	mono_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	mono_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mono_style := StyleBoxFlat.new()
	mono_style.bg_color = DesignTokens.PAPER_3
	mono_style.border_width_left = 1
	mono_style.border_width_top = 1
	mono_style.border_width_right = 1
	mono_style.border_width_bottom = 1
	mono_style.border_color = DesignTokens.INK_3
	mono_box.add_theme_stylebox_override("panel", mono_style)
	hbox.add_child(mono_box)

	_mono_lbl = Label.new()
	_mono_lbl.add_theme_font_size_override("font_size", 24)
	_mono_lbl.add_theme_color_override("font_color", DesignTokens.INK)
	_mono_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mono_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_mono_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mono_box.add_child(_mono_lbl)

	# Right side
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 1)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(right)

	_name_lbl = Label.new()
	_name_lbl.add_theme_font_size_override("font_size", 18)
	_name_lbl.add_theme_color_override("font_color", DesignTokens.INK)
	_name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_name_lbl)

	_role_lbl = Label.new()
	_role_lbl.add_theme_font_size_override("font_size", 11)
	_role_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	_role_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_role_lbl)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	right.add_child(spacer)

	var hp_row := _build_bar_row("HP", DesignTokens.MOSS)
	right.add_child(hp_row)
	_hp_fill = hp_row.get_node("Bar/Fill")
	_hp_value = hp_row.get_node("Value")

	var mp_row := _build_bar_row("MP", DesignTokens.INDIGO)
	right.add_child(mp_row)
	_mp_fill = mp_row.get_node("Bar/Fill")
	_mp_value = mp_row.get_node("Value")


func _build_bar_row(label_text: String, fill_color: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var lbl := Label.new()
	lbl.text = label_text
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	lbl.custom_minimum_size = Vector2(20, 0)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lbl)

	var bar := Control.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 6)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var bar_bg := ColorRect.new()
	bar_bg.name = "Bg"
	bar_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bar_bg.color = DesignTokens.PAPER_3
	bar_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_bg)

	var bar_fill := ColorRect.new()
	bar_fill.name = "Fill"
	bar_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	bar_fill.color = fill_color
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(bar_fill)

	row.add_child(bar)

	var num := Label.new()
	num.name = "Value"
	num.add_theme_font_size_override("font_size", 11)
	num.add_theme_color_override("font_color", DesignTokens.INK)
	num.custom_minimum_size = Vector2(32, 0)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	num.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(num)

	return row


func _apply_styleboxes() -> void:
	var transparent := StyleBoxFlat.new()
	transparent.bg_color = Color(0, 0, 0, 0)

	var hover := StyleBoxFlat.new()
	hover.bg_color = DesignTokens.PAPER_2

	var pressed := StyleBoxFlat.new()
	pressed.bg_color = DesignTokens.PAPER
	pressed.border_width_left = 1
	pressed.border_width_top = 1
	pressed.border_width_right = 1
	pressed.border_width_bottom = 1
	pressed.border_color = DesignTokens.INK
	pressed.shadow_color = DesignTokens.INK
	pressed.shadow_size = 3
	pressed.shadow_offset = Vector2(3, 3)

	add_theme_stylebox_override("normal", transparent)
	add_theme_stylebox_override("hover", hover)
	add_theme_stylebox_override("pressed", pressed)
	add_theme_stylebox_override("focus", transparent)
	add_theme_stylebox_override("hover_pressed", pressed)
