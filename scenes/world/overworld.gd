extends Node3D
## Main overworld scene controller (3D version).

@onready var _player: CharacterBody3D = $Player
@onready var _location_markers: Node3D = $LocationMarkers
@onready var _orbit_camera: OrbitCamera = $OrbitCamera
@onready var _ui: CanvasLayer = $UI
@onready var _fast_travel_menu: PanelContainer = $UI/FastTravelMenu
@onready var _hud_gold_label: Label = $UI/HUD/GoldLabel
@onready var _hud_location_label: Label = $UI/HUD/LocationLabel
@onready var _message_label: Label = $UI/HUD/MessageLabel if has_node("UI/HUD/MessageLabel") else null

const BATTLE_COOLDOWN_TIME: float = 3.0  ## Seconds of immunity after battle
const MESSAGE_DISPLAY_TIME: float = 3.0  ## Seconds to show messages
const _PAUSE_SCENE := preload("res://scenes/menus/pause_menu.tscn")
const _PARTY_HUD_SCRIPT := preload("res://scenes/world/party_hud.gd")

# Decoration scenes
const _TREE_LARGE := preload("res://scenes/world/objects/tree_large.tscn")
const _TREE_MEDIUM := preload("res://scenes/world/objects/tree_medium.tscn")
const _TREE_SMALL := preload("res://scenes/world/objects/tree_small.tscn")
const _ROCK_LARGE := preload("res://scenes/world/objects/rock_large.tscn")
const _ROCK_MEDIUM := preload("res://scenes/world/objects/rock_medium.tscn")
const _ROCK_SMALL := preload("res://scenes/world/objects/rock_small.tscn")
const _BUSH := preload("res://scenes/world/objects/bush.tscn")
const _FENCE := preload("res://scenes/world/objects/fence.tscn")
const _SIGN := preload("res://scenes/world/objects/sign.tscn")
const _FLOWER_RED := preload("res://scenes/world/objects/flower_red.tscn")
const _FLOWER_YELLOW := preload("res://scenes/world/objects/flower_yellow.tscn")
const _GRASS := preload("res://scenes/world/objects/grass_tuft.tscn")

# Terrain block types (indices match tools/generate_mesh_library.gd)
enum Block { GRASS, DIRT, STONE, WATER, PATH, SAND, DARK_GRASS, SNOW }
const BLOCK_COLORS = [
	Color(0.35, 0.55, 0.25, 1.0),  # Grass
	Color(0.45, 0.32, 0.18, 1.0),  # Dirt
	Color(0.5, 0.5, 0.5, 1.0),     # Stone
	Color(0.2, 0.4, 0.8, 0.7),     # Water
	Color(0.6, 0.5, 0.35, 1.0),    # Path
	Color(0.85, 0.77, 0.55, 1.0),  # Sand
	Color(0.25, 0.4, 0.2, 1.0),    # DarkGrass
	Color(0.9, 0.9, 0.95, 1.0),    # Snow
]

var _message_timer: float = 0.0
var _current_message: String = ""
var _pause_menu_instance: Control = null
var _party_hud: HBoxContainer = null


func _ready() -> void:
	# Camera setup — follow the player
	_orbit_camera.set_follow_target(_player)

	# Restore player position from save if returning
	if GameManager.party:
		var saved_pos: Vector3 = _get_saved_position()
		DebugLogger.log_info("Saved position: %s" % saved_pos, "Overworld")
		if saved_pos != Vector3.ZERO:
			_player.global_position = saved_pos
			DebugLogger.log_info("Restored player to: %s" % saved_pos, "Overworld")

	DebugLogger.log_info("Player starting at: %s" % _player.global_position, "Overworld")

	EventBus.gold_changed.connect(_update_hud_gold)
	EventBus.location_prompt_visible.connect(_on_location_prompt)
	EventBus.show_message.connect(_show_message)
	_update_hud_gold(GameManager.gold)
	_hud_location_label.text = ""

	# Setup message label if it doesn't exist
	if not _message_label:
		_message_label = Label.new()
		_message_label.name = "MessageLabel"
		_message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_message_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_message_label.set_anchors_preset(Control.PRESET_CENTER)
		_message_label.position = Vector2(0, -200)
		_message_label.add_theme_font_size_override("font_size", 24)
		_message_label.add_theme_color_override("font_color", Color.YELLOW)
		_message_label.add_theme_color_override("font_outline_color", Color.BLACK)
		_message_label.add_theme_constant_override("outline_size", 4)
		_message_label.visible = false
		$UI/HUD.add_child(_message_label)

	# Party HUD (character cards: portrait, HP, MP)
	_party_hud = HBoxContainer.new()
	_party_hud.set_script(_PARTY_HUD_SCRIPT)
	$UI/HUD.add_child(_party_hud)

	# Auto-save on entry
	GameManager.current_location_name = "Overworld"
	SaveManager.auto_save()
	DebugLogger.log_info("Auto-saved at: %s" % _player.global_position, "Overworld")

	# Snap camera to player immediately, then allow smooth follow
	_orbit_camera.global_position = _player.global_position

	# Build terrain grid (replaces CSG ground plane)
	_build_terrain()

	# Populate world with decorations (trees, rocks, bushes, etc.)
	_populate_world()

	# Enable enemy detection after scene is fully loaded and player is positioned
	_enable_enemy_detection()


