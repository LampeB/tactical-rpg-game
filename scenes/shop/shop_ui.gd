extends Control
## Merchant shop screen — unified drag-and-drop for all four panels.
##
## SELL sources → SELL destinations:
##   PLAYER_GRID or STASH  ──drag──▶  merchant grid OR sold panel  = sell
## BUY sources  → BUY destinations:
##   MERCHANT or SOLD_PANEL ──drag──▶  player grid OR stash        = buy / buy-back
##
## Moving within same side:
##   PLAYER_GRID → PLAYER_GRID = free repositon
##   STASH       → PLAYER_GRID = free move to grid
##   STASH drop back on stash  = cancel
##
## R = rotate, Escape/RMB = cancel drag.

enum DragState { IDLE, DRAGGING }
enum DragSource { NONE, MERCHANT, PLAYER_GRID, STASH, SOLD_PANEL }

@onready var _bg: ColorRect               = $Background
@onready var _title: Label                = $VBox/TopBar/Title
@onready var _gold_label: Label           = $VBox/TopBar/GoldLabel
@onready var _merchant_grid_panel         = $VBox/Content/MerchantSide/MerchantGridCentering/MerchantGridPanel
@onready var _hover_info: Label           = $VBox/Content/MerchantSide/HoverInfoLabel
@onready var _sold_panel: PanelContainer  = $VBox/Content/MerchantSide/SoldPanel
@onready var _sold_item_list: VBoxContainer = $VBox/Content/MerchantSide/SoldPanel/SoldVBox/SoldScroll/SoldItemList
@onready var _sold_total_label: Label     = $VBox/Content/MerchantSide/SoldPanel/SoldVBox/SoldTotalLabel
@onready var _character_tabs              = $VBox/Content/PlayerSide/CharacterTabs
@onready var _player_grid_panel           = $VBox/Content/PlayerSide/GridCentering/PlayerGridPanel
@onready var _stash_panel                 = $VBox/Content/PlayerSide/StashPanel
@onready var _close_btn: Button           = $VBox/BottomBar/CloseButton
@onready var _drag_preview                = $DragLayer/DragPreview
@onready var _item_tooltip                = $TooltipLayer/ItemTooltip

const MERCHANT_GRID_WIDTH  := 10
const MERCHANT_GRID_HEIGHT := 7

var _shop_data: ShopData      = null
var _merchant_inv: GridInventory = null
var _player_grid_inventories: Dictionary = {}
var _current_character_id: String = ""

# ── Drag state ──────────────────────────────────────────────────────────────
var _drag_state: DragState  = DragState.IDLE
var _dragged_item: ItemData = null
var _drag_source: DragSource = DragSource.NONE
var _drag_rotation: int      = 0
var _drag_hover_pos: Vector2i = Vector2i(-1, -1)  ## Last grid cell hovered during drag

# Per-source return info (for cancel)
var _drag_source_merchant_pos: Vector2i = Vector2i.ZERO
var _drag_source_merchant_rot: int = 0
var _drag_source_player_pos: Vector2i = Vector2i.ZERO
var _drag_source_player_rot: int = 0
var _drag_source_stash_index: int  = -1
var _drag_source_sold_index: int   = -1
var _drag_source_sold_price: int   = 0   # gold received when sold; cost to buy back

# ── Session tracking ────────────────────────────────────────────────────────
## ItemData ref → gold paid this session → gives full refund on immediate resell.
var _purchase_prices: Dictionary = {}
## [{item, name, price}] — sold items; can be bought back for entry.price.
var _sold_log: Array = []


# ════════════════════════════════════════════════════════════════════════════
#  Setup
# ════════════════════════════════════════════════════════════════════════════

func _ready() -> void:
	_bg.color = Color(0.10, 0.14, 0.20, 1)
	_close_btn.pressed.connect(_on_close)
	_hover_info.text = ""

	_merchant_grid_panel.cell_clicked.connect(_on_merchant_cell_clicked)
	_merchant_grid_panel.cell_hovered.connect(_on_merchant_cell_hovered)
	_merchant_grid_panel.cell_exited.connect(_on_merchant_hover_exited)

	_player_grid_panel.cell_clicked.connect(_on_player_cell_clicked)
	_player_grid_panel.cell_hovered.connect(_on_player_cell_hovered)
	_player_grid_panel.cell_exited.connect(_on_player_hover_exited)

	_stash_panel.item_clicked.connect(_on_stash_item_clicked)
	_stash_panel.item_hovered.connect(func(item: ItemData, pos: Vector2) -> void:
		_item_tooltip.show_for_item(item, null, null, pos, _sell_price_for(item), "Sell"))
	_stash_panel.item_exited.connect(func() -> void: _item_tooltip.hide_tooltip())
	_stash_panel.set_label_prefix("Stash", false)

	if GameManager.party:
		_player_grid_inventories = GameManager.party.grid_inventories
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	_drag_preview.visible = false
	_item_tooltip.visible = false
	_refresh_sold_panel()


