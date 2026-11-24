extends SceneTree
# Checks OmniVirtualCursor (prebuilt/cursor/): the ring shows on stick input, hovers and clicks what is
# under it (OmniButtons and Godot's own Controls, with a real controller A press), snaps, scrolls,
# hides for the d-pad and the real mouse, and the demo scene loads.
# The cursor drives real mouse input, so these checks go through Input.parse_input_event.
# Usage: godot --headless --path . -s res://addons/omni_button/prebuilt/cursor/dev/OmniVirtualCursorValidation.gd

const CURSOR_SCENE := "res://addons/omni_button/prebuilt/cursor/omni_virtual_cursor.tscn"
const DEMO_SCENE := "res://addons/omni_button/prebuilt/cursor/demo/omni_cursor_demo.tscn"
const BUTTONS := "res://addons/omni_button/prebuilt/buttons/"

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(load(CURSOR_SCENE) is PackedScene, "omni_virtual_cursor.tscn loads")
	await _check_virtual_cursor()

	# Demo scene: loads, shows the controller line, adds A to ui_accept, and has an active cursor.
	var demo: Control = load(DEMO_SCENE).instantiate()
	root.add_child(demo)
	await _frames(2)
	var cursor: OmniVirtualCursor = demo.get_node("%Cursor")
	_check(cursor != null and cursor.active, "demo: the cursor is in the scene and active")
	_check(demo.get_node("%CursorState").text.begins_with("No controller found") or demo.get_node("%CursorState").text.begins_with("Controllers:"), "demo: it says which controllers Godot sees")
	var accept_has_pad := false
	for e in InputMap.action_get_events(&"ui_accept"):
		accept_has_pad = accept_has_pad or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)
	_check(accept_has_pad, "demo: the controller's A button is added to ui_accept so focused buttons can be pressed")
	cursor.hide_mouse_pointer = false
	var play: Omni_Button = demo.get_node("%Play")
	var played := [0]
	play.pressed.connect(func(): played[0] += 1)
	_stick(JOY_AXIS_LEFT_X, 0.6)
	await _frames(3)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	cursor.warp_to(play.get_global_rect().get_center())
	await _frames(3)
	_joy_button(JOY_BUTTON_A, true)
	await _frames(2)
	_joy_button(JOY_BUTTON_A, false)
	await _frames(2)
	_check(played[0] == 1, "demo: A over Play presses it")
	demo.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniVirtualCursor validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniVirtualCursor validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