func _process(delta: float) -> void:
	# Handle message display timer
	if _message_timer > 0:
		_message_timer -= delta
		if _message_timer <= 0:
			_hide_message()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		if _fast_travel_menu.visible:
			_fast_travel_menu._on_cancel()
		else:
			_toggle_pause_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("fast_travel"):
		_open_fast_travel_menu()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("open_inventory"):
		# Save position before opening inventory
		_save_current_position()
		SceneManager.push_scene("res://scenes/character_hub/character_hub.tscn")
		get_viewport().set_input_as_handled()


func receive_data(data: Dictionary) -> void:
	## Called by SceneManager after returning from another scene.
	# Refresh party HUD (HP/MP may have changed in battle, shop, dialogue, etc.)
	if _party_hud:
		_party_hud.rebuild()

	if data.get("from_battle", false):
		# Push player away from any nearby enemies to prevent immediate re-engagement
		_push_player_from_enemies()
		# Re-enable player input after battle
		_player.enable_input(true)
		# Auto-save after battle (with new position)
		SaveManager.auto_save()
		# Re-enable enemy detection after player is safely positioned
		_enable_enemy_detection()
		# Apply battle cooldown to all enemies
		_apply_battle_cooldown()


func _get_saved_position() -> Vector3:
	## Reads saved position, handling both old Vector2 and new Vector3 formats.
	var saved: Variant = GameManager.get_flag("overworld_position", Vector3.ZERO)
	if saved is Vector3:
		return saved
	if saved is Vector2:
		# Legacy 2D position — convert using pixel scale
		return Vector3(saved.x / Constants.PIXEL_TO_WORLD, 0.0, saved.y / Constants.PIXEL_TO_WORLD)
	return Vector3.ZERO


func _update_hud_gold(gold: int) -> void:
	_hud_gold_label.text = "Gold: %d" % gold


func _on_location_prompt(prompt_visible: bool, location_name: String) -> void:
	if prompt_visible:
		_hud_location_label.text = "[E] Enter: %s" % location_name
	else:
		_hud_location_label.text = ""


func _show_message(message: String) -> void:
	## Displays a temporary message to the player.
	if not _message_label:
		DebugLogger.log_warn("No message label to display: %s" % message, "Overworld")
		return

	_current_message = message
	_message_label.text = message
	_message_label.visible = true
	_message_timer = MESSAGE_DISPLAY_TIME
	DebugLogger.log_info("Showing message: %s" % message, "Overworld")


func _hide_message() -> void:
	## Hides the current message.
	if _message_label:
		_message_label.visible = false
	_current_message = ""


func _save_current_position() -> void:
	## Saves the player's current position so it can be restored when returning.
	if _player:
		GameManager.set_flag("overworld_position", _player.global_position)
		DebugLogger.log_info("Saved current position: %s" % _player.global_position, "Overworld")


func _open_fast_travel_menu() -> void:
	## Opens the fast travel menu with all available locations.
	# Gather all LocationData from markers
	var all_locations: Array[LocationData] = []
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data"):
			all_locations.append(marker.get_location_data())

	_fast_travel_menu.open_menu(all_locations)
	_fast_travel_menu.location_selected.connect(_on_fast_travel_selected, CONNECT_ONE_SHOT)
	_fast_travel_menu.visibility_changed.connect(_on_fast_travel_menu_visibility_changed, CONNECT_ONE_SHOT)
	_player.enable_input(false)


