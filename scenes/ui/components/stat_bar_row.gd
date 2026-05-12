@tool
class_name StatBarRow
extends HBoxContainer
## Stat row: caps label | bar gauge with optional delta overlay | current | arrow | signed delta.
## Use for inspector stat displays where you want to compare a current value against a previewed change.
##
##   row.set_stat("ATK", current=59, max_val=80)               # neutral
##   row.set_stat("ATK", current=59, max_val=80, preview=72)   # green delta
##   row.set_stat("DEF", current=58, max_val=80, preview=44)   # red delta

@export var label: String = "STAT":
	set(value):
		label = value
		_update()

@export var current: int = 0:
	set(value):
		current = value
		_update()

@export var max_value: int = 100:
	set(value):
		max_value = max(1, value)
		_update()

@export var preview: int = -1:  ## -1 = no preview / no delta shown
	set(value):
		preview = value
		_update()

var _label_lbl: Label
var _gauge: Control
var _gauge_fill: ColorRect
var _gauge_delta: ColorRect
var _v0_lbl: Label
var _arrow_lbl: Label
var _v1_lbl: Label


func _ready() -> void:
	_build()
	_update()


func set_stat(label_text: String, cur: int, max_val: int, prev: int = -1) -> void:
	label = label_text
	max_value = max_val
	current = cur
	preview = prev


func _build() -> void:
	if _label_lbl:
		return
	add_theme_constant_override("separation", 8)

	_label_lbl = Label.new()
	_label_lbl.custom_minimum_size = Vector2(60, 0)
	_label_lbl.add_theme_font_size_override("font_size", 10)
	_label_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	_label_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label_lbl)

	_gauge = Control.new()
	_gauge.custom_minimum_size = Vector2(0, 6)
	_gauge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gauge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_gauge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_gauge)

	var gauge_bg := ColorRect.new()
	gauge_bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	gauge_bg.color = DesignTokens.PAPER_3
	gauge_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_child(gauge_bg)

	_gauge_fill = ColorRect.new()
	_gauge_fill.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	_gauge_fill.color = DesignTokens.INK_2
	_gauge_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge.add_child(_gauge_fill)

	_gauge_delta = ColorRect.new()
	_gauge_delta.color = DesignTokens.MOSS
	_gauge_delta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_gauge_delta.visible = false
	_gauge.add_child(_gauge_delta)

	_v0_lbl = Label.new()
	_v0_lbl.custom_minimum_size = Vector2(40, 0)
	_v0_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_v0_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_v0_lbl.add_theme_font_size_override("font_size", 12)
	_v0_lbl.add_theme_color_override("font_color", DesignTokens.INK_2)
	add_child(_v0_lbl)

	_arrow_lbl = Label.new()
	_arrow_lbl.custom_minimum_size = Vector2(14, 0)
	_arrow_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_arrow_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_arrow_lbl.add_theme_font_size_override("font_size", 10)
	add_child(_arrow_lbl)

	_v1_lbl = Label.new()
	_v1_lbl.custom_minimum_size = Vector2(44, 0)
	_v1_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_v1_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_v1_lbl.add_theme_font_size_override("font_size", 12)
	add_child(_v1_lbl)


func _update() -> void:
	if not _label_lbl:
		return
	_label_lbl.text = label.to_upper()
	_v0_lbl.text = str(current)

	var cur_ratio: float = clampf(float(current) / float(max_value), 0.0, 1.0)
	_gauge_fill.anchor_right = cur_ratio
	_gauge_fill.size_flags_horizontal = 0  # static; anchor drives width

	if preview < 0:
		_gauge_delta.visible = false
		_arrow_lbl.text = ""
		_v1_lbl.text = ""
		return

	var delta: int = preview - current
	var prev_ratio: float = clampf(float(preview) / float(max_value), 0.0, 1.0)

	if delta == 0:
		_gauge_delta.visible = false
		_arrow_lbl.text = "·"
		_arrow_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
		_v1_lbl.text = "—"
		_v1_lbl.add_theme_color_override("font_color", DesignTokens.INK_3)
	elif delta > 0:
		_gauge_delta.visible = true
		_gauge_delta.color = DesignTokens.MOSS
		_gauge_delta.set_anchors_preset(Control.PRESET_LEFT_WIDE, false)
		_gauge_delta.anchor_left = cur_ratio
		_gauge_delta.anchor_right = prev_ratio
		_arrow_lbl.text = "▲"
		_arrow_lbl.add_theme_color_override("font_color", DesignTokens.MOSS)
		_v1_lbl.text = "+%d" % delta
		_v1_lbl.add_theme_color_override("font_color", DesignTokens.MOSS)
	else:
		_gauge_delta.visible = true
		_gauge_delta.color = DesignTokens.EMBER
		_gauge_delta.set_anchors_preset(Control.PRESET_LEFT_WIDE, false)
		_gauge_delta.anchor_left = prev_ratio
		_gauge_delta.anchor_right = cur_ratio
		_arrow_lbl.text = "▼"
		_arrow_lbl.add_theme_color_override("font_color", DesignTokens.EMBER)
		_v1_lbl.text = str(delta)
		_v1_lbl.add_theme_color_override("font_color", DesignTokens.EMBER)