## The virtual cursor drives real mouse input, so these checks go through Input.parse_input_event.
func _check_virtual_cursor() -> void:
	root.size = Vector2i(1152, 648)
	var menu := Control.new()
	menu.size = Vector2(1152, 648)
	root.add_child(menu)
	var omni: Omni_Button = load(BUTTONS + "presets/omni_menu_button.tscn").instantiate()
	omni.position = Vector2(100, 100)
	menu.add_child(omni)
	var plain := Button.new()
	plain.text = "Godot Button"
	plain.position = Vector2(100, 300)
	plain.size = Vector2(200, 50)
	menu.add_child(plain)
	var focused: Omni_Button = load(BUTTONS + "presets/omni_menu_button.tscn").instantiate()
	focused.position = Vector2(100, 500)
	menu.add_child(focused)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(700, 100)
	scroll.size = Vector2(300, 200)
	var tall := Control.new()
	tall.custom_minimum_size = Vector2(280, 2000)
	scroll.add_child(tall)
	menu.add_child(scroll)
	var cursor: OmniVirtualCursor = load(CURSOR_SCENE).instantiate()
	cursor.hide_mouse_pointer = false
	menu.add_child(cursor)
	await process_frame
	await process_frame
	_check(not cursor.is_shown(), "cursor: hidden until the stick moves")

	focused.grab_focus()
	var start := cursor.cursor_position
	_stick(JOY_AXIS_LEFT_X, 1.0)
	await _frames(5)
	_check(cursor.is_shown() and cursor.cursor_position.x > start.x + 5.0, "cursor: pushing the stick shows the ring and moves it")
	_check(root.gui_get_focus_owner() == null, "cursor: showing the ring releases keyboard / gamepad focus")
	_stick(JOY_AXIS_LEFT_X, 0.0)
	await process_frame
	var still := cursor.cursor_position
	await _frames(3)
	_check(cursor.cursor_position == still, "cursor: it stops when the stick is let go")

	# Hover and click an Omni_Button.
	var omni_presses := [0]
	omni.pressed.connect(func(): omni_presses[0] += 1)
	var focused_presses := [0]
	focused.pressed.connect(func(): focused_presses[0] += 1)
	cursor.snap_strength = 0.0
	cursor.warp_to(omni.get_global_rect().get_center())
	await _frames(3)
	_check(omni.IsHovering and cursor.get_hovered_control() == omni, "cursor: the button under the ring is hovered")
	# A real controller A press: Godot's stock ui_accept has no controller button, so this checks
	# click_button works on its own.
	_joy_button(JOY_BUTTON_A, true)
	await _frames(2)
	_check(omni.IsPressed and omni_presses[0] == 1, "cursor: the A button presses the button under the ring")
	_joy_button(JOY_BUTTON_A, false)
	await _frames(2)
	_check(not omni.IsPressed and focused_presses[0] == 0, "cursor: release lets go, and the previously focused button wasn't pressed")

	# A plain Godot Button works too.
	var plain_presses := [0]
	plain.pressed.connect(func(): plain_presses[0] += 1)
	cursor.warp_to(plain.get_global_rect().get_center())
	await _frames(2)
	_action(&"ui_accept", true)
	await _frames(2)
	_action(&"ui_accept", false)
	await _frames(2)
	_check(plain_presses[0] == 1, "cursor: the click action (Enter / Space) clicks too, and reaches Godot's own Button")

	# Snap pulls toward the center of what's under the ring.
	cursor.snap_strength = 1.0
	var center := omni.get_global_rect().get_center()
	cursor.warp_to(center + Vector2(80, 10))
	await _frames(20)
	_check(cursor.cursor_position.distance_to(center) < 60.0, "cursor: snap pulls the ring toward the button's center")
	cursor.snap_strength = 0.0

	# The other stick scrolls what's under the ring.
	cursor.warp_to(scroll.get_global_rect().get_center())
	await _frames(2)
	_stick(JOY_AXIS_RIGHT_Y, 1.0)
	await _frames(10)
	_stick(JOY_AXIS_RIGHT_Y, 0.0)
	await _frames(2)
	_check(scroll.scroll_vertical > 0, "cursor: the other stick scrolls a scroll container")

	# The stick's own ui_left mapping doesn't hide it, but the d-pad / arrows do.
	_stick(JOY_AXIS_LEFT_X, -1.0)
	await _frames(2)
	_check(cursor.is_shown(), "cursor: moving the stick (also mapped to ui_left) keeps the ring")
	_stick(JOY_AXIS_LEFT_X, 0.0)
	_action(&"ui_down", true)
	await _frames(2)
	_action(&"ui_down", false)
	_check(not cursor.is_shown(), "cursor: the d-pad (focus navigation) hides the ring")

	# A real mouse takes over.
	_stick(JOY_AXIS_LEFT_X, 1.0)
	await _frames(3)
	_stick(JOY_AXIS_LEFT_X, 0.0)
	var m := InputEventMouseMotion.new()
	m.position = Vector2(10, 10)
	m.relative = Vector2(5, 0)
	Input.parse_input_event(m)
	await _frames(2)
	_check(not cursor.is_shown(), "cursor: moving the real mouse hides the ring")

	_stick(JOY_AXIS_LEFT_X, 1.0)
	await _frames(3)
	cursor.active = false
	_check(not cursor.is_shown(), "cursor: active = false hides it")
	await _frames(3)
	_check(not cursor.is_shown(), "cursor: while inactive the stick doesn't bring it back")
	_stick(JOY_AXIS_LEFT_X, 0.0)
	menu.queue_free()
	await process_frame

func _stick(axis: JoyAxis, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = 0
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)

func _joy_button(button: JoyButton, pressed: bool) -> void:
	var e := InputEventJoypadButton.new()
	e.device = 0
	e.button_index = button
	e.pressed = pressed
	Input.parse_input_event(e)

func _action(action: StringName, pressed: bool) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = pressed
	Input.parse_input_event(e)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
