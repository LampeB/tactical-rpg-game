@tool
class_name SectionHeader
extends HBoxContainer
## Section header: big title + caps subtitle on the left, optional toolbar on the right.
## Use `set_title()` / `set_subtitle()` from code, or set the @export properties.
## Add toolbar buttons by appending children to the `toolbar` node:
##   header.toolbar.add_child(my_button)

@export var title: String = "Section":
	set(value):
		title = value
		_update()

@export var subtitle: String = "":
	set(value):
		subtitle = value
		_update()

@export var title_size: int = 26:
	set(value):
		title_size = value
		_update()

var _title_lbl: Label
var _subtitle_lbl: Label
var toolbar: HBoxContainer


func _ready() -> void:
	_build()
	_update()


func _build() -> void:
	if _title_lbl:
		return
	add_theme_constant_override("separation", 16)
	alignment = BoxContainer.ALIGNMENT_BEGIN

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 2)
	add_child(left)

	_title_lbl = Label.new()
	_title_lbl.add_theme_color_override("font_color", Color(0.184, 0.157, 0.122))
	left.add_child(_title_lbl)

	_subtitle_lbl = Label.new()
	_subtitle_lbl.add_theme_color_override("font_color", Color(0.471, 0.435, 0.388))
	_subtitle_lbl.add_theme_font_size_override("font_size", 11)
	left.add_child(_subtitle_lbl)

	toolbar = HBoxContainer.new()
	toolbar.size_flags_vertical = Control.SIZE_SHRINK_END
	toolbar.add_theme_constant_override("separation", 6)
	add_child(toolbar)


func _update() -> void:
	if not _title_lbl:
		return
	_title_lbl.text = title
	_title_lbl.add_theme_font_size_override("font_size", title_size)
	_subtitle_lbl.text = subtitle
	_subtitle_lbl.visible = not subtitle.is_empty()
