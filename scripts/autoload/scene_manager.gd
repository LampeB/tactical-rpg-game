extends Node
## Manages scene transitions with fade effects and a scene stack for back-navigation.
## push_scene stashes the current scene node in memory (no rebuild on pop).
## replace_scene frees the current scene (full rebuild on next visit).

const FADE_DURATION := 0.15

var _scene_stack: Array[Dictionary] = []  ## [{node: Node, path: String}]
var _transition_overlay: ColorRect
var _is_transitioning: bool = false

# Pending navigation request (queued if called during a transition)
var _pending_request: Dictionary = {}  ## {type, path, data}

func _ready() -> void:
	# Create a persistent overlay for fade transitions
	_transition_overlay = ColorRect.new()
	_transition_overlay.color = Color.BLACK
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_transition_overlay.modulate.a = 0.0
	# Use a CanvasLayer so it draws on top of everything
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	canvas.add_child(_transition_overlay)
	add_child(canvas)
	# Resize overlay to fill screen
	_transition_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	DebugLogger.log_info("SceneManager ready", "SceneManager")

## Push a new scene onto the stack (keeps history for back navigation).
## The current scene is stashed in memory and restored on pop (no rebuild).
func push_scene(scene_path: String, data: Dictionary = {}) -> void:
	if _is_transitioning:
		DebugLogger.log_warn("Transition in progress — queuing push: %s" % scene_path, "SceneManager")
		_pending_request = {"type": "push", "path": scene_path, "data": data}
		return
	_push_and_change(scene_path, data)

## Replace the current scene (no history — can't go back).
func replace_scene(scene_path: String, data: Dictionary = {}) -> void:
	if _is_transitioning:
		DebugLogger.log_warn("Transition in progress — queuing replace: %s" % scene_path, "SceneManager")
		_pending_request = {"type": "replace", "path": scene_path, "data": data}
		return
	_change_scene(scene_path, data)

## Go back to the previous scene in the stack.
## Restores the stashed scene node (no rebuild).
func pop_scene(data: Dictionary = {}) -> void:
	if _is_transitioning:
		DebugLogger.log_warn("Transition in progress — queuing pop", "SceneManager")
		_pending_request = {"type": "pop", "data": data}
		return
	if _scene_stack.is_empty():
		DebugLogger.log_warn("Scene stack is empty, cannot pop", "SceneManager")
		return
	var entry: Dictionary = _scene_stack.pop_back()
	var stashed_node: Node = entry.get("node")
	if stashed_node and is_instance_valid(stashed_node):
		_restore_scene(stashed_node, data)
	else:
		# Fallback: stashed node was freed, reload from file
		var path: String = entry.get("path", "")
		if not path.is_empty():
			_change_scene(path, data)

## Clear the entire scene stack (frees all stashed scenes).
func clear_stack() -> void:
	for entry in _scene_stack:
		var stashed_node: Node = entry.get("node")
		if stashed_node and is_instance_valid(stashed_node):
			stashed_node.queue_free()
	_scene_stack.clear()

func can_go_back() -> bool:
	return not _scene_stack.is_empty()


func _push_and_change(scene_path: String, data: Dictionary) -> void:
	## Stashes the current scene node (removed from tree but kept alive),
	## then loads the new scene.
	_is_transitioning = true
	DebugLogger.log_scene_change(scene_path.get_file().get_basename())

	# Fade out
	var tween := create_tween()
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# Stash the current scene — remove from tree but don't free
	var current: Node = get_tree().current_scene
	if current:
		var path: String = current.scene_file_path
		get_tree().root.remove_child(current)
		get_tree().current_scene = null
		_scene_stack.append({"node": current, "path": path})
		DebugLogger.log_info("Stashed scene: %s" % current.name, "SceneManager")

	# Load new scene
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		DebugLogger.log_error("Failed to change scene to: %s (error %d)" % [scene_path, err], "SceneManager")
		_is_transitioning = false
		return

	await get_tree().process_frame
	await get_tree().process_frame

	var new_scene: Node = get_tree().current_scene
	if new_scene and new_scene.has_method("receive_data") and not data.is_empty():
		new_scene.receive_data(data)
		DebugLogger.log_info("Passed data to %s" % new_scene.name, "SceneManager")

	# Fade in
	var tween_in := create_tween()
	tween_in.tween_property(_transition_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween_in.finished
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	_flush_pending()


func _restore_scene(stashed_node: Node, data: Dictionary) -> void:
	## Restores a stashed scene node to the tree (no rebuild, instant).
	_is_transitioning = true
	DebugLogger.log_scene_change(stashed_node.name)

	# Fade out
	var tween := create_tween()
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# Free the current (menu) scene
	var current: Node = get_tree().current_scene
	if current:
		current.queue_free()
		await get_tree().process_frame

	# Re-add stashed scene
	get_tree().root.add_child(stashed_node)
	get_tree().current_scene = stashed_node
	DebugLogger.log_info("Restored stashed scene: %s" % stashed_node.name, "SceneManager")

	await get_tree().process_frame

	# Always notify the restored scene so it can refresh (e.g. HUD after inventory)
	if stashed_node.has_method("receive_data"):
		stashed_node.receive_data(data)
		DebugLogger.log_info("Passed data to %s" % stashed_node.name, "SceneManager")

	# Fade in
	var tween_in := create_tween()
	tween_in.tween_property(_transition_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween_in.finished
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false
	_flush_pending()


func _change_scene(scene_path: String, data: Dictionary) -> void:
	## Full scene change — frees the current scene and loads a new one from file.
	_is_transitioning = true
	DebugLogger.log_scene_change(scene_path.get_file().get_basename())

	# Fade out
	var tween := create_tween()
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	tween.tween_property(_transition_overlay, "modulate:a", 1.0, FADE_DURATION)
	await tween.finished

	# Change scene
	var err := get_tree().change_scene_to_file(scene_path)
	if err != OK:
		DebugLogger.log_error("Failed to change scene to: %s (error %d)" % [scene_path, err], "SceneManager")
		_is_transitioning = false
		return

	# Two frames: first lets the deferred scene swap complete and _ready() run,
	# second ensures child _ready() callbacks have all propagated before receive_data.
	await get_tree().process_frame
	await get_tree().process_frame

	# Pass data to the new scene if it has a receive_data method
	var new_scene: Node = get_tree().current_scene
	if new_scene and new_scene.has_method("receive_data") and not data.is_empty():
		new_scene.receive_data(data)
		DebugLogger.log_info("Passed data to %s" % new_scene.name, "SceneManager")

	# Fade in
	var tween_in := create_tween()
	tween_in.tween_property(_transition_overlay, "modulate:a", 0.0, FADE_DURATION)
	await tween_in.finished
	_transition_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_is_transitioning = false

	# Execute pending request if one was queued during the transition
	_flush_pending()


func _flush_pending() -> void:
	if _pending_request.is_empty():
		return
	var req: Dictionary = _pending_request
	_pending_request = {}
	DebugLogger.log_info("Executing pending %s request" % req.type, "SceneManager")
	match req.type:
		"push":
			push_scene(req.path, req.get("data", {}))
		"replace":
			replace_scene(req.path, req.get("data", {}))
		"pop":
			pop_scene(req.get("data", {}))
