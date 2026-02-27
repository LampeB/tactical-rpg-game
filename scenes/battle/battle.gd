extends Control
## Battle scene orchestrator. Manages combat flow, UI updates, and player input.
## Battlefield uses a SubViewport with Node2D sprites for future camera/animation support.

enum BattleState { INIT, PLAYER_ACTION, TARGET_SELECT, ENEMY_ACTION, ANIMATING, VICTORY, DEFEAT }

const EntityStatusBarScene: PackedScene = preload("res://scenes/battle/ui/entity_status_bar.tscn")
const BattleSpriteScene: PackedScene = preload("res://scenes/battle/ui/battle_sprite.tscn")
const DamagePopupScene: PackedScene = preload("res://scenes/battle/ui/damage_popup.tscn")

const LootGeneratorScript = preload("res://scripts/systems/loot/loot_generator.gd")

const ACTION_DELAY: float = 0.6  ## Seconds between actions for readability
const BATTLE_START_DELAY: float = 0.5  ## Delay before first turn
const VICTORY_DELAY: float = 1.5  ## Pause before victory screen
const DEFEAT_DELAY: float = 2.0  ## Pause before defeat screen

# Battle positions relative to SubViewport center (computed at runtime)
const PLAYER_OFFSETS: Array[Vector2] = [
	Vector2(-300, -30),
	Vector2(-350, 40),
	Vector2(-240, 50),
	Vector2(-400, -10),
]
const ENEMY_OFFSETS: Array[Vector2] = [
	Vector2(300, -30),
	Vector2(350, 40),
	Vector2(240, 50),
	Vector2(400, -10),
]

# --- Child references (UI overlay) ---
@onready var _bg: ColorRect = $Background
@onready var _title: Label = $MainLayout/TopBar/MarginContainer/HBox/Title
@onready var _round_label: Label = $MainLayout/TopBar/MarginContainer/HBox/RoundLabel
@onready var _turn_order_bar: PanelContainer = $MainLayout/TurnOrderSection/TurnOrderBar
@onready var _enemy_list: VBoxContainer = $MainLayout/BattleField/FieldLayout/EnemyPortraits/EnemyList
@onready var _party_list: HBoxContainer = $MainLayout/BattleField/FieldLayout/PartyCards/PartyList
@onready var _target_prompt: HBoxContainer = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt
@onready var _target_prompt_label: Label = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt/Label
@onready var _action_menu: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/ActionMenu
@onready var _log_toggle: Button = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/LogSection/LogToggle
@onready var _battle_log: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/LogSection/BattleLog
@onready var _popup_layer: CanvasLayer = $PopupLayer

# --- Battlefield (SubViewport) references ---
@onready var _battle_viewport: SubViewportContainer = $MainLayout/BattleField/FieldLayout/BattleViewport
@onready var _sub_viewport: SubViewport = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport
@onready var _battle_world: Node2D = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport/BattleWorld
@onready var _battle_camera: Camera2D = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport/BattleWorld/BattleCamera

# --- State ---
var _encounter_data: EncounterData
var _combat_manager: CombatManager
var _state: BattleState = BattleState.INIT

# Entity -> UI mappings
var _entity_bars: Dictionary = {}  ## CombatEntity -> EntityStatusBar node
var _entity_sprites: Dictionary = {}  ## CombatEntity -> BattleSprite (Node2D)
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory

# Target selection
var _pending_action_type: int = -1
var _pending_skill: SkillData = null
var _pending_target_type: int = -1
var _pending_item: ItemData = null

# Battle log file recording
var _log_lines: Array[String] = []
const BATTLE_LOG_PATH := "res://battle_log.txt"


func _clear_pending_action() -> void:
	_pending_action_type = -1
	_pending_skill = null
	_pending_target_type = -1
	_pending_item = null


func _ready() -> void:
	_bg.color = UIColors.BG_BATTLE
	_action_menu.hide_menu()
	_action_menu.action_chosen.connect(_on_action_chosen)
	_target_prompt.visible = false
	_log_toggle.toggled.connect(_on_log_toggle)
	_battle_log.visible = false
	DebugLogger.log_info("Battle scene ready", "Battle")


func receive_data(data: Dictionary) -> void:
	DebugLogger.log_info("receive_data called, keys: %s" % str(data.keys()), "Battle")
	if data.has("encounter"):
		_encounter_data = data["encounter"]
		_title.text = "Battle: %s" % _encounter_data.display_name
		DebugLogger.log_info("Encounter set: %s (enemies: %d, can_flee: %s)" % [_encounter_data.display_name, _encounter_data.enemies.size(), str(_encounter_data.can_flee)], "Battle")
	if data.has("grid_inventories"):
		_grid_inventories = data["grid_inventories"]
		DebugLogger.log_info("Received %d grid inventories" % _grid_inventories.size(), "Battle")
	_start_battle.call_deferred()


