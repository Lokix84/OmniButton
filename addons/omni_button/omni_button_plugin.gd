@tool
extends EditorPlugin
## editor plugin: registers the OmniButton type and its inspector plugin, and resyncs buttons
## when the editor's undo/redo history changes.

const OmniButtonInspector = preload("res://addons/omni_button/core/omni_button_inspector.gd")
const EDITOR_POLL_GROUP := &"_omni_button_editor_poll"
const DIALOG_AUTOLOAD := "OmniDialog"
const DIALOG_AUTOLOAD_PATH := "res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd"
const OmniDialogScript = preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")
const CHECK_DIALOG_MENU := "Check OmniButton dialog files"
## project setting. turn it off for button only projects and the OmniDialog autoload goes away.
const DIALOG_ENABLED_SETTING := "omni_button/dialog/enable_autoload"
const MENUS_AUTOLOAD := "OmniMenus"
const MENUS_AUTOLOAD_PATH := "res://addons/omni_button/prebuilt/menus/core/omni_menus.gd"
const OmniMenusScript = preload("res://addons/omni_button/prebuilt/menus/core/omni_menus.gd")
## project setting. turn it off and the OmniMenus autoload goes away (the menus still work without it).
const MENUS_ENABLED_SETTING := "omni_button/menus/enable_autoload"
## each optional autoload: its name, script, and the project setting that turns it on.
const AUTOLOADS := [
	[DIALOG_AUTOLOAD, DIALOG_AUTOLOAD_PATH, DIALOG_ENABLED_SETTING],
	[MENUS_AUTOLOAD, MENUS_AUTOLOAD_PATH, MENUS_ENABLED_SETTING],
]
var _omni_button_inspector: EditorInspectorPlugin
var _sync_queued := false

## editor syncing runs off events. every inspector edit, undo/redo and signal (dis)connect goes
## through the editor's undo/redo history, so we only recheck buttons when that history changes
## (or you switch scenes) instead of building a property signature for every button five times a
## second. each button still compares its own signature and only refreshes if something changed.

func _enable_plugin() -> void:
	_sync_autoloads()

func _disable_plugin() -> void:
	for a in AUTOLOADS:
		if ProjectSettings.has_setting("autoload/" + a[0]):
			remove_autoload_singleton(a[0])

## adds or removes the OmniDialog and OmniMenus autoloads to match their enable_autoload project
## settings. also runs when the plugin loads, since projects that turned the plugin on before
## these existed never ran _enable_plugin.
func _sync_autoloads() -> void:
	for a in AUTOLOADS:
		var wanted := bool(ProjectSettings.get_setting(a[2], true))
		var present := ProjectSettings.has_setting("autoload/" + a[0])
		if wanted and not present:
			add_autoload_singleton(a[0], a[1])
		elif not wanted and present:
			remove_autoload_singleton(a[0])

