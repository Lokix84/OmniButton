extends SceneTree
# Checks JSON dialog files: loading, every line type, answers, conditions, jumps, events and the
# runner working with or without the OmniDialog autoload.
# Usage: godot --headless --path . -s res://addons/omni_button/prebuilt/dialog/dev/OmniDialogDataValidation.gd

const DialogScript := preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")
const BoxScene := preload("res://addons/omni_button/prebuilt/dialog/windows/dialogue_box/omni_dialogue_box.tscn")
const FILE := "user://omni_dialog_test.json"
const BAD_FILE := "user://omni_dialog_bad.json"
const MISTAKES_FILE := "user://omni_dialog_mistakes.json"
const PORTRAIT := "res://addons/omni_button/prebuilt/dialog/demo/icons/Icon-Sword1.png"

var _failures: Array[String] = []
var _checks := 0
var _shown: Array[String] = []
var _picks: Array = []   # answers the driver gives, in order (index for options, true/false for confirm)
var _driving := false

func _initialize() -> void:
	call_deferred("_run")

func _write_files() -> void:
	var data := {
		"intro": [
			{"type": "narrate", "text": "The city of Vell."},
			{"type": "say", "name": "Guard", "text": "Halt!", "portrait": PORTRAIT},
			{"type": "say", "name": "Guard", "text": "Business?", "choices": {"id": "business", "options": [
				{"text": "Trade", "value": "trade", "set": {"met_guard": true}},
				{"text": "Leave", "value": "leave", "next": "leave"},
				{"text": "Bribe", "value": "bribe", "if": {"has_gold": true}},
			]}},
			{"type": "say", "name": "Guard", "text": "Welcome, trader.", "if": {"business": "trade"}},
			{"type": "say", "name": "Guard", "text": "Bribes noted.", "if": {"business": "bribe"}},
			{"type": "event", "name": "flash", "args": [1, "red"]},
			{"type": "confirm", "id": "follow", "text": "Follow him?", "on_no": "leave"},
			{"type": "toast", "text": "You follow the guard."},
			{"type": "goto", "next": "market"},
			{"type": "say", "text": "skipped by goto"},
		],
		"leave": [
			{"type": "say", "name": "Guard", "text": "Then go."},
			{"type": "end"},
			{"type": "say", "text": "after end"},
		],
		"market": [
			{"type": "wait", "seconds": 0.1},
			{"type": "say", "text": "The market.", "if_not": {"follow": false}},
			{"type": "alert", "text": "Chapter done.", "title": "End"},
		],
		"loop": [{"type": "goto", "next": "loop"}],
		"object_form": {"skippable": false, "lines": [{"type": "say", "text": "Object form."}]},
		"plain_options": [
			{"type": "say", "text": "Pick one", "choices": {"id": "num", "options": ["A", "B"]}},
			{"type": "say", "text": "Picked B.", "if": {"num": 1}},
			{"type": "say", "text": "Picked A or B.", "if": {"num": [0, 1]}},
			{"type": "say", "text": "Unasked.", "if": {"never_asked": null}},
		],
		"popup_choice": [
			{"type": "choice", "text": "Class?", "title": "New game", "choices": {"id": "class", "options": [
				{"text": "Warrior", "value": "warrior"}, {"text": "Mage", "value": "mage", "event": "mage_picked"}]}},
		],
		"slow_event": [
			{"type": "event", "name": "slow"},
			{"type": "say", "text": "After the slow event."},
		],
		"line_event": [
			{"type": "say", "text": "With a cue.", "event": {"name": "cue", "args": ["door"]}},
		],
		"skip_me": [
			{"type": "say", "text": "Skip A"},
			{"type": "say", "text": "Skip B", "set": {"skipped_set": true}},
			{"type": "event", "name": "skip_event"},
			{"type": "wait", "seconds": 5},
			{"type": "toast", "text": "Skipped toast"},
			{"type": "goto", "next": "skip_tail"},
		],
		"skip_tail": [
			{"type": "say", "text": "Skip C"},
			{"type": "say", "text": "Question", "choices": {"id": "after_skip", "options": ["Yes", "No"]}},
			{"type": "say", "text": "After the question"},
		],
		"no_skip": {"skippable": false, "lines": [
			{"type": "say", "text": "Must read"},
			{"type": "say", "text": "Must read too"},
		]},
	}
	var f := FileAccess.open(FILE, FileAccess.WRITE)
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	var mistakes := {
		"start": [
			{"type": "say", "text": "Hi", "nmae": "Typo"},
			{"type": "sya", "text": "Bad type"},
			{"type": "goto", "next": "nowhere"},
			{"type": "confirm", "text": "Sure?", "on_no": "missing_entry"},
			{"type": "say", "text": "Pick", "choices": {"options": [{"text": "A", "next": "gone"}, {"value": 2}]}},
			{"type": "say", "text": "Cond", "if": {"never_stored": true}},
			{"type": "say", "text": "Side", "side": "middle"},
			{"type": "say", "text": "Face", "portrait": "res://no/such/portrait.png"},
			{"type": "wait", "seconds": "two"},
			{"type": "event"},
			"just a string",
		],
		"broken_entry": {"lnies": []},
	}
	var m := FileAccess.open(MISTAKES_FILE, FileAccess.WRITE)
	m.store_string(JSON.stringify(mistakes))
	m.close()
	var b := FileAccess.open(BAD_FILE, FileAccess.WRITE)
	b.store_string("{ \"broken\": [ ")
	b.close()
	OmniDialogFile.clear_cache()

