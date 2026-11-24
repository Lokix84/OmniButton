@tool
class_name OmniPauseMenu
extends OmniMenu
## the pause menu: Resume, Options and Quit to title, opened with esc or start on a gamepad.
##
## drop [code]omni_pause_menu.tscn[/code] into your level (or player) scene. during play the pause
## action opens it and pauses the game, and pressing it again, cancel or Resume closes it and
## unpauses. it only opens if nothing else is open on screen (a dialog, another menu) and the game
## isn't already paused. Quit to title asks first, then changes to [member title_scene] or sends
## [signal quit_to_title].

## the menu closed and the game's running again.
signal resumed
## Quit to title got confirmed. goes out after the menu closed and the game unpaused.
signal quit_to_title
## Quit game got confirmed.
signal quit_game

## lets [member pause_action] / [member pause_button] open the menu during play.
@export var open_on_pause := true
## input map action that opens and closes the menu (esc by default).
@export var pause_action: StringName = &"ui_cancel"
## controller button that opens and closes the menu.
@export var pause_button: JoyButton = JOY_BUTTON_START
## scene to change to once Quit to title is confirmed. empty means only [signal quit_to_title] goes out.
@export_file("*.tscn", "*.scn") var title_scene: String = ""
## asks before quitting.
@export var confirm_quit := true
## the question it asks before Quit to title.
@export_multiline var quit_question := "Quit to the title screen?\nUnsaved progress will be lost."
## shows a Quit game item too (off by default, and hidden on the web and phones).
@export var show_quit_game := false:
	set(value):
		show_quit_game = value
		if is_node_ready():
			set_item_visible(&"quit_game", value and not OmniTitleMenu._quit_unsupported())
## the options screen Options opens. empty makes one from
## [b]Project Settings > omni_button/menus/options_scene[/b] the first time.
@export var options_menu: OmniOptionsMenu

var _popup: OmniPopup

func _ready() -> void:
	super()
	set_item_visible(&"quit_game", show_quit_game and not OmniTitleMenu._quit_unsupported())
	if not Engine.is_editor_hint():
		OmniSettings.ensure_loaded()

## opens the menu and pauses the game (same as hitting the pause action).
func pause() -> void:
	open()

## closes the menu and unpauses the game.
func resume() -> void:
	if is_open():
		await close()
		resumed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if Engine.is_editor_hint() or not _is_pause_input(event):
		super(event)
		return
	if is_open():
		if is_top():
			get_viewport().set_input_as_handled()
			resume()
		return
	if open_on_pause and OmniOverlay.get_top() == null and not get_tree().paused:
		get_viewport().set_input_as_handled()
		pause()

func _is_pause_input(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.pressed and not event.is_echo() and event.button_index == pause_button:
		return true
	return pause_action != &"" and InputMap.has_action(pause_action) and event.is_action_pressed(pause_action)

func cancel() -> void:
	if is_open():
		canceled.emit()
		resume()

func _handle_item(item: StringName) -> void:
	match item:
		&"resume":
			resume()
		&"options":
			options_menu = _open_child_menu(options_menu, OmniMenusAutoload.scene_path("options_scene")) as OmniOptionsMenu
		&"quit_to_title":
			if confirm_quit and not await _ask(quit_question):
				return
			await close()
			quit_to_title.emit()
			if title_scene != "":
				get_tree().change_scene_to_file(title_scene)
		&"quit_game":
			if confirm_quit and not await _ask("Quit the game?"):
				return
			quit_game.emit()
			get_tree().quit()

## asks a yes / no question in a popup on top of the menu.
func _ask(question: String) -> bool:
	if _popup == null or not is_instance_valid(_popup):
		var scene := load(OmniDialogAutoload.scene_path("popup_scene")) as PackedScene
		_popup = scene.instantiate()
		_popup.layer = layer + 2
		add_child(_popup)
	return await _popup.confirm(question, "", "Quit", "Cancel")
