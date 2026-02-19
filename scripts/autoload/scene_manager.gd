extends Node
## Manages scene transitions with fade effects and a scene stack for back-navigation.

const FADE_DURATION := 0.3

var _scene_stack: Array[String] = []
var _transition_overlay: ColorRect
var _is_transitioning: bool = false

# Pending navigation request (queued if called during a transition)
var _pending_request: Dictionary = {}  ## {type, path, data}

func _ready():
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
func push_scene(scene_path: String, data: Dictionary = {}):
	if _is_transitioning:
		DebugLogger.log_warning("Transition in progress — queuing push: %s" % scene_path, "SceneManager")
		_pending_request = {"type": "push", "path": scene_path, "data": data}
		return
	# Save current scene to stack
	var current := get_tree().current_scene
	if current and current.scene_file_path:
		_scene_stack.append(current.scene_file_path)
	_change_scene(scene_path, data)

## Replace the current scene (no history — can't go back).
func replace_scene(scene_path: String, data: Dictionary = {}):
	if _is_transitioning:
		DebugLogger.log_warning("Transition in progress — queuing replace: %s" % scene_path, "SceneManager")
		_pending_request = {"type": "replace", "path": scene_path, "data": data}
		return
	_change_scene(scene_path, data)

## Go back to the previous scene in the stack.
func pop_scene(data: Dictionary = {}):
	if _is_transitioning:
		DebugLogger.log_warning("Transition in progress — queuing pop", "SceneManager")
		_pending_request = {"type": "pop", "data": data}
		return
	if _scene_stack.is_empty():
		DebugLogger.log_warn("Scene stack is empty, cannot pop", "SceneManager")
		return
	var previous: String = _scene_stack.pop_back()
	_change_scene(previous, data)

## Clear the entire scene stack.
func clear_stack():
	_scene_stack.clear()

func can_go_back() -> bool:
	return not _scene_stack.is_empty()

func _change_scene(scene_path: String, data: Dictionary):
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

	# Wait for the new scene to fully initialize
	await get_tree().process_frame
	await get_tree().process_frame

	# Pass data to the new scene if it has a receive_data method
	var new_scene := get_tree().current_scene
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


func _flush_pending():
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
