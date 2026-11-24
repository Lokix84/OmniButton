@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/popup.svg")
extends OmniOverlay
class_name OmniPopup
## A centered window with a title, a message and buttons: alert, confirm and choice in one scene.
##
## Two buttons sit in a row; more stack vertically (see [member max_buttons_in_row]). All buttons share one font size, and long button text wraps. Every call can be awaited and returns once the popup has closed. One popup shows one question at a time: a call made while it is busy waits for its turn.
## [codeblock]
## await $Popup.alert("Saved.")
## if await $Popup.confirm("Quit to the title screen?"):
##     get_tree().quit()
## var pick := await $Popup.choose("Pick a class", ["Warrior", "Mage", "Rogue"])
## [/codeblock]
## Dropped into a scene, it can also be set up entirely in the Inspector ([member title], [member message], [member buttons]) and shown with [code]await $Popup.show_configured()[/code].

## A button was picked (not emitted on cancel).
signal button_pressed(index: int, text: String)
signal _answered(index: int)
signal _released

@export_group("Content")
## Title above the message. Empty hides it.
@export var title: String = "":
	set(value):
		title = value
		_apply_texts()
## The message. BBCode is allowed. Long messages wrap and then shrink to fit.
@export_multiline var message: String = "":
	set(value):
		message = value
		_apply_texts()
## Button labels, left to right (or top to bottom when stacked).
@export var buttons: PackedStringArray = ["OK"]:
	set(value):
		buttons = value
		_preview_buttons()
## Index of the button focused when the popup opens.
@export var default_button: int = 0
@export_group("Message Typing")
## Type the message out with the typewriter instead of showing it at once. Clicking the message shows the rest.
@export var type_message: bool = false
## Typing speed when [member type_message] is on.
@export_range(1.0, 500.0, 1.0, "suffix:chars/s") var message_speed: float = 60.0
@export_group("Cancel")
## The cancel action and backdrop clicks answer the popup with [member cancel_index].
@export var allow_cancel: bool = true
## Index returned when the popup is canceled. [code]-1[/code] means none of the buttons.
@export var cancel_index: int = -1
@export_group("Buttons")
## With more buttons than this, they stack vertically instead of sitting in a row.
@export_range(1, 10) var max_buttons_in_row: int = 2:
	set(value):
		max_buttons_in_row = value
		_preview_buttons()
## Scene each button is made from. Must be an [code]Omni_Button[/code] (or have a [code]pressed[/code] signal and a [code]Text[/code] property).
@export var option_button_scene: PackedScene = preload("res://addons/omni_button/prebuilt/dialog/parts/omni_option_button.tscn")

## [Label] for the title (type variation [code]OmniDialogTitle[/code]).
@onready var title_label: Label = %Title
## The message, an [code]Omni_Button[/code]: long text shrinks to fit its fixed height.
@onready var message_label: Control = %Message
## Holds the buttons when there are [member max_buttons_in_row] or fewer.
@onready var button_row: HBoxContainer = %ButtonRow
## Holds the buttons when there are more than [member max_buttons_in_row].
@onready var button_column: VBoxContainer = %ButtonColumn

var _busy := false
var _waiting := false
var _button_nodes: Array[Control] = []

func _ready() -> void:
	super()
	_apply_texts()
	if Engine.is_editor_hint():
		_preview_buttons()

#region Public API

## Shows [param text] with [param options] as buttons and returns the index picked, or [param cancel] when canceled. [b]Note:[/b] this is the general popup question; [method OmniDialogAutoload.ask] asks in the dialogue box.
func ask(text: String, options: PackedStringArray, title_text: String = "", default_index: int = 0, cancel: int = -1) -> int:
	while _busy:
		await _released
	_busy = true
	title = title_text
	message = text
	buttons = options
	default_button = default_index
	cancel_index = cancel
	var index := await _show_and_wait()
	_busy = false
	_released.emit()
	return index

