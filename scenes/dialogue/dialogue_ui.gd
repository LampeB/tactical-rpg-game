extends Control
## Dialogue UI. Receives an npc_id via receive_data(), loads the matching NpcData,
## and walks the player through the conversation tree with typewriter text and choices.

const TYPEWRITER_INTERVAL := 0.025  ## Seconds per character (~40 chars/sec).

@onready var _bg: ColorRect = $BG
@onready var _portrait: TextureRect = $VBox/PortraitRow/Portrait
@onready var _speaker_name: Label = $VBox/PortraitRow/SpeakerName
@onready var _dialogue_text: RichTextLabel = $VBox/DialogueBox/DialogueText
@onready var _choices_box: VBoxContainer = $VBox/ChoicesBox
@onready var _continue_hint: Label = $VBox/ContinueHint

var _npc: NpcData = null
var _conversation: DialogueConversation = null
var _line_index: int = 0
var _typewriter_full: String = ""
var _typewriter_pos: int = 0
var _typewriter_timer: Timer = null
var _waiting_for_input: bool = false
var _choices_visible: bool = false


func _ready() -> void:
	_bg.color = UIColors.BG_DIALOGUE
	_typewriter_timer = Timer.new()
	_typewriter_timer.wait_time = TYPEWRITER_INTERVAL
	_typewriter_timer.timeout.connect(_on_typewriter_tick)
	add_child(_typewriter_timer)


func receive_data(data: Dictionary) -> void:
	var npc_id: String = data.get("npc_id", "")
	_npc = NpcDatabase.get_npc(npc_id)
	if not _npc:
		DebugLogger.log_warn("DialogueUI: NPC not found: %s" % npc_id, "Dialogue")
		SceneManager.pop_scene()
		return

	_speaker_name.text = _npc.display_name
	if _npc.portrait:
		_portrait.texture = _npc.portrait
		_portrait.visible = true
	else:
		_portrait.visible = false

	var conv := _find_first_valid_conversation()
	if not conv:
		DebugLogger.log_warn("DialogueUI: No valid conversation for %s" % npc_id, "Dialogue")
		SceneManager.pop_scene()
		return

	_show_conversation(conv)


# === Conversation logic ===

func _find_first_valid_conversation() -> DialogueConversation:
	for conv in _npc.conversations:
		if conv.condition_flag.is_empty():
			return conv
		if GameManager.get_flag(conv.condition_flag) == conv.condition_value:
			return conv
	return null


func _find_conversation_by_id(conv_id: String) -> DialogueConversation:
	for conv in _npc.conversations:
		if conv.id == conv_id:
			return conv
	DebugLogger.log_warn("Conversation not found: %s" % conv_id, "Dialogue")
	return null


func _show_conversation(conv: DialogueConversation) -> void:
	_conversation = conv
	_line_index = 0
	_clear_choices()
	_continue_hint.visible = false
	_waiting_for_input = false
	_choices_visible = false
	_show_next_line()


func _show_next_line() -> void:
	if _line_index >= _conversation.lines.size():
		_on_all_lines_done()
		return
	_start_typewriter(_conversation.lines[_line_index])
	_line_index += 1


# === Typewriter ===

func _start_typewriter(text: String) -> void:
	_typewriter_full = text
	_typewriter_pos = 0
	_dialogue_text.text = ""
	_waiting_for_input = false
	_continue_hint.visible = false
	_typewriter_timer.start()


func _on_typewriter_tick() -> void:
	_typewriter_pos = min(_typewriter_pos + 1, _typewriter_full.length())
	_dialogue_text.text = _typewriter_full.substr(0, _typewriter_pos)
	if _typewriter_pos >= _typewriter_full.length():
		_typewriter_timer.stop()
		_waiting_for_input = true
		_continue_hint.visible = not _conversation.choices.is_empty() or _line_index < _conversation.lines.size()


func _skip_typewriter() -> void:
	_typewriter_timer.stop()
	_typewriter_pos = _typewriter_full.length()
	_dialogue_text.text = _typewriter_full
	_waiting_for_input = true
	_continue_hint.visible = not _conversation.choices.is_empty() or _line_index < _conversation.lines.size()


# === Input ===

func _input(event: InputEvent) -> void:
	var is_key_advance: bool = event.is_action_pressed("interact") or \
		(event is InputEventKey and event.keycode == KEY_SPACE and event.pressed)
	var is_click: bool = event is InputEventMouseButton and \
		(event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT and event.pressed

	# When choices are visible let mouse clicks fall through to the buttons.
	if _choices_visible and is_click:
		return

	if not (is_key_advance or is_click):
		return

	get_viewport().set_input_as_handled()

	if not _typewriter_timer.is_stopped():
		_skip_typewriter()
	elif _waiting_for_input and not _choices_visible:
		_waiting_for_input = false
		_continue_hint.visible = false
		_show_next_line()


# === End of conversation ===

func _on_all_lines_done() -> void:
	if not _conversation.choices.is_empty():
		_show_choices()
	elif not _conversation.auto_next_id.is_empty():
		var next := _find_conversation_by_id(_conversation.auto_next_id)
		if next:
			_show_conversation(next)
		else:
			_end_dialogue()
	else:
		_end_dialogue()


# === Choices ===

func _show_choices() -> void:
	_continue_hint.visible = false
	_waiting_for_input = false
	_clear_choices()  # resets _choices_visible = false, clears old buttons
	for choice in _conversation.choices:
		var btn := Button.new()
		btn.text = choice.text
		btn.pressed.connect(_on_choice_selected.bind(choice))
		_choices_box.add_child(btn)
	_choices_box.visible = true
	_choices_visible = true  # set last so _input lets clicks reach the buttons


func _clear_choices() -> void:
	_choices_visible = false
	_choices_box.visible = false
	for child in _choices_box.get_children():
		child.queue_free()


func _on_choice_selected(choice: DialogueChoice) -> void:
	if not choice.set_flag.is_empty():
		GameManager.set_flag(choice.set_flag, choice.set_flag_value)

	# Check specific actions FIRST before falling back on next_conversation_id.
	if choice.action == "unlock_backpack_tier":
		GameManager.unlock_next_tier_via_weaver()
		_end_dialogue()
	elif choice.action.begins_with("open_shop:"):
		var shop_id := choice.action.trim_prefix("open_shop:")
		# replace_scene keeps the stack intact (overworld stays at stack bottom) so
		# shop's pop_scene() returns there — one fade cycle instead of two.
		EventBus.dialogue_ended.emit(_npc.id)
		SceneManager.replace_scene("res://scenes/shop/shop_ui.tscn", {"shop_id": shop_id})
	elif choice.action == "end" or choice.next_conversation_id.is_empty():
		_end_dialogue()
	else:
		var next := _find_conversation_by_id(choice.next_conversation_id)
		if next:
			_show_conversation(next)
		else:
			_end_dialogue()


func _end_dialogue() -> void:
	EventBus.dialogue_ended.emit(_npc.id)
	SceneManager.pop_scene()