func _start_battle() -> void:
	_log_lines.clear()
	DebugLogger.log_info("_start_battle called", "Battle")
	if not _encounter_data:
		DebugLogger.log_error("No encounter data!", "Battle")
		return

	# Sync SubViewport size to container
	_sync_viewport_size()

	_combat_manager = CombatManager.new()
	_combat_manager.turn_ready.connect(_on_turn_ready)
	_combat_manager.action_resolved.connect(_on_action_resolved)
	_combat_manager.combat_finished.connect(_on_combat_finished)
	_combat_manager.entity_died.connect(_on_entity_died)
	_combat_manager.log_message.connect(_on_log_message)
	_combat_manager.status_ticked.connect(_on_status_ticked)
	DebugLogger.log_info("CombatManager created and signals connected", "Battle")

	# Bridge EventBus signals (CombatManager can't access autoloads)
	EventBus.combat_started.emit(_encounter_data)

	# Build player entities from party
	var player_entities: Array = []
	if GameManager.party:
		DebugLogger.log_info("Building player entities from party (squad size: %d, roster size: %d)" % [GameManager.party.squad.size(), GameManager.party.roster.size()], "Battle")
		for character_id in GameManager.party.squad:
			var char_data: CharacterData = GameManager.party.roster.get(character_id)
			if char_data:
				var inv: GridInventory = _grid_inventories.get(character_id)
				var tree = PassiveTreeDatabase.get_passive_tree()
				var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

				# Load current HP/MP from persistent vitals
				var starting_hp: int = GameManager.party.get_current_hp(character_id)
				var starting_mp: int = GameManager.party.get_current_mp(character_id)

				var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses, starting_hp, starting_mp)
				player_entities.append(entity)
				var skill_count: int = entity.get_available_skills().size()
				DebugLogger.log_info("  Player: %s - HP:%d/%d MP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f Skills:%d Inv:%s AoE:%s ToolStates:%d" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.current_mp, entity.max_mp, entity.get_effective_stat(Enums.Stat.SPEED), entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), skill_count, str(inv != null), str(entity.has_force_aoe()), entity.tool_modifier_states.size()], "Battle")
			else:
				DebugLogger.log_warn("Character ID '%s' not found in roster" % character_id, "Battle")
	else:
		DebugLogger.log_warn("No party data available!", "Battle")

	# Build enemy entities from encounter
	var enemy_entities: Array = []
	DebugLogger.log_info("Building %d enemy entities" % _encounter_data.enemies.size(), "Battle")
	for i in range(_encounter_data.enemies.size()):
		var e_data: EnemyData = _encounter_data.enemies[i]
		if e_data:
			var entity: CombatEntity = CombatEntity.from_enemy(e_data)
			# Disambiguate duplicate enemy names
			var count: int = 0
			for j in range(enemy_entities.size()):
				var existing: CombatEntity = enemy_entities[j]
				if existing.enemy_data and existing.enemy_data.id == e_data.id:
					count += 1
			if count > 0:
				entity.entity_name = "%s %s" % [e_data.display_name, _letter(count)]
			enemy_entities.append(entity)
			var skill_count: int = entity.get_available_skills().size()
			DebugLogger.log_info("  Enemy: %s - HP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f Skills:%d" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.get_effective_stat(Enums.Stat.SPEED), entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), skill_count], "Battle")

	# Build UI bars and sprites
	DebugLogger.log_info("Building UI bars (%d enemies, %d players)" % [enemy_entities.size(), player_entities.size()], "Battle")
	_build_entity_bars(player_entities, enemy_entities)
	_build_entity_sprites(player_entities, enemy_entities)

	# Start combat
	DebugLogger.log_info("Starting combat via CombatManager", "Battle")
	_combat_manager.start_combat(_encounter_data, player_entities, enemy_entities)
	_refresh_all_ui()

	# Begin first turn
	DebugLogger.log_info("Waiting %.1fs before first turn..." % BATTLE_START_DELAY, "Battle")
	await get_tree().create_timer(BATTLE_START_DELAY).timeout
	DebugLogger.log_info("Advancing to first turn", "Battle")
	_combat_manager.advance_turn()


func _letter(index: int) -> String:
	return char(65 + index)  # A, B, C...


func _sync_viewport_size() -> void:
	## Position camera to show the full viewport.
	## anchor_mode = FIXED_TOP_LEFT (0), so position (0,0) shows the entire SubViewport.
	var vp_size: Vector2 = Vector2(_sub_viewport.size)
	DebugLogger.log_info("Syncing viewport: size=%s" % str(vp_size), "BattleView")
	_battle_camera.position = Vector2.ZERO
	DebugLogger.log_info("  Camera positioned at %s" % str(_battle_camera.position), "BattleView")


