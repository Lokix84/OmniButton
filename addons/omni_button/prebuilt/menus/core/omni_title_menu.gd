@tool
class_name OmniTitleMenu
extends OmniMenu
## The title screen: the game's title with Start, Continue, Options and Quit.
##
## Drop [code]omni_title_menu.tscn[/code] into your title scene. It opens on its own, loads and applies
## the player's settings, and covers the screen. Connect [signal start_pressed] (and
## [signal continue_pressed] if you have saves) to start the game; Options opens the options screen and
## Quit quits, with no code. Rename, hide or add items in the scene ([OmniMenu]).

## Start was pressed.
signal start_pressed
## Continue was pressed.
signal continue_pressed

## Show Continue (set it when the player has a save).
@export var can_continue := false:
	set(value):
		can_continue = value
		if is_node_ready():
			set_item_visible(&"continue", value)
## Show Quit. Off by default on the web and phones, where games don't quit.
@export var show_quit := true:
	set(value):
		show_quit = value
		if is_node_ready():
			set_item_visible(&"quit", value and not _quit_unsupported())
## Close the title screen when Start or Continue is pressed. Turn off if you change scenes yourself.
@export var close_on_start := true
## The options screen opened by Options. Empty: one is made from
## [b]Project Settings > omni_button/menus/options_scene[/b] the first time.
@export var options_menu: OmniOptionsMenu

func _ready() -> void:
	super()
	set_item_visible(&"continue", can_continue)
	set_item_visible(&"quit", show_quit and not _quit_unsupported())
	if not Engine.is_editor_hint():
		OmniSettings.ensure_loaded()

func _handle_item(item: StringName) -> void:
	match item:
		&"start":
			start_pressed.emit()
			if close_on_start:
				close()
		&"continue":
			continue_pressed.emit()
			if close_on_start:
				close()
		&"options":
			options_menu = _open_child_menu(options_menu, OmniMenusAutoload.scene_path("options_scene")) as OmniOptionsMenu
		&"quit":
			get_tree().quit()

static func _quit_unsupported() -> bool:
	return OS.has_feature("web") or OS.has_feature("mobile")
