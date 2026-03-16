extends Control
## Battle scene orchestrator. Manages combat flow, UI updates, and player input.
## Battlefield uses a SubViewport with Node3D CSG models for 3D rendering.

enum BattleState { INIT, PLAYER_ACTION, TARGET_SELECT, ENEMY_ACTION, ANIMATING, VICTORY, DEFEAT }

const EntityStatusBarScene: PackedScene = preload("res://scenes/battle/ui/entity_status_bar.tscn")
const BattleSpriteScene: PackedScene = preload("res://scenes/battle/ui/battle_sprite.tscn")
const DamagePopupScene: PackedScene = preload("res://scenes/battle/ui/damage_popup.tscn")

const LootGeneratorScript = preload("res://scripts/systems/loot/loot_generator.gd")

const ACTION_DELAY: float = 0.6  ## Seconds between actions for readability
const BATTLE_START_DELAY: float = 0.5  ## Delay before first turn
const VICTORY_DELAY: float = 1.5  ## Pause before victory screen
const DEFEAT_DELAY: float = 2.0  ## Pause before defeat screen

# Battle positions in 3D world space
const PLAYER_POSITIONS: Array[Vector3] = [
	Vector3(-3.0, 0, 0.0),
	Vector3(-4.0, 0, 1.0),
	Vector3(-3.5, 0, -1.0),
	Vector3(-5.0, 0, 0.5),
]
const ENEMY_POSITIONS: Array[Vector3] = [
	Vector3(3.0, 0, 0.0),
	Vector3(4.0, 0, 1.0),
	Vector3(3.5, 0, -1.0),
	Vector3(5.0, 0, 0.5),
]

# --- Child references (UI overlay) ---
@onready var _bg: ColorRect = $Background
@onready var _title: Label = $MainLayout/TopBar/MarginContainer/HBox/Title
@onready var _round_label: Label = $MainLayout/TopBar/MarginContainer/HBox/RoundLabel
@onready var _turn_order_bar: PanelContainer = $MainLayout/TurnOrderSection/TurnOrderBar
@onready var _enemy_list: VBoxContainer = $MainLayout/BattleField/FieldLayout/EnemyPortraits/EnemyList
@onready var _party_list: HBoxContainer = $MainLayout/BattleField/FieldLayout/PartyCards/PartyList
@onready var _target_prompt: HBoxContainer = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt
@warning_ignore("unused_private_class_variable")
@onready var _target_prompt_label: Label = $MainLayout/BottomSection/MarginContainer/VBox/TargetPrompt/Label
@onready var _action_menu: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/ActionMenu
@onready var _log_toggle: Button = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/LogSection/LogToggle
@onready var _battle_log: PanelContainer = $MainLayout/BottomSection/MarginContainer/VBox/BottomRow/LogSection/BattleLog
@onready var _popup_layer: CanvasLayer = $PopupLayer

# --- Battlefield (SubViewport) references ---
@onready var _battle_viewport: SubViewportContainer = $MainLayout/BattleField/FieldLayout/BattleViewport
@onready var _sub_viewport: SubViewport = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport
@onready var _battle_world: Node3D = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport/BattleWorld
@onready var _battle_camera: Camera3D = $MainLayout/BattleField/FieldLayout/BattleViewport/SubViewport/BattleWorld/BattleCamera

# --- State ---
var _encounter_data: EncounterData
var _combat_manager: CombatManager
var _state: BattleState = BattleState.INIT

# Entity -> UI mappings
var _entity_bars: Dictionary = {}  ## CombatEntity -> EntityStatusBar node
var _entity_sprites: Dictionary = {}  ## CombatEntity -> BattleSprite (Node3D)
var _entity_slots: Dictionary = {}  ## CombatEntity -> slot index (int)
var _grid_inventories: Dictionary = {}  ## character_id -> GridInventory

# Target selection
var _pending_action_type: int = -1
var _pending_skill: SkillData = null
var _pending_target_type: int = -1
var _pending_item: ItemData = null

# Battle log file recording
var _log_lines: Array[String] = []
const BATTLE_LOG_PATH := "res://battle_log.txt"

# Battle background context
var _fight_position: Vector3 = Vector3.ZERO
var _map_id: String = ""
var _arena_center: Vector3 = Vector3.ZERO  ## World position of the battle arena on the map
var _arena_rotation_y: float = 0.0  ## Y-axis rotation of the battle arena