# === Camera Stubs (for future use) ===

func _shake_camera(_intensity: float = 5.0, _duration: float = 0.3) -> void:
	## Stub: will shake camera for impact effects.
	DebugLogger.log_info("Camera shake (stub): intensity=%.1f duration=%.1f" % [_intensity, _duration], "BattleView")
	pass


func _pan_camera_to(_target: Vector2, _duration: float = 0.5) -> void:
	## Stub: will smoothly pan camera to a position.
	DebugLogger.log_info("Camera pan (stub): target=%s duration=%.1f" % [str(_target), _duration], "BattleView")
	pass


func _reset_camera(_duration: float = 0.3) -> void:
	## Stub: will return camera to default center position.
	DebugLogger.log_info("Camera reset (stub): duration=%.1f" % _duration, "BattleView")
	pass


# === UI Building ===

func _add_entity_bar(entity: CombatEntity, container: Container) -> void:
	var bar: PanelContainer = EntityStatusBarScene.instantiate()
	container.add_child(bar)
	bar.setup(entity)
	bar.gui_input.connect(_on_entity_bar_input.bind(entity))
	bar.mouse_entered.connect(_on_entity_bar_mouse_entered.bind(entity))
	bar.mouse_exited.connect(_on_entity_bar_mouse_exited.bind(entity))
	_entity_bars[entity] = bar


func _build_entity_bars(players: Array, enemies: Array) -> void:
	for c in _enemy_list.get_children():
		c.queue_free()
	for c in _party_list.get_children():
		c.queue_free()
	_entity_bars.clear()

	for i in range(enemies.size()):
		_add_entity_bar(enemies[i], _enemy_list)

	for i in range(players.size()):
		_add_entity_bar(players[i], _party_list)


func _add_entity_sprite(entity: CombatEntity, slot_index: int, is_player: bool) -> void:
	var sprite: Node2D = BattleSpriteScene.instantiate()
	_battle_world.add_child(sprite)

	# Position at battle slot
	var viewport_center: Vector2 = Vector2(_sub_viewport.size) / 2.0
	var offsets: Array[Vector2] = PLAYER_OFFSETS if is_player else ENEMY_OFFSETS
	var offset: Vector2 = offsets[slot_index % offsets.size()]
	sprite.position = viewport_center + offset

	var side: String = "player" if is_player else "enemy"
	DebugLogger.log_info("Sprite placed: %s [%s slot %d] at %s (center=%s + offset=%s)" % [entity.entity_name, side, slot_index, str(sprite.position), str(viewport_center), str(offset)], "BattleView")

	sprite.setup(entity)

	# Connect sprite signals for target selection
	sprite.clicked.connect(_on_sprite_clicked)
	sprite.mouse_entered_sprite.connect(_on_entity_bar_mouse_entered)
	sprite.mouse_exited_sprite.connect(_on_entity_bar_mouse_exited)

	_entity_sprites[entity] = sprite


func _build_entity_sprites(players: Array, enemies: Array) -> void:
	# Clear existing sprites from battle world
	for child in _battle_world.get_children():
		if child is Node2D and child != _battle_camera:
			child.queue_free()
	_entity_sprites.clear()

	for pi in range(players.size()):
		_add_entity_sprite(players[pi], pi, true)

	for ei in range(enemies.size()):
		_add_entity_sprite(enemies[ei], ei, false)


func _refresh_all_ui() -> void:
	var keys: Array = _entity_bars.keys()
	for i in range(keys.size()):
		var entity: CombatEntity = keys[i]
		var bar: PanelContainer = _entity_bars[entity]
		bar.refresh()

	if _combat_manager:
		_turn_order_bar.refresh(
			_combat_manager.get_turn_order(),
			_combat_manager.current_entity,
		)
		_round_label.text = "Round %d" % (_combat_manager.round_number + 1)

		# Highlight current entity's bar
		for hi in range(keys.size()):
			var hl_entity: CombatEntity = keys[hi]
			var hl_bar: PanelContainer = _entity_bars[hl_entity]
			if hl_entity == _combat_manager.current_entity and hl_entity.is_player:
				hl_bar.highlight_active_turn()
			elif hl_entity == _combat_manager.current_entity:
				hl_bar.highlight(true)
			else:
				hl_bar.highlight(false)


# === Combat Manager Callbacks ===

