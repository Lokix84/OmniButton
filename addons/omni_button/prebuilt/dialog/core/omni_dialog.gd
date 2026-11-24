extends Node
class_name OmniDialogAutoload
## The [code]OmniDialog[/code] autoload: shows OmniButton's dialog windows from any script.
##
## The OmniButton plugin registers this script as the [code]OmniDialog[/code] autoload. Using it is optional: every window also works dropped into a scene ([OmniPopup], [OmniToast], [OmniDialogueBox], [OmniNarration]), and an [OmniDialogRunner] plays dialog files without it.
## Each window is created the first time it's needed and then reused. Which scene a window uses comes from [b]Project Settings > omni_button/dialog/popup_scene[/b] ([code]toast_scene[/code], [code]dialogue_scene[/code], [code]narration_scene[/code]), and its look from [code]omni_button/dialog/theme[/code].
## [codeblock]
## OmniDialog.toast("Game saved")
## if await OmniDialog.confirm("Quit to the title screen?"):
##     get_tree().quit()
## await OmniDialog.say("Guard", "Halt!", "res://portraits/guard.png")
## var pick := await OmniDialog.ask("Guard", "Your business?", ["Trade", "Leave"])
## await OmniDialog.narrate("Three days later...")
## var answers := await OmniDialog.play("res://story/chapter1.json", "gate")
## [/codeblock]

## Prefix of the Project Settings that choose each window's scene.
const SETTING_PREFIX := "omni_button/dialog/"
## The prebuilt scene for each window, used when its Project Setting is empty.
const DEFAULT_SCENES := {
	"popup_scene": "res://addons/omni_button/prebuilt/dialog/windows/popup/omni_popup.tscn",
	"toast_scene": "res://addons/omni_button/prebuilt/dialog/windows/toast/omni_toast.tscn",
	"dialogue_scene": "res://addons/omni_button/prebuilt/dialog/windows/dialogue_box/omni_dialogue_box.tscn",
	"narration_scene": "res://addons/omni_button/prebuilt/dialog/windows/narration/omni_narration.tscn",
}

## Look of the windows this autoload manages. [code]null[/code] uses the project default ([code]omni_button/dialog/theme[/code]). Change it with [method set_dialog_theme].
var dialog_theme: OmniDialogTheme

## Player text-speed setting for every dialog window, including dropped-in ones: [code]1[/code] normal,
## [code]2[/code] twice as fast, [code]0[/code] instant. Same as [member OmniTextWindow.text_speed_scale].
## Save it with the player's settings; it isn't saved for you.
var text_speed_scale: float:
	get: return OmniTextWindow.text_speed_scale
	set(value): OmniTextWindow.text_speed_scale = maxf(value, 0.0)

## The [OmniDialogRunner] that [method play] uses, wired to this autoload's windows. Its answers are the ones [method get_answer] and [method set_answers] read and write.
var runner := OmniDialogRunner.new()

## An entry from a dialog file started playing (see [method play]).
signal started(file: String, key: String)
## A dialog line fired an event. Handlers registered with [method register_event] also run.
signal event_triggered(event_name: String, args: Array)
## A question in a dialog file was answered, or a line's [code]set[/code] stored a value.
signal choice_made(id: String, value: Variant)
## Skipping started (see [method skip_entry]).
signal skip_started(file: String, key: String)
## Skipping ended: a question was reached, or the entry finished.
signal skip_stopped(file: String, key: String)
## An entry finished. [param entry_answers] holds the answers given during it.
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

## Shows a short message that disappears on its own after [param duration] seconds (the toast's [member OmniToast.default_duration] when negative). Doesn't block: await it only to wait until it's gone.
func toast(text: String, duration: float = -1.0) -> void:
	await get_toast().toast(text, duration)

## Shows [param text] with one acknowledge button. Returns once it's dismissed.
func alert(text: String, title: String = "", ok: String = "OK") -> void:
	await get_popup().alert(text, title, ok)

## Asks a Yes / No question. Returns [code]true[/code] for Yes. Canceling counts as No.
func confirm(text: String, title: String = "", yes: String = "Yes", no: String = "No") -> bool:
	return await get_popup().confirm(text, title, yes, no)

## Asks a question with several [param options] in a popup. Returns the index picked, or [code]-1[/code] when canceled.
func choose(text: String, options: PackedStringArray, title: String = "") -> int:
	return await get_popup().choose(text, options, title)

