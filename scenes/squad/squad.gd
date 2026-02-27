extends Control
## Squad management screen. Move characters between active squad and bench.

@onready var _bg: ColorRect = $Background
@onready var _squad_list: VBoxContainer = $VBox/Panels/SquadPanel/SquadList
@onready var _bench_list: VBoxContainer = $VBox/Panels/BenchPanel/BenchList
@onready var _squad_count: Label = $VBox/TopBar/SquadCount

var _card_buttons: Dictionary = {}  ## character_id -> Button


func _ready() -> void:
	_bg.color = UIColors.BG_SQUAD
	$VBox/TopBar/BackButton.pressed.connect(_on_back)
	_refresh()
	DebugLogger.log_info("Squad scene ready", "Squad")


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()


func _refresh() -> void:
	_clear_list(_squad_list)
	_clear_list(_bench_list)
	_card_buttons.clear()

	var party: Party = GameManager.party
	if not party:
		return

	# Build squad cards
	for char_id in party.squad:
		var char_data: CharacterData = party.roster.get(char_id)
		if char_data:
			var card := _create_card(char_data, true)
			_squad_list.add_child(card)

	# Build bench cards (roster members not in squad)
	for char_id in party.roster:
		if char_id not in party.squad:
			var char_data: CharacterData = party.roster[char_id]
			var card := _create_card(char_data, false)
			_bench_list.add_child(card)

	# Update count
	_squad_count.text = "Squad: %d/%d" % [party.squad.size(), Constants.MAX_SQUAD_SIZE]


func _create_card(char_data: CharacterData, in_squad: bool) -> PanelContainer:
	var panel := PanelContainer.new()

	var hbox := HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 12)
	panel.add_child(hbox)

	# Name + stats column
	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(vbox)

	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TITLE)
	if in_squad:
		name_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_EMPHASIS)
	vbox.add_child(name_label)

	var stats_label := Label.new()
	stats_label.text = "HP:%d  MP:%d  ATK:%d  DEF:%d  SPD:%d" % [
		char_data.max_hp, char_data.max_mp,
		char_data.physical_attack, char_data.physical_defense,
		char_data.speed
	]
	stats_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
	stats_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_SECONDARY)
	vbox.add_child(stats_label)

	var desc_label := Label.new()
	desc_label.text = char_data.description
	desc_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
	desc_label.add_theme_color_override("font_color", Constants.COLOR_TEXT_FADED)
	desc_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(desc_label)

	# Action button
	var party: Party = GameManager.party
	var btn := Button.new()
	if in_squad:
		btn.text = "Remove"
		btn.pressed.connect(_on_remove_from_squad.bind(char_data.id))
		if party and party.squad.size() <= 1:
			btn.disabled = true
			btn.tooltip_text = "Cannot remove last squad member"
	else:
		btn.text = "Add"
		btn.pressed.connect(_on_add_to_squad.bind(char_data.id))
		if party and party.squad.size() >= Constants.MAX_SQUAD_SIZE:
			btn.disabled = true
			btn.tooltip_text = "Squad is full"
	btn.custom_minimum_size = Vector2(80, 0)
	hbox.add_child(btn)

	_card_buttons[char_data.id] = btn
	return panel


func _on_add_to_squad(char_id: String) -> void:
	var party: Party = GameManager.party
	if not party:
		return
	if party.squad.size() >= Constants.MAX_SQUAD_SIZE:
		DebugLogger.log_warn("Squad is full, cannot add %s" % char_id, "Squad")
		return
	if char_id in party.squad:
		return
	party.squad.append(char_id)
	party.squad_changed.emit()
	DebugLogger.log_info("Added %s to squad" % char_id, "Squad")
	_refresh()


func _on_remove_from_squad(char_id: String) -> void:
	var party: Party = GameManager.party
	if not party:
		return
	if party.squad.size() <= 1:
		DebugLogger.log_warn("Cannot remove last squad member", "Squad")
		return
	party.squad.erase(char_id)
	party.squad_changed.emit()
	DebugLogger.log_info("Removed %s from squad" % char_id, "Squad")
	_refresh()


func _clear_list(list: VBoxContainer) -> void:
	for child in list.get_children():
		child.queue_free()


func _on_back() -> void:
	SceneManager.pop_scene()
