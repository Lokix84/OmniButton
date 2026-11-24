@tool
extends OmniOverlay
class_name OmniTextWindow
## the shared base for [OmniDialogueBox] and [OmniNarration]: typing the text, answers and moving on.
##
## a line types out in [member body] (an [code]OmniButton[/code]). pressing the body or [member advance_action] while it's typing shows the rest right away, pressing again moves on ([method advance] does the same thing from code). if a line has answers they show up in [member options_box] once the text is all showing, and the line ends when one gets picked.
## you can await each line, it returns the answer picked or [code]-1[/code]. lines asked for while one is showing wait their turn. the window stays open between lines, [method close_if_idle] closes it at the end of the frame unless another line started, so lines back to back don't flicker.
## the text can use bbcode and the typewriter's timing tags: [code][pause=0.5][/code], [code][speed=10][/code] and [code][/speed][/code].

## a line started typing.
signal line_started(text: String)
## all of the current line's text is showing. answers, if there are any, show up now.
signal line_revealed
## the current line ended. [param result] is the answer picked, or [code]-1[/code].
signal line_finished(result: int)
## the player wants to skip: they held [member skip_button] or pressed [member skip_action]. an
## [OmniDialogRunner] playing a skippable entry on this window listens for this and fast forwards.
signal skip_requested
signal _line_done(result: int)
signal _released

## what the window's doing: [code]IDLE[/code] (no line), [code]REVEALING[/code] (typing), [code]WAITING[/code] (all showing, waiting to move on) or [code]CHOOSING[/code] (answers showing).
enum State {IDLE, REVEALING, WAITING, CHOOSING}

## the player's text speed for every dialog window. [code]1[/code] is normal, [code]2[/code] types
## twice as fast, [code]0.5[/code] half as fast, and [code]0[/code] shows each line right away. it
## multiplies each window's [member characters_per_second] (and the popup's message speed). usually
## you set it from the game's options menu: [code]OmniDialog.text_speed_scale = 2.0[/code]. speeds
## set inside the text with [code][speed=...][/code] don't get scaled.
static var text_speed_scale: float = 1.0

@export_group("Text")
## typewriter speed. a line can override it.
@export_range(1.0, 500.0, 1.0, "suffix:chars/s") var characters_per_second: float = 40.0
## moves on by itself this many seconds after a line is all showing. 0 waits for input.
@export_range(0.0, 30.0, 0.1, "suffix:s") var auto_advance_delay: float = 0.0
## input map action that skips the typing / moves on (also works while %Body has focus).
@export var advance_action: StringName = &"ui_accept"
@export_group("Typing Sound")
## plays while the text types. empty is silent.
@export var typing_sound: AudioStream
## plays the sound every N characters.
@export_range(1, 20) var typing_sound_every: int = 2
## random pitch change per blip (0.05 is ±5%).
@export_range(0.0, 0.5, 0.01) var typing_pitch_variation: float = 0.05
## audio bus the typing sound plays on.
@export var typing_sound_bus: StringName = &"Master"
@export_group("Skipping")
## shows [member skip_button] while a skippable story entry is playing on this window.
@export var show_skip_button: bool = true
## how many seconds you have to hold the skip button.
@export_range(0.1, 5.0, 0.05, "suffix:s") var skip_hold_time: float = 0.8
## input map action that skips (just pressed once). empty turns it off.
@export var skip_action: StringName = &""
@export_group("Options")
## the scene each option gets made from. it has to be an OmniButton (or at least have a `pressed` signal and `text`).
@export var option_button_scene: PackedScene = preload("res://addons/omni_button/prebuilt/dialog/parts/omni_option_button.tscn")

## the [code]OmniButton[/code] the text types into.
@onready var body: Control = %Body
## the [Container] answers get added to.
@onready var options_box: Container = get_node_or_null("%Options")
## the marker that blinks once a line is all showing.
@onready var continue_indicator: Control = get_node_or_null("%ContinueIndicator")
## hold to skip button (an [code]OmniButton[/code] using its hold). only shows while a skippable
## entry is playing, see [method set_skip_available].
@onready var skip_button: Control = get_node_or_null("%SkipButton")

