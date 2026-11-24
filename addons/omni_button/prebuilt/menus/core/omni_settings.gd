class_name OmniSettings
extends RefCounted
## the game's player settings (volume, window mode, text speed...). you define them once, they get
## saved to a file, and they're applied to the game whenever they change. it's static, so use it
## from anywhere, no node needed.
##
## each setting has a key ([code]"audio/music"[/code]), a default, and if you want a function that
## applies it. the options screen ([OmniOptionsMenu]) builds its rows from these, so a setting your
## game adds with [method define] shows up there without any extra ui work:
## [codeblock]
## OmniSettings.define("gameplay/screen_shake", true, {
##     "page": "Gameplay", "label": "Screen shake",
##     "apply": func(on: bool): Camera.shake_enabled = on,
## })
## var shake: bool = OmniSettings.get_value("gameplay/screen_shake")
## [/codeblock]
## the [code]OmniMenus[/code] autoload loads and applies the settings when the game starts, or the
## first menu that needs them does ([method ensure_loaded]). they get saved to
## [code]user://settings.cfg[/code] ([b]Project Settings > omni_button/menus/settings_path[/b]).

## how the options screen shows a setting.
enum Kind {
	SLIDER, ## a 0-100 % slider (values 0 to 1, or [code]min[/code] to [code]max[/code]).
	TOGGLE, ## on / off.
	CHOICE, ## one out of a list (the [code]choices[/code] option).
}

## project setting with the settings file path.
const PATH_SETTING := "omni_button/menus/settings_path"
## settings file to use when the project setting is empty.
const DEFAULT_PATH := "user://settings.cfg"

static var _defs: Dictionary = {}
static var _values: Dictionary = {}
static var _order := 0
static var _loaded := false
static var _watchers: Array[Callable] = []
## everything read from the settings file, so settings defined after loading still get their saved value.
static var _file_values: Dictionary = {}

static func _static_init() -> void:
	_define_builtins()

#region Defining

## adds a setting (or updates its definition, a value that's already set or loaded stays). if you
## define a setting after the settings file loaded (normal for your game's own settings) it picks up
## its saved value and applies it.
## [param options] (all optional):[br]
## - [code]page[/code]: which options screen tab, like [code]"Audio"[/code]. empty keeps it off the options screen.[br]
## - [code]label[/code]: the row text. defaults to something made from the key.[br]
## - [code]kind[/code]: a [enum Kind]. defaults to TOGGLE for bools, CHOICE if you gave [code]choices[/code], otherwise SLIDER.[br]
## - [code]choices[/code]: for CHOICE, an Array of [code][label, value][/code] pairs.[br]
## - [code]min[/code], [code]max[/code], [code]step[/code]: for SLIDER (defaults 0, 1, 0.05, shown as a percent).[br]
## - [code]apply[/code]: a [Callable] that gets the value whenever it's set or loaded.[br]
## - [code]hidden[/code]: [code]true[/code] keeps it off the options screen (like on a platform that can't use it).
static func define(key: String, default_value: Variant, options: Dictionary = {}) -> void:
	var def := options.duplicate()
	def["key"] = key
	def["default"] = default_value
	if not def.has("kind"):
		if typeof(default_value) == TYPE_BOOL:
			def["kind"] = Kind.TOGGLE
		elif def.has("choices"):
			def["kind"] = Kind.CHOICE
		else:
			def["kind"] = Kind.SLIDER
	if not def.has("label"):
		def["label"] = key.get_slice("/", key.get_slice_count("/") - 1).capitalize()
	def["order"] = _defs[key]["order"] if _defs.has(key) else _next_order()
	_defs[key] = def
	if not _values.has(key):
		_values[key] = _file_values.get(key, default_value)
		if _loaded:
			_apply(key)

## true if [param key] has been defined.
static func has_setting(key: String) -> bool:
	return _defs.has(key)

## a setting's definition: the [param options] you gave [method define], plus [code]key[/code],
## [code]default[/code], [code]kind[/code] and [code]label[/code].
static func get_definition(key: String) -> Dictionary:
	return _defs.get(key, {})

