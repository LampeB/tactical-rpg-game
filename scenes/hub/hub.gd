extends Control
## Hub scene — main out-of-battle area.
## POC: Mission Board, Party (stats + inventory), Merchant, Blacksmith,
## Doctor (heal), Save & Quit. Multi-hub travel + tavern + dialogue NPCs come later.

const SHOP_ID := "merchant_general"     ## data/shops/{SHOP_ID}.tres
const STATION_ID := "blacksmith"        ## data/crafting/{STATION_ID}.tres
const _GameMenuScene := preload("res://scenes/menus/game_menu.tscn")
const _GameMenuScript := preload("res://scenes/menus/game_menu.gd")

@onready var _mission_board_button: Button = $CenterPanel/VBox/MissionBoardButton
@onready var _party_button: Button = $CenterPanel/VBox/PartyButton
@onready var _merchant_button: Button = $CenterPanel/VBox/MerchantButton
@onready var _blacksmith_button: Button = $CenterPanel/VBox/BlacksmithButton
@onready var _doctor_button: Button = $CenterPanel/VBox/DoctorButton
@onready var _quit_button: Button = $CenterPanel/VBox/QuitButton
@onready var _gold_label: Label = $TopBar/GoldLabel
@onready var _status_label: Label = $StatusLabel  ## Brief feedback after actions (e.g. "Party fully healed")

var _game_menu: _GameMenuScript


func _ready() -> void:
	_mission_board_button.pressed.connect(_on_mission_board_pressed)
	_party_button.pressed.connect(_on_party_pressed)
	_merchant_button.pressed.connect(_on_merchant_pressed)
	_blacksmith_button.pressed.connect(_on_blacksmith_pressed)
	_doctor_button.pressed.connect(_on_doctor_pressed)
	_quit_button.pressed.connect(_on_quit_pressed)
	_ensure_party_initialized()
	_refresh_gold()
	_status_label.text = ""
	_game_menu = _GameMenuScene.instantiate()
	add_child(_game_menu)
	EventBus.show_message.connect(_game_menu.show_toast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_game_menu.toggle()
		get_viewport().set_input_as_handled()


func _ensure_party_initialized() -> void:
	## When running hub.tscn directly via F6 (no main-menu New Game flow),
	## GameManager.party is null and the battle has no player characters.
	## Auto-init a default party so the MVP loop works standalone.
	if GameManager.party == null or GameManager.party.roster.is_empty():
		GameManager.new_game()
		DebugLogger.log_info("[Hub] Auto-initialized new game (no party found)", "Hub")
		_auto_equip_starter_weapons()


func _auto_equip_starter_weapons() -> void:
	## new_game() drops starter weapons into the stash but doesn't equip them on
	## characters. Without an equipped weapon, the Attack button shows an empty
	## weapon list and target selection never starts.
	## MVP: place a basic weapon at grid (0,0) for each starter character.
	const STARTER_WEAPON_BY_ID := {
		"warrior": "sword_common",
		"mage": "staff_common",
		"rogue": "dagger_common",
	}
	var party = GameManager.party
	if not party:
		return
	for char_id in party.roster.keys():
		var weapon_id: String = STARTER_WEAPON_BY_ID.get(char_id, "sword_common")
		var weapon: ItemData = ItemDatabase.get_item(weapon_id)
		if not weapon:
			DebugLogger.log_warn("[Hub] Starter weapon %s not found for %s" % [weapon_id, char_id], "Hub")
			continue
		var inv: GridInventory = party.grid_inventories.get(char_id)
		if not inv:
			DebugLogger.log_warn("[Hub] No grid inventory for character %s" % char_id, "Hub")
			continue
		var placed = inv.place_item(weapon, Vector2i(0, 0), 0)
		if placed:
			# Remove the duplicate copy from the stash (since we equipped one).
			party.remove_from_stash(weapon)
			DebugLogger.log_info("[Hub] Equipped %s on %s" % [weapon_id, char_id], "Hub")
		else:
			DebugLogger.log_warn("[Hub] Could not place %s on %s at (0,0)" % [weapon_id, char_id], "Hub")


func receive_data(_data: Dictionary) -> void:
	# Returning from Mission Board / battle / loot — refresh displayed state.
	_refresh_gold()


func _refresh_gold() -> void:
	if GameManager:
		_gold_label.text = "Gold: %d" % GameManager.gold


func _on_mission_board_pressed() -> void:
	SceneManager.push_scene("res://scenes/hub/mission_board.tscn")


func _on_party_pressed() -> void:
	## Open the character stats / inventory editor.
	## character_stats.tscn reads GameManager.party directly — no scene data needed.
	SceneManager.push_scene("res://scenes/character_stats/character_stats.tscn")


func _on_merchant_pressed() -> void:
	SceneManager.push_scene("res://scenes/shop/shop_ui.tscn", {"shop_id": SHOP_ID})


func _on_blacksmith_pressed() -> void:
	SceneManager.push_scene("res://scenes/crafting/crafting_ui.tscn", {"station_id": STATION_ID})


func _on_doctor_pressed() -> void:
	## No UI scene yet — heal the active squad to full HP/MP in place.
	if not GameManager.party:
		return
	var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
	var healed_count: int = 0
	for character_id in GameManager.party.squad:
		var max_hp: int = GameManager.party.get_max_hp(character_id, tree)
		var max_mp: int = GameManager.party.get_max_mp(character_id, tree)
		GameManager.party.set_current_hp(character_id, max_hp, tree)
		GameManager.party.set_current_mp(character_id, max_mp, tree)
		healed_count += 1
	_status_label.text = "Doctor: %d party members fully restored." % healed_count
	DebugLogger.log_info("[Hub] Doctor healed %d squad members" % healed_count, "Hub")


func _on_quit_pressed() -> void:
	SaveManager.auto_save()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")