func receive_data(data: Dictionary) -> void:
	var shop_id: String = data.get("shop_id", "")
	var shop_path := "res://data/shops/%s.tres" % shop_id
	_shop_data = load(shop_path) as ShopData
	if not _shop_data:
		DebugLogger.log_warn("ShopUI: shop not found: %s" % shop_path, "Shop")
		SceneManager.pop_scene()
		return

	_title.text = _shop_data.display_name
	_setup_merchant_grid()
	_refresh_stash()
	_update_gold_label()

	if GameManager.party and not GameManager.party.squad.is_empty():
		_on_character_selected(GameManager.party.squad[0])
		_character_tabs.select(GameManager.party.squad[0])


# ════════════════════════════════════════════════════════════════════════════
#  Merchant grid setup
# ════════════════════════════════════════════════════════════════════════════

func _setup_merchant_grid() -> void:
	var tpl := GridTemplate.new()
	tpl.id = "merchant_grid"
	tpl.width  = MERCHANT_GRID_WIDTH
	tpl.height = MERCHANT_GRID_HEIGHT
	_merchant_inv = GridInventory.new(tpl)
	_merchant_inv.skip_equipment_checks = true

	# Collect unpurchased items with their stock index
	var pending: Array = []
	DebugLogger.log_info("ShopUI: stock has %d items" % _shop_data.stock.size(), "Shop")
	for i in range(_shop_data.stock.size()):
		var stock_item: ItemData = _shop_data.stock[i]
		if stock_item == null:
			DebugLogger.log_warn("ShopUI: stock[%d] is NULL" % i, "Shop")
			continue
		DebugLogger.log_info("ShopUI: stock[%d] = %s (id=%s)" % [i, stock_item.display_name, stock_item.id], "Shop")
		if _is_slot_purchased(i):
			DebugLogger.log_info("ShopUI:   -> skipped (purchased)", "Shop")
			continue
		pending.append(i)

	# Sort largest items first for better bin-packing
	pending.sort_custom(func(a: int, b: int) -> bool:
		var sa: ItemData = _shop_data.stock[a]
		var sb: ItemData = _shop_data.stock[b]
		var ca: int = sa.shape.cells.size() if sa.shape else 1
		var cb: int = sb.shape.cells.size() if sb.shape else 1
		return ca > cb)

	for i in pending:
		var item: ItemData = _shop_data.stock[i]
		var placed_item := item.duplicate()
		placed_item.set_meta("shop_slot_index", i)
		if not _try_place_merchant(placed_item):
			DebugLogger.log_warn("ShopUI: could not place '%s' (cells=%d)" % [item.display_name, item.shape.cells.size() if item.shape else 1], "Shop")
	DebugLogger.log_info("ShopUI: placed %d items in merchant grid" % _merchant_inv.placed_items.size(), "Shop")
	_merchant_grid_panel.setup(_merchant_inv)


func _try_place_merchant(item: ItemData) -> bool:
	var rotations := item.shape.rotation_states if item.shape else 1
	for y in range(MERCHANT_GRID_HEIGHT):
		for x in range(MERCHANT_GRID_WIDTH):
			for r in range(rotations):
				if _merchant_inv.place_item(item, Vector2i(x, y), r):
					return true
	return false


# ════════════════════════════════════════════════════════════════════════════
#  Character switching
# ════════════════════════════════════════════════════════════════════════════

func _on_character_selected(character_id: String) -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	_current_character_id = character_id
	var inv: GridInventory = _player_grid_inventories.get(character_id)
	if inv:
		_player_grid_panel.setup(inv)
	_item_tooltip.hide_tooltip()


# ════════════════════════════════════════════════════════════════════════════
#  _process — sold-panel green tint while a sell-source is being dragged
# ════════════════════════════════════════════════════════════════════════════