func _on_turn_ready(entity: CombatEntity) -> void:
	_refresh_all_ui()

	if entity.is_player:
		if entity.is_dead:
			_combat_manager.advance_turn()
			return
		_state = BattleState.PLAYER_ACTION
		DebugLogger.log_info("State -> PLAYER_ACTION: %s (HP:%d/%d MP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.current_mp, entity.max_mp], "Battle")
		var skills: Array = entity.get_available_skills()
		var skill_names: String = ", ".join(skills.map(func(s: SkillData) -> String: return s.display_name)) if not skills.is_empty() else "none"
		DebugLogger.log_info("  Skills: [%s], can_flee: %s" % [skill_names, str(_encounter_data.can_flee)], "Battle")
		_action_menu.show_for_entity(entity, _encounter_data.can_flee)
	else:
		_state = BattleState.ENEMY_ACTION
		DebugLogger.log_info("State -> ENEMY_ACTION: %s (HP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp], "Battle")
		_action_menu.show_disabled()
		await get_tree().create_timer(ACTION_DELAY).timeout
		_execute_enemy_turn(entity)


func _on_action_resolved(_results: Dictionary) -> void:
	_refresh_all_ui()


func _write_battle_log(victory: bool) -> void:
	var encounter_name: String = _encounter_data.display_name if _encounter_data else "Unknown"
	var result_str: String = "VICTORY" if victory else "DEFEAT"
	var path: String = ProjectSettings.globalize_path(BATTLE_LOG_PATH)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if not file:
		DebugLogger.log_warn("Could not write battle log to %s" % path, "Battle")
		return
	file.store_line("=== BATTLE LOG: %s ===" % encounter_name)
	file.store_line("=== %s ===" % result_str)
	file.store_line("")
	for line in _log_lines:
		file.store_line(line)
	file.store_line("")
	file.store_line("=== END ===")
	file.close()
	DebugLogger.log_info("Battle log written to: %s" % path, "Battle")


func _on_combat_finished(victory: bool) -> void:
	_write_battle_log(victory)
	_action_menu.hide_menu()
	_target_prompt.visible = false

	# Save player HP/MP back to persistent vitals (revive KO'd chars at 1 HP on victory)
	_save_player_vitals(victory)

	if victory:
		_state = BattleState.VICTORY
		_title.text = "Victory!"
		DebugLogger.log_info("State -> VICTORY! Gold earned: %d (bonus: %d)" % [_combat_manager.gold_earned, _encounter_data.bonus_gold], "Battle")
		GameManager.add_gold(_combat_manager.gold_earned)
		EventBus.combat_ended.emit(true)
		await get_tree().create_timer(VICTORY_DELAY).timeout
		# Generate loot and show reward screen
		var loot: Array = LootGeneratorScript.generate_loot(_encounter_data, _combat_manager.enemy_entities)
		if not loot.is_empty():
			DebugLogger.log_info("Generated %d loot items, opening loot screen" % loot.size(), "Battle")
			var loot_data := {
				"loot": loot,
				"gold": _combat_manager.gold_earned,
				"source": "battle",
			}
			SceneManager.replace_scene("res://scenes/loot/loot.tscn", loot_data)
		else:
			DebugLogger.log_info("No loot generated, returning to previous scene", "Battle")
			SceneManager.pop_scene({"from_battle": true})
	elif _combat_manager.player_fled:
		DebugLogger.log_info("Player fled — returning to overworld", "Battle")
		EventBus.combat_ended.emit(false)
		SceneManager.pop_scene({"from_battle": true})
	else:
		_state = BattleState.DEFEAT
		_title.text = "Defeat..."
		DebugLogger.log_info("State -> DEFEAT", "Battle")
		EventBus.combat_ended.emit(false)
		await get_tree().create_timer(DEFEAT_DELAY).timeout
		DebugLogger.log_info("Showing defeat screen", "Battle")
		_show_defeat_screen()


func _on_entity_died(entity: CombatEntity) -> void:
	DebugLogger.log_info("Entity died: %s (is_player: %s)" % [entity.entity_name, str(entity.is_player)], "Battle")

	# Play death animation and wait for it
	var sprite: Node2D = _entity_sprites.get(entity)
	if sprite:
		DebugLogger.log_info("Anim: %s -> play_death (pos=%s)" % [entity.entity_name, str(sprite.position)], "BattleAnim")
		sprite.play_death_animation()
		await sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> death finished" % entity.entity_name, "BattleAnim")
	else:
		DebugLogger.log_warn("Anim: no sprite found for dying entity %s" % entity.entity_name, "BattleAnim")

	_refresh_all_ui()


func _on_log_message(text: String, color: Color) -> void:
	_battle_log.add_message(text, color)
	DebugLogger.log_info("[CombatLog] %s" % text, "Battle")
	_log_lines.append(text)


func _on_log_toggle(toggled_on: bool) -> void:
	_battle_log.visible = toggled_on


func _on_status_ticked(entity: CombatEntity, damage: int, status_name: String) -> void:
	DebugLogger.log_info("Status tick on %s: %d damage from %s (HP now: %d/%d)" % [entity.entity_name, damage, status_name, entity.current_hp, entity.max_hp], "Battle")
	_spawn_popup_at_entity(entity, damage, Enums.PopupType.DAMAGE)

	# Play hurt animation for status tick
	var sprite: Node2D = _entity_sprites.get(entity)
	if sprite:
		DebugLogger.log_info("Anim: %s -> play_hurt (status tick: %s, dmg=%d)" % [entity.entity_name, status_name, damage], "BattleAnim")
		sprite.play_hurt_animation()
		await sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> hurt finished (status tick)" % entity.entity_name, "BattleAnim")

	_refresh_all_ui()


# === Player Input ===

func _on_action_chosen(action_type: int, skill: SkillData, target_type: int, item: ItemData) -> void:
	# If already selecting a target, cancel that first then handle the new action
	if _state == BattleState.TARGET_SELECT:
		_clear_target_highlights()
		_clear_pending_action()
		_state = BattleState.PLAYER_ACTION
		_target_prompt.visible = false
	if _state != BattleState.PLAYER_ACTION:
		DebugLogger.log_warn("Action chosen but state is %s, ignoring" % BattleState.keys()[_state], "Battle")
		return

	var action_name: String = Enums.CombatAction.keys()[action_type] if action_type < Enums.CombatAction.size() else str(action_type)
	var skill_name: String = skill.display_name if skill else "none"
	DebugLogger.log_info("Player chose action: %s, skill: %s, target_type: %d" % [action_name, skill_name, target_type], "Battle")

	match action_type:
		Enums.CombatAction.DEFEND:
			_action_menu.show_disabled()
			_combat_manager.execute_defend(_combat_manager.current_entity)
			_advance_after_action()

		Enums.CombatAction.FLEE:
			_action_menu.show_disabled()
			_combat_manager.execute_flee()

		Enums.CombatAction.ATTACK:
			_pending_action_type = action_type
			_pending_skill = null
			_pending_target_type = target_type
			_pending_item = null
			_enter_target_selection()

		Enums.CombatAction.SKILL:
			if skill:
				_pending_action_type = action_type
				_pending_skill = skill
				_pending_target_type = target_type
				_pending_item = null
				_enter_target_selection()

		Enums.CombatAction.ITEM:
			if skill:
				_pending_action_type = action_type
				_pending_skill = skill
				_pending_target_type = target_type
				_pending_item = item
				_enter_target_selection()


func _enter_target_selection() -> void:
	_state = BattleState.TARGET_SELECT

	match _pending_target_type:
		Enums.TargetType.SINGLE_ENEMY:
			DebugLogger.log_info("State -> TARGET_SELECT (single enemy)", "Battle")
		Enums.TargetType.SINGLE_ALLY:
			DebugLogger.log_info("State -> TARGET_SELECT (single ally)", "Battle")
		Enums.TargetType.SELF:
			DebugLogger.log_info("State -> TARGET_SELECT (self)", "Battle")
		Enums.TargetType.ALL_ENEMIES:
			DebugLogger.log_info("State -> TARGET_SELECT (all enemies)", "Battle")
		Enums.TargetType.ALL_ALLIES:
			DebugLogger.log_info("State -> TARGET_SELECT (all allies)", "Battle")
		_:
			DebugLogger.log_info("State -> TARGET_SELECT (unknown)", "Battle")


func _on_entity_bar_input(event: InputEvent, entity: CombatEntity) -> void:
	if _state != BattleState.TARGET_SELECT:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	var targets: Array = _get_targets_for_hover(entity)
	if targets.is_empty():
		DebugLogger.log_info("Click on invalid target: %s" % entity.entity_name, "Battle")
		return

	DebugLogger.log_info("Target confirmed: %s (affecting %d targets)" % [entity.entity_name, targets.size()], "Battle")
	_execute_player_action(targets)


func _on_sprite_clicked(entity: CombatEntity) -> void:
	## Handle clicks on battlefield sprites (same logic as entity bar clicks).
	if _state != BattleState.TARGET_SELECT:
		return

	var targets: Array = _get_targets_for_hover(entity)
	if targets.is_empty():
		DebugLogger.log_info("Click on invalid target sprite: %s" % entity.entity_name, "Battle")
		return

	DebugLogger.log_info("Target confirmed via sprite: %s (affecting %d targets)" % [entity.entity_name, targets.size()], "Battle")
	_execute_player_action(targets)


func _on_entity_bar_mouse_entered(entity: CombatEntity) -> void:
	if _state != BattleState.TARGET_SELECT:
		return
	_update_target_highlights(entity)


func _on_entity_bar_mouse_exited(_entity: CombatEntity) -> void:
	if _state != BattleState.TARGET_SELECT:
		return
	_clear_target_highlights()


func _get_targets_for_hover(hovered_entity: CombatEntity) -> Array:
	if hovered_entity.is_dead:
		return []

	match _pending_target_type:
		Enums.TargetType.SINGLE_ENEMY:
			if not hovered_entity.is_player:
				return [hovered_entity]
			return []

		Enums.TargetType.SINGLE_ALLY:
			if hovered_entity.is_player:
				return [hovered_entity]
			return []

		Enums.TargetType.SELF:
			return [_combat_manager.current_entity]

		Enums.TargetType.ALL_ENEMIES:
			if not hovered_entity.is_player:
				return _combat_manager.get_alive_enemies()
			return []

		Enums.TargetType.ALL_ALLIES:
			if hovered_entity.is_player:
				return _combat_manager.get_alive_players()
			return []

		_:
			return []


func _update_target_highlights(hovered_entity: CombatEntity) -> void:
	_clear_target_highlights()

	var targets: Array = _get_targets_for_hover(hovered_entity)
	if targets.is_empty():
		var hover_bar: PanelContainer = _entity_bars.get(hovered_entity)
		if hover_bar:
			hover_bar.set_highlight(hover_bar.HighlightType.INVALID)
		var hover_sprite: Node2D = _entity_sprites.get(hovered_entity)
		if hover_sprite:
			hover_sprite.set_highlight(false)
		return

	for i in range(targets.size()):
		var target: CombatEntity = targets[i]
		var bar: PanelContainer = _entity_bars.get(target)
		if bar:
			if target == hovered_entity:
				bar.set_highlight(bar.HighlightType.PRIMARY)
			else:
				bar.set_highlight(bar.HighlightType.SECONDARY)

		var sprite: Node2D = _entity_sprites.get(target)
		if sprite:
			sprite.set_highlight(target == hovered_entity)


func _clear_target_highlights() -> void:
	var keys: Array = _entity_bars.keys()
	for i in range(keys.size()):
		var entity: CombatEntity = keys[i]
		var bar: PanelContainer = _entity_bars[entity]
		bar.set_highlight(bar.HighlightType.NONE)

		var sprite: Node2D = _entity_sprites.get(entity)
		if sprite:
			sprite.set_highlight(false)


func _unhandled_input(event: InputEvent) -> void:
	if _state == BattleState.TARGET_SELECT:
		if event.is_action_pressed("escape") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			DebugLogger.log_info("Target selection cancelled by player", "Battle")
			_cancel_target_selection()
			get_viewport().set_input_as_handled()


func _cancel_target_selection() -> void:
	_clear_target_highlights()
	_clear_pending_action()
	_state = BattleState.PLAYER_ACTION
	_target_prompt.visible = false
	DebugLogger.log_info("State -> PLAYER_ACTION (target cancelled)", "Battle")
	_action_menu.show_for_entity(_combat_manager.current_entity, _encounter_data.can_flee)


func _execute_player_action(targets: Array) -> void:
	_clear_target_highlights()
	_target_prompt.visible = false
	_action_menu.show_disabled()
	_state = BattleState.ANIMATING
	var target_names: String = ", ".join(targets.map(func(t: CombatEntity) -> String: return t.entity_name))
	DebugLogger.log_info("State -> ANIMATING: executing player action on [%s]" % target_names, "Battle")

	var source: CombatEntity = _combat_manager.current_entity

	# Step 1: Play attacker animation and wait
	var attacker_sprite: Node2D = _entity_sprites.get(source)
	if attacker_sprite:
		DebugLogger.log_info("Anim: %s -> play_attack (pos=%s)" % [source.entity_name, str(attacker_sprite.position)], "BattleAnim")
		attacker_sprite.play_attack_animation()
		await attacker_sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> attack finished" % source.entity_name, "BattleAnim")
	else:
		DebugLogger.log_warn("Anim: no sprite found for attacker %s" % source.entity_name, "BattleAnim")

	# Step 2: Execute combat logic
	var result: Dictionary
	match _pending_action_type:
		Enums.CombatAction.ATTACK:
			if not targets.is_empty():
				result = _combat_manager.execute_attack(source, targets[0])
				_spawn_damage_popup(targets[0], result)
				# Spawn popups for AoE splash targets
				var splash_results: Array = result.get("splash_results", [])
				for s_r in splash_results:
					var splash_popup_result: Dictionary = {"actual_damage": s_r.damage, "is_crit": s_r.is_crit}
					_spawn_damage_popup(s_r.target, splash_popup_result)
				# Step 3: Play target reaction
				await _play_target_reactions(targets, result)

		Enums.CombatAction.SKILL:
			if _pending_skill:
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)
				await _play_target_reactions_from_results(result)

		Enums.CombatAction.ITEM:
			if _pending_skill:
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)
				await _play_target_reactions_from_results(result)

				# Remove item from character's grid inventory
				if _pending_item and source.grid_inventory and source.character_data:
					var char_id: String = source.character_data.id
					var placed_items: Array = source.grid_inventory.get_all_placed_items()
					for j in range(placed_items.size()):
						var placed: GridInventory.PlacedItem = placed_items[j]
						if placed.item_data == _pending_item:
							source.grid_inventory.remove_item(placed)
							EventBus.item_removed.emit(char_id, _pending_item, placed.grid_position)
							EventBus.inventory_changed.emit(char_id)
							DebugLogger.log_info("Consumed item: %s from grid inventory" % _pending_item.display_name, "Battle")
							break

	_clear_pending_action()
	_advance_after_action()


