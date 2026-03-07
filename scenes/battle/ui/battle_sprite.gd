extends Node3D
## Displays a 3D CSG model for a combat entity on the battlefield.
## Supports awaitable animations for sequenced combat flow.

signal animation_finished
signal clicked(entity: CombatEntity)
signal mouse_entered_sprite(entity: CombatEntity)
signal mouse_exited_sprite(entity: CombatEntity)

enum AttackAnimType { LUNGE, SLASH, BASH, SHOOT, CAST }

var _entity: CombatEntity
var _model: Node3D = null
var _click_area: Area3D = null
var _animator: ModelAnimator = null

# Cached limb references for attack animations (humanoid models only)
var _left_arm: Node3D = null
var _right_arm: Node3D = null
var _left_forearm: Node3D = null
var _right_forearm: Node3D = null
var _left_hand: Node3D = null
var _right_hand: Node3D = null
var _has_limbs: bool = false

# Torso and leg references for full-body attack animations
var _hip: Node3D = null
var _belly: Node3D = null
var _chest: Node3D = null
var _left_thigh: Node3D = null
var _right_thigh: Node3D = null
var _left_calf: Node3D = null
var _right_calf: Node3D = null
var _left_foot: Node3D = null
var _right_foot: Node3D = null


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

	# Face units toward opponents along the X axis.
	# Voxel models default to facing -Z; rotate to face ±X for side-view layout.
	if entity.is_player:
		_model.rotation.y = -PI / 2.0  # Face +X (toward enemies)
	else:
		_model.rotation.y = PI / 2.0   # Face -X (toward players)

	# Attach idle breathing animator
	_animator = ModelAnimator.new()
	add_child(_animator)
	_animator.setup(_model)

	# Cache all body part references for full-body attack animations
	_hip = _find_part(_model, "Hip")
	if _hip:
		# 16-part skeleton — find parts in hierarchy
		_belly = _find_part(_hip, "Belly")
		_chest = _find_part(_hip, "Chest")
		var chest_or_model: Node3D = _chest if _chest else _model
		_left_arm = _find_part(chest_or_model, "LeftArm")
		_right_arm = _find_part(chest_or_model, "RightArm")
		_left_thigh = _find_part(_hip, "LeftThigh")
		_right_thigh = _find_part(_hip, "RightThigh")
	else:
		# 10-part or flat hierarchy
		_left_arm = _find_part(_model, "LeftArm")
		_right_arm = _find_part(_model, "RightArm")

	_has_limbs = _left_arm != null and _right_arm != null
	if not _has_limbs:
		push_warning("BattleSprite: no limbs found for %s (L=%s R=%s)" % [
			entity.entity_name,
			str(_left_arm != null),
			str(_right_arm != null)])

	# Forearms and hands
	if _left_arm:
		_left_forearm = _find_part(_left_arm, "LeftForearm")
		_left_hand = _find_part(_left_arm, "LeftHand")
	if _right_arm:
		_right_forearm = _find_part(_right_arm, "RightForearm")
		_right_hand = _find_part(_right_arm, "RightHand")
	# Calves and feet
	if _left_thigh:
		_left_calf = _find_part(_left_thigh, "LeftLeg")
		_left_foot = _find_part(_left_thigh, "LeftFoot")
	if _right_thigh:
		_right_calf = _find_part(_right_thigh, "RightLeg")
		_right_foot = _find_part(_right_thigh, "RightFoot")

	# Build click detection area
	_build_click_area()


func _find_part(parent: Node3D, part_name: String) -> Node3D:
	var node: Node = parent.get_node_or_null(part_name)
	if not node:
		node = parent.find_child(part_name, true, false)
	if node is Node3D:
		return node as Node3D
	return null


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

func _get_all_materials() -> Array:
	## Collects all StandardMaterial3D instances from the model tree.
	## Recursively handles nested structures (hands inside arms, feet inside legs).
	var mats: Array = []
	if not _model:
		return mats
	_collect_materials_recursive(_model, mats)
	return mats


