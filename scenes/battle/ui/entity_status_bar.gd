extends PanelContainer
## Displays HP/MP bars and status icons for a single combat entity.

var _entity: CombatEntity

@onready var _name_label: Label = $VBox/NameLabel
@onready var _hp_bar: ProgressBar = $VBox/HPBar
@onready var _hp_label: Label = $VBox/HPBar/HPLabel
@onready var _mp_bar: ProgressBar = $VBox/MPBar
@onready var _mp_label: Label = $VBox/MPBar/MPLabel
@onready var _status_icons: HBoxContainer = $VBox/StatusIcons


func setup(entity: CombatEntity) -> void:
	_entity = entity
	_name_label.text = entity.entity_name
	_mp_bar.visible = entity.is_player
	_mp_label.visible = entity.is_player
	refresh()


func refresh() -> void:
	if not _entity:
		return

	# HP bar
	_hp_bar.max_value = _entity.max_hp
	_hp_bar.value = _entity.current_hp
	_hp_label.text = "%d / %d" % [_entity.current_hp, _entity.max_hp]

	# Color HP bar based on percentage
	var hp_pct: float = float(_entity.current_hp) / float(_entity.max_hp)
	if hp_pct > 0.5:
		_hp_bar.modulate = Color(0.3, 0.9, 0.3)
	elif hp_pct > 0.25:
		_hp_bar.modulate = Color(0.9, 0.7, 0.2)
	else:
		_hp_bar.modulate = Color(0.9, 0.2, 0.2)

	# MP bar
	if _entity.is_player:
		_mp_bar.max_value = _entity.max_mp
		_mp_bar.value = _entity.current_mp
		_mp_label.text = "%d / %d" % [_entity.current_mp, _entity.max_mp]

	# Dead state
	if _entity.is_dead:
		modulate = Color(0.5, 0.5, 0.5, 0.6)
	else:
		modulate = Color.WHITE

	# Status effect icons
	_update_status_icons()


func highlight(active: bool) -> void:
	if active:
		self_modulate = Color(1.2, 1.2, 0.8)
	else:
		self_modulate = Color.WHITE


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