# === Animation Helpers ===

func _play_hurt_animation_for(target: CombatEntity, dmg: int) -> void:
	## Play hurt animation on a single target if it took damage.
	if dmg <= 0:
		DebugLogger.log_info("Anim: %s took 0 damage, skipping hurt anim" % target.entity_name, "BattleAnim")
		return
	var sprite: Node2D = _entity_sprites.get(target)
	if sprite and not target.is_dead:
		DebugLogger.log_info("Anim: %s -> play_hurt (dmg=%d, pos=%s)" % [target.entity_name, dmg, str(sprite.position)], "BattleAnim")
		sprite.play_hurt_animation()
		await sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> hurt finished" % target.entity_name, "BattleAnim")
	elif not sprite:
		DebugLogger.log_warn("Anim: no sprite found for hurt target %s" % target.entity_name, "BattleAnim")


func _play_target_reactions(targets: Array, result: Dictionary) -> void:
	## Play hurt animation on single-target attack results.
	if targets.is_empty():
		return
	var target: CombatEntity = targets[0]
	var dmg: int = result.get("damage", result.get("actual_damage", 0))
	await _play_hurt_animation_for(target, dmg)


func _play_target_reactions_from_results(result: Dictionary) -> void:
	## Play hurt/heal animations from multi-target skill results.
	var target_results: Array = result.get("target_results", [])
	DebugLogger.log_info("Anim: processing %d target reactions from skill results" % target_results.size(), "BattleAnim")
	for i in range(target_results.size()):
		var target_result: Dictionary = target_results[i]
		var target: CombatEntity = target_result.target
		var dmg: int = target_result.get("damage", target_result.get("actual_damage", 0))
		await _play_hurt_animation_for(target, dmg)


