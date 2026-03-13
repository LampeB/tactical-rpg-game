extends Node
## Manages game language / locale. Wraps TranslationServer with persistence.
## Loads CSV translations at startup and exposes a simple API for switching.

const SAVE_PATH := "user://locale_settings.json"
const DEFAULT_LOCALE := "en"

## Supported locales: code -> display name.
const LANGUAGES := {
	"en": "English",
	"fr": "Français",
}

var current_locale: String = DEFAULT_LOCALE


func _ready() -> void:
	_load_settings()
	_apply_locale()


func set_locale(locale_code: String) -> void:
	if not LANGUAGES.has(locale_code):
		DebugLogger.log_warn("Unknown locale: %s" % locale_code, "LocaleManager")
		return
	current_locale = locale_code
	_apply_locale()
	_save_settings()
	DebugLogger.log_info("Locale changed to: %s (%s)" % [locale_code, LANGUAGES[locale_code]], "LocaleManager")


func get_locale_display_name(locale_code: String) -> String:
	return LANGUAGES.get(locale_code, locale_code)


func get_supported_locales() -> Array:
	return LANGUAGES.keys()


func _apply_locale() -> void:
	TranslationServer.set_locale(current_locale)


func _load_settings() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	var parse_result := json.parse(file.get_as_text())
	file.close()
	if parse_result != OK:
		return
	var data: Dictionary = json.data
	current_locale = data.get("locale", DEFAULT_LOCALE)


func _save_settings() -> void:
	var data := {"locale": current_locale}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if not file:
		push_error("Failed to save locale settings")
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
