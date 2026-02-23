extends Control
## In-game item editor. Create, edit, and save ItemData resources.
## Accessible from the main menu — no game session required.

const RARITY_SUFFIXES: Array[String] = [
	"_common", "_uncommon", "_rare", "_elite", "_legendary", "_unique",
]

const TYPE_SECTION_NAMES: Dictionary = {
	Enums.ItemType.ACTIVE_TOOL: "Weapons",
	Enums.ItemType.PASSIVE_GEAR: "Armor",
	Enums.ItemType.MODIFIER: "Modifiers",
	Enums.ItemType.CONSUMABLE: "Consumables",
	Enums.ItemType.MATERIAL: "Materials",
}

# === Cached resource lists (loaded once) ===
var _shapes: Array = []        # Array of ItemShape
var _shape_paths: Array = []   # Matching res:// paths
var _skills: Array = []        # Array of SkillData
var _skill_paths: Array = []   # Matching res:// paths
var _status_effects: Array = []
var _status_effect_paths: Array = []
var _icon_paths: Array = []
var _icon_textures: Array = []

# === Item data ===
var _items: Dictionary = {}    # id -> ItemData (working copies)
var _selected_id: String = ""
var _dirty_ids: Dictionary = {}
var _expanded_families: Dictionary = {}  # family_key -> bool (collapsed state)
var _editing_shape: bool = false  # true when inline shape editor is open

# === Node references ===
@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _save_btn: Button = $VBox/TopBar/SaveButton
@onready var _save_all_btn: Button = $VBox/TopBar/SaveAllButton
@onready var _status_label: Label = $VBox/TopBar/StatusLabel
@onready var _title_label: Label = $VBox/TopBar/Title
@onready var _search_edit: LineEdit = $VBox/Content/ListPanel/ListVBox/FilterRow/SearchEdit
@onready var _type_filter: OptionButton = $VBox/Content/ListPanel/ListVBox/FilterRow/TypeFilter
@onready var _item_list_vbox: VBoxContainer = $VBox/Content/ListPanel/ListVBox/ItemListScroll/ItemListVBox
@onready var _new_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/NewButton
@onready var _duplicate_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/DuplicateButton
@onready var _delete_btn: Button = $VBox/Content/ListPanel/ListVBox/ListButtons/DeleteButton
@onready var _property_vbox: VBoxContainer = $VBox/Content/PropertyPanel/PropertyScroll/PropertyVBox
@onready var _hint_bar: Label = $VBox/HintBar


func _ready() -> void:
	_title_label.add_theme_font_size_override("font_size", Constants.FONT_SIZE_HEADER)

	_back_btn.pressed.connect(_on_back)
	_save_btn.pressed.connect(_on_save_item)
	_save_all_btn.pressed.connect(_on_save_all)
	_new_btn.pressed.connect(_on_new_item)
	_duplicate_btn.pressed.connect(_on_duplicate_item)
	_delete_btn.pressed.connect(_on_delete_item)
	_search_edit.text_changed.connect(func(_t: String) -> void: _rebuild_item_list())
	_type_filter.item_selected.connect(func(_i: int) -> void: _rebuild_item_list())

	_type_filter.add_item("All", 0)
	var type_keys: PackedStringArray = Enums.ItemType.keys()
	for i in range(type_keys.size()):
		_type_filter.add_item(type_keys[i].capitalize().replace("_", " "), i + 1)

	_load_shapes()
	_load_skills()
	_load_status_effects()
	_load_icons()

	for item in ItemDatabase.get_all_items():
		var copy: ItemData = item.duplicate(true) as ItemData
		_items[copy.id] = copy

	_rebuild_item_list()
	_clear_property_panel()
	_update_hint_bar()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_S and event.ctrl_pressed:
			_on_save_item()
			get_viewport().set_input_as_handled()
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


# =========================================================================
# Resource scanning
# =========================================================================

func _load_shapes() -> void:
	_scan_resources("res://data/shapes/", func(res: Resource, path: String) -> void:
		if res is ItemShape:
			_shapes.append(res)
			_shape_paths.append(path)
	)

func _load_skills() -> void:
	_scan_resources("res://data/skills/", func(res: Resource, path: String) -> void:
		if res is SkillData:
			_skills.append(res)
			_skill_paths.append(path)
	)

func _load_status_effects() -> void:
	_scan_resources("res://data/status_effects/", func(res: Resource, path: String) -> void:
		if res is StatusEffect:
			_status_effects.append(res)
			_status_effect_paths.append(path)
	)

func _load_icons() -> void:
	var dir := DirAccess.open("res://assets/sprites/items/")
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".png"):
			var path := "res://assets/sprites/items/" + file_name
			var tex := load(path) as Texture2D
			if tex:
				_icon_paths.append(path)
				_icon_textures.append(tex)
		file_name = dir.get_next()
	dir.list_dir_end()

func _scan_resources(dir_path: String, callback: Callable) -> void:
	var dir := DirAccess.open(dir_path)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var full_path := dir_path + file_name
			var res := load(full_path)
			if res:
				callback.call(res, full_path)
		file_name = dir.get_next()
	dir.list_dir_end()


# =========================================================================
# Family grouping
# =========================================================================

## Extract the family name from an item ID by stripping rarity suffixes.
## e.g. "fire_gem_common" → "fire_gem", "megummy_gem" → "megummy_gem"
func _get_family(item_id: String) -> String:
	for suffix in RARITY_SUFFIXES:
		if item_id.ends_with(suffix):
			return item_id.substr(0, item_id.length() - suffix.length())
	return item_id


## Build a grouped structure: { item_type: { family_name: [ItemData, ...] } }
func _build_grouped_items() -> Dictionary:
	var grouped: Dictionary = {}
	for item in _items.values():
		if not grouped.has(item.item_type):
			grouped[item.item_type] = {}
		var family: String = _get_family(item.id)
		if not grouped[item.item_type].has(family):
			grouped[item.item_type][family] = []
		grouped[item.item_type][family].append(item)

	# Sort variants within each family by rarity
	for type_dict in grouped.values():
		for family_items in type_dict.values():
			family_items.sort_custom(func(a: ItemData, b: ItemData) -> bool:
				return a.rarity < b.rarity
			)
	return grouped