## the definitions on [param page] of the options screen, in the order they were defined.
static func get_definitions(page: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for def: Dictionary in _defs.values():
		if def.get("page", "") == page and not def.get("hidden", false):
			out.append(def)
	out.sort_custom(func(a, b): return a["order"] < b["order"])
	return out

## the options screen pages, in the order their first setting was defined.
static func get_pages() -> PackedStringArray:
	var firsts := {}
	for def: Dictionary in _defs.values():
		var page: String = def.get("page", "")
		if page == "" or def.get("hidden", false):
			continue
		if not firsts.has(page) or def["order"] < firsts[page]:
			firsts[page] = def["order"]
	var pages := firsts.keys()
	pages.sort_custom(func(a, b): return firsts[a] < firsts[b])
	return PackedStringArray(pages)

#endregion

#region Values

## the current value of [param key], or [param fallback] if it isn't defined.
static func get_value(key: String, fallback: Variant = null) -> Variant:
	return _values.get(key, fallback)

## changes a setting and applies it. call [method save] to keep it (the options screen saves when it closes).
static func set_value(key: String, value: Variant) -> void:
	if not _defs.has(key):
		push_warning("OmniSettings: '%s' isn't defined; call OmniSettings.define() first." % key)
		return
	_values[key] = value
	_apply(key)
	for w in _watchers.duplicate():
		if w.is_valid():
			w.call(key, value)
		else:
			_watchers.erase(w)

## calls [param callback] with [code](key, value)[/code] whenever a setting changes.
static func watch(callback: Callable) -> void:
	if not _watchers.has(callback):
		_watchers.append(callback)

## stops calling [param callback].
static func unwatch(callback: Callable) -> void:
	_watchers.erase(callback)

## puts settings back to their defaults (only the ones on [param page] if you give one) and applies them.
static func reset_to_defaults(page: String = "") -> void:
	for def: Dictionary in _defs.values():
		if page == "" or def.get("page", "") == page:
			set_value(def["key"], def["default"])

#endregion

#region Saving and loading

## the settings file path ([b]Project Settings > omni_button/menus/settings_path[/b]).
static func get_path() -> String:
	var path := str(ProjectSettings.get_setting(PATH_SETTING, ""))
	return path if path != "" else DEFAULT_PATH

## loads the settings file (anything missing keeps its default) and applies every setting.
static func load_settings(path: String = "") -> void:
	var file := ConfigFile.new()
	var err := file.load(path if path != "" else get_path())
	if err == OK:
		_file_values.clear()
		for section in file.get_sections():
			for name in file.get_section_keys(section):
				_file_values[section + "/" + name] = file.get_value(section, name)
		for key: String in _defs:
			if _file_values.has(key):
				_values[key] = _file_values[key]
	elif err != ERR_FILE_NOT_FOUND:
		push_warning("OmniSettings: couldn't read '%s' (error %d); using defaults." % [path if path != "" else get_path(), err])
	_loaded = true
	apply_all()

## writes every setting to the settings file.
static func save(path: String = "") -> void:
	var file := ConfigFile.new()
	# keep saved settings that nothing's defined yet this run so they don't get lost.
	var all := _file_values.duplicate()
	all.merge(_values, true)
	_file_values = all
	for key: String in all:
		var section := key.get_slice("/", 0)
		file.set_value(section, key.trim_prefix(section + "/"), all[key])
	var target := path if path != "" else get_path()
	var err := file.save(target)
	if err != OK:
		push_warning("OmniSettings: couldn't save '%s' (error %d)." % [target, err])

## loads and applies the settings the first time it's called, does nothing after that.
static func ensure_loaded() -> void:
	if not _loaded:
		load_settings()

## applies every setting to the game (volumes, window, text speed, your own apply functions).
static func apply_all() -> void:
	for key: String in _defs:
		_apply(key)

#endregion

#region Built-in settings

static func _define_builtins() -> void:
	define("audio/master", 1.0, {"page": "Audio", "label": "Master volume", "apply": _apply_bus.bind("Master")})
	define("audio/music", 0.8, {"page": "Audio", "label": "Music", "apply": _apply_bus.bind("Music")})
	define("audio/sfx", 0.8, {"page": "Audio", "label": "Sound effects", "apply": _apply_bus.bind("SFX")})
	var desktop := not (OS.has_feature("web") or OS.has_feature("mobile"))
	define("display/window_mode", "windowed", {
		"page": "Display", "label": "Window mode", "hidden": not desktop,
		"choices": [["Windowed", "windowed"], ["Fullscreen", "fullscreen"]],
		"apply": _apply_window_mode,
	})
	define("display/vsync", true, {"page": "Display", "label": "VSync", "hidden": not desktop, "apply": _apply_vsync})
	define("gameplay/text_speed", 1.0, {
		"page": "Gameplay", "label": "Text speed",
		"choices": [["Slow", 0.5], ["Normal", 1.0], ["Fast", 2.0], ["Instant", 0.0]],
		"apply": func(v: float): OmniTextWindow.text_speed_scale = v,
	})

static func _apply_bus(value: float, bus_name: String) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index < 0:
		return # the project doesn't have a bus with this name, the setting still saves though.
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(value, 0.0001)))
	AudioServer.set_bus_mute(index, value <= 0.001)

static func _apply_window_mode(value: String) -> void:
	if not _can_change_window():
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if value == "fullscreen" else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)

static func _apply_vsync(on: bool) -> void:
	if not _can_change_window():
		return
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if on else DisplayServer.VSYNC_DISABLED)

## there's no window to change when running headless, and the editor's embedded game view handles its own.
static func _can_change_window() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return not Engine.is_embedded_in_editor()

#endregion

static func _apply(key: String) -> void:
	var def: Dictionary = _defs.get(key, {})
	var apply = def.get("apply")
	if apply is Callable and (apply as Callable).is_valid():
		(apply as Callable).call(_values[key])

static func _next_order() -> int:
	_order += 1
	return _order
