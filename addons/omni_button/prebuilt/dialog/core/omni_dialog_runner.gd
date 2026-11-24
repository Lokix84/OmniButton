extends RefCounted
class_name OmniDialogRunner
## plays dialog entries from json files on the dialog windows, one line at a time.
##
## the [code]OmniDialog[/code] autoload has one runner ([method OmniDialogAutoload.play] uses it), but a runner works on its own too, with windows you dropped into your scene:
## [codeblock]
## var runner := OmniDialogRunner.new()
## runner.dialogue_box = $DialogueBox
## runner.narration = $Narration
## runner.popup = $Popup
## runner.toast = $Toast
## var answers := await runner.play("res://story/chapter1.json", "gate")
## [/codeblock]
## answers to questions get stored by id in [member answers] (save and load that Dictionary), and [method play] returns the answers given during that entry. lines can check answers ([code]if[/code] / [code]if_not[/code]), store values ([code]set[/code]), jump to other entries ([code]next[/code] / [code]goto[/code]), and fire events your game code handles ([method register_event]). the dialog README goes over every line type and field.

## an entry started playing.
signal started(file: String, key: String)
## a line is about to run (its conditions passed). `line` is the Dictionary from the file.
signal line_started(line: Dictionary)
## an event line, or a line's or option's "event", fired. any handler registered for it runs too.
signal event_triggered(event_name: String, args: Array)
## a question got answered (or `set` set a value).
signal choice_made(id: String, value: Variant)
## an entry finished. `entry_answers` are the answers given during it.
signal finished(file: String, key: String, entry_answers: Dictionary)
## skipping started, the rest of the entry fast forwards (see [method skip]).
signal skip_started(file: String, key: String)
## skipping stopped, either it hit a question or the entry finished.
signal skip_stopped(file: String, key: String)
signal _released

## window for [code]say[/code] lines. leave it empty and [member window_provider] makes it.
var dialogue_box: OmniDialogueBox
## window for [code]narrate[/code] lines.
var narration: OmniNarration
## window for [code]alert[/code], [code]confirm[/code] and [code]choice[/code] lines.
var popup: OmniPopup
## window for [code]toast[/code] lines.
var toast: OmniToast
## optional. gets called with [code]"dialogue_box"[/code], [code]"narration"[/code], [code]"popup"[/code] or [code]"toast"[/code] when that window is empty and should give back the window. the [code]OmniDialog[/code] autoload uses it to make its windows the first time they're needed.
var window_provider: Callable

## every answer and [code]set[/code] value so far, by id. save and restore it with your game ([method get_answers] / [method set_answers]).
var answers: Dictionary = {}

## safety limit. an entry that runs more lines than this (a [code]goto[/code] loop) gets stopped with an error.
var max_lines_per_play := 10000

var _events: Dictionary = {}
var _running := false
var _stop_requested := false
var _skipping := false
var _skippable := true
var _file := ""
var _key := ""
var _current_type := ""
## true while the line showing is a question (answers, confirm or choice).
var _current_is_question := false

#region Playing

## plays the entry [param key] from [param file] and returns the answers given during it. a call made while another entry is playing waits its turn.
func play(file: String, key: String) -> Dictionary:
	while _running:
		await _released
	_running = true
	_stop_requested = false
	var given: Dictionary = {}
	_file = file
	_key = key
	started.emit(file, key)
	var entry := OmniDialogFile.get_entry(file, key)
	_skippable = bool(entry.get("skippable", true))
	var lines: Array = entry.get("lines", [])
	var index := 0
	var steps := 0
	var current_key := key
	while index < lines.size() and not _stop_requested:
		steps += 1
		if steps > max_lines_per_play:
			push_error("OmniDialog: stopped '%s' in %s after %d lines (does a goto loop?)." % [current_key, file, max_lines_per_play])
			break
		var line: Variant = lines[index]
		index += 1
		if not line is Dictionary:
			push_error("OmniDialog: line %d of '%s' in %s is not an object." % [index, current_key, file])
			continue
		var jump := await _run_line(line, given)
		if jump == "__end":
			break
		if jump != "":
			var next_entry := OmniDialogFile.get_entry(file, jump)
			if next_entry.is_empty():
				break
			lines = next_entry["lines"]
			current_key = jump
			index = 0
	_stop_skipping()
	for kind in ["dialogue_box", "narration"]:
		var tw := _get_window(kind, false) as OmniTextWindow
		if tw != null:
			tw.set_skip_available(false)
	_close_text_windows()
	_running = false
	_current_type = ""
	_current_is_question = false
	finished.emit(file, key, given)
	_released.emit()
	return given

