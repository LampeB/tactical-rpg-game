@tool
class_name ToolButton
extends Button
## Small caps-letter capsule button for section toolbars.
## Variants: ghost (default — paper bg + ink-3 border) and solid (ink bg + paper text).
## Set `solid = true` for the solid variant; toggle_mode + button_pressed also flip solid.

@export var solid: bool = false:
	set(value):
		solid = value
		_apply_styles()


func _init() -> void:
	custom_minimum_size = Vector2(0, 28)


func _ready() -> void:
	if not text.is_empty():
		text = text.to_upper()
	add_theme_font_size_override("font_size", 10)
	add_theme_constant_override("h_separation", 6)
	_apply_styles()


func _apply_styles() -> void:
	var ghost := StyleBoxFlat.new()
	ghost.bg_color = DesignTokens.PAPER
	ghost.border_width_left = 1
	ghost.border_width_top = 1
	ghost.border_width_right = 1
	ghost.border_width_bottom = 1
	ghost.border_color = DesignTokens.INK_3
	ghost.corner_radius_top_left = 2
	ghost.corner_radius_top_right = 2
	ghost.corner_radius_bottom_left = 2
	ghost.corner_radius_bottom_right = 2
	ghost.content_margin_left = 10
	ghost.content_margin_right = 10
	ghost.content_margin_top = 4
	ghost.content_margin_bottom = 4

	var ghost_hover := ghost.duplicate() as StyleBoxFlat
	ghost_hover.bg_color = DesignTokens.PAPER_2
	ghost_hover.border_color = DesignTokens.INK

	var solid_style := ghost.duplicate() as StyleBoxFlat
	solid_style.bg_color = DesignTokens.INK
	solid_style.border_color = DesignTokens.INK

	add_theme_stylebox_override("normal", solid_style if solid else ghost)
	add_theme_stylebox_override("hover", solid_style if solid else ghost_hover)
	add_theme_stylebox_override("pressed", solid_style)
	add_theme_stylebox_override("hover_pressed", solid_style)
	add_theme_stylebox_override("focus", ghost_hover)
	add_theme_color_override("font_color", DesignTokens.PAPER if solid else DesignTokens.INK_2)
	add_theme_color_override("font_hover_color", DesignTokens.PAPER if solid else DesignTokens.INK)
	add_theme_color_override("font_pressed_color", DesignTokens.PAPER)
