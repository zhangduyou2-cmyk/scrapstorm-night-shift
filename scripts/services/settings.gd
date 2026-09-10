extends Node
## Cross-scene preferences. First launch is English on every operating system.

signal preferences_changed

const SUPPORTED_LOCALES: Array[String] = ["en", "zh_CN"]
const DEFAULT_CONFIG_PATH := "user://settings.cfg"
const TEST_CONFIG_PATH := "user://settings-test-%d.cfg"

var locale: String = "en"
var master_volume: float = 0.7
var effects_enabled: bool = true
var music_volume: float = 0.65
var sfx_volume: float = 0.8
var vacuum_toggle: bool = false
var tutorial_completed: bool = false
var key_bindings: Dictionary = {}
const DEFAULT_KEYS: Dictionary = {"move_left": KEY_A, "move_right": KEY_D, "move_up": KEY_W, "move_down": KEY_S, "dash": KEY_SPACE, "active_skill": KEY_E}
var _config_path: String = DEFAULT_CONFIG_PATH


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if OS.get_cmdline_user_args().has("--test-settings"):
		_config_path = TEST_CONFIG_PATH % OS.get_process_id()
	_load_preferences()
	TranslationServer.set_locale(locale)


func get_preferences_path() -> String:
	return _config_path


func set_locale(value: String) -> void:
	if value not in SUPPORTED_LOCALES or value == locale:
		return
	locale = value
	TranslationServer.set_locale(locale)
	save_preferences()
	preferences_changed.emit()


func set_volume(value: float) -> void:
	if not is_finite(value):
		return
	var next_volume := clampf(value, 0.0, 1.0)
	if is_equal_approx(master_volume, next_volume):
		return
	master_volume = next_volume
	save_preferences()
	preferences_changed.emit()


func set_effects(value: bool) -> void:
	if effects_enabled == value:
		return
	effects_enabled = value
	save_preferences()
	preferences_changed.emit()


func save_preferences() -> void:
	var config := ConfigFile.new()
	config.set_value("preferences", "locale", locale)
	config.set_value("preferences", "master_volume", master_volume)
	config.set_value("preferences", "effects_enabled", effects_enabled)
	config.set_value("preferences", "music_volume", music_volume)
	config.set_value("preferences", "sfx_volume", sfx_volume)
	config.set_value("preferences", "vacuum_toggle", vacuum_toggle)
	config.set_value("preferences", "tutorial_completed", tutorial_completed)
	config.set_value("preferences", "key_bindings", key_bindings)
	var result := config.save(_config_path)
	if result != OK:
		push_warning("Could not save preferences (%s)." % error_string(result))


func _load_preferences() -> void:
	var config := ConfigFile.new()
	if config.load(_config_path) != OK:
		return
	var saved_locale: Variant = config.get_value("preferences", "locale", "en")
	if saved_locale is String and saved_locale in SUPPORTED_LOCALES:
		locale = saved_locale
	var saved_volume: Variant = config.get_value("preferences", "master_volume", 0.7)
	if (saved_volume is float or saved_volume is int) and is_finite(float(saved_volume)):
		master_volume = clampf(float(saved_volume), 0.0, 1.0)
	var saved_effects: Variant = config.get_value("preferences", "effects_enabled", true)
	if saved_effects is bool:
		effects_enabled = saved_effects
	for field: String in ["music_volume", "sfx_volume"]:
		var saved: Variant = config.get_value("preferences", field, get(field))
		if (saved is float or saved is int) and is_finite(float(saved)):
			set(field, clampf(float(saved), 0.0, 1.0))
	for field: String in ["vacuum_toggle", "tutorial_completed"]:
		var saved: Variant = config.get_value("preferences", field, false)
		if saved is bool:
			set(field, saved)
	var saved_keys: Variant = config.get_value("preferences", "key_bindings", {})
	if saved_keys is Dictionary:
		var used: Array[int] = []
		for action: String in DEFAULT_KEYS:
			var key: Variant = saved_keys.get(action, DEFAULT_KEYS[action])
			if key is int and _valid_key(key) and key not in used:
				key_bindings[action] = key
				used.append(key)
		# Invalid or colliding profiles revert together, preserving usable controls.
		if key_bindings.size() != DEFAULT_KEYS.size():
			key_bindings.clear()


func set_music_volume(value: float) -> void:
	_set_mix("music_volume", value)


func set_sfx_volume(value: float) -> void:
	_set_mix("sfx_volume", value)


func _set_mix(field: String, value: float) -> void:
	if not is_finite(value):
		return
	set(field, clampf(value, 0.0, 1.0))
	save_preferences()
	preferences_changed.emit()


func set_vacuum_toggle(value: bool) -> void:
	vacuum_toggle = value
	save_preferences()
	preferences_changed.emit()


func set_tutorial_completed(value: bool) -> void:
	tutorial_completed = value
	save_preferences()
	preferences_changed.emit()


func _valid_key(key: int) -> bool:
	return key > 0 and key != KEY_ESCAPE and key not in [KEY_ALT, KEY_CTRL, KEY_SHIFT, KEY_META, KEY_TAB, KEY_ENTER]


func rebind(action: String, key: int) -> bool:
	if not DEFAULT_KEYS.has(action) or not _valid_key(key):
		return false
	for other: String in DEFAULT_KEYS:
		if other != action and get_key(other) == key:
			return false
	key_bindings[action] = key
	save_preferences()
	apply_input_bindings()
	preferences_changed.emit()
	return true


func get_key(action: String) -> int:
	return int(key_bindings.get(action, DEFAULT_KEYS.get(action, 0)))


func reset_keys() -> void:
	key_bindings.clear()
	save_preferences()
	apply_input_bindings()
	preferences_changed.emit()


func apply_input_bindings() -> void:
	for action: String in DEFAULT_KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		InputMap.action_erase_events(action)
		var event := InputEventKey.new()
		event.physical_keycode = get_key(action)
		InputMap.action_add_event(action, event)