func _on_fast_travel_menu_visibility_changed() -> void:
	## Re-enable input when fast travel menu is closed (if not traveling)
	if not _fast_travel_menu.visible:
		_player.enable_input(true)


func _on_fast_travel_selected(location: LocationData) -> void:
	## Teleports player to the selected fast travel location.
	# Find the marker node with this location
	for marker in _location_markers.get_children():
		if marker.has_method("get_location_data") and marker.get_location_data() == location:
			# Teleport player to marker
			_player.global_position = marker.global_position
			_player.enable_input(true)

			# Save new position
			GameManager.set_flag("overworld_position", _player.global_position)
			SaveManager.auto_save()
			break


func _enable_enemy_detection() -> void:
	## Enables battle detection on all enemies after player is safely positioned.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and enemy.has_method("enable_detection"):
			enemy.enable_detection()
	DebugLogger.log_info("Enabled detection for %d enemies" % enemies.size(), "Overworld")


func _push_player_from_enemies() -> void:
	## Moves player away from any nearby enemies to prevent immediate re-engagement after battle.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	var player_pos: Vector3 = _player.global_position
	var closest_enemy: Node = null
	var closest_distance: float = INF

	# Find closest enemy
	for i in range(enemies.size()):
		var enemy: Node = enemies[i]
		if enemy and is_instance_valid(enemy) and enemy is Node3D:
			var distance: float = player_pos.distance_to(enemy.global_position)
			if distance < closest_distance:
				closest_distance = distance
				closest_enemy = enemy

	# If player is too close to an enemy, push them away
	if closest_enemy and closest_distance < Constants.SAFE_DISTANCE:
		var push_direction: Vector3 = (player_pos - closest_enemy.global_position).normalized()
		push_direction.y = 0.0  # Keep on ground plane
		if push_direction.length() < 0.1:  # Handle case where positions are identical
			push_direction = Vector3.RIGHT  # Default push to the right

		var new_position: Vector3 = closest_enemy.global_position + (push_direction.normalized() * Constants.PUSH_DISTANCE)
		new_position.y = 0.0
		_player.global_position = new_position

		# Update saved position
		GameManager.set_flag("overworld_position", _player.global_position)

		DebugLogger.log_info("Pushed player away from enemy (distance was %.1f)" % closest_distance, "Overworld")


func _apply_battle_cooldown() -> void:
	## Disables battle triggers on all enemies for a short period.
	var enemies: Array[Node] = get_tree().get_nodes_in_group("roaming_enemies")
	for ei in range(enemies.size()):
		var e: Node = enemies[ei]
		if e.has_method("disable_battles_temporarily"):
			e.disable_battles_temporarily()

	# Re-enable after cooldown
	await get_tree().create_timer(BATTLE_COOLDOWN_TIME).timeout

	for ri in range(enemies.size()):
		var re: Node = enemies[ri]
		if re and is_instance_valid(re) and "_can_trigger_battle" in re:
			re._can_trigger_battle = true

	DebugLogger.log_info("Battle cooldown ended - enemies can trigger battles again", "Overworld")


# === Pause Menu ===

func _toggle_pause_menu() -> void:
	if _pause_menu_instance:
		_pause_menu_instance.queue_free()
		_pause_menu_instance = null
		return
	_save_current_position()
	_pause_menu_instance = _PAUSE_SCENE.instantiate()
	_ui.add_child(_pause_menu_instance)
	_pause_menu_instance.resume_requested.connect(_toggle_pause_menu)
	_pause_menu_instance.save_requested.connect(_open_save_screen)
	_pause_menu_instance.load_requested.connect(_open_load_screen)
	_pause_menu_instance.main_menu_requested.connect(_go_to_main_menu)


func _open_save_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "save"})


func _open_load_screen() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.push_scene("res://scenes/menus/save_load_menu.tscn", {"mode": "load"})


func _go_to_main_menu() -> void:
	_pause_menu_instance.queue_free()
	_pause_menu_instance = null
	SceneManager.clear_stack()
	SceneManager.replace_scene("res://scenes/main_menu/main_menu.tscn")


