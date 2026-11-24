extends SceneTree
# Renders a grid of OmniButtons covering every generated visual and saves PNG snapshots, so the
# output before and after a rendering change can be compared. Dev tool; not needed at runtime.
# Needs a real renderer (not --headless).
# Usage: godot --path . -s res://addons/omni_button/dev/OmniButtonSnapshot.gd -- <out_dir>

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

	# Panels: default theme, custom style, each state style.
	_cell(func(b): b.BackgroundType = 1)
	_cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.STEEL_BLUE, 10, 2); b.PanelModulate = Color(1, 0.8, 0.8))
	var hov := _cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.DIM_GRAY); b.PanelHoverStyleBox = _flat(Color.SEA_GREEN))
	var prs := _cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.DIM_GRAY); b.PanelPressedStyleBox = _flat(Color.FIREBRICK))
	_cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.DIM_GRAY); b.PanelDisabledStyleBox = _flat(Color.BLACK, 2, 1); b.Disabled = true)
	# Background textures: every stretch mode, a non-square texture, flips, modulate.
	for stretch in 7:
		_cell(func(b): b.BackgroundType = 2; b.texture = WIDE; b.stretch_mode = stretch; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE)
	_cell(func(b): b.BackgroundType = 2; b.texture = WIDE; b.stretch_mode = 0; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; b.flip_h = true; b.BackgroundModulate = Color(0.6, 1, 0.6))
	_cell(func(b): b.BackgroundType = 2; b.texture = WIDE; b.stretch_mode = 6; b.expand_mode = TextureRect.EXPAND_IGNORE_SIZE; b.flip_v = true)
	# Background expand modes (minimum-size effects), default stretch.
	for expand in 6:
		_cell(func(b): b.BackgroundType = 2; b.texture = WIDE; b.expand_mode = expand)
	# Icons: stretch modes, flips, modulate, expand modes.
	for stretch in 7:
		_cell(func(b): b.IconTexture = ICON; b.IconStretchMode = stretch; b.IconExpandMode = TextureRect.EXPAND_IGNORE_SIZE)
	_cell(func(b): b.IconTexture = ICON; b.IconFlipH = true; b.IconFlipV = true; b.IconModulate = Color(1, 0.5, 0.5); b.IconExpandMode = 1; b.IconStretchMode = 5)
	for expand in 6:
		_cell(func(b): b.IconTexture = WIDE; b.IconExpandMode = expand; b.IconStretchMode = 0)
	# Icon + panel + label, selection overlay, invert on press.
	_cell(func(b): b.BackgroundType = 1; b.IconTexture = ICON; b.IconExpandMode = 1; b.IconStretchMode = 5; b.Text = "Label")
	_cell(func(b): b.BackgroundType = 1; b.IconTexture = ICON; b.IconExpandMode = 1; b.IconStretchMode = 5; b.Selected = true; b.SelectedColor = Color(1, 1, 0, 0.35))
	var inv := _cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.ROYAL_BLUE); b.IconTexture = ICON; b.IconExpandMode = 1; b.IconStretchMode = 5; b.Text = "Invert"; b.InvertModes = 1)
	# Cooldown fill: every direction, filled and draining. Hold fill: every direction.
	var cds: Array = []
	for dir in 4:
		for filled in [false, true]:
			cds.append(_cell(func(b): b.BackgroundType = 1; b.CooldownTrigger = 1; b.CooldownDuration = 10.0; b.CooldownFillDirection = dir; b.CooldownStartFilled = filled; b.CooldownColor = Color(0, 0, 0, 0.6)))
	var holds: Array = []
	for dir in 4:
		holds.append(_cell(func(b): b.BackgroundType = 1; b.HoldDuration = 1.0; b.HoldFillDirection = dir; b.HoldFillColor = Color(1, 1, 1, 0.5)))
	# Virtual joystick default thumb.
	_cell(func(b): b.EnableVirtualJoystick = true; b.DefaultThumbColor = Color(0.9, 0.6, 0.2, 0.9), 80, 80)
	# Managed visuals above / below a user child.
	for on_top in [true, false]:
		_cell(func(b):
			var deco := ColorRect.new()
			deco.color = Color(0.2, 0.9, 0.9)
			deco.position = Vector2(20, 10)
			deco.size = Vector2(60, 30)
			b.add_child(deco)
			b.BackgroundType = 1
			b.PanelStyleBox = _flat(Color.MEDIUM_PURPLE)
			b.ManagedDrawOnTop = on_top)
	# Hover-scaled button (settled).
	var hover_scaled := _cell(func(b): b.BackgroundType = 1; b.PanelStyleBox = _flat(Color.DARK_ORANGE); b.IconTexture = ICON; b.IconExpandMode = 1; b.IconStretchMode = 5; b.HoverScale = 1.25)

	for _f in 10:
		await process_frame
	# Freeze interaction states.
	hov.IsHovering = true
	prs.IsPressed = true
	inv.IsPressed = true
	OmniButtonInput.on_mouse_entered(hover_scaled)
	for i in cds.size():
		var b = cds[i]
		OmniButtonTiming.begin_cooldown_now(b)
		b._cooldown_time_left = 10.0 * 0.6
		OmniButtonTiming.update_cooldown_visual(b)
	for b in holds:
		b.IsPressed = true
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

	# Demo scene, with the typewriter finished so the frame is deterministic.
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