# =========================================================================
# Item List — grouped by type & family
# =========================================================================

func _rebuild_item_list() -> void:
	for child in _item_list_vbox.get_children():
		child.queue_free()

	var search_text: String = _search_edit.text.strip_edges().to_lower()
	var type_idx: int = _type_filter.selected
	var grouped: Dictionary = _build_grouped_items()

	# Iterate types in defined order
	var type_order: Array = [
		Enums.ItemType.ACTIVE_TOOL,
		Enums.ItemType.PASSIVE_GEAR,
		Enums.ItemType.MODIFIER,
		Enums.ItemType.CONSUMABLE,
		Enums.ItemType.MATERIAL,
	]

	for item_type in type_order:
		if type_idx > 0 and item_type != (type_idx - 1):
			continue
		if not grouped.has(item_type):
			continue

		var families: Dictionary = grouped[item_type]

		# Collect families that pass the search filter
		var visible_families: Array = []
		for family_name in families.keys():
			var family_items: Array = families[family_name]
			var any_match: bool = false
			for item in family_items:
				if search_text.is_empty() or search_text in item.display_name.to_lower() or search_text in item.id.to_lower():
					any_match = true
					break
			if any_match:
				visible_families.append(family_name)

		if visible_families.is_empty():
			continue

		visible_families.sort()

		# Type section header
		var section_label := Label.new()
		section_label.text = TYPE_SECTION_NAMES.get(item_type, "Other")
		section_label.add_theme_font_size_override("font_size", 15)
		section_label.add_theme_color_override("font_color", Color(0.7, 0.85, 1.0))
		_item_list_vbox.add_child(section_label)

		for family_name in visible_families:
			var family_items: Array = families[family_name]
			# Filter items within family by search
			var filtered_items: Array = []
			for item in family_items:
				if search_text.is_empty() or search_text in item.display_name.to_lower() or search_text in item.id.to_lower():
					filtered_items.append(item)

			if filtered_items.is_empty():
				continue

			var family_key: String = "%d_%s" % [item_type, family_name]
			var is_expanded: bool = _expanded_families.get(family_key, false)

			# Check if selected item is in this family
			var selected_in_family: bool = false
			for item in filtered_items:
				if item.id == _selected_id:
					selected_in_family = true
					break

			# Auto-expand if selection is inside
			if selected_in_family:
				is_expanded = true
				_expanded_families[family_key] = true

			# Family header button
			var first_item: ItemData = filtered_items[0]
			var family_display: String = first_item.display_name
			# If multiple variants, show the family base name
			if filtered_items.size() > 1:
				family_display = family_name.replace("_", " ").capitalize()
			var arrow: String = "v " if is_expanded else "> "
			var family_btn := Button.new()
			family_btn.text = "%s%s  (%d)" % [arrow, family_display, filtered_items.size()]
			family_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
			family_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			family_btn.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
			var captured_key: String = family_key
			# Single item family: click selects directly
			if filtered_items.size() == 1:
				var single_id: String = filtered_items[0].id
				family_btn.text = "  %s" % filtered_items[0].display_name
				var rarity_color: Color = Constants.RARITY_COLORS.get(filtered_items[0].rarity, Color.WHITE)
				family_btn.add_theme_color_override("font_color", rarity_color)
				if single_id == _selected_id:
					family_btn.add_theme_color_override("font_color", Color.WHITE)
					family_btn.add_theme_stylebox_override("normal", _make_selected_stylebox())
				family_btn.pressed.connect(func() -> void: _select_item(single_id))
			else:
				family_btn.pressed.connect(func() -> void:
					_expanded_families[captured_key] = not _expanded_families.get(captured_key, false)
					_rebuild_item_list()
				)
			_item_list_vbox.add_child(family_btn)

			# Expanded: show rarity variants
			if is_expanded and filtered_items.size() > 1:
				for item in filtered_items:
					var variant_btn := Button.new()
					var rarity_name: String = Enums.Rarity.keys()[item.rarity].capitalize()
					variant_btn.text = "    %s [%s]" % [item.display_name, rarity_name]
					variant_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
					variant_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					var rarity_color: Color = Constants.RARITY_COLORS.get(item.rarity, Color.WHITE)
					variant_btn.add_theme_color_override("font_color", rarity_color)
					if item.id == _selected_id:
						variant_btn.add_theme_color_override("font_color", Color.WHITE)
						variant_btn.add_theme_stylebox_override("normal", _make_selected_stylebox())
					var captured_id: String = item.id
					variant_btn.pressed.connect(func() -> void: _select_item(captured_id))
					_item_list_vbox.add_child(variant_btn)

		# Separator between type sections
		var sep := HSeparator.new()
		sep.add_theme_constant_override("separation", 4)
		_item_list_vbox.add_child(sep)


func _make_selected_stylebox() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.3, 0.4, 0.6, 0.6)
	sb.set_corner_radius_all(4)
	return sb


func _select_item(item_id: String) -> void:
	_selected_id = item_id
	_editing_shape = false
	_rebuild_item_list()
	var item: ItemData = _items.get(item_id)
	if item:
		_build_property_panel(item)
	else:
		_clear_property_panel()
	_update_hint_bar()


# =========================================================================
# Item CRUD
# =========================================================================

func _on_new_item() -> void:
	var new_id: String = "new_item_%d" % Time.get_ticks_msec()
	var item := ItemData.new()
	item.id = new_id
	item.display_name = "New Item"
	item.item_type = Enums.ItemType.ACTIVE_TOOL
	item.rarity = Enums.Rarity.COMMON
	item.base_price = 10
	if _shapes.size() > 0:
		item.shape = _shapes[0]
	_items[new_id] = item
	_dirty_ids[new_id] = true
	_select_item(new_id)
	_update_hint_bar()


func _on_duplicate_item() -> void:
	if _selected_id.is_empty():
		return
	var source: ItemData = _items.get(_selected_id)
	if not source:
		return
	var copy: ItemData = source.duplicate(true) as ItemData
	copy.id = source.id + "_copy"
	while _items.has(copy.id):
		copy.id += "_"
	_items[copy.id] = copy
	_dirty_ids[copy.id] = true
	_select_item(copy.id)
	_update_hint_bar()


