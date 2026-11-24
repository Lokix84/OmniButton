extends SceneTree
# dev tool: benchmarks loading, hover/press and the typewriter, plus checks on the visuals, lazy
# accessors and unhandled input gating. not needed at runtime.
# usage: godot --headless --path . -s res://addons/omni_button/dev/OmniButtonBenchmark.gd

const OmniButtonScript = preload("res://addons/omni_button/omni_button.gd")

func _initialize() -> void:
	call_deferred("_run")

func _make() -> Control:
	var b = OmniButtonScript.new()
	b.size = Vector2(120, 48)
	b.background_type = 1 # USE_PANEL
	var normal := StyleBoxFlat.new()
	var pressed := StyleBoxFlat.new()
	pressed.bg_color = Color.RED
	b.panel_style_box = normal
	b.panel_pressed_style_box = pressed
	b.text = "Button"
	b.hover_scale = 1.2
	b.invert_modes = 1 | 4
	return b

func _run() -> void:
	var buttons: Array = []
	for i in 200:
		var b := _make()
		b.position = Vector2(150 + (i % 10) * 5, 150 + (i / 10) * 5)
		root.add_child(b)
		buttons.append(b)
	for _f in 8:
		await process_frame

	# --- demo style load: properties set before entering the tree, like a .tscn instance.
	var icon_tex := load("res://addons/omni_button/demo/icons/Icon-Potion6.png")
	var style := StyleBoxFlat.new()
	for same_text in [false, true]:
		await _bench_load(icon_tex, style, same_text)

	# --- autosize/settle: 200 buttons with labels made and settled over 8 frames.
	var ts := Time.get_ticks_usec()
	var text_buttons: Array = []
	for i in 200:
		var tb = OmniButtonScript.new()
		tb.size = Vector2(140, 48)
		tb.text = "Autosized label %d" % i
		root.add_child(tb)
		text_buttons.append(tb)
	for _f in 8:
		await process_frame
	print("BENCH create+settle 200 labelled buttons: %.2f ms" % (float(Time.get_ticks_usec() - ts) / 1000.0))
	for tb in text_buttons: tb.queue_free()
	await process_frame

	# --- typewriter: 40 rich text buttons typing out a long bbcode message.
	var msg := ""
	for _r in 12:
		msg += "Some [b]bold[/b] and [i]italic[/i] text with a [wave amp=20]wavy[/wave] bit and [color=green]colour[/color]. "
	var tw_buttons: Array = []
	for i in 40:
		var wb = OmniButtonScript.new()
		wb.size = Vector2(400, 220)
		wb.label_type = 1
		root.add_child(wb)
		tw_buttons.append(wb)
	await process_frame
	await process_frame
	var tt := Time.get_ticks_usec()
	for wb in tw_buttons:
		wb.start_typewriter(msg, 600.0, false, true)
	var frames := 0
	var any_active := true
	while any_active and frames < 2000:
		any_active = false
		for wb in tw_buttons:
			if wb._tw_active:
				wb._process(0.016)
				any_active = any_active or wb._tw_active
		frames += 1
	print("BENCH typewriter 40 x %d chars: %.2f ms over %d frames" % [msg.length(), float(Time.get_ticks_usec() - tt) / 1000.0, frames])
	if tw_buttons[0]._typewriter != null:
		var twf: Array[String] = []
		var w = tw_buttons[0]
		if w._rich_label.text != msg: twf.append("completed reveal restores full text incl. effect tags")
		if w._rich_label.visible_characters != -1: twf.append("completed reveal shows all characters")
		w.start_typewriter(msg, 30.0, false, true)
		if w._rich_label.text.contains("[wave"): twf.append("effect tags held back during reveal")
		w._process(0.2)
		var shown: int = w._rich_label.visible_characters
		if shown <= 0 or shown >= w._typewriter.total_chars: twf.append("rich reveal is partial (%d)" % shown)
		w.stop_typewriter()
		if w._tw_active or w.text.is_empty() or w.text.length() >= msg.length(): twf.append("cancel commits partial text")
		w.label_type = 0
		w.start_typewriter("one two three four", 2.0, true)
		w._process(0.5)
		if w._label.visible_characters != 4: twf.append("by-word reveals whole first word (got %d)" % w._label.visible_characters)
		w._process(0.5)
		if w._label.visible_characters != 8: twf.append("by-word reveals second word (got %d)" % w._label.visible_characters)
		w.skip_typewriter()
		if w.text != "one two three four" or w._label.visible_characters != -1: twf.append("skip shows full plain text")
		print("TW CHECKS passed" if twf.is_empty() else "TW CHECK FAILED: " + ", ".join(twf))
	for wb in tw_buttons: wb.queue_free()
	await process_frame

	var cycles := 25
	var t0 := Time.get_ticks_usec()
	for _c in cycles:
		for b in buttons:
			OmniButtonInput.on_mouse_entered(b)
			b.is_pressed = true
			b._process(0.016)
			b.is_pressed = false
			OmniButtonInput.on_mouse_exited(b)
			b._process(0.016)
	var ms := float(Time.get_ticks_usec() - t0) / 1000.0
	print("BENCH hover+press cycles: %d buttons x %d = %.2f ms (%.2f us/cycle)" % [buttons.size(), cycles, ms, ms * 1000.0 / (buttons.size() * cycles)])

	var unhandled_on := 0
	for b in buttons:
		if b.is_processing_unhandled_input():
			unhandled_on += 1
	print("BENCH idle buttons receiving _unhandled_input: %d / %d" % [unhandled_on, buttons.size()])

	if "_pending_state_refresh" in buttons[0]:
		var fails: Array[String] = []
		var b = buttons[0]
		# panel stylebox swaps with state
		b.is_pressed = true; b._process(0.016)
		if b._panel.style != b.panel_pressed_style_box: fails.append("pressed stylebox applied")
		if b._label.material != b._invert_material: fails.append("press invert applied to label")
		b.is_pressed = false; b._process(0.016)
		if b._panel.style != b.panel_style_box: fails.append("normal stylebox restored")
		if b._label.material != null: fails.append("invert cleared on release")
		# hover only scales the managed root
		OmniButtonInput.on_mouse_entered(b)
		for _i in 30: b._process(0.016)
		if b._managed_root.scale.x <= 1.01: fails.append("hover scales managed root")
		if not (b._panel is OmniDrawItem): fails.append("panel is a canvas item, not a node")
		OmniButtonInput.on_mouse_exited(b)
		for _i in 60: b._process(0.016)
		if not b._managed_root.scale.is_equal_approx(Vector2.ONE): fails.append("hover-out returns root to 1")
		# swapping the icon keeps the node and its siblings
		b.icon_texture = load("res://addons/omni_button/demo/icons/Icon-Potion6.png")
		await process_frame
		var icon_node = b._icon
		var panel_node = b._panel
		var label_node = b._label
		b.icon_texture = load("res://addons/omni_button/demo/icons/Icon-Sword1.png")
		await process_frame
		await process_frame
		if b._icon != icon_node: fails.append("icon node reused on texture change")
		if b._panel != panel_node or b._label != label_node: fails.append("siblings not rebuilt on icon change")
		if b._icon.texture.resource_path.get_file() != "Icon-Sword1.png": fails.append("icon texture updated")
		b.icon_texture = null
		await process_frame
		if is_instance_valid(b._icon): fails.append("icon removed when cleared")
		# unhandled input gating
		b.focus_mode = Control.FOCUS_ALL
		if b.is_processing_unhandled_input(): fails.append("idle button has unhandled input off")
		b.grab_focus()
		await process_frame
		if not b.is_processing_unhandled_input(): fails.append("focused button has unhandled input on")
		b.release_focus()
		await process_frame
		if b.is_processing_unhandled_input(): fails.append("unfocused button turns unhandled input off")
		# starting the typewriter keeps the panel node
		var panel_before = b._panel
		b.start_typewriter("Hello", 1000.0)
		if b._panel != panel_before: fails.append("typewriter start does not rebuild panel")
		await create_timer(0.1).timeout
		if b.text != "Hello": fails.append("typewriter completes")
		# starting/stopping the joystick from code
		var js = OmniButtonScript.new()
		js.size = Vector2(80, 80)
		js.position = Vector2(300, 300)
		js.enable_virtual_joystick = true
		root.add_child(js)
		await process_frame
		var started := [0]
		js.joystick_started.connect(func(): started[0] += 1)
		js.start_virtual_joystick_at(js.global_position + Vector2(60, 40))
		if not (js._vj_active and js.is_pressed and js.mouse_filter == Control.MOUSE_FILTER_IGNORE and started[0] == 1):
			fails.append("start_virtual_joystick_at activates, presses, ignores mouse, emits once")
		js.stop_virtual_joystick()
		if js._vj_active or js.is_pressed or js.mouse_filter != Control.MOUSE_FILTER_STOP:
			fails.append("stop_virtual_joystick restores state")
		js.queue_free()
		# lazy accessors
		if not b._accessor_cache.is_empty(): fails.append("accessors are not created until used")
		b.label.color = Color.RED
		if b.label_text_color != Color.RED: fails.append("label accessor writes through")
		if b.label != b.label: fails.append("accessor instance is reused")
		b.charge_up.duration = 0.25
		if not is_equal_approx(b.hold_duration, 0.25): fails.append("charge_up accessor writes through")
		b.hold_duration = 0.0
		# debug flag
		b.debugger_log = 1
		if not b._dbg: fails.append("debugger_log sets _dbg")
		b.debugger_log = 0
		if b._dbg: fails.append("debugger_log clears _dbg")
		if fails.is_empty():
			print("CHECKS passed")
		else:
			for f in fails: print("CHECK FAILED: ", f)
	quit()

