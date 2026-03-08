class_name CameraOcclusion
extends Node
## Fades objects that stand between the camera and the player so the
## character is always visible.  Uses XZ line-distance checks and
## GeometryInstance3D.transparency (no material modifications needed).

const OCCLUSION_RADIUS := 2.5   ## XZ distance from camera→player line to trigger fade
const FADE_ALPHA := 0.6         ## Target transparency when fading (0.0=opaque, 1.0=invisible)
const FADE_SPEED := 8.0         ## Lerp speed for smooth transitions

var camera: OrbitCamera
var player: Node3D

## node instance_id → current transparency float
var _fade_states: Dictionary = {}
## node instance_id → cached Array[GeometryInstance3D]
var _geometry_cache: Dictionary = {}


func _process(delta: float) -> void:
	if not camera or not player:
		return
	var cam_node: Camera3D = camera.get_node("PitchNode/Camera3D") as Camera3D
	if not cam_node:
		return

	var cam_pos: Vector3 = cam_node.global_position
	var player_pos: Vector3 = player.global_position

	# Project to XZ plane
	var cam_xz := Vector2(cam_pos.x, cam_pos.z)
	var player_xz := Vector2(player_pos.x, player_pos.z)
	var line_dir: Vector2 = player_xz - cam_xz
	var line_len_sq: float = line_dir.length_squared()

	if line_len_sq < 0.001:
		return

	var occluders: Array[Node] = get_tree().get_nodes_in_group("occludable")
	var radius_sq: float = OCCLUSION_RADIUS * OCCLUSION_RADIUS

	# Track which nodes should be faded this frame
	var should_fade: Dictionary = {}

	for node in occluders:
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var n3d: Node3D = node as Node3D
		var obj_xz := Vector2(n3d.global_position.x, n3d.global_position.z)

		# Project onto camera→player line: t=0 at camera, t=1 at player
		var to_obj: Vector2 = obj_xz - cam_xz
		var t: float = to_obj.dot(line_dir) / line_len_sq

		if t <= 0.05 or t >= 0.95:
			continue

		# Perpendicular distance squared
		var proj: Vector2 = cam_xz + line_dir * t
		var dist_sq: float = (obj_xz - proj).length_squared()

		if dist_sq < radius_sq:
			should_fade[node.get_instance_id()] = node

	# Update fade states
	var to_remove: Array[int] = []

	# Fade in nodes that should be faded
	for nid: int in should_fade:
		var n: Node3D = should_fade[nid] as Node3D
		var current: float = _fade_states.get(nid, 0.0) as float
		var target: float = FADE_ALPHA
		current = lerpf(current, target, FADE_SPEED * delta)
		if absf(current - target) < 0.01:
			current = target
		_fade_states[nid] = current
		_apply_transparency(n, current)

	# Restore nodes that should no longer be faded
	for nid: int in _fade_states:
		if should_fade.has(nid):
			continue
		var n: Node3D = instance_from_id(nid) as Node3D
		if not is_instance_valid(n):
			to_remove.append(nid)
			continue
		var current: float = _fade_states[nid] as float
		current = lerpf(current, 0.0, FADE_SPEED * delta)
		if current < 0.01:
			current = 0.0
			to_remove.append(nid)
		_fade_states[nid] = current
		_apply_transparency(n, current)

	# Clean up fully-restored entries
	for nid: int in to_remove:
		_fade_states.erase(nid)
		_geometry_cache.erase(nid)


func _apply_transparency(node: Node3D, value: float) -> void:
	var nid: int = node.get_instance_id()
	if not _geometry_cache.has(nid):
		_geometry_cache[nid] = _collect_geometry_instances(node)
	var geos: Array = _geometry_cache[nid] as Array
	for geo: GeometryInstance3D in geos:
		if is_instance_valid(geo):
			geo.transparency = value


func _collect_geometry_instances(node: Node) -> Array[GeometryInstance3D]:
	var result: Array[GeometryInstance3D] = []
	if node is GeometryInstance3D:
		result.append(node as GeometryInstance3D)
	for child in node.get_children():
		result.append_array(_collect_geometry_instances(child))
	return result