func _collect_materials_recursive(node: Node, mats: Array) -> void:
	for child in node.get_children():
		var mat: StandardMaterial3D = _get_node_material(child)
		if mat:
			mats.append(mat)
		if child.get_child_count() > 0:
			_collect_materials_recursive(child, mats)


func _set_emission(color: Color, energy: float) -> void:
	for mat in _get_all_materials():
		if energy > 0:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = energy
		else:
			mat.emission_enabled = false


static func _get_node_material(node: Node) -> StandardMaterial3D:
	if node is CSGShape3D and node.material is StandardMaterial3D:
		return node.material as StandardMaterial3D
	if node is MeshInstance3D:
		var mi: MeshInstance3D = node as MeshInstance3D
		if mi.mesh and mi.mesh.get_surface_count() > 0:
			var mat: Material = mi.mesh.surface_get_material(0)
			if mat is StandardMaterial3D:
				return mat as StandardMaterial3D
	return null


# === Awaitable Animations ===

func play_attack_animation() -> void:
	## Weapon-type-specific attack animation. Falls back to lunge for non-humanoid.
	var anim_type: AttackAnimType = _determine_attack_anim()
	var lunge_dir: float = 1.0 if _entity.is_player else -1.0

	match anim_type:
		AttackAnimType.SLASH:
			_play_slash_anim(lunge_dir)
		AttackAnimType.BASH:
			_play_bash_anim(lunge_dir)
		AttackAnimType.SHOOT:
			_play_shoot_anim(lunge_dir)
		AttackAnimType.CAST:
			_play_cast_anim()
		_:
			_play_lunge_anim(lunge_dir)


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
	for mat in _get_all_materials():
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.chain().tween_callback(func() -> void: animation_finished.emit())


func play_cast_animation() -> void:
	## Dedicated cast animation for skills that use magic.
	## Humanoids get full channel/release/recoil; others get squash + glow.
	if _has_limbs:
		_play_cast_anim()
	else:
		_play_cast_no_limbs()


func play_idle_animation() -> void:
	## Stub — idle breathing handled by ModelAnimator._process().
	animation_finished.emit()


# === Attack Animation Helpers ===

func _determine_attack_anim() -> AttackAnimType:
	if not _has_limbs:
		return AttackAnimType.LUNGE

	if _entity.is_player and _entity.grid_inventory:
		var placed_items: Array = _entity.grid_inventory.get_all_placed_items()
		for i in range(placed_items.size()):
			var placed: GridInventory.PlacedItem = placed_items[i]
			if placed.item_data.item_type == Enums.ItemType.ACTIVE_TOOL:
				match placed.item_data.category:
					Enums.EquipmentCategory.SWORD, \
					Enums.EquipmentCategory.AXE, \
					Enums.EquipmentCategory.DAGGER:
						return AttackAnimType.SLASH
					Enums.EquipmentCategory.MACE, \
					Enums.EquipmentCategory.SHIELD:
						return AttackAnimType.BASH
					Enums.EquipmentCategory.BOW:
						return AttackAnimType.SHOOT
					Enums.EquipmentCategory.STAFF:
						return AttackAnimType.CAST
		return AttackAnimType.LUNGE

	if not _entity.is_player and _entity.enemy_data:
		if _entity.enemy_data.damage_type == Enums.DamageType.MAGICAL:
			return AttackAnimType.CAST
		return AttackAnimType.LUNGE

	return AttackAnimType.LUNGE


func _pause_animator() -> void:
	if _animator:
		_animator.reset_pose()
		_animator.set_process(false)


func _resume_animator() -> void:
	if _animator:
		_animator.set_process(true)


