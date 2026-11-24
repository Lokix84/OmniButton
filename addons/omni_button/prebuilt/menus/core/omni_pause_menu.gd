@tool
class_name OmniPauseMenu
extends OmniMenu
## The pause menu: Resume, Options and Quit to title, opened by Esc or the gamepad Start button.
##
## Drop [code]omni_pause_menu.tscn[/code] into your level (or player) scene. During play, the pause
## action opens it and pauses the game; pressing it again, cancel or Resume closes it and unpauses.
## It only opens while nothing else is open on screen (a dialog, another menu) and the game isn't
## already paused. Quit to title asks first, then changes to [member title_scene] or emits
## [signal quit_to_title].

## The menu closed and the game resumed.
signal resumed
## Quit to title was confirmed. Emitted after the menu closed and the game unpaused.
signal quit_to_title
## Quit game was confirmed.
signal quit_game

## Open the menu with [member pause_action] / [member pause_button] during play.
@export var open_on_pause := true
## InputMap action that opens and closes the menu (Esc by default).
@export var pause_action: StringName = &"ui_cancel"
## Controller button that opens and closes the menu.
@export var pause_button: JoyButton = JOY_BUTTON_START
## Scene to change to after Quit to title is confirmed. Empty: only [signal quit_to_title] is emitted.
@export_file("*.tscn", "*.scn") var title_scene: String = ""
## Ask before quitting.
@export var confirm_quit := true
## Question asked before Quit to title.
@export_multiline var quit_question := "Quit to the title screen?\nUnsaved progress will be lost."
## Show a Quit game item too (off by default; hidden on the web and phones).
@export var show_quit_game := false:
	set(value):
		show_quit_game = value
		if is_node_ready():
			set_item_visible(&"quit_game", value and not OmniTitleMenu._quit_unsupported())
## The options screen opened by Options. Empty: one is made from
## [b]Project Settings > omni_button/menus/options_scene[/b] the first time.
@export var options_menu: OmniOptionsMenu

var _popup: OmniPopup

func _ready() -> void:
	super()
	set_item_visible(&"quit_game", show_quit_game and not OmniTitleMenu._quit_unsupported())
	if not Engine.is_editor_hint():
		OmniSettings.ensure_loaded()

## Opens the menu and pauses the game (same as pressing the pause action).
func pause() -> void:
	open()

## Closes the menu and resumes the game.
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

## Asks a yes / no question in a popup above the menu.
func _ask(question: String) -> bool:
	if _popup == null or not is_instance_valid(_popup):
		var scene := load(OmniDialogAutoload.scene_path("popup_scene")) as PackedScene
		_popup = scene.instantiate()
		_popup.layer = layer + 2
		add_child(_popup)
	return await _popup.confirm(question, "", "Quit", "Cancel")
