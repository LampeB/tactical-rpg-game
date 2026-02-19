extends PanelContainer
## Scrollable combat log displaying battle messages.

@onready var _scroll: ScrollContainer = $Scroll
@onready var _log_text: RichTextLabel = $Scroll/LogText


func _ready() -> void:
	_log_text.text = ""


func add_message(text: String, color: Color = Color.WHITE) -> void:
	var hex: String = color.to_html(false)
	_log_text.append_text("[color=#%s]%s[/color]\n" % [hex, text])
	# Auto-scroll to bottom
	await get_tree().process_frame
	_scroll.scroll_vertical = int(_scroll.get_v_scroll_bar().max_value)


func clear_log() -> void:
	_log_text.text = ""