func _play_lunge_anim(lunge_dir: float) -> void:
	## Default lunge: punch with step forward.
	## rotation.x signs: negative = arm back, positive = arm forward (model-local space).
	_pause_animator()
	var base_x: float = position.x
	var base_y: float = position.y
	var tween := create_tween()

	if _has_limbs:
		# Wind-up — arm back, forearm curls
		tween.set_parallel(true)
		tween.tween_property(_right_arm, "rotation:x", -0.8, 0.20)
		if _right_forearm:
			tween.tween_property(_right_forearm, "rotation:x", 2.2, 0.20)
		if _chest:
			tween.tween_property(_chest, "rotation:y", -0.3, 0.20)
		tween.set_parallel(false)
		tween.tween_interval(0.3)
		# Return
		tween.set_parallel(true)
		_tween_reset_all(tween, 0.15)
		tween.set_parallel(false)
	else:
		# No limbs — hop-lunge
		tween.set_parallel(true)
		tween.tween_property(self, "position:x", base_x + lunge_dir * 1.2, 0.15)
		tween.tween_property(self, "position:y", base_y + 0.15, 0.08)
		tween.set_parallel(false)
		tween.set_parallel(true)
		tween.tween_property(self, "position:x", base_x, 0.18)
		tween.tween_property(self, "position:y", base_y, 0.18)
		tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_slash_anim(_lunge_dir: float) -> void:
	## Slash: wind-up, hold, return. Same as confirmed working test.
	_pause_animator()
	var tween := create_tween()

	# Wind-up — arm back, forearm curls (confirmed working)
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -0.8, 0.20)
	if _right_forearm:
		tween.tween_property(_right_forearm, "rotation:x", 2.2, 0.20)
	if _chest:
		tween.tween_property(_chest, "rotation:y", -0.3, 0.20)
	tween.set_parallel(false)

	# Hold so pose is visible
	tween.tween_interval(0.3)

	# Return
	tween.set_parallel(true)
	_tween_reset_all(tween, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_bash_anim(_lunge_dir: float) -> void:
	## Bash: same test as all others for now.
	_pause_animator()
	var tween := create_tween()

	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -0.8, 0.20)
	if _right_forearm:
		tween.tween_property(_right_forearm, "rotation:x", 2.2, 0.20)
	if _chest:
		tween.tween_property(_chest, "rotation:y", -0.3, 0.20)
	tween.set_parallel(false)
	tween.tween_interval(0.3)
	tween.set_parallel(true)
	_tween_reset_all(tween, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_shoot_anim(_lunge_dir: float) -> void:
	## Shoot: same test as all others for now.
	_pause_animator()
	var tween := create_tween()

	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -0.8, 0.20)
	if _right_forearm:
		tween.tween_property(_right_forearm, "rotation:x", 2.2, 0.20)
	if _chest:
		tween.tween_property(_chest, "rotation:y", -0.3, 0.20)
	tween.set_parallel(false)
	tween.tween_interval(0.3)
	tween.set_parallel(true)
	_tween_reset_all(tween, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_cast_anim() -> void:
	## Cast: same test as all others for now.
	_pause_animator()
	var tween := create_tween()

	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -0.8, 0.20)
	if _right_forearm:
		tween.tween_property(_right_forearm, "rotation:x", 2.2, 0.20)
	if _chest:
		tween.tween_property(_chest, "rotation:y", -0.3, 0.20)
	tween.set_parallel(false)
	tween.tween_interval(0.3)
	tween.set_parallel(true)
	_tween_reset_all(tween, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _tween_reset_all(tween: Tween, duration: float) -> void:
	## Tween all cached body parts back to rotation zero. Must be called inside
	## a parallel tween block — caller handles set_parallel(true/false).
	if _right_arm:
		tween.tween_property(_right_arm, "rotation:x", 0.0, duration)
	if _left_arm:
		tween.tween_property(_left_arm, "rotation:x", 0.0, duration)
	if _right_forearm:
		tween.tween_property(_right_forearm, "rotation:x", 0.0, duration)
	if _left_forearm:
		tween.tween_property(_left_forearm, "rotation:x", 0.0, duration)
	if _right_hand:
		tween.tween_property(_right_hand, "rotation:x", 0.0, duration)
	if _left_hand:
		tween.tween_property(_left_hand, "rotation:x", 0.0, duration)
	if _chest:
		tween.tween_property(_chest, "rotation:x", 0.0, duration)
		tween.tween_property(_chest, "rotation:y", 0.0, duration)
	if _belly:
		tween.tween_property(_belly, "rotation:x", 0.0, duration)
	if _left_thigh:
		tween.tween_property(_left_thigh, "rotation:x", 0.0, duration)
	if _right_thigh:
		tween.tween_property(_right_thigh, "rotation:x", 0.0, duration)
	if _left_calf:
		tween.tween_property(_left_calf, "rotation:x", 0.0, duration)
	if _right_calf:
		tween.tween_property(_right_calf, "rotation:x", 0.0, duration)
	if _left_foot:
		tween.tween_property(_left_foot, "rotation:x", 0.0, duration)
	if _right_foot:
		tween.tween_property(_right_foot, "rotation:x", 0.0, duration)


func _play_cast_no_limbs() -> void:
	## Non-humanoid cast: squash/stretch pulse with glow build and flash.
	_pause_animator()
	var base_y: float = position.y
	var base_scale: Vector3 = _model.scale if _model else Vector3.ONE
	var tween := create_tween()

	# Channel: squash down + dim glow
	tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.3))
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", base_y - 0.08, 0.15)
	if _model:
		tween.tween_property(_model, "scale:y", base_scale.y * 0.8, 0.15)
		tween.tween_property(_model, "scale:x", base_scale.x * 1.15, 0.15)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: _set_emission(Color(0.5, 0.7, 1.0), 0.6))
	tween.tween_interval(0.08)

	# Release: stretch up + bright flash
	tween.tween_callback(func() -> void: _set_emission(Color(0.7, 0.85, 1.0), 1.2))
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", base_y + 0.15, 0.1).set_ease(Tween.EASE_IN)
	if _model:
		tween.tween_property(_model, "scale:y", base_scale.y * 1.2, 0.1).set_ease(Tween.EASE_IN)
		tween.tween_property(_model, "scale:x", base_scale.x * 0.85, 0.1).set_ease(Tween.EASE_IN)
	tween.set_parallel(false)

	# Settle: return to rest
	tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.3))
	tween.set_parallel(true)
	tween.tween_property(self, "position:y", base_y, 0.15)
	if _model:
		tween.tween_property(_model, "scale", base_scale, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_set_emission(Color.BLACK, 0.0)
		_resume_animator()
		animation_finished.emit()
	)


