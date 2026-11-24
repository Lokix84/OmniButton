extends SceneTree
# draws a grid of OmniButtons that covers every visual they make and saves png snapshots, so you can
# compare before and after a rendering change. dev tool, not needed at runtime.
# needs a real renderer (not --headless).
# usage: godot --path . -s res://addons/omni_button/dev/OmniButtonSnapshot.gd -- <out_dir>

const OmniButtonScript = preload("res://addons/omni_button/omni_button.gd")
const ICON := preload("res://addons/omni_button/demo/icons/Icon-Potion6.png")
const WIDE := preload("res://addons/omni_button/OmniButtonGDV1.png")

var _out_dir := ""
var _x := 10.0
var _y := 10.0
var _all: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _cell(cfg: Callable, w := 100.0, h := 50.0) -> Control:
	var b = OmniButtonScript.new()
	b.position = Vector2(_x, _y)
	b.size = Vector2(w, h)
	cfg.call(b)
	root.add_child(b)
	_all.append(b)
	_x += w + 12.0
	if _x > 1040.0:
		_x = 10.0
		_y += 74.0
	return b

func _flat(c: Color, radius := 6, border := 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = c
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = Color.WHITE
	return s

func _run() -> void:
	_out_dir = OS.get_cmdline_user_args()[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	root.size = Vector2i(1152, 648)
	var bg := ColorRect.new()
	bg.color = Color(0.15, 0.17, 0.2)
	bg.size = Vector2(1152, 648)
	root.add_child(bg)

	# panels: default theme, custom style, each state style.
	_cell(func(b): b.background_type = 1)
	_cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.STEEL_BLUE, 10, 2); b.panel_modulate = Color(1, 0.8, 0.8))
	var hov := _cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.DIM_GRAY); b.panel_hover_style_box = _flat(Color.SEA_GREEN))
	var prs := _cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.DIM_GRAY); b.panel_pressed_style_box = _flat(Color.FIREBRICK))
	_cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.DIM_GRAY); b.panel_disabled_style_box = _flat(Color.BLACK, 2, 1); b.disabled = true)
	# background textures: every stretch mode, a non square texture, flips, modulate.
	for stretch in 7:
		_cell(func(b): b.background_type = 2; b.texture = WIDE; b.stretch_mode = stretch; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE)
	_cell(func(b): b.background_type = 2; b.texture = WIDE; b.stretch_mode = 0; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; b.flip_h = true; b.background_modulate = Color(0.6, 1, 0.6))
	_cell(func(b): b.background_type = 2; b.texture = WIDE; b.stretch_mode = 6; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; b.flip_v = true)
	# background expand modes (what they do to the minimum size), default stretch.
	for expand in 6:
		_cell(func(b): b.background_type = 2; b.texture = WIDE; b.expand_mode = expand)
	# icons: stretch modes, flips, modulate, expand modes.
	for stretch in 7:
		_cell(func(b): b.icon_texture = ICON; b.icon_stretch_mode = stretch; b.icon_expand_mode = TextureRect.EXPAND_IGNORE_SIZE)
	_cell(func(b): b.icon_texture = ICON; b.icon_flip_h = true; b.icon_flip_v = true; b.icon_modulate = Color(1, 0.5, 0.5); b.icon_expand_mode = 1; b.icon_stretch_mode = 5)
	for expand in 6:
		_cell(func(b): b.icon_texture = WIDE; b.icon_expand_mode = expand; b.icon_stretch_mode = 0)
	# icon + panel + label, selected overlay, invert on press.
	_cell(func(b): b.background_type = 1; b.icon_texture = ICON; b.icon_expand_mode = 1; b.icon_stretch_mode = 5; b.text = "Label")
	_cell(func(b): b.background_type = 1; b.icon_texture = ICON; b.icon_expand_mode = 1; b.icon_stretch_mode = 5; b.selected = true; b.selected_color = Color(1, 1, 0, 0.35))
	var inv := _cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.ROYAL_BLUE); b.icon_texture = ICON; b.icon_expand_mode = 1; b.icon_stretch_mode = 5; b.text = "Invert"; b.invert_modes = 1)
	# cooldown fill in every direction, filling and draining. hold fill in every direction.
	var cds: Array = []
	for dir in 4:
		for filled in [false, true]:
			cds.append(_cell(func(b): b.background_type = 1; b.cooldown_trigger = 1; b.cooldown_duration = 10.0; b.cooldown_fill_direction = dir; b.cooldown_start_filled = filled; b.cooldown_color = Color(0, 0, 0, 0.6)))
	var holds: Array = []
	for dir in 4:
		holds.append(_cell(func(b): b.background_type = 1; b.hold_duration = 1.0; b.hold_fill_direction = dir; b.hold_fill_color = Color(1, 1, 1, 0.5)))
	# virtual joystick default thumb.
	_cell(func(b): b.enable_virtual_joystick = true; b.default_thumb_color = Color(0.9, 0.6, 0.2, 0.9), 80, 80)
	# managed visuals above / below a child you added.
	for on_top in [true, false]:
		_cell(func(b):
			var deco := ColorRect.new()
			deco.color = Color(0.2, 0.9, 0.9)
			deco.position = Vector2(20, 10)
			deco.size = Vector2(60, 30)
			b.add_child(deco)
			b.background_type = 1
			b.panel_style_box = _flat(Color.MEDIUM_PURPLE)
			b.managed_draw_on_top = on_top)
	# hover scaled button (settled).
	var hover_scaled := _cell(func(b): b.background_type = 1; b.panel_style_box = _flat(Color.DARK_ORANGE); b.icon_texture = ICON; b.icon_expand_mode = 1; b.icon_stretch_mode = 5; b.hover_scale = 1.25)

	for _f in 10:
		await process_frame
	# freeze the interaction states.
	hov.is_hovering = true
	prs.is_pressed = true
	inv.is_pressed = true
	OmniButtonInput.on_mouse_entered(hover_scaled)
	for i in cds.size():
		var b = cds[i]
		OmniButtonTiming.begin_cooldown_now(b)
		b._cooldown_time_left = 10.0 * 0.6
		OmniButtonTiming.update_cooldown_visual(b)
	for b in holds:
		b.is_pressed = true
		b._hold_timer = 0.4
		OmniButtonTiming.update_hold_fill_visual(b)
	for _f in 40:
		for b in [hover_scaled]:
			b._process(0.05)
		await process_frame
	for b in _all:
		b.set_process(false)
	for i in cds.size():
		cds[i]._cooldown_time_left = 10.0 * 0.6
		OmniButtonTiming.update_cooldown_visual(cds[i])
	for b in holds:
		b._hold_timer = 0.4
		OmniButtonTiming.update_hold_fill_visual(b)
	for _f in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join("grid.png"))

	# demo scene, with the typewriter done so the frame comes out the same every time.
	for b in _all:
		b.queue_free()
	bg.queue_free()
	var demo := (load("res://addons/omni_button/demo/omni_button_demo.tscn") as PackedScene).instantiate()
	root.add_child(demo)
	for _f in 10:
		await process_frame
	var text_block := demo.get_node("%TextBlock")
	text_block.skip_typewriter()
	for _f in 10:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(_out_dir.path_join("demo.png"))
	print("snapshots saved to ", _out_dir)
	quit()