func _process(_delta: float) -> void:
	if _drag_state != DragState.DRAGGING:
		return
	if _drag_source in [DragSource.PLAYER_GRID, DragSource.STASH]:
		var over_sold := _sold_panel.get_global_rect().has_point(get_global_mouse_position())
		_sold_panel.modulate = Color(0.6, 1.2, 0.6, 1.0) if over_sold else Color.WHITE
	# Highlight upgradeable items on player grid and stash
	_player_grid_panel.highlight_upgradeable_items(_dragged_item)
	_stash_panel.highlight_upgradeable_items(_dragged_item)


# ════════════════════════════════════════════════════════════════════════════
#  Input — _input (fires before children) so sold-panel row buttons don't
#  swallow drop clicks; handles rotate, cancel, and overlay-zone drops.
# ════════════════════════════════════════════════════════════════════════════

func _input(event: InputEvent) -> void:
	if _drag_state != DragState.DRAGGING:
		if event.is_action_pressed("escape"):
			_on_close()
			get_viewport().set_input_as_handled()
		return

	# Rotate (right-click)
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT:
		if _dragged_item and _dragged_item.shape:
			_drag_rotation = (_drag_rotation + 1) % 4
			_drag_preview.rotate_cw()
			if _drag_hover_pos != Vector2i(-1, -1):
				_on_player_cell_hovered(_drag_hover_pos)
		get_viewport().set_input_as_handled()
		return

	# Cancel
	if event.is_action_pressed("escape"):
		_cancel_drag()
		get_viewport().set_input_as_handled()
		return

	# Left-click drop on overlay zones (sold panel / stash) — must be caught
	# here before children consume the event.
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse_pos := get_global_mouse_position()

		# Sell sources → sold panel
		if _drag_source in [DragSource.PLAYER_GRID, DragSource.STASH]:
			if _sold_panel.get_global_rect().has_point(mouse_pos):
				_complete_sell()
				get_viewport().set_input_as_handled()
				return

		# Buy sources → stash
		if _drag_source in [DragSource.MERCHANT, DragSource.SOLD_PANEL]:
			if _stash_panel.is_mouse_over():
				_complete_buy_to_stash()
				get_viewport().set_input_as_handled()
				return

		# Stash or player grid drag dropped onto stash — let through to slot
		# click handler so upgrade checks can fire. Only cancel if not on a slot.
		if _drag_source in [DragSource.STASH, DragSource.PLAYER_GRID] and _stash_panel.is_mouse_over():
			# Don't consume — let the click reach stash slots for upgrade checks.
			# If no slot is hit, stash_panel._gui_input emits background_clicked
			# which we don't handle while dragging, so the drag persists (harmless).
			pass


# ════════════════════════════════════════════════════════════════════════════
#  Merchant grid handlers
# ════════════════════════════════════════════════════════════════════════════

func _on_merchant_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return

	if _drag_state == DragState.DRAGGING:
		match _drag_source:
			DragSource.PLAYER_GRID, DragSource.STASH:
				_complete_sell()
			DragSource.MERCHANT, DragSource.SOLD_PANEL:
				_cancel_drag()
		return

	var placed: GridInventory.PlacedItem = _merchant_inv.get_item_at(grid_pos)
	if placed:
		_start_drag_from_merchant(placed)


func _on_merchant_cell_hovered(grid_pos: Vector2i) -> void:
	if _drag_state == DragState.DRAGGING:
		if _drag_source in [DragSource.PLAYER_GRID, DragSource.STASH]:
			_merchant_grid_panel.modulate = Color(0.6, 1.2, 0.6, 1.0)
			_drag_preview.set_valid(true)
		return

	var placed: GridInventory.PlacedItem = _merchant_inv.get_item_at(grid_pos)
	if placed:
		var price := ShopSystem.get_buy_price(placed.item_data, _shop_data)
		_set_hover_info("%s  —  %dg" % [placed.item_data.display_name, price],
			Constants.RARITY_COLORS.get(placed.item_data.rarity, Color.WHITE))
		_item_tooltip.show_for_item(placed.item_data, null, null,
			get_global_mouse_position(), price, "Buy")
	else:
		_item_tooltip.hide_tooltip()
		_merchant_grid_panel.clear_highlights()