## Shows [param text] with a single acknowledge button.
func alert(text: String, title_text: String = "", ok: String = "OK") -> void:
	await ask(text, PackedStringArray([ok]), title_text, 0, 0)

## Asks a Yes / No question. Returns [code]true[/code] for Yes. Canceling counts as No.
func confirm(text: String, title_text: String = "", yes: String = "Yes", no: String = "No") -> bool:
	var index := await ask(text, PackedStringArray([yes, no]), title_text, 0, 1)
	return index == 0

## Asks a question with several [param options]. Returns the index picked, or [code]-1[/code] when canceled.
func choose(text: String, options: PackedStringArray, title_text: String = "") -> int:
	return await ask(text, options, title_text, 0, -1)

## Shows the popup with the [member title], [member message] and [member buttons] set in the Inspector. Returns the index picked.
func show_configured() -> int:
	while _busy:
		await _released
	_busy = true
	var index := await _show_and_wait()
	_busy = false
	_released.emit()
	return index

## Returns [code]true[/code] while a question is showing or waiting to show.
func is_busy() -> bool:
	return _busy

#endregion

func _show_and_wait() -> int:
	_build_buttons()
	_waiting = true
	open()
	if type_message and message != "" and OmniTextWindow.text_speed_scale > 0.0:
		message_label.call("start_typewriter", message, message_speed * OmniTextWindow.text_speed_scale, false, true)
	var index: int = await _answered
	await close()
	return index

## Answers the popup with [member cancel_index] and closes it, if [member allow_cancel] is on.
func cancel() -> void:
	if not is_open() or not allow_cancel:
		return
	canceled.emit()
	_answer(cancel_index)

func _answer(index: int) -> void:
	if not _waiting:
		return
	_waiting = false
	_answered.emit(index)

func _on_button_pressed(index: int) -> void:
	if not _waiting:
		return
	button_pressed.emit(index, buttons[index] if index < buttons.size() else "")
	_answer(index)

## Closing from outside (close() called by code) still answers, so nothing waits forever.
func _on_close() -> void:
	_answer(cancel_index)

func _on_dialog_theme(t: OmniDialogTheme) -> void:
	t.style_text(message_label)
	for b in _button_nodes:
		if is_instance_valid(b):
			t.style_option(b)
	if not _button_nodes.is_empty():
		_fit_buttons()

func _get_default_focus() -> Control:
	if default_button >= 0 and default_button < _button_nodes.size():
		return _button_nodes[default_button]
	return super()

#region Building

func _apply_texts() -> void:
	if not is_node_ready():
		return
	title_label.text = title
	title_label.visible = title != ""
	message_label.call("stop_typewriter")
	message_label.set("Text", message)
	message_label.visible = message != ""

func _build_buttons() -> void:
	for n in _button_nodes:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_button_nodes.clear()
	var stacked := buttons.size() > max_buttons_in_row
	button_row.visible = not stacked
	button_column.visible = stacked
	var parent: Container = button_column if stacked else button_row
	for i in buttons.size():
		var b: Control = option_button_scene.instantiate()
		b.set("Text", buttons[i])
		var t := get_dialog_theme()
		if t != null:
			t.style_option(b)
		parent.add_child(b)
		if not Engine.is_editor_hint() and b.has_signal("pressed"):
			b.connect("pressed", _on_button_pressed.bind(i))
		_button_nodes.append(b)
	_fit_buttons()

## One font size for all the buttons, hidden until it is set so sizes don't visibly jump.
func _fit_buttons() -> void:
	var t := get_dialog_theme()
	if t == null or _button_nodes.is_empty():
		return
	var nodes := _button_nodes.duplicate()
	for n in nodes:
		n.modulate.a = 0.0
	await t.fit_option_group(nodes)
	for n in nodes:
		if is_instance_valid(n):
			n.modulate.a = 1.0

## In the editor, show the buttons from the Inspector so the layout can be judged. These nodes have
## no owner, so they are never saved into the scene.
func _preview_buttons() -> void:
	if Engine.is_editor_hint() and is_node_ready():
		_build_buttons()

#endregion
