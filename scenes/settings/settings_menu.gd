extends Control
## Settings menu with Display and Controls tabs.

@onready var _bg: ColorRect = $ColorRect
@onready var _tab_container: TabContainer = $Panel/MarginContainer/VBoxContainer/TabContainer
@onready var _display_settings: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Display/DisplaySettings
@onready var _audio_settings: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Audio/AudioScroll/AudioSettings
@onready var _keybind_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/TabContainer/Controls/ScrollContainer/KeybindContainer
@onready var _rebind_popup: Panel = $RebindPopup
@onready var _rebind_label: Label = $RebindPopup/MarginContainer/VBoxContainer/Label
@onready var _rebind_key_label: Label = $RebindPopup/MarginContainer/VBoxContainer/KeyLabel
@onready var _reset_all_btn: Button = $Panel/MarginContainer/VBoxContainer/ButtonContainer/ResetAllButton

var _waiting_for_input: bool = false
var _current_action: String = ""
var _resolution_button: OptionButton = null

# Friendly names for actions
const ACTION_NAMES := {
	"move_up": "Move Up",
	"move_down": "Move Down",
	"move_left": "Move Left",
	"move_right": "Move Right",
	"interact": "Interact",
	"open_inventory": "Open Inventory",
	"escape": "Menu / Cancel",
	"rotate_item": "Rotate Item",
	"fast_travel": "Fast Travel",
}

const WINDOW_MODE_NAMES := ["Windowed", "Borderless Fullscreen", "Exclusive Fullscreen"]
const SHADOW_QUALITY_NAMES := ["Off", "Low", "Medium", "High"]
const UI_SCALE_LABELS := ["75%", "100%", "125%", "150%"]
const FONT_SCALE_LABELS := ["80%", "100%", "120%", "140%"]


func _ready() -> void:
	_bg.color = UIColors.BG_SETTINGS
	_build_display_tab()
	_build_audio_tab()
	_populate_keybinds()
	_rebind_popup.hide()
	_update_reset_button_visibility()


# ─── Display Tab ─────────────────────────────────────────────────────────────