func _on_merchant_hover_exited() -> void:
	_merchant_grid_panel.modulate = Color.WHITE
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
		_hover_info.text = ""
	_merchant_grid_panel.clear_placement_preview()
	_player_grid_panel.clear_placement_preview()


# ════════════════════════════════════════════════════════════════════════════
#  Player grid handlers
# ════════════════════════════════════════════════════════════════════════════

func _on_player_cell_clicked(grid_pos: Vector2i, button: int) -> void:
	if button != MOUSE_BUTTON_LEFT:
		return
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		match _drag_source:
			DragSource.MERCHANT:
				_complete_buy_to_player_grid(grid_pos, inv)
			DragSource.SOLD_PANEL:
				_complete_buyback_to_player_grid(grid_pos, inv)
			DragSource.PLAYER_GRID:
				_complete_move_within_grid(grid_pos, inv)
			DragSource.STASH:
				_complete_move_stash_to_grid(grid_pos, inv)
		return

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_start_drag_from_player_grid(placed, inv)


func _on_player_cell_hovered(grid_pos: Vector2i) -> void:
	var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
	if not inv:
		return

	if _drag_state == DragState.DRAGGING:
		_drag_hover_pos = grid_pos
		_player_grid_panel.show_placement_preview(_dragged_item, grid_pos, _drag_rotation)
		_drag_preview.set_valid(inv.can_place(_dragged_item, grid_pos, _drag_rotation))
		return

	var placed: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if placed:
		_player_grid_panel.highlight_modifier_connections(placed)
		_item_tooltip.show_for_item(placed.item_data, placed, inv,
			get_global_mouse_position(), _sell_price_for(placed.item_data), "Sell")
	else:
		_item_tooltip.hide_tooltip()
		_player_grid_panel.clear_highlights()


func _on_player_hover_exited() -> void:
	if _drag_state == DragState.IDLE:
		_item_tooltip.hide_tooltip()
	_drag_hover_pos = Vector2i(-1, -1)
	_player_grid_panel.clear_placement_preview()


# ════════════════════════════════════════════════════════════════════════════
#  Stash — click starts drag
# ════════════════════════════════════════════════════════════════════════════

func _on_stash_item_clicked(item: ItemData, index: int) -> void:
	if _drag_state == DragState.DRAGGING:
		# Check for stash-on-stash upgrade
		if ItemUpgradeSystem.can_upgrade(_dragged_item, item):
			_perform_stash_upgrade(item, index)
			return
		_cancel_drag()
		return
	_start_drag_from_stash(item, index)


func _perform_stash_upgrade(target_item: ItemData, target_index: int) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_item)
	GameManager.party.stash.remove_at(target_index)
	GameManager.party.add_to_stash(upgraded_item)
	_end_drag()
	_refresh_stash()
	EventBus.stash_changed.emit()
	DebugLogger.log_info("SHOP STASH UPGRADE! → %s" % upgraded_item.display_name, "Shop")


# ════════════════════════════════════════════════════════════════════════════
#  Drag start
# ════════════════════════════════════════════════════════════════════════════

func _start_drag_from_merchant(placed: GridInventory.PlacedItem) -> void:
	_dragged_item = placed.item_data
	_drag_source_merchant_pos = placed.grid_position
	_drag_source_merchant_rot = placed.rotation
	_drag_rotation = placed.rotation
	_drag_source = DragSource.MERCHANT
	_drag_state  = DragState.DRAGGING

	_merchant_inv.remove_item(placed)
	_merchant_grid_panel.refresh()
	_item_tooltip.hide_tooltip()

	var price := ShopSystem.get_buy_price(_dragged_item, _shop_data)
	_set_hover_info("Buying: %s  —  %dg" % [_dragged_item.display_name, price],
		Color(1.0, 0.84, 0.0))
	_drag_preview.setup(_dragged_item, _drag_rotation)


func _start_drag_from_player_grid(placed: GridInventory.PlacedItem, inv: GridInventory) -> void:
	_dragged_item = placed.item_data
	_drag_source_player_pos = placed.grid_position
	_drag_source_player_rot = placed.rotation
	_drag_rotation = placed.rotation
	_drag_source = DragSource.PLAYER_GRID
	_drag_state  = DragState.DRAGGING

	inv.remove_item(placed)
	_player_grid_panel.refresh()
	_item_tooltip.hide_tooltip()

	var sell_preview := _sell_price_for(_dragged_item)
	_set_hover_info("Selling: %s  →  +%dg" % [_dragged_item.display_name, sell_preview],
		Color(0.5, 1.0, 0.5))
	_drag_preview.setup(_dragged_item, _drag_rotation)


