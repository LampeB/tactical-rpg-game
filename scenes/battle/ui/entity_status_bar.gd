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
		_hp_bar.modulate = Color(0.4, 1.0, 0.4)
	elif hp_pct > 0.25:
		_hp_bar.modulate = Color(1.0, 0.8, 0.2)
	else:
		_hp_bar.modulate = Color(1.0, 0.3, 0.3)

	# MP bar
	if _entity.is_player:
		_mp_bar.max_value = _entity.max_mp
		_mp_bar.value = _entity.current_mp
		_mp_label.text = "%d/%d" % [_entity.current_mp, _entity.max_mp]
		_mp_bar.modulate = Color(0.4, 0.6, 1.0)

	# Dead state
	if _entity.is_dead:
		modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		modulate = Color.WHITE

	# Status effect icons
	_update_status_icons()


enum HighlightType {
	NONE,
	PRIMARY,    ## Direct hover target
	SECONDARY,  ## Affected by AOE
	INVALID,    ## Can't target
}

var _highlight_type: HighlightType = HighlightType.NONE


func highlight(active: bool) -> void:
	# Legacy support - defaults to PRIMARY highlight
	if active:
		set_highlight(HighlightType.PRIMARY)
	else:
		set_highlight(HighlightType.NONE)


func set_highlight(type: HighlightType) -> void:
	_highlight_type = type
	match type:
		HighlightType.PRIMARY:
			self_modulate = Color(1.3, 1.3, 0.9)  ## Bright yellow
		HighlightType.SECONDARY:
			self_modulate = Color(1.15, 1.15, 1.0)  ## Subtle highlight
		HighlightType.INVALID:
			self_modulate = Color(1.2, 0.8, 0.8)  ## Red tint
		_:
			self_modulate = Color.WHITE


func get_highlight_type() -> HighlightType:
	return _highlight_type


func get_entity() -> CombatEntity:
	return _entity


func get_global_center() -> Vector2:
	return global_position + size / 2.0


func _update_status_icons() -> void:
	for child in _status_icons.get_children():
		child.queue_free()
	if not _entity:
		return
	for effect in _entity.status_effects:
		var data: StatusEffectData = effect.data
		var label: Label = Label.new()
		label.text = data.display_name.left(3)
		label.add_theme_font_size_override("font_size", 10)
		label.tooltip_text = "%s (%d turns)" % [data.display_name, effect.remaining_turns]
		_status_icons.add_child(label)
