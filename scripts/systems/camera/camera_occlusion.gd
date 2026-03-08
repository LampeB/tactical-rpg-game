class_name CameraOcclusion
extends Node
## Fades objects that stand between the camera and the player so the
## character is always visible.  Uses 3D AABB-segment intersection to
## detect occlusion and GeometryInstance3D.transparency to fade.

const AABB_MARGIN := 0.3        ## Extra padding around each object's bounding box
const FADE_ALPHA := 0.8         ## Target transparency when fading (0=opaque, 1=invisible)
const FADE_SPEED := 10.0        ## Lerp speed for smooth transitions
const PLAYER_SPREAD := 0.4      ## Lateral offset for extra test rays around player

var camera: OrbitCamera
var player: Node3D

## node instance_id → current transparency float
var _fade_states: Dictionary = {}
## node instance_id → cached Array[GeometryInstance3D]
var _geometry_cache: Dictionary = {}
## node instance_id → cached global AABB (decorations don't move)
var _aabb_cache: Dictionary = {}


func _process(delta: float) -> void:
	if not camera or not player:
		return
	var cam_node: Camera3D = camera.get_node("PitchNode/Camera3D") as Camera3D
	if not cam_node:
		return

	var cam_pos: Vector3 = cam_node.global_position
	var player_pos: Vector3 = player.global_position

	# Build a few test segments: center + lateral offsets for wider coverage
	var forward: Vector3 = (player_pos - cam_pos).normalized()
	var lateral: Vector3 = forward.cross(Vector3.UP).normalized() * PLAYER_SPREAD
	var segments: Array[Vector3] = [
		player_pos,
		player_pos + lateral,
		player_pos - lateral,
		player_pos + Vector3.UP * PLAYER_SPREAD,
	]

	var occluders: Array[Node] = get_tree().get_nodes_in_group("occludable")

	# Track which nodes should be faded this frame
	var should_fade: Dictionary = {}

	for node in occluders:
		if not is_instance_valid(node) or not node is Node3D:
			continue
		var n3d: Node3D = node as Node3D
		var aabb: AABB = _get_global_aabb(n3d)
		if aabb.size == Vector3.ZERO:
			continue

		# Test each ray segment against the object's bounding box
		for target in segments:
			if aabb.intersects_segment(cam_pos, target):
				should_fade[node.get_instance_id()] = node
				break

	# Update fade states
	var to_remove: Array[int] = []

	# Fade nodes that should be faded
	for nid: int in should_fade:
		var n: Node3D = should_fade[nid] as Node3D
		var current: float = _fade_states.get(nid, 0.0) as float
		current = lerpf(current, FADE_ALPHA, FADE_SPEED * delta)
		if absf(current - FADE_ALPHA) < 0.01:
			current = FADE_ALPHA
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


func _get_global_aabb(node: Node3D) -> AABB:
	## Returns the cached global AABB for a node (computed once since decorations are static).
	var nid: int = node.get_instance_id()
	if _aabb_cache.has(nid):
		return _aabb_cache[nid]

	# Collect geometry instances and merge their AABBs in global space
	if not _geometry_cache.has(nid):
		_geometry_cache[nid] = _collect_geometry_instances(node)
	var geos: Array = _geometry_cache[nid] as Array

	var merged := AABB()
	var first := true
	for geo: GeometryInstance3D in geos:
		if not is_instance_valid(geo):
			continue
		var global_aabb: AABB = _local_aabb_to_global(geo.get_aabb(), geo.global_transform)
		if first:
			merged = global_aabb
			first = false
		else:
			merged = merged.merge(global_aabb)

	if not first:
		merged = merged.grow(AABB_MARGIN)

	_aabb_cache[nid] = merged
	return merged


func _local_aabb_to_global(local_aabb: AABB, xform: Transform3D) -> AABB:
	## Transforms a local AABB to global space by transforming all 8 corners.
	var corners: Array[Vector3] = []
	var pos: Vector3 = local_aabb.position
	var sz: Vector3 = local_aabb.size
	corners.append(xform * pos)
	corners.append(xform * Vector3(pos.x + sz.x, pos.y, pos.z))
	corners.append(xform * Vector3(pos.x, pos.y + sz.y, pos.z))
	corners.append(xform * Vector3(pos.x, pos.y, pos.z + sz.z))
	corners.append(xform * Vector3(pos.x + sz.x, pos.y + sz.y, pos.z))
	corners.append(xform * Vector3(pos.x + sz.x, pos.y, pos.z + sz.z))
	corners.append(xform * Vector3(pos.x, pos.y + sz.y, pos.z + sz.z))
	corners.append(xform * (pos + sz))

	var result := AABB(corners[0], Vector3.ZERO)
	for ci in range(1, corners.size()):
		result = result.expand(corners[ci])
	return result


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
