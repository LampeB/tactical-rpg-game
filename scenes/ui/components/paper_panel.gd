@tool
class_name PaperPanel
extends PanelContainer
## Paper-bg + ink-border panel with optional 10px corner brackets.
## Drop into any scene; add a single child for content.
## Inherits panel stylebox from `assets/ui/theme/inventory_paper.tres` when the
## scene has the theme applied. Brackets are drawn in script.

@export var show_brackets: bool = true:
	set(value):
		show_brackets = value
		queue_redraw()

@export var bracket_size: int = 10:
	set(value):
		bracket_size = value
		queue_redraw()

@export var bracket_thickness: int = 1:
	set(value):
		bracket_thickness = value
		queue_redraw()

@export var bracket_color: Color = Color(0.184, 0.157, 0.122):
	set(value):
		bracket_color = value
		queue_redraw()


func _ready() -> void:
	resized.connect(queue_redraw)


func _draw() -> void:
	if not show_brackets:
		return
	var s: float = float(bracket_size)
	var t: float = float(bracket_thickness)
	var c: Color = bracket_color
	var w: float = size.x
	var h: float = size.y
	# Brackets sit slightly outside the panel edge (-1 px) so they extend past
	# the 1px border line, mimicking the design's :before/:after corner squares.
	var o: float = -1.0
	# Top-left
	draw_rect(Rect2(o, o, s, t), c)
	draw_rect(Rect2(o, o, t, s), c)
	# Top-right
	draw_rect(Rect2(w - s + 1.0, o, s, t), c)
	draw_rect(Rect2(w + 1.0 - t, o, t, s), c)
	# Bottom-left
	draw_rect(Rect2(o, h + 1.0 - t, s, t), c)
	draw_rect(Rect2(o, h - s + 1.0, t, s), c)
	# Bottom-right
	draw_rect(Rect2(w - s + 1.0, h + 1.0 - t, s, t), c)
	draw_rect(Rect2(w + 1.0 - t, h - s + 1.0, t, s), c)