func _build_display_tab() -> void:
	# Language row
	var lang_row := _create_setting_row("Language")
	var lang_btn := OptionButton.new()
	lang_btn.custom_minimum_size = Vector2(250, 0)
	var locales: Array = LocaleManager.get_supported_locales()
	var lang_selected := 0
	for idx in locales.size():
		var code: String = locales[idx]
		lang_btn.add_item(LocaleManager.get_locale_display_name(code), idx)
		if code == LocaleManager.current_locale:
			lang_selected = idx
	lang_btn.selected = lang_selected
	lang_btn.item_selected.connect(_on_language_changed.bind(locales))
	lang_row.add_child(lang_btn)
	_display_settings.add_child(lang_row)

	# Window mode row
	var mode_row := _create_setting_row("Window Mode")
	var mode_btn := OptionButton.new()
	mode_btn.custom_minimum_size = Vector2(250, 0)
	for i in WINDOW_MODE_NAMES.size():
		mode_btn.add_item(WINDOW_MODE_NAMES[i], i)
	mode_btn.selected = DisplayManager.window_mode
	mode_btn.item_selected.connect(_on_window_mode_changed)
	mode_row.add_child(mode_btn)
	_display_settings.add_child(mode_row)

	# Resolution row
	var res_row := _create_setting_row("Resolution")
	_resolution_button = OptionButton.new()
	_resolution_button.custom_minimum_size = Vector2(250, 0)
	_populate_resolutions()
	_resolution_button.item_selected.connect(_on_resolution_changed)
	res_row.add_child(_resolution_button)
	_display_settings.add_child(res_row)

	# VSync row
	var vsync_row := _create_setting_row("VSync")
	var vsync_btn := CheckButton.new()
	vsync_btn.button_pressed = DisplayManager.vsync_enabled
	vsync_btn.toggled.connect(_on_vsync_toggled)
	vsync_row.add_child(vsync_btn)
	_display_settings.add_child(vsync_row)

	# Brightness row
	var bright_row := _create_setting_row("Brightness")
	var bright_slider := HSlider.new()
	bright_slider.custom_minimum_size = Vector2(200, 0)
	bright_slider.min_value = 0.5
	bright_slider.max_value = 1.5
	bright_slider.step = 0.05
	bright_slider.value = DisplayManager.brightness
	var bright_label := Label.new()
	bright_label.text = "%.2f" % DisplayManager.brightness
	bright_label.custom_minimum_size = Vector2(40, 0)
	bright_slider.value_changed.connect(_on_brightness_changed.bind(bright_label))
	bright_row.add_child(bright_slider)
	bright_row.add_child(bright_label)
	_display_settings.add_child(bright_row)

	# Shadow quality row
	var shadow_row := _create_setting_row("Shadow Quality")
	var shadow_btn := OptionButton.new()
	shadow_btn.custom_minimum_size = Vector2(250, 0)
	for idx in SHADOW_QUALITY_NAMES.size():
		shadow_btn.add_item(SHADOW_QUALITY_NAMES[idx], idx)
	shadow_btn.selected = DisplayManager.shadow_quality
	shadow_btn.item_selected.connect(_on_shadow_quality_changed)
	shadow_row.add_child(shadow_btn)
	_display_settings.add_child(shadow_row)

	# UI Scale row
	var scale_row := _create_setting_row("UI Scale")
	var scale_btn := OptionButton.new()
	scale_btn.custom_minimum_size = Vector2(250, 0)
	for idx in UI_SCALE_LABELS.size():
		scale_btn.add_item(UI_SCALE_LABELS[idx], idx)
	var scale_idx := DisplayManager.UI_SCALE_OPTIONS.find(DisplayManager.ui_scale)
	scale_btn.selected = maxi(scale_idx, 0)
	scale_btn.item_selected.connect(_on_ui_scale_changed)
	scale_row.add_child(scale_btn)
	_display_settings.add_child(scale_row)

	# Font Size row
	var font_row := _create_setting_row("Font Size")
	var font_btn := OptionButton.new()
	font_btn.custom_minimum_size = Vector2(250, 0)
	for idx in FONT_SCALE_LABELS.size():
		font_btn.add_item(FONT_SCALE_LABELS[idx], idx)
	var font_idx := DisplayManager.FONT_SCALE_OPTIONS.find(DisplayManager.font_scale)
	font_btn.selected = maxi(font_idx, 0)
	font_btn.item_selected.connect(_on_font_scale_changed)
	font_row.add_child(font_btn)
	_display_settings.add_child(font_row)

	_update_resolution_enabled()