# === Enemy Turn ===

func _execute_enemy_turn(entity: CombatEntity) -> void:
	var alive_players: Array = _combat_manager.get_alive_players()
	DebugLogger.log_info("Enemy AI deciding for %s (%d alive player targets)" % [entity.entity_name, alive_players.size()], "Battle")
	var decision: Dictionary = EnemyAI.choose_action(entity, alive_players)

	_state = BattleState.ANIMATING
	var action_type: int = decision.action
	var skill: SkillData = decision.skill
	var targets: Array = decision.targets
	var target_names: String = ", ".join(targets.map(func(t: CombatEntity) -> String: return t.entity_name))
	var action_name: String = Enums.CombatAction.keys()[action_type] if action_type < Enums.CombatAction.size() else str(action_type)
	var skill_name: String = skill.display_name if skill else "none"
	DebugLogger.log_info("Enemy AI chose: %s, skill: %s, targets: [%s]" % [action_name, skill_name, target_names], "Battle")

	# Step 1: Play enemy attack animation
	var enemy_sprite: Node2D = _entity_sprites.get(entity)
	if enemy_sprite:
		DebugLogger.log_info("Anim: %s -> play_attack (pos=%s)" % [entity.entity_name, str(enemy_sprite.position)], "BattleAnim")
		enemy_sprite.play_attack_animation()
		await enemy_sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> attack finished" % entity.entity_name, "BattleAnim")
	else:
		DebugLogger.log_warn("Anim: no sprite found for enemy attacker %s" % entity.entity_name, "BattleAnim")

	# Step 2: Execute combat logic
	match action_type:
		Enums.CombatAction.ATTACK:
			if not targets.is_empty():
				var result: Dictionary = _combat_manager.execute_attack(entity, targets[0])
				_spawn_damage_popup(targets[0], result)
				await _play_target_reactions(targets, result)

		Enums.CombatAction.SKILL:
			if skill:
				var result: Dictionary = _combat_manager.execute_skill(entity, skill, targets)
				_spawn_popups_for_results(result)
				await _play_target_reactions_from_results(result)

		Enums.CombatAction.DEFEND:
			_combat_manager.execute_defend(entity)

	_advance_after_action()