func _start_drag_from_stash(item: ItemData, index: int) -> void:
	_dragged_item = item
	_drag_source_stash_index = index
	_drag_rotation = 0
	_drag_source = DragSource.STASH
	_drag_state  = DragState.DRAGGING

	GameManager.party.stash.remove_at(index)
	EventBus.stash_changed.emit()
	_refresh_stash()
	_item_tooltip.hide_tooltip()

	var sell_preview := _sell_price_for(_dragged_item)
	_set_hover_info("Selling: %s  →  +%dg" % [_dragged_item.display_name, sell_preview],
		Color(0.5, 1.0, 0.5))
	_drag_preview.setup(_dragged_item, _drag_rotation)


func _start_drag_from_sold_panel(index: int) -> void:
	if index < 0 or index >= _sold_log.size():
		return
	var entry: Dictionary = _sold_log[index]
	_dragged_item          = entry.item
	_drag_source_sold_index = index
	_drag_source_sold_price = entry.price
	_drag_rotation = 0
	_drag_source = DragSource.SOLD_PANEL
	_drag_state  = DragState.DRAGGING

	_sold_log.remove_at(index)
	_refresh_sold_panel()
	_item_tooltip.hide_tooltip()

	_set_hover_info("Buying back: %s  —  %dg" % [_dragged_item.display_name, _drag_source_sold_price],
		Color(1.0, 0.84, 0.0))
	_drag_preview.setup(_dragged_item, _drag_rotation)


# ════════════════════════════════════════════════════════════════════════════
#  Drop completions
# ════════════════════════════════════════════════════════════════════════════

## MERCHANT → player grid (buy)
func _complete_buy_to_player_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	var price := ShopSystem.get_buy_price(_dragged_item, _shop_data)
	if not GameManager.spend_gold(price):
		_flash_gold_label()
		return
	_purchase_prices[_dragged_item] = price
	_mark_item_purchased(_dragged_item)
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_update_gold_label()
	var item_name := _dragged_item.display_name
	_end_drag()
	_set_hover_info("Bought: %s  —  %dg" % [item_name, price], Color(0.5, 0.8, 1.0))
	DebugLogger.log_info("Bought %s for %dg" % [item_name, price], "Shop")


## SOLD_PANEL → player grid (buy back)
func _complete_buyback_to_player_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	if not GameManager.spend_gold(_drag_source_sold_price):
		_flash_gold_label()
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_update_gold_label()
	var item_name := _dragged_item.display_name
	var price     := _drag_source_sold_price
	_end_drag()
	_set_hover_info("Bought back: %s  —  %dg" % [item_name, price], Color(0.5, 0.8, 1.0))
	DebugLogger.log_info("Bought back %s for %dg" % [item_name, price], "Shop")


## MERCHANT or SOLD_PANEL → stash (buy / buy back)
func _complete_buy_to_stash() -> void:
	var price: int
	match _drag_source:
		DragSource.MERCHANT:   price = ShopSystem.get_buy_price(_dragged_item, _shop_data)
		DragSource.SOLD_PANEL: price = _drag_source_sold_price
		_: return
	if not GameManager.spend_gold(price):
		_flash_gold_label()
		_cancel_drag()
		return
	if _drag_source == DragSource.MERCHANT:
		_purchase_prices[_dragged_item] = price
		_mark_item_purchased(_dragged_item)
	var item_name := _dragged_item.display_name
	GameManager.party.add_to_stash(_dragged_item)
	EventBus.stash_changed.emit()
	_refresh_stash()
	_update_gold_label()
	_end_drag()
	_set_hover_info("Bought: %s → stash  —  %dg" % [item_name, price], Color(0.5, 0.8, 1.0))
	DebugLogger.log_info("Bought %s to stash for %dg" % [item_name, price], "Shop")


