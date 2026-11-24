class_name OmniMenusAutoload
extends Node
## The optional [code]OmniMenus[/code] autoload: loads and applies the player's settings when the game
## starts, and opens the options screen from anywhere.
##
## The menus work without it (each loads the settings when it first needs them); the autoload makes
## sure volumes, window mode and text speed are applied from the very first frame, even in a game
## that opens no menu before play. Turn it off with
## [b]Project Settings > omni_button/menus/enable_autoload[/b].
## [codeblock]
## OmniMenus.open_options()
## OmniMenus.setting_changed.connect(func(key, value): print(key, " = ", value))
## [/codeblock]

## A setting changed (from the options screen or [method OmniSettings.set_value]).
signal setting_changed(key: String, value: Variant)

## Project Setting prefix for the menu scenes.
const SETTING_PREFIX := "omni_button/menus/"
## The prebuilt scene for each menu, used when its Project Setting is empty.
const DEFAULT_SCENES := {
	"options_scene": "res://addons/omni_button/prebuilt/menus/screens/omni_options_menu.tscn",
}
## Layer of the options screen this autoload opens (above dialog windows and the pause menu).
const OPTIONS_LAYER := 30

var _options: OmniOptionsMenu

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	OmniSettings.ensure_loaded()
	OmniSettings.watch(_on_setting_changed)

func _exit_tree() -> void:
	OmniSettings.unwatch(_on_setting_changed)

## Opens the options screen (created the first time). Returns it; await [signal OmniOverlay.closed] to wait for it.
func open_options() -> OmniOptionsMenu:
	if _options == null or not is_instance_valid(_options):
		var scene := load(scene_path("options_scene")) as PackedScene
		if scene == null:
			push_error("OmniMenus: could not load the options screen '%s'." % scene_path("options_scene"))
			return null
		_options = scene.instantiate()
		_options.layer = OPTIONS_LAYER
		add_child(_options)
	_options.open()
	return _options

## Scene path for a menu ([param key] is a key of [constant DEFAULT_SCENES]), from Project Settings or the prebuilt default.
static func scene_path(key: String) -> String:
	var path := str(ProjectSettings.get_setting(SETTING_PREFIX + key, ""))
	return path if path != "" else str(DEFAULT_SCENES[key])

func _on_setting_changed(key: String, value: Variant) -> void:
	setting_changed.emit(key, value)