## fast forwards the rest of the running entry. the lines don't show, but their [code]set[/code] values,
## conditions and jumps still happen, so the game ends up where it would have anyway. [code]wait[/code]
## lines and toasts get dropped, and events still run (handlers can check [method is_skipping] and
## jump to where they'd end up). skipping stops at the next question, which shows like normal. does
## nothing for an entry with [code]"skippable": false[/code]. the windows' hold to skip button and
## [member OmniTextWindow.skip_action] call this.
func skip() -> void:
	if not _running or not _skippable or _skipping:
		return
	if _current_is_question:
		# never skip a question, just show the rest of it and its answers.
		for kind in ["dialogue_box", "narration"]:
			var qw := _get_window(kind, false) as OmniTextWindow
			if qw != null:
				qw.end_line()
		return
	_skipping = true
	skip_started.emit(_file, _key)
	# end the line showing now, unless it's a question.
	for kind in ["dialogue_box", "narration"]:
		var tw := _get_window(kind, false) as OmniTextWindow
		if tw != null:
			tw.end_line()
	if _current_type == "alert":
		var p := _get_window("popup", false) as OmniPopup
		if p != null and p.is_open():
			p.cancel()

## returns [code]true[/code] while the entry is being skipped. event handlers use it to jump to where
## they'd end up instead of animating.
func is_skipping() -> bool:
	return _skipping

func _stop_skipping() -> void:
	if _skipping:
		_skipping = false
		skip_stopped.emit(_file, _key)

## stops the running entry. the line showing now ends (a question counts as canceled) and its windows close.
func stop() -> void:
	if not _running:
		return
	_stop_requested = true
	for kind in ["dialogue_box", "narration", "popup"]:
		var w := _get_window(kind, false) as OmniOverlay
		if w != null and w.is_open():
			w.close()

## returns [code]true[/code] while an entry is playing.
func is_running() -> bool:
	return _running

#endregion

#region Answers

## returns the answer stored under [param id], or [param default] if there isn't one.
func get_answer(id: String, default: Variant = null) -> Variant:
	return answers.get(id, default)

## stores [param value] under [param id]. lines can check it with [code]if[/code] / [code]if_not[/code].
func set_answer(id: String, value: Variant) -> void:
	answers[id] = value

## returns a deep copy of [member answers].
func get_answers() -> Dictionary:
	return answers.duplicate(true)

## replaces [member answers] with a deep copy of [param values].
func set_answers(values: Dictionary) -> void:
	answers = values.duplicate(true)

#endregion

#region Events

## runs [param handler] (with the event's [code]args[/code]) whenever an event named [param event_name] fires. if the handler awaits, the dialog waits for it unless the event says [code]"wait": false[/code].
## [b]heads up:[/b] don't bind this runner into its own handler ([code]_f.bind(runner)[/code]). the runner holds onto its handlers so it'd never get freed.
func register_event(event_name: String, handler: Callable) -> void:
	_events[event_name] = handler

## stops running the handler registered for [param event_name].
func unregister_event(event_name: String) -> void:
	_events.erase(event_name)

func _fire_event(event: Variant, wait := true) -> void:
	var event_name := ""
	var args: Array = []
	if event is String:
		event_name = event
	elif event is Dictionary:
		event_name = str(event.get("name", ""))
		args = event.get("args", []) if event.get("args") is Array else []
		wait = bool(event.get("wait", wait))
	if event_name == "":
		return
	event_triggered.emit(event_name, args)
	var handler: Callable = _events.get(event_name, Callable())
	if handler.is_valid():
		if wait:
			await handler.callv(args)
		else:
			handler.callv(args)

#endregion

#region Lines

## runs one line. returns "" to keep going, an entry key to jump to, or "__end" to stop.
func _run_line(line: Dictionary, given: Dictionary) -> String:
	if not _passes(line):
		return ""
	line_started.emit(line)
	if line.has("event") and str(line.get("type", "")) != "event":
		await _fire_event(line["event"])
	_apply_set(line.get("set"), given)
	var type := str(line.get("type", "say"))
	_current_type = type
	_current_is_question = type in ["confirm", "choice"] or (type in ["say", "narrate"] and not _choices(line)["options"].is_empty())
	if _skipping:
		match type:
			"toast", "alert", "wait":
				return ""
			"confirm", "choice":
				_stop_skipping()
	match type:
		"say":
			return await _run_text_line(line, given, "dialogue_box")
		"narrate":
			return await _run_text_line(line, given, "narration")
		"toast":
			var t := _get_window("toast") as OmniToast
			if t != null:
				t.toast(_tr(line.get("text", "")), float(line.get("duration", -1.0)))
		"alert":
			var p := _get_window("popup") as OmniPopup
			if p != null:
				await p.alert(_tr(line.get("text", "")), _tr(line.get("title", "")), _tr(line.get("button", "OK")))
		"confirm":
			var p := _get_window("popup") as OmniPopup
			if p != null:
				var yes := await p.confirm(_tr(line.get("text", "")), _tr(line.get("title", "")), _tr(line.get("yes", "Yes")), _tr(line.get("no", "No")))
				_store(str(line.get("id", "")), yes, given)
				var target := str(line.get("on_yes" if yes else "on_no", ""))
				if target != "":
					return target
		"choice":
			var p := _get_window("popup") as OmniPopup
			if p != null:
				var group := _choices(line)
				var labels := PackedStringArray()
				for o in group["options"]:
					labels.append(_tr(o.get("text", "")))
				var pick := await p.choose(_tr(line.get("text", "")), labels, _tr(line.get("title", "")))
				return await _apply_option(group, pick, given)
		"event":
			await _fire_event(line, bool(line.get("wait", true)))
		"wait":
			var tree := Engine.get_main_loop() as SceneTree
			if tree != null:
				await tree.create_timer(float(line.get("seconds", 0.0)), true, false, true).timeout
		"goto":
			return str(line.get("next", ""))
		"end":
			return "__end"
		_:
			push_error("OmniDialog: unknown line type '%s'." % type)
	return ""

