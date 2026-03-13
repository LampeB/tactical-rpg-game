extends Control
## Live tweaks editor: displays all registered LiveTweaks variables with sliders.

@onready var _bg: ColorRect = $Background
@onready var _tweaks_container: VBoxContainer = $VBox/ScrollContainer/TweaksContainer
@onready var _close_button: Button = $VBox/TopBar/CloseButton
@onready var _reset_all_button: Button = $VBox/TopBar/ResetAllButton
@onready var _modified_label: Label = $VBox/TopBar/ModifiedLabel

var _value_labels: Dictionary = {}  ## key -> Label (displays current value)
var _sliders: Dictionary = {}       ## key -> HSlider


func _ready() -> void:
	_bg.color = UIColors.BG_SETTINGS
	_close_button.pressed.connect(func() -> void: SceneManager.pop_scene())
	_reset_all_button.pressed.connect(_on_reset_all)
	_build_ui()
	_update_modified_count()


func receive_data(_data: Dictionary) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		get_viewport().set_input_as_handled()
		SceneManager.pop_scene()


func _build_ui() -> void:
	var categories: Array = LiveTweaks.get_categories()
	for i in range(categories.size()):
		var cat: String = categories[i]
		_add_category_header(cat)
		var keys: Array = LiveTweaks.get_tweaks_for_category(cat)
		for j in range(keys.size()):
			_add_tweak_row(keys[j])


func _add_category_header(category: String) -> void:
	var sep := HSeparator.new()
	_tweaks_container.add_child(sep)
	var lbl := Label.new()
	lbl.text = category
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_tweaks_container.add_child(lbl)


func _add_tweak_row(key: String) -> void:
	var tweaks: Dictionary = LiveTweaks.get_all_tweaks()
	var entry: Dictionary = tweaks[key]

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Label: formatted key name
	var name_lbl := Label.new()
	name_lbl.text = key.replace("_", " ").capitalize()
	name_lbl.custom_minimum_size = Vector2(220, 0)
	name_lbl.add_theme_font_size_override("font_size", 14)
	row.add_child(name_lbl)

	# Slider
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(300, 0)
	slider.min_value = entry["min_value"]
	slider.max_value = entry["max_value"]
	slider.step = entry["step"]
	slider.value = entry["value"]
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(slider)
	_sliders[key] = slider

	# Value label
	var val_lbl := Label.new()
	val_lbl.text = _format_value(entry["value"], entry["step"])
	val_lbl.custom_minimum_size = Vector2(80, 0)
	val_lbl.add_theme_font_size_override("font_size", 14)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(val_lbl)
	_value_labels[key] = val_lbl

	# Default indicator
	var default_lbl := Label.new()
	default_lbl.custom_minimum_size = Vector2(80, 0)
	default_lbl.add_theme_font_size_override("font_size", 12)
	default_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	default_lbl.text = "(def: %s)" % _format_value(entry["default_value"], entry["step"])
	row.add_child(default_lbl)

	# Reset button
	var reset_btn := Button.new()
	reset_btn.text = "R"
	reset_btn.tooltip_text = "Reset to default"
	reset_btn.custom_minimum_size = Vector2(30, 0)
	reset_btn.pressed.connect(_on_reset_key.bind(key))
	row.add_child(reset_btn)

	slider.value_changed.connect(_on_slider_changed.bind(key, val_lbl, name_lbl))
	_highlight_if_modified(key, name_lbl)

	_tweaks_container.add_child(row)


func _on_slider_changed(value: float, key: String, val_lbl: Label, name_lbl: Label) -> void:
	var tweaks: Dictionary = LiveTweaks.get_all_tweaks()
	val_lbl.text = _format_value(value, tweaks[key]["step"])
	LiveTweaks.set_value(key, value)
	_highlight_if_modified(key, name_lbl)
	_update_modified_count()


func _on_reset_key(key: String) -> void:
	LiveTweaks.reset_key(key)
	var tweaks: Dictionary = LiveTweaks.get_all_tweaks()
	if _sliders.has(key):
		_sliders[key].value = tweaks[key]["value"]
	_update_modified_count()


func _on_reset_all() -> void:
	LiveTweaks.reset_all()
	var tweaks: Dictionary = LiveTweaks.get_all_tweaks()
	var keys: Array = _sliders.keys()
	for i in range(keys.size()):
		var key: String = keys[i]
		_sliders[key].value = tweaks[key]["value"]
	_update_modified_count()


func _highlight_if_modified(key: String, name_lbl: Label) -> void:
	if LiveTweaks.is_modified(key):
		name_lbl.add_theme_color_override("font_color", Color(1.0, 0.8, 0.2))
	else:
		name_lbl.remove_theme_color_override("font_color")


func _update_modified_count() -> void:
	var count: int = 0
	var keys: Array = LiveTweaks.get_all_tweaks().keys()
	for i in range(keys.size()):
		if LiveTweaks.is_modified(keys[i]):
			count += 1
	if count > 0:
		_modified_label.text = "%d modified" % count
	else:
		_modified_label.text = ""


func _format_value(val: float, step: float) -> String:
	if step >= 1.0:
		return "%d" % int(val)
	elif step >= 0.1:
		return "%.1f" % val
	elif step >= 0.01:
		return "%.2f" % val
	else:
		return "%.4f" % val