## Plays the windows like a player: advances text, and answers questions from _picks.
func _drive(runner: OmniDialogRunner) -> void:
	_driving = true
	while _driving:
		await process_frame
		for kind in ["dialogue_box", "narration"]:
			var w = runner.get(kind)
			if w == null and runner.window_provider.is_valid():
				w = runner.window_provider.call(kind)
			if w == null or not w.is_open():
				continue
			match w.state:
				OmniTextWindow.State.REVEALING, OmniTextWindow.State.WAITING:
					w.advance()
				OmniTextWindow.State.CHOOSING:
					if not w._option_nodes.is_empty():
						var i: int = _picks.pop_front() if not _picks.is_empty() else 0
						w._option_nodes[i].pressed.emit()
		var p = runner.popup if runner.popup != null else (runner.window_provider.call("popup") if runner.window_provider.is_valid() else null)
		if p != null and p.is_open() and p._waiting and not p._button_nodes.is_empty():
			var a = _picks.pop_front() if not _picks.is_empty() else 0
			var index: int = (0 if a else 1) if a is bool else int(a)
			p._button_nodes[index].pressed.emit()

func _play(runner_or_dlg, key: String, picks: Array) -> Dictionary:
	_shown.clear()
	_picks = picks.duplicate()
	var runner: OmniDialogRunner = runner_or_dlg if runner_or_dlg is OmniDialogRunner else runner_or_dlg.runner
	_drive(runner)
	var result: Dictionary = await runner_or_dlg.play(FILE, key)
	_driving = false
	await process_frame
	await process_frame
	return result

