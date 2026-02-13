extends Node
## Autoload singleton that captures errors and logs to a file
## Claude Code can read this file to debug issues

const LOG_PATH = "res://debug_log.txt"
const MAX_LINES = 200

var log_lines: Array[String] = []

func _ready():
	# Clear log on startup
	log_lines.clear()
	_write("=== Game Started: %s ===" % Time.get_datetime_string_from_system())
	_write("Godot %s | %s" % [Engine.get_version_info().string, OS.get_name()])
	_write("Viewport: %s" % get_viewport().get_visible_rect().size)
	_write("")

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_write("=== Game Closed: %s ===" % Time.get_datetime_string_from_system())
		_flush()

func log_info(message: String, source: String = ""):
	var prefix = "[INFO]"
	if source:
		prefix += " [%s]" % source
	_write("%s %s" % [prefix, message])

func log_warn(message: String, source: String = ""):
	var prefix = "[WARN]"
	if source:
		prefix += " [%s]" % source
	_write("%s %s" % [prefix, message])
	push_warning(message)

func log_error(message: String, source: String = ""):
	var prefix = "[ERROR]"
	if source:
		prefix += " [%s]" % source
	_write("%s %s" % [prefix, message])
	push_error(message)

func log_scene_change(scene_name: String):
	_write("")
	_write(">>> Scene changed to: %s" % scene_name)

func _write(text: String):
	var timestamp = Time.get_time_string_from_system()
	var line = "[%s] %s" % [timestamp, text] if text and not text.begins_with("=") else text
	log_lines.append(line)

	# Keep log from growing too large
	if log_lines.size() > MAX_LINES:
		log_lines = log_lines.slice(log_lines.size() - MAX_LINES)

	# Write to file immediately so Claude can read it
	_flush()

func _flush():
	var file = FileAccess.open(LOG_PATH, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(log_lines))
		file.close()
