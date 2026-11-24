extends Node
class_name OmniDialogAutoload
## the [code]OmniDialog[/code] autoload. shows the dialog windows from any script.
##
## the plugin registers this as the [code]OmniDialog[/code] autoload, but you don't have to use it. every window also works dropped into a scene ([OmniPopup], [OmniToast], [OmniDialogueBox], [OmniNarration]), and an [OmniDialogRunner] can play dialog files without it.
## each window gets made the first time it's needed and then reused. the scene each window uses comes from [b]Project Settings > omni_button/dialog/popup_scene[/b] ([code]toast_scene[/code], [code]dialogue_scene[/code], [code]narration_scene[/code]), and the look comes from [code]omni_button/dialog/theme[/code].
## [codeblock]
## OmniDialog.toast("Game saved")
## if await OmniDialog.confirm("Quit to the title screen?"):
##     get_tree().quit()
## await OmniDialog.say("Guard", "Halt!", "res://portraits/guard.png")
## var pick := await OmniDialog.ask("Guard", "Your business?", ["Trade", "Leave"])
## await OmniDialog.narrate("Three days later...")
## var answers := await OmniDialog.play("res://story/chapter1.json", "gate")
## [/codeblock]

## prefix of the project settings that pick each window's scene.
const SETTING_PREFIX := "omni_button/dialog/"
## the prebuilt scene for each window, used when its project setting is empty.
const DEFAULT_SCENES := {
	"popup_scene": "res://addons/omni_button/prebuilt/dialog/windows/popup/omni_popup.tscn",
	"toast_scene": "res://addons/omni_button/prebuilt/dialog/windows/toast/omni_toast.tscn",
	"dialogue_scene": "res://addons/omni_button/prebuilt/dialog/windows/dialogue_box/omni_dialogue_box.tscn",
	"narration_scene": "res://addons/omni_button/prebuilt/dialog/windows/narration/omni_narration.tscn",
}

## the look for the windows this autoload handles. [code]null[/code] uses the project default ([code]omni_button/dialog/theme[/code]). change it with [method set_dialog_theme].
var dialog_theme: OmniDialogTheme

## the player's text speed for every dialog window, dropped in ones too. [code]1[/code] is normal,
## [code]2[/code] is twice as fast, [code]0[/code] is instant. same as [member OmniTextWindow.text_speed_scale].
## save it with the player's settings, it doesn't get saved for you.
var text_speed_scale: float:
	get: return OmniTextWindow.text_speed_scale
	set(value): OmniTextWindow.text_speed_scale = maxf(value, 0.0)

## the [OmniDialogRunner] that [method play] uses, hooked up to this autoload's windows. its answers are what [method get_answer] and [method set_answers] read and write.
var runner := OmniDialogRunner.new()

## an entry from a dialog file started playing (see [method play]).
signal started(file: String, key: String)
## a dialog line fired an event. handlers you registered with [method register_event] run too.
signal event_triggered(event_name: String, args: Array)
## a question in a dialog file got answered, or a line's [code]set[/code] stored a value.
signal choice_made(id: String, value: Variant)
## skipping started (see [method skip_entry]).
signal skip_started(file: String, key: String)
## skipping stopped, either it hit a question or the entry finished.
signal skip_stopped(file: String, key: String)
## an entry finished. [param entry_answers] has the answers given during it.
signal finished(file: String, key: String, entry_answers: Dictionary)

var _popup: OmniPopup
var _toast: OmniToast
var _dialogue: OmniDialogueBox
var _narration: OmniNarration

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	runner.window_provider = func(kind: String) -> Node:
		match kind:
			"dialogue_box": return get_dialogue()
			"narration": return get_narration()
			"popup": return get_popup()
			"toast": return get_toast()
		return null
	runner.started.connect(started.emit)
	runner.event_triggered.connect(event_triggered.emit)
	runner.choice_made.connect(choice_made.emit)
	runner.finished.connect(finished.emit)
	runner.skip_started.connect(skip_started.emit)
	runner.skip_stopped.connect(skip_stopped.emit)

#region Windows

## shows a short message that goes away on its own after [param duration] seconds (negative uses the toast's [member OmniToast.default_duration]). it doesn't block, only await it if you want to wait until it's gone.
func toast(text: String, duration: float = -1.0) -> void:
	await get_toast().toast(text, duration)

## shows [param text] with one ok button. returns once it's dismissed.
func alert(text: String, title: String = "", ok: String = "OK") -> void:
	await get_popup().alert(text, title, ok)

## asks a yes / no question. returns [code]true[/code] for yes, canceling counts as no.
func confirm(text: String, title: String = "", yes: String = "Yes", no: String = "No") -> bool:
	return await get_popup().confirm(text, title, yes, no)

## asks a question with a few [param options] in a popup. returns the index picked, or [code]-1[/code] if it got canceled.
func choose(text: String, options: PackedStringArray, title: String = "") -> int:
	return await get_popup().choose(text, options, title)