# Camera positions
var _cam_home_pos: Vector3 = Vector3.ZERO  ## Behind-party camera position (home)
var _cam_home_look: Vector3 = Vector3.ZERO  ## Behind-party look target
var _cam_tween: Tween = null  ## Active camera tween (for cancellation)


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
	if data.has("fight_position"):
		_fight_position = data["fight_position"]
	if data.has("map_id"):
		_map_id = data["map_id"]
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

	# Begin first turn — walk players in while orbiting camera behind party
	var cam_sweep_duration: float = 2.5
	DebugLogger.log_info("Orbiting camera behind party (%.1fs)..." % cam_sweep_duration, "Battle")
	_orbit_camera_to(_cam_home_pos, _cam_home_look, cam_sweep_duration)
	_walk_players_in(player_entities, cam_sweep_duration)
	await get_tree().create_timer(cam_sweep_duration).timeout
	DebugLogger.log_info("Advancing to first turn", "Battle")
	_combat_manager.advance_turn()


func _letter(index: int) -> String:
	return char(65 + index)  # A, B, C...


func _sync_viewport_size() -> void:
	## Set up 3D battle camera, lighting, and background.
	_sub_viewport.physics_object_picking = true

	# Build 3D battle background from map data (once) — must come first to set _arena_center
	if not _battle_world.has_node("BattleBackground") and not _map_id.is_empty():
		# Check for preloaded heightmap battle background first
		var preloaded_bg: Node3D = GameManager.preloaded_battle_bg
		if preloaded_bg:
			_arena_center = GameManager.preloaded_battle_arena_center
			_arena_rotation_y = GameManager.preloaded_battle_arena_rotation
			_battle_world.add_child(preloaded_bg)
			GameManager.preloaded_battle_bg = null  # Consumed — clear reference
			DebugLogger.log_info("Using preloaded battle background at y=%.1f" % _arena_center.y, "BattleView")
		else:
			var map_data: MapData = MapDatabase.get_map(_map_id)
			if map_data:
				var battle_area: BattleAreaData = MapLoader.find_nearest_battle_area(map_data, _fight_position)
				if battle_area:
					_arena_center = battle_area.position
					_arena_rotation_y = battle_area.rotation_y

				# Use heightmap terrain background if available, otherwise legacy GridMap
				var heightmap_data: Resource = GameManager.current_heightmap_data
				if heightmap_data and heightmap_data is HeightmapData:
					var hdata: HeightmapData = heightmap_data as HeightmapData
					# Fall back to fight position if no battle area defined
					if not battle_area:
						_arena_center = _fight_position
						_arena_rotation_y = 0.0
					# Ground arena center to terrain height
					var tscale: Vector3 = hdata.terrain_scale
					var gx: int = clampi(roundi(_arena_center.x / tscale.x), 0, hdata.width - 1)
					var gz: int = clampi(roundi(_arena_center.z / tscale.z), 0, hdata.height - 1)
					_arena_center.y = hdata.get_height_at(gx, gz) * tscale.y
					var bg: Node3D = MapLoader.build_heightmap_battle_background(
						hdata, _arena_center, _arena_rotation_y
					)
					_battle_world.add_child(bg)
					DebugLogger.log_info("Built heightmap battle background at y=%.1f" % _arena_center.y, "BattleView")
				elif battle_area:
					var bg: Node3D = MapLoader.build_battle_background(map_data, battle_area)
					_battle_world.add_child(bg)
					DebugLogger.log_info("Built battle background from area: %s" % battle_area.area_name, "BattleView")

	# Position camera: start at default center view, then orbit behind party
	var default_offset := Vector3(0, 3.5, 8)
	var rotated_default := default_offset.rotated(Vector3.UP, _arena_rotation_y)
	_battle_camera.position = _arena_center + rotated_default
	var default_look := _arena_center + Vector3(0, 0.5, 0)
	_battle_camera.look_at(default_look)
	_battle_camera.fov = 40.0

	# Compute behind-party camera position:
	# Behind the right shoulder of the rightmost player (positive Z), further out and elevated
	var behind_offset := Vector3(-7.0, 4.0, 2.2)
	_cam_home_pos = _arena_center + behind_offset.rotated(Vector3.UP, _arena_rotation_y)
	var look_ahead_offset := Vector3(2.0, 0.6, -0.3)
	_cam_home_look = _arena_center + look_ahead_offset.rotated(Vector3.UP, _arena_rotation_y)
	DebugLogger.log_info("Battle camera at %s, home=%s, fov=%.0f" % [str(_battle_camera.position), str(_cam_home_pos), _battle_camera.fov], "BattleView")

	# Read current day/night state for lighting
	var dn_state: Dictionary = DayNightCycle.get_lighting_state()
	var dn_sun: float = dn_state.get("sun_energy", 1.2)
	var sun_ratio: float = dn_sun / 1.2  # 0.0 at night, 1.0 at noon
	DayNightCycle.paused = true  # Freeze time during battle

	# Add directional light (once)
	if not _battle_world.has_node("BattleLight"):
		var light := DirectionalLight3D.new()
		light.name = "BattleLight"
		light.rotation_degrees = Vector3(dn_state.get("sun_pitch", -45.0), dn_state.get("sun_yaw", 30.0), 0)
		light.light_energy = maxf(dn_state.get("sun_energy", 1.0), 0.15)
		light.light_color = dn_state.get("sun_color", Color(1.0, 0.96, 0.88))
		light.shadow_enabled = false
		_battle_world.add_child(light)

	# Add moon light for night battles (once)
	if not _battle_world.has_node("BattleMoon"):
		var moon_energy: float = dn_state.get("moon_energy", 0.0)
		if moon_energy > 0.01:
			var moon := DirectionalLight3D.new()
			moon.name = "BattleMoon"
			moon.rotation_degrees = Vector3(dn_state.get("moon_pitch", -45.0), dn_state.get("moon_yaw", 90.0), 0)
			moon.light_energy = moon_energy
			moon.light_color = Color(0.7, 0.75, 0.9)
			moon.shadow_enabled = false
			_battle_world.add_child(moon)

	# Add environment with ambient light (once)
	if not _battle_world.has_node("BattleEnv"):
		var base_bg := Color(0.15, 0.12, 0.2)
		var night_bg := Color(0.03, 0.02, 0.06)
		var bg_color: Color = night_bg.lerp(base_bg, sun_ratio)

		var base_fog := Color(0.2, 0.18, 0.25)
		var night_fog := Color(0.05, 0.04, 0.08)
		var fog_color: Color = night_fog.lerp(base_fog, sun_ratio)

		var env := Environment.new()
		env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.ambient_light_color = dn_state.get("ambient_color", Color(0.4, 0.4, 0.5))
		env.ambient_light_energy = maxf(dn_state.get("ambient_energy", 0.4) * 2.0, 0.3)
		env.background_mode = Environment.BG_COLOR
		env.background_color = bg_color
		env.fog_enabled = true
		env.fog_light_color = fog_color
		env.fog_density = 0.03
		var world_env := WorldEnvironment.new()
		world_env.name = "BattleEnv"
		world_env.environment = env
		_battle_world.add_child(world_env)


