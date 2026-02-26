extends PanelContainer
## Displays HP/MP bars and status icons for a single combat entity.

var _entity: CombatEntity

@onready var _portrait: TextureRect = $MarginContainer/HBox/PortraitContainer/Portrait
@onready var _name_label: Label = $MarginContainer/HBox/VBox/NameLabel
@onready var _hp_bar: ProgressBar = $MarginContainer/HBox/VBox/HPContainer/HPBar
@onready var _hp_label: Label = $MarginContainer/HBox/VBox/HPContainer/HPBar/HPLabel
@onready var _mp_bar: ProgressBar = $MarginContainer/HBox/VBox/MPContainer/MPBar
@onready var _mp_label: Label = $MarginContainer/HBox/VBox/MPContainer/MPBar/MPLabel
@onready var _mp_container: HBoxContainer = $MarginContainer/HBox/VBox/MPContainer
@onready var _status_icons: HBoxContainer = $MarginContainer/HBox/VBox/StatusIcons


func setup(entity: CombatEntity) -> void:
	_entity = entity
	_name_label.text = entity.entity_name
	_mp_container.visible = entity.is_player

	# Load portrait
	if entity.is_player and entity.character_data:
		_portrait.texture = entity.character_data.portrait
	elif not entity.is_player and entity.enemy_data:
		_portrait.texture = entity.enemy_data.sprite

	refresh()


func refresh() -> void:
	if not _entity:
		return

	# HP bar
	_hp_bar.max_value = _entity.max_hp
	_hp_bar.value = _entity.current_hp
	_hp_label.text = "%d/%d" % [_entity.current_hp, _entity.max_hp]

	# Color HP bar based on percentage
	var hp_pct: float = float(_entity.current_hp) / float(_entity.max_hp) if _entity.max_hp > 0 else 0.0
	if hp_pct > 0.5:
		_hp_bar.modulate = Constants.COLOR_HP_HIGH
	elif hp_pct > 0.25:
		_hp_bar.modulate = Constants.COLOR_HP_MID
	else:
		_hp_bar.modulate = Constants.COLOR_HP_LOW

	# MP bar
	if _entity.is_player:
		_mp_bar.max_value = _entity.max_mp
		_mp_bar.value = _entity.current_mp
		_mp_label.text = "%d/%d" % [_entity.current_mp, _entity.max_mp]
		_mp_bar.modulate = Constants.COLOR_MP

	# Dead state
	if _entity.is_dead:
		modulate = Constants.COLOR_DEAD
	else:
		modulate = Color.WHITE

	# Status effect icons
	_update_status_icons()


enum HighlightType {
	NONE,
	PRIMARY,    ## Direct hover target
	SECONDARY,  ## Affected by AOE
	INVALID,    ## Can't target
	ACTIVE_TURN,  ## Currently acting (gold border)
}

var _highlight_type: HighlightType = HighlightType.NONE


func highlight(active: bool) -> void:
	# Legacy support - defaults to PRIMARY highlight
	if active:
		set_highlight(HighlightType.PRIMARY)
	else:
		set_highlight(HighlightType.NONE)


func highlight_active_turn() -> void:
	## Highlights this entity bar with a gold border to show it's their turn
	set_highlight(HighlightType.ACTIVE_TURN)


func set_highlight(type: HighlightType) -> void:
	_highlight_type = type
	match type:
		HighlightType.PRIMARY:
			self_modulate = Constants.COLOR_HIGHLIGHT_ACTIVE
		HighlightType.SECONDARY:
			self_modulate = Constants.COLOR_HIGHLIGHT_HOVER
		HighlightType.INVALID:
			self_modulate = Constants.COLOR_HIGHLIGHT_TARGET
		HighlightType.ACTIVE_TURN:
			self_modulate = Color(1.0, 0.84, 0.0, 1.0)  # Gold
		_:
			self_modulate = Color.WHITE


func get_global_center() -> Vector2:
	return global_position + size / 2.0


func _update_status_icons() -> void:
	for child in _status_icons.get_children():
		child.queue_free()
	if not _entity:
		return

	# Regular status effects (text labels)
	for effect in _entity.status_effects:
		var data: StatusEffectData = effect.data
		var label: Label = Label.new()
		label.text = data.display_name.left(3)
		label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_TINY)
		label.tooltip_text = "%s (%d turns)" % [data.display_name, effect.remaining_turns]
		_status_icons.add_child(label)

	# Gem status effects — colored squares with stack count
	for gem_effect in _entity.active_gem_status_effects:
		if gem_effect.duration_turns <= 0:
			continue
		var bg_color: Color = _gem_status_color(gem_effect.effect_type)
		var short_name: String = _gem_status_name(gem_effect.effect_type)

		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = bg_color
		style.corner_radius_top_left = 3
		style.corner_radius_top_right = 3
		style.corner_radius_bottom_left = 3
		style.corner_radius_bottom_right = 3
		style.set_content_margin_all(2)
		panel.add_theme_stylebox_override("panel", style)
		panel.custom_minimum_size = Vector2(20, 20)
		panel.tooltip_text = "%s (%d stacks)" % [short_name, gem_effect.duration_turns]

		var count_label := Label.new()
		count_label.text = str(gem_effect.duration_turns)
		count_label.add_theme_font_size_override("font_size", 10)
		count_label.add_theme_color_override("font_color", Color.WHITE)
		count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		count_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		count_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
		panel.add_child(count_label)
		_status_icons.add_child(panel)


func _gem_status_color(effect_type: int) -> Color:
	match effect_type:
		Enums.StatusEffectType.BURN:     return Color(0.90, 0.20, 0.10)
		Enums.StatusEffectType.POISONED: return Color(0.15, 0.72, 0.20)
		Enums.StatusEffectType.CHILLED:  return Color(0.20, 0.55, 1.00)
		Enums.StatusEffectType.SHOCKED:  return Color(1.00, 0.85, 0.10)
	return Color(0.5, 0.5, 0.5)


func _gem_status_name(effect_type: int) -> String:
	match effect_type:
		Enums.StatusEffectType.BURN:     return "Burn"
		Enums.StatusEffectType.POISONED: return "Poison"
		Enums.StatusEffectType.CHILLED:  return "Chill"
		Enums.StatusEffectType.SHOCKED:  return "Shock"
	return "?"
