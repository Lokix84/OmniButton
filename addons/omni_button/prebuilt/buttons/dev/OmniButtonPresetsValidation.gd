extends SceneTree
# checks the ready made buttons in prebuilt/buttons/presets/. each one loads with the shared styles
# and sends the signal it's supposed to (the touch ones with real input events), buttons in scaled
# containers keep their size while hovered or dragged, and the demo scene loads and fits small screens.
# usage: godot --headless --path . -s res://addons/omni_button/prebuilt/buttons/dev/OmniButtonPresetsValidation.gd

const DIR := "res://addons/omni_button/prebuilt/buttons/"
const PRESETS := ["omni_menu_button", "omni_toggle_button", "omni_icon_button", "omni_item_button",
	"omni_hold_button", "omni_cooldown_button"]
const TOUCH_PRESETS := ["omni_joystick", "omni_floating_joystick", "omni_swipe_pad", "omni_action_button"]
const MORE_PRESETS := ["omni_typewriter_button", "omni_invert_button", "omni_tab_button", "omni_tab_bar"]
const NORMAL := preload(DIR + "styles/button_normal.tres")
const FOCUS := preload(DIR + "styles/button_focus.tres")
const DISABLED := preload(DIR + "styles/button_disabled.tres")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var made := {}
	for p: String in PRESETS:
		var scene := load(DIR + "presets/" + p + ".tscn") as PackedScene
		_check(scene != null, "%s loads" % p)
		if scene == null:
			continue
		var b = scene.instantiate()
		_check(b is OmniButton, "%s is an OmniButton" % p)
		_check(b.panel_style_box == NORMAL and b.panel_focus_style_box == FOCUS and b.panel_disabled_style_box == DISABLED, "%s uses the shared styles" % p)
		_check(b.focus_mode == Control.FOCUS_ALL, "%s can take keyboard / gamepad focus" % p)
		_check(b.custom_minimum_size.x > 0.0 and b.custom_minimum_size.y > 0.0, "%s has a minimum size" % p)
		root.add_child(b)
		made[p] = b
	await process_frame
	await process_frame

	# menu: pressed
	var menu: OmniButton = made["omni_menu_button"]
	var count := [0]
	menu.pressed.connect(func(): count[0] += 1)
	_click(menu)
	_check(count[0] == 1, "menu button emits pressed on click")
	_check(menu.hover_scale > 1.0, "menu button grows on hover")
	menu.disabled = true
	await process_frame
	_click(menu)
	_check(count[0] == 1, "a disabled menu button ignores clicks")
	_check(menu._label != null and menu._label.modulate == menu.disabled_modulate, "a disabled button fades its text")
	menu.disabled = false
	await process_frame
	_check(menu._label.modulate == Color.WHITE, "re-enabling restores the text")

	# toggle: toggled(on), stays on
	var toggle: OmniButton = made["omni_toggle_button"]
	var states: Array[bool] = []
	toggle.toggled.connect(func(on: bool): states.append(on))
	_click(toggle)
	_check(states == [true] and toggle.is_toggled, "toggle button turns on with toggled(true)")
	_click(toggle)
	_check(states == [true, false] and not toggle.is_toggled, "a second click turns it off with toggled(false)")

	# icon: pressed, no text, tooltip
	var icon: OmniButton = made["omni_icon_button"]
	_check(icon.icon_texture != null and icon.label_type == OmniButton.LabelKind.NONE, "icon button shows an icon and no text")
	_check(icon.tooltip_text != "", "icon button has a tooltip")
	icon.disabled = true
	await process_frame
	_check(icon._icon != null and icon._icon.modulate == icon.disabled_modulate, "a disabled button fades its icon")
	icon.disabled_modulate = Color.WHITE
	await process_frame
	_check(icon._icon.modulate == Color.WHITE, "a white disabled_modulate leaves the icon unchanged")
	icon.disabled = false

	# item: icon and caption along the bottom
	var item: OmniButton = made["omni_item_button"]
	_check(item.icon_texture != null and item.text != "" and item.label_vertical_alignment == VERTICAL_ALIGNMENT_BOTTOM, "item button has an icon and a bottom caption")

	# hold: only hold fires, after the hold time
	var hold: OmniButton = made["omni_hold_button"]
	hold.hold_duration = 0.1
	var held := [0]
	var hold_pressed := [0]
	hold.hold.connect(func(): held[0] += 1)
	hold.pressed.connect(func(): hold_pressed[0] += 1)
	_send_mouse(hold, true)
	await create_timer(0.03).timeout
	_send_mouse(hold, false)
	_check(held[0] == 0, "letting go of the hold button early does nothing")
	_send_mouse(hold, true)
	await create_timer(0.25).timeout
	_check(held[0] == 1, "holding the hold button long enough emits hold once")
	_send_mouse(hold, false)
	_check(hold_pressed[0] == 0, "the hold button doesn't emit pressed")
	_check(hold._hold_fill != null and hold._hold_fill.corner_radius == Vector4i(10, 10, 10, 10), "the hold fill follows the panel's rounded corners")

	# cooldown: pressed, then ignores presses until the cooldown's over
	var cd: OmniButton = made["omni_cooldown_button"]
	cd.cooldown_duration = 0.2
	var fired := [0]
	cd.pressed.connect(func(): fired[0] += 1)
	_click(cd)
	_check(fired[0] == 1, "cooldown button emits pressed")
	await process_frame
	_check(cd._cooldown != null and cd._cooldown.visible, "cooldown fill shows after a press")
	_check(cd._cooldown.corner_radius == Vector4i(10, 10, 10, 10), "the cooldown fill follows the panel's rounded corners")
	_click(cd)
	_check(fired[0] == 1, "presses during the cooldown are ignored")
	await create_timer(0.35).timeout
	_click(cd)
	_check(fired[0] == 2, "it can be pressed again once the cooldown ends")

	for b in made.values():
		b.queue_free()
	await process_frame

	# square panels keep square fills.
	var square := OmniButton.new()
	square.background_type = OmniButton.BackgroundMode.USE_PANEL
	square.panel_style_box = StyleBoxFlat.new()
	square.cooldown_trigger = OmniButton.CooldownTrigger.ON_PRESS
	square.size = Vector2(80, 40)
	root.add_child(square)
	await process_frame
	_click(square)
	await process_frame
	_check(square._cooldown != null and square._cooldown.corner_radius == Vector4i.ZERO, "a square panel keeps a square cooldown fill")
	square.queue_free()

	await _check_touch_presets()
	await _check_scaled_parent()
	await _check_more_presets()

	# demo scene: loads, hooks up its buttons, and fits a 320x180 screen.
	var demo: Control = load(DIR + "demo/omni_button_presets_demo.tscn").instantiate()
	root.add_child(demo)
	await process_frame
	await process_frame
	var music: OmniButton = demo.get_node("%Music")
	_click(music)
	_check(music.text == "Music: On", "demo: the toggle handler changes the toggle's text")
	_check(demo.get_node("%Log").text.contains("Music: toggled on"), "demo: signals are logged")
	var accept_has_pad := false
	for e in InputMap.action_get_events(&"ui_accept"):
		accept_has_pad = accept_has_pad or (e is InputEventJoypadButton and e.button_index == JOY_BUTTON_A)
	_check(accept_has_pad, "demo: the controller's A button is added to ui_accept so focused buttons can be pressed")
	demo.get_node("%Tabs").current_tab = 2
	_check(demo.get_node("%MoreCards").visible and not demo.get_node("%Cards").visible, "demo: the page tabs switch pages")
	demo.get_node("%Tabs").current_tab = 0
	root.content_scale_size = Vector2i(320, 180)
	await process_frame
	await process_frame
	var margin: Control = demo.get_node("Margin")
	var visible_size := root.get_visible_rect().size
	_check(margin.size.x * margin.scale.x <= visible_size.x + 1.0 and margin.size.y * margin.scale.y <= visible_size.y + 1.0, "demo: the page fits a 320x180 screen")
	root.content_scale_size = Vector2i(1152, 648)
	demo.queue_free()
	await process_frame

	if _failures.is_empty():
		print("OmniButton presets validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniButton presets validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _check_more_presets() -> void:
	for p: String in MORE_PRESETS:
		_check(load(DIR + "presets/" + p + ".tscn") != null, "%s loads" % p)

	# typewriter: types on start, the first press just finishes, later presses count.
	var tw: OmniTypewriterButton = load(DIR + "presets/omni_typewriter_button.tscn").instantiate()
	tw.start_delay = 0.0
	tw.characters_per_second = 20.0
	tw.position = Vector2(50, 50)
	root.add_child(tw)
	await process_frame
	await process_frame
	_check(tw.is_typing(), "typewriter: starts typing by itself")
	var presses := [0]
	var typed := [0]
	tw.pressed.connect(func(): presses[0] += 1)
	tw.typewriter_completed.connect(func(): typed[0] += 1)
	_click(tw)
	_check(not tw.is_typing() and typed[0] == 1 and presses[0] == 0, "typewriter: the first press finishes the text without counting as a press")
	_click(tw)
	_check(presses[0] == 1, "typewriter: presses after that emit pressed")
	await create_timer(0.3).timeout
	_check(tw.modulate.a < 0.99, "typewriter: the text pulses once typed")
	tw.play()
	await process_frame
	_check(tw.is_typing() and tw.modulate.a == 1.0, "typewriter: play() restarts the typing and stops the pulse")
	tw.queue_free()

	# invert flash: colors only flip while pressed.
	var inv: OmniButton = load(DIR + "presets/omni_invert_button.tscn").instantiate()
	inv.position = Vector2(50, 200)
	root.add_child(inv)
	await process_frame
	_check(inv._panel != null and inv._panel.material == null, "invert button: normal colors at rest")
	_send_mouse(inv, true)
	await process_frame
	_check(inv._panel.material != null and inv._label.material != null, "invert button: panel and text invert while pressed")
	_send_mouse(inv, false)
	await process_frame
	_check(inv._panel.material == null, "invert button: colors return on release")
	inv.queue_free()

	# tab bar: one tab on, the signal, pages, and new tabs getting picked up.
	var bar: OmniTabBar = load(DIR + "presets/omni_tab_bar.tscn").instantiate()
	bar.position = Vector2(50, 300)
	var pages := Control.new()
	for i in 3:
		pages.add_child(Control.new())
	root.add_child(pages)
	bar.pages = pages
	root.add_child(bar)
	await process_frame
	var tabs := bar.get_tabs()
	_check(tabs.size() == 3 and tabs[0].is_toggled and not tabs[1].is_toggled, "tab bar: the first tab starts on")
	_check(pages.get_child(0).visible and not pages.get_child(1).visible, "tab bar: only the first page is shown")
	var changes: Array[int] = []
	bar.tab_changed.connect(func(i: int): changes.append(i))
	_click(tabs[2])
	_check(changes == [2] and bar.current_tab == 2 and tabs[2].is_toggled and not tabs[0].is_toggled, "tab bar: clicking a tab turns it on and the others off")
	_check(pages.get_child(2).visible and not pages.get_child(0).visible, "tab bar: the matching page is shown")
	_click(tabs[2])
	_check(tabs[2].is_toggled and changes == [2], "tab bar: clicking the tab that is on keeps it on")
	bar.current_tab = 1
	_check(tabs[1].is_toggled and not tabs[2].is_toggled and changes == [2, 1], "tab bar: setting current_tab switches tabs")
	var extra: OmniButton = load(DIR + "presets/omni_tab_button.tscn").instantiate()
	bar.add_child(extra)
	await process_frame
	await process_frame
	_click(extra)
	_check(bar.current_tab == 3 and not tabs[1].is_toggled, "tab bar: a tab added at runtime joins the group")
	bar.queue_free()
	pages.queue_free()
	await process_frame

func _check_touch_presets() -> void:
	# headless windows start tiny, and input pushed outside the window never gets to the gui.
	root.size = Vector2i(1152, 648)
	for p: String in TOUCH_PRESETS:
		_check(load(DIR + "presets/" + p + ".tscn") != null, "%s loads" % p)
	for a in ["test_left", "test_right", "test_up", "test_down", "test_jump"]:
		if not InputMap.has_action(a):
			InputMap.add_action(a)

	# fixed joystick: 160x160 at (100, 100), center (180, 180). the thumb goes out to the ring's edge (80 px).
	var stick: OmniJoystick = load(DIR + "presets/omni_joystick.tscn").instantiate()
	stick.position = Vector2(100, 100)
	stick.action_right = &"test_right"
	stick.action_up = &"test_up"
	root.add_child(stick)
	await process_frame
	var events: Array[String] = []
	stick.started.connect(func(): events.append("started"))
	stick.ended.connect(func(): events.append("ended"))
	_mouse_button(Vector2(180, 180), true)
	await process_frame
	_check(stick.is_active() and events == ["started"], "joystick: pressing the ring starts it")
	_mouse_move(Vector2(210, 180))
	await process_frame
	_check(_near(_center(stick.thumb), Vector2(210, 180)), "joystick: the thumb follows the pointer")
	_mouse_move(Vector2(300, 180))
	await process_frame
	_check(stick.axis.x > 0.99 and absf(stick.axis.y) < 0.01, "joystick: pushing right past the ring gives axis (1, 0)")
	_check(_near(_center(stick.thumb), Vector2(260, 180)), "joystick: the thumb stops at the edge of its travel")
	_check(Input.get_action_strength("test_right") > 0.99, "joystick: action_right is held with the stick's strength")
	_mouse_move(Vector2(180, 90))
	await process_frame
	_check(stick.axis.y < -0.9 and Input.is_action_pressed("test_up") and not Input.is_action_pressed("test_right"), "joystick: pushing up holds action_up and releases action_right")
	_mouse_button(Vector2(180, 90), false)
	await process_frame
	_check(not stick.is_active() and stick.axis == Vector2.ZERO and events == ["started", "ended"], "joystick: releasing ends it with axis zero")
	_check(not Input.is_action_pressed("test_up"), "joystick: releasing lets go of the actions")
	_check(_near(_center(stick.thumb), Vector2(180, 180)), "joystick: the thumb goes back to the middle")
	_mouse_button(Vector2(30, 30), true)
	await process_frame
	_check(not stick.is_active(), "joystick: presses outside it are ignored")
	_mouse_button(Vector2(30, 30), false)
	stick.queue_free()

	# floating joystick: a 400x240 zone at (0, 300). the ring shows up where the finger lands.
	var zone: OmniJoystick = load(DIR + "presets/omni_floating_joystick.tscn").instantiate()
	zone.position = Vector2(0, 300)
	root.add_child(zone)
	await process_frame
	_check(zone.floating and not zone.base.visible, "floating joystick: the ring is hidden until touched")
	_touch(0, Vector2(150, 420), true)
	await process_frame
	_check(zone.base.visible and _near(_center(zone.base), Vector2(150, 420)), "floating joystick: the ring appears under the finger")
	_drag(0, Vector2(190, 420))
	await process_frame
	_check(zone.axis.x > 0.5, "floating joystick: dragging moves the stick")
	_touch(1, Vector2(300, 450), true)
	await process_frame
	_drag(1, Vector2(300, 300))
	await process_frame
	_check(zone.axis.x > 0.5 and absf(zone.axis.y) < 0.1, "floating joystick: a second finger doesn't take over")
	_touch(0, Vector2(190, 420), false)
	await process_frame
	_check(not zone.base.visible and zone.axis == Vector2.ZERO, "floating joystick: lifting the finger hides the ring")
	_touch(1, Vector2(300, 300), false)
	_touch(0, Vector2(5, 305), true)
	await process_frame
	var ring_pos := zone.base.global_position
	_check(ring_pos.x >= -0.5 and ring_pos.y >= 299.5, "floating joystick: the ring stays inside the zone near its edge")
	_touch(0, Vector2(5, 305), false)
	await process_frame
	zone.queue_free()

	# swipe pad: one swiped signal per gesture, snapped to four directions.
	var pad: OmniSwipePad = load(DIR + "presets/omni_swipe_pad.tscn").instantiate()
	pad.position = Vector2(500, 100)
	root.add_child(pad)
	await process_frame
	var dirs: Array[Vector2] = []
	pad.swiped.connect(func(d: Vector2): dirs.append(d))
	_mouse_button(Vector2(600, 180), true)
	_mouse_move(Vector2(630, 185))
	await process_frame
	_check(dirs.is_empty(), "swipe pad: a short move isn't a swipe")
	_mouse_move(Vector2(670, 190))
	_mouse_move(Vector2(740, 195))
	await process_frame
	_check(dirs == [Vector2.RIGHT], "swipe pad: one swipe right gives one swiped(RIGHT)")
	_mouse_button(Vector2(740, 195), false)
	await process_frame
	_mouse_button(Vector2(650, 230), true)
	_mouse_move(Vector2(655, 150))
	await process_frame
	_mouse_button(Vector2(655, 150), false)
	await process_frame
	_check(dirs == [Vector2.RIGHT, Vector2.UP], "swipe pad: the next gesture swipes again (up)")
	_check(OmniSwipePad.snap(Vector2(-0.8, 0.6)) == Vector2.LEFT and OmniSwipePad.snap(Vector2(0.2, 0.9)) == Vector2.DOWN, "swipe pad: directions snap to the nearest of four")
	pad.queue_free()

	# action button: holds its output_action while pressed.
	var action: OmniButton = load(DIR + "presets/omni_action_button.tscn").instantiate()
	action.position = Vector2(500, 400)
	action.output_action = &"test_jump"
	root.add_child(action)
	await process_frame
	var pressed := [0]
	action.pressed.connect(func(): pressed[0] += 1)
	_send_mouse(action, true)
	_check(pressed[0] == 1 and Input.is_action_pressed("test_jump"), "action button: pressing it holds output_action")
	_send_mouse(action, false)
	_check(not Input.is_action_pressed("test_jump"), "action button: releasing it lets go of output_action")
	# a real touch (through the viewport, so _gui_input gets control relative positions) on a button
	# away from the corner of the screen, while another finger is down somewhere else.
	_touch(0, Vector2(50, 600), true)
	_touch(1, Vector2(555, 455), true)
	await process_frame
	_check(action.is_pressed and Input.is_action_pressed("test_jump"), "action button: a second finger's touch presses it")
	_touch(1, Vector2(555, 455), false)
	await process_frame
	_check(not action.is_pressed and not Input.is_action_pressed("test_jump"), "action button: lifting that finger releases it")
	_touch(0, Vector2(50, 600), false)
	_send_mouse(action, true)
	action.queue_free()
	await process_frame
	_check(not Input.is_action_pressed("test_jump"), "action button: removing it while pressed lets go of output_action")

## buttons inside a scaled container keep their on screen size while hovered or dragged.
func _check_scaled_parent() -> void:
	var holder := Control.new()
	holder.scale = Vector2(0.5, 0.5)
	root.add_child(holder)
	var menu: OmniButton = load(DIR + "presets/omni_menu_button.tscn").instantiate()
	menu.position = Vector2(100, 100)
	holder.add_child(menu)
	await process_frame
	var before := menu.get_global_rect()
	menu.notification(Control.NOTIFICATION_MOUSE_ENTER)
	await process_frame
	_check(menu.top_level and menu.get_global_transform().get_scale().is_equal_approx(Vector2(0.5, 0.5)) and menu.get_global_rect().position.is_equal_approx(before.position), "scaled parent: a hovered button keeps its on-screen size and place")
	menu.notification(Control.NOTIFICATION_MOUSE_EXIT)
	for i in 30:
		await process_frame
	_check(not menu.top_level and menu.scale == Vector2.ONE and menu.position.is_equal_approx(Vector2(100, 100)), "scaled parent: after hover the button is back where it was")

	var stick: OmniJoystick = load(DIR + "presets/omni_joystick.tscn").instantiate()
	stick.position = Vector2(400, 400)
	holder.add_child(stick)
	await process_frame
	# on screen: 80x80 at (200, 200), center (240, 240), 40 px of travel.
	_mouse_button(Vector2(240, 240), true)
	await process_frame
	_mouse_move(Vector2(256, 240))
	await process_frame
	_check(_near(_center(stick.thumb), Vector2(256, 240)) and stick.thumb.get_global_transform().get_scale().is_equal_approx(Vector2(0.5, 0.5)), "scaled parent: the thumb follows the pointer at its on-screen size")
	_check(absf(stick.axis.x - 0.4) < 0.05, "scaled parent: the axis uses the on-screen travel")
	_mouse_button(Vector2(256, 240), false)
	await process_frame
	_check(_near(_center(stick.thumb), Vector2(240, 240)), "scaled parent: the thumb returns to the middle")
	holder.queue_free()
	await process_frame

func _center(c: Control) -> Vector2:
	return c.get_global_transform() * (c.size * 0.5)

func _near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < 1.5

func _mouse_button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	e.position = pos
	e.global_position = pos
	root.push_input(e)

func _mouse_move(pos: Vector2) -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT
	e.position = pos
	e.global_position = pos
	root.push_input(e)

func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.pressed = pressed
	e.position = pos
	root.push_input(e)

func _drag(index: int, pos: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	root.push_input(e)

func _click(b: Control) -> void:
	_send_mouse(b, true)
	_send_mouse(b, false)

func _send_mouse(b: Control, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = Vector2(10, 10)
	e.global_position = b.global_position + e.position
	b._gui_input(e)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
