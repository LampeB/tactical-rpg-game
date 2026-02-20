extends Control
## Battle scene orchestrator. Manages combat flow, UI updates, and player input.

enum BattleState { INIT, PLAYER_ACTION, TARGET_SELECT, ENEMY_ACTION, ANIMATING, VICTORY, DEFEAT }

const EntityStatusBarScene: PackedScene = preload("res://scenes/battle/ui/entity_status_bar.tscn")
const DamagePopupScene: PackedScene = preload("res://scenes/battle/ui/damage_popup.tscn")

const LootGeneratorScript = preload("res://scripts/systems/loot/loot_generator.gd")

const ACTION_DELAY: float = 0.6  ## Seconds between actions for readability
const BATTLE_START_DELAY: float = 0.5  ## Delay before first turn
const VICTORY_DELAY: float = 1.5  ## Pause before victory screen
const DEFEAT_DELAY: float = 2.0  ## Pause before defeat screen

# --- Child references ---
@onready var _title: Label = $MainLayout/TopBar/MarginContainer/HBox/Title
@onready var _round_label: Label = $MainLayout/TopBar/MarginContainer/HBox/RoundLabel
@onready var _turn_order_bar: HBoxContainer = $MainLayout/TurnOrderSection/TurnOrderBar
@onready var _enemy_list: VBoxContainer = $MainLayout/BattleField/HBox/EnemyPanel/EnemyList
@onready var _party_list: VBoxContainer = $MainLayout/BattleField/HBox/PartyPanel/PartyList
@onready var _target_prompt: HBoxContainer = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt
@onready var _target_prompt_label: Label = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt/Label
@onready var _target_cancel_btn: Button = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt/CancelButton
@onready var _action_menu: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/ActionMenu
@onready var _battle_log: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/BattleLog
@onready var _popup_layer: CanvasLayer = $PopupLayer

# --- State ---
var _encounter_data: EncounterData
var _combat_manager: CombatManager
var _state: BattleState = BattleState.INIT

# Entity -> UI bar mapping
var _entity_bars: Dictionary = {}  ## CombatEntity -> EntityStatusBar node
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory

# Target selection
var _pending_action_type: int = -1
var _pending_skill: SkillData = null
var _pending_target_type: int = -1
var _pending_item: ItemData = null


func _clear_pending_action() -> void:
	_pending_action_type = -1
	_pending_skill = null
	_pending_target_type = -1
	_pending_item = null


func _ready() -> void:
	_action_menu.hide_menu()
	_action_menu.action_chosen.connect(_on_action_chosen)
	_target_prompt.visible = false
	_target_cancel_btn.pressed.connect(_cancel_target_selection)
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
	DebugLogger.log_info("_start_battle called", "Battle")
	if not _encounter_data:
		DebugLogger.log_error("No encounter data!", "Battle")
		return

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
				var tree = PassiveTreeDatabase.get_passive_tree(character_id)
				var passive_bonuses: Dictionary = GameManager.party.get_passive_bonuses(character_id, tree)

				# Load current HP/MP from persistent vitals
				var starting_hp: int = GameManager.party.get_current_hp(character_id)
				var starting_mp: int = GameManager.party.get_current_mp(character_id)

				var entity: CombatEntity = CombatEntity.from_character(char_data, inv, passive_bonuses, starting_hp, starting_mp)
				player_entities.append(entity)
				var skill_count: int = entity.get_available_skills().size()
				DebugLogger.log_info("  Player: %s — HP:%d/%d MP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f Skills:%d Inv:%s" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.current_mp, entity.max_mp, entity.get_effective_stat(Enums.Stat.SPEED), entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), skill_count, str(inv != null)], "Battle")
			else:
				DebugLogger.log_warn("Character ID '%s' not found in roster" % character_id, "Battle")
	else:
		DebugLogger.log_warn("No party data available!", "Battle")

	# Build enemy entities from encounter
	var enemy_entities: Array = []
	DebugLogger.log_info("Building %d enemy entities" % _encounter_data.enemies.size(), "Battle")
	for i in range(_encounter_data.enemies.size()):
		var e_data = _encounter_data.enemies[i]
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
			DebugLogger.log_info("  Enemy: %s — HP:%d/%d SPD:%.0f ATK:%.0f DEF:%.0f Skills:%d" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.get_effective_stat(Enums.Stat.SPEED), entity.get_effective_stat(Enums.Stat.PHYSICAL_ATTACK), entity.get_effective_stat(Enums.Stat.PHYSICAL_DEFENSE), skill_count], "Battle")

	# Build UI bars
	DebugLogger.log_info("Building UI bars (%d enemies, %d players)" % [enemy_entities.size(), player_entities.size()], "Battle")
	_build_entity_bars(player_entities, enemy_entities)

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


