extends HBoxContainer
## Persistent party character cards showing portrait, HP bar, and MP bar
## for each active squad member. Added to the overworld HUD.

const CARD_WIDTH := 140
const BAR_HEIGHT := 10
const PORTRAIT_SIZE := 40
const CARD_PADDING := 4

var _cards: Dictionary = {}  ## character_id -> card_container


func _ready() -> void:
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	anchor_top = 1.0
	anchor_bottom = 1.0
	anchor_left = 0.0
	anchor_right = 0.0
	offset_left = 12.0
	offset_top = -12.0
	offset_bottom = -12.0
	grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_theme_constant_override("separation", 8)

	if GameManager.party:
		GameManager.party.vitals_changed.connect(_on_vitals_changed)
		GameManager.party.squad_changed.connect(rebuild)
	rebuild()


func rebuild() -> void:
	for child in get_children():
		child.queue_free()
	_cards.clear()

	if not GameManager.party:
		return

	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()

	for char_id: String in GameManager.party.squad:
		var char_data: CharacterData = GameManager.party.roster.get(char_id)
		if not char_data:
			continue

		var card := _create_card(char_id, char_data, tree)
		add_child(card)
		_cards[char_id] = card


func _create_card(char_id: String, char_data: CharacterData, tree: PassiveTreeData) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(CARD_WIDTH, 0)

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15, 0.85)
	style.corner_radius_top_left = 4
	style.corner_radius_top_right = 4
	style.corner_radius_bottom_left = 4
	style.corner_radius_bottom_right = 4
	style.content_margin_left = CARD_PADDING
	style.content_margin_right = CARD_PADDING
	style.content_margin_top = CARD_PADDING
	style.content_margin_bottom = CARD_PADDING
	panel.add_theme_stylebox_override("panel", style)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)
	panel.add_child(vbox)

	# Top row: portrait + name
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 4)
	vbox.add_child(top_row)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(PORTRAIT_SIZE, PORTRAIT_SIZE)
	portrait.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if char_data.portrait:
		portrait.texture = char_data.portrait
	elif char_data.sprite:
		portrait.texture = char_data.sprite
	top_row.add_child(portrait)

	var name_label := Label.new()
	name_label.text = char_data.display_name
	name_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_SMALL)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.clip_text = true
	top_row.add_child(name_label)

	# HP bar
	var current_hp: int = GameManager.party.get_current_hp(char_id)
	var max_hp: int = GameManager.party.get_max_hp(char_id, tree)

	var hp_bar := ProgressBar.new()
	hp_bar.name = "HPBar"
	hp_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	hp_bar.max_value = max_hp
	hp_bar.value = current_hp
	hp_bar.show_percentage = false
	_apply_hp_bar_style(hp_bar, current_hp, max_hp)
	vbox.add_child(hp_bar)

	var hp_label := Label.new()
	hp_label.name = "HPLabel"
	hp_label.text = "%d/%d" % [current_hp, max_hp]
	hp_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TINY)
	hp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(hp_label)

	# MP bar
	var current_mp: int = GameManager.party.get_current_mp(char_id)
	var max_mp: int = GameManager.party.get_max_mp(char_id, tree)

	var mp_bar := ProgressBar.new()
	mp_bar.name = "MPBar"
	mp_bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	mp_bar.max_value = max_mp
	mp_bar.value = current_mp
	mp_bar.show_percentage = false
	_apply_mp_bar_style(mp_bar)
	vbox.add_child(mp_bar)

	var mp_label := Label.new()
	mp_label.name = "MPLabel"
	mp_label.text = "%d/%d" % [current_mp, max_mp]
	mp_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TINY)
	mp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(mp_label)

	# Dead overlay
	if current_hp <= 0:
		name_label.add_theme_color_override("font_color", Constants.COLOR_DEAD)
		hp_label.text = "DEAD"
		hp_label.add_theme_color_override("font_color", Constants.COLOR_DEAD)

	return panel


func _on_vitals_changed(character_id: String) -> void:
	if not _cards.has(character_id):
		return

	var card: PanelContainer = _cards[character_id]
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()

	var current_hp: int = GameManager.party.get_current_hp(character_id)
	var max_hp: int = GameManager.party.get_max_hp(character_id, tree)
	var current_mp: int = GameManager.party.get_current_mp(character_id)
	var max_mp: int = GameManager.party.get_max_mp(character_id, tree)

	var hp_bar: ProgressBar = card.find_child("HPBar", true, false)
	if hp_bar:
		hp_bar.max_value = max_hp
		hp_bar.value = current_hp
		_apply_hp_bar_style(hp_bar, current_hp, max_hp)

	var hp_label: Label = card.find_child("HPLabel", true, false)
	if hp_label:
		if current_hp <= 0:
			hp_label.text = "DEAD"
			hp_label.add_theme_color_override("font_color", Constants.COLOR_DEAD)
		else:
			hp_label.text = "%d/%d" % [current_hp, max_hp]
			hp_label.remove_theme_color_override("font_color")

	var mp_bar: ProgressBar = card.find_child("MPBar", true, false)
	if mp_bar:
		mp_bar.max_value = max_mp
		mp_bar.value = current_mp

	var mp_label: Label = card.find_child("MPLabel", true, false)
	if mp_label:
		mp_label.text = "%d/%d" % [current_mp, max_mp]


func _apply_hp_bar_style(bar: ProgressBar, current_hp: int, max_hp: int) -> void:
	var fill := StyleBoxFlat.new()
	var ratio: float = float(current_hp) / float(maxi(max_hp, 1))
	if current_hp <= 0:
		fill.bg_color = Constants.COLOR_DEAD
	elif ratio < 0.3:
		fill.bg_color = Constants.COLOR_HP_LOW
	elif ratio < 0.6:
		fill.bg_color = Constants.COLOR_HP_MID
	else:
		fill.bg_color = Constants.COLOR_HP_HIGH
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bar.add_theme_stylebox_override("background", bg)


func _apply_mp_bar_style(bar: ProgressBar) -> void:
	var fill := StyleBoxFlat.new()
	fill.bg_color = Constants.COLOR_MP
	bar.add_theme_stylebox_override("fill", fill)

	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.15, 0.15, 0.15, 1.0)
	bar.add_theme_stylebox_override("background", bg)