# === Camera ===

func _shake_camera(intensity: float = 0.15, duration: float = 0.3) -> void:
	## Shake the battle camera for impact effects, snapping back to home position.
	if not _battle_camera:
		return
	var base_pos: Vector3 = _cam_home_pos if _cam_home_pos != Vector3.ZERO else _battle_camera.position
	var tween := create_tween()
	var steps: int = int(duration / 0.04)
	for i in range(steps):
		var offset := Vector3(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity),
			randf_range(-intensity * 0.5, intensity * 0.5)
		)
		tween.tween_property(_battle_camera, "position", base_pos + offset, 0.04)
	tween.tween_property(_battle_camera, "position", base_pos, 0.04)


func _move_camera_to(target_pos: Vector3, look_at_pos: Vector3, duration: float = 0.5) -> void:
	## Smoothly move the camera to a new position while re-orienting to look at a target.
	if not _battle_camera:
		return
	# Kill any active camera tween to avoid conflicts
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()

	# We tween position directly. For look_at, we interpolate the look target
	# by tweening a helper variable and calling look_at each step.
	var start_pos: Vector3 = _battle_camera.position
	# Approximate current look direction as a point in front of the camera
	var start_look: Vector3 = _battle_camera.global_position + (-_battle_camera.global_transform.basis.z * 5.0)

	_cam_tween = create_tween()
	_cam_tween.set_ease(Tween.EASE_IN_OUT)
	_cam_tween.set_trans(Tween.TRANS_CUBIC)

	# Use a simple approach: tween position, update look_at via method tweening
	var steps: int = int(duration / 0.03)
	if steps < 2:
		steps = 2
	var step_time: float = duration / steps
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		var pos: Vector3 = start_pos.lerp(target_pos, t)
		var look: Vector3 = start_look.lerp(look_at_pos, t)
		_cam_tween.tween_callback(_set_camera_pose.bind(pos, look))
		if i < steps:
			_cam_tween.tween_interval(step_time)