# === UI Building ===

func _add_entity_bar(entity: CombatEntity, container: VBoxContainer) -> void:
	var bar: PanelContainer = EntityStatusBarScene.instantiate()
	container.add_child(bar)
	bar.setup(entity)
	bar.gui_input.connect(_on_entity_bar_input.bind(entity))
	bar.mouse_entered.connect(_on_entity_bar_mouse_entered.bind(entity))
	bar.mouse_exited.connect(_on_entity_bar_mouse_exited.bind(entity))
	_entity_bars[entity] = bar


func _build_entity_bars(players: Array, enemies: Array) -> void:
	for child in _enemy_list.get_children():
		child.queue_free()
	for child in _party_list.get_children():
		child.queue_free()
	_entity_bars.clear()

	for i in range(enemies.size()):
		_add_entity_bar(enemies[i], _enemy_list)

	for i in range(players.size()):
		_add_entity_bar(players[i], _party_list)


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
		for i in range(keys.size()):
			var entity: CombatEntity = keys[i]
			var bar: PanelContainer = _entity_bars[entity]
			bar.highlight(entity == _combat_manager.current_entity)


# === Combat Manager Callbacks ===

func _on_turn_ready(entity: CombatEntity) -> void:
	_refresh_all_ui()

	if entity.is_player:
		_state = BattleState.PLAYER_ACTION
		DebugLogger.log_info("State -> PLAYER_ACTION: %s (HP:%d/%d MP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.current_mp, entity.max_mp], "Battle")
		var skills: Array = entity.get_available_skills()
		var skill_names: String = ", ".join(skills.map(func(s: SkillData) -> String: return s.display_name)) if not skills.is_empty() else "none"
		DebugLogger.log_info("  Skills: [%s], can_flee: %s" % [skill_names, str(_encounter_data.can_flee)], "Battle")
		_action_menu.show_for_entity(entity, _encounter_data.can_flee)
	else:
		_state = BattleState.ENEMY_ACTION
		DebugLogger.log_info("State -> ENEMY_ACTION: %s (HP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp], "Battle")
		_action_menu.hide_menu()
		await get_tree().create_timer(ACTION_DELAY).timeout
		_execute_enemy_turn(entity)


func _on_action_resolved(_results: Dictionary) -> void:
	_refresh_all_ui()


func _on_combat_finished(victory: bool) -> void:
	_action_menu.hide_menu()
	_target_prompt.visible = false

	# Save player HP/MP back to persistent vitals
	_save_player_vitals()

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
			SceneManager.pop_scene()
	else:
		_state = BattleState.DEFEAT
		_title.text = "Defeat..."
		DebugLogger.log_info("State -> DEFEAT", "Battle")
		EventBus.combat_ended.emit(false)
		await get_tree().create_timer(DEFEAT_DELAY).timeout
		DebugLogger.log_info("Returning to previous scene after defeat", "Battle")
		SceneManager.pop_scene()


func _on_entity_died(entity: CombatEntity) -> void:
	DebugLogger.log_info("Entity died: %s (is_player: %s)" % [entity.entity_name, str(entity.is_player)], "Battle")
	_refresh_all_ui()


func _on_log_message(text: String, color: Color) -> void:
	_battle_log.add_message(text, color)
	DebugLogger.log_info("[CombatLog] %s" % text, "Battle")


func _on_status_ticked(entity: CombatEntity, damage: int, status_name: String) -> void:
	DebugLogger.log_info("Status tick on %s: %d damage from %s (HP now: %d/%d)" % [entity.entity_name, damage, status_name, entity.current_hp, entity.max_hp], "Battle")
	_spawn_popup_at_entity(entity, damage, Enums.PopupType.DAMAGE)
	_refresh_all_ui()


# === Player Input ===

func _on_action_chosen(action_type: int, skill: SkillData, target_type: int, item: ItemData) -> void:
	if _state != BattleState.PLAYER_ACTION:
		DebugLogger.log_warn("Action chosen but state is %s, ignoring" % BattleState.keys()[_state], "Battle")
		return

	var action_name: String = Enums.CombatAction.keys()[action_type] if action_type < Enums.CombatAction.size() else str(action_type)
	var skill_name: String = skill.display_name if skill else "none"
	DebugLogger.log_info("Player chose action: %s, skill: %s, target_type: %d" % [action_name, skill_name, target_type], "Battle")

	match action_type:
		Enums.CombatAction.DEFEND:
			_action_menu.hide_menu()
			_combat_manager.execute_defend(_combat_manager.current_entity)
			_advance_after_action()

		Enums.CombatAction.FLEE:
			_action_menu.hide_menu()
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
				# All skills go through target selection/confirmation for consistency
				_enter_target_selection()

		Enums.CombatAction.ITEM:
			if skill:
				_pending_action_type = action_type
				_pending_skill = skill
				_pending_target_type = target_type
				_pending_item = item
				# Items use their use_skill for targeting, same flow as skills
				_enter_target_selection()


func _enter_target_selection() -> void:
	_state = BattleState.TARGET_SELECT
	_action_menu.hide_menu()
	_target_prompt.visible = true

	# Simpler prompts - hover shows affected targets
	var skill_name: String = _pending_skill.display_name if _pending_skill else "action"
	match _pending_target_type:
		Enums.TargetType.SINGLE_ENEMY:
			_target_prompt_label.text = "%s — Select an enemy" % skill_name
			DebugLogger.log_info("State -> TARGET_SELECT (single enemy)", "Battle")
		Enums.TargetType.SINGLE_ALLY:
			_target_prompt_label.text = "%s — Select an ally" % skill_name
			DebugLogger.log_info("State -> TARGET_SELECT (single ally)", "Battle")
		Enums.TargetType.SELF:
			_target_prompt_label.text = "%s — Click to use on yourself" % skill_name
			DebugLogger.log_info("State -> TARGET_SELECT (self)", "Battle")
		Enums.TargetType.ALL_ENEMIES:
			var count: int = _combat_manager.get_alive_enemies().size()
			_target_prompt_label.text = "%s — Targets all enemies (%d)" % [skill_name, count]
			DebugLogger.log_info("State -> TARGET_SELECT (all enemies)", "Battle")
		Enums.TargetType.ALL_ALLIES:
			var count: int = _combat_manager.get_alive_players().size()
			_target_prompt_label.text = "%s — Targets all allies (%d)" % [skill_name, count]
			DebugLogger.log_info("State -> TARGET_SELECT (all allies)", "Battle")
		_:
			_target_prompt_label.text = "%s — Select a target" % skill_name
			DebugLogger.log_info("State -> TARGET_SELECT (unknown)", "Battle")


func _on_entity_bar_input(event: InputEvent, entity: CombatEntity) -> void:
	if _state != BattleState.TARGET_SELECT:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return

	# Get targets based on hovered entity and skill type
	var targets: Array = _get_targets_for_hover(entity)
	if targets.is_empty():
		DebugLogger.log_info("Click on invalid target: %s" % entity.entity_name, "Battle")
		return

	DebugLogger.log_info("Target confirmed: %s (affecting %d targets)" % [entity.entity_name, targets.size()], "Battle")
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
	"""Returns array of entities that would be affected if clicking on hovered_entity."""
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
			# Self targets always hit the current entity, regardless of hover
			return [_combat_manager.current_entity]

		Enums.TargetType.ALL_ENEMIES:
			# Must hover an enemy to confirm
			if not hovered_entity.is_player:
				return _combat_manager.get_alive_enemies()
			return []

		Enums.TargetType.ALL_ALLIES:
			# Must hover an ally to confirm
			if hovered_entity.is_player:
				return _combat_manager.get_alive_players()
			return []

		_:
			return []


func _update_target_highlights(hovered_entity: CombatEntity) -> void:
	"""Highlight targets that would be affected by clicking on hovered_entity."""
	_clear_target_highlights()

	var targets: Array = _get_targets_for_hover(hovered_entity)
	if targets.is_empty():
		# Invalid target - show red
		var bar: PanelContainer = _entity_bars.get(hovered_entity)
		if bar:
			bar.set_highlight(bar.HighlightType.INVALID)
		return

	# Highlight all affected targets
	for i in range(targets.size()):
		var target: CombatEntity = targets[i]
		var bar: PanelContainer = _entity_bars.get(target)
		if bar:
			# Primary highlight for the hovered one, secondary for others
			if target == hovered_entity:
				bar.set_highlight(bar.HighlightType.PRIMARY)
			else:
				bar.set_highlight(bar.HighlightType.SECONDARY)


func _clear_target_highlights() -> void:
	"""Remove all target highlighting."""
	var keys: Array = _entity_bars.keys()
	for i in range(keys.size()):
		var entity: CombatEntity = keys[i]
		var bar: PanelContainer = _entity_bars[entity]
		bar.set_highlight(bar.HighlightType.NONE)


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
	_action_menu.hide_menu()
	_state = BattleState.ANIMATING
	var target_names: String = ", ".join(targets.map(func(t: CombatEntity) -> String: return t.entity_name))
	DebugLogger.log_info("State -> ANIMATING: executing player action on [%s]" % target_names, "Battle")

	var source: CombatEntity = _combat_manager.current_entity
	var result: Dictionary

	match _pending_action_type:
		Enums.CombatAction.ATTACK:
			if not targets.is_empty():
				result = _combat_manager.execute_attack(source, targets[0])
				_spawn_damage_popup(targets[0], result)
		Enums.CombatAction.SKILL:
			if _pending_skill:
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)
		Enums.CombatAction.ITEM:
			if _pending_skill:
				# Execute the item's skill
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)

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

	match action_type:
		Enums.CombatAction.ATTACK:
			if not targets.is_empty():
				var result: Dictionary = _combat_manager.execute_attack(entity, targets[0])
				_spawn_damage_popup(targets[0], result)
		Enums.CombatAction.SKILL:
			if skill:
				var result: Dictionary = _combat_manager.execute_skill(entity, skill, targets)
				_spawn_popups_for_results(result)
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


func _save_player_vitals() -> void:
	## Save current HP/MP from player entities back to persistent Party vitals
	if not _combat_manager or not GameManager.party:
		return

	for i in range(_combat_manager.player_entities.size()):
		var entity: CombatEntity = _combat_manager.player_entities[i]
		if entity.character_data:
			var char_id: String = entity.character_data.id
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree(char_id)
			GameManager.party.set_current_hp(char_id, entity.current_hp, tree)
			GameManager.party.set_current_mp(char_id, entity.current_mp, tree)
			DebugLogger.log_info("Saved vitals for %s: HP %d/%d, MP %d/%d" % [
				entity.entity_name,
				entity.current_hp,
				entity.max_hp,
				entity.current_mp,
				entity.max_mp
			], "Battle")


func _spawn_popup_at_entity(entity: CombatEntity, amount: int, popup_type: Enums.PopupType) -> void:
	if not _entity_bars.has(entity):
		return

	var bar: PanelContainer = _entity_bars[entity]
	var popup: Label = DamagePopupScene.instantiate()
	_popup_layer.add_child(popup)
	popup.global_position = bar.get_global_center() + Vector2(randf_range(-20, 20), -10)
	popup.setup(amount, popup_type)
