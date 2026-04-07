extends PanelContainer
## Scrollable list of items in the party's shared stash.

signal item_clicked(item: ItemData, index: int)
signal item_hovered(item: ItemData, global_pos: Vector2)
signal item_exited()
signal item_use_requested(item: ItemData, index: int)
signal item_discard_requested(item: ItemData, index: int)
signal background_clicked()

const StashSlotScene: PackedScene = preload("res://scenes/inventory/ui/stash_slot.tscn")

enum SortKey { NONE, NAME, TYPE, RARITY }

## Session-persistent sort state shared across all StashPanel instances.
static var _sort_primary: SortKey = SortKey.NONE
static var _sort_ascending: bool = true

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
@onready var _name_sort_btn: Button = $VBox/SortBar/NameSortBtn
@onready var _type_sort_btn: Button = $VBox/SortBar/TypeSortBtn
@onready var _rarity_sort_btn: Button = $VBox/SortBar/RaritySortBtn


func _ready() -> void:
	# Swap normal/pressed styleboxes on filter buttons (selected = visually pressed)
	_invert_button_styles(_tools_btn)
	_invert_button_styles(_gear_btn)
	_invert_button_styles(_mods_btn)
	_invert_button_styles(_cons_btn)
	_invert_button_styles(_mat_btn)
	_invert_button_styles(_all_btn)

	# Connect filter button signals (left-click solos via pressed, right-click toggles via gui_input)
	_tools_btn.pressed.connect(_on_filter_solo.bind(Enums.ItemType.ACTIVE_TOOL))
	_gear_btn.pressed.connect(_on_filter_solo.bind(Enums.ItemType.PASSIVE_GEAR))
	_mods_btn.pressed.connect(_on_filter_solo.bind(Enums.ItemType.MODIFIER))
	_cons_btn.pressed.connect(_on_filter_solo.bind(Enums.ItemType.CONSUMABLE))
	_mat_btn.pressed.connect(_on_filter_solo.bind(Enums.ItemType.MATERIAL))
	_tools_btn.gui_input.connect(_on_filter_input.bind(Enums.ItemType.ACTIVE_TOOL, _tools_btn))
	_gear_btn.gui_input.connect(_on_filter_input.bind(Enums.ItemType.PASSIVE_GEAR, _gear_btn))
	_mods_btn.gui_input.connect(_on_filter_input.bind(Enums.ItemType.MODIFIER, _mods_btn))
	_cons_btn.gui_input.connect(_on_filter_input.bind(Enums.ItemType.CONSUMABLE, _cons_btn))
	_mat_btn.gui_input.connect(_on_filter_input.bind(Enums.ItemType.MATERIAL, _mat_btn))
	_all_btn.pressed.connect(_on_all_pressed)


	# Connect sort button signals
	_name_sort_btn.pressed.connect(_on_sort_pressed.bind(SortKey.NAME))
	_type_sort_btn.pressed.connect(_on_sort_pressed.bind(SortKey.TYPE))
	_rarity_sort_btn.pressed.connect(_on_sort_pressed.bind(SortKey.RARITY))
	_update_sort_button_states()


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

	# Build indexed list, applying filters
	var indexed: Array = []
	for i in range(stash.size()):
		var item: ItemData = stash[i]
		if not _filter_active.get(item.item_type, true):
			continue
		indexed.append({"item": item, "index": i})

	# Sort if a sort key is active
	if _sort_primary != SortKey.NONE:
		indexed.sort_custom(_compare_items)

	# Create slot nodes
	var visible_count: int = indexed.size()
	for entry in indexed:
		var item: ItemData = entry.item
		var original_index: int = entry.index
		var is_returnable: bool = returnable_indices.has(original_index)
		var slot: PanelContainer = StashSlotScene.instantiate()
		_item_list.add_child(slot)
		slot.setup(item, original_index, is_returnable)
		slot.clicked.connect(_on_slot_clicked.bind(item))
		slot.hovered.connect(func(it: ItemData, pos: Vector2) -> void: item_hovered.emit(it, pos))
		slot.exited.connect(func() -> void: item_exited.emit())
		slot.use_requested.connect(_on_slot_use_requested.bind(item))
		slot.discard_requested.connect(_on_slot_discard_requested.bind(item))
		_slots.append(slot)

	_update_count_label(visible_count, stash.size())


