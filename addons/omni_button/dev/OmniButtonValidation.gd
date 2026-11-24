extends SceneTree

const OmniButtonScript = preload("res://addons/omni_button/omni_button.gd")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var button = OmniButtonScript.new()
	button.size = Vector2(120, 60)
	var removed_properties := [
		"ActionMaskBits", "EnableCooldown", "EnableHoldBuildUp",
		"IconSide", "ContentAlignment", "IconVerticalAlignment", "LabelText",
		"BackgroundTexture", "BackgroundExpandMode", "BackgroundStretchMode",
		"BackgroundFlipH", "BackgroundFlipV"
	]
	var legacy_properties_present := false
	for property in removed_properties:
		if _has_property(button, property):
			legacy_properties_present = true
			break
	_check(not legacy_properties_present, "obsolete compatibility properties are absent")
	root.add_child(button)
	await process_frame

	_check(button._typewriter == null, "typewriter module remains uninitialized until requested")
	_check(button._joystick == null, "joystick module remains uninitialized until requested")
	var label_property := {"name": &"label_uppercase", "usage": PROPERTY_USAGE_EDITOR}
	button._validate_property(label_property)
	_check((int(label_property["usage"]) & PROPERTY_USAGE_EDITOR) == 0, "label-only Inspector property is hidden when text is disabled")
	button.label_type = button.LabelKind.LABEL
	label_property["usage"] = PROPERTY_USAGE_EDITOR
	button._validate_property(label_property)
	_check((int(label_property["usage"]) & PROPERTY_USAGE_EDITOR) != 0, "label-only Inspector property is visible for plain labels")
	var rich_text_property := {"name": &"rich_label_use_bbcode", "usage": PROPERTY_USAGE_EDITOR}
	button._validate_property(rich_text_property)
	_check((int(rich_text_property["usage"]) & PROPERTY_USAGE_EDITOR) == 0, "rich-text Inspector property is hidden for plain labels")
	button.label_type = button.LabelKind.RICH_TEXT_LABEL
	rich_text_property["usage"] = PROPERTY_USAGE_EDITOR
	button._validate_property(rich_text_property)
	_check((int(rich_text_property["usage"]) & PROPERTY_USAGE_EDITOR) != 0, "rich-text Inspector property is visible for rich labels")
	# scenes saved before the snake_case rename still load their values
	button.set(&"HoldDuration", 2.5)
	button.set(&"RichLabelUseBBCode", true)
	button.set(&"IconFlipH", true)
	_check(is_equal_approx(button.hold_duration, 2.5) and button.rich_label_use_bbcode and button.icon_flip_h, "old PascalCase setting names map onto the snake_case ones")
	var fb = OmniButtonScript.new()
	var feature_hidden := not _shown(fb, &"cooldown_duration") and not _shown(fb, &"swipe_threshold") 		and not _shown(fb, &"hold_fill_color") and not _shown(fb, &"icon_modulate") 		and not _shown(fb, &"joystick_deadzone") and not _shown(fb, &"clamp_to_bounds") and not _shown(fb, &"hover_lerp_speed")
	_check(feature_hidden, "feature settings are hidden while their feature is off")
	fb.cooldown_trigger = fb.CooldownTrigger.ON_PRESS
	fb.enable_swipe_actions = true
	fb.hold_duration = 0.5
	fb.follow_mode = fb.FollowMode.FOLLOW_BOTH
	_check(_shown(fb, &"clamp_to_bounds") and not _shown(fb, &"joystick_deadzone"), "drag mode shows its clamp setting but not the joystick settings")
	_check(_shown(fb, &"bounds_source") and _shown(fb, &"hit_slop"), "hit-test bounds stay visible for every mode")
	fb.enable_virtual_joystick = true
	_check(fb.follow_mode == fb.FollowMode.VIRTUAL_JOYSTICK, "enable_virtual_joystick still switches follow_mode to VirtualJoystick")
	var evj_listed := false
	for prop in fb.get_property_list():
		if prop["name"] == "enable_virtual_joystick" and (int(prop["usage"]) & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)) != 0:
			evj_listed = true
	_check(not evj_listed, "enable_virtual_joystick is not shown or saved; follow_mode is the switch")
	fb.hover_scale = 1.2
	fb.enable_default_thumb = false # on by default
	var feature_shown := _shown(fb, &"cooldown_duration") and _shown(fb, &"swipe_threshold") 		and _shown(fb, &"hold_fill_color") and _shown(fb, &"joystick_deadzone") and _shown(fb, &"clamp_to_bounds") 		and _shown(fb, &"hover_lerp_speed") and _shown(fb, &"allow_hold_during_cooldown") and _shown(fb, &"suspend_hover_scale_during_cooldown")
	_check(feature_shown, "feature settings appear once their feature is on")
	_check(not _shown(fb, &"cooldown_invert_duration") and not _shown(fb, &"joystick_area_color") and not _shown(fb, &"default_thumb_color"), "nested feature settings stay hidden until their sub-switch is on")
	fb.invert_on_cooldown = true
	fb.enable_joystick_area = true
	fb.enable_default_thumb = true
	_check(_shown(fb, &"cooldown_invert_duration") and _shown(fb, &"joystick_area_color") and _shown(fb, &"default_thumb_color"), "nested feature settings appear with their sub-switch")
	var stored := {"name": &"cooldown_duration", "usage": PROPERTY_USAGE_DEFAULT}
	fb.cooldown_trigger = fb.CooldownTrigger.NONE
	fb._validate_property(stored)
	_check((int(stored["usage"]) & PROPERTY_USAGE_STORAGE) != 0, "hidden feature settings are still saved")
	var accessor_errors := 0
	for key in [&"label", &"icon", &"background", &"panel", &"overlay", &"cooldown", &"charge_up"]:
		var acc: Object = fb.get(key)
		for prop in acc.get_property_list():
			if (int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE) == 0 or str(prop["name"]).begins_with("_"):
				continue
			if prop["type"] == TYPE_NIL:
				accessor_errors += 1
			acc.set(prop["name"], acc.get(prop["name"]))
	_check(accessor_errors == 0, "every scripting accessor property is typed and round-trips")
	fb.free()
	button.label_type = button.LabelKind.NONE
	await process_frame

	var counts := {"pressed": 0, "released": 0, "held": 0, "typed": 0}
	button.pressed.connect(func(): counts["pressed"] += 1)
	button.released.connect(func(): counts["released"] += 1)
	button.hold.connect(func(): counts["held"] += 1)
	button.typewriter_completed.connect(func(): counts["typed"] += 1)

	button.enable_pressed_actions = true
	button.enable_released_actions = true
	_send_mouse(button, true)
	_check(button.is_pressed, "mouse press enters pressed state")
	_check(counts["pressed"] == 1, "mouse press emits pressed")
	_send_mouse(button, false)
	_check(not button.is_pressed, "mouse release clears pressed state")
	_check(counts["released"] == 1, "mouse release emits released")

	var swipe_counts := {"swipe": 0, "ended": 0}
	button.swipe.connect(func(_dir): swipe_counts["swipe"] += 1)
	button.swipe_ended.connect(func(): swipe_counts["ended"] += 1)
	button.enable_swipe_actions = true
	_send_mouse(button, true)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(80, 10)
	drag.global_position = button.global_position + drag.position
	button._gui_input(drag)
	_check(swipe_counts["swipe"] == 1, "mouse drag past the threshold emits swipe")
	_send_mouse(button, false)
	_check(swipe_counts["ended"] == 1, "mouse release emits swipe_ended when mouse_swipe_exit is OnReleased")
	_send_mouse(button, true)
	_send_mouse(button, false)
	_check(swipe_counts["ended"] == 1, "press and release without a swipe does not emit swipe_ended")
	button.enable_swipe_actions = false
	_send_mouse(button, true)
	button._gui_input(drag)
	_send_mouse(button, false)
	_check(swipe_counts["swipe"] == 1 and swipe_counts["ended"] == 1, "swipe signals stay silent when swipe actions are disabled")
	counts["pressed"] -= 3
	counts["released"] -= 3

	var input_action := &"omni_button_validation_activate"
	InputMap.add_action(input_action)
	var input_key := InputEventKey.new()
	input_key.keycode = KEY_K
	InputMap.action_add_event(input_action, input_key)
	var input_gamepad_button := InputEventJoypadButton.new()
	input_gamepad_button.button_index = JOY_BUTTON_A
	InputMap.action_add_event(input_action, input_gamepad_button)
	button.activation_action = input_action
	button.focus_mode = Control.FOCUS_ALL
	var action_press := InputEventKey.new()
	action_press.keycode = KEY_K
	action_press.pressed = true
	button._gui_input(action_press)
	_check(not button.is_pressed, "focused input action does not activate an unfocused button")
	button.grab_focus()
	await process_frame
	button._gui_input(action_press)
	_check(button.is_pressed and counts["pressed"] == 2, "focused InputMap action enters the normal pressed state")
	var action_release := InputEventKey.new()
	action_release.keycode = KEY_K
	action_release.pressed = false
	button._gui_input(action_release)
	_check(not button.is_pressed and counts["released"] == 2, "focused InputMap action releases through normal button behavior")
	var gamepad_press := InputEventJoypadButton.new()
	gamepad_press.button_index = JOY_BUTTON_A
	gamepad_press.pressed = true
	button._unhandled_input(gamepad_press)
	_check(button.is_pressed and counts["pressed"] == 3, "focused InputMap action accepts gamepad buttons")
	var gamepad_release := InputEventJoypadButton.new()
	gamepad_release.button_index = JOY_BUTTON_A
	gamepad_release.pressed = false
	button._unhandled_input(gamepad_release)
	_check(not button.is_pressed and counts["released"] == 3, "gamepad action releases through normal button behavior")
	button.release_focus()
	InputMap.erase_action(input_action)

	button.interaction_mode = button.InteractionMode.TOGGLE_ON_RELEASE
	button.cooldown_trigger = button.CooldownTrigger.ON_RELEASE
	button.cooldown_duration = 0.1
	_send_mouse(button, false)
	_check(not button.is_toggled, "unmatched mouse release does not toggle")
	_check(not button._cooldown_active, "unmatched mouse release does not start cooldown")
	_check(counts["released"] == 3, "unmatched mouse release does not emit released")

	_send_mouse(button, true)
	_send_mouse(button, false)
	_check(button.is_toggled, "matched release toggles in ToggleOnRelease mode")
	_check(button._cooldown_active, "matched release starts cooldown")
	await create_timer(0.15).timeout
	_check(not button._cooldown_active, "cooldown expires")
	button.interaction_mode = button.InteractionMode.MOMENTARY

	button.disabled = true
	_send_mouse(button, true)
	_check(not button.is_pressed, "disabled button ignores mouse press")
	button.disabled = false
	_send_mouse(button, true)
	button.visible = false
	_check(not button.is_pressed, "hiding a pressed button clears its press state")
	_check(button._pointer_gesture_source == button.PointerGestureSource.NONE, "hiding a pressed button releases pointer ownership")
	button.visible = true
	button.cooldown_trigger = button.CooldownTrigger.NONE

	button.hold_duration = 0.05
	button.enable_hold_actions = true
	button.invert_modes = button.INVERT_HOLD
	button.icon_texture = load("res://addons/omni_button/demo/icons/Icon-Potion6.png")
	await process_frame
	await process_frame
	_check(is_instance_valid(button._icon), "hold inversion test icon is created")
	if is_instance_valid(button._icon):
		_check(button._icon.material == null, "hold inversion stays off during hold build-up")
	_send_mouse(button, true)
	await create_timer(0.1).timeout
	_check(button.is_holding, "hold duration enters holding state")
	_check(counts["held"] == 1, "hold action emits once")
	await process_frame
	if is_instance_valid(button._icon):
		_check(button._icon.material == button._invert_material, "hold inversion activates when build-up completes")
	_send_mouse(button, false)
	await process_frame
	if is_instance_valid(button._icon):
		_check(button._icon.material == null, "hold inversion clears when the button is released")

	button.label_type = button.LabelKind.LABEL
	button.start_typewriter("ABC", 1000.0)
	_check(button._typewriter != null, "first typewriter request initializes its module")
	await create_timer(0.1).timeout
	_check(button.text == "ABC", "typewriter completes and preserves final text")
	_check(counts["typed"] == 1, "typewriter completion emits once")

	button.start_typewriter("A long typewriter message should keep its prefit size", 60.0)
	var prefit_size: int = button._label.get_theme_font_size("font_size")
	await create_timer(0.05).timeout
	_check(button._label.visible_characters > 0 and button._label.visible_characters < button._typewriter.full_text.length(), "typewriter reveals text incrementally")
	_check(button._label.get_theme_font_size("font_size") == prefit_size, "typewriter keeps the final-text font size while revealing characters")
	await create_timer(1.0).timeout
	_check(not button._tw_active, "long typewriter finishes after revealing the full text")

	# the typewriter keeps a fixed font size instead of refitting for the new text.
	button.fixed_font_size = 13
	await process_frame
	button.start_typewriter("A much longer line of text than before", 1000.0)
	_check(button._label.get_theme_font_size("font_size") == 13, "typewriter keeps fixed_font_size")
	button.skip_typewriter()
	button.fixed_font_size = 0
	await process_frame

	# per character signal.
	var revealed: Array = []
	var on_char := func(index: int, character: String): revealed.append([index, character])
	button.typewriter_char_revealed.connect(on_char)
	button.start_typewriter("Hi!", 1000.0)
	await create_timer(0.1).timeout
	_check(revealed == [[0, "H"], [1, "i"], [2, "!"]], "typewriter_char_revealed emits each character once, in order")
	revealed.clear()
	button.start_typewriter("Skip me", 2.0)
	await create_timer(0.1).timeout
	button.skip_typewriter()
	await process_frame
	_check(revealed.size() <= 1, "skipping does not emit the characters it skipped past")
	button.typewriter_char_revealed.disconnect(on_char)

	# [pause] holds the reveal and never shows up on the label.
	button.start_typewriter("A[pause=0.4]B", 1000.0)
	_check(button._label.text == "AB", "timing tags are removed before the text reaches the label")
	await create_timer(0.15).timeout
	_check(button._tw_active and button._label.visible_characters == 1, "[pause] holds the reveal after the preceding character")
	await create_timer(0.5).timeout
	_check(not button._tw_active and button.text == "AB", "reveal continues after [pause] and commits clean text")

	# [speed] changes the rate from where it is, [/speed] goes back to the starting speed.
	button.start_typewriter("[speed=1000]ABCDEF[/speed]GH", 1.0)
	await create_timer(0.2).timeout
	_check(button._label.visible_characters >= 6 and button._label.visible_characters < 8, "[speed] reveals fast until [/speed] returns to the start speed")
	button.skip_typewriter()
	_check(button.text == "ABCDEFGH", "skipping commits the text without timing tags")

	# skipping during a pause finishes right away.
	button.start_typewriter("Wait[pause=5] here", 1000.0)
	await create_timer(0.1).timeout
	button.skip_typewriter()
	_check(not button._tw_active and button.text == "Wait here", "skipping during [pause] completes the reveal")

	# bbcode mode: timing positions ignore formatting tags.
	button.rich_label_use_bbcode = true
	button.start_typewriter("[b]Hi[/b][pause=0.4] there", 1000.0, false, true)
	_check(button._rich_label != null and not button._rich_label.text.contains("pause"), "timing tags are removed from rich text")
	await create_timer(0.15).timeout
	_check(button._tw_active and button._rich_label.visible_characters == 2, "[pause] position skips BBCode tags")
	button.skip_typewriter()
	button.label_type = button.LabelKind.LABEL

	# containers: OmniButton doesn't report a minimum size of its own, so containers need custom_minimum_size.
	var box := VBoxContainer.new()
	box.size = Vector2(200, 300)
	root.add_child(box)
	var boxed = OmniButtonScript.new()
	boxed.custom_minimum_size = Vector2(0, 40)
	boxed.text = "Option"
	box.add_child(boxed)
	await process_frame
	await process_frame
	_check(boxed.size.y >= 40.0 and boxed.size.x >= 199.0, "OmniButton in a VBoxContainer takes its custom minimum height and the full width")
	_check(boxed._label != null and boxed._label.size.y > 0.0, "label is laid out inside a container-sized button")

	# focus: keyboard/gamepad activation and focus styling.
	var focus_style := StyleBoxFlat.new()
	boxed.background_type = boxed.BackgroundMode.USE_PANEL
	boxed.panel_focus_style_box = focus_style
	boxed.focus_mode = Control.FOCUS_ALL
	boxed.enable_pressed_actions = true
	var focus_presses := [0]
	boxed.pressed.connect(func(): focus_presses[0] += 1)
	boxed.grab_focus()
	await process_frame
	_check(boxed.has_focus() and OmniButtonVisuals._active_panel_style(boxed) == focus_style, "focused button uses panel_focus_style_box")
	var accept := InputEventAction.new()
	accept.action = &"ui_accept"
	accept.pressed = true
	boxed._unhandled_input(accept)
	_check(focus_presses[0] == 1, "focused button activates on ui_accept")
	var accept_up := InputEventAction.new()
	accept_up.action = &"ui_accept"
	accept_up.pressed = false
	boxed._unhandled_input(accept_up)
	box.queue_free()
	await process_frame

	button.label_type = button.LabelKind.RICH_TEXT_LABEL
	button.text_to_type = "[b]Rich[/b] text"
	_check(button.rich_label_use_bbcode, "BBCode is enabled by default for rich labels")
	button.start_typewriter_from_text_to_type(30.0, false, true)
	await create_timer(0.1).timeout
	_check(button._rich_label.bbcode_enabled, "RichTextLabel receives the BBCode setting")
	_check(button._tw_active and button._rich_label.get_parsed_text() != "", "BBCode typewriter incrementally reveals parsed rich text")
	_check(not button._rich_label.has_theme_font_override("bold_font") and not button._rich_label.has_theme_font_override("italics_font"), "rich text autosizing preserves bold and italic style fonts")
	await create_timer(1.0).timeout
	_check(not button._tw_active and button._rich_label.get_parsed_text() == "Rich text", "BBCode typewriter completes with formatting parsed and tags stripped from output")
	button.rich_label_use_bbcode = false
	await process_frame
	await process_frame
	_check(not button._rich_label.bbcode_enabled, "disabling BBCode updates the live RichTextLabel")
	button.rich_label_use_bbcode = true
	await process_frame
	await process_frame
	_check(button._rich_label.bbcode_enabled and button._rich_label.get_parsed_text() == "Rich text", "re-enabling BBCode restores parsed rich text")
	button.text = "[b]Raw[/b]"
	button.rich_label_use_bbcode = false
	await process_frame
	await process_frame
	_check(button._rich_label.get_parsed_text() == "[b]Raw[/b]", "BBCode-disabled rich labels display tags literally")
	button.rich_label_use_bbcode = true
	await process_frame
	await process_frame
	_check(button._rich_label.get_parsed_text() == "Raw", "BBCode-enabled rich labels parse formatting tags")

	button.label_type = button.LabelKind.LABEL
	button.text_to_type = "[b]Promoted[/b] to rich text"
	button.rich_label_use_bbcode = true
	button.start_typewriter_from_text_to_type(1000.0, false, true)
	_check(button.label_type == button.LabelKind.RICH_TEXT_LABEL, "preserving BBCode selects a RichTextLabel when the current type cannot parse it")
	await create_timer(0.1).timeout
	_check(button._rich_label.get_parsed_text() == "Promoted to rich text", "preserve-BBCode typewriter keeps and renders tags from a plain-label starting state")

	button.is_holding = true
	button.hold_duration = 0.0
	_check(not button.is_holding and button._hold_timer == 0.0, "disabling hold duration clears the holding state and timer")
	button.is_pressed = true
	for _frame in range(6):
		await process_frame
	_check(not button.is_processing(), "idle held button stops per-frame processing")

	button.is_pressed = false
	button.hold_duration = 0.05
	button.is_holding = false
	button.is_pressed = true
	_check(button.is_processing(), "active hold build-up keeps per-frame processing")
	button.is_pressed = false

	button.enable_joystick_area = true
	button.joystick_area_external_path = NodePath("Missing/JoystickArea")
	button._ensure_joystick().ensure_and_refresh_joystick_area(button.global_position + button.size * 0.5)
	_check(button._joystick != null, "first joystick request initializes its module")
	_check(is_instance_valid(button._vj_area_panel), "missing external joystick area falls back to a managed area")
	var temporary_bounds := Control.new()
	button.bounds_source = temporary_bounds
	temporary_bounds.free()
	_check(button._ensure_joystick().get_follow_clamp_rect().size == button.get_viewport_rect().size, "freed bounds source falls back to viewport bounds")

	button.queue_free()
	await process_frame

	# handlers connected before entering the tree (like the .tscn connections the editor makes) run
	# once, and an action set before entering the tree gets kept and called once.
	var early := {"signal": 0, "action": 0, "log": 0}
	var early_button = OmniButtonScript.new()
	early_button.size = Vector2(100, 50)
	early_button.pressed.connect(func(): early["signal"] += 1)
	early_button.released_action = func(): early["action"] += 1
	early_button.log_action = func(_m): early["log"] += 1
	root.add_child(early_button)
	await process_frame
	early_button.enable_pressed_actions = true
	early_button.enable_released_actions = true
	_send_mouse(early_button, true)
	_send_mouse(early_button, false)
	_check(early["signal"] == 1, "handler connected before entering the tree runs once per press")
	_check(early["action"] == 1, "Action assigned before entering the tree is kept and runs once")
	early_button.print_log("hello")
	_check(early["log"] == 1, "print_log runs log_action once")
	var connection_count := 0
	for s in early_button.get_signal_list():
		for c in early_button.get_signal_connection_list(s["name"]):
			if (c["callable"] as Callable).get_object() == early_button:
				connection_count += 1
	_check(connection_count == 0, "button makes no signal connections to itself")
	early_button.queue_free()
	await process_frame

	# scene load order: icon_texture set before ready queues a child rebuild that replaces the Label.
	var fit_button = OmniButtonScript.new()
	fit_button.size = Vector2(100, 50)
	fit_button.icon_texture = load("res://addons/omni_button/demo/icons/Icon-Potion6.png")
	fit_button.text = "Press then Swipe Button"
	fit_button.background_type = fit_button.BackgroundMode.USE_PANEL
	fit_button.selected = true
	root.add_child(fit_button)
	for _frame in range(8):
		await process_frame
	_check(fit_button._label.has_theme_font_size_override("font_size"), "plain label is autosized after the scene-load child rebuild")
	_check(fit_button._label.get_combined_minimum_size().x <= fit_button.size.x, "autosized plain label does not overflow the button width")
	var all_ignore := true
	for child in fit_button._managed_root.get_children():
		if child is Control and (child as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			all_ignore = false
	_check(all_ignore and fit_button._managed_root.mouse_filter == Control.MOUSE_FILTER_IGNORE, "generated visuals ignore the mouse so input matches the button rect")
	fit_button.queue_free()
	await process_frame

	var stress_buttons: Array[Control] = []
	var setup_started := Time.get_ticks_usec()
	for _index in range(500):
		var stress_button = OmniButtonScript.new()
		stress_button.size = Vector2(32, 32)
		root.add_child(stress_button)
		stress_buttons.append(stress_button)
	var setup_elapsed_ms := float(Time.get_ticks_usec() - setup_started) / 1000.0
	for _frame in range(6):
		await process_frame
	var processing_count := 0
	for stress_button in stress_buttons:
		if stress_button.is_processing():
			processing_count += 1
	_check(processing_count == 0, "500 settled idle buttons disable per-frame processing")
	print("OmniButton stress: 500 controls created in %.2f ms; %d still process after settling." % [setup_elapsed_ms, processing_count])
	for stress_button in stress_buttons:
		stress_button.queue_free()
	await process_frame

	var demo_scene := load("res://addons/omni_button/demo/omni_button_demo.tscn") as PackedScene
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	await create_timer(0.2).timeout
	var demo_text := demo.get_node("%TextBlock") as OmniButton
	_check(demo_text._tw_active, "demo starts its configured typewriter")
	_check(is_instance_valid(demo_text._rich_label) and not demo_text._rich_label.text.is_empty(), "demo visibly reveals rich text")
	if is_instance_valid(demo_text._rich_label):
		_check(demo_text._rich_label.visible_characters >= 0 and demo_text._rich_label.visible_characters < demo_text._rich_label.get_parsed_text().length(), "demo typewriter has not completed immediately")
	demo_text.queue_refresh(true, false, false)
	await process_frame
	_check(demo_text._tw_active and is_instance_valid(demo_text._rich_label) and not demo_text._rich_label.text.is_empty(), "visual refresh preserves active typewriter output")
	demo_text.skip_typewriter()
	await process_frame
	await process_frame
	_check(not demo_text._tw_active and demo_text._rich_label.text == demo_text.text_to_type, "demo typewriter completes with the full rich text")
	_check(demo_text._rich_label.get_content_height() <= demo_text.size.y, "rich text autosizing fits the complete typewriter message in its block")
	demo.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniButton validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniButton validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _send_mouse(button: Control, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.position = Vector2(10, 10)
	event.global_position = button.global_position + event.position
	button._gui_input(event)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)

func _has_property(object: Object, property_name: String) -> bool:
	for property in object.get_property_list():
		if property["name"] == property_name:
			return true
	return false

func _shown(b, prop: StringName) -> bool:
	var info := {"name": prop, "usage": PROPERTY_USAGE_DEFAULT}
	b._validate_property(info)
	return (int(info["usage"]) & PROPERTY_USAGE_EDITOR) != 0