## what the window's doing right now. see [enum State].
var state: State = State.IDLE
var _busy := false
var _line_id := 0
var _options := PackedStringArray()
var _option_nodes: Array[Control] = []
var _blink: Tween
var _sound_player: AudioStreamPlayer
var _skip_available := false

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	if continue_indicator != null:
		continue_indicator.visible = false
	if options_box != null:
		options_box.visible = false
	body.connect("pressed", _on_body_pressed)
	body.connect("typewriter_completed", _on_revealed)
	body.connect("typewriter_char_revealed", _on_char_revealed)
	if skip_button != null:
		skip_button.focus_mode = Control.FOCUS_NONE
		skip_button.set("enable_hold_actions", true)
		skip_button.set("hold_duration", skip_hold_time)
		skip_button.connect("hold", _on_skip_held)
		skip_button.visible = false

#region Lines

## shows one line and waits until it's done. `prepare` runs once it's this line's turn (the
## subclass sets the speaker, background and so on). returns the option picked, or -1.
func _show_text(text: String, options: PackedStringArray, speed: float, prepare: Callable = Callable()) -> int:
	while _busy:
		await _released
	_busy = true
	_line_id += 1
	_options = options
	_clear_options()
	_set_indicator(false)
	if prepare.is_valid():
		prepare.call()
	_layout_for_line(not options.is_empty())
	if not is_open():
		open()
	else:
		refresh_focus()
	state = State.REVEALING
	line_started.emit(text)
	_update_skip_button()
	if text.strip_edges() == "":
		body.call("stop_typewriter")
		body.set("text", "")
		_on_revealed()
	else:
		var cps := (speed if speed > 0.0 else characters_per_second) * maxf(text_speed_scale, 0.0)
		body.call("start_typewriter", text, maxf(cps, 1.0), false, true)
		if text_speed_scale <= 0.0:
			body.call("skip_typewriter")   # instant text
	var result: int = await _line_done
	_busy = false
	_released.emit()
	return result

## shows the rest of the current line right away, or moves on if it's already all showing.
func advance() -> void:
	match state:
		State.REVEALING:
			body.call("skip_typewriter")
		State.WAITING:
			_finish(-1)

## ends the line showing now like it got read (a line with no answers returns [code]-1[/code]).
## a line with answers never ends this way. if it's still typing, the rest of it and its answers
## show instead. [method OmniDialogRunner.skip] uses this.
func end_line() -> void:
	if not _options.is_empty():
		if state == State.REVEALING:
			body.call("skip_typewriter")
		return
	if state == State.REVEALING or state == State.WAITING:
		body.call("stop_typewriter")
		_finish(-1)

## shows or hides [member skip_button]. an [OmniDialogRunner] turns it on while it plays a
## skippable entry on this window.
func set_skip_available(on: bool) -> void:
	_skip_available = on
	_update_skip_button()

func _update_skip_button() -> void:
	if skip_button != null:
		# hidden on lines with answers, skipping never skips a question.
		skip_button.visible = show_skip_button and _skip_available and state != State.CHOOSING and _options.is_empty()

func _on_skip_held() -> void:
	if _skip_available:
		skip_requested.emit()

## closes the window at the end of this frame, unless a new line started by then.
func close_if_idle() -> void:
	_close_if_idle.call_deferred()

func _close_if_idle() -> void:
	if not _busy and is_open():
		close()

## returns [code]true[/code] while a line is showing or waiting to show.
func is_busy() -> bool:
	return _busy

#endregion

#region Internals

func _on_revealed() -> void:
	if state != State.REVEALING:
		return
	line_revealed.emit()
	if not _options.is_empty() and options_box != null:
		state = State.CHOOSING
		_update_skip_button()
		_build_options()
		refresh_focus()
		return
	state = State.WAITING
	_set_indicator(true)
	if auto_advance_delay > 0.0:
		var id := _line_id
		await get_tree().create_timer(auto_advance_delay, true, false, true).timeout
		if id == _line_id and state == State.WAITING:
			_finish(-1)

## runs before each line starts typing so a window can set its layout for the whole line
## (the dialogue box saves room for its options column here so nothing moves when they show up).
func _layout_for_line(_has_options: bool) -> void:
	pass

