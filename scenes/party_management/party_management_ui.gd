extends Control
## Party management screen: view roster, swap squad members.
## Opened via NPC dialogue action "open_party_management" or SceneManager push.

@onready var _bg: ColorRect = $Background
@onready var _close_button: Button = $VBox/TopBar/CloseButton
@onready var _squad_grid: GridContainer = $VBox/Content/SquadPanel/SquadVBox/SquadGrid
@onready var _reserve_grid: GridContainer = $VBox/Content/ReservePanel/ReserveVBox/ReserveGrid
@onready var _info_panel: VBoxContainer = $VBox/Content/InfoPanel
@onready var _portrait_rect: TextureRect = $VBox/Content/InfoPanel/Portrait
@onready var _name_label: Label = $VBox/Content/InfoPanel/NameLabel
@onready var _class_label: Label = $VBox/Content/InfoPanel/ClassLabel
@onready var _stats_label: RichTextLabel = $VBox/Content/InfoPanel/StatsLabel
@onready var _action_box: HBoxContainer = $VBox/Content/InfoPanel/ActionBox
@onready var _move_button: Button = $VBox/Content/InfoPanel/ActionBox/MoveButton
@onready var _squad_count_label: Label = $VBox/Content/SquadPanel/SquadVBox/SquadHeader/SquadCountLabel
@onready var _roster_count_label: Label = $VBox/Content/ReservePanel/ReserveVBox/ReserveHeader/ReserveCountLabel

var _selected_id: String = ""


func _ready() -> void:
	_bg.color = UIColors.BG_PARTY_MGMT
	_close_button.pressed.connect(func() -> void: SceneManager.pop_scene())
	_move_button.pressed.connect(_on_move_pressed)
	_refresh()


func receive_data(_data: Dictionary) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		get_viewport().set_input_as_handled()
		SceneManager.pop_scene()


func _refresh() -> void:
	_selected_id = ""
	_build_squad_cards()
	_build_reserve_cards()
	_update_info_panel()
	_update_counts()


func _update_counts() -> void:
	var party: Party = GameManager.party
	if not party:
		return
	_squad_count_label.text = "%d / %d" % [party.squad.size(), Constants.MAX_SQUAD_SIZE]
	_roster_count_label.text = "%d / %d" % [party.roster.size(), Constants.MAX_ROSTER_SIZE]


func _build_squad_cards() -> void:
	_clear_children(_squad_grid)
	var party: Party = GameManager.party
	if not party:
		return
	for i in range(party.squad.size()):
		var char_id: String = party.squad[i]
		var char_data: CharacterData = party.roster.get(char_id)
		if char_data:
			_add_character_card(_squad_grid, char_data)


func _build_reserve_cards() -> void:
	_clear_children(_reserve_grid)
	var party: Party = GameManager.party
	if not party:
		return
	var roster_keys: Array = party.roster.keys()
	for i in range(roster_keys.size()):
		var char_id: String = roster_keys[i]
		if party.squad.has(char_id):
			continue
		var char_data: CharacterData = party.roster.get(char_id)
		if char_data:
			_add_character_card(_reserve_grid, char_data)


func _add_character_card(grid: GridContainer, char_data: CharacterData) -> void:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(140, 170)

	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 4)

	# Portrait
	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(80, 80)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if char_data.portrait:
		portrait.texture = char_data.portrait
	vbox.add_child(portrait)

	# Name
	var name_lbl := Label.new()
	name_lbl.text = char_data.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 14)
	vbox.add_child(name_lbl)

	# HP / MP
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var hp: int = GameManager.party.get_current_hp(char_data.id)
	var max_hp: int = GameManager.party.get_max_hp(char_data.id, tree)
	var mp: int = GameManager.party.get_current_mp(char_data.id)
	var max_mp: int = GameManager.party.get_max_mp(char_data.id, tree)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP: %d/%d" % [hp, max_hp]
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 12)
	if hp <= 0:
		hp_lbl.add_theme_color_override("font_color", Color(0.8, 0.2, 0.2))
	vbox.add_child(hp_lbl)

	var mp_lbl := Label.new()
	mp_lbl.text = "MP: %d/%d" % [mp, max_mp]
	mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	mp_lbl.add_theme_font_size_override("font_size", 12)
	vbox.add_child(mp_lbl)

	card.add_child(vbox)

	# Selection
	card.gui_input.connect(_on_card_input.bind(char_data.id))
	card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	grid.add_child(card)


