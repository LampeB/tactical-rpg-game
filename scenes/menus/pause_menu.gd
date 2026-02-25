extends Control
## In-game pause overlay. Instantiated directly by overworld (no scene transition).

signal resume_requested
signal save_requested
signal load_requested
signal main_menu_requested

@onready var _resume_btn: Button = $CenterContainer/Panel/Margin/VBox/ResumeButton
@onready var _save_btn: Button = $CenterContainer/Panel/Margin/VBox/SaveButton
@onready var _load_btn: Button = $CenterContainer/Panel/Margin/VBox/LoadButton
@onready var _main_menu_btn: Button = $CenterContainer/Panel/Margin/VBox/MainMenuButton


func _ready() -> void:
	_resume_btn.pressed.connect(func() -> void: resume_requested.emit())
	_save_btn.pressed.connect(func() -> void: save_requested.emit())
	_load_btn.pressed.connect(func() -> void: load_requested.emit())
	_main_menu_btn.pressed.connect(func() -> void: main_menu_requested.emit())

	_load_btn.disabled = not SaveManager.has_any_save()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("escape"):
		resume_requested.emit()
		get_viewport().set_input_as_handled()
