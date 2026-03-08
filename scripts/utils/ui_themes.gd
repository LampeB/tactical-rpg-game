class_name UIThemes
extends RefCounted
## Static helpers for applying common theme overrides to UI controls.
## Reduces repetitive add_theme_*_override() boilerplate.

## Font scale multiplier (set by DisplayManager). 1.0 = 100%.
static var font_scale: float = 1.0


## Apply scaled font size + font color to a label in one call.
## Stores the base size as metadata so it can be re-scaled live.
static func style_label(label: Label, font_size: int, color: Color) -> void:
	label.set_meta("_base_font_size", font_size)
	label.add_theme_font_size_override("font_size", scaled_font_size(font_size))
	label.add_theme_color_override("font_color", color)


## Apply scaled font size + font color to a Button in one call.
## Stores the base size as metadata so it can be re-scaled live.
static func style_button(button: Button, font_size: int, color: Color) -> void:
	button.set_meta("_base_font_size", font_size)
	button.add_theme_font_size_override("font_size", scaled_font_size(font_size))
	button.add_theme_color_override("font_color", color)


## Set a scaled font_size override on a control, storing the base size as metadata.
## Use this instead of raw add_theme_font_size_override + scaled_font_size.
static func set_font_size(ctrl: Control, base_size: int) -> void:
	ctrl.set_meta("_base_font_size", base_size)
	ctrl.add_theme_font_size_override("font_size", scaled_font_size(base_size))


## Returns the given base font size multiplied by the current font scale.
static func scaled_font_size(base_size: int) -> int:
	return int(base_size * font_scale)


## Re-applies font scale to all Controls in the tree that have font_size overrides.
## Controls styled via UIThemes already have _base_font_size metadata.
## Controls with direct add_theme_font_size_override calls get their current
## (unscaled) value captured as the base on first encounter.
## Called by DisplayManager when font_scale changes.
static func rescale_all(root: Node) -> void:
	if root is Control:
		var ctrl: Control = root as Control
		if ctrl.has_meta("_base_font_size"):
			var base: int = ctrl.get_meta("_base_font_size") as int
			ctrl.add_theme_font_size_override("font_size", scaled_font_size(base))
		elif ctrl.has_theme_font_size_override("font_size"):
			# First time seeing this control — record current value as base
			var current: int = ctrl.get_theme_font_size("font_size")
			ctrl.set_meta("_base_font_size", current)
			ctrl.add_theme_font_size_override("font_size", scaled_font_size(current))
		# RichTextLabel variants (normal_font_size, bold_font_size)
		if ctrl.has_theme_font_size_override("normal_font_size"):
			_rescale_override(ctrl, "normal_font_size")
		if ctrl.has_theme_font_size_override("bold_font_size"):
			_rescale_override(ctrl, "bold_font_size")
	for child in root.get_children():
		rescale_all(child)


static func _rescale_override(ctrl: Control, override_name: String) -> void:
	var meta_key: String = "_base_" + override_name
	if ctrl.has_meta(meta_key):
		var base: int = ctrl.get_meta(meta_key) as int
		ctrl.add_theme_font_size_override(override_name, scaled_font_size(base))
	else:
		var current: int = ctrl.get_theme_font_size(override_name)
		ctrl.set_meta(meta_key, current)
		ctrl.add_theme_font_size_override(override_name, scaled_font_size(current))


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