func play_defend_animation() -> void:
	## Guard pose animation: arms cross for humanoid, squash for non-humanoid.
	_pause_animator()
	var tween := create_tween()

	if _has_limbs:
		# Blue glow guard stance (body part animations TBD)
		tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.5))
		tween.tween_interval(0.12)
	else:
		# Squash down + blue glow
		tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.5))
		if _model:
			tween.set_parallel(true)
			tween.tween_property(_model, "scale:y", _model.scale.y * 0.85, 0.1)
			tween.tween_property(_model, "scale:x", _model.scale.x * 1.1, 0.1)
			tween.set_parallel(false)
			tween.tween_property(_model, "scale", _model.scale, 0.15)

	tween.tween_callback(func() -> void:
		_set_emission(Color(0.3, 0.5, 1.0), 0.3)
		_resume_animator()
		animation_finished.emit()
	)


func show_defend_indicator(active: bool) -> void:
	## Persistent blue emission glow while entity is defending.
	if active:
		_set_emission(Color(0.3, 0.5, 1.0), 0.3)
	else:
		_set_emission(Color.BLACK, 0.0)


func set_highlight(active: bool) -> void:
	if active:
		_set_emission(Color(1, 1, 1), 0.3)
	else:
		_set_emission(Color.BLACK, 0.0)


func get_global_center() -> Vector3:
	return global_position + Vector3(0, 1.0, 0)