## project settings > omni_button/dialog/*: which scene each window uses.
func _register_dialog_settings() -> void:
	if not ProjectSettings.has_setting(DIALOG_ENABLED_SETTING):
		ProjectSettings.set_setting(DIALOG_ENABLED_SETTING, true)
	ProjectSettings.set_initial_value(DIALOG_ENABLED_SETTING, true)
	ProjectSettings.add_property_info({"name": DIALOG_ENABLED_SETTING, "type": TYPE_BOOL})
	ProjectSettings.set_as_basic(DIALOG_ENABLED_SETTING, true)
	for key in OmniDialogScript.DEFAULT_SCENES:
		var setting_name: String = OmniDialogScript.SETTING_PREFIX + key
		var default_path: String = OmniDialogScript.DEFAULT_SCENES[key]
		if not ProjectSettings.has_setting(setting_name) or not ResourceLoader.exists(str(ProjectSettings.get_setting(setting_name))):
			ProjectSettings.set_setting(setting_name, default_path)
		ProjectSettings.set_initial_value(setting_name, default_path)
		ProjectSettings.add_property_info({"name": setting_name, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tscn,*.scn"})
	# the look every dialog window uses unless it sets its own dialog_theme.
	var theme_setting := "omni_button/dialog/theme"
	var theme_default := "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres"
	# a path that doesn't exist anymore (like after moving files) goes back to the default.
	if not ProjectSettings.has_setting(theme_setting) or not ResourceLoader.exists(str(ProjectSettings.get_setting(theme_setting))):
		ProjectSettings.set_setting(theme_setting, theme_default)
	ProjectSettings.set_initial_value(theme_setting, theme_default)
	ProjectSettings.add_property_info({"name": theme_setting, "type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tres,*.res"})
	ProjectSettings.set_as_basic(theme_setting, true)
	# the screen size the windows are laid out for, they scale from that to the game's resolution.
	var ref_setting := OmniOverlay.REFERENCE_SIZE_SETTING
	if not ProjectSettings.has_setting(ref_setting):
		ProjectSettings.set_setting(ref_setting, OmniOverlay.DEFAULT_REFERENCE_SIZE)
	ProjectSettings.set_initial_value(ref_setting, OmniOverlay.DEFAULT_REFERENCE_SIZE)
	ProjectSettings.add_property_info({"name": ref_setting, "type": TYPE_VECTOR2I})
	ProjectSettings.set_as_basic(ref_setting, true)

## project settings > omni_button/menus/*.
func _register_menus_settings() -> void:
	_register_setting(MENUS_ENABLED_SETTING, true, {"type": TYPE_BOOL})
	for key in OmniMenusScript.DEFAULT_SCENES:
		var path: String = OmniMenusScript.DEFAULT_SCENES[key]
		var name: String = OmniMenusScript.SETTING_PREFIX + key
		if ProjectSettings.has_setting(name) and not ResourceLoader.exists(str(ProjectSettings.get_setting(name))):
			ProjectSettings.set_setting(name, path) # moved or deleted, back to the prebuilt scene
		_register_setting(name, path, {"type": TYPE_STRING, "hint": PROPERTY_HINT_FILE, "hint_string": "*.tscn,*.scn"})
	_register_setting(OmniSettings.PATH_SETTING, OmniSettings.DEFAULT_PATH, {"type": TYPE_STRING})

func _register_setting(name: String, default_value: Variant, info: Dictionary) -> void:
	if not ProjectSettings.has_setting(name):
		ProjectSettings.set_setting(name, default_value)
	ProjectSettings.set_initial_value(name, default_value)
	info["name"] = name
	ProjectSettings.add_property_info(info)
	ProjectSettings.set_as_basic(name, true)

func _enter_tree() -> void:
	_register_dialog_settings()
	_register_menus_settings()
	_sync_autoloads()
	if not ProjectSettings.settings_changed.is_connected(_sync_autoloads):
		ProjectSettings.settings_changed.connect(_sync_autoloads)
	add_tool_menu_item(CHECK_DIALOG_MENU, _check_dialog_files)
	add_custom_type("OmniButton", "Control", preload("res://addons/omni_button/omni_button.gd"), preload("res://addons/omni_button/OmniButtonGDV1.png"))
	_omni_button_inspector = OmniButtonInspector.new()
	add_inspector_plugin(_omni_button_inspector)
	var undo_redo := get_undo_redo()
	if undo_redo != null and not undo_redo.version_changed.is_connected(_queue_sync):
		undo_redo.version_changed.connect(_queue_sync)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)

func _on_scene_changed(_root: Node) -> void:
	_queue_sync()

## squash bursts (like dragging a slider makes a bunch of versions) into one pass per frame.
func _queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	call_deferred("_sync_buttons")

func _sync_buttons() -> void:
	_sync_queued = false
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if edited_scene_root == null:
		return
	var scene_tree := edited_scene_root.get_tree()
	if scene_tree == null:
		return
	for node in scene_tree.get_nodes_in_group(EDITOR_POLL_GROUP):
		if is_instance_valid(node) and node.is_inside_tree():
			node.call("_editor_poll")

## project > tools > check OmniButton dialog files: checks every dialog json file in the project and
## prints the report to the output panel.
func _check_dialog_files() -> void:
	OmniDialogFile.clear_cache()
	var results := OmniDialogValidator.check_folder("res://")
	if results.is_empty():
		print("OmniButton: no dialog files found in the project.")
		return
	var total := 0
	for path in results:
		var problems: Array[Dictionary] = []
		problems.assign(results[path])
		total += problems.size()
		print(OmniDialogValidator.format_report(path, problems))
	if total > 0:
		push_warning("OmniButton: %d problem(s) in dialog files; see the Output panel." % total)
	else:
		print("OmniButton: %d dialog file(s) checked, no problems found." % results.size())

func _exit_tree() -> void:
	remove_tool_menu_item(CHECK_DIALOG_MENU)
	if ProjectSettings.settings_changed.is_connected(_sync_autoloads):
		ProjectSettings.settings_changed.disconnect(_sync_autoloads)
	var undo_redo := get_undo_redo()
	if undo_redo != null and undo_redo.version_changed.is_connected(_queue_sync):
		undo_redo.version_changed.disconnect(_queue_sync)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	remove_inspector_plugin(_omni_button_inspector)
	_omni_button_inspector = null
	remove_custom_type("OmniButton")