func _orbit_camera_to(target_pos: Vector3, _look_at_pos: Vector3, duration: float = 1.5) -> void:
	## Move the camera along a circular arc around the arena center to the target position.
	if not _battle_camera:
		return
	if _cam_tween and _cam_tween.is_valid():
		_cam_tween.kill()

	var start_pos: Vector3 = _battle_camera.position

	# Compute polar coordinates (angle, radius, height) relative to arena center
	var start_offset: Vector3 = start_pos - _arena_center
	var end_offset: Vector3 = target_pos - _arena_center

	var start_angle: float = atan2(start_offset.x, start_offset.z)
	var start_radius: float = Vector2(start_offset.x, start_offset.z).length()
	var start_height: float = start_offset.y

	var end_angle: float = atan2(end_offset.x, end_offset.z)
	var end_radius: float = Vector2(end_offset.x, end_offset.z).length()
	var end_height: float = end_offset.y

	# Force clockwise sweep (positive angle direction) for dramatic orbit
	var angle_diff: float = end_angle - start_angle
	# Always take the long way around: force positive (clockwise) direction
	while angle_diff < 0.0:
		angle_diff += TAU
	# If the arc ended up very small (< 90°), go the other way for a longer sweep
	if angle_diff < PI * 0.5:
		angle_diff += TAU

	_cam_tween = create_tween()

	# Apply easing manually via smoothstep since tween easing only affects intervals
	var steps: int = int(duration / 0.025)
	if steps < 2:
		steps = 2
	var step_time: float = duration / steps
	for i in range(steps + 1):
		var t: float = float(i) / float(steps)
		# Smoothstep for ease-in-out feel on the arc itself
		var st: float = t * t * (3.0 - 2.0 * t)
		# Interpolate polar coordinates along the arc
		var angle: float = start_angle + angle_diff * st
		var radius: float = lerpf(start_radius, end_radius, st)
		var height: float = lerpf(start_height, end_height, st)
		var pos := Vector3(sin(angle) * radius, height, cos(angle) * radius) + _arena_center
		# Look target always points at arena center during the sweep
		var look: Vector3 = _arena_center + Vector3(0, 0.5, 0)
		_cam_tween.tween_callback(_set_camera_pose.bind(pos, look))
		if i < steps:
			_cam_tween.tween_interval(step_time)


func _set_camera_pose(pos: Vector3, look: Vector3) -> void:
	if _battle_camera:
		_battle_camera.position = pos
		_battle_camera.look_at(look)


func _reset_camera(duration: float = 0.3) -> void:
	## Return camera to the behind-party home position.
	if _cam_home_pos != Vector3.ZERO:
		_move_camera_to(_cam_home_pos, _cam_home_look, duration)


func _move_camera_behind_entity(entity: CombatEntity, duration: float = 0.6) -> void:
	## Move the camera behind a specific player character, over their right shoulder.
	var slot_index: int = _entity_slots.get(entity, 0)
	var slot_offset: Vector3 = PLAYER_POSITIONS[slot_index % PLAYER_POSITIONS.size()]

	# Camera offset: behind (-X) and to the right (+Z) of the character, elevated
	var cam_offset := Vector3(-3.5, 2.5, 1.5)
	var cam_pos: Vector3 = _arena_center + (slot_offset + cam_offset).rotated(Vector3.UP, _arena_rotation_y)

	# Look toward the enemy side, slightly above ground
	var look_offset := Vector3(3.0, 0.5, 0.0)
	var look_pos: Vector3 = _arena_center + look_offset.rotated(Vector3.UP, _arena_rotation_y)

	_move_camera_to(cam_pos, look_pos, duration)


