extends SceneTree
# Checks the prebuilt dialogue box and narration windows through the OmniDialog autoload.
# Usage: godot --headless --path . -s res://addons/omni_button/prebuilt/dialog/dev/OmniDialogueValidation.gd

const DialogScript := preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")
const PORTRAIT := "res://addons/omni_button/prebuilt/dialog/demo/icons/Icon-Sword1.png"
const BG := preload("res://addons/omni_button/prebuilt/dialog/demo/icons/Icon-Potion6.png")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var dlg = DialogScript.new()
	root.add_child(dlg)
	var game_button := Button.new()
	game_button.focus_mode = Control.FOCUS_ALL
	root.add_child(game_button)
	game_button.grab_focus()
	await process_frame

	var box: OmniDialogueBox = dlg.get_dialogue()
	box.animation_duration = 0.0
	box.characters_per_second = 20.0
	var done := [false]
	var result := [null]

	# --- One line
	var say_one := func(): await dlg.say("Gate Guard", "Halt! Who goes there?", PORTRAIT); done[0] = true
	say_one.call()
	await process_frame
	_check(box.is_open() and box.state == OmniTextWindow.State.REVEALING, "say opens the box and starts revealing")
	_check(box.name_label.text == "Gate Guard" and box.name_label.visible, "speaker name shows")
	_check(box.portrait_left.visible and box.portrait_left.texture != null and not box.portrait_right.visible, "portrait from a path shows on the left")
	_check(not box.continue_indicator.visible, "continue indicator is hidden while revealing")
	_check(root.gui_get_focus_owner() == box.body, "the text body has focus")
	box.body.pressed.emit()
	await process_frame
	_check(box.state == OmniTextWindow.State.WAITING and box.body.Text == "Halt! Who goes there?", "pressing while revealing shows the whole line")
	_check(box.continue_indicator.visible, "continue indicator shows once the line is complete")
	_check(not done[0], "the line waits for input once fully shown")
	box.body.pressed.emit()
	await process_frame
	await process_frame
	_check(done[0] and not box.is_open(), "pressing again ends the line and the box closes after the last line")
	_check(root.gui_get_focus_owner() == game_button, "focus returns to the game")

	# --- Back-to-back lines keep the box open; speakers and sides change per line.
	done[0] = false
	var opened_count := [0]
	box.opened.connect(func(): opened_count[0] += 1)
	var conversation := func():
		await dlg.say("Gate Guard", "Halt!", PORTRAIT, "left")
		await dlg.say("Mira", "Easy, we're friends.", PORTRAIT, "right")
		await dlg.say("", "(The guard squints.)")
		done[0] = true
	conversation.call()
	await process_frame
	box.advance(); box.advance()
	await process_frame
	await process_frame
	_check(box.is_open() and box.name_label.text == "Mira", "the next line follows without closing")
	_check(box.portrait_right.visible and not box.portrait_left.visible and box.name_label.horizontal_alignment == HORIZONTAL_ALIGNMENT_RIGHT, "a right-side speaker shows on the right")
	box.advance(); box.advance()
	await process_frame
	await process_frame
	_check(not box.name_label.visible and not box.portrait_left.visible and not box.portrait_right.visible, "no name or portrait hides both")
	box.advance(); box.advance()
	await process_frame
	await process_frame
	_check(done[0] and not box.is_open() and opened_count[0] == 1, "a three-line conversation opens the box once")

	# --- ui_accept advances while the body has focus
	done[0] = false
	say_one.call()
	await process_frame
	root.push_input(_action(&"ui_accept", true))
	root.push_input(_action(&"ui_accept", false))
	await process_frame
	_check(box.state == OmniTextWindow.State.WAITING, "ui_accept skips the reveal")
	root.push_input(_action(&"ui_accept", true))
	root.push_input(_action(&"ui_accept", false))
	await process_frame
	await process_frame
	_check(done[0], "ui_accept moves on")

	# --- Options
	var ask := func(): result[0] = await dlg.ask("Gate Guard", "State your business.", PackedStringArray(["Trade", "Leave"]), PORTRAIT)
	ask.call()
	await process_frame
	await process_frame
	_check(not box.options_box.visible, "options wait until the text is shown")
	_check(box.options_column.visible, "a line with options reserves the options column from the start")
	var panel_size_typing: Vector2 = box.panel.size
	var body_size_typing: Vector2 = box.body.size
	box.advance()
	await process_frame
	await process_frame
	_check(box.state == OmniTextWindow.State.CHOOSING and box.options_box.visible and box.options_box.get_child_count() == 2, "options appear once the text is shown")
	_check(box.panel.size == panel_size_typing, "the box keeps its size when the options appear")
	_check(box.body.size == body_size_typing, "the question keeps its width when the options appear")
	_check(box.options_column.global_position.x > box.body.global_position.x + box.body.size.x - 1.0, "options sit to the right of the question")
	_check(not box.continue_indicator.visible, "no continue indicator while choosing")
	_check(root.gui_get_focus_owner() == box._option_nodes[0], "the first option takes focus")
	box.body.pressed.emit()
	await process_frame
	_check(box.state == OmniTextWindow.State.CHOOSING, "pressing the body does not skip a choice")
	box._option_nodes[1].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 1 and not box.is_open(), "ask returns the option picked")
	_check(box.options_box.get_child_count() == 0 or box._option_nodes.is_empty(), "options are removed after the choice")

	# --- Many options scroll instead of growing the box; plain lines hide the column.
	var plain_size := Vector2.ZERO
	done[0] = false
	say_one.call()
	await process_frame
	await process_frame
	plain_size = box.panel.size
	_check(not box.options_column.visible, "a line without options hides the options column")
	box.advance(); box.advance()
	await process_frame
	await process_frame
	result[0] = null
	var ask_many := func(): result[0] = await dlg.ask("Merchant", "What will it be?", PackedStringArray(["Sword", "Shield", "Potion", "Map", "Lantern", "Nothing"]), PORTRAIT)
	ask_many.call()
	await process_frame
	box.advance()
	await process_frame
	await process_frame
	_check(box._option_nodes.size() == 6 and box.panel.size == plain_size, "six options scroll inside the column; the box stays the same size")
	box._option_nodes[5].grab_focus()
	await process_frame
	await process_frame
	_check(box.options_column.scroll_vertical > 0, "the column scrolls to the focused option")
	box._option_nodes[5].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 5, "a scrolled-to option can be picked")

	# --- Long answers: wrap, share one font size, and grow instead of shrinking past the minimum.
	result[0] = null
	var ask_long := func(): result[0] = await dlg.ask("Gate Guard", "State your business.", PackedStringArray([
		"I'm a travelling merchant with silk and spices to sell in the market, and a cart of fine cloth from the southern ports.",
		"Just passing through on my way to the coast.",
		"No.",
	]), PORTRAIT)
	ask_long.call()
	await process_frame
	box.advance()
	for i in 14:
		await process_frame
	var look: OmniDialogTheme = box.get_dialog_theme()
	var sizes := box._option_nodes.map(func(b): return b.FixedFontSize)
	_check(sizes[0] == sizes[1] and sizes[1] == sizes[2] and sizes[0] >= look.option_min_font_size, "all answers share one font size, never below the minimum")
	_check(box._option_nodes.all(func(b): return b.LabelAutowrap != TextServer.AUTOWRAP_OFF), "answers wrap")
	_check(box._option_nodes[0].size.y > box._option_nodes[2].size.y, "an answer too long for the minimum size gets taller")
	_check(box._option_nodes[2].size.y == look.option_height, "short answers keep the normal height")
	_check(box.panel.size == plain_size, "long answers don't resize the box")
	_check(box.options_box.modulate.a == 1.0, "answers show once they are fitted")
	box._option_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 0, "a long answer can be picked")

	# --- Timing tags and auto-advance
	done[0] = false
	box.auto_advance_delay = 0.2
	var tagged := func(): await dlg.say("Narrator", "Wait[pause=5] for it."); done[0] = true
	tagged.call()
	await process_frame
	box.advance()
	await process_frame
	_check(box.body.Text == "Wait for it.", "timing tags never show in the box")
	await create_timer(0.4).timeout
	_check(done[0], "auto_advance_delay moves on by itself")
	box.auto_advance_delay = 0.0

	# --- Closing from code ends the line
	result[0] = null
	ask.call()
	await process_frame
	box.close()
	await process_frame
	await process_frame
	_check(result[0] == -1 and not box.is_busy(), "closing from code ends the line with -1")

	# --- Typing sound
	box.typing_sound = AudioStreamWAV.new()
	box.characters_per_second = 400.0
	done[0] = false
	say_one.call()
	await create_timer(0.3).timeout
	_check(box._sound_player != null, "typing sound plays while text appears")
	box.advance()
	await process_frame
	await process_frame
	box.typing_sound = null

	# --- Player text speed
	box.characters_per_second = 20.0
	OmniTextWindow.text_speed_scale = 2.0
	done[0] = false
	say_one.call()
	await process_frame
	_check(is_equal_approx(box.body._typewriter._cps, 40.0), "text_speed_scale 2 types twice as fast")
	box.advance(); box.advance()
	await process_frame
	await process_frame
	dlg.text_speed_scale = 0.0
	_check(OmniTextWindow.text_speed_scale == 0.0, "OmniDialog.text_speed_scale sets the shared setting")
	done[0] = false
	say_one.call()
	await process_frame
	_check(box.state == OmniTextWindow.State.WAITING and box.body.Text == "Halt! Who goes there?", "text_speed_scale 0 shows each line at once")
	box.advance()
	await process_frame
	await process_frame
	var popup: OmniPopup = dlg.get_popup()
	popup.animation_duration = 0.0
	popup.type_message = true
	var alert_done := [false]
	var run_alert := func(): await dlg.alert("Instant message"); alert_done[0] = true
	run_alert.call()
	await process_frame
	_check(not popup.message_label._tw_active and popup.message_label.Text == "Instant message", "instant text also applies to popup messages")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	popup.type_message = false
	dlg.text_speed_scale = 1.0
	box.characters_per_second = 500.0

	# --- Narration
	var nar: OmniNarration = dlg.get_narration()
	nar.animation_duration = 0.0
	done[0] = false
	var narrate := func():
		await dlg.narrate("The city of Vell.", BG)
		await dlg.narrate("Three days after the fire.")
		done[0] = true
	narrate.call()
	await process_frame
	_check(nar.is_open() and nar.background.visible and nar.background.texture == BG and nar.shade.visible, "narration shows its background")
	_check(nar.backdrop.color.a == 1.0, "narration backdrop is opaque")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	nar._on_backdrop_gui_input(click)
	await process_frame
	_check(nar.state == OmniTextWindow.State.WAITING, "clicking anywhere skips the reveal")
	nar._on_backdrop_gui_input(click)
	await process_frame
	await process_frame
	_check(nar.is_open() and nar.background.texture == BG, "a line without a background keeps the current one")
	nar.advance(); nar.advance()
	await process_frame
	await process_frame
	_check(done[0] and not nar.is_open() and nar.background.texture == null, "narration closes after the last line and clears its background")

	dlg.queue_free()
	game_button.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniDialogue validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniDialogue validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _action(name: StringName, pressed: bool) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = pressed
	return e

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
