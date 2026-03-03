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
var _has_limbs: bool = false


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

	# Attach idle breathing animator
	_animator = ModelAnimator.new()
	add_child(_animator)
	_animator.setup(_model)

	# Cache limb references for attack animations
	_left_arm = _model.get_node_or_null("LeftArm")
	_right_arm = _model.get_node_or_null("RightArm")
	_has_limbs = _left_arm != null and _right_arm != null

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

func _get_all_materials() -> Array:
	## Collects all StandardMaterial3D instances from the model tree.
	## Handles both flat (CSG/single-vox) and nested (multi-part vox) structures.
	var mats: Array = []
	if not _model:
		return mats
	for child in _model.get_children():
		var mat: StandardMaterial3D = _get_node_material(child)
		if mat:
			mats.append(mat)
		# Check grandchildren for multi-part models (root > pivot > Mesh)
		for grandchild in child.get_children():
			mat = _get_node_material(grandchild)
			if mat:
				mats.append(mat)
	return mats


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
	## Default lunge: quick forward-back on X axis.
	_pause_animator()
	var base_x: float = position.x
	var tween := create_tween()
	tween.tween_property(self, "position:x", base_x + lunge_dir, 0.15)
	tween.tween_property(self, "position:x", base_x, 0.15)
	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_slash_anim(lunge_dir: float) -> void:
	## Slash: right arm swings forward, slight body lunge.
	_pause_animator()
	var base_x: float = position.x
	var tween := create_tween()

	# Wind up — pull arm back
	tween.tween_property(_right_arm, "rotation:x", -0.6, 0.08)

	# Swing forward + lunge
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.8, 0.12)
	tween.tween_property(self, "position:x", base_x + lunge_dir * 0.4, 0.12)
	tween.set_parallel(false)

	# Return to neutral
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.0, 0.15)
	tween.tween_property(self, "position:x", base_x, 0.15)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_bash_anim(lunge_dir: float) -> void:
	## Bash: both arms raise then slam down with a small hop.
	_pause_animator()
	var base_x: float = position.x
	var base_y: float = position.y
	var tween := create_tween()

	# Raise arms + hop
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -1.0, 0.12)
	tween.tween_property(_left_arm, "rotation:x", -1.0, 0.12)
	tween.tween_property(self, "position:y", base_y + 0.15, 0.12)
	tween.set_parallel(false)

	# Slam down + lunge
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.5, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(_left_arm, "rotation:x", 0.5, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", base_y, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", base_x + lunge_dir * 0.3, 0.1)
	tween.set_parallel(false)

	# Reset
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.0, 0.13)
	tween.tween_property(_left_arm, "rotation:x", 0.0, 0.13)
	tween.tween_property(self, "position:x", base_x, 0.13)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_shoot_anim(lunge_dir: float) -> void:
	## Shoot: draw back then snap release forward.
	_pause_animator()
	var base_x: float = position.x
	var tween := create_tween()

	# Draw back — pull right arm back, lean body away
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -0.8, 0.15)
	tween.tween_property(self, "position:x", base_x - lunge_dir * 0.2, 0.15)
	tween.set_parallel(false)

	# Release — snap arm forward, small lunge
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.4, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", base_x + lunge_dir * 0.15, 0.1)
	tween.set_parallel(false)

	# Return to neutral
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.0, 0.1)
	tween.tween_property(self, "position:x", base_x, 0.1)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


func _play_cast_anim() -> void:
	## Cast with 3 phases: channel (arms raise + glow builds), release (thrust +
	## bright flash), recoil (small backward step + fade).
	_pause_animator()
	var base_x: float = position.x
	var base_y: float = position.y
	var lunge_dir: float = 1.0 if _entity.is_player else -1.0
	var tween := create_tween()

	# Phase 1 — Channel: arms raise, body lifts, glow builds
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", -1.2, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(_left_arm, "rotation:x", -1.2, 0.18).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", base_y + 0.1, 0.18)
	tween.set_parallel(false)
	tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.3))
	tween.tween_interval(0.08)
	tween.tween_callback(func() -> void: _set_emission(Color(0.5, 0.7, 1.0), 0.6))
	tween.tween_interval(0.06)

	# Phase 2 — Release: arms thrust forward, bright flash, slight lunge
	tween.tween_callback(func() -> void: _set_emission(Color(0.7, 0.85, 1.0), 1.2))
	tween.set_parallel(true)
	tween.tween_property(_right_arm, "rotation:x", 0.6, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(_left_arm, "rotation:x", 0.6, 0.1).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:x", base_x + lunge_dir * 0.25, 0.1)
	tween.tween_property(self, "position:y", base_y, 0.1)
	tween.set_parallel(false)

	# Phase 3 — Recoil: step back, glow fades, arms settle
	tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.3))
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", base_x - lunge_dir * 0.1, 0.1)
	tween.tween_property(_right_arm, "rotation:x", -0.15, 0.1)
	tween.tween_property(_left_arm, "rotation:x", -0.15, 0.1)
	tween.set_parallel(false)

	# Settle back to neutral
	tween.tween_callback(func() -> void: _set_emission(Color.BLACK, 0.0))
	tween.set_parallel(true)
	tween.tween_property(self, "position:x", base_x, 0.12)
	tween.tween_property(_right_arm, "rotation:x", 0.0, 0.12)
	tween.tween_property(_left_arm, "rotation:x", 0.0, 0.12)
	tween.set_parallel(false)

	tween.tween_callback(func() -> void:
		_resume_animator()
		animation_finished.emit()
	)


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
		# Arms cross into guard pose + blue glow
		tween.set_parallel(true)
		tween.tween_property(_right_arm, "rotation:x", -0.8, 0.12)
		tween.tween_property(_left_arm, "rotation:x", -0.8, 0.12)
		tween.set_parallel(false)
		tween.tween_callback(func() -> void: _set_emission(Color(0.4, 0.6, 1.0), 0.5))
		# Settle to subtle guard
		tween.set_parallel(true)
		tween.tween_property(_right_arm, "rotation:x", -0.4, 0.15)
		tween.tween_property(_left_arm, "rotation:x", -0.4, 0.15)
		tween.set_parallel(false)
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