func _on_card_input(event: InputEvent, char_id: String) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_selected_id = char_id
		_update_info_panel()
		_highlight_selected()


func _highlight_selected() -> void:
	_reset_card_styles(_squad_grid)
	_reset_card_styles(_reserve_grid)
	# Find and highlight selected
	_apply_highlight(_squad_grid)
	_apply_highlight(_reserve_grid)


func _reset_card_styles(grid: GridContainer) -> void:
	for i in range(grid.get_child_count()):
		var card: PanelContainer = grid.get_child(i)
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.15, 0.15, 0.2, 0.8)
		style.set_corner_radius_all(6)
		card.add_theme_stylebox_override("panel", style)


func _apply_highlight(grid: GridContainer) -> void:
	var party: Party = GameManager.party
	if not party:
		return
	# Build ordered ID list matching grid children
	var ids: Array = []
	if grid == _squad_grid:
		ids = party.squad.duplicate()
	else:
		var roster_keys: Array = party.roster.keys()
		for i in range(roster_keys.size()):
			var char_id: String = roster_keys[i]
			if not party.squad.has(char_id):
				ids.append(char_id)

	for i in range(mini(ids.size(), grid.get_child_count())):
		if ids[i] == _selected_id:
			var card: PanelContainer = grid.get_child(i)
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.25, 0.5, 1.0)
			style.border_color = Color(0.7, 0.5, 1.0)
			style.set_border_width_all(2)
			style.set_corner_radius_all(6)
			card.add_theme_stylebox_override("panel", style)
			break


func _update_info_panel() -> void:
	if _selected_id.is_empty() or not GameManager.party or not GameManager.party.roster.has(_selected_id):
		_info_panel.visible = false
		return

	_info_panel.visible = true
	var char_data: CharacterData = GameManager.party.roster[_selected_id]
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()

	if char_data.portrait:
		_portrait_rect.texture = char_data.portrait
		_portrait_rect.visible = true
	else:
		_portrait_rect.visible = false

	_name_label.text = char_data.display_name
	_class_label.text = char_data.character_class

	var hp: int = GameManager.party.get_current_hp(_selected_id)
	var max_hp: int = GameManager.party.get_max_hp(_selected_id, tree)
	var mp: int = GameManager.party.get_current_mp(_selected_id)
	var max_mp: int = GameManager.party.get_max_mp(_selected_id, tree)

	_stats_label.text = "HP: %d / %d\nMP: %d / %d\nATK: %d\nDEF: %d\nM.ATK: %d\nM.DEF: %d\nSPD: %d\nLUK: %d" % [
		hp, max_hp, mp, max_mp,
		char_data.physical_attack, char_data.physical_defense,
		char_data.magical_attack, char_data.magical_defense,
		char_data.speed, char_data.luck
	]

	# Update button states
	var in_squad: bool = GameManager.party.squad.has(_selected_id)
	if in_squad:
		_move_button.text = "Move to Reserve"
		_move_button.disabled = GameManager.party.squad.size() <= 1
	else:
		_move_button.text = "Move to Squad"
		_move_button.disabled = GameManager.party.squad.size() >= Constants.MAX_SQUAD_SIZE


func _on_move_pressed() -> void:
	if _selected_id.is_empty():
		return
	var party: Party = GameManager.party
	if not party:
		return

	if party.squad.has(_selected_id):
		# Move to reserve
		if party.squad.size() <= 1:
			return
		var new_squad: Array[String] = []
		for i in range(party.squad.size()):
			if party.squad[i] != _selected_id:
				new_squad.append(party.squad[i])
		party.set_squad(new_squad)
	else:
		# Move to squad
		if party.squad.size() >= Constants.MAX_SQUAD_SIZE:
			return
		var new_squad: Array[String] = party.squad.duplicate()
		new_squad.append(_selected_id)
		party.set_squad(new_squad)

	var keep_id: String = _selected_id
	_build_squad_cards()
	_build_reserve_cards()
	_update_counts()
	_selected_id = keep_id
	_update_info_panel()
	_highlight_selected()


func _clear_children(node: Node) -> void:
	for i in range(node.get_child_count() - 1, -1, -1):
		node.get_child(i).queue_free()