func _on_delete_item() -> void:
	if _selected_id.is_empty():
		return
	_items.erase(_selected_id)
	_dirty_ids.erase(_selected_id)
	_selected_id = ""
	_rebuild_item_list()
	_clear_property_panel()
	_update_hint_bar()


# =========================================================================
# Save
# =========================================================================

func _get_item_directory(item: ItemData) -> String:
	match item.item_type:
		Enums.ItemType.ACTIVE_TOOL:
			return "res://data/items/weapons/"
		Enums.ItemType.PASSIVE_GEAR:
			return "res://data/items/armor/"
		Enums.ItemType.MODIFIER:
			return "res://data/items/modifiers/"
		Enums.ItemType.CONSUMABLE:
			return "res://data/items/consumables/"
		Enums.ItemType.MATERIAL:
			return "res://data/items/materials/"
		_:
			return "res://data/items/weapons/"


func _save_single_item(item: ItemData) -> bool:
	var dir_path: String = _get_item_directory(item)
	DirAccess.make_dir_recursive_absolute(dir_path)
	var file_path: String = dir_path + item.id + ".tres"
	var err := ResourceSaver.save(item, file_path)
	return err == OK


func _on_save_item() -> void:
	if _selected_id.is_empty():
		_show_status("No item selected", Color(0.9, 0.7, 0.3))
		return
	var item: ItemData = _items.get(_selected_id)
	if not item:
		return
	if _save_single_item(item):
		_dirty_ids.erase(_selected_id)
		_show_status("Saved: %s" % item.id, Color(0.2, 0.8, 0.3))
		ItemDatabase.reload()
	else:
		_show_status("Save failed: %s" % item.id, Color(0.9, 0.3, 0.3))


func _on_save_all() -> void:
	var success_count: int = 0
	var fail_count: int = 0
	for item in _items.values():
		if _save_single_item(item):
			success_count += 1
		else:
			fail_count += 1
	_dirty_ids.clear()
	ItemDatabase.reload()
	if fail_count == 0:
		_show_status("Saved all %d items" % success_count, Color(0.2, 0.8, 0.3))
	else:
		_show_status("Saved %d, failed %d" % [success_count, fail_count], Color(0.9, 0.7, 0.3))


func _show_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)
	await get_tree().create_timer(3.0).timeout
	if is_inside_tree():
		_status_label.text = ""


func _on_back() -> void:
	SceneManager.pop_scene()


# =========================================================================
# Property Panel
# =========================================================================

func _clear_property_panel() -> void:
	for child in _property_vbox.get_children():
		_property_vbox.remove_child(child)
		child.queue_free()
	var label := Label.new()
	label.text = "Select an item from the list to edit its properties."
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_property_vbox.add_child(label)


func _build_property_panel(item: ItemData) -> void:
	for child in _property_vbox.get_children():
		_property_vbox.remove_child(child)
		child.queue_free()

	_build_identity_section(item)
	_add_separator()
	_build_classification_section(item)
	_add_separator()
	_build_equipment_section(item)
	_add_separator()
	_build_shape_section(item)
	_add_separator()
	_build_stats_section(item)
	_add_separator()
	_build_combat_section(item)
	_add_separator()
	_build_modifier_section(item)
	_add_separator()
	_build_consumable_section(item)
	_add_separator()
	_build_economy_section(item)
	_add_separator()

	var delete_btn := Button.new()
	delete_btn.text = "Delete Item"
	delete_btn.add_theme_color_override("font_color", Color(0.9, 0.3, 0.3))
	delete_btn.pressed.connect(func() -> void: _on_delete_item())
	_property_vbox.add_child(delete_btn)


# === Identity ===

func _build_identity_section(item: ItemData) -> void:
	_add_section_header("Identity")

	_add_label_row("ID:")
	var id_edit := LineEdit.new()
	id_edit.text = item.id
	id_edit.placeholder_text = "unique_item_id"
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_submitted.connect(func(new_text: String) -> void:
		var trimmed: String = new_text.strip_edges().replace(" ", "_").to_lower()
		if trimmed.is_empty() or (trimmed != item.id and _items.has(trimmed)):
			id_edit.text = item.id
			return
		var old_id: String = item.id
		_items.erase(old_id)
		_dirty_ids.erase(old_id)
		item.id = trimmed
		_items[trimmed] = item
		_dirty_ids[trimmed] = true
		_selected_id = trimmed
		_rebuild_item_list()
	)
	_property_vbox.add_child(id_edit)

	_add_label_row("Display Name:")
	var name_edit := LineEdit.new()
	name_edit.text = item.display_name
	name_edit.placeholder_text = "Item Name"
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text: String) -> void:
		item.display_name = new_text
		_dirty_ids[item.id] = true
		_rebuild_item_list()
	)
	_property_vbox.add_child(name_edit)

	_add_label_row("Description:")
	var desc_edit := TextEdit.new()
	desc_edit.text = item.description
	desc_edit.custom_minimum_size = Vector2(0, 60)
	desc_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	desc_edit.text_changed.connect(func() -> void:
		item.description = desc_edit.text
		_dirty_ids[item.id] = true
	)
	_property_vbox.add_child(desc_edit)

	_add_label_row("Icon:")
	var icon_hbox := HBoxContainer.new()
	icon_hbox.alignment = BoxContainer.ALIGNMENT_BEGIN
	var icon_preview := TextureRect.new()
	icon_preview.custom_minimum_size = Vector2(32, 32)
	icon_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if item.icon:
		icon_preview.texture = item.icon
	icon_hbox.add_child(icon_preview)
	var icon_btn := OptionButton.new()
	icon_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	icon_btn.add_item("(none)", 0)
	var selected_icon_idx: int = 0
	for i in range(_icon_paths.size()):
		var fname: String = _icon_paths[i].get_file()
		icon_btn.add_item(fname, i + 1)
		if item.icon and item.icon.resource_path == _icon_paths[i]:
			selected_icon_idx = i + 1
	icon_btn.selected = selected_icon_idx
	icon_btn.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			item.icon = null
			icon_preview.texture = null
		else:
			item.icon = _icon_textures[idx - 1]
			icon_preview.texture = item.icon
		_dirty_ids[item.id] = true
	)
	icon_hbox.add_child(icon_btn)
	_property_vbox.add_child(icon_hbox)