# === Terrain ===

func _build_terrain() -> void:
	## Creates a GridMap terrain with painted zones replacing the old flat ground plane.
	var lib := MeshLibrary.new()
	for i in BLOCK_COLORS.size():
		lib.create_item(i)
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1, 1, 1)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = BLOCK_COLORS[i]
		if BLOCK_COLORS[i].a < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		lib.set_item_mesh(i, mesh)
		var shape := BoxShape3D.new()
		shape.size = Vector3(1, 1, 1)
		lib.set_item_shapes(i, [shape, Transform3D.IDENTITY])

	var grid := GridMap.new()
	grid.name = "Terrain"
	grid.mesh_library = lib
	grid.cell_size = Vector3(1, 1, 1)
	grid.collision_layer = 1
	grid.collision_mask = 0
	grid.position.y = -0.5  # Top surface aligns with Y=0

	for x in range(80):
		for z in range(50):
			grid.set_cell_item(Vector3i(x, 0, z), _get_terrain_block(x, z))

	add_child(grid)
	DebugLogger.log_info("Built GridMap terrain: 80x50 cells", "Overworld")


func _get_terrain_block(x: int, z: int) -> int:
	## Returns the block type for a grid cell based on world zones.
	# Small pond in eastern wilds
	if x >= 56 and x <= 59 and z >= 21 and z <= 24:
		return Block.WATER
	# Sand beach around pond
	if x >= 55 and x <= 60 and z >= 20 and z <= 25:
		return Block.SAND
	# Road from town to cave (z:15-17, x:20→36)
	if x >= 20 and x <= 36 and z >= 15 and z <= 17:
		return Block.PATH
	# Town main street (x:8-11)
	if x >= 8 and x <= 11 and z >= 3 and z <= 18:
		return Block.PATH
	# Cave area (x:33-50, z:10-25)
	if x >= 33 and x <= 50 and z >= 10 and z <= 25:
		return Block.STONE
	# Town area (x:3-20, z:3-18)
	if x >= 3 and x <= 20 and z >= 3 and z <= 18:
		return Block.DIRT
	# Forest West (x:0-15, z:20-48)
	if x <= 15 and z >= 20 and z <= 48:
		return Block.DARK_GRASS
	# Forest North (x:15-65, z:35-48)
	if x >= 15 and x <= 65 and z >= 35 and z <= 48:
		return Block.DARK_GRASS
	# Default: open grassland
	return Block.GRASS


# === World Population ===

