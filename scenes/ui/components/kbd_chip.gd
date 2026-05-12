@tool
class_name KbdChip
extends HBoxContainer
## Keycap pill + label (e.g. "[A] PICK"). Used in headers and footers.
## Set `key` and `label` in the inspector or via setters.

@export var key: String = "A":
	set(value):
		key = value
		_update()

@export var label: String = "ACTION":
	set(value):
		label = value
		_update()

@export var compact: bool = false:
	set(value):
		compact = value
		_update()

var _key_panel: PanelContainer
var _key_lbl: Label
var _label_lbl: Label


func _ready() -> void:
	_build()
	_update()


func _build() -> void:
	if _key_panel:
		return
	add_theme_constant_override("separation", 6)

	_key_panel = PanelContainer.new()
	_key_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key_style := StyleBoxFlat.new()
	key_style.bg_color = Color(0.953, 0.910, 0.838)
	key_style.border_width_left = 1
	key_style.border_width_top = 1
	key_style.border_width_right = 1
	key_style.border_width_bottom = 1
	key_style.border_color = Color(0.471, 0.435, 0.388)
	key_style.content_margin_left = 6
	key_style.content_margin_right = 6
	key_style.content_margin_top = 2
	key_style.content_margin_bottom = 2
	key_style.corner_radius_top_left = 3
	key_style.corner_radius_top_right = 3
	key_style.corner_radius_bottom_left = 3
	key_style.corner_radius_bottom_right = 3
	_key_panel.add_theme_stylebox_override("panel", key_style)
	add_child(_key_panel)

	_key_lbl = Label.new()
	_key_lbl.add_theme_color_override("font_color", Color(0.318, 0.286, 0.247))
	_key_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_key_panel.add_child(_key_lbl)

	_label_lbl = Label.new()
	_label_lbl.add_theme_color_override("font_color", Color(0.471, 0.435, 0.388))
	_label_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_label_lbl)


func _update() -> void:
	if not _key_panel:
		return
	_key_lbl.text = key
	_key_lbl.add_theme_font_size_override("font_size", 9 if compact else 10)
	_label_lbl.text = label
	_label_lbl.add_theme_font_size_override("font_size", 10 if compact else 11)