func _finish(result: int) -> void:
	if state == State.IDLE:
		return
	state = State.IDLE
	_update_skip_button()
	_set_indicator(false)
	_clear_options()
	line_finished.emit(result)
	_line_done.emit(result)

func _on_body_pressed() -> void:
	advance()

func _on_option_pressed(index: int) -> void:
	if state == State.CHOOSING:
		_finish(index)

func _unhandled_input(event: InputEvent) -> void:
	if is_top() and _skip_available and skip_action != &"" and InputMap.has_action(skip_action) and event.is_action_pressed(skip_action):
		get_viewport().set_input_as_handled()
		skip_requested.emit()
		return
	if is_top() and advance_action != &"" and InputMap.has_action(advance_action) \
			and event.is_action_pressed(advance_action) and (state == State.REVEALING or state == State.WAITING):
		get_viewport().set_input_as_handled()
		advance()
		return
	super(event)

## closing while a line is showing (close() from code, or cancel) ends the line with -1.
func _on_close() -> void:
	if state != State.IDLE:
		body.call("stop_typewriter")
		_finish(-1)

func _on_dialog_theme(t: OmniDialogTheme) -> void:
	t.style_text(body)
	if skip_button != null:
		t.style_option(skip_button)
	for b in _option_nodes:
		if is_instance_valid(b):
			t.style_option(b)
	if not _option_nodes.is_empty():
		_fit_options()

func _get_default_focus() -> Control:
	if state == State.CHOOSING and not _option_nodes.is_empty():
		return _option_nodes[0]
	return body

func _get_focus_chain() -> Array[Control]:
	if state == State.CHOOSING and not _option_nodes.is_empty():
		return _option_nodes.duplicate()
	return [body] as Array[Control]

func _build_options() -> void:
	for i in _options.size():
		var b: Control = option_button_scene.instantiate()
		b.set("text", _options[i])
		var t := get_dialog_theme()
		if t != null:
			t.style_option(b)
		options_box.add_child(b)
		b.connect("pressed", _on_option_pressed.bind(i))
		_option_nodes.append(b)
	options_box.visible = true
	_fit_options()

## one font size for all of a line's options. they stay hidden until it's set so you don't see the sizes jump.
func _fit_options() -> void:
	var t := get_dialog_theme()
	if t == null or _option_nodes.is_empty():
		return
	var nodes := _option_nodes.duplicate()
	options_box.modulate.a = 0.0
	await t.fit_option_group(nodes)
	if is_instance_valid(options_box):
		options_box.modulate.a = 1.0

func _clear_options() -> void:
	for n in _option_nodes:
		if is_instance_valid(n):
			n.get_parent().remove_child(n)
			n.queue_free()
	_option_nodes.clear()
	if options_box != null:
		options_box.visible = false

func _set_indicator(on: bool) -> void:
	if continue_indicator == null:
		return
	if _blink != null and _blink.is_valid():
		_blink.kill()
	continue_indicator.visible = on
	continue_indicator.modulate.a = 1.0
	if on:
		_blink = create_tween().set_loops()
		_blink.tween_property(continue_indicator, "modulate:a", 0.25, 0.5)
		_blink.tween_property(continue_indicator, "modulate:a", 1.0, 0.5)

func _on_char_revealed(index: int, character: String) -> void:
	if typing_sound == null or index % typing_sound_every != 0 or character.strip_edges() == "":
		return
	if _sound_player == null:
		_sound_player = AudioStreamPlayer.new()
		add_child(_sound_player)
	_sound_player.stream = typing_sound
	_sound_player.bus = typing_sound_bus
	_sound_player.pitch_scale = 1.0 + randf_range(-typing_pitch_variation, typing_pitch_variation)
	_sound_player.play()

## returns [param value] as a [Texture2D]. a texture comes back as is, a resource path gets loaded, anything else gives [code]null[/code].
static func to_texture(value: Variant) -> Texture2D:
	if value is Texture2D:
		return value
	if value is String and value != "" and ResourceLoader.exists(value):
		return load(value) as Texture2D
	return null

#endregion
