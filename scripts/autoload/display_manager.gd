extends Node
## Manages display settings (window mode, resolution, vsync) and persists them.

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


func _ready() -> void:
	load_settings()


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
	_apply_current()


func save_settings() -> void:
	var data := {
		"window_mode": window_mode,
		"resolution_width": resolution.x,
		"resolution_height": resolution.y,
		"vsync": vsync_enabled,
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
	win.position = (screen_size - resolution) / 2


func _apply_vsync() -> void:
	if vsync_enabled:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED)
	else:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