## shows one line in the dialogue box. [param portrait] is a [Texture2D] or a resource path, [param side] is [code]"left"[/code] or [code]"right"[/code]. a bunch of [method say] calls in a row reads as one conversation, the box stays open between lines.
func say(speaker: String, text: String, portrait: Variant = null, side: String = "left") -> void:
	await get_dialogue().say(speaker, text, portrait, side)

## shows a dialogue line with answers in the dialogue box. returns the index picked.
func ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") -> int:
	return await get_dialogue().ask(speaker, text, options, portrait, side)

## shows one full screen narration line. [param background] is a [Texture2D] or a resource path, [code]null[/code] keeps the current one while narration stays open.
func narrate(text: String, background: Variant = null) -> void:
	await get_narration().narrate(text, background)

#endregion

#region JSON dialog

## plays the entry [param key] from the dialog json [param file] and returns the answers given during it. entries play one at a time, so a call made while one's playing waits its turn. the dialog README has the file format.
func play(file: String, key: String) -> Dictionary:
	return await runner.play(file, key)

## ends the entry that's playing. the line showing now ends and its windows close.
func stop() -> void:
	runner.stop()

## checks a dialog file for mistakes and prints what it finds to the output panel. returns the
## problems (see [OmniDialogValidator]), empty means the file's fine.
func check_file(file: String) -> Array[Dictionary]:
	var problems := OmniDialogValidator.check_file(file)
	print(OmniDialogValidator.format_report(file, problems))
	return problems

## fast forwards the rest of the playing entry up to its next question. see [method OmniDialogRunner.skip].
## the dialogue box and narration also have a hold to skip button that does this.
func skip_entry() -> void:
	runner.skip()

## returns [code]true[/code] while the playing entry is being skipped. event handlers can check it to
## jump straight to where they'd end up.
func is_skipping() -> bool:
	return runner.is_skipping()

## returns [code]true[/code] while an entry from a dialog file is playing.
func is_playing() -> bool:
	return runner.is_running()

## runs [param handler] whenever a dialog line fires the event [param event_name], and passes it the event's [code]args[/code]. if the handler awaits something the dialog waits for it (unless the event says [code]"wait": false[/code]).
func register_event(event_name: String, handler: Callable) -> void:
	runner.register_event(event_name, handler)

## stops running the handler registered for [param event_name].
func unregister_event(event_name: String) -> void:
	runner.unregister_event(event_name)

## returns the answer a dialog file question stored under [param id], or [param default] if it hasn't been answered.
func get_answer(id: String, default: Variant = null) -> Variant:
	return runner.get_answer(id, default)

## stores [param value] under [param id], like so dialog lines can check game state with [code]if[/code].
func set_answer(id: String, value: Variant) -> void:
	runner.set_answer(id, value)

## returns a copy of every stored answer. save it with your game.
func get_answers() -> Dictionary:
	return runner.get_answers()

## replaces every stored answer, like with a Dictionary from a saved game.
func set_answers(values: Dictionary) -> void:
	runner.set_answers(values)

#endregion

#region Look

## switches the look of every window this autoload handles, now and from here on. [code]null[/code] goes back to the project default.
func set_dialog_theme(t: OmniDialogTheme) -> void:
	dialog_theme = t
	for w in [_popup, _toast, _dialogue, _narration]:
		if is_instance_valid(w):
			w.dialog_theme = t

#endregion

#region Window instances

## the [OmniPopup] this autoload uses (made on the first call).
func get_popup() -> OmniPopup:
	if not is_instance_valid(_popup):
		_popup = _instantiate("popup_scene") as OmniPopup
	return _popup

## the [OmniToast] this autoload uses (made on the first call).
func get_toast() -> OmniToast:
	if not is_instance_valid(_toast):
		_toast = _instantiate("toast_scene") as OmniToast
	return _toast

## the [OmniDialogueBox] this autoload uses (made on the first call).
func get_dialogue() -> OmniDialogueBox:
	if not is_instance_valid(_dialogue):
		_dialogue = _instantiate("dialogue_scene") as OmniDialogueBox
	return _dialogue

## the [OmniNarration] this autoload uses (made on the first call).
func get_narration() -> OmniNarration:
	if not is_instance_valid(_narration):
		_narration = _instantiate("narration_scene") as OmniNarration
	return _narration

## scene path for a window ([param key] is a key of [constant DEFAULT_SCENES]), from project settings or the prebuilt default.
static func scene_path(key: String) -> String:
	var path := str(ProjectSettings.get_setting(SETTING_PREFIX + key, ""))
	return path if path != "" else str(DEFAULT_SCENES[key])

func _instantiate(key: String) -> Node:
	var path := scene_path(key)
	var scene := load(path) as PackedScene
	if scene == null:
		push_error("OmniDialog: could not load %s scene '%s'; using the prebuilt one." % [key, path])
		scene = load(DEFAULT_SCENES[key]) as PackedScene
	var node := scene.instantiate()
	if dialog_theme != null:
		node.set("dialog_theme", dialog_theme)
	add_child(node)
	return node

#endregion