## PLAYER_GRID or STASH → merchant grid or sold panel (both call this).
## Routing is based on item origin, NOT drop target:
##   • Merchant-origin item (bought this session) → back to merchant grid.
##   • Player-origin item                         → session sales log (sold panel).
func _complete_sell() -> void:
	var was_merchant_item := _purchase_prices.has(_dragged_item)
	var sell_price := _sell_price_for(_dragged_item)
	if was_merchant_item:
		_purchase_prices.erase(_dragged_item)
		_unmark_item_purchased(_dragged_item)

	var item_name := _dragged_item.display_name
	GameManager.add_gold(sell_price)

	match _drag_source:
		DragSource.PLAYER_GRID:
			EventBus.inventory_changed.emit(_current_character_id)
		DragSource.STASH:
			pass  # already removed from stash + refreshed at drag start

	if was_merchant_item:
		_try_place_merchant(_dragged_item)
		_merchant_grid_panel.refresh()
	else:
		_sold_log.append({"item": _dragged_item, "name": item_name, "price": sell_price})
		_refresh_sold_panel()

	_update_gold_label()
	_end_drag()
	_set_hover_info("Sold: %s  +%dg" % [item_name, sell_price], Color(0.5, 1.0, 0.5))
	DebugLogger.log_info("Sold %s (%s) for %dg" % [item_name, "→ merchant" if was_merchant_item else "→ panel", sell_price], "Shop")


## STASH → player grid (free move, no gold)
func _complete_move_stash_to_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	# Check for item upgrade
	var target: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target and ItemUpgradeSystem.can_upgrade(_dragged_item, target.item_data):
		_perform_player_grid_upgrade(inv, target)
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_end_drag()


## PLAYER_GRID → PLAYER_GRID (reposition)
func _complete_move_within_grid(grid_pos: Vector2i, inv: GridInventory) -> void:
	# Check for item upgrade
	var target: GridInventory.PlacedItem = inv.get_item_at(grid_pos)
	if target and ItemUpgradeSystem.can_upgrade(_dragged_item, target.item_data):
		_perform_player_grid_upgrade(inv, target)
		return

	if not inv.can_place(_dragged_item, grid_pos, _drag_rotation):
		return
	inv.place_item(_dragged_item, grid_pos, _drag_rotation)
	EventBus.inventory_changed.emit(_current_character_id)
	_player_grid_panel.refresh()
	_end_drag()


func _perform_player_grid_upgrade(inv: GridInventory, target_placed: GridInventory.PlacedItem) -> void:
	var upgraded_item: ItemData = ItemUpgradeSystem.create_upgraded_item(target_placed.item_data)
	var target_pos: Vector2i = target_placed.grid_position
	var target_rot: int = target_placed.rotation
	inv.remove_item(target_placed)
	var new_placed: GridInventory.PlacedItem = inv.place_item(upgraded_item, target_pos, target_rot)
	_end_drag()
	if new_placed:
		_player_grid_panel.refresh()
		EventBus.inventory_changed.emit(_current_character_id)
		if _drag_source == DragSource.STASH:
			EventBus.stash_changed.emit()
			_refresh_stash()
		DebugLogger.log_info("SHOP UPGRADE! → %s" % upgraded_item.display_name, "Shop")


# ════════════════════════════════════════════════════════════════════════════
#  Cancel / end drag
# ════════════════════════════════════════════════════════════════════════════

func _cancel_drag() -> void:
	if not _dragged_item:
		_end_drag()
		return

	match _drag_source:
		DragSource.MERCHANT:
			if not _merchant_inv.place_item(_dragged_item, _drag_source_merchant_pos, _drag_source_merchant_rot):
				_try_place_merchant(_dragged_item)
			_merchant_grid_panel.refresh()
		DragSource.PLAYER_GRID:
			var inv: GridInventory = _player_grid_inventories.get(_current_character_id)
			if inv:
				if not inv.place_item(_dragged_item, _drag_source_player_pos, _drag_source_player_rot):
					GameManager.party.add_to_stash(_dragged_item)
					EventBus.stash_changed.emit()
					_refresh_stash()
				else:
					_player_grid_panel.refresh()
		DragSource.STASH:
			GameManager.party.stash.insert(_drag_source_stash_index, _dragged_item)
			EventBus.stash_changed.emit()
			_refresh_stash()
		DragSource.SOLD_PANEL:
			_sold_log.insert(_drag_source_sold_index,
				{"item": _dragged_item, "name": _dragged_item.display_name, "price": _drag_source_sold_price})
			_refresh_sold_panel()

	_end_drag()


