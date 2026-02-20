extends PanelContainer
## Scrollable list of items in the party's shared stash.

signal item_clicked(item: ItemData, index: int)
signal item_hovered(item: ItemData, global_pos: Vector2)
signal item_exited()
signal item_use_requested(item: ItemData, index: int)

const StashSlotScene: PackedScene = preload("res://scenes/inventory/ui/stash_slot.tscn")

var _slots: Array = []
var _drop_highlighted: bool = false
var _label_prefix: String = "Stash"
var _show_max: bool = true

@onready var _count_label: Label = $VBox/StashLabel
@onready var _item_list: VBoxContainer = $VBox/ScrollContainer/ItemList


func refresh(stash: Array) -> void:
	if not is_inside_tree():
		await ready
	# Clear existing slots
	for child in _item_list.get_children():
		child.queue_free()
	_slots.clear()

	# Build new slots
	for i in range(stash.size()):
		var item: ItemData = stash[i]
		var slot: PanelContainer = StashSlotScene.instantiate()
		_item_list.add_child(slot)
		slot.setup(item, i)
		slot.clicked.connect(_on_slot_clicked.bind(item))
		slot.hovered.connect(func(it: ItemData, pos: Vector2) -> void: item_hovered.emit(it, pos))
		slot.exited.connect(func() -> void: item_exited.emit())
		slot.use_requested.connect(_on_slot_use_requested.bind(item))
		_slots.append(slot)

	_update_count_label(stash.size())


func highlight_drop_target(show: bool) -> void:
	_drop_highlighted = show
	if show:
		self_modulate = Color(0.3, 0.8, 0.3, 1.0)
	else:
		self_modulate = Color.WHITE


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _on_slot_clicked(index: int, item: ItemData) -> void:
	item_clicked.emit(item, index)


func _on_slot_use_requested(index: int, item: ItemData) -> void:
	item_use_requested.emit(item, index)


func set_label_prefix(prefix: String, show_max: bool = true) -> void:
	_label_prefix = prefix
	_show_max = show_max


func _update_count_label(count: int) -> void:
	if _count_label:
		if _show_max:
			_count_label.text = "%s (%d/%d)" % [_label_prefix, count, Constants.MAX_STASH_SLOTS]
		else:
			_count_label.text = "%s (%d)" % [_label_prefix, count]