func _run() -> void:
	_write_files()
	var dlg = DialogScript.new()
	root.add_child(dlg)
	await process_frame
	for w in [dlg.get_dialogue(), dlg.get_narration(), dlg.get_popup(), dlg.get_toast()]:
		w.animation_duration = 0.0
	dlg.get_dialogue().characters_per_second = 500.0
	dlg.get_narration().characters_per_second = 500.0
	dlg.runner.line_started.connect(func(line): _shown.append(str(line.get("text", line.get("type", "")))))
	var events: Array = []
	dlg.event_triggered.connect(func(n, a): events.append([n, a]))
	var flashes: Array = []
	dlg.register_event("flash", func(times, color): flashes.append([times, color]))

	# --- Loading
	_check(OmniDialogFile.get_keys(FILE).has("intro") and OmniDialogFile.get_keys(FILE).size() == 12, "a dialog file loads with all its entries")
	_check(OmniDialogFile.get_entry(FILE, "object_form").get("skippable") == false, "an entry can be an object with lines and options")
	_check(OmniDialogFile.get_entry(FILE, "missing").is_empty(), "a missing key gives an empty entry")
	_check(OmniDialogFile.load_file(BAD_FILE).is_empty(), "a broken JSON file reports an error and loads nothing")
	_check(OmniDialogFile.load_file("user://does_not_exist.json").is_empty(), "a missing file reports an error and loads nothing")

	# --- The main path: Trade, then follow
	var given := await _play(dlg, "intro", [0, true])
	_check(given == {"business": "trade", "met_guard": true, "follow": true}, "play returns the answers given during the entry")
	_check(_shown.has("Welcome, trader.") and not _shown.has("Bribes noted."), "if shows only the line whose answer matches")
	# JSON numbers load as floats, so 1 arrives as 1.0.
	_check(flashes == [[1.0, "red"]] and events.has(["flash", [1.0, "red"]]), "event lines run their handler with the args")
	_check(_shown.has("You follow the guard.") and dlg.get_toast().count() >= 1, "toast lines show a toast")
	_check(_shown.has("The market.") and _shown.has("Chapter done.") and not _shown.has("skipped by goto"), "goto continues in another entry and skips the rest")
	_check(dlg.get_answer("business") == "trade" and dlg.get_answers().has("met_guard"), "answers are kept on the runner")
	_check(not dlg.get_dialogue().is_open() and not dlg.get_narration().is_open() and not dlg.get_popup().is_open(), "windows close when the entry ends")
	_check(not dlg.get_narration().is_open(), "switching from narration to dialogue closes the narration")

	# --- Leave: option next + end
	given = await _play(dlg, "intro", [1])
	_check(given.get("business") == "leave" and _shown.has("Then go.") and not _shown.has("after end"), "an option's next jumps, and end stops the entry")
	_check(not _shown.has("Welcome, trader."), "lines after a jump don't run")

	# --- Hidden option appears once its condition is met; confirm No goes to on_no
	dlg.set_answer("has_gold", true)
	_picks = []
	var seen_options := [0]
	var count_options := func():
		var box = dlg.get_dialogue()
		if box.state == OmniTextWindow.State.CHOOSING:
			seen_options[0] = box._option_nodes.size()
	dlg.get_dialogue().line_revealed.connect(func(): count_options.call_deferred())
	given = await _play(dlg, "intro", [2, false])
	_check(seen_options[0] == 3, "an option shows once its if condition is met")
	_check(given.get("business") == "bribe" and _shown.has("Bribes noted."), "the extra option can be picked")
	_check(given.get("follow") == false and _shown.has("Then go."), "confirm stores false and follows on_no")

	# --- Plain string options, number values and list / null conditions
	given = await _play(dlg, "plain_options", [1])
	_check(given.get("num") == 1, "plain string options store their index")
	_check(_shown.has("Picked B.") and _shown.has("Picked A or B.") and _shown.has("Unasked."), "number, list and null conditions match")

	# --- Popup choice with an option event
	given = await _play(dlg, "popup_choice", [1])
	_check(given.get("class") == "mage" and events.any(func(e): return e[0] == "mage_picked"), "choice lines use the popup and fire option events")

	# --- An awaited event holds the dialog until it finishes
	var slow_done := [false]
	dlg.register_event("slow", func():
		await create_timer(0.3).timeout
		slow_done[0] = true)
	var shown_before_done := [false]
	dlg.runner.line_started.connect(func(line):
		if line.get("text") == "After the slow event." and not slow_done[0]:
			shown_before_done[0] = true)
	await _play(dlg, "slow_event", [])
	_check(slow_done[0] and not shown_before_done[0], "the next line waits for an awaited event handler")

	# --- A line's own event fires before it shows
	events.clear()
	await _play(dlg, "line_event", [])
	_check(events.has(["cue", ["door"]]), "a line's event fires")

	# --- Object-form entry, loop guard, missing key
	await _play(dlg, "object_form", [])
	_check(_shown.has("Object form."), "object-form entries play their lines")
	dlg.runner.max_lines_per_play = 50
	var loop_result: Dictionary = await dlg.play(FILE, "loop")
	_check(loop_result.is_empty() and not dlg.is_playing(), "a goto loop is stopped by the line limit")
	dlg.runner.max_lines_per_play = 10000
	var missing: Dictionary = await dlg.play(FILE, "missing")
	_check(missing.is_empty() and not dlg.is_playing(), "a missing entry ends straight away")

	# --- stop() ends the entry and closes its windows
	var stopped := [false]
	var run_stop := func():
		await dlg.play(FILE, "leave")
		stopped[0] = true
	run_stop.call()
	await process_frame
	await process_frame
	dlg.stop()
	await process_frame
	await process_frame
	_check(stopped[0] and not dlg.get_dialogue().is_open(), "stop ends the entry and closes the dialogue box")

	# --- Saving and loading answers
	var saved: Dictionary = dlg.get_answers()
	dlg.set_answers({})
	_check(dlg.get_answer("business") == null, "set_answers replaces the answers")
	dlg.set_answers(saved)
	_check(dlg.get_answer("business") == "bribe", "answers come back from a saved Dictionary")

	# --- Skipping fast-forwards to the next question
	var box: OmniDialogueBox = dlg.get_dialogue()
	var skip_events: Array = []
	dlg.register_event("skip_event", func(): skip_events.append(dlg.is_skipping()))
	var skip_signals: Array = []
	dlg.skip_started.connect(func(_f, _k): skip_signals.append("started"))
	dlg.skip_stopped.connect(func(_f, _k): skip_signals.append("stopped"))
	_shown.clear()
	var toasts_before: int = dlg.get_toast().count()
	var skip_result := [null]
	var run_skip := func(): skip_result[0] = await dlg.play(FILE, "skip_me")
	run_skip.call()
	await process_frame
	await process_frame
	_check(box.skip_button != null and box.skip_button.visible, "the hold-to-skip button shows during a skippable entry")
	var started_at := Time.get_ticks_msec()
	box.skip_button.hold.emit()   # what holding the button until its fill completes does
	for i in 10:
		await process_frame
	_check(box.state == OmniTextWindow.State.CHOOSING, "skipping stops at the next question, which shows normally")
	_check(Time.get_ticks_msec() - started_at < 2000, "skipping doesn't wait for wait lines")
	_check(dlg.get_answer("skipped_set") == true, "skipped lines still apply their set values")
	_check(skip_events == [true], "events still run while skipping, and see is_skipping()")
	_check(dlg.get_toast().count() == toasts_before, "toasts are dropped while skipping")
	_check(skip_signals == ["started", "stopped"] and not dlg.is_skipping(), "skip_started and skip_stopped are emitted")
	_check(not box.skip_button.visible, "the skip button hides while answers show")
	_check(_shown.has("Skip C") and box.body.Text == "Question", "skipped lines run without being shown")
	box._option_nodes[0].pressed.emit()
	await process_frame
	# (Text only updates when the reveal finishes, so check that the line started and is typing.)
	_check(_shown.back() == "After the question" and box.state in [OmniTextWindow.State.REVEALING, OmniTextWindow.State.WAITING], "after the question the entry plays normally again")
	box.advance(); box.advance()
	for i in 4:
		await process_frame
	_check(skip_result[0] != null and skip_result[0].get("after_skip") == 0, "the entry finishes with the answer given after skipping")
	_check(not box.skip_button.visible, "the skip button hides when the entry ends")

	# --- Skipping during a question only reveals it; the question is never skipped
	var q_result := [null]
	var run_q := func(): q_result[0] = await dlg.play(FILE, "skip_tail")
	run_q.call()
	await process_frame
	box.advance(); box.advance()   # past "Skip C"
	await process_frame
	await process_frame
	_check(box.body.get("_tw_active") or box.state == OmniTextWindow.State.CHOOSING, "the question line is showing")
	_check(not box.skip_button.visible, "no skip button on a question line, even while it types")
	dlg.skip_entry()
	await process_frame
	await process_frame
	_check(box.state == OmniTextWindow.State.CHOOSING and not dlg.is_skipping(), "skip during a question reveals it instead of skipping it")
	box._option_nodes[0].pressed.emit()
	await process_frame
	box.advance(); box.advance()
	for i in 4:
		await process_frame
	_check(q_result[0] != null and q_result[0].get("after_skip") == 0, "the question was still answered")

	# --- An entry marked "skippable": false can't be skipped
	var no_skip_done := [false]
	var run_no_skip := func():
		await dlg.play(FILE, "no_skip")
		no_skip_done[0] = true
	run_no_skip.call()
	await process_frame
	await process_frame
	_check(not box.skip_button.visible, "no skip button for a skippable: false entry")
	dlg.skip_entry()
	await process_frame
	_check(not dlg.is_skipping() and box.state != OmniTextWindow.State.IDLE and box.body.Text == "Must read", "skip does nothing on a skippable: false entry")
	for i in 3:
		box.advance(); box.advance()
		await process_frame
		await process_frame
	_check(no_skip_done[0], "the unskippable entry plays through")

	# --- skip_action input
	box.skip_action = &"ui_end"
	run_skip.call()
	await process_frame
	await process_frame
	var key := InputEventAction.new()
	key.action = &"ui_end"
	key.pressed = true
	root.push_input(key)
	for i in 10:
		await process_frame
	_check(box.state == OmniTextWindow.State.CHOOSING, "the skip_action input skips")
	box._option_nodes[1].pressed.emit()
	await process_frame
	box.advance(); box.advance()
	for i in 4:
		await process_frame
	box.skip_action = &""

	# --- The file checker
	_check(OmniDialogValidator.check_file(FILE).filter(func(p): return p["severity"] == "error").is_empty(), "the test story has no errors")
	var problems := OmniDialogValidator.check_file(MISTAKES_FILE)
	var report := OmniDialogValidator.format_report(MISTAKES_FILE, problems)
	var expect := {
		"misspelled field": "\"nmae\"",
		"unknown type": "Unknown type \"sya\"",
		"goto to a missing entry": "next points to \"nowhere\"",
		"confirm without id": "confirm without an \"id\"",
		"on_no to a missing entry": "on_no points to \"missing_entry\"",
		"choices without id": "choices without an \"id\"",
		"option next to a missing entry": "option 1 next points to \"gone\"",
		"option without text": "Option 2 has no \"text\"",
		"condition nothing stores": "checks \"never_stored\"",
		"bad side": "\"side\" must be",
		"missing portrait": "portrait not found",
		"wait seconds not a number": "needs \"seconds\" as a number",
		"event without a name": "event line has no \"name\"",
		"line that isn't an object": "A line must be an object",
		"bad entry": "Unknown entry field \"lnies\"",
	}
	for what in expect:
		_check(report.contains(expect[what]), "the checker reports: " + what)
	_check(report.contains("start, line 2"), "problems say which entry and line they're on")
	_check(OmniDialogValidator.check_file(BAD_FILE).size() == 1, "an unreadable file is one error")

	# --- A runner without the autoload, on a dropped-in dialogue box
	var own_box: OmniDialogueBox = BoxScene.instantiate()
	own_box.animation_duration = 0.0
	own_box.characters_per_second = 500.0
	root.add_child(own_box)
	await process_frame
	var own := OmniDialogRunner.new()
	own.dialogue_box = own_box
	given = await _play(own, "plain_options", [0])
	_check(given.get("num") == 0 and own.get_answer("num") == 0 and dlg.get_answer("num") == 1, "a runner works on its own windows with its own answers")
	own_box.queue_free()

	dlg.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OmniDialog data validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniDialog data validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
