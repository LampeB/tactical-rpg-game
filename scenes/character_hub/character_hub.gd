extends Control
## Unified character hub. Combines Stats and Skills views
## into one screen with shared character tabs and view switching.
## Stats view includes the inventory grid and stash.

enum ViewType { STATS, SKILLS }

@onready var _bg: ColorRect = $BG
@onready var _back_btn: Button = $VBox/TopBar/BackButton
@onready var _gold_label: Label = $VBox/TopBar/GoldLabel
@onready var _character_tabs: HBoxContainer = $VBox/CharacterTabs
@onready var _stats_tab: Button = $VBox/ViewTabs/StatsTab
@onready var _skills_tab: Button = $VBox/ViewTabs/SkillsTab
@onready var _view_container: Control = $VBox/ViewContainer

var _current_character_id: String = ""
var _current_view: ViewType = ViewType.STATS

# Sub-scene instances
var _stats_view: Control = null
var _skills_view: Control = null

# Track which views need a character refresh when shown
var _dirty_views: Dictionary = {ViewType.STATS: false, ViewType.SKILLS: false}


func _ready() -> void:
	_bg.color = UIColors.BG_CHARACTER_HUB
	_back_btn.pressed.connect(_on_back)
	_stats_tab.pressed.connect(_on_view_tab.bind(ViewType.STATS))
	_skills_tab.pressed.connect(_on_view_tab.bind(ViewType.SKILLS))

	# Character tabs
	if GameManager.party:
		_character_tabs.setup(GameManager.party.squad, GameManager.party.roster)
		_character_tabs.character_selected.connect(_on_character_selected)

	# Gold display
	EventBus.gold_changed.connect(_on_gold_changed)
	_update_gold_display()

	# Refresh stats when passives or inventory change
	EventBus.passive_unlocked.connect(_on_data_changed.bind(ViewType.STATS))
	EventBus.inventory_changed.connect(_on_data_changed_any)

	# Instance sub-scenes
	_stats_view = _instance_view("res://scenes/character_stats/character_stats.tscn")
	_skills_view = _instance_view("res://scenes/passive_tree/passive_tree.tscn")

	# Select first character and show stats view
	if GameManager.party and not GameManager.party.squad.is_empty():
		_current_character_id = GameManager.party.squad[0]
		_character_tabs.select(_current_character_id)

	# Initialize all views with the current character (deferred so sub-scenes finish _ready)
	_setup_views.call_deferred()

	DebugLogger.log_info("Character hub ready", "CharHub")


func _setup_views() -> void:
	if not _current_character_id.is_empty():
		_stats_view.setup_embedded(_current_character_id)
		_skills_view.setup_embedded(_current_character_id)
	_switch_view(ViewType.STATS)


func _instance_view(scene_path: String) -> Control:
	var scene: PackedScene = load(scene_path)
	var instance: Control = scene.instantiate()
	instance.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_view_container.add_child(instance)
	instance.visible = false
	return instance


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		_on_back()
		get_viewport().set_input_as_handled()


# === View Switching ===

func _on_view_tab(view_name: ViewType) -> void:
	_switch_view(view_name)


func _switch_view(view_name: ViewType) -> void:
	_current_view = view_name

	_stats_view.visible = (view_name == ViewType.STATS)
	_skills_view.visible = (view_name == ViewType.SKILLS)

	_stats_tab.button_pressed = (view_name == ViewType.STATS)
	_skills_tab.button_pressed = (view_name == ViewType.SKILLS)

	# Refresh the view if it was marked dirty
	if _dirty_views.get(view_name, false) and not _current_character_id.is_empty():
		_get_view(view_name).setup_embedded(_current_character_id)
		_dirty_views[view_name] = false


func _get_view(view_name: ViewType) -> Control:
	match view_name:
		ViewType.STATS: return _stats_view
		ViewType.SKILLS: return _skills_view
	return _stats_view


# === Character Switching ===

func _on_character_selected(character_id: String) -> void:
	_current_character_id = character_id

	# Update the active view immediately
	_get_view(_current_view).setup_embedded(character_id)

	# Mark other views as dirty so they refresh when shown
	for view_name in [ViewType.STATS, ViewType.SKILLS]:
		if view_name != _current_view:
			_dirty_views[view_name] = true


# === Data Change Refresh ===

func _on_data_changed(_arg1: Variant, _arg2: Variant, dirty_view: ViewType) -> void:
	## A specific view needs refreshing (e.g. stats after passive unlock).
	if _current_view == dirty_view and not _current_character_id.is_empty():
		_get_view(dirty_view).setup_embedded(_current_character_id)
	else:
		_dirty_views[dirty_view] = true


func _on_data_changed_any(_character_id: String) -> void:
	## Inventory changed — stats view needs refresh (equipment affects stats).
	if _current_view == ViewType.STATS and not _current_character_id.is_empty():
		_stats_view.setup_embedded(_current_character_id)
	else:
		_dirty_views[ViewType.STATS] = true


# === Navigation ===

func _on_back() -> void:
	SceneManager.pop_scene()


func _on_gold_changed(_new_gold: int) -> void:
	_update_gold_display()


func _update_gold_display() -> void:
	_gold_label.text = "Gold: %d" % GameManager.gold