func highlight_displaced_item(stash_index: int) -> void:
	## Highlights a specific stash slot to show it was just displaced from the inventory.
	for slot in _slots:
		if slot.index == stash_index:
			slot.modulate = Color(1.0, 0.85, 0.3, 1.0)  # Gold highlight
			break


func clear_displaced_highlights() -> void:
	## Removes displaced item highlights from all stash slots.
	for slot in _slots:
		slot.modulate = Color.WHITE


func highlight_drop_target(highlighted: bool) -> void:
	_drop_highlighted = highlighted
	if highlighted:
		self_modulate = Color(0.3, 0.8, 0.3, 1.0)
	else:
		self_modulate = Color.WHITE


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func _on_slot_clicked(index: int, item: ItemData) -> void:
	item_clicked.emit(item, index)


func _on_slot_use_requested(index: int, item: ItemData) -> void:
	item_use_requested.emit(item, index)


func _on_slot_discard_requested(index: int, item: ItemData) -> void:
	item_discard_requested.emit(item, index)


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

		if _show_max and total_count >= Constants.MAX_STASH_SLOTS:
			_count_label.add_theme_color_override("font_color", Constants.COLOR_DAMAGE)
		else:
			_count_label.remove_theme_color_override("font_color")


# ════════════════════════════════════════════════════════════════════════════
#  Sorting
# ════════════════════════════════════════════════════════════════════════════

func _on_sort_pressed(key: SortKey) -> void:
	if _sort_primary == key:
		_sort_ascending = not _sort_ascending
	else:
		_sort_primary = key
		_sort_ascending = true
	_update_sort_button_states()
	refresh(_cached_stash, _cached_returnable)


func _update_sort_button_states() -> void:
	_name_sort_btn.set_pressed_no_signal(_sort_primary == SortKey.NAME)
	_type_sort_btn.set_pressed_no_signal(_sort_primary == SortKey.TYPE)
	_rarity_sort_btn.set_pressed_no_signal(_sort_primary == SortKey.RARITY)

	var arrow: String = " ▲" if _sort_ascending else " ▼"
	_name_sort_btn.text = "Name" + (arrow if _sort_primary == SortKey.NAME else "")
	_type_sort_btn.text = "Type" + (arrow if _sort_primary == SortKey.TYPE else "")
	_rarity_sort_btn.text = "Rarity" + (arrow if _sort_primary == SortKey.RARITY else "")


func _compare_items(a: Dictionary, b: Dictionary) -> bool:
	var item_a: ItemData = a.item
	var item_b: ItemData = b.item
	var result: int = _compare_by_key(item_a, item_b, _sort_primary)
	if result == 0:
		# Secondary tiebreakers
		match _sort_primary:
			SortKey.TYPE:
				# Same item_type → group by sub-category (sword/staff/helmet/etc.)
				result = int(item_a.category) - int(item_b.category)
				if result == 0:
					result = int(item_b.rarity) - int(item_a.rarity)
				if result == 0:
					result = item_a.display_name.naturalnocasecmp_to(item_b.display_name)
			SortKey.RARITY:
				result = item_a.display_name.naturalnocasecmp_to(item_b.display_name)
			SortKey.NAME:
				result = int(item_a.item_type) - int(item_b.item_type)
	if not _sort_ascending:
		return result > 0
	return result < 0


func _compare_by_key(a: ItemData, b: ItemData, key: SortKey) -> int:
	match key:
		SortKey.NAME:
			return a.display_name.naturalnocasecmp_to(b.display_name)
		SortKey.TYPE:
			return int(a.item_type) - int(b.item_type)
		SortKey.RARITY:
			return int(a.rarity) - int(b.rarity)
	return 0