## demo style load: properties set before entering the tree, like a .tscn instance.
## same_text is like a hotbar (every button says "Use"), otherwise every label is different.
func _bench_load(icon_tex: Texture2D, style: StyleBox, same_text: bool) -> void:
	var nodes0 := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var objs0 := Performance.get_monitor(Performance.OBJECT_COUNT)
	var tl0 := Time.get_ticks_usec()
	var demo_buttons: Array = []
	for i in 200:
		var db = OmniButtonScript.new()
		db.size = Vector2(100, 50)
		db.background_type = 1
		db.panel_style_box = style
		db.icon_texture = icon_tex
		db.text = "Use" if same_text else "Demo button %d" % i
		db.invert_modes = 1
		root.add_child(db)
		demo_buttons.append(db)
	var t_add := float(Time.get_ticks_usec() - tl0) / 1000.0
	for _f in 8:
		await process_frame
	var t_total := float(Time.get_ticks_usec() - tl0) / 1000.0
	var nodes_per := (Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes0) / 200.0
	var objs_per := (Performance.get_monitor(Performance.OBJECT_COUNT) - objs0) / 200.0
	print("BENCH load 200 %s buttons: add_child %.2f ms, settled %.2f ms, %.1f nodes + %.1f objects live per button" % ["same-text" if same_text else "unique-text", t_add, t_total, nodes_per, objs_per])
	for db in demo_buttons: db.queue_free()
	await process_frame
