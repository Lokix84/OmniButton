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
	var label_property := {"name": &"LabelUppercase", "usage": PROPERTY_USAGE_EDITOR}
	button._validate_property(label_property)
	_check((int(label_property["usage"]) & PROPERTY_USAGE_EDITOR) == 0, "label-only Inspector property is hidden when text is disabled")
	button.LabelType = button.LabelKind.Label
	label_property["usage"] = PROPERTY_USAGE_EDITOR
	button._validate_property(label_property)
	_check((int(label_property["usage"]) & PROPERTY_USAGE_EDITOR) != 0, "label-only Inspector property is visible for plain labels")
	var rich_text_property := {"name": &"RichLabelUseBBCode", "usage": PROPERTY_USAGE_EDITOR}
	button._validate_property(rich_text_property)
	_check((int(rich_text_property["usage"]) & PROPERTY_USAGE_EDITOR) == 0, "rich-text Inspector property is hidden for plain labels")
	button.LabelType = button.LabelKind.RichTextLabel
	rich_text_property["usage"] = PROPERTY_USAGE_EDITOR
	button._validate_property(rich_text_property)
	_check((int(rich_text_property["usage"]) & PROPERTY_USAGE_EDITOR) != 0, "rich-text Inspector property is visible for rich labels")
	var fb = OmniButtonScript.new()
	var feature_hidden := not _shown(fb, &"CooldownDuration") and not _shown(fb, &"SwipeThreshold") 		and not _shown(fb, &"HoldFillColor") and not _shown(fb, &"IconModulate") 		and not _shown(fb, &"JoystickDeadzone") and not _shown(fb, &"ClampToBounds") and not _shown(fb, &"HoverLerpSpeed")
	_check(feature_hidden, "feature settings are hidden while their feature is off")
	fb.CooldownTrigger = fb.CooldownTriggerEnum.OnPress
	fb.EnableSwipeActions = true
	fb.HoldDuration = 0.5
	fb.FollowMode = fb.FollowModeEnum.FollowBoth
	_check(_shown(fb, &"ClampToBounds") and not _shown(fb, &"JoystickDeadzone"), "drag mode shows its clamp setting but not the joystick settings")
	_check(_shown(fb, &"BoundsSource") and _shown(fb, &"HitSlop"), "hit-test bounds stay visible for every mode")
	fb.EnableVirtualJoystick = true
	_check(fb.FollowMode == fb.FollowModeEnum.VirtualJoystick, "EnableVirtualJoystick still switches FollowMode to VirtualJoystick")
	var evj_listed := false
	for prop in fb.get_property_list():
		if prop["name"] == "EnableVirtualJoystick" and (int(prop["usage"]) & (PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_STORAGE)) != 0:
			evj_listed = true
	_check(not evj_listed, "EnableVirtualJoystick is not shown or saved; FollowMode is the switch")
	fb.HoverScale = 1.2
	fb.EnableDefaultThumb = false # on by default
	var feature_shown := _shown(fb, &"CooldownDuration") and _shown(fb, &"SwipeThreshold") 		and _shown(fb, &"HoldFillColor") and _shown(fb, &"JoystickDeadzone") and _shown(fb, &"ClampToBounds") 		and _shown(fb, &"HoverLerpSpeed") and _shown(fb, &"AllowHoldDuringCooldown") and _shown(fb, &"SuspendHoverScaleDuringCooldown")
	_check(feature_shown, "feature settings appear once their feature is on")
	_check(not _shown(fb, &"CooldownInvertDuration") and not _shown(fb, &"JoystickAreaColor") and not _shown(fb, &"DefaultThumbColor"), "nested feature settings stay hidden until their sub-switch is on")
	fb.InvertOnCooldown = true
	fb.EnableJoystickArea = true
	fb.EnableDefaultThumb = true
	_check(_shown(fb, &"CooldownInvertDuration") and _shown(fb, &"JoystickAreaColor") and _shown(fb, &"DefaultThumbColor"), "nested feature settings appear with their sub-switch")
	var stored := {"name": &"CooldownDuration", "usage": PROPERTY_USAGE_DEFAULT}
	fb.CooldownTrigger = fb.CooldownTriggerEnum.None
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
	button.LabelType = button.LabelKind.None
	await process_frame

	var counts := {"pressed": 0, "released": 0, "held": 0, "typed": 0}
	button.pressed.connect(func(): counts["pressed"] += 1)
	button.released.connect(func(): counts["released"] += 1)
	button.hold.connect(func(): counts["held"] += 1)
	button.typewriter_completed.connect(func(): counts["typed"] += 1)

	button.EnablePressedActions = true
	button.EnableReleasedActions = true
	_send_mouse(button, true)
	_check(button.IsPressed, "mouse press enters pressed state")
	_check(counts["pressed"] == 1, "mouse press emits pressed")
	_send_mouse(button, false)
	_check(not button.IsPressed, "mouse release clears pressed state")
	_check(counts["released"] == 1, "mouse release emits released")

	var swipe_counts := {"swipe": 0, "ended": 0}
	button.swipe.connect(func(_dir): swipe_counts["swipe"] += 1)
	button.swipe_ended.connect(func(): swipe_counts["ended"] += 1)
	button.EnableSwipeActions = true
	_send_mouse(button, true)
	var drag := InputEventMouseMotion.new()
	drag.position = Vector2(80, 10)
	drag.global_position = button.global_position + drag.position
	button._gui_input(drag)
	_check(swipe_counts["swipe"] == 1, "mouse drag past the threshold emits swipe")
	_send_mouse(button, false)
	_check(swipe_counts["ended"] == 1, "mouse release emits swipe_ended when MouseSwipeExit is OnReleased")
	_send_mouse(button, true)
	_send_mouse(button, false)
	_check(swipe_counts["ended"] == 1, "press and release without a swipe does not emit swipe_ended")
	button.EnableSwipeActions = false
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
	button.ActivationAction = input_action
	button.focus_mode = Control.FOCUS_ALL
	var action_press := InputEventKey.new()
	action_press.keycode = KEY_K
	action_press.pressed = true
	button._gui_input(action_press)
	_check(not button.IsPressed, "focused input action does not activate an unfocused button")
	button.grab_focus()
	await process_frame
	button._gui_input(action_press)
	_check(button.IsPressed and counts["pressed"] == 2, "focused InputMap action enters the normal pressed state")
	var action_release := InputEventKey.new()
	action_release.keycode = KEY_K
	action_release.pressed = false
	button._gui_input(action_release)
	_check(not button.IsPressed and counts["released"] == 2, "focused InputMap action releases through normal button behavior")
	var gamepad_press := InputEventJoypadButton.new()
	gamepad_press.button_index = JOY_BUTTON_A
	gamepad_press.pressed = true
	button._unhandled_input(gamepad_press)
	_check(button.IsPressed and counts["pressed"] == 3, "focused InputMap action accepts gamepad buttons")
	var gamepad_release := InputEventJoypadButton.new()
	gamepad_release.button_index = JOY_BUTTON_A
	gamepad_release.pressed = false
	button._unhandled_input(gamepad_release)
	_check(not button.IsPressed and counts["released"] == 3, "gamepad action releases through normal button behavior")
	button.release_focus()
	InputMap.erase_action(input_action)

	button.InteractionMode = button.InteractionModeEnum.ToggleOnRelease
	button.CooldownTrigger = button.CooldownTriggerEnum.OnRelease
	button.CooldownDuration = 0.1
	_send_mouse(button, false)
	_check(not button.IsToggled, "unmatched mouse release does not toggle")
	_check(not button._cooldown_active, "unmatched mouse release does not start cooldown")
	_check(counts["released"] == 3, "unmatched mouse release does not emit released")

	_send_mouse(button, true)
	_send_mouse(button, false)
	_check(button.IsToggled, "matched release toggles in ToggleOnRelease mode")
	_check(button._cooldown_active, "matched release starts cooldown")
	await create_timer(0.15).timeout
	_check(not button._cooldown_active, "cooldown expires")
	button.InteractionMode = button.InteractionModeEnum.Momentary

	button.Disabled = true
	_send_mouse(button, true)
	_check(not button.IsPressed, "disabled button ignores mouse press")
	button.Disabled = false
	_send_mouse(button, true)
	button.visible = false
	_check(not button.IsPressed, "hiding a pressed button clears its press state")
	_check(button._pointer_gesture_source == button.PointerGestureSource.None, "hiding a pressed button releases pointer ownership")
	button.visible = true
	button.CooldownTrigger = button.CooldownTriggerEnum.None

	button.HoldDuration = 0.05
	button.EnableHoldActions = true
	button.InvertModes = button.INVERT_HOLD
	button.IconTexture = load("res://addons/omni_button/test/icons/Icon-Potion6.png")
	await process_frame
	await process_frame
	_check(is_instance_valid(button._icon), "hold inversion test icon is created")
	if is_instance_valid(button._icon):
		_check(button._icon.material == null, "hold inversion stays off during hold build-up")
	_send_mouse(button, true)
	await create_timer(0.1).timeout
	_check(button.IsHolding, "hold duration enters holding state")
	_check(counts["held"] == 1, "hold action emits once")
	await process_frame
	if is_instance_valid(button._icon):
		_check(button._icon.material == button._invert_material, "hold inversion activates when build-up completes")
	_send_mouse(button, false)
	await process_frame
	if is_instance_valid(button._icon):
		_check(button._icon.material == null, "hold inversion clears when the button is released")

	button.LabelType = button.LabelKind.Label
	button.start_typewriter("ABC", 1000.0)
	_check(button._typewriter != null, "first typewriter request initializes its module")
	await create_timer(0.1).timeout
	_check(button.Text == "ABC", "typewriter completes and preserves final text")
	_check(counts["typed"] == 1, "typewriter completion emits once")

	button.start_typewriter("A long typewriter message should keep its prefit size", 60.0)
	var prefit_size: int = button._label.get_theme_font_size("font_size")
	await create_timer(0.05).timeout
	_check(button._label.visible_characters > 0 and button._label.visible_characters < button._typewriter.full_text.length(), "typewriter reveals text incrementally")
	_check(button._label.get_theme_font_size("font_size") == prefit_size, "typewriter keeps the final-text font size while revealing characters")
	await create_timer(1.0).timeout
	_check(not button._tw_active, "long typewriter finishes after revealing the full text")

	button.LabelType = button.LabelKind.RichTextLabel
	button.TextToType = "[b]Rich[/b] text"
	_check(button.RichLabelUseBBCode, "BBCode is enabled by default for rich labels")
	button.start_typewriter_from_text_to_type(30.0, false, true)
	await create_timer(0.1).timeout
	_check(button._rich_label.bbcode_enabled, "RichTextLabel receives the BBCode setting")
	_check(button._tw_active and button._rich_label.get_parsed_text() != "", "BBCode typewriter incrementally reveals parsed rich text")
	_check(not button._rich_label.has_theme_font_override("bold_font") and not button._rich_label.has_theme_font_override("italics_font"), "rich text autosizing preserves bold and italic style fonts")
	await create_timer(1.0).timeout
	_check(not button._tw_active and button._rich_label.get_parsed_text() == "Rich text", "BBCode typewriter completes with formatting parsed and tags stripped from output")
	button.RichLabelUseBBCode = false
	await process_frame
	await process_frame
	_check(not button._rich_label.bbcode_enabled, "disabling BBCode updates the live RichTextLabel")
	button.RichLabelUseBBCode = true
	await process_frame
	await process_frame
	_check(button._rich_label.bbcode_enabled and button._rich_label.get_parsed_text() == "Rich text", "re-enabling BBCode restores parsed rich text")
	button.Text = "[b]Raw[/b]"
	button.RichLabelUseBBCode = false
	await process_frame
	await process_frame
	_check(button._rich_label.get_parsed_text() == "[b]Raw[/b]", "BBCode-disabled rich labels display tags literally")
	button.RichLabelUseBBCode = true
	await process_frame
	await process_frame
	_check(button._rich_label.get_parsed_text() == "Raw", "BBCode-enabled rich labels parse formatting tags")

	button.LabelType = button.LabelKind.Label
	button.TextToType = "[b]Promoted[/b] to rich text"
	button.RichLabelUseBBCode = true
	button.start_typewriter_from_text_to_type(1000.0, false, true)
	_check(button.LabelType == button.LabelKind.RichTextLabel, "preserving BBCode selects a RichTextLabel when the current type cannot parse it")
	await create_timer(0.1).timeout
	_check(button._rich_label.get_parsed_text() == "Promoted to rich text", "preserve-BBCode typewriter keeps and renders tags from a plain-label starting state")

	button.IsHolding = true
	button.HoldDuration = 0.0
	_check(not button.IsHolding and button._hold_timer == 0.0, "disabling hold duration clears the holding state and timer")
	button.IsPressed = true
	for _frame in range(6):
		await process_frame
	_check(not button.is_processing(), "idle held button stops per-frame processing")

	button.IsPressed = false
	button.HoldDuration = 0.05
	button.IsHolding = false
	button.IsPressed = true
	_check(button.is_processing(), "active hold build-up keeps per-frame processing")
	button.IsPressed = false

	button.EnableJoystickArea = true
	button.JoystickAreaExternalPath = NodePath("Missing/JoystickArea")
	button._ensure_joystick().ensure_and_refresh_joystick_area(button.global_position + button.size * 0.5)
	_check(button._joystick != null, "first joystick request initializes its module")
	_check(is_instance_valid(button._vj_area_panel), "missing external joystick area falls back to a managed area")
	var temporary_bounds := Control.new()
	button.BoundsSource = temporary_bounds
	temporary_bounds.free()
	_check(button._ensure_joystick().get_follow_clamp_rect().size == button.get_viewport_rect().size, "freed bounds source falls back to viewport bounds")

	button.queue_free()
	await process_frame

	# Handlers connected before entering the tree (as editor-made .tscn connections are) run once,
	# and an Action assigned before entering the tree is kept and called once.
	var early := {"signal": 0, "action": 0, "log": 0}
	var early_button = OmniButtonScript.new()
	early_button.size = Vector2(100, 50)
	early_button.pressed.connect(func(): early["signal"] += 1)
	early_button.ReleasedAction = func(): early["action"] += 1
	early_button.LogAction = func(_m): early["log"] += 1
	root.add_child(early_button)
	await process_frame
	early_button.EnablePressedActions = true
	early_button.EnableReleasedActions = true
	_send_mouse(early_button, true)
	_send_mouse(early_button, false)
	_check(early["signal"] == 1, "handler connected before entering the tree runs once per press")
	_check(early["action"] == 1, "Action assigned before entering the tree is kept and runs once")
	early_button.print_log("hello")
	_check(early["log"] == 1, "print_log runs LogAction once")
	var connection_count := 0
	for s in early_button.get_signal_list():
		for c in early_button.get_signal_connection_list(s["name"]):
			if (c["callable"] as Callable).get_object() == early_button:
				connection_count += 1
	_check(connection_count == 0, "button makes no signal connections to itself")
	early_button.queue_free()
	await process_frame

	# Scene-load order: IconTexture set before ready queues a child rebuild that replaces the Label.
	var fit_button = OmniButtonScript.new()
	fit_button.size = Vector2(100, 50)
	fit_button.IconTexture = load("res://addons/omni_button/test/icons/Icon-Potion6.png")
	fit_button.Text = "Press then Swipe Button"
	fit_button.BackgroundType = fit_button.BackgroundMode.UsePanel
	fit_button.Selected = true
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

	var demo_scene := load("res://addons/omni_button/test/GodotTest.tscn") as PackedScene
	var demo := demo_scene.instantiate()
	root.add_child(demo)
	await create_timer(0.2).timeout
	var demo_text := demo.get_node("%TextBlock") as Omni_Button
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
	_check(not demo_text._tw_active and demo_text._rich_label.text == demo_text.TextToType, "demo typewriter completes with the full rich text")
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
