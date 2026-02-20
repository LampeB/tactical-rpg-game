extends PanelContainer
## Tooltip popup showing item details on hover.

@onready var _name_label: Label = $Margin/VBox/NameLabel
@onready var _rarity_label: Label = $Margin/VBox/RarityLabel
@onready var _type_label: Label = $Margin/VBox/TypeLabel
@onready var _stats_container: VBoxContainer = $Margin/VBox/StatsContainer
@onready var _modifier_section: VBoxContainer = $Margin/VBox/ModifierSection
@onready var _modifier_list: VBoxContainer = $Margin/VBox/ModifierSection/ModifierList
@onready var _description_label: Label = $Margin/VBox/DescriptionLabel


func show_for_item(item: ItemData, placed: GridInventory.PlacedItem = null, grid_inv: GridInventory = null, screen_pos: Vector2 = Vector2.ZERO) -> void:
	# Name with rarity color
	_name_label.text = item.display_name
	var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
	_name_label.add_theme_color_override("font_color", rarity_color)

	# Rarity
	_rarity_label.text = Constants.RARITY_NAMES.get(item.rarity, "Common")
	_rarity_label.add_theme_color_override("font_color", rarity_color)

	# Type
	_type_label.text = _get_type_text(item.item_type)

	# Stats
	_clear_container(_stats_container)
	for mod in item.stat_modifiers:
		if mod is StatModifier:
			var label: Label = Label.new()
			label.text = mod.get_description()
			label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
			_stats_container.add_child(label)

	if item.base_power > 0:
		var power_label: Label = Label.new()
		power_label.text = "Power: %d" % item.base_power
		power_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
		_stats_container.add_child(power_label)

	# Modifier bonuses (for gems, show what they grant; for tools, show active gem bonuses)
	_modifier_section.visible = false
	_clear_container(_modifier_list)

	if item.item_type == Enums.ItemType.MODIFIER and not item.modifier_bonuses.is_empty():
		_modifier_section.visible = true
		for mod in item.modifier_bonuses:
			if mod is StatModifier:
				var label: Label = Label.new()
				label.text = mod.get_description()
				label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
				label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
				_modifier_list.add_child(label)

	elif item.item_type == Enums.ItemType.ACTIVE_TOOL and placed and grid_inv:
		var modifiers: Array = grid_inv.get_modifiers_affecting(placed)
		if not modifiers.is_empty():
			_modifier_section.visible = true
			for i in range(modifiers.size()):
				var gem_placed: GridInventory.PlacedItem = modifiers[i]
				for gem_mod in gem_placed.item_data.modifier_bonuses:
					if gem_mod is StatModifier:
						var label: Label = Label.new()
						label.text = "%s (from %s)" % [gem_mod.get_description(), gem_placed.item_data.display_name]
						label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_DETAIL)
						label.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
						_modifier_list.add_child(label)

	# Description
	_description_label.text = item.description
	_description_label.visible = not item.description.is_empty()

	# Position near mouse, clamped to viewport
	_position_at(screen_pos)
	visible = true


func hide_tooltip() -> void:
	visible = false


func _position_at(screen_pos: Vector2) -> void:
	# Wait one frame for size to update, then clamp
	await get_tree().process_frame
	var viewport_size: Vector2 = get_viewport_rect().size
	var tooltip_size: Vector2 = size
	var pos: Vector2 = screen_pos + Vector2(16, 16)  # Offset from cursor
	pos.x = minf(pos.x, viewport_size.x - tooltip_size.x - 8)
	pos.y = minf(pos.y, viewport_size.y - tooltip_size.y - 8)
	pos.x = maxf(pos.x, 8)
	pos.y = maxf(pos.y, 8)
	global_position = pos


func _get_type_text(item_type: Enums.ItemType) -> String:
	match item_type:
		Enums.ItemType.ACTIVE_TOOL: return "Active Tool"
		Enums.ItemType.PASSIVE_GEAR: return "Passive Gear"
		Enums.ItemType.MODIFIER: return "Modifier"
		Enums.ItemType.CONSUMABLE: return "Consumable"
		Enums.ItemType.MATERIAL: return "Material"
	return ""


func _clear_container(container: VBoxContainer) -> void:
	for child in container.get_children():
		child.queue_free()