# ════════════════════════════════════════════════════════════════════════════
#  Filtering
# ════════════════════════════════════════════════════════════════════════════

func _on_filter_solo(item_type: Enums.ItemType) -> void:
	# Left click: solo this filter
	for type in _filter_active.keys():
		_filter_active[type] = (type == item_type)
	_sync_filter_buttons()
	refresh(_cached_stash, _cached_returnable)


func _on_filter_input(event: InputEvent, item_type: Enums.ItemType, btn: Button) -> void:
	# Right click: toggle this filter independently
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
		return
	var new_state: bool = not _filter_active[item_type]
	# Don't allow turning off the last active filter
	if not new_state:
		var active_count: int = 0
		for type in _filter_active:
			if _filter_active[type]:
				active_count += 1
		if active_count <= 1:
			return
	_filter_active[item_type] = new_state
	_sync_filter_buttons()
	refresh(_cached_stash, _cached_returnable)
	btn.accept_event()


func _on_all_pressed() -> void:
	# Activate all filters
	for type in _filter_active.keys():
		_filter_active[type] = true
	_sync_filter_buttons()
	refresh(_cached_stash, _cached_returnable)


func _sync_filter_buttons() -> void:
	_tools_btn.set_pressed_no_signal(_filter_active[Enums.ItemType.ACTIVE_TOOL])
	_gear_btn.set_pressed_no_signal(_filter_active[Enums.ItemType.PASSIVE_GEAR])
	_mods_btn.set_pressed_no_signal(_filter_active[Enums.ItemType.MODIFIER])
	_cons_btn.set_pressed_no_signal(_filter_active[Enums.ItemType.CONSUMABLE])
	_mat_btn.set_pressed_no_signal(_filter_active[Enums.ItemType.MATERIAL])
	var all_active: bool = true
	for type in _filter_active:
		if not _filter_active[type]:
			all_active = false
			break
	_all_btn.set_pressed_no_signal(all_active)


func _invert_button_styles(btn: Button) -> void:
	## Swaps the normal and pressed styleboxes from the global theme.
	var normal: StyleBox = btn.get_theme_stylebox("normal", "Button")
	var pressed: StyleBox = btn.get_theme_stylebox("pressed", "Button")
	if normal and pressed:
		btn.add_theme_stylebox_override("normal", pressed)
		btn.add_theme_stylebox_override("pressed", normal)
		btn.add_theme_stylebox_override("hover", pressed)


# ════════════════════════════════════════════════════════════════════════════
#  Upgrade Highlights
# ════════════════════════════════════════════════════════════════════════════

func highlight_upgradeable_items(dragged_item: ItemData) -> void:
	## Highlights stash items that can be upgraded with the dragged item
	if not dragged_item:
		clear_upgradeable_highlights()
		return

	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		if slot.has_method("set_upgradeable_highlight"):
			var can_upgrade: bool = ItemUpgradeSystem.can_upgrade(dragged_item, slot.item_data)
			slot.set_upgradeable_highlight(can_upgrade)


func clear_upgradeable_highlights() -> void:
	## Clears all upgradeable highlights from stash slots
	for i in range(_slots.size()):
		var slot: PanelContainer = _slots[i]
		if slot.has_method("set_upgradeable_highlight"):
			slot.set_upgradeable_highlight(false)


func highlight_matching_ingredient(ingredient: CraftingIngredient) -> void:
	## Highlights stash items that match a crafting ingredient (cyan tint).
	if not ingredient:
		clear_ingredient_highlights()
		return
	for slot in _slots:
		if slot.has_method("set_ingredient_highlight"):
			var matches: bool = CraftingSystem.item_matches(slot.item_data, ingredient)
			slot.set_ingredient_highlight(matches)


func clear_ingredient_highlights() -> void:
	## Clears all ingredient highlights from stash slots.
	for slot in _slots:
		if slot.has_method("set_ingredient_highlight"):
			slot.set_ingredient_highlight(false)