# === Flow Control ===

func _advance_after_action() -> void:
	_refresh_all_ui()
	if _combat_manager.is_combat_active:
		DebugLogger.log_info("Waiting %.1fs before next turn..." % ACTION_DELAY, "Battle")
		await get_tree().create_timer(ACTION_DELAY).timeout
		if _combat_manager.is_combat_active:
			_combat_manager.advance_turn()
		else:
			DebugLogger.log_info("Combat ended during action delay", "Battle")
	else:
		DebugLogger.log_info("Combat no longer active after action", "Battle")


# === Damage Popups ===

func _spawn_popups_for_results(result: Dictionary) -> void:
	var target_results: Array = result.get("target_results", [])
	for i in range(target_results.size()):
		var target_result: Dictionary = target_results[i]
		var target: CombatEntity = target_result.target
		_spawn_damage_popup(target, target_result)


func _spawn_damage_popup(target: CombatEntity, result: Dictionary) -> void:
	if not _entity_bars.has(target):
		return

	var amount: int = result.get("damage", result.get("actual_damage", result.get("heal", 0)))
	var popup_type: Enums.PopupType = Enums.PopupType.DAMAGE

	if result.has("heal"):
		popup_type = Enums.PopupType.HEAL
	elif result.get("is_crit", false):
		popup_type = Enums.PopupType.CRIT

	DebugLogger.log_info("Popup: %s on %s (%d)" % [Enums.PopupType.keys()[popup_type], target.entity_name, amount], "Battle")
	_spawn_popup_at_entity(target, amount, popup_type)