# === Classification ===

func _build_classification_section(item: ItemData) -> void:
	_add_section_header("Classification")

	var type_row := HBoxContainer.new()
	var type_label := Label.new()
	type_label.text = "Type:"
	type_row.add_child(type_label)
	var type_btn := OptionButton.new()
	type_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var type_keys: PackedStringArray = Enums.ItemType.keys()
	for i in range(type_keys.size()):
		type_btn.add_item(type_keys[i].capitalize().replace("_", " "), i)
	type_btn.selected = item.item_type
	type_btn.item_selected.connect(func(idx: int) -> void:
		item.item_type = idx
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	type_row.add_child(type_btn)
	_property_vbox.add_child(type_row)

	var cat_row := HBoxContainer.new()
	var cat_label := Label.new()
	cat_label.text = "Category:"
	cat_row.add_child(cat_label)
	var cat_btn := OptionButton.new()
	cat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cat_keys: PackedStringArray = Enums.EquipmentCategory.keys()
	for i in range(cat_keys.size()):
		cat_btn.add_item(cat_keys[i].capitalize().replace("_", " "), i)
	cat_btn.selected = item.category
	cat_btn.item_selected.connect(func(idx: int) -> void:
		item.category = idx
		_dirty_ids[item.id] = true
	)
	cat_row.add_child(cat_btn)
	_property_vbox.add_child(cat_row)

	var rar_row := HBoxContainer.new()
	var rar_label := Label.new()
	rar_label.text = "Rarity:"
	rar_row.add_child(rar_label)
	var rar_btn := OptionButton.new()
	rar_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var rar_keys: PackedStringArray = Enums.Rarity.keys()
	for i in range(rar_keys.size()):
		rar_btn.add_item(rar_keys[i].capitalize(), i)
	rar_btn.selected = item.rarity
	rar_btn.item_selected.connect(func(idx: int) -> void:
		item.rarity = idx
		_dirty_ids[item.id] = true
		_rebuild_item_list()
	)
	rar_row.add_child(rar_btn)
	_property_vbox.add_child(rar_row)


# === Equipment Slots ===

func _build_equipment_section(item: ItemData) -> void:
	_add_section_header("Equipment Slots")

	var hand_row := HBoxContainer.new()
	var hand_label := Label.new()
	hand_label.text = "Hand Slots:"
	hand_row.add_child(hand_label)
	var hand_spin := SpinBox.new()
	hand_spin.min_value = 0
	hand_spin.max_value = 2
	hand_spin.value = item.hand_slots_required
	hand_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hand_spin.value_changed.connect(func(val: float) -> void:
		item.hand_slots_required = int(val)
		_dirty_ids[item.id] = true
	)
	hand_row.add_child(hand_spin)
	_property_vbox.add_child(hand_row)

	var armor_row := HBoxContainer.new()
	var armor_label := Label.new()
	armor_label.text = "Armor Slot:"
	armor_row.add_child(armor_label)
	var armor_btn := OptionButton.new()
	armor_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cat_keys: PackedStringArray = Enums.EquipmentCategory.keys()
	for i in range(cat_keys.size()):
		armor_btn.add_item(cat_keys[i].capitalize().replace("_", " "), i)
	armor_btn.selected = item.armor_slot
	armor_btn.item_selected.connect(func(idx: int) -> void:
		item.armor_slot = idx
		_dirty_ids[item.id] = true
	)
	armor_row.add_child(armor_btn)
	_property_vbox.add_child(armor_row)

	var bonus_row := HBoxContainer.new()
	var bonus_label := Label.new()
	bonus_label.text = "Bonus Hand Slots:"
	bonus_row.add_child(bonus_label)
	var bonus_spin := SpinBox.new()
	bonus_spin.min_value = 0
	bonus_spin.max_value = 4
	bonus_spin.value = item.bonus_hand_slots
	bonus_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bonus_spin.value_changed.connect(func(val: float) -> void:
		item.bonus_hand_slots = int(val)
		_dirty_ids[item.id] = true
	)
	bonus_row.add_child(bonus_spin)
	_property_vbox.add_child(bonus_row)


# === Shape ===

func _build_shape_section(item: ItemData) -> void:
	_add_section_header("Shape")

	# Shape selector dropdown
	var shape_btn := OptionButton.new()
	shape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shape_btn.add_item("(none)", 0)
	var selected_shape_idx: int = 0
	for i in range(_shapes.size()):
		var s: ItemShape = _shapes[i]
		shape_btn.add_item("%s (%s)" % [s.display_name, s.id], i + 1)
		if item.shape and item.shape.id == s.id:
			selected_shape_idx = i + 1
	shape_btn.selected = selected_shape_idx
	shape_btn.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			item.shape = null
		else:
			item.shape = _shapes[idx - 1]
		_dirty_ids[item.id] = true
		_editing_shape = false
		_build_property_panel(item)
	)
	_property_vbox.add_child(shape_btn)

	# Shape preview (read-only)
	if item.shape and item.shape.cells.size() > 0 and not _editing_shape:
		var preview := _create_shape_preview(item.shape.cells)
		_property_vbox.add_child(preview)

	# Buttons row: Edit Shape / New Shape
	var shape_btns := HBoxContainer.new()
	if item.shape and not _editing_shape:
		var edit_btn := Button.new()
		edit_btn.text = "Edit Shape"
		edit_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		edit_btn.pressed.connect(func() -> void:
			_editing_shape = true
			_build_property_panel(item)
		)
		shape_btns.add_child(edit_btn)
	var new_shape_btn := Button.new()
	new_shape_btn.text = "New Shape"
	new_shape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_shape_btn.pressed.connect(func() -> void:
		# Create a blank shape, assign to item, open editor
		var new_shape := ItemShape.new()
		new_shape.id = "shape_custom_%d" % Time.get_ticks_msec()
		new_shape.display_name = "Custom"
		new_shape.cells = [Vector2i(0, 0)] as Array[Vector2i]
		new_shape.rotation_states = 4
		item.shape = new_shape
		_dirty_ids[item.id] = true
		_editing_shape = true
		_build_property_panel(item)
	)
	shape_btns.add_child(new_shape_btn)
	_property_vbox.add_child(shape_btns)

	# Inline shape editor
	if _editing_shape and item.shape:
		_build_shape_editor(item)


