class_name UIThemes
extends RefCounted
## Static helpers for applying common theme overrides to UI controls.
## Reduces repetitive add_theme_*_override() boilerplate.


## Apply font size + font color to a label in one call.
static func style_label(label: Label, font_size: int, color: Color) -> void:
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)


## Apply font size + font color to a Button in one call.
static func style_button(button: Button, font_size: int, color: Color) -> void:
	button.add_theme_font_size_override("font_size", font_size)
	button.add_theme_color_override("font_color", color)


## Set all four margin overrides on a MarginContainer.
static func set_margins(container: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	container.add_theme_constant_override("margin_left", left)
	container.add_theme_constant_override("margin_right", right)
	container.add_theme_constant_override("margin_top", top)
	container.add_theme_constant_override("margin_bottom", bottom)


## Set uniform margins (all four sides equal).
static func set_uniform_margins(container: MarginContainer, value: int) -> void:
	set_margins(container, value, value, value, value)


## Set separation on an HBoxContainer or VBoxContainer.
static func set_separation(box: BoxContainer, value: int) -> void:
	box.add_theme_constant_override("separation", value)
