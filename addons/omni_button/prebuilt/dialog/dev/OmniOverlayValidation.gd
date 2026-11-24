extends SceneTree
# checks the dialog system's base overlay and option button scenes.
# usage: godot --headless --path . -s res://addons/omni_button/prebuilt/dialog/dev/OmniOverlayValidation.gd

const OverlayScene := preload("res://addons/omni_button/prebuilt/dialog/core/overlay/omni_overlay.tscn")
const OptionScene := preload("res://addons/omni_button/prebuilt/dialog/parts/omni_option_button.tscn")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	# a control standing in for the game's own ui.
	var game_ui := Control.new()
	game_ui.size = Vector2(800, 600)
	root.add_child(game_ui)
	var game_button := Button.new()
	game_button.focus_mode = Control.FOCUS_ALL
	game_button.size = Vector2(100, 40)
	game_ui.add_child(game_button)
	game_button.grab_focus()

	# --- option button scene
	var opt = OptionScene.instantiate()
	_check(opt.focus_mode == Control.FOCUS_ALL, "option button is focusable")
	_check(opt.custom_minimum_size.y > 0.0, "option button has a minimum height for containers")
	_check(opt.enable_pressed_actions, "option button emits pressed")
	_check(opt.background_type == opt.BackgroundMode.USE_PANEL and opt.panel_focus_style_box != null, "option button has panel and focus styles")
	opt.free()

	# --- overlay basics
	var a: OmniOverlay = OverlayScene.instantiate()
	a.animation_duration = 0.05
	root.add_child(a)
	var a_box := VBoxContainer.new()
	a.content.add_child(a_box)
	var a1 = OptionScene.instantiate(); a1.text = "First"; a_box.add_child(a1)
	var a2 = OptionScene.instantiate(); a2.text = "Second"; a_box.add_child(a2)
	await process_frame
	_check(not a.visible and not a.is_open(), "overlay starts hidden and closed")

	var events: Array[String] = []
	for sig in ["opening", "opened", "closing", "closed", "canceled"]:
		a.connect(sig, func(): events.append(sig))
	await a.open()
	_check(a.visible and a.is_open() and a.is_top(), "open shows the overlay and puts it on top")
	_check(events == ["opening", "opened"], "open emits opening then opened")
	_check(root.gui_get_focus_owner() == a1, "open focuses the first focusable control")
	_check(a1.focus_next == a1.get_path_to(a2) and a2.focus_next == a2.get_path_to(a1), "Tab order loops inside the overlay")
	_check(a.backdrop.visible and a.backdrop.mouse_filter == Control.MOUSE_FILTER_STOP, "backdrop shows and blocks clicks")
	_check(a.root_control.modulate.a == 1.0 and a.panel.scale == Vector2.ONE, "visuals settle after the open animation")

	# focus trap
	a2.grab_focus()
	game_button.grab_focus()
	await process_frame
	await process_frame
	_check(root.gui_get_focus_owner() == a2, "focus that leaves the overlay is pulled back to the last focused control")

	# cancel action
	events.clear()
	var cancel := InputEventAction.new()
	cancel.action = &"ui_cancel"
	cancel.pressed = true
	root.push_input(cancel)
	await create_timer(0.15).timeout
	_check(events == ["canceled", "closing", "closed"], "ui_cancel emits canceled and closes")
	_check(not a.visible and not a.is_open(), "closed overlay is hidden")
	_check(root.gui_get_focus_owner() == game_button, "closing gives focus back to the control focused before opening")

	# close_on_cancel off: canceled still fires, overlay stays
	a.close_on_cancel = false
	await a.open()
	events.clear()
	a.cancel()
	_check(events == ["canceled"] and a.is_open(), "close_on_cancel off keeps the overlay open")
	a.close_on_cancel = true
	await a.close()

	# backdrop click
	a.close_on_backdrop_click = true
	await a.open()
	events.clear()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	a._on_backdrop_gui_input(click)
	await create_timer(0.15).timeout
	_check(events.has("canceled") and not a.is_open(), "backdrop click cancels when enabled")
	a.close_on_backdrop_click = false

	# no backdrop
	a.show_backdrop = false
	_check(not a.backdrop.visible and a.backdrop.mouse_filter == Control.MOUSE_FILTER_IGNORE, "backdrop off lets clicks through")
	a.show_backdrop = true

	# pausing
	a.pause_tree = true
	await a.open()
	_check(paused, "pause_tree pauses the game while open")
	_check(a.process_mode == Node.PROCESS_MODE_ALWAYS, "overlay keeps processing while the game is paused")
	await a.close()
	_check(not paused, "closing restores the previous pause state")
	a.pause_tree = false

	# interrupting: closing during the open animation can't leave either call hanging.
	a.animation_duration = 0.3
	var done := [false, false]
	var open_call := func(): await a.open(); done[0] = true
	var close_call := func(): await a.close(); done[1] = true
	open_call.call()
	await process_frame
	close_call.call()
	await create_timer(0.5).timeout
	_check(done[0] and done[1], "open and close both return when close interrupts the open animation")
	_check(not a.visible and a.root_control.modulate.a == 1.0, "interrupted overlay ends hidden with visuals reset")

	# a slide puts the panel back where it was.
	a.open_animation = OmniOverlay.OverlayAnimation.SLIDE_UP
	a.close_animation = OmniOverlay.OverlayAnimation.SLIDE_DOWN
	a.animation_duration = 0.05
	await a.open()
	var rest := a.panel.position
	await a.close()
	await a.open()
	_check(a.panel.position == rest, "slide animations return the panel to its resting position")
	var open_call2 := func(): await a.close()
	open_call2.call()
	await process_frame
	a.open() # reopen mid slide
	await create_timer(0.2).timeout
	_check(a.is_open() and a.panel.position == rest, "reopening mid-slide keeps the resting position")

	# --- stacking
	var b: OmniOverlay = OverlayScene.instantiate()
	b.animation_duration = 0.0
	b.layer = 11
	root.add_child(b)
	var b1 = OptionScene.instantiate(); b1.text = "OK"; b.content.add_child(b1)
	await process_frame
	a2.grab_focus()
	await b.open()
	_check(b.is_top() and not a.is_top(), "the newest overlay is on top")
	_check(root.gui_get_focus_owner() == b1, "the top overlay takes focus")
	var a_canceled := [0]
	a.canceled.connect(func(): a_canceled[0] += 1)
	root.push_input(cancel)
	await process_frame
	_check(not b.is_open() and a.is_open() and a_canceled[0] == 0, "cancel only closes the top overlay")
	_check(root.gui_get_focus_owner() == a2, "closing the top overlay gives focus back to the one underneath")

	# freeing an open overlay cleans up
	await b.open()
	b.queue_free()
	await process_frame
	_check(a.is_top(), "freeing an open overlay removes it from the stack")

	# scaling to the game's resolution (the game's base size, from the stretch settings)
	var old_base := root.content_scale_size
	root.content_scale_size = Vector2i(576, 324)
	await process_frame
	_check(is_equal_approx(a.get_screen_scale(), 0.5), "a half-size screen scales the window by 0.5")
	_check(a.root_control.size.is_equal_approx(Vector2(1152, 648)), "the root covers the screen in reference-size pixels")
	root.content_scale_size = Vector2i(320, 240)
	await process_frame
	_check(is_equal_approx(a.get_screen_scale(), 320.0 / 1152.0) and a.root_control.size.is_equal_approx(Vector2(1152, 864)),
		"a different aspect ratio scales by the tighter side and the root still covers the screen")
	a.fit_to_screen = false
	_check(a.get_screen_scale() == 1.0 and a.root_control.size.is_equal_approx(Vector2(320, 240)), "fit_to_screen off lays out in the game's own pixels")
	a.fit_to_screen = true
	root.content_scale_size = old_base
	await process_frame
	_check(is_equal_approx(a.get_screen_scale(), 1.0), "the window rescales when the screen size changes back")

	a.queue_free()
	game_ui.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniOverlay validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniOverlay validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
