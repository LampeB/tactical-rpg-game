extends Node
## Manages display settings (window mode, resolution, vsync, brightness,
## shadow quality, UI scale) and persists them.

signal graphics_changed

const SAVE_PATH := "user://display_settings.json"

## Common 16:9 resolutions, filtered at runtime by screen size.
const COMMON_RESOLUTIONS: Array[Vector2i] = [
	Vector2i(1280, 720),
	Vector2i(1366, 768),
	Vector2i(1600, 900),
	Vector2i(1920, 1080),
	Vector2i(2560, 1440),
	Vector2i(3840, 2160),
]

## 0 = Windowed, 1 = Borderless Fullscreen, 2 = Exclusive Fullscreen
var window_mode: int = 0
var resolution: Vector2i = Vector2i(1920, 1080)
var vsync_enabled: bool = true
var brightness: float = 1.0         ## 0.5 – 1.5
var shadow_quality: int = 2         ## 0=Off, 1=Low, 2=Medium, 3=High
var ui_scale: int = 100             ## 75, 100, 125, 150
var font_scale: int = 100           ## 80, 100, 120, 140
var colorblind_mode: bool = false    ## Use colorblind-safe rarity palette

const UI_SCALE_OPTIONS := [75, 100, 125, 150]
const FONT_SCALE_OPTIONS := [80, 100, 120, 140]
const SHADOW_ATLAS_SIZES := [512, 1024, 2048, 4096]


func _ready() -> void:
	load_settings()
	get_tree().node_added.connect(_on_node_added)


func load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_apply_current()
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		_apply_current()
		return

	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()

	if parse_result != OK:
		push_error("Failed to parse display settings JSON")
		_apply_current()
		return

	var data: Dictionary = json.data
	window_mode = int(data.get("window_mode", 0))
	resolution = Vector2i(
		int(data.get("resolution_width", 1920)),
		int(data.get("resolution_height", 1080))
	)
	vsync_enabled = bool(data.get("vsync", true))
	brightness = float(data.get("brightness", 1.0))
	shadow_quality = int(data.get("shadow_quality", 2))
	ui_scale = int(data.get("ui_scale", 100))
	font_scale = int(data.get("font_scale", 100))
	colorblind_mode = bool(data.get("colorblind_mode", false))
	_apply_current()


func save_settings() -> void:
	var data := {
		"window_mode": window_mode,
		"resolution_width": resolution.x,
		"resolution_height": resolution.y,
		"vsync": vsync_enabled,
		"brightness": brightness,
		"shadow_quality": shadow_quality,
		"ui_scale": ui_scale,
		"font_scale": font_scale,
		"colorblind_mode": colorblind_mode,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to open display settings file for writing")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func set_window_mode(mode: int) -> void:
	window_mode = mode
	_apply_window_mode()
	save_settings()


func set_resolution(width: int, height: int) -> void:
	resolution = Vector2i(width, height)
	_apply_resolution()
	save_settings()


func set_vsync(enabled: bool) -> void:
	vsync_enabled = enabled
	_apply_vsync()
	save_settings()


func set_brightness(value: float) -> void:
	brightness = clampf(value, 0.5, 1.5)
	graphics_changed.emit()
	save_settings()


func set_shadow_quality(quality: int) -> void:
	shadow_quality = clampi(quality, 0, 3)
	_apply_shadow_quality()
	graphics_changed.emit()
	save_settings()


func set_ui_scale(scale_percent: int) -> void:
	ui_scale = scale_percent
	_apply_ui_scale()
	save_settings()


func set_colorblind_mode(enabled: bool) -> void:
	colorblind_mode = enabled
	Constants.colorblind_palette = enabled
	save_settings()


func set_font_scale(scale_percent: int) -> void:
	font_scale = scale_percent
	_apply_font_scale()
	graphics_changed.emit()
	save_settings()


func get_available_resolutions() -> Array[Vector2i]:
	var screen_size := DisplayServer.screen_get_size()
	var result: Array[Vector2i] = []
	for res in COMMON_RESOLUTIONS:
		if res.x <= screen_size.x and res.y <= screen_size.y:
			result.append(res)
	if result.is_empty():
		result.append(Vector2i(1280, 720))
	return result


func _apply_current() -> void:
	_apply_vsync()
	_apply_window_mode()
	_apply_resolution()
	_apply_shadow_quality()
	_apply_ui_scale()
	_apply_font_scale()
	Constants.colorblind_palette = colorblind_mode


func _apply_window_mode() -> void:
	var win := get_window()
	match window_mode:
		0:  # Windowed
			win.mode = Window.MODE_WINDOWED
			win.borderless = false
		1:  # Borderless Fullscreen
			win.mode = Window.MODE_WINDOWED
			win.borderless = true
			var screen_size := DisplayServer.screen_get_size()
			win.size = screen_size
			win.position = Vector2i.ZERO
		2:  # Exclusive Fullscreen
			win.mode = Window.MODE_EXCLUSIVE_FULLSCREEN


func _apply_resolution() -> void:
	if window_mode != 0:
		return
	var win := get_window()
	win.size = resolution
	# Center window on screen
	var screen_size := DisplayServer.screen_get_size()
	@warning_ignore("integer_division")
	win.position = (screen_size - resolution) / 2


func _apply_vsync() -> void:
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)


func _apply_shadow_quality() -> void:
	var atlas_size: int = SHADOW_ATLAS_SIZES[clampi(shadow_quality, 0, 3)]
	RenderingServer.directional_shadow_atlas_set_size(atlas_size, true)


func _apply_ui_scale() -> void:
	var factor := ui_scale / 100.0
	var base := Vector2i(1920, 1080)
	get_window().content_scale_size = Vector2i(int(base.x / factor), int(base.y / factor))


func _apply_font_scale() -> void:
	UIThemes.font_scale = font_scale / 100.0
	var scaled_default: int = int(16 * UIThemes.font_scale)
	# Scale the global fallback font size
	ThemeDB.fallback_font_size = scaled_default
	# Also update the project's custom theme so all controls get the scaled size
	# (theme default_font_size takes priority over ThemeDB.fallback_font_size)
	var project_theme: Theme = load("res://assets/ui/default_theme.tres") as Theme
	if project_theme:
		project_theme.default_font_size = scaled_default
	if is_inside_tree():
		UIThemes.rescale_all(get_tree().root)


func _on_node_added(node: Node) -> void:
	if font_scale == 100:
		return
	if node is Control:
		var ctrl: Control = node as Control
		if ctrl.has_theme_font_size_override("font_size"):
			if not ctrl.has_meta("_base_font_size"):
				var current: int = ctrl.get_theme_font_size("font_size")
				ctrl.set_meta("_base_font_size", current)
				ctrl.add_theme_font_size_override("font_size", UIThemes.scaled_font_size(current))
		# RichTextLabel variants
		if ctrl.has_theme_font_size_override("normal_font_size"):
			UIThemes._rescale_override(ctrl, "normal_font_size")
		if ctrl.has_theme_font_size_override("bold_font_size"):
			UIThemes._rescale_override(ctrl, "bold_font_size")


func apply_environment(env: WorldEnvironment, sun: DirectionalLight3D) -> void:
	## Called by Environment3D scene to apply brightness + shadow settings.
	if env and env.environment:
		env.environment.adjustment_enabled = true
		env.environment.adjustment_brightness = brightness
	if sun:
		sun.shadow_enabled = shadow_quality > 0