func _walk_players_in(players: Array, duration: float) -> void:
	## Animate player sprites walking from off-screen to their battle positions.
	var walk_duration: float = duration * 0.8  # Finish walking before camera settles
	for pi in range(players.size()):
		var entity: CombatEntity = players[pi]
		var sprite: Node3D = _entity_sprites.get(entity)
		if not sprite:
			continue
		# Compute final position
		var slot_offset: Vector3 = PLAYER_POSITIONS[pi % PLAYER_POSITIONS.size()]
		var final_pos: Vector3 = _arena_center + slot_offset.rotated(Vector3.UP, _arena_rotation_y)
		# Stagger arrivals slightly per character
		var delay: float = pi * 0.15
		var char_walk_time: float = walk_duration - delay
		if char_walk_time < 0.5:
			char_walk_time = 0.5
		# Start walking animation
		sprite.set_walking(true)
		# Tween position from current to final
		var tween := create_tween()
		if delay > 0.0:
			tween.tween_interval(delay)
		tween.tween_property(sprite, "position", final_pos, char_walk_time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
		tween.tween_callback(sprite.set_walking.bind(false))


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


func _add_entity_sprite(entity: CombatEntity, slot_index: int, is_player: bool, walk_in: bool = false) -> void:
	var sprite: Node3D = BattleSpriteScene.instantiate()
	_battle_world.add_child(sprite)

	# Position at battle slot in 3D world space, rotated and offset by arena center
	var positions: Array[Vector3] = PLAYER_POSITIONS if is_player else ENEMY_POSITIONS
	var slot_offset: Vector3 = positions[slot_index % positions.size()]
	var final_pos: Vector3 = _arena_center + slot_offset.rotated(Vector3.UP, _arena_rotation_y)

	if walk_in:
		# Start off-screen behind the player side and walk to position
		var entry_offset := Vector3(-8.0, 0, 0).rotated(Vector3.UP, _arena_rotation_y)
		sprite.position = final_pos + entry_offset
	else:
		sprite.position = final_pos

	sprite.rotation.y = _arena_rotation_y  # Rotate so models face each other along rotated axis

	var side: String = "player" if is_player else "enemy"
	DebugLogger.log_info("Sprite placed: %s [%s slot %d] at %s" % [entity.entity_name, side, slot_index, str(sprite.position)], "BattleView")

	sprite.setup(entity)

	# Connect sprite signals for target selection
	sprite.clicked.connect(_on_sprite_clicked)
	sprite.mouse_entered_sprite.connect(_on_entity_bar_mouse_entered)
	sprite.mouse_exited_sprite.connect(_on_entity_bar_mouse_exited)

	_entity_sprites[entity] = sprite
	_entity_slots[entity] = slot_index


func _build_entity_sprites(players: Array, enemies: Array) -> void:
	# Clear existing battle sprites
	for entity_key in _entity_sprites:
		var old_sprite: Node3D = _entity_sprites[entity_key]
		if is_instance_valid(old_sprite):
			old_sprite.queue_free()
	_entity_sprites.clear()
	_entity_slots.clear()

	for pi in range(players.size()):
		_add_entity_sprite(players[pi], pi, true, true)

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
	# Clear defend indicator when entity's turn starts (defend lasts one round)
	var turn_sprite: Node3D = _entity_sprites.get(entity)
	if turn_sprite and turn_sprite.has_method("show_defend_indicator"):
		turn_sprite.show_defend_indicator(false)
	_refresh_all_ui()

	if entity.is_player:
		if entity.is_dead:
			_combat_manager.advance_turn()
			return
		_state = BattleState.PLAYER_ACTION
		DebugLogger.log_info("State -> PLAYER_ACTION: %s (HP:%d/%d MP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp, entity.current_mp, entity.max_mp], "Battle")
		_move_camera_behind_entity(entity)
		var skills: Array = entity.get_available_skills()
		var skill_names: String = ", ".join(skills.map(func(s: SkillData) -> String: return s.display_name)) if not skills.is_empty() else "none"
		DebugLogger.log_info("  Skills: [%s], can_flee: %s" % [skill_names, str(_encounter_data.can_flee)], "Battle")
		_action_menu.show_for_entity(entity, _encounter_data.can_flee)
	else:
		_state = BattleState.ENEMY_ACTION
		DebugLogger.log_info("State -> ENEMY_ACTION: %s (HP:%d/%d)" % [entity.entity_name, entity.current_hp, entity.max_hp], "Battle")
		_reset_camera(0.5)
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
		var defeated_ids: Array = []
		for i in range(_combat_manager.enemy_entities.size()):
			var entity: CombatEntity = _combat_manager.enemy_entities[i]
			if entity.enemy_data:
				defeated_ids.append(entity.enemy_data.id)
		EventBus.combat_ended.emit(true, defeated_ids)
		await get_tree().create_timer(VICTORY_DELAY).timeout
		# Generate loot and show reward screen
		var loot: Array = LootGeneratorScript.generate_loot(_encounter_data, _combat_manager.enemy_entities)
		if not loot.is_empty():
			DebugLogger.log_info("Generated %d loot items, opening loot screen" % loot.size(), "Battle")
			var loot_data := {
				"loot": loot,
				"gold": _combat_manager.gold_earned,
				"source": "battle",
				"loot_grid_template": _encounter_data.loot_grid_template,
			}
			SceneManager.replace_scene("res://scenes/loot/loot.tscn", loot_data)
		else:
			DebugLogger.log_info("No loot generated, returning to previous scene", "Battle")
			SceneManager.pop_scene({"from_battle": true})
	elif _combat_manager.player_fled:
		DebugLogger.log_info("Player fled — returning to overworld", "Battle")
		AudioManager.play_sfx("flee_success")
		EventBus.combat_ended.emit(false, [])
		SceneManager.pop_scene({"from_battle": true})
	else:
		_state = BattleState.DEFEAT
		_title.text = "Defeat..."
		DebugLogger.log_info("State -> DEFEAT", "Battle")
		EventBus.combat_ended.emit(false, [])
		await get_tree().create_timer(DEFEAT_DELAY).timeout
		DebugLogger.log_info("Showing defeat screen", "Battle")
		_show_defeat_screen()


func _on_entity_died(entity: CombatEntity) -> void:
	DebugLogger.log_info("Entity died: %s (is_player: %s)" % [entity.entity_name, str(entity.is_player)], "Battle")

	# Play death animation and wait for it
	AudioManager.play_sfx("death_ko")
	var sprite: Node3D = _entity_sprites.get(entity)
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
	var sprite: Node3D = _entity_sprites.get(entity)
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
		_exit_target_selection()
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
			AudioManager.play_sfx("defend_stance")
			var def_sprite: Node3D = _entity_sprites.get(_combat_manager.current_entity)
			if def_sprite:
				def_sprite.play_defend_animation()
				await def_sprite.animation_finished
				def_sprite.show_defend_indicator(true)
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
		_set_entity_highlight(hovered_entity, _entity_bars.get(hovered_entity).HighlightType.INVALID, false)
		return

	for i in range(targets.size()):
		var target: CombatEntity = targets[i]
		var is_primary: bool = (target == hovered_entity)
		var bar: PanelContainer = _entity_bars.get(target)
		var hl_type: int = bar.HighlightType.PRIMARY if is_primary else bar.HighlightType.SECONDARY
		_set_entity_highlight(target, hl_type, is_primary)


func _clear_target_highlights() -> void:
	var keys: Array = _entity_bars.keys()
	for i in range(keys.size()):
		_set_entity_highlight(keys[i], _entity_bars[keys[i]].HighlightType.NONE, false)


func _set_entity_highlight(entity: CombatEntity, highlight_type: int, sprite_active: bool) -> void:
	var bar: PanelContainer = _entity_bars.get(entity)
	if bar:
		bar.set_highlight(highlight_type)
	var sprite: Node3D = _entity_sprites.get(entity)
	if sprite:
		sprite.set_highlight(sprite_active)


func _unhandled_input(event: InputEvent) -> void:
	if _state == BattleState.TARGET_SELECT:
		if event.is_action_pressed("escape") or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_RIGHT):
			DebugLogger.log_info("Target selection cancelled by player", "Battle")
			_cancel_target_selection()
			get_viewport().set_input_as_handled()


func _exit_target_selection() -> void:
	_clear_target_highlights()
	_clear_pending_action()
	_state = BattleState.PLAYER_ACTION
	_target_prompt.visible = false


func _cancel_target_selection() -> void:
	_exit_target_selection()
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
	var attacker_sprite: Node3D = _entity_sprites.get(source)
	if attacker_sprite:
		var use_cast: bool = _is_magical_action(_pending_action_type, _pending_skill)
		if use_cast:
			DebugLogger.log_info("Anim: %s -> play_cast (pos=%s)" % [source.entity_name, str(attacker_sprite.position)], "BattleAnim")
			attacker_sprite.play_cast_animation()
		else:
			DebugLogger.log_info("Anim: %s -> play_attack (pos=%s)" % [source.entity_name, str(attacker_sprite.position)], "BattleAnim")
			attacker_sprite.play_attack_animation()
		await attacker_sprite.animation_finished
		DebugLogger.log_info("Anim: %s -> anim finished" % source.entity_name, "BattleAnim")
	else:
		DebugLogger.log_warn("Anim: no sprite found for attacker %s" % source.entity_name, "BattleAnim")

	# Step 2: Fire projectiles (if applicable) then execute combat logic + VFX
	if _pending_skill and (_pending_action_type == Enums.CombatAction.SKILL or _pending_action_type == Enums.CombatAction.ITEM):
		await _fire_projectiles(source, targets, _pending_skill)

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
				# VFX + SFX: default slash for basic attacks
				_spawn_vfx_on_targets(targets, Enums.SkillVFX.SLASH, Color.WHITE, result.get("is_crit", false))
				if result.get("is_crit", false):
					AudioManager.play_sfx("critical_hit")
				elif result.get("actual_damage", 0) > 0:
					AudioManager.play_sfx("slash")
				else:
					AudioManager.play_sfx("miss_dodge")
				# Step 3: Play target reaction
				await _play_target_reactions(targets, result)

		Enums.CombatAction.SKILL:
			if _pending_skill:
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)
				_spawn_skill_vfx(targets, _pending_skill, result)
				await _play_target_reactions_from_results(result)

		Enums.CombatAction.ITEM:
			if _pending_skill:
				result = _combat_manager.execute_skill(source, _pending_skill, targets)
				_spawn_popups_for_results(result)
				_spawn_skill_vfx(targets, _pending_skill, result)
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

