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
var _resurrect_popup: AcceptDialog = null


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
	# ESC ends dialogue immediately
	if event.is_action_pressed("escape"):
		get_viewport().set_input_as_handled()
		_end_dialogue()
		return

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
	if choice.action == "heal_party":
		_do_heal_party()
		return
	elif choice.action == "resurrect_party":
		_do_resurrect_party()
		return
	elif choice.action == "unlock_backpack_tier":
		GameManager.unlock_next_tier_via_weaver()
		_end_dialogue()
	elif choice.action.begins_with("open_shop:"):
		var shop_id := choice.action.trim_prefix("open_shop:")
		# replace_scene keeps the stack intact (overworld stays at stack bottom) so
		# shop's pop_scene() returns there — one fade cycle instead of two.
		EventBus.dialogue_ended.emit(_npc.id)
		SceneManager.replace_scene("res://scenes/shop/shop_ui.tscn", {"shop_id": shop_id})
	elif choice.action.begins_with("open_crafting:"):
		var station_id := choice.action.trim_prefix("open_crafting:")
		EventBus.dialogue_ended.emit(_npc.id)
		SceneManager.replace_scene("res://scenes/crafting/crafting_ui.tscn", {"station_id": station_id})
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


# === Doctor actions ===

func _do_heal_party() -> void:
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var healed := 0
	for char_id: String in GameManager.party.roster.keys():
		var cur_hp: int = GameManager.party.get_current_hp(char_id)
		if cur_hp <= 0:
			continue  # Dead — heal doesn't revive
		var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
		var max_mp: int = GameManager.party.get_max_mp(char_id, tree)
		GameManager.party.set_current_hp(char_id, max_hp, tree)
		GameManager.party.set_current_mp(char_id, max_mp, tree)
		healed += 1
	DebugLogger.log_info("Doctor healed %d characters" % healed, "Dialogue")
	# Overwrite conversation state so the next advance ends the dialogue cleanly.
	_conversation = DialogueConversation.new()
	_conversation.lines = ["Your wounds have been tended. Go in peace."]
	_line_index = 0
	_clear_choices()
	_show_next_line()


func _do_resurrect_party() -> void:
	var dead_ids: Array[String] = _get_dead_character_ids()
	if dead_ids.is_empty():
		_conversation = DialogueConversation.new()
		_conversation.lines = ["All of your companions are alive and well. No resurrection needed."]
		_line_index = 0
		_clear_choices()
		_show_next_line()
		return

	_show_resurrect_popup(dead_ids)


func _get_dead_character_ids() -> Array[String]:
	var dead: Array[String] = []
	for char_id: String in GameManager.party.roster.keys():
		if GameManager.party.get_current_hp(char_id) <= 0:
			dead.append(char_id)
	return dead


func _show_resurrect_popup(dead_ids: Array[String]) -> void:
	if _resurrect_popup and is_instance_valid(_resurrect_popup):
		_resurrect_popup.queue_free()

	_resurrect_popup = AcceptDialog.new()
	_resurrect_popup.title = "Resurrect — 1 Gold each"
	_resurrect_popup.dialog_hide_on_ok = false
	_resurrect_popup.get_ok_button().text = "Done"
	_resurrect_popup.get_ok_button().pressed.connect(_on_resurrect_done)

	var vbox := VBoxContainer.new()
	for char_id: String in dead_ids:
		var char_data: CharacterData = GameManager.party.roster.get(char_id)
		if not char_data:
			continue
		var btn := Button.new()
		btn.text = "%s (1 Gold)" % char_data.display_name
		btn.pressed.connect(_on_resurrect_target.bind(char_id, btn))
		vbox.add_child(btn)

	var gold_label := Label.new()
	gold_label.name = "GoldLabel"
	gold_label.text = "Gold: %d" % GameManager.gold
	vbox.add_child(gold_label)

	_resurrect_popup.add_child(vbox)
	add_child(_resurrect_popup)
	_resurrect_popup.popup_centered(Vector2i(300, 0))


func _on_resurrect_target(char_id: String, btn: Button) -> void:
	if not GameManager.spend_gold(1):
		EventBus.show_message.emit("Not enough gold!")
		return

	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var max_hp: int = GameManager.party.get_max_hp(char_id, tree)
	var max_mp: int = GameManager.party.get_max_mp(char_id, tree)
	GameManager.party.set_current_hp(char_id, max_hp, tree)
	GameManager.party.set_current_mp(char_id, max_mp, tree)

	var char_data: CharacterData = GameManager.party.roster.get(char_id)
	var char_name: String = char_data.display_name if char_data else char_id
	DebugLogger.log_info("Doctor resurrected %s for 1 gold" % char_name, "Dialogue")

	btn.disabled = true
	btn.text = "%s — Revived!" % char_name

	# Update gold display
	var gold_label: Label = _resurrect_popup.find_child("GoldLabel", true, false)
	if gold_label:
		gold_label.text = "Gold: %d" % GameManager.gold


func _on_resurrect_done() -> void:
	if _resurrect_popup and is_instance_valid(_resurrect_popup):
		_resurrect_popup.queue_free()
		_resurrect_popup = null
	_end_dialogue()