func _save_player_vitals(victory: bool = false) -> void:
	if not _combat_manager or not GameManager.party:
		return

	for i in range(_combat_manager.player_entities.size()):
		var entity: CombatEntity = _combat_manager.player_entities[i]
		if entity.character_data:
			var char_id: String = entity.character_data.id
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
			# On victory, revive KO'd characters at 1 HP so they're ready for the next fight
			var saved_hp: int = entity.current_hp
			if victory and entity.is_dead:
				saved_hp = 1
			GameManager.party.set_current_hp(char_id, saved_hp, tree)
			GameManager.party.set_current_mp(char_id, entity.current_mp, tree)
			DebugLogger.log_info("Saved vitals for %s: HP %d/%d, MP %d/%d%s" % [
				entity.entity_name,
				saved_hp,
				entity.max_hp,
				entity.current_mp,
				entity.max_mp,
				" (revived)" if victory and entity.is_dead else "",
			], "Battle")


func _show_defeat_screen() -> void:
	## Shows a fullscreen overlay with Main Menu / Load Save / Quit buttons.
	var canvas := CanvasLayer.new()
	canvas.layer = 20
	add_child(canvas)

	var blocker := ColorRect.new()
	blocker.color = Color(0.0, 0.0, 0.0, 0.75)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	blocker.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(blocker)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(center)

	var panel := PanelContainer.new()
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 48)
	margin.add_theme_constant_override("margin_right", 48)
	margin.add_theme_constant_override("margin_top", 36)
	margin.add_theme_constant_override("margin_bottom", 36)
	panel.add_child(margin)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	vbox.custom_minimum_size = Vector2(280, 0)
	margin.add_child(vbox)

	var title_lbl := Label.new()
	title_lbl.text = "Defeat"
	title_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_lbl.add_theme_font_size_override("font_size", 28)
	title_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	vbox.add_child(title_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = "Your party has fallen."
	sub_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub_lbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.75))
	vbox.add_child(sub_lbl)

	vbox.add_child(HSeparator.new())

	var main_menu_btn := Button.new()
	main_menu_btn.text = "Main Menu"
	main_menu_btn.pressed.connect(func() -> void:
		SceneManager.clear_stack()
		SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")
	)
	vbox.add_child(main_menu_btn)

	var load_btn := Button.new()
	load_btn.text = "Load Save"
	load_btn.disabled = not SaveManager.has_any_save()
	load_btn.pressed.connect(func() -> void:
		SceneManager.clear_stack()
		SceneManager.replace_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})
	)
	vbox.add_child(load_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit Game"
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	vbox.add_child(quit_btn)


func _spawn_popup_at_entity(entity: CombatEntity, amount: int, popup_type: Enums.PopupType) -> void:
	if not _entity_bars.has(entity):
		return

	var bar: PanelContainer = _entity_bars[entity]
	var popup: Label = DamagePopupScene.instantiate()
	_popup_layer.add_child(popup)
	popup.global_position = bar.get_global_center() + Vector2(randf_range(-20, 20), -10)
	popup.setup(amount, popup_type)
