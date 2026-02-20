extends PanelContainer
## Scrollable list of items in the party's shared stash.

signal item_clicked(item: ItemData, index: int)
signal item_hovered(item: ItemData, global_pos: Vector2)
signal item_exited()
signal item_use_requested(item: ItemData, index: int)
signal background_clicked()

const StashSlotScene: PackedScene = preload("res://scenes/inventory/ui/stash_slot.tscn")

var _slots: Array = []
var _drop_highlighted: bool = false
var _label_prefix: String = "Stash"
var _show_max: bool = true
var _cached_stash: Array = []
var _cached_returnable: Dictionary = {}

# Filter state: which item types are visible
var _filter_active: Dictionary = {
	Enums.ItemType.ACTIVE_TOOL: true,
	Enums.ItemType.PASSIVE_GEAR: true,
	Enums.ItemType.MODIFIER: true,
	Enums.ItemType.CONSUMABLE: true,
	Enums.ItemType.MATERIAL: true,
}

@onready var _count_label: Label = $VBox/StashLabel
@onready var _item_list: VBoxContainer = $VBox/ScrollContainer/ItemList
@onready var _tools_btn: Button = $VBox/FilterGrid/ToolsBtn
@onready var _gear_btn: Button = $VBox/FilterGrid/GearBtn
@onready var _mods_btn: Button = $VBox/FilterGrid/ModsBtn
@onready var _cons_btn: Button = $VBox/FilterGrid/ConsBtn
@onready var _mat_btn: Button = $VBox/FilterGrid/MatBtn
@onready var _all_btn: Button = $VBox/FilterGrid/AllBtn


func _ready() -> void:
	# Connect filter button signals
	_tools_btn.toggled.connect(_on_filter_toggled.bind(Enums.ItemType.ACTIVE_TOOL))
	_gear_btn.toggled.connect(_on_filter_toggled.bind(Enums.ItemType.PASSIVE_GEAR))
	_mods_btn.toggled.connect(_on_filter_toggled.bind(Enums.ItemType.MODIFIER))
	_cons_btn.toggled.connect(_on_filter_toggled.bind(Enums.ItemType.CONSUMABLE))
	_mat_btn.toggled.connect(_on_filter_toggled.bind(Enums.ItemType.MATERIAL))
	_all_btn.pressed.connect(_on_all_filters)


func refresh(stash: Array, returnable_indices: Dictionary = {}) -> void:
	if not is_inside_tree():
		await ready

	# Cache stash data for re-filtering
	_cached_stash = stash
	_cached_returnable = returnable_indices

	# Clear existing slots
	for child in _item_list.get_children():
		child.queue_free()
	_slots.clear()

	# Build slots only for items matching active filters
	var visible_count: int = 0
	for i in range(stash.size()):
		var item: ItemData = stash[i]

		# Check if this item type is filtered
		if not _filter_active.get(item.item_type, true):
			continue

		visible_count += 1
		var is_returnable: bool = returnable_indices.has(i)
		var slot: PanelContainer = StashSlotScene.instantiate()
		_item_list.add_child(slot)
		slot.setup(item, i, is_returnable)
		slot.clicked.connect(_on_slot_clicked.bind(item))
		slot.hovered.connect(func(it: ItemData, pos: Vector2) -> void: item_hovered.emit(it, pos))
		slot.exited.connect(func() -> void: item_exited.emit())
		slot.use_requested.connect(_on_slot_use_requested.bind(item))
		_slots.append(slot)

	_update_count_label(visible_count, stash.size())


func highlight_drop_target(show: bool) -> void:
	_drop_highlighted = show
	if show:
		self_modulate = Color(0.3, 0.8, 0.3, 1.0)
	else:
		self_modulate = Color.WHITE


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _on_slot_clicked(index: int, item: ItemData) -> void:
	# Slot emits (index, item) but we re-emit as (item, index) for consistency with other signals
	item_clicked.emit(item, index)


func _on_slot_use_requested(index: int, item: ItemData) -> void:
	# Slot emits (index, item) but we re-emit as (item, index) for consistency with other signals
	item_use_requested.emit(item, index)


func _gui_input(event: InputEvent) -> void:
	# Detect clicks on background (not handled by slots)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		background_clicked.emit()


func set_label_prefix(prefix: String, show_max: bool = true) -> void:
	_label_prefix = prefix
	_show_max = show_max


func _update_count_label(visible_count: int, total_count: int = -1) -> void:
	if _count_label:
		if total_count < 0:
			total_count = visible_count

		if _show_max:
			if visible_count < total_count:
				_count_label.text = "%s (%d/%d showing %d)" % [_label_prefix, total_count, Constants.MAX_STASH_SLOTS, visible_count]
			else:
				_count_label.text = "%s (%d/%d)" % [_label_prefix, total_count, Constants.MAX_STASH_SLOTS]
		else:
			if visible_count < total_count:
				_count_label.text = "%s (%d showing %d)" % [_label_prefix, total_count, visible_count]
			else:
				_count_label.text = "%s (%d)" % [_label_prefix, total_count]


func _on_filter_toggled(button_pressed: bool, item_type: Enums.ItemType) -> void:
	_filter_active[item_type] = button_pressed
	# Re-apply filters with cached data
	refresh(_cached_stash, _cached_returnable)


func _on_all_filters() -> void:
	# Enable all filters
	_filter_active[Enums.ItemType.ACTIVE_TOOL] = true
	_filter_active[Enums.ItemType.PASSIVE_GEAR] = true
	_filter_active[Enums.ItemType.MODIFIER] = true
	_filter_active[Enums.ItemType.CONSUMABLE] = true
	_filter_active[Enums.ItemType.MATERIAL] = true

	# Update button states
	_tools_btn.button_pressed = true
	_gear_btn.button_pressed = true
	_mods_btn.button_pressed = true
	_cons_btn.button_pressed = true
	_mat_btn.button_pressed = true

	# Re-apply filters
	refresh(_cached_stash, _cached_returnable)