func _create_setting_row(label_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(200, 0)
	row.add_child(lbl)
	return row


func _populate_resolutions() -> void:
	_resolution_button.clear()
	var resolutions := DisplayManager.get_available_resolutions()
	var selected_idx := 0
	for i in resolutions.size():
		var res := resolutions[i]
		_resolution_button.add_item("%d x %d" % [res.x, res.y], i)
		if res == DisplayManager.resolution:
			selected_idx = i
	_resolution_button.selected = selected_idx


func _update_resolution_enabled() -> void:
	# Resolution only matters in windowed mode
	_resolution_button.disabled = DisplayManager.window_mode != 0


func _on_window_mode_changed(idx: int) -> void:
	DisplayManager.set_window_mode(idx)
	_update_resolution_enabled()


func _on_resolution_changed(idx: int) -> void:
	var resolutions := DisplayManager.get_available_resolutions()
	if idx < resolutions.size():
		var res := resolutions[idx]
		DisplayManager.set_resolution(res.x, res.y)


func _on_vsync_toggled(enabled: bool) -> void:
	DisplayManager.set_vsync(enabled)


func _on_brightness_changed(value: float, value_label: Label) -> void:
	value_label.text = "%.2f" % value
	DisplayManager.set_brightness(value)


func _on_shadow_quality_changed(idx: int) -> void:
	DisplayManager.set_shadow_quality(idx)


func _on_ui_scale_changed(idx: int) -> void:
	if idx >= 0 and idx < DisplayManager.UI_SCALE_OPTIONS.size():
		DisplayManager.set_ui_scale(DisplayManager.UI_SCALE_OPTIONS[idx])


func _on_font_scale_changed(idx: int) -> void:
	if idx >= 0 and idx < DisplayManager.FONT_SCALE_OPTIONS.size():
		DisplayManager.set_font_scale(DisplayManager.FONT_SCALE_OPTIONS[idx])


func _on_language_changed(idx: int, locales: Array) -> void:
	if idx >= 0 and idx < locales.size():
		LocaleManager.set_locale(locales[idx])


# ─── Audio Tab ───────────────────────────────────────────────────────────────

func _build_audio_tab() -> void:
	# --- Master volume sliders ---
	_add_section_label(_audio_settings, "Volume")
	_add_volume_slider(_audio_settings, "Master", AudioManager.master_volume_db, func(v: float) -> void:
		AudioManager.master_volume_db = v
		AudioManager.save_audio_settings()
	)
	_add_volume_slider(_audio_settings, "Music", linear_to_db(AudioManager.music_volume), func(v: float) -> void:
		AudioManager.music_volume = db_to_linear(v)
		AudioManager.save_audio_settings()
	)
	_add_volume_slider(_audio_settings, "SFX", linear_to_db(AudioManager.sfx_volume), func(v: float) -> void:
		AudioManager.sfx_volume = db_to_linear(v)
		AudioManager.save_audio_settings()
	)
	_add_volume_slider(_audio_settings, "Ambient", linear_to_db(AudioManager.ambient_volume), func(v: float) -> void:
		AudioManager.ambient_volume = db_to_linear(v)
		AudioManager.save_audio_settings()
	)

	# --- Debug: individual SFX test sliders ---
	_add_section_label(_audio_settings, "Debug — SFX Preview (click label to play)")
	var sfx_keys: Array = AudioManager.SFX.keys()
	sfx_keys.sort()
	for key in sfx_keys:
		_add_sfx_test_row(_audio_settings, key)

	# --- Debug: music test buttons ---
	_add_section_label(_audio_settings, "Debug — Music Preview")
	var music_keys: Array = AudioManager.MUSIC.keys()
	music_keys.sort()
	for key in music_keys:
		_add_music_test_row(_audio_settings, key)


func _add_section_label(parent: VBoxContainer, text: String) -> void:
	var sep := HSeparator.new()
	parent.add_child(sep)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	parent.add_child(lbl)


func _add_volume_slider(parent: VBoxContainer, label_text: String, initial_db: float, callback: Callable) -> void:
	var row := _create_setting_row(label_text)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(200, 0)
	slider.min_value = -40.0
	slider.max_value = 6.0
	slider.step = 0.5
	slider.value = initial_db
	var val_label := Label.new()
	val_label.text = "%.1f dB" % initial_db
	val_label.custom_minimum_size = Vector2(70, 0)
	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = "%.1f dB" % v
		callback.call(v)
	)
	row.add_child(slider)
	row.add_child(val_label)
	parent.add_child(row)


