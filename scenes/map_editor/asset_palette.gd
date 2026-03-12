class_name AssetPalette
extends VBoxContainer
## Scrollable categorized list of .tscn scene assets for the map editor.
## Scans res://scenes/world/objects/ on init.

signal asset_selected(path: String)

const SCENES_DIR := "res://scenes/world/objects/"

var _search_edit: LineEdit
var _list_vbox: VBoxContainer
var _selected_path: String = ""

# Cached asset lists: Array of { "name": String, "path": String }
var _all_assets: Array[Dictionary] = []


func _ready() -> void:
	_scan_assets()
	_build_ui()
	_rebuild_list()


func _scan_assets() -> void:
	var scene_dir := DirAccess.open(SCENES_DIR)
	if scene_dir:
		scene_dir.list_dir_begin()
		var fname := scene_dir.get_next()
		while fname != "":
			if not scene_dir.current_is_dir() and fname.ends_with(".tscn"):
				_all_assets.append({
					"name": fname.get_basename(),
					"path": SCENES_DIR + fname,
				})
			fname = scene_dir.get_next()
		scene_dir.list_dir_end()

	_all_assets.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["name"].naturalcasecmp_to(b["name"]) < 0
	)


func _build_ui() -> void:
	add_theme_constant_override("separation", 4)

	var header := Label.new()
	header.text = "Asset Palette"
	header.add_theme_font_size_override("font_size", 16)
	header.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	add_child(header)

	_search_edit = LineEdit.new()
	_search_edit.placeholder_text = "Search..."
	_search_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_search_edit.text_changed.connect(func(_t: String) -> void: _rebuild_list())
	add_child(_search_edit)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	_list_vbox = VBoxContainer.new()
	_list_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list_vbox.add_theme_constant_override("separation", 1)
	scroll.add_child(_list_vbox)


func _rebuild_list() -> void:
	for child in _list_vbox.get_children():
		child.queue_free()

	var search_text: String = _search_edit.text.strip_edges().to_lower()

	for asset in _all_assets:
		var asset_name: String = asset["name"]
		if not search_text.is_empty() and search_text not in asset_name.to_lower():
			continue

		var btn := Button.new()
		btn.text = asset_name
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.tooltip_text = asset["path"]

		var asset_path: String = asset["path"]

		if asset_path == _selected_path:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.3, 0.5, 0.7, 0.5)
			style.set_content_margin_all(2)
			btn.add_theme_stylebox_override("normal", style)

		btn.pressed.connect(func() -> void:
			_selected_path = asset_path
			asset_selected.emit(asset_path)
			_rebuild_list()
		)
		_list_vbox.add_child(btn)


func get_selected_path() -> String:
	return _selected_path
