extends Control
## Displays upcoming turns in the turn order with portrait icons.
## Configurable: layout, colors, sizes, visible count — all via inspector.

signal entity_hovered(entity: CombatEntity)
signal entity_unhovered(entity: CombatEntity)

## Layout
@export_enum("Horizontal", "Vertical") var turn_layout: int = 0

## Colors
@export_group("Colors")
@export var active_border_color: Color = Color(1.0, 0.84, 0.0, 0.9)
@export var player_border_color: Color = Color(0.4, 0.7, 1.0, 0.7)
@export var enemy_border_color: Color = Color(1.0, 0.4, 0.4, 0.7)

## Sizes
@export_group("Sizes")
@export var base_slot_size: Vector2 = Vector2(64, 64)
@export_range(0.01, 0.2) var shrink_per_step: float = 0.1  ## Each slot is this fraction smaller than the previous
@export_range(0.2, 1.0) var min_scale: float = 0.3  ## Slots never shrink below this fraction
@export_range(1, 20) var visible_turns: int = 10

var _container: BoxContainer = null
var _fallback_cache: Dictionary = {}  # entity_name → ImageTexture
var _slot_entities: Dictionary = {}  # PanelContainer → CombatEntity


func _ready() -> void:
	_build_container()


func _build_container() -> void:
	if _container:
		_container.queue_free()
		_container = null


func refresh(turn_order: Array, current_entity: CombatEntity) -> void:
	# Clear old slots
	for child in get_children():
		child.queue_free()
	_slot_entities.clear()

	var count: int = mini(turn_order.size(), visible_turns)
	var offset: float = 0.0
	var gap: float = 4.0

	for i in range(count):
		var entity: CombatEntity = turn_order[i]
		var is_current: bool = (entity == current_entity)

		var scale_factor: float = maxf(1.0 - i * shrink_per_step, min_scale)
		var slot_size: Vector2 = base_slot_size * scale_factor

		# Slot panel
		var slot: PanelContainer = PanelContainer.new()
		slot.size = slot_size

		# Position manually
		if turn_layout == 1:
			# Vertical: stack downward, align left
			slot.position = Vector2(0, offset)
			offset += slot_size.y + gap
		else:
			# Horizontal: stack rightward, align bottom
			slot.position = Vector2(offset, base_slot_size.y - slot_size.y)
			offset += slot_size.x + gap

		# Border style
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0, 0, 0, 0.5)
		var bw: int = 3 if is_current else 2
		if is_current:
			style.border_color = active_border_color
		elif entity.is_player:
			style.border_color = player_border_color
		else:
			style.border_color = enemy_border_color
		style.border_width_left = bw
		style.border_width_top = bw
		style.border_width_right = bw
		style.border_width_bottom = bw
		style.corner_radius_top_left = 4
		style.corner_radius_top_right = 4
		style.corner_radius_bottom_left = 4
		style.corner_radius_bottom_right = 4
		slot.add_theme_stylebox_override("panel", style)

		# Portrait
		var tex_rect: TextureRect = TextureRect.new()
		tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.set_anchors_preset(Control.PRESET_FULL_RECT)

		var portrait: Texture2D = _get_portrait(entity)
		tex_rect.texture = portrait
		slot.add_child(tex_rect)
		slot.mouse_entered.connect(_on_slot_hover.bind(entity))
		slot.mouse_exited.connect(_on_slot_unhover.bind(entity))
		_slot_entities[slot] = entity
		add_child(slot)


func highlight_entity(entity: CombatEntity, active: bool) -> void:
	## Highlight or unhighlight all slots belonging to the given entity.
	for slot in _slot_entities:
		if _slot_entities[slot] == entity:
			if active:
				slot.self_modulate = Color(1.5, 1.3, 0.5, 1.0)
				slot.z_index = 1
				slot.scale = Vector2(1.15, 1.15)
			else:
				slot.self_modulate = Color.WHITE
				slot.z_index = 0
				slot.scale = Vector2.ONE


func _on_slot_hover(entity: CombatEntity) -> void:
	entity_hovered.emit(entity)


func _on_slot_unhover(entity: CombatEntity) -> void:
	entity_unhovered.emit(entity)


func _get_portrait(entity: CombatEntity) -> Texture2D:
	# Player: use character_data.portrait if available
	if entity.is_player and entity.character_data and entity.character_data.portrait:
		return entity.character_data.portrait
	# Fallback: generate a black square with the entity name
	return _get_fallback_portrait(entity.entity_name)


func _get_fallback_portrait(entity_name: String) -> Texture2D:
	if _fallback_cache.has(entity_name):
		return _fallback_cache[entity_name]

	# Create a 64x64 image with black background and white text
	var size: int = 64
	var img: Image = Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.1, 0.1, 0.1, 1.0))

	# Draw a colored bar at the top for visual distinction
	var hash_val: int = entity_name.hash()
	var hue: float = absf(float(hash_val % 360)) / 360.0
	var bar_color: Color = Color.from_hsv(hue, 0.6, 0.8)
	for x in range(size):
		for y in range(4):
			img.set_pixel(x, y, bar_color)

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	_fallback_cache[entity_name] = tex
	return tex