func _end_drag() -> void:
	_drag_state  = DragState.IDLE
	_dragged_item = null
	_drag_source = DragSource.NONE
	_drag_source_stash_index = -1
	_drag_source_sold_index  = -1
	_drag_source_sold_price  = 0
	_sold_panel.modulate          = Color.WHITE
	_merchant_grid_panel.modulate = Color.WHITE
	_drag_preview.hide_preview()
	_merchant_grid_panel.clear_placement_preview()
	_player_grid_panel.clear_placement_preview()
	_stash_panel.clear_upgradeable_highlights()


# ════════════════════════════════════════════════════════════════════════════
#  Session sales panel
# ════════════════════════════════════════════════════════════════════════════

func _refresh_sold_panel() -> void:
	for child in _sold_item_list.get_children():
		child.queue_free()

	var total := 0
	for i in range(_sold_log.size()):
		var entry: Dictionary = _sold_log[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		# MOUSE_FILTER_STOP lets gui_input receive clicks on the label/bg areas
		# (buttons inside still handle their own events first).
		row.mouse_filter = Control.MOUSE_FILTER_STOP

		var name_lbl := Label.new()
		name_lbl.text = entry.name
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(name_lbl)

		var price_lbl := Label.new()
		price_lbl.text = "+%dg" % entry.price
		price_lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5))
		price_lbl.add_theme_font_size_override("font_size", 13)
		row.add_child(price_lbl)

		var bb_btn := Button.new()
		bb_btn.text = "↩ %dg" % entry.price
		bb_btn.tooltip_text = "Quick buy-back to stash"
		bb_btn.pressed.connect(_on_buyback.bind(i))
		row.add_child(bb_btn)

		# Clicking the name/price area (not the button) starts a drag.
		var captured_i := i
		row.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT \
					and _drag_state == DragState.IDLE:
				_start_drag_from_sold_panel(captured_i)
				get_viewport().set_input_as_handled()
		)

		_sold_item_list.add_child(row)
		total += entry.price

	_sold_total_label.text = "Total received: +%dg" % total


## Quick buy-back (button click) → goes directly to stash.
func _on_buyback(index: int) -> void:
	if index < 0 or index >= _sold_log.size():
		return
	var entry: Dictionary = _sold_log[index]
	var item: ItemData    = entry.item
	var price: int        = entry.price
	if not GameManager.spend_gold(price):
		_flash_gold_label()
		return
	_sold_log.remove_at(index)
	GameManager.party.add_to_stash(item)
	EventBus.stash_changed.emit()
	_refresh_sold_panel()
	_refresh_stash()
	_update_gold_label()
	_set_hover_info("Bought back: %s  —  %dg" % [item.display_name, price], Color(0.5, 0.8, 1.0))
	DebugLogger.log_info("Bought back %s for %dg" % [item.display_name, price], "Shop")


# ════════════════════════════════════════════════════════════════════════════
#  Helpers
# ════════════════════════════════════════════════════════════════════════════

func _sell_price_for(item: ItemData) -> int:
	if _purchase_prices.has(item):
		return _purchase_prices[item]  # full refund for items bought this session
	return ShopSystem.get_sell_price(item, _shop_data)


func _set_hover_info(text: String, color: Color) -> void:
	_hover_info.text = text
	_hover_info.add_theme_color_override("font_color", color)


func _flash_gold_label() -> void:
	var tween := create_tween()
	tween.tween_property(_gold_label, "modulate", Color.RED, 0.1)
	tween.tween_property(_gold_label, "modulate", Color.WHITE, 0.3)


func _refresh_stash() -> void:
	if GameManager.party:
		_stash_panel.refresh(GameManager.party.stash)


func _update_gold_label() -> void:
	_gold_label.text = "%d g" % GameManager.gold


func _slot_flag(slot_index: int) -> String:
	return "shop_%s_slot_%d" % [_shop_data.id, slot_index]

func _is_slot_purchased(slot_index: int) -> bool:
	return GameManager.get_flag(_slot_flag(slot_index))

func _mark_item_purchased(item: ItemData) -> void:
	if item.has_meta("shop_slot_index"):
		var idx: int = item.get_meta("shop_slot_index")
		GameManager.set_flag(_slot_flag(idx), true)

func _unmark_item_purchased(item: ItemData) -> void:
	if item.has_meta("shop_slot_index"):
		var idx: int = item.get_meta("shop_slot_index")
		GameManager.set_flag(_slot_flag(idx), false)


func _on_close() -> void:
	if _drag_state == DragState.DRAGGING:
		_cancel_drag()
	SceneManager.pop_scene()