func _is_magical_action(action_type: int, skill: SkillData) -> bool:
	## Returns true when the action should play a cast animation instead of attack.
	if action_type != Enums.CombatAction.SKILL and action_type != Enums.CombatAction.ITEM:
		return false
	if not skill:
		return false
	if skill.magical_scaling > skill.physical_scaling:
		return true
	if skill.heal_amount > 0 or skill.heal_percent > 0.0:
		return true
	return false


func _play_hurt_animation_for(target: CombatEntity, dmg: int) -> void:
	## Play hurt animation on a single target if it took damage.
	if dmg <= 0:
		DebugLogger.log_info("Anim: %s took 0 damage, skipping hurt anim" % target.entity_name, "BattleAnim")
		return
	var sprite: Node3D = _entity_sprites.get(target)
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

	# Step 1: Play enemy animation (cast for magical skills, attack otherwise; skip for defend)
	if action_type != Enums.CombatAction.DEFEND:
		var enemy_sprite: Node3D = _entity_sprites.get(entity)
		if enemy_sprite:
			var use_cast: bool = _is_magical_action(action_type, skill)
			if use_cast:
				DebugLogger.log_info("Anim: %s -> play_cast (pos=%s)" % [entity.entity_name, str(enemy_sprite.position)], "BattleAnim")
				enemy_sprite.play_cast_animation()
			else:
				DebugLogger.log_info("Anim: %s -> play_attack (pos=%s)" % [entity.entity_name, str(enemy_sprite.position)], "BattleAnim")
				enemy_sprite.play_attack_animation()
			await enemy_sprite.animation_finished
			DebugLogger.log_info("Anim: %s -> anim finished" % entity.entity_name, "BattleAnim")
		else:
			DebugLogger.log_warn("Anim: no sprite found for enemy attacker %s" % entity.entity_name, "BattleAnim")

	# Fire projectiles for skill actions
	if skill and action_type == Enums.CombatAction.SKILL:
		await _fire_projectiles(entity, targets, skill)

	# Step 2: Execute combat logic + VFX
	match action_type:
		Enums.CombatAction.ATTACK:
			if not targets.is_empty():
				var result: Dictionary = _combat_manager.execute_attack(entity, targets[0])
				_spawn_damage_popup(targets[0], result)
				_spawn_vfx_on_targets(targets, Enums.SkillVFX.SLASH, Color.WHITE, result.get("is_crit", false))
				await _play_target_reactions(targets, result)

		Enums.CombatAction.SKILL:
			if skill:
				var result: Dictionary = _combat_manager.execute_skill(entity, skill, targets)
				_spawn_popups_for_results(result)
				_spawn_skill_vfx(targets, skill, result)
				await _play_target_reactions_from_results(result)

		Enums.CombatAction.DEFEND:
			var def_sprite: Node3D = _entity_sprites.get(entity)
			if def_sprite:
				def_sprite.play_defend_animation()
				await def_sprite.animation_finished
				def_sprite.show_defend_indicator(true)
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
	elif result.get("defended", false):
		popup_type = Enums.PopupType.BLOCKED
	elif result.get("is_crit", false):
		popup_type = Enums.PopupType.CRIT

	DebugLogger.log_info("Popup: %s on %s (%d)" % [Enums.PopupType.keys()[popup_type], target.entity_name, amount], "Battle")
	_spawn_popup_at_entity(target, amount, popup_type)


