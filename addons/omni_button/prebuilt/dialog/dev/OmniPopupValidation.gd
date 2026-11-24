extends SceneTree
# Checks the OmniDialog autoload with the prebuilt popup and toast scenes.
# Usage: godot --headless --path . -s res://addons/omni_button/prebuilt/dialog/dev/OmniPopupValidation.gd

const DialogScript := preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")

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

	_check(DialogScript.scene_path("popup_scene").ends_with("omni_popup.tscn"), "popup scene defaults to the prebuilt one")
	var popup: OmniPopup = dlg.get_popup()
	_check(popup != null and dlg.get_popup() == popup, "popup is created once and reused")
	popup.animation_duration = 0.0

	# confirm: Yes
	var result := [null]
	var run := func(c: Callable): result[0] = await c.call()
	run.call(func(): return await dlg.confirm("Quit?", "Leaving"))
	await process_frame
	_check(popup.is_open() and popup.title_label.text == "Leaving" and popup.title_label.visible, "confirm opens the popup with its title")
	_check(popup._button_nodes.size() == 2 and popup.button_row.visible and not popup.button_column.visible, "confirm shows two buttons in a row")
	_check(popup._button_nodes[0].Text == "Yes" and popup._button_nodes[1].Text == "No", "confirm buttons default to Yes / No")
	_check(root.gui_get_focus_owner() == popup._button_nodes[0], "the default button has focus")
	var picked := []
	popup.button_pressed.connect(func(i, t): picked.append([i, t]))
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == true and not popup.is_open(), "pressing Yes returns true and closes")
	_check(picked == [[0, "Yes"]], "button_pressed reports index and text")
	_check(root.gui_get_focus_owner() == game_button, "focus returns to the game after the popup closes")

	# The message is an Omni_Button; long text shrinks to fit, and it can type out.
	_check(popup.message_label is Omni_Button, "popup message is an Omni_Button")
	popup.type_message = true
	popup.message_speed = 10.0
	result[0] = null
	run.call(func(): return await dlg.alert("A message typed out slowly enough to check."))
	await process_frame
	_check(popup.message_label._tw_active, "type_message types the message out")
	_check(root.gui_get_focus_owner() == popup._button_nodes[0], "the button keeps focus while the message types")
	popup.message_label.skip_typewriter()
	_check(popup.message_label.Text == "A message typed out slowly enough to check.", "skipping shows the whole message")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	popup.type_message = false
	run.call(func(): return await dlg.alert("Shown at once"))
	await process_frame
	_check(not popup.message_label._tw_active and popup.message_label.Text == "Shown at once", "without type_message the message shows at once")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame

	# confirm: cancel counts as No
	result[0] = null
	run.call(func(): return await dlg.confirm("Quit?"))
	await process_frame
	_check(not popup.title_label.visible, "an empty title is hidden")
	root.push_input(_action(&"ui_cancel"))
	await process_frame
	await process_frame
	_check(result[0] == false, "canceling a confirm returns false")

	# choose: more than two options stack vertically
	result[0] = null
	run.call(func(): return await dlg.choose("Pick a class", PackedStringArray(["Warrior", "Mage", "Rogue"])))
	await process_frame
	_check(popup.button_column.visible and not popup.button_row.visible and popup.button_column.get_child_count() == 3, "three options stack vertically")
	_check(popup.button_row.get_child_count() == 0, "buttons from the previous question are removed")
	popup._button_nodes[2].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 2, "choose returns the index picked")
	result[0] = null
	run.call(func(): return await dlg.choose("Pick", PackedStringArray(["A", "B", "C"])))
	await process_frame
	popup.cancel()
	await process_frame
	await process_frame
	_check(result[0] == -1, "canceling a choice returns -1")

	# alert
	result[0] = "pending"
	run.call(func(): await dlg.alert("Saved."); return "done")
	await process_frame
	_check(popup._button_nodes.size() == 1 and popup._button_nodes[0].Text == "OK", "alert shows one OK button")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == "done", "alert returns after it is acknowledged")

	# Queue: a second question waits for the first.
	var first := [null]
	var second := [null]
	var ask_first := func(): first[0] = await dlg.choose("First", PackedStringArray(["a", "b"]))
	var ask_second := func(): second[0] = await dlg.choose("Second", PackedStringArray(["c", "d"]))
	ask_first.call()
	ask_second.call()
	await process_frame
	_check(popup.message_label.Text == "First" and popup.is_busy(), "the first question shows first")
	popup._button_nodes[1].pressed.emit()
	await process_frame
	await process_frame
	await process_frame
	_check(first[0] == 1 and popup.message_label.Text == "Second" and popup.is_open(), "the queued question shows after the first is answered")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	_check(second[0] == 0 and not popup.is_busy(), "the queued question returns its own answer")

	# Long button text shares one font size with the other buttons.
	result[0] = null
	run.call(func(): return await dlg.choose("Pick one", PackedStringArray(["A rather long answer that will not fit on one line at full size", "Short", "Medium answer"])))
	for i in 14:
		await process_frame
	var fs := popup._button_nodes.map(func(b): return b.FixedFontSize)
	_check(fs[0] == fs[1] and fs[1] == fs[2] and fs[0] > 0, "popup buttons share one font size")
	_check(popup._button_nodes.all(func(b): return b.modulate.a == 1.0), "popup buttons show once fitted")
	popup._button_nodes[1].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 1, "a fitted popup button can be picked")

	# allow_cancel off
	popup.allow_cancel = false
	result[0] = null
	run.call(func(): return await dlg.choose("Must pick", PackedStringArray(["x", "y"])))
	await process_frame
	root.push_input(_action(&"ui_cancel"))
	await process_frame
	_check(popup.is_open() and result[0] == null, "allow_cancel off ignores the cancel action")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame
	popup.allow_cancel = true

	# Closing from code still answers.
	result[0] = null
	run.call(func(): return await dlg.choose("Closed by code", PackedStringArray(["x", "y"])))
	await process_frame
	popup.close()
	await process_frame
	await process_frame
	_check(result[0] == -1 and not popup.is_busy(), "closing from code answers with cancel_index")

	# Inspector-configured popup
	popup.title = "Configured"
	popup.message = "Set up in the Inspector"
	popup.buttons = PackedStringArray(["One", "Two"])
	popup.default_button = 1
	result[0] = null
	run.call(func(): return await popup.show_configured())
	await process_frame
	_check(popup.message_label.Text == "Set up in the Inspector" and root.gui_get_focus_owner() == popup._button_nodes[1], "show_configured uses the Inspector values and default button")
	popup._button_nodes[1].pressed.emit()
	await process_frame
	await process_frame
	_check(result[0] == 1, "show_configured returns the index picked")

	# --- Toasts
	var toast: OmniToast = dlg.get_toast()
	_check(not toast.modal and not toast.show_backdrop, "toast overlay is non-modal without a backdrop")
	dlg.toast("Hello", 0.3)
	await process_frame
	_check(toast.is_open() and toast.count() == 1, "toast shows")
	var shown = toast.toast_list.get_child(toast.toast_list.get_child_count() - 1)
	_check(shown is Omni_Button and shown.Text == "Hello", "each toast is an Omni_Button showing its text")
	_check(OmniButtonVisuals._resolved_panel_style(shown) == shown.get_theme_stylebox("panel", "OmniDialogToast"), "toast panel comes from the look's OmniDialogToast style")
	_check(shown.mouse_filter == Control.MOUSE_FILTER_STOP, "toasts can be clicked when dismiss_on_click is on")
	await create_timer(0.7).timeout
	_check(toast.count() == 0 and not toast.is_open(), "toast disappears after its duration and the overlay closes")

	for i in 6:
		dlg.toast("Toast %d" % i, 5.0)
	await process_frame
	_check(toast.count() == toast.max_visible, "only max_visible toasts show at once")
	toast.clear()
	await process_frame
	_check(toast.count() == 0, "clear removes every toast")

	dlg.toast("Click me", 5.0)
	await process_frame
	var clickable = toast.toast_list.get_child(toast.toast_list.get_child_count() - 1)
	clickable.pressed.emit()
	await create_timer(0.4).timeout
	_check(toast.count() == 0 and not toast.is_open(), "clicking a toast dismisses it")
	toast.dismiss_on_click = false
	dlg.toast("Pass-through", 5.0)
	await process_frame
	var passthrough = toast.toast_list.get_child(toast.toast_list.get_child_count() - 1)
	_check(passthrough.mouse_filter == Control.MOUSE_FILTER_IGNORE, "dismiss_on_click off lets clicks through")
	toast.clear()
	toast.dismiss_on_click = true
	await process_frame

	# Toast while a popup is open: popup keeps focus and cancel.
	result[0] = null
	run.call(func(): return await dlg.confirm("Toast test"))
	await process_frame
	dlg.toast("Saved", 0.2)
	await process_frame
	_check(root.gui_get_focus_owner() == popup._button_nodes[0], "a toast does not take focus from an open popup")
	root.push_input(_action(&"ui_cancel"))
	await process_frame
	await process_frame
	_check(result[0] == false, "cancel still goes to the popup while a toast shows")

	# Toasts run while the game is paused.
	await create_timer(0.5).timeout
	paused = true
	dlg.toast("Paused", 0.2)
	await create_timer(0.6).timeout
	_check(toast.count() == 0, "toasts time out while the game is paused")
	paused = false

	dlg.queue_free()
	game_button.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniPopup validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniPopup validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _action(name: StringName) -> InputEventAction:
	var e := InputEventAction.new()
	e.action = name
	e.pressed = true
	return e

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
