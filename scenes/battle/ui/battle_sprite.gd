extends Node3D
## Displays a 3D CSG model for a combat entity on the battlefield.
## Supports awaitable animations for sequenced combat flow.

signal animation_finished
signal clicked(entity: CombatEntity)
signal mouse_entered_sprite(entity: CombatEntity)
signal mouse_exited_sprite(entity: CombatEntity)

var _entity: CombatEntity
var _model: Node3D = null
var _click_area: Area3D = null


func setup(entity: CombatEntity) -> void:
	_entity = entity

	# Build CSG model
	if entity.is_player and entity.character_data:
		_model = CSGCharacterFactory.create_from_character(entity.character_data)
	elif not entity.is_player and entity.enemy_data:
		_model = CSGCharacterFactory.create_from_enemy(entity.enemy_data)
	else:
		_model = CSGCharacterFactory.create_humanoid(Constants.CHARACTER_DEFAULT_COLOR)

	add_child(_model)

	# Face enemies toward players
	if not entity.is_player:
		_model.rotation.y = PI

	# Build click detection area
	_build_click_area()


func _build_click_area() -> void:
	_click_area = Area3D.new()
	_click_area.name = "ClickArea"
	_click_area.input_ray_pickable = true
	add_child(_click_area)

	var col_shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1.0, 2.0, 1.0)
	col_shape.shape = box
	col_shape.position = Vector3(0, 1.0, 0)
	_click_area.add_child(col_shape)

	_click_area.input_event.connect(_on_area_input_event)
	_click_area.mouse_entered.connect(_on_area_mouse_entered)
	_click_area.mouse_exited.connect(_on_area_mouse_exited)


func _on_area_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _entity and event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked.emit(_entity)


func _on_area_mouse_entered() -> void:
	if _entity:
		mouse_entered_sprite.emit(_entity)


func _on_area_mouse_exited() -> void:
	if _entity:
		mouse_exited_sprite.emit(_entity)


# === Material Helpers ===

func _set_emission(color: Color, energy: float) -> void:
	if not _model:
		return
	for child in _model.get_children():
		var mat: StandardMaterial3D = _get_child_material(child)
		if mat:
			if energy > 0:
				mat.emission_enabled = true
				mat.emission = color
				mat.emission_energy_multiplier = energy
			else:
				mat.emission_enabled = false


static func _get_child_material(child: Node) -> StandardMaterial3D:
	if child is CSGShape3D and child.material is StandardMaterial3D:
		return child.material as StandardMaterial3D
	if child is MeshInstance3D:
		var mi: MeshInstance3D = child as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat: Material = mi.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				return mat as StandardMaterial3D
	return null


# === Awaitable Animations ===

func play_attack_animation() -> void:
	## Quick forward lunge on the X axis.
	var tween := create_tween()
	var lunge_dir: float = 1.0 if _entity.is_player else -1.0
	tween.tween_property(self, "position:x", position.x + lunge_dir, 0.15)
	tween.tween_property(self, "position:x", position.x, 0.15)
	tween.tween_callback(func() -> void: animation_finished.emit())


func play_hurt_animation() -> void:
	## Flash red emission and shake.
	_set_emission(Color(1.0, 0.3, 0.3), 0.5)

	var tween := create_tween()
	var base_x: float = position.x
	tween.tween_property(self, "position:x", base_x + 0.2, 0.05)
	tween.tween_property(self, "position:x", base_x - 0.2, 0.05)
	tween.tween_property(self, "position:x", base_x, 0.05)
	tween.tween_callback(func() -> void:
		_set_emission(Color.BLACK, 0.0)
		animation_finished.emit()
	)


func play_death_animation() -> void:
	## Sink into ground and fade out.
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", position.y - 0.5, 0.5)
	if _model:
		for child in _model.get_children():
			var mat: StandardMaterial3D = _get_child_material(child)
			if mat:
				mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(func() -> void: animation_finished.emit())


func play_cast_animation() -> void:
	## Stub for future spell casting animation.
	animation_finished.emit()


func play_idle_animation() -> void:
	## Stub for future idle/breathing animation.
	animation_finished.emit()


func set_highlight(active: bool) -> void:
	if active:
		_set_emission(Color(1, 1, 1), 0.3)
	else:
		_set_emission(Color.BLACK, 0.0)


func get_global_center() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)