func _populate_world() -> void:
	## Procedurally spawns trees, rocks, bushes, flowers, fences, and signs.
	## Uses seeded RNG for deterministic placement across sessions.
	var decorations := Node3D.new()
	decorations.name = "Decorations"

	# Gather exclusion positions from entities (keep 2.5-unit radius clear)
	var exclusions: Array[Vector3] = [_player.global_position]
	for marker in _location_markers.get_children():
		if marker is Node3D:
			exclusions.append(marker.position)
	for enemy in $Enemies.get_children():
		if enemy is Node3D:
			exclusions.append(enemy.position)
	for child in get_children():
		if "npc_id" in child and child is Node3D:
			exclusions.append(child.position)

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var placed: Array[Vector3] = []

	# Zone definitions: rect = Rect2(x, z, width, depth) in XZ plane
	var zones: Array[Dictionary] = [
		# Border trees (edges of 80x50 map)
		{"rect": Rect2(1, 1, 78, 2), "objects": [_TREE_LARGE], "count": 15, "spacing": 5.0},
		{"rect": Rect2(1, 47, 78, 2), "objects": [_TREE_LARGE], "count": 15, "spacing": 5.0},
		{"rect": Rect2(1, 3, 2, 44), "objects": [_TREE_LARGE], "count": 8, "spacing": 5.0},
		{"rect": Rect2(77, 3, 2, 44), "objects": [_TREE_LARGE], "count": 8, "spacing": 5.0},
		# Forest West (x:0-15, z:20-48)
		{"rect": Rect2(0, 20, 15, 28), "objects": [_TREE_LARGE, _TREE_LARGE, _TREE_MEDIUM, _BUSH], "count": 25, "spacing": 3.0},
		# Forest North (x:15-65, z:35-48)
		{"rect": Rect2(15, 35, 50, 13), "objects": [_TREE_LARGE, _TREE_MEDIUM, _TREE_SMALL, _BUSH], "count": 25, "spacing": 3.0},
		# Town (x:4-19, z:4-18) — light decorations only
		{"rect": Rect2(4, 4, 15, 14), "objects": [_TREE_SMALL, _FLOWER_RED, _FLOWER_YELLOW, _GRASS, _GRASS], "count": 25, "spacing": 1.5},
		# Road edges (x:20-38, z:12-24)
		{"rect": Rect2(20, 12, 18, 12), "objects": [_BUSH, _FLOWER_RED, _FLOWER_YELLOW, _GRASS], "count": 15, "spacing": 2.0},
		# Cave area (x:33-50, z:10-25) — rocky terrain
		{"rect": Rect2(33, 10, 17, 15), "objects": [_ROCK_LARGE, _ROCK_MEDIUM, _ROCK_SMALL, _ROCK_SMALL, _TREE_SMALL], "count": 18, "spacing": 2.0},
		# Eastern wilds (x:50-78, z:2-48) — mixed wilderness
		{"rect": Rect2(50, 2, 28, 46), "objects": [_TREE_MEDIUM, _TREE_SMALL, _ROCK_MEDIUM, _ROCK_SMALL, _BUSH], "count": 30, "spacing": 3.5},
	]

	for zone in zones:
		var rect: Rect2 = zone["rect"]
		var obj_list: Array = zone["objects"]
		var count: int = zone["count"]
		var spacing: float = zone["spacing"]
		var placed_in_zone: int = 0
		var attempts: int = 0

		while placed_in_zone < count and attempts < count * 10:
			attempts += 1
			var x: float = rng.randf_range(rect.position.x, rect.position.x + rect.size.x)
			var z: float = rng.randf_range(rect.position.y, rect.position.y + rect.size.y)
			var pos := Vector3(x, 0, z)

			if _is_valid_placement(pos, exclusions, placed, spacing):
				var scene: PackedScene = obj_list[rng.randi_range(0, obj_list.size() - 1)]
				var obj: Node3D = scene.instantiate()
				obj.position = pos
				obj.rotation.y = rng.randf_range(0, TAU)
				decorations.add_child(obj)
				placed.append(pos)
				placed_in_zone += 1

	# Town fences along south edge (z=3, x:4→20)
	var fence_x: float = 4.0
	while fence_x <= 20.0:
		var fence_obj: Node3D = _FENCE.instantiate()
		fence_obj.position = Vector3(fence_x, 0, 3.0)
		decorations.add_child(fence_obj)
		fence_x += 1.5

	# Town fences along west edge (x=3, z:4→18)
	var fence_z: float = 4.0
	while fence_z <= 18.0:
		var fence_obj: Node3D = _FENCE.instantiate()
		fence_obj.position = Vector3(3.0, 0, fence_z)
		fence_obj.rotation.y = PI / 2.0
		decorations.add_child(fence_obj)
		fence_z += 1.5

	# Signs at key locations
	for sign_pos in [Vector3(9, 0, 3.5), Vector3(36, 0, 20), Vector3(20, 0, 17)]:
		var sign_obj: Node3D = _SIGN.instantiate()
		sign_obj.position = sign_pos
		decorations.add_child(sign_obj)

	add_child(decorations)
	DebugLogger.log_info("Populated world with %d decorations" % decorations.get_child_count(), "Overworld")


func _is_valid_placement(pos: Vector3, exclusions: Array[Vector3], placed_list: Array[Vector3], min_spacing: float) -> bool:
	## Returns false if pos is too close to any exclusion zone or previously placed object.
	const EXCLUSION_RADIUS := 2.5
	var excl_sq: float = EXCLUSION_RADIUS * EXCLUSION_RADIUS
	var spacing_sq: float = min_spacing * min_spacing

	for excl in exclusions:
		var dx: float = pos.x - excl.x
		var dz: float = pos.z - excl.z
		if dx * dx + dz * dz < excl_sq:
			return false

	for p in placed_list:
		var dx: float = pos.x - p.x
		var dz: float = pos.z - p.z
		if dx * dx + dz * dz < spacing_sq:
			return false

	return true