## a dialogue or narration line, maybe with answers.
func _run_text_line(line: Dictionary, given: Dictionary, kind: String) -> String:
	var group := _choices(line)
	if _skipping:
		if group["options"].is_empty():
			return ""
		_stop_skipping()
	var window := _get_window(kind) as OmniTextWindow
	if window == null:
		return ""
	if not window.skip_requested.is_connected(skip):
		window.skip_requested.connect(skip)
	window.set_skip_available(_skippable)
	# only one text window at a time, switching from dialogue to narration closes the other one.
	var other := _get_window("narration" if kind == "dialogue_box" else "dialogue_box", false) as OmniTextWindow
	if other != null and other.is_open():
		await other.close()
	var labels := PackedStringArray()
	for o in group["options"]:
		labels.append(_tr(o.get("text", "")))
	var speed := float(line.get("speed", 0.0))
	var pick := -1
	if kind == "dialogue_box":
		pick = await (window as OmniDialogueBox).show_line(_tr(line.get("name", "")), _tr(line.get("text", "")),
			line.get("portrait"), str(line.get("side", "left")), labels, speed)
	else:
		pick = await (window as OmniNarration).show_text(_tr(line.get("text", "")), line.get("background"), labels, speed)
	if group["options"].is_empty():
		return ""
	return await _apply_option(group, pick, given)

## the line's "choices" group, minus any options whose conditions fail.
## returns { "id": String, "options": Array[Dictionary] (with "_index": where it was originally) }.
func _choices(line: Dictionary) -> Dictionary:
	var group: Variant = line.get("choices")
	var out := {"id": "", "options": []}
	if not group is Dictionary:
		return out
	out["id"] = str(group.get("id", ""))
	var options: Variant = group.get("options", [])
	if not options is Array:
		return out
	for i in options.size():
		var o: Variant = options[i]
		if o is String:
			o = {"text": o}
		if o is Dictionary and _passes(o):
			var copy: Dictionary = o.duplicate()
			copy["_index"] = i
			out["options"].append(copy)
	return out

## stores the picked option's value, does its `set` and `event`, and returns its `next`.
func _apply_option(group: Dictionary, pick: int, given: Dictionary) -> String:
	var options: Array = group["options"]
	if pick < 0 or pick >= options.size():
		_store(group["id"], -1, given)
		return ""
	var option: Dictionary = options[pick]
	_store(group["id"], option.get("value", option["_index"]), given)
	_apply_set(option.get("set"), given)
	if option.has("event"):
		await _fire_event(option["event"])
	return str(option.get("next", ""))

func _store(id: String, value: Variant, given: Dictionary) -> void:
	if id == "":
		return
	answers[id] = value
	given[id] = value
	choice_made.emit(id, value)

func _apply_set(values: Variant, given: Dictionary) -> void:
	if values is Dictionary:
		for id in values:
			_store(str(id), values[id], given)

## conditions: every `if` id has to match and no `if_not` id can match. a list matches any of its
## values, null matches an id that hasn't been answered yet.
func _passes(item: Dictionary) -> bool:
	var must: Variant = item.get("if")
	if must is Dictionary:
		for id in must:
			if not _matches(str(id), must[id]):
				return false
	var must_not: Variant = item.get("if_not")
	if must_not is Dictionary:
		for id in must_not:
			if _matches(str(id), must_not[id]):
				return false
	return true

func _matches(id: String, expected: Variant) -> bool:
	if expected == null:
		return not answers.has(id)
	if not answers.has(id):
		return false
	var actual: Variant = answers[id]
	if expected is Array:
		for e in expected:
			if _same(actual, e):
				return true
		return false
	return _same(actual, expected)

## json numbers are floats, so 1 and 1.0 count as the same answer.
static func _same(a: Variant, b: Variant) -> bool:
	if (a is int or a is float) and (b is int or b is float):
		return is_equal_approx(float(a), float(b))
	return typeof(a) == typeof(b) and a == b

#endregion

#region Windows

func _get_window(kind: String, create := true) -> Node:
	var w: Node = get(kind)
	if is_instance_valid(w):
		return w
	if create and window_provider.is_valid():
		w = window_provider.call(kind)
		# remember it so closing and switching windows later can find it.
		if is_instance_valid(w):
			set(kind, w)
		return w
	if create:
		push_error("OmniDialog: this line needs a %s, and the runner has none." % kind)
	return null

func _close_text_windows() -> void:
	for kind in ["dialogue_box", "narration"]:
		var w := _get_window(kind, false) as OmniTextWindow
		if w != null:
			w.close_if_idle()

static func _tr(value: Variant) -> String:
	var s := str(value) if value != null else ""
	return String(TranslationServer.translate(s)) if s != "" else ""

#endregion
