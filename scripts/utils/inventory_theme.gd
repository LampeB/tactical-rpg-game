class_name InventoryTheme
## Manages inventory visual theme — sprite-based cells and panels from the UI kit.
## Supports 10 color variants. Change the active palette to restyle the entire inventory.

enum Palette {
	BROWN,
	TEAL,
	DARK_GREY,
	DARK_BROWN,
	GREY,
	RED,
	BLUE,
	PURPLE,
	PINK,
	GREEN,
}

const COLOR_NAMES: Array[String] = [
	"brown", "teal", "dark_grey", "dark_brown", "grey",
	"red", "blue", "purple", "pink", "green",
]

const _BASE_PATH := "res://assets/ui/inventory/"

## Active palette for the inventory UI. Change this to restyle.
static var active_color: int = Palette.BROWN

## Cached textures (loaded on first access per palette)
static var _panel_cache: Dictionary = {}
static var _cell_cache: Dictionary = {}
static var _edge_v_cache: Dictionary = {}
static var _edge_h_cache: Dictionary = {}
static var _corner_cache: Dictionary = {}


static func get_panel_texture(palette: int = active_color) -> Texture2D:
	if not _panel_cache.has(palette):
		var path: String = _BASE_PATH + "panel_%s.png" % COLOR_NAMES[palette]
		if ResourceLoader.exists(path):
			_panel_cache[palette] = load(path) as Texture2D
		else:
			_panel_cache[palette] = null
	return _panel_cache[palette]


static func get_cell_texture(palette: int = active_color) -> Texture2D:
	if not _cell_cache.has(palette):
		var path: String = _BASE_PATH + "cell_%s_24.png" % COLOR_NAMES[palette]
		if ResourceLoader.exists(path):
			_cell_cache[palette] = load(path) as Texture2D
		else:
			_cell_cache[palette] = null
	return _cell_cache[palette]


static func get_edge_v_texture(palette: int = active_color) -> Texture2D:
	if not _edge_v_cache.has(palette):
		var path: String = _BASE_PATH + "edge_v_%s.png" % COLOR_NAMES[palette]
		_edge_v_cache[palette] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _edge_v_cache[palette]


static func get_edge_h_texture(palette: int = active_color) -> Texture2D:
	if not _edge_h_cache.has(palette):
		var path: String = _BASE_PATH + "edge_h_%s.png" % COLOR_NAMES[palette]
		_edge_h_cache[palette] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _edge_h_cache[palette]


static func get_corner_texture(palette: int = active_color) -> Texture2D:
	if not _corner_cache.has(palette):
		var path: String = _BASE_PATH + "corner_%s.png" % COLOR_NAMES[palette]
		_corner_cache[palette] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _corner_cache[palette]


static func get_color_name(palette: int = active_color) -> String:
	return COLOR_NAMES[palette]