func _save_player_vitals(_victory: bool = false) -> void:
	if not _combat_manager or not GameManager.party:
		return

	for i in range(_combat_manager.player_entities.size()):
		var entity: CombatEntity = _combat_manager.player_entities[i]
		if entity.character_data:
			var char_id: String = entity.character_data.id
			var tree: PassiveTreeData = PassiveTreeDatabase.get_passive_tree()
			var saved_hp: int = entity.current_hp
			GameManager.party.set_current_hp(char_id, saved_hp, tree)
			GameManager.party.set_current_mp(char_id, entity.current_mp, tree)
			DebugLogger.log_info("Saved vitals for %s: HP %d/%d, MP %d/%d%s" % [
				entity.entity_name,
				saved_hp,
				entity.max_hp,
				entity.current_mp,
				entity.max_mp,
				" (DEAD)" if entity.is_dead else "",
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
	UIThemes.set_font_size(title_lbl, 28)
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


# === VFX Helpers ===

func _spawn_vfx_on_targets(targets: Array, vfx_type: int, color: Color, is_crit: bool) -> void:
	## Spawn a VFX effect at each target's position.
	for i in range(targets.size()):
		var target: CombatEntity = targets[i]
		var sprite: Node3D = _entity_sprites.get(target)
		if sprite and is_instance_valid(sprite):
			var vfx_pos: Vector3 = sprite.global_position + Vector3(0, 1.0, 0)
			BattleVFX.spawn_at(_battle_world, vfx_pos, vfx_type, color)
	if is_crit:
		_shake_camera(0.2, 0.3)


func _spawn_skill_vfx(targets: Array, skill: SkillData, result: Dictionary) -> void:
	## Spawn VFX for a skill based on its vfx_type property.
	var vfx_type: int = skill.vfx_type
	if vfx_type == 0:  # NONE — auto-detect from skill properties
		if skill.heal_amount > 0 or skill.heal_percent > 0.0:
			vfx_type = 9  # HEAL
		elif skill.magical_scaling > 0.0:
			vfx_type = 5  # FIRE as default magic
		elif skill.physical_scaling >= 1.3:
			vfx_type = 2  # POWER_SLASH for heavy physical
		elif skill.physical_scaling > 0.0:
			vfx_type = 1  # SLASH for light physical
	_spawn_vfx_on_targets(targets, vfx_type, skill.vfx_color, false)
	AudioManager.play_sfx_for_vfx(vfx_type)
	# Screen shake from skill property or crit
	var has_crit: bool = false
	var target_results: Array = result.get("target_results", [])
	for i in range(target_results.size()):
		var tgt_result: Dictionary = target_results[i]
		if tgt_result.get("is_crit", false):
			has_crit = true
			break
	if skill.screen_shake or has_crit:
		_shake_camera(0.2 if skill.screen_shake else 0.15, 0.3)


func _fire_projectiles(source: CombatEntity, targets: Array, skill: SkillData) -> void:
	## Fire projectiles from source to all targets and await their arrival.
	## Only fires if the skill has has_projectile=true or is auto-detected as ranged.
	var should_fire: bool = skill.has_projectile
	if not should_fire:
		# Auto-detect: magical skills with single/all enemy targeting get projectiles
		if skill.magical_scaling > 0.0 and skill.has_damage():
			should_fire = true

	if not should_fire:
		return

	var source_sprite: Node3D = _entity_sprites.get(source)
	if not source_sprite or not is_instance_valid(source_sprite):
		return

	AudioManager.play_sfx("projectile_launch")
	var from_pos: Vector3 = source_sprite.global_position + Vector3(0, 1.0, 0)
	var vfx_type: int = skill.vfx_type
	if vfx_type == 0:
		vfx_type = 5  # Default FIRE for magic

	var max_flight: float = 0.0
	for i in range(targets.size()):
		var target: CombatEntity = targets[i]
		var target_sprite: Node3D = _entity_sprites.get(target)
		if target_sprite and is_instance_valid(target_sprite):
			var to_pos: Vector3 = target_sprite.global_position + Vector3(0, 1.0, 0)
			var flight: float = BattleVFX.spawn_projectile(_battle_world, from_pos, to_pos, vfx_type, skill.vfx_color)
			if flight > max_flight:
				max_flight = flight

	if max_flight > 0.0:
		await get_tree().create_timer(max_flight).timeout


func _spawn_popup_at_entity(entity: CombatEntity, amount: int, popup_type: Enums.PopupType) -> void:
	var popup: Label = DamagePopupScene.instantiate()
	_popup_layer.add_child(popup)

	# Position above the 3D model using camera projection
	var sprite: Node3D = _entity_sprites.get(entity)
	if sprite and is_instance_valid(sprite) and _battle_camera:
		# Project model center into screen space, then offset upward in 2D
		var world_pos: Vector3 = sprite.global_position + Vector3(0, 1.0, 0)
		var viewport_pos: Vector2 = _battle_camera.unproject_position(world_pos)
		# With stretch=true, SubViewport auto-resizes to container so scale is 1:1
		var screen_pos: Vector2 = viewport_pos + _battle_viewport.global_position
		popup.global_position = screen_pos + Vector2(randf_range(-20, 20), -40)
	elif _entity_bars.has(entity):
		# Fallback to status bar position
		var bar: PanelContainer = _entity_bars[entity]
		popup.global_position = bar.get_global_center() + Vector2(randf_range(-20, 20), -10)
	else:
		popup.queue_free()
		return

	popup.setup(amount, popup_type)