## Shows one line in the dialogue box. [param portrait] is a [Texture2D] or a resource path; [param side] is [code]"left"[/code] or [code]"right"[/code]. A run of [method say] calls reads as one conversation: the box stays open between lines.
func say(speaker: String, text: String, portrait: Variant = null, side: String = "left") -> void:
	await get_dialogue().say(speaker, text, portrait, side)

## Shows a dialogue line with answers in the dialogue box. Returns the index picked.
func ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") -> int:
	return await get_dialogue().ask(speaker, text, options, portrait, side)

## Shows one full-screen narration line. [param background] is a [Texture2D] or a resource path; [code]null[/code] keeps the current one while narration stays open.
func narrate(text: String, background: Variant = null) -> void:
	await get_narration().narrate(text, background)

#endregion

#region JSON dialog

## Plays the entry [param key] from the dialog JSON [param file] and returns the answers given during it. Entries play one at a time: a call made while one is playing waits for its turn. See the dialog README for the file format.
func play(file: String, key: String) -> Dictionary:
	return await runner.play(file, key)

## Ends the entry that is playing. The line showing now ends and its windows close.
func stop() -> void:
	runner.stop()

## Checks a dialog file for mistakes and prints what it finds to the Output panel. Returns the problems
## (see [OmniDialogValidator]); empty means the file is fine.
func check_file(file: String) -> Array[Dictionary]:
	var problems := OmniDialogValidator.check_file(file)
	print(OmniDialogValidator.format_report(file, problems))
	return problems

## Fast-forwards the rest of the playing entry, up to its next question. See [method OmniDialogRunner.skip].
## The dialogue box and narration also have a hold-to-skip button that does this.
func skip_entry() -> void:
	runner.skip()

## Returns [code]true[/code] while the playing entry is being skipped. Event handlers can check it to
## jump straight to their end state.
func is_skipping() -> bool:
	return runner.is_skipping()

## Returns [code]true[/code] while an entry from a dialog file is playing.
func is_playing() -> bool:
	return runner.is_running()

## Runs [param handler] whenever a dialog line fires the event [param event_name], passing the event's [code]args[/code]. If the handler awaits something, the dialog waits for it (unless the event says [code]"wait": false[/code]).
func register_event(event_name: String, handler: Callable) -> void:
	runner.register_event(event_name, handler)

## Stops running the handler registered for [param event_name].
func unregister_event(event_name: String) -> void:
	runner.unregister_event(event_name)

## Returns the answer stored under [param id] by a question in a dialog file, or [param default] if it hasn't been answered.
func get_answer(id: String, default: Variant = null) -> Variant:
	return runner.get_answer(id, default)

## Stores [param value] under [param id], for example to let dialog lines check game state with [code]if[/code].
func set_answer(id: String, value: Variant) -> void:
	runner.set_answer(id, value)

## Returns a copy of every stored answer. Save it with your game.
func get_answers() -> Dictionary:
	return runner.get_answers()

## Replaces every stored answer, for example with a Dictionary from a saved game.
func set_answers(values: Dictionary) -> void:
	runner.set_answers(values)

#endregion

#region Look

## Switches the look of every window this autoload manages, now and later. [code]null[/code] goes back to the project default.
func set_dialog_theme(t: OmniDialogTheme) -> void:
	dialog_theme = t
	for w in [_popup, _toast, _dialogue, _narration]:
		if is_instance_valid(w):
			w.dialog_theme = t

#endregion

#region Window instances

## The [OmniPopup] this autoload uses (created on first call).
func get_popup() -> OmniPopup:
	if not is_instance_valid(_popup):
		_popup = _instantiate("popup_scene") as OmniPopup
	return _popup

## The [OmniToast] this autoload uses (created on first call).
func get_toast() -> OmniToast:
	if not is_instance_valid(_toast):
		_toast = _instantiate("toast_scene") as OmniToast
	return _toast

## The [OmniDialogueBox] this autoload uses (created on first call).
func get_dialogue() -> OmniDialogueBox:
	if not is_instance_valid(_dialogue):
		_dialogue = _instantiate("dialogue_scene") as OmniDialogueBox
	return _dialogue

## The [OmniNarration] this autoload uses (created on first call).
func get_narration() -> OmniNarration:
	if not is_instance_valid(_narration):
		_narration = _instantiate("narration_scene") as OmniNarration
	return _narration

## Scene path for a window ([param key] is a key of [constant DEFAULT_SCENES]), from Project Settings or the prebuilt default.
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