func _add_sfx_test_row(parent: VBoxContainer, sfx_key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	# Clickable label to play the sound
	var btn := Button.new()
	btn.text = sfx_key
	btn.custom_minimum_size = Vector2(200, 0)
	btn.flat = true
	btn.pressed.connect(func() -> void: AudioManager.play_sfx(sfx_key))
	row.add_child(btn)

	# Per-SFX volume slider (adjusts the stream's volume_db when played)
	var slider := HSlider.new()
	slider.custom_minimum_size = Vector2(150, 0)
	slider.min_value = -30.0
	slider.max_value = 10.0
	slider.step = 0.5
	slider.value = AudioManager.get_sfx_volume_db(sfx_key)
	var val_label := Label.new()
	val_label.text = "%.1f" % slider.value
	val_label.custom_minimum_size = Vector2(50, 0)
	slider.value_changed.connect(func(v: float) -> void:
		val_label.text = "%.1f" % v
		AudioManager.set_sfx_volume_db(sfx_key, v)
		AudioManager.save_audio_settings()
	)
	row.add_child(slider)
	row.add_child(val_label)

	# Test play button
	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(60, 0)
	play_btn.pressed.connect(func() -> void: AudioManager.play_sfx(sfx_key))
	row.add_child(play_btn)

	parent.add_child(row)


func _add_music_test_row(parent: VBoxContainer, music_key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var btn := Button.new()
	btn.text = music_key
	btn.custom_minimum_size = Vector2(200, 0)
	btn.pressed.connect(func() -> void: AudioManager.play_music(music_key, true))
	row.add_child(btn)
	parent.add_child(row)


# ─── Controls Tab ────────────────────────────────────────────────────────────

func _populate_keybinds() -> void:
	for child in _keybind_container.get_children():
		child.queue_free()
	for action_name in ACTION_NAMES.keys():
		var row := _create_keybind_row(action_name)
		_keybind_container.add_child(row)


func _create_keybind_row(action_name: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)

	var name_label := Label.new()
	name_label.text = ACTION_NAMES[action_name]
	name_label.custom_minimum_size = Vector2(200, 0)
	row.add_child(name_label)

	var key_label := Label.new()
	key_label.text = InputManager.get_action_key_name(action_name)
	key_label.custom_minimum_size = Vector2(150, 0)
	key_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(key_label)

	var rebind_btn := Button.new()
	rebind_btn.text = "Rebind"
	rebind_btn.custom_minimum_size = Vector2(100, 0)
	rebind_btn.pressed.connect(_on_rebind_pressed.bind(action_name, key_label))
	row.add_child(rebind_btn)

	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.custom_minimum_size = Vector2(100, 0)
	reset_btn.pressed.connect(_on_reset_pressed.bind(action_name, key_label))
	row.add_child(reset_btn)

	return row


func _on_rebind_pressed(action_name: String, _key_label: Label) -> void:
	_current_action = action_name
	_waiting_for_input = true
	_rebind_label.text = "Press a key for:\n%s" % ACTION_NAMES[action_name]
	_rebind_key_label.text = ""
	_rebind_popup.show()


func _on_reset_pressed(action_name: String, key_label: Label) -> void:
	InputManager.reset_action(action_name)
	key_label.text = InputManager.get_action_key_name(action_name)


func _input(event: InputEvent) -> void:
	if not _waiting_for_input:
		return
	if event is InputEventKey and event.pressed:
		InputManager.rebind_action(_current_action, event)
		_rebind_key_label.text = "Bound to: %s" % OS.get_keycode_string(event.keycode)
		await get_tree().create_timer(0.5).timeout
		_waiting_for_input = false
		_rebind_popup.hide()
		_populate_keybinds()
		get_viewport().set_input_as_handled()


# ─── Shared ──────────────────────────────────────────────────────────────────

func _on_tab_changed(_tab: int) -> void:
	_update_reset_button_visibility()


func _update_reset_button_visibility() -> void:
	# Only show "Reset All to Defaults" on the Controls tab
	_reset_all_btn.visible = _tab_container.current_tab == 2


func _on_reset_all_pressed() -> void:
	InputManager.reset_all_actions()
	_populate_keybinds()


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting_for_input and event.is_action_pressed("escape"):
		_on_back_pressed()
		get_viewport().set_input_as_handled()


func _on_back_pressed() -> void:
	SceneManager.pop_scene()