func _build_shape_editor(item: ItemData) -> void:
	var shape: ItemShape = item.shape
	var editor_box := VBoxContainer.new()
	editor_box.add_theme_constant_override("separation", 4)

	# Shape ID
	var id_row := HBoxContainer.new()
	var id_label := Label.new()
	id_label.text = "Shape ID:"
	id_row.add_child(id_label)
	var id_edit := LineEdit.new()
	id_edit.text = shape.id
	id_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	id_edit.text_submitted.connect(func(new_text: String) -> void:
		shape.id = new_text.strip_edges().replace(" ", "_").to_lower()
		id_edit.text = shape.id
	)
	id_row.add_child(id_edit)
	editor_box.add_child(id_row)

	# Shape display name
	var name_row := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = "Name:"
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = shape.display_name
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.text_changed.connect(func(new_text: String) -> void:
		shape.display_name = new_text
	)
	name_row.add_child(name_edit)
	editor_box.add_child(name_row)

	# Rotation states
	var rot_row := HBoxContainer.new()
	var rot_label := Label.new()
	rot_label.text = "Rotations:"
	rot_row.add_child(rot_label)
	var rot_spin := SpinBox.new()
	rot_spin.min_value = 1
	rot_spin.max_value = 4
	rot_spin.value = shape.rotation_states
	rot_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rot_spin.value_changed.connect(func(val: float) -> void:
		shape.rotation_states = int(val)
	)
	rot_row.add_child(rot_spin)
	editor_box.add_child(rot_row)

	# Clickable cell grid (6x6)
	var grid_label := Label.new()
	grid_label.text = "Click cells to toggle (top-left is 0,0):"
	editor_box.add_child(grid_label)
	var grid := _create_shape_cell_editor(item, shape)
	editor_box.add_child(grid)

	# Save / Close buttons
	var btn_row := HBoxContainer.new()
	var save_shape_btn := Button.new()
	save_shape_btn.text = "Save Shape"
	save_shape_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	save_shape_btn.pressed.connect(func() -> void:
		_save_shape(shape)
		_editing_shape = false
		# Reload shapes so the dropdown picks up the new/edited one
		_shapes.clear()
		_shape_paths.clear()
		_load_shapes()
		_build_property_panel(item)
	)
	btn_row.add_child(save_shape_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	close_btn.pressed.connect(func() -> void:
		_editing_shape = false
		_build_property_panel(item)
	)
	btn_row.add_child(close_btn)
	editor_box.add_child(btn_row)

	_property_vbox.add_child(editor_box)


func _create_shape_cell_editor(item: ItemData, shape: ItemShape) -> Control:
	var grid_size: int = 6
	var cell_size: int = 28
	var container := Control.new()
	container.custom_minimum_size = Vector2(grid_size * cell_size + 2, grid_size * cell_size + 2)

	var active_cells: Dictionary = {}
	for cell in shape.cells:
		active_cells[cell] = true

	for gy in range(grid_size):
		for gx in range(grid_size):
			var coord := Vector2i(gx, gy)
			var btn := Button.new()
			btn.position = Vector2(gx * cell_size, gy * cell_size)
			btn.size = Vector2(cell_size - 1, cell_size - 1)

			if active_cells.has(coord):
				btn.modulate = Color(0.4, 0.7, 1.0)
			else:
				btn.modulate = Color(0.25, 0.25, 0.25)

			var captured_coord: Vector2i = coord
			btn.pressed.connect(func() -> void:
				var found: int = -1
				for k in range(shape.cells.size()):
					if shape.cells[k] == captured_coord:
						found = k
						break
				if found >= 0:
					# Don't allow removing the last cell
					if shape.cells.size() > 1:
						shape.cells.remove_at(found)
				else:
					shape.cells.append(captured_coord)
				_dirty_ids[item.id] = true
				_build_property_panel(item)
			)
			container.add_child(btn)

	return container


func _save_shape(shape: ItemShape) -> void:
	DirAccess.make_dir_recursive_absolute("res://data/shapes/")
	var path := "res://data/shapes/" + shape.id + ".tres"
	var err := ResourceSaver.save(shape, path)
	if err == OK:
		_show_status("Shape saved: %s" % shape.id, Color(0.2, 0.8, 0.3))
	else:
		_show_status("Shape save failed!", Color(0.9, 0.3, 0.3))


func _create_shape_preview(cells: Array[Vector2i]) -> Control:
	var container := Control.new()
	var cell_size: int = 16
	var max_x: int = 0
	var max_y: int = 0
	for cell in cells:
		max_x = maxi(max_x, cell.x)
		max_y = maxi(max_y, cell.y)
	container.custom_minimum_size = Vector2((max_x + 1) * cell_size + 2, (max_y + 1) * cell_size + 2)
	for cell in cells:
		var rect := ColorRect.new()
		rect.position = Vector2(cell.x * cell_size + 1, cell.y * cell_size + 1)
		rect.size = Vector2(cell_size - 2, cell_size - 2)
		rect.color = Color(0.4, 0.6, 0.9, 0.8)
		container.add_child(rect)
	return container


# === Stats ===

func _build_stats_section(item: ItemData) -> void:
	_add_section_header("Stat Modifiers")

	for i in range(item.stat_modifiers.size()):
		var mod: StatModifier = item.stat_modifiers[i]
		_add_stat_modifier_row(item, item.stat_modifiers, mod, func() -> void:
			_build_property_panel(item)
		)

	var add_btn := Button.new()
	add_btn.text = "+ Add Stat Modifier"
	add_btn.pressed.connect(func() -> void:
		var new_mod := StatModifier.new()
		new_mod.stat = Enums.Stat.MAX_HP
		new_mod.modifier_type = Enums.ModifierType.FLAT
		new_mod.value = 5.0
		item.stat_modifiers.append(new_mod)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	_property_vbox.add_child(add_btn)


func _add_stat_modifier_row(item: ItemData, array: Array, mod: StatModifier, rebuild_callback: Callable) -> void:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var top_row := HBoxContainer.new()
	var stat_btn := OptionButton.new()
	var stat_keys: PackedStringArray = Enums.Stat.keys()
	for k in range(stat_keys.size()):
		stat_btn.add_item(stat_keys[k].capitalize().replace("_", " "), k)
	stat_btn.selected = mod.stat
	stat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stat_btn.item_selected.connect(func(idx: int) -> void:
		mod.stat = idx
		_dirty_ids[item.id] = true
	)
	top_row.add_child(stat_btn)

	var remove_btn := Button.new()
	remove_btn.text = "X"
	remove_btn.pressed.connect(func() -> void:
		array.erase(mod)
		_dirty_ids[item.id] = true
		rebuild_callback.call()
	)
	top_row.add_child(remove_btn)
	row.add_child(top_row)

	var bottom_row := HBoxContainer.new()
	var type_btn := OptionButton.new()
	type_btn.add_item("Flat", 0)
	type_btn.add_item("Percent", 1)
	type_btn.selected = mod.modifier_type
	type_btn.item_selected.connect(func(idx: int) -> void:
		mod.modifier_type = idx
		_dirty_ids[item.id] = true
	)
	bottom_row.add_child(type_btn)

	var val_spin := SpinBox.new()
	val_spin.min_value = -999
	val_spin.max_value = 999
	val_spin.step = 1
	val_spin.value = mod.value
	val_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	val_spin.value_changed.connect(func(val: float) -> void:
		mod.value = val
		_dirty_ids[item.id] = true
	)
	bottom_row.add_child(val_spin)
	row.add_child(bottom_row)

	_property_vbox.add_child(row)


# === Combat ===

func _build_combat_section(item: ItemData) -> void:
	_add_section_header("Combat")

	var power_row := HBoxContainer.new()
	var power_label := Label.new()
	power_label.text = "Base Power:"
	power_row.add_child(power_label)
	var power_spin := SpinBox.new()
	power_spin.min_value = 0
	power_spin.max_value = 999
	power_spin.value = item.base_power
	power_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	power_spin.value_changed.connect(func(val: float) -> void:
		item.base_power = int(val)
		_dirty_ids[item.id] = true
	)
	power_row.add_child(power_spin)
	_property_vbox.add_child(power_row)

	var mag_row := HBoxContainer.new()
	var mag_label := Label.new()
	mag_label.text = "Magical Power:"
	mag_row.add_child(mag_label)
	var mag_spin := SpinBox.new()
	mag_spin.min_value = 0
	mag_spin.max_value = 999
	mag_spin.value = item.magical_power
	mag_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mag_spin.value_changed.connect(func(val: float) -> void:
		item.magical_power = int(val)
		_dirty_ids[item.id] = true
	)
	mag_row.add_child(mag_spin)
	_property_vbox.add_child(mag_row)

	_add_label_row("Granted Skills:")
	for i in range(item.granted_skills.size()):
		var skill: SkillData = item.granted_skills[i]
		var skill_row := HBoxContainer.new()
		var skill_btn := OptionButton.new()
		skill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_btn.add_item("(none)", 0)
		var selected_skill_idx: int = 0
		for j in range(_skills.size()):
			skill_btn.add_item(_skills[j].display_name, j + 1)
			if skill and _skills[j].id == skill.id:
				selected_skill_idx = j + 1
		skill_btn.selected = selected_skill_idx
		var captured_i: int = i
		skill_btn.item_selected.connect(func(idx: int) -> void:
			if idx == 0:
				item.granted_skills[captured_i] = null
			else:
				item.granted_skills[captured_i] = _skills[idx - 1]
			_dirty_ids[item.id] = true
		)
		skill_row.add_child(skill_btn)
		var remove_btn := Button.new()
		remove_btn.text = "X"
		remove_btn.pressed.connect(func() -> void:
			item.granted_skills.remove_at(captured_i)
			_dirty_ids[item.id] = true
			_build_property_panel(item)
		)
		skill_row.add_child(remove_btn)
		_property_vbox.add_child(skill_row)

	var add_skill_btn := Button.new()
	add_skill_btn.text = "+ Add Skill"
	add_skill_btn.pressed.connect(func() -> void:
		if _skills.size() > 0:
			item.granted_skills.append(_skills[0])
		else:
			item.granted_skills.append(null)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	_property_vbox.add_child(add_skill_btn)


# === Modifier ===

func _build_modifier_section(item: ItemData) -> void:
	if item.item_type != Enums.ItemType.MODIFIER:
		return

	_add_section_header("Modifier")

	var reach_row := HBoxContainer.new()
	var reach_label := Label.new()
	reach_label.text = "Reach (fallback):"
	reach_row.add_child(reach_label)
	var reach_spin := SpinBox.new()
	reach_spin.min_value = 0
	reach_spin.max_value = 10
	reach_spin.value = item.modifier_reach
	reach_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reach_spin.value_changed.connect(func(val: float) -> void:
		item.modifier_reach = int(val)
		_dirty_ids[item.id] = true
	)
	reach_row.add_child(reach_spin)
	_property_vbox.add_child(reach_row)

	# Reach pattern grid (7x7 clickable grid centered on origin)
	_add_label_row("Reach Pattern (click to toggle):")
	var grid_container := _create_reach_pattern_editor(item)
	_property_vbox.add_child(grid_container)

	# Modifier bonuses
	_add_label_row("Modifier Bonuses:")
	for i in range(item.modifier_bonuses.size()):
		var mod: StatModifier = item.modifier_bonuses[i]
		_add_stat_modifier_row(item, item.modifier_bonuses, mod, func() -> void:
			_build_property_panel(item)
		)

	var add_bonus_btn := Button.new()
	add_bonus_btn.text = "+ Add Modifier Bonus"
	add_bonus_btn.pressed.connect(func() -> void:
		var new_mod := StatModifier.new()
		new_mod.stat = Enums.Stat.PHYSICAL_ATTACK
		new_mod.modifier_type = Enums.ModifierType.FLAT
		new_mod.value = 5.0
		item.modifier_bonuses.append(new_mod)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	_property_vbox.add_child(add_bonus_btn)

	_add_separator()

	# Conditional rules
	_add_label_row("Conditional Rules:")
	for i in range(item.conditional_modifier_rules.size()):
		var rule: ConditionalModifierRule = item.conditional_modifier_rules[i]
		_build_conditional_rule(item, rule, i)

	var add_rule_btn := Button.new()
	add_rule_btn.text = "+ Add Conditional Rule"
	add_rule_btn.pressed.connect(func() -> void:
		var new_rule := ConditionalModifierRule.new()
		new_rule.target_weapon_type = Enums.WeaponType.MELEE
		item.conditional_modifier_rules.append(new_rule)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	_property_vbox.add_child(add_rule_btn)


func _create_reach_pattern_editor(item: ItemData) -> Control:
	var grid_size: int = 7
	var cell_size: int = 24
	var center: int = grid_size / 2  # 3 for 7x7
	var container := Control.new()
	container.custom_minimum_size = Vector2(grid_size * cell_size + 2, grid_size * cell_size + 2)

	var active_offsets: Dictionary = {}
	for offset in item.modifier_reach_pattern:
		active_offsets[offset] = true

	for gy in range(grid_size):
		for gx in range(grid_size):
			var offset := Vector2i(gx - center, gy - center)
			var btn := Button.new()
			btn.position = Vector2(gx * cell_size, gy * cell_size)
			btn.size = Vector2(cell_size - 1, cell_size - 1)

			if offset == Vector2i.ZERO:
				btn.modulate = Color(0.5, 0.5, 0.5)
				btn.disabled = true
				btn.text = "G"
			elif active_offsets.has(offset):
				btn.modulate = Color(0.3, 0.8, 0.4)
				btn.text = "+"
			else:
				btn.modulate = Color(0.25, 0.25, 0.25)
				btn.text = ""

			var captured_offset: Vector2i = offset
			btn.pressed.connect(func() -> void:
				if captured_offset == Vector2i.ZERO:
					return
				var found: int = -1
				for k in range(item.modifier_reach_pattern.size()):
					if item.modifier_reach_pattern[k] == captured_offset:
						found = k
						break
				if found >= 0:
					item.modifier_reach_pattern.remove_at(found)
				else:
					item.modifier_reach_pattern.append(captured_offset)
				_dirty_ids[item.id] = true
				_build_property_panel(item)
			)
			container.add_child(btn)

	return container


func _build_conditional_rule(item: ItemData, rule: ConditionalModifierRule, index: int) -> void:
	var rule_container := VBoxContainer.new()
	rule_container.add_theme_constant_override("separation", 2)

	var header := HBoxContainer.new()
	var wtype_btn := OptionButton.new()
	wtype_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var wtype_keys: PackedStringArray = Enums.WeaponType.keys()
	for k in range(wtype_keys.size()):
		wtype_btn.add_item(wtype_keys[k].capitalize(), k)
	wtype_btn.selected = rule.target_weapon_type
	wtype_btn.item_selected.connect(func(idx: int) -> void:
		rule.target_weapon_type = idx
		_dirty_ids[item.id] = true
	)
	header.add_child(wtype_btn)

	var remove_rule_btn := Button.new()
	remove_rule_btn.text = "X"
	remove_rule_btn.pressed.connect(func() -> void:
		item.conditional_modifier_rules.remove_at(index)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	header.add_child(remove_rule_btn)
	rule_container.add_child(header)

	# Stat bonuses
	_add_label_row_to("  Stat Bonuses:", rule_container)
	for j in range(rule.stat_bonuses.size()):
		var mod: StatModifier = rule.stat_bonuses[j]
		var mod_row := VBoxContainer.new()
		mod_row.add_theme_constant_override("separation", 1)
		var top := HBoxContainer.new()
		var stat_btn := OptionButton.new()
		var stat_keys: PackedStringArray = Enums.Stat.keys()
		for k in range(stat_keys.size()):
			stat_btn.add_item(stat_keys[k].capitalize().replace("_", " "), k)
		stat_btn.selected = mod.stat
		stat_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		stat_btn.item_selected.connect(func(idx: int) -> void:
			mod.stat = idx
			_dirty_ids[item.id] = true
		)
		top.add_child(stat_btn)
		var rm := Button.new()
		rm.text = "X"
		rm.pressed.connect(func() -> void:
			rule.stat_bonuses.erase(mod)
			_dirty_ids[item.id] = true
			_build_property_panel(item)
		)
		top.add_child(rm)
		mod_row.add_child(top)
		var bot := HBoxContainer.new()
		var type_btn := OptionButton.new()
		type_btn.add_item("Flat", 0)
		type_btn.add_item("Percent", 1)
		type_btn.selected = mod.modifier_type
		type_btn.item_selected.connect(func(idx: int) -> void:
			mod.modifier_type = idx
			_dirty_ids[item.id] = true
		)
		bot.add_child(type_btn)
		var val_spin := SpinBox.new()
		val_spin.min_value = -999
		val_spin.max_value = 999
		val_spin.step = 1
		val_spin.value = mod.value
		val_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		val_spin.value_changed.connect(func(val: float) -> void:
			mod.value = val
			_dirty_ids[item.id] = true
		)
		bot.add_child(val_spin)
		mod_row.add_child(bot)
		rule_container.add_child(mod_row)

	var add_stat_btn := Button.new()
	add_stat_btn.text = "  + Add Stat Bonus"
	add_stat_btn.pressed.connect(func() -> void:
		var new_mod := StatModifier.new()
		new_mod.stat = Enums.Stat.MAGICAL_ATTACK
		new_mod.modifier_type = Enums.ModifierType.FLAT
		new_mod.value = 5.0
		rule.stat_bonuses.append(new_mod)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	rule_container.add_child(add_stat_btn)

	# Status effect
	var status_row := HBoxContainer.new()
	var status_label := Label.new()
	status_label.text = "  Status Effect:"
	status_row.add_child(status_label)
	var status_btn := OptionButton.new()
	status_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	status_btn.add_item("(none)", 0)
	var selected_status_idx: int = 0
	for j in range(_status_effects.size()):
		var se: StatusEffect = _status_effects[j]
		status_btn.add_item(Enums.StatusEffectType.keys()[se.effect_type].capitalize(), j + 1)
		if rule.status_effect and rule.status_effect.effect_type == se.effect_type:
			selected_status_idx = j + 1
	status_btn.selected = selected_status_idx
	status_btn.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			rule.status_effect = null
		else:
			rule.status_effect = _status_effects[idx - 1]
		_dirty_ids[item.id] = true
	)
	status_row.add_child(status_btn)
	rule_container.add_child(status_row)

	# Effect chance
	var chance_row := HBoxContainer.new()
	var chance_label := Label.new()
	chance_label.text = "  Effect Chance:"
	chance_row.add_child(chance_label)
	var chance_spin := SpinBox.new()
	chance_spin.min_value = 0.0
	chance_spin.max_value = 1.0
	chance_spin.step = 0.05
	chance_spin.value = rule.status_effect_chance
	chance_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chance_spin.value_changed.connect(func(val: float) -> void:
		rule.status_effect_chance = val
		_dirty_ids[item.id] = true
	)
	chance_row.add_child(chance_spin)
	rule_container.add_child(chance_row)

	# Granted skills
	_add_label_row_to("  Granted Skills:", rule_container)
	for j in range(rule.granted_skills.size()):
		var skill: SkillData = rule.granted_skills[j]
		var skill_row := HBoxContainer.new()
		var skill_btn := OptionButton.new()
		skill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		skill_btn.add_item("(none)", 0)
		var sel_idx: int = 0
		for k in range(_skills.size()):
			skill_btn.add_item(_skills[k].display_name, k + 1)
			if skill and _skills[k].id == skill.id:
				sel_idx = k + 1
		skill_btn.selected = sel_idx
		var captured_j: int = j
		skill_btn.item_selected.connect(func(idx: int) -> void:
			if idx == 0:
				rule.granted_skills[captured_j] = null
			else:
				rule.granted_skills[captured_j] = _skills[idx - 1]
			_dirty_ids[item.id] = true
		)
		skill_row.add_child(skill_btn)
		var rm_skill := Button.new()
		rm_skill.text = "X"
		rm_skill.pressed.connect(func() -> void:
			rule.granted_skills.remove_at(captured_j)
			_dirty_ids[item.id] = true
			_build_property_panel(item)
		)
		skill_row.add_child(rm_skill)
		rule_container.add_child(skill_row)

	var add_gskill_btn := Button.new()
	add_gskill_btn.text = "  + Add Skill"
	add_gskill_btn.pressed.connect(func() -> void:
		if _skills.size() > 0:
			rule.granted_skills.append(_skills[0])
		else:
			rule.granted_skills.append(null)
		_dirty_ids[item.id] = true
		_build_property_panel(item)
	)
	rule_container.add_child(add_gskill_btn)

	# Force AoE
	var aoe_check := CheckBox.new()
	aoe_check.text = "  Force AoE"
	aoe_check.button_pressed = rule.force_aoe
	aoe_check.toggled.connect(func(val: bool) -> void:
		rule.force_aoe = val
		_dirty_ids[item.id] = true
	)
	rule_container.add_child(aoe_check)

	# HP Cost per attack
	var hp_row := HBoxContainer.new()
	var hp_label := Label.new()
	hp_label.text = "  HP Cost/Attack:"
	hp_row.add_child(hp_label)
	var hp_spin := SpinBox.new()
	hp_spin.min_value = 0
	hp_spin.max_value = 100
	hp_spin.value = rule.hp_cost_per_attack
	hp_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hp_spin.value_changed.connect(func(val: float) -> void:
		rule.hp_cost_per_attack = int(val)
		_dirty_ids[item.id] = true
	)
	hp_row.add_child(hp_spin)
	rule_container.add_child(hp_row)

	var rule_sep := HSeparator.new()
	rule_sep.add_theme_constant_override("separation", 4)
	rule_container.add_child(rule_sep)

	_property_vbox.add_child(rule_container)


# === Consumable ===

func _build_consumable_section(item: ItemData) -> void:
	if item.item_type != Enums.ItemType.CONSUMABLE:
		return

	_add_section_header("Consumable")

	var skill_row := HBoxContainer.new()
	var skill_label := Label.new()
	skill_label.text = "Use Skill:"
	skill_row.add_child(skill_label)
	var skill_btn := OptionButton.new()
	skill_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	skill_btn.add_item("(none)", 0)
	var selected_idx: int = 0
	for i in range(_skills.size()):
		skill_btn.add_item(_skills[i].display_name, i + 1)
		if item.use_skill and _skills[i].id == item.use_skill.id:
			selected_idx = i + 1
	skill_btn.selected = selected_idx
	skill_btn.item_selected.connect(func(idx: int) -> void:
		if idx == 0:
			item.use_skill = null
		else:
			item.use_skill = _skills[idx - 1]
		_dirty_ids[item.id] = true
	)
	skill_row.add_child(skill_btn)
	_property_vbox.add_child(skill_row)


# === Economy ===

func _build_economy_section(item: ItemData) -> void:
	_add_section_header("Economy")

	var price_row := HBoxContainer.new()
	var price_label := Label.new()
	price_label.text = "Base Price:"
	price_row.add_child(price_label)
	var price_spin := SpinBox.new()
	price_spin.min_value = 0
	price_spin.max_value = 99999
	price_spin.step = 10
	price_spin.value = item.base_price
	price_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	price_spin.value_changed.connect(func(val: float) -> void:
		item.base_price = int(val)
		_dirty_ids[item.id] = true
	)
	price_row.add_child(price_spin)
	_property_vbox.add_child(price_row)

	var sell_label := Label.new()
	sell_label.text = "Sell Price: %d (50%%)" % item.get_sell_price()
	sell_label.modulate = Color(0.7, 0.7, 0.7)
	_property_vbox.add_child(sell_label)


# =========================================================================
# UI Helpers
# =========================================================================

func _add_section_header(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_property_vbox.add_child(label)


func _add_label_row(text: String) -> void:
	var label := Label.new()
	label.text = text
	_property_vbox.add_child(label)


func _add_label_row_to(text: String, parent: Control) -> void:
	var label := Label.new()
	label.text = text
	parent.add_child(label)


func _add_separator() -> void:
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 8)
	_property_vbox.add_child(sep)


func _update_hint_bar() -> void:
	_hint_bar.text = "Items: %d | Ctrl+S: save | Esc: back" % _items.size()
