@tool
class_name Omni_Button
extends Control

# Signals (parity with C# OmniButton)
signal pressed
signal released
signal hover_in
signal hover_out
signal toggled(pressed: bool)
signal hold
signal swipe(direction: Vector2)
signal log(message: String)
signal warning(message: String)
signal error(message: String)
signal joystick_started
signal joystick_axis(axis: Vector2)
signal joystick_ended

enum CooldownDirection { BottomToTop = 0, TopToBottom = 1, LeftToRight = 2, RightToLeft = 3 }

# State
@export_group("State")
var _disabled := false
@export var Disabled: bool:
	get: return _disabled
	set(value): _disabled = value; _invalidate_visual_state()

var _selected := false
@export var Selected: bool:
	get: return _selected
	set(value): _selected = value; _update_overlay(); _apply_visual_state()

var _is_toggled := false
@export var IsToggled: bool:
	get: return _is_toggled
	set(value): _is_toggled = value; _update_overlay(); _apply_visual_state()

var _is_pressed := false
@export var IsPressed: bool:
	get: return _is_pressed
	set(value):
		if _is_pressed == value:
			_apply_visual_state(); return
		var was := _is_pressed
		_is_pressed = value
		if (not was) and _is_pressed and EnableHoldBuildUp and not _is_holding:
			_hold_timer = 0.0; _ensure_hold_fill_rect(); _update_hold_fill_visual(); if is_instance_valid(_hold_fill): _hold_fill.visible = true; set_process(true)
		elif was and (not _is_pressed):
			_remove_hold_fill()
		_apply_visual_state()

var _is_hovering := false
@export var IsHovering: bool:
	get: return _is_hovering
	set(value): _is_hovering = value; _apply_visual_state()

var _is_holding := false
@export var IsHolding: bool:
	get: return _is_holding
	set(value):
		var was := _is_holding
		_is_holding = value
		if (not was) and _is_holding:
			_remove_hold_fill()
		_apply_visual_state()

# Content Display
@export_group("Content Display")
var _enable_panel := false
@export var EnablePanel: bool:
	get: return _enable_panel
	set(value):
		if _enable_panel == value: return
		_enable_panel = value
		if _enable_panel:
			_setup_children()
			_apply_panel_styling()
		else:
			_setup_children()
		_apply_visual_state()

var _icon_texture: Texture2D
@export var IconTexture: Texture2D:
	get: return _icon_texture
	set(value):
		_icon_texture = value
		_ensure_icon()
		_apply_visual_state()

var _label_text: String = ""
@export var LabelText: String:
	get: return _label_text
	set(value):
		_label_text = value if value != null else ""
		var lbl := _get_or_create_label()
		lbl.text = _label_text
		_apply_visual_state()
		_fit_label_text()

var _enable_selected_overlay := false
@export var EnableSelectedOverlay: bool:
	get: return _enable_selected_overlay
	set(value):
		if _enable_selected_overlay == value: return
		_enable_selected_overlay = value
		_update_overlay()
		_apply_visual_state()
@export var SelectedColor: Color = Color(1, 1, 1, 0.3)
@export var UnselectedColor: Color = Color(0, 0, 0, 0.2)

# Actions
@export_group("Actions")
@export_subgroup("Pressed")
@export var EnablePressedActions: bool = false
@export var PressedAction: Callable
@export_subgroup("Released")
@export var EnableReleasedActions: bool = false
@export var ReleasedAction: Callable
@export_subgroup("Hover")
@export var EnableHoverActions: bool = false
@export var HoverInAction: Callable
@export var HoverOutAction: Callable
@export_subgroup("Toggle")
@export var EnableToggleActions: bool = false
@export var ToggledAction: Callable
@export_subgroup("Hold")
@export var EnableHoldActions: bool = false
@export var HoldAction: Callable
@export_subgroup("Swipe")
@export var EnableSwipeActions: bool = false
@export var SwipeAction: Callable
@export_subgroup("Logging")
@export var EnableLogActions: bool = false
@export var LogAction: Callable
@export var EnableWarningActions: bool = false
@export var WarningAction: Callable
@export var EnableErrorActions: bool = false
@export var ErrorAction: Callable

# Input
@export_group("Input")
@export var BoundsSource: Control
@export var HitSlop: Vector2 = Vector2.ZERO

# Swipe & Hold
@export_group("Swipe & Hold")
@export_subgroup("Swipe")
@export_range(0.0, 1000.0, 1.0) var SwipeThreshold: float = 20.0
@export_subgroup("Hold")
@export_range(0.05, 5.0, 0.05) var HoldDuration: float = 0.5
@export var EnableHoldBuildUp: bool = false
@export var HoldFillColor: Color = Color(1, 1, 1, 0.25)
@export var HoldFillDirection: int = CooldownDirection.BottomToTop

# Follow Input
@export_group("Follow Input")
@export var FollowOnPress: bool = false
@export var FollowWhileHeld: bool = false
@export var ClampToBounds: bool = true

# Cooldown
@export_group("Cooldown")
@export var EnableCooldown: bool = false
@export_range(0.05, 60.0, 0.05) var CooldownDuration: float = 1.0
@export var CooldownOnPress: bool = false
@export var CooldownOnRelease: bool = false
@export var CooldownStartFilled: bool = false
@export var CooldownColor: Color = Color(0, 0, 0, 0.4)
@export var CooldownFillDirection: int = CooldownDirection.BottomToTop
@export var SuspendHoverScaleDuringCooldown: bool = false
@export var AllowHoldDuringCooldown: bool = false
@export var HideCooldownDuringHoldBuildUp: bool = true

# Hover Scaling
@export_group("Hover Scaling")
@export var EnableHoverScale: bool = false
@export_range(1.0, 3.0, 0.01) var HoverScale: float = 1.25
@export_range(0.0, 100.0, 0.1) var HoverLerpSpeed: float = 25.0

# Label Settings
@export_group("Label Settings")
@export var LabelFont: Font
@export var LabelTextColor: Color = Color.WHITE
@export_range(6, 300, 1) var MinFontSize: int = 12
@export_range(6, 300, 1) var MaxFontSize: int = 100
@export var LabelHorizontalAlignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var LabelVerticalAlignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
@export var LabelAutowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_WORD

# Panel Settings
@export_group("Panel Settings")
@export var PanelThemeType: String = "Panel"
@export var PanelThemeVariation: String = ""
@export var PanelStyleBox: StyleBox

# Icon Settings
@export_group("Icon Settings")
@export var IconExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var IconStretchMode: int = TextureRect.STRETCH_SCALE
@export var IconFlipH: bool = false
@export var IconFlipV: bool = false

# Invert Display
@export_group("Invert Display")
@export var InvertDisplayOnPress: bool = false
@export var InvertDisplayOnToggle: bool = false
@export var InvertDisplayOnHover: bool = false

# Virtual Joystick
@export_group("Virtual Joystick")
@export var EnableVirtualJoystick: bool = false
@export var JoystickUseCircularClamp: bool = true
@export_range(0, 4096, 1) var JoystickRadiusPx: int = 0
@export var JoystickRectSizePx: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var JoystickDeadzone: float = 0.1
@export var JoystickSnapToInput: bool = true
@export var JoystickHideWhenInactive: bool = false
@export var JoystickResetOnRelease: bool = true

# Private state and caches
var _hover_target_scale := 1.0
var _hold_timer := 0.0
var _cooldown_active := false
var _cooldown_time_left := 0.0
var _swipe_start := Vector2.ZERO
var _hover_top_level_active := false
var _saved_global_pos := Vector2.ZERO
var _vj_active := false
var _vj_home_global := Vector2.ZERO
var _panel: Panel
var _icon: TextureRect
var _label: Label
var _overlay: ColorRect
var _cooldown: ColorRect
var _hold_fill: ColorRect
var _invert_material: ShaderMaterial
var _fitting_label := false
var _last_visual_state: String
var _theme_applying := false
# Lifecycle
func _enter_tree() -> void:
	_initialize_callables()
	if not Engine.is_editor_hint():
		_connect_signals()
	_connect_mouse_events()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	if EnableSelectedOverlay and Selected and not EnablePanel:
		EnablePanel = true
	var shader_path = "res://addons/omni_button/Shader/InvertColor.tres"
	if ResourceLoader.exists(shader_path):
		_invert_material = load(shader_path)
	_setup_children()
	_apply_panel_styling()
	_apply_visual_state()
	_fit_label_text()
	if not Engine.is_editor_hint() and EnableVirtualJoystick and JoystickHideWhenInactive:
		visible = false

func _exit_tree() -> void:
	_disconnect_all_signal_handlers()
	_panel = null; _icon = null; _label = null; _overlay = null; _cooldown = null; _hold_fill = null

func _process(delta: float) -> void:
	# Hold progression
	if _is_pressed and (not EnableCooldown or not _cooldown_active or AllowHoldDuringCooldown or EnableHoldBuildUp):
		_hold_timer += delta
		if not _is_holding and _hold_timer >= HoldDuration:
			_is_holding = true
			if EnableHoldActions: emit_signal("hold"); if HoldAction.is_valid(): HoldAction.call()
			_remove_hold_fill()
		if EnableHoldBuildUp:
			if not _is_holding: _update_hold_fill_visual()
			else: _remove_hold_fill()
	elif EnableHoldBuildUp:
		_remove_hold_fill()

	# Hover scaling
	if EnableHoverScale:
		if EnableCooldown and _cooldown_active and SuspendHoverScaleDuringCooldown:
			var t_reset := min(1.0, delta * HoverLerpSpeed)
			_lerp_scale_to(_panel, Vector2.ONE, t_reset)
			_lerp_scale_to(_icon, Vector2.ONE, t_reset)
			_lerp_scale_to(_label, Vector2.ONE, t_reset)
			_lerp_scale_to(_overlay, Vector2.ONE, t_reset)
			_enable_top_level(false)
		else:
			var target := Vector2.ONE * _hover_target_scale
			var t := min(1.0, delta * HoverLerpSpeed)
			var any := false
			any = _lerp_scale_to(_panel, target, t) or any
			any = _lerp_scale_to(_icon, target, t) or any
			any = _lerp_scale_to(_label, target, t) or any
			any = _lerp_scale_to(_overlay, target, t) or any
			var hold_build := EnableHoldBuildUp and _is_pressed and not _is_holding
			if not any and not _is_hovering and not (_cooldown_active and EnableCooldown) and not hold_build:
				set_process(false)
				_enable_top_level(false)
	else:
		var t2 := min(1.0, delta * HoverLerpSpeed)
		var any2 := false
		any2 = _lerp_scale_to(_panel, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_icon, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_label, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_overlay, Vector2.ONE, t2) or any2
		var hold_build2 := EnableHoldBuildUp and _is_pressed and not _is_holding
		if not any2 and not (_cooldown_active and EnableCooldown) and not hold_build2:
			set_process(false)
			_enable_top_level(false)

	# Hide cooldown during buildup
	if HideCooldownDuringHoldBuildUp and is_instance_valid(_cooldown):
		var hold_active := EnableHoldBuildUp and _is_pressed and not _is_holding
		if hold_active: _cooldown.visible = false
		elif _cooldown_active: _cooldown.visible = true

	# Cooldown tick
	if _cooldown_active:
		_cooldown_time_left = max(0.0, _cooldown_time_left - delta)
		_update_cooldown_visual()
		if _cooldown_time_left <= 0.0:
			_cooldown_active = false
			if is_instance_valid(_cooldown): _cooldown.visible = false
			if is_instance_valid(_cooldown): _cooldown.size = Vector2.ZERO; _cooldown.position = Vector2.ZERO

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_fit_label_text()
			if EnablePanel: queue_redraw()
			if _is_hovering and EnableHoverScale:
				_update_hover_pivots(); _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_THEME_CHANGED:
			if theme != null: _apply_theme_to_children()
			_last_visual_state = ""; _apply_theme_now(); _apply_panel_styling(); _fit_label_text()
			if _is_hovering and EnableHoverScale: _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree(): _is_pressed = false; _is_hovering = false; _invalidate_visual_state()
		NOTIFICATION_PREDELETE:
			_exit_tree()


# Input and hover handlers
func _gui_input(event: InputEvent) -> void:
	if _disabled: return
	var inside := _input_inside(event)
	if EnableCooldown and _cooldown_active: return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if not inside: return
			_is_pressed = true
			_hold_timer = 0.0
			_is_holding = false

			if EnableVirtualJoystick:
				_vj_active = true
				_vj_home_global = global_position + size * 0.5
				_enable_top_level(true)
				if JoystickSnapToInput: _move_to_global(mb.global_position)
				if JoystickHideWhenInactive: visible = true
				emit_signal("joystick_started")
				_emit_joystick_axis_for(mb.global_position)
			elif FollowOnPress:
				_enable_top_level(true)
				_move_to_global(mb.global_position)

			if EnableSwipeActions: _swipe_start = mb.position
			if EnablePressedActions:
				emit_signal("pressed")
				if PressedAction.is_valid(): PressedAction.call()
			if EnableToggleActions:
				_is_toggled = not _is_toggled
				_update_overlay()
				emit_signal("toggled", _is_toggled)
				if ToggledAction.is_valid(): ToggledAction.call(_is_toggled)
			if EnableCooldown and CooldownOnPress:
				call_deferred("_start_cooldown")
			if EnableHoldBuildUp and not _is_holding:
				_hold_timer = 0.0
				_ensure_hold_fill_rect()
				_update_hold_fill_visual()
				if is_instance_valid(_hold_fill): _hold_fill.visible = true
				set_process(true)
			_apply_visual_state()
		else:
			_is_pressed = false
			_swipe_start = Vector2.ZERO
			if EnableReleasedActions and inside:
				emit_signal("released")
				if ReleasedAction.is_valid(): ReleasedAction.call()
			if EnableCooldown and CooldownOnRelease:
				_start_cooldown()
			if is_instance_valid(_hold_fill): _remove_hold_fill()

			if _vj_active:
				emit_signal("joystick_axis", Vector2.ZERO)
				emit_signal("joystick_ended")
				if JoystickResetOnRelease:
					global_position = _vj_home_global - size * 0.5
				if JoystickHideWhenInactive:
					visible = false
				_vj_active = false
			_enable_top_level(false)
			_apply_visual_state()

	elif _is_pressed and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if EnableVirtualJoystick and _vj_active:
			if JoystickSnapToInput:
				_move_to_global(mm.global_position)
			_emit_joystick_axis_for(mm.global_position)
		elif FollowWhileHeld:
			_move_to_global(mm.global_position)

	elif _is_pressed and event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if EnableVirtualJoystick and _vj_active:
			if JoystickSnapToInput:
				_move_to_global(sd.position)
			_emit_joystick_axis_for(sd.position)
		elif FollowWhileHeld:
			_move_to_global(sd.position)

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var gp := global_position + st.position
		if st.pressed and inside:
			_is_pressed = true
			_hold_timer = 0.0
			_is_holding = false
			if EnableVirtualJoystick:
				_vj_active = true
				_vj_home_global = global_position + size * 0.5
				_enable_top_level(true)
				if JoystickSnapToInput: _move_to_global(gp)
				if JoystickHideWhenInactive: visible = true
				emit_signal("joystick_started")
				_emit_joystick_axis_for(gp)
			elif FollowOnPress:
				_enable_top_level(true)
				_move_to_global(gp)
			if EnablePressedActions:
				emit_signal("pressed")
				if PressedAction.is_valid(): PressedAction.call()
			_apply_visual_state()
		elif not st.pressed:
			_is_pressed = false
			if EnableReleasedActions and inside:
				emit_signal("released")
				if ReleasedAction.is_valid(): ReleasedAction.call()
			if _vj_active:
				emit_signal("joystick_axis", Vector2.ZERO)
				emit_signal("joystick_ended")
				if JoystickResetOnRelease:
					global_position = _vj_home_global - size * 0.5
				if JoystickHideWhenInactive:
					visible = false
				_vj_active = false
			_enable_top_level(false)
			_apply_visual_state()

	# Swipe via drag or motion
	if EnableSwipeActions and event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _swipe_start == Vector2.ZERO:
			_swipe_start = drag.position
		else:
			var direction := drag.position - _swipe_start
			if direction.length() > SwipeThreshold:
				emit_signal("swipe", direction.normalized())
				if SwipeAction.is_valid(): SwipeAction.call(direction.normalized())
				_swipe_start = Vector2.ZERO
	elif EnableSwipeActions and _is_pressed and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _swipe_start == Vector2.ZERO:
			_swipe_start = motion.position
		else:
			var direction2 := motion.position - _swipe_start
			if direction2.length() > SwipeThreshold:
				emit_signal("swipe", direction2.normalized())
				if SwipeAction.is_valid(): SwipeAction.call(direction2.normalized())
				_swipe_start = Vector2.ZERO

func _connect_mouse_events() -> void:
	_connect_if_not_connected("mouse_entered", Callable(self, "_on_mouse_entered"))
	_connect_if_not_connected("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_mouse_entered() -> void:
	if _disabled: return
	_is_hovering = true
	if EnableHoverActions and not (EnableCooldown and _cooldown_active):
		emit_signal("hover_in")
		if HoverInAction.is_valid(): HoverInAction.call()
	if EnableHoverScale:
		if not (EnableCooldown and _cooldown_active and SuspendHoverScaleDuringCooldown):
			_update_hover_pivots()
			_hover_target_scale = _hover_target_for_viewport()
			_enable_top_level(true)
		set_process(true)
	_invalidate_visual_state()

func _on_mouse_exited() -> void:
	if _disabled: return
	_is_hovering = false
	if EnableHoverActions and not (EnableCooldown and _cooldown_active):
		emit_signal("hover_out")
		if HoverOutAction.is_valid(): HoverOutAction.call()
	if EnableHoverScale:
		if not (EnableCooldown and _cooldown_active and SuspendHoverScaleDuringCooldown):
			_update_hover_pivots()
			_hover_target_scale = 1.0
		set_process(true)
	_invalidate_visual_state()

# Children management and visuals
func _setup_children() -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_panel = null
	_icon = null
	_label = null
	_overlay = null
	_cooldown = null
	_hold_fill = null

	if _enable_panel:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
		_ensure_full_rect(_panel)
		_panel.mouse_filter = MOUSE_FILTER_PASS

	if _icon_texture != null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.texture = _icon_texture
		_icon.expand_mode = IconExpandMode
		_icon.stretch_mode = IconStretchMode
		_icon.flip_h = IconFlipH
		_icon.flip_v = IconFlipV
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_icon)
		_ensure_full_rect(_icon)

	if _label_text != "":
		_label = Label.new()
		_label.name = "Label"
		_label.text = _label_text
		add_child(_label)
		_configure_label(_label)

	_update_overlay()

	if EnableCooldown and (_cooldown_active or Engine.is_editor_hint()):
		_ensure_cooldown()
		_update_cooldown_visual()

	_reorder_children()

func _update_overlay() -> void:
	var need := _enable_selected_overlay and (_selected or _is_toggled)
	var alive := _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == self
	if need and not alive:
		_overlay = ColorRect.new()
		_overlay.name = "Overlay"
		_overlay.color = (SelectedColor if Selected else UnselectedColor)
		add_child(_overlay)
		_ensure_full_rect(_overlay)
	elif (not need) and alive:
		remove_child(_overlay)
		_overlay.queue_free()
		_overlay = null

func _ensure_cooldown() -> void:
	if _cooldown == null or not is_instance_valid(_cooldown):
		_cooldown = ColorRect.new()
		_cooldown.name = "Cooldown"
		_cooldown.color = CooldownColor
		_cooldown.mouse_filter = MOUSE_FILTER_PASS
		add_child(_cooldown)

func _ensure_hold_fill_rect() -> void:
	if _hold_fill == null or not is_instance_valid(_hold_fill):
		_hold_fill = ColorRect.new()
		_hold_fill.name = "HoldFill"
		_hold_fill.color = HoldFillColor
		_hold_fill.mouse_filter = MOUSE_FILTER_PASS
		add_child(_hold_fill)
		_hold_fill.set_anchors_preset(PRESET_TOP_LEFT)

func _remove_hold_fill() -> void:
	if is_instance_valid(_hold_fill):
		_hold_fill.visible = false
		_hold_fill.size = Vector2.ZERO
		_hold_fill.position = Vector2.ZERO

func _reorder_children() -> void:
	var idx := 0
	if _panel != null: move_child(_panel, idx); idx += 1
	if _icon != null: move_child(_icon, idx); idx += 1
	if _label != null: move_child(_label, idx); idx += 1
	if _overlay != null: move_child(_overlay, idx); idx += 1
	if _cooldown != null: move_child(_cooldown, idx); idx += 1
	if _hold_fill != null: move_child(_hold_fill, idx); idx += 1

func _configure_label(lbl: Label) -> void:
	# Fill parent and zero offsets so it truly stretches
	lbl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.size_flags_vertical = SIZE_EXPAND_FILL
	# Respect configured alignment and wrap
	lbl.horizontal_alignment = LabelHorizontalAlignment
	lbl.vertical_alignment = LabelVerticalAlignment
	lbl.autowrap_mode = LabelAutowrap
	# Apply optional font override
	if LabelFont != null:
		lbl.add_theme_font_override("font", LabelFont)

func _fit_label_text() -> void:
	if _fitting_label or _label == null or not is_instance_valid(_label) or _label.text == "":
		return
	_fitting_label = true
	var avail := size - Vector2(8, 8)
	if avail.x <= 1.0 or avail.y <= 1.0:
		_fitting_label = false
		return
	var fnt: Font = _label.get_theme_font("font") if _label.get_theme_font("font") != null else ThemeDB.fallback_font
	if fnt == null:
		_fitting_label = false
		return
	var best := MinFontSize
	for s in range(MinFontSize, MaxFontSize + 1):
		var ts := fnt.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s)
		if ts.x <= avail.x and ts.y <= avail.y:
			best = s
		else:
			break
	_label.add_theme_font_override("font", fnt)
	_label.add_theme_font_size_override("font_size", best)
	_fitting_label = false

func _ensure_full_rect(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	node.size_flags_vertical = SIZE_EXPAND_FILL

func _update_hover_pivots() -> void:
	pivot_offset = size / 2.0
	if _icon != null and is_instance_valid(_icon): _icon.pivot_offset = _icon.size / 2.0
	if _label != null and is_instance_valid(_label): _label.pivot_offset = _label.size / 2.0
	if _overlay != null and is_instance_valid(_overlay): _overlay.pivot_offset = _overlay.size / 2.0

func _hover_target_for_viewport() -> float:
	var desired := HoverScale
	var rect := get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 1.0
	var vp := get_viewport_rect()
	var center := rect.position + rect.size * 0.5
	var half_w := max(0.001, rect.size.x * 0.5)
	var half_h := max(0.001, rect.size.y * 0.5)
	var left_space := center.x - vp.position.x
	var right_space := vp.position.x + vp.size.x - center.x
	var top_space := center.y - vp.position.y
	var bottom_space := vp.position.y + vp.size.y - center.y
	var max_scale_x := min(left_space / half_w, right_space / half_w)
	var max_scale_y := min(top_space / half_h, bottom_space / half_h)
	return min(desired, max(1.0, min(max_scale_x, max_scale_y)))

func _lerp_scale_to(node: Control, target: Vector2, t: float) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var new_scale := node.scale.lerp(target, t)
	var changed := new_scale.distance_to(target) >= 0.001
	node.scale = new_scale
	if not changed:
		node.scale = target
	return changed

func _enable_top_level(enable: bool) -> void:
	if enable and not _hover_top_level_active:
		_saved_global_pos = global_position
		top_level = true
		global_position = _saved_global_pos
		_hover_top_level_active = true
	elif (not enable) and _hover_top_level_active:
		var gp := global_position
		top_level = false
		global_position = gp
		_hover_top_level_active = false

# Ensure helpers for dynamic creation
func _ensure_icon() -> void:
	if _icon == null or not is_instance_valid(_icon):
		if _icon_texture == null:
			return
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.texture = _icon_texture
		_icon.expand_mode = IconExpandMode
		_icon.stretch_mode = IconStretchMode
		_icon.flip_h = IconFlipH
		_icon.flip_v = IconFlipV
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_icon)
		_ensure_full_rect(_icon)

func _get_or_create_label() -> Label:
	if _label == null or not is_instance_valid(_label):
		_label = Label.new()
		_label.name = "Label"
		add_child(_label)
		_configure_label(_label)
	return _label

func _input_inside(event: InputEvent) -> bool:
	var src := BoundsSource if (is_instance_valid(BoundsSource) and BoundsSource != null) else self
	var rect := src.get_global_rect()
	if HitSlop != Vector2.ZERO:
		rect = rect.grow_individual(HitSlop.x, HitSlop.y, HitSlop.x, HitSlop.y)
	if event is InputEventMouseButton:
		return rect.has_point((event as InputEventMouseButton).global_position)
	if event is InputEventMouseMotion:
		return rect.has_point((event as InputEventMouseMotion).global_position)
	if event is InputEventScreenTouch:
		return rect.has_point(global_position + (event as InputEventScreenTouch).position)
	if event is InputEventScreenDrag:
		return rect.has_point((event as InputEventScreenDrag).position)
	return false

# Virtual joystick helpers
func _move_to_global(global_point: Vector2) -> void:
	var half := size * 0.5
	if _vj_active and JoystickUseCircularClamp:
		var clamp := (BoundsSource if (is_instance_valid(BoundsSource) and BoundsSource != null) else self).get_global_rect()
		var pointer := global_point
		var radius: float = float(JoystickRadiusPx) if JoystickRadiusPx > 0 else _compute_auto_joystick_radius(_vj_home_global, clamp)
		var delta := pointer - _vj_home_global
		var len := delta.length()
		if len > radius and len > 0.0001:
			pointer = _vj_home_global + delta / len * radius
		pointer.x = clampf(pointer.x, clamp.position.x, clamp.position.x + clamp.size.x)
		pointer.y = clampf(pointer.y, clamp.position.y, clamp.position.y + clamp.size.y)
		global_position = pointer - half
		return

	if _vj_active and not JoystickUseCircularClamp:
		var clamp2 := (BoundsSource if (is_instance_valid(BoundsSource) and BoundsSource != null) else self).get_global_rect()
		var pointer2 := global_point
		var half_ext := (JoystickRectSizePx / 2.0) if JoystickRectSizePx != Vector2.ZERO else _compute_auto_joystick_half_extents(_vj_home_global, clamp2)
		pointer2.x = clampf(pointer2.x, _vj_home_global.x - half_ext.x, _vj_home_global.x + half_ext.x)
		pointer2.y = clampf(pointer2.y, _vj_home_global.y - half_ext.y, _vj_home_global.y + half_ext.y)
		pointer2.x = clampf(pointer2.x, clamp2.position.x, clamp2.position.x + clamp2.size.x)
		pointer2.y = clampf(pointer2.y, clamp2.position.y, clamp2.position.y + clamp2.size.y)
		global_position = pointer2 - half
		return

	var desired := global_point - half
	if ClampToBounds:
		var bounds := (BoundsSource if (is_instance_valid(BoundsSource) and BoundsSource != null) else self).get_global_rect()
		desired.x = clampf(desired.x, bounds.position.x, bounds.position.x + bounds.size.x - size.x)
		desired.y = clampf(desired.y, bounds.position.y, bounds.position.y + bounds.size.y - size.y)
	global_position = desired

func _emit_joystick_axis_for(pointer_global: Vector2) -> void:
	var clamp_rect := (BoundsSource if (is_instance_valid(BoundsSource) and BoundsSource != null) else self).get_global_rect()
	if HitSlop != Vector2.ZERO:
		clamp_rect = clamp_rect.grow_individual(HitSlop.x, HitSlop.y, HitSlop.x, HitSlop.y)
	var clamped := Vector2(
		clampf(pointer_global.x, clamp_rect.position.x, clamp_rect.position.x + clamp_rect.size.x),
		clampf(pointer_global.y, clamp_rect.position.y, clamp_rect.position.y + clamp_rect.size.y)
	)
	var delta := clamped - _vj_home_global
	var axis := Vector2.ZERO
	if JoystickUseCircularClamp:
		var radius: float = float(JoystickRadiusPx) if JoystickRadiusPx > 0 else _compute_auto_joystick_radius(_vj_home_global, clamp_rect)
		if radius <= 0.001:
			emit_signal("joystick_axis", Vector2.ZERO)
			return
		axis = delta / radius
		if axis.length() > 1.0:
			axis = axis.normalized()
	else:
		var half_ext := (JoystickRectSizePx / 2.0) if JoystickRectSizePx != Vector2.ZERO else _compute_auto_joystick_half_extents(_vj_home_global, clamp_rect)
		if half_ext.x <= 0.001 or half_ext.y <= 0.001:
			emit_signal("joystick_axis", Vector2.ZERO)
			return
		axis = Vector2(delta.x / half_ext.x, delta.y / half_ext.y)
		axis.x = clampf(axis.x, -1.0, 1.0)
		axis.y = clampf(axis.y, -1.0, 1.0)
	if axis.length() < JoystickDeadzone:
		axis = Vector2.ZERO
	emit_signal("joystick_axis", axis)

func _compute_auto_joystick_radius(home_center_global: Vector2, clamp_rect: Rect2) -> float:
	var left := home_center_global.x - clamp_rect.position.x
	var right := (clamp_rect.position.x + clamp_rect.size.x) - home_center_global.x
	var top := home_center_global.y - clamp_rect.position.y
	var bottom := (clamp_rect.position.y + clamp_rect.size.y) - home_center_global.y
	return max(0.0, min(left, right, top, bottom))

func _compute_auto_joystick_half_extents(home_center_global: Vector2, clamp_rect: Rect2) -> Vector2:
	var left := home_center_global.x - clamp_rect.position.x
	var right := (clamp_rect.position.x + clamp_rect.size.x) - home_center_global.x
	var top := home_center_global.y - clamp_rect.position.y
	var bottom := (clamp_rect.position.y + clamp_rect.size.y) - home_center_global.y
	return Vector2(max(0.0, min(left, right)), max(0.0, min(top, bottom)))

func start_virtual_joystick_at(global_point: Vector2) -> void:
	if not EnableVirtualJoystick: return
	_vj_active = true
	_vj_home_global = global_position + size * 0.5
	_enable_top_level(true)
	if JoystickSnapToInput: _move_to_global(global_point)
	if JoystickHideWhenInactive: visible = true
	emit_signal("joystick_started")
	_emit_joystick_axis_for(global_point)

func update_virtual_joystick(global_point: Vector2) -> void:
	if not _vj_active: return
	if JoystickSnapToInput: _move_to_global(global_point)
	_emit_joystick_axis_for(global_point)

func stop_virtual_joystick() -> void:
	if not _vj_active: return
	emit_signal("joystick_axis", Vector2.ZERO)
	emit_signal("joystick_ended")
	if JoystickResetOnRelease:
		global_position = _vj_home_global - size * 0.5
	_vj_active = false
	_is_pressed = false
	_apply_visual_state()
	_enable_top_level(false)
	if JoystickHideWhenInactive: visible = false

func StartVirtualJoystickAt(global_point: Vector2) -> void: start_virtual_joystick_at(global_point)
func UpdateVirtualJoystick(global_point: Vector2) -> void: update_virtual_joystick(global_point)
func StopVirtualJoystick() -> void: stop_virtual_joystick()

func _apply_visual_state() -> void:
	if _enable_panel and _panel == null:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
		_ensure_full_rect(_panel)
		_apply_panel_styling()

	var overlay_alive := _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == self
	if EnableSelectedOverlay and (_selected or _is_toggled) and not overlay_alive:
		_overlay = ColorRect.new(); _overlay.name = "Overlay"; add_child(_overlay)

	if _enable_panel and _panel != null:
		_panel.visible = true
		_panel.modulate = Color.WHITE
		_apply_invert(_panel, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover)

	if _icon != null:
		_icon.texture = _icon_texture
		_icon.flip_h = IconFlipH
		_icon.flip_v = IconFlipV
		_icon.expand_mode = IconExpandMode
		_icon.stretch_mode = IconStretchMode
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_invert(_icon, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover)

	if _label != null:
		_label.text = _label_text
		_configure_label(_label)
		_label.add_theme_color_override("font_color", LabelTextColor)
		_apply_invert(_label, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover)

	if _enable_selected_overlay and _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = true
		_overlay.color = (SelectedColor if Selected else UnselectedColor)
		_apply_invert(_overlay, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover)

	if _cooldown != null and is_instance_valid(_cooldown):
		_cooldown.color = CooldownColor
	if _hold_fill != null and is_instance_valid(_hold_fill):
		_hold_fill.color = HoldFillColor

func _apply_invert(node: CanvasItem, on_press: bool, on_toggle: bool, on_hover: bool) -> void:
	var should := (_is_pressed and on_press) or (_is_toggled and on_toggle) or (_is_hovering and on_hover)
	if _invert_material != null and should:
		node.material = _invert_material
	else:
		node.material = null

func _apply_panel_styling() -> void:
	if not _enable_panel:
		if _panel != null:
			if _panel.has_theme_stylebox_override("panel"):
				_panel.remove_theme_stylebox_override("panel")
			_panel.queue_redraw()
		return
	if _panel == null: return
	_panel.theme = null
	_panel.theme_type_variation = PanelThemeVariation if PanelThemeVariation != null else ""
	if _panel.has_theme_stylebox_override("panel"):
		_panel.remove_theme_stylebox_override("panel")
	if PanelStyleBox != null:
		_panel.add_theme_stylebox_override("panel", PanelStyleBox)
	_panel.queue_redraw()
	if Engine.is_editor_hint(): queue_redraw()

func _apply_theme_to_children() -> void:
	if _label != null and is_instance_valid(_label): _label.theme = theme
	if _icon != null and is_instance_valid(_icon): _icon.theme = theme

func _apply_theme_now() -> void:
	if _theme_applying: return
	_theme_applying = true
	if _label != null and is_instance_valid(_label): _label.theme = theme
	if _icon != null and is_instance_valid(_icon): _icon.theme = theme
	_theme_applying = false

func _invalidate_visual_state() -> void:
	_last_visual_state = ""
	_apply_visual_state()
	_apply_theme_now()

# Cooldown & Hold visuals
func _start_cooldown() -> void:
	if not EnableCooldown: return
	_cooldown_active = true
	_cooldown_time_left = CooldownDuration
	_ensure_cooldown()
	_update_cooldown_visual()
	set_process(true)
	call_deferred("_reset_pressed_visuals_after_cooldown_start")

func _reset_pressed_visuals_after_cooldown_start() -> void:
	_is_pressed = false
	_enable_top_level(false)
	_apply_visual_state()

func _update_cooldown_visual() -> void:
	if not EnableCooldown: return
	_ensure_cooldown()
	if _cooldown == null or not is_instance_valid(_cooldown): return
	var total: float = max(0.0001, CooldownDuration)
	var remaining: float = max(0.0, _cooldown_time_left)
	var progress: float = 1.0 - (remaining / total)
	var sz := size
	match CooldownFillDirection:
		CooldownDirection.BottomToTop:
			if CooldownStartFilled:
				var h := sz.y * (1.0 - progress)
				_cooldown.size = Vector2(sz.x, h)
				_cooldown.position = Vector2(0, 0)
				_cooldown.visible = h > 0.0
			else:
				var h2 := sz.y * progress
				_cooldown.size = Vector2(sz.x, h2)
				_cooldown.position = Vector2(0, sz.y - h2)
				_cooldown.visible = h2 > 0.0
		CooldownDirection.TopToBottom:
			if CooldownStartFilled:
				var h := sz.y * (1.0 - progress)
				_cooldown.size = Vector2(sz.x, h)
				_cooldown.position = Vector2(0, sz.y - h)
				_cooldown.visible = h > 0.0
			else:
				var h2 := sz.y * progress
				_cooldown.size = Vector2(sz.x, h2)
				_cooldown.position = Vector2(0, 0)
				_cooldown.visible = h2 > 0.0
		CooldownDirection.LeftToRight:
			if CooldownStartFilled:
				var w := sz.x * (1.0 - progress)
				_cooldown.size = Vector2(w, sz.y)
				_cooldown.position = Vector2(sz.x - w, 0)
				_cooldown.visible = w > 0.0
			else:
				var w2 := sz.x * progress
				_cooldown.size = Vector2(w2, sz.y)
				_cooldown.position = Vector2(0, 0)
				_cooldown.visible = w2 > 0.0
		CooldownDirection.RightToLeft:
			if CooldownStartFilled:
				var w := sz.x * (1.0 - progress)
				_cooldown.size = Vector2(w, sz.y)
				_cooldown.position = Vector2(0, 0)
				_cooldown.visible = w > 0.0
			else:
				var w2 := sz.x * progress
				_cooldown.size = Vector2(w2, sz.y)
				_cooldown.position = Vector2(sz.x - w2, 0)
				_cooldown.visible = w2 > 0.0

func _update_hold_fill_visual() -> void:
	if not EnableHoldBuildUp or not _is_pressed: return
	_ensure_hold_fill_rect()
	if _hold_fill == null or not is_instance_valid(_hold_fill): return
	var total: float = max(0.0001, HoldDuration)
	var progress: float = clamp(_hold_timer / total, 0.0, 1.0)
	_hold_fill.visible = true
	var sz := size
	match HoldFillDirection:
		CooldownDirection.BottomToTop:
			var h := max(1.0, sz.y * progress)
			_hold_fill.size = Vector2(sz.x, h)
			_hold_fill.position = Vector2(0, sz.y - h)
		CooldownDirection.TopToBottom:
			var h2 := max(1.0, sz.y * progress)
			_hold_fill.size = Vector2(sz.x, h2)
			_hold_fill.position = Vector2(0, 0)
		CooldownDirection.LeftToRight:
			var w := max(1.0, sz.x * progress)
			_hold_fill.size = Vector2(w, sz.y)
			_hold_fill.position = Vector2(0, 0)
		CooldownDirection.RightToLeft:
			var w2 := max(1.0, sz.x * progress)
			_hold_fill.size = Vector2(w2, sz.y)
			_hold_fill.position = Vector2(sz.x - w2, 0)


# Signal wiring and built-ins
func _initialize_callables() -> void:
	var fallbacks := [
		["Pressed", Callable(self, "_run_built_in_pressed")],
		["Released", Callable(self, "_run_built_in_released")],
		["HoverIn", Callable(self, "_run_built_in_hover_in")],
		["HoverOut", Callable(self, "_run_built_in_hover_out")],
		["Toggled", Callable(self, "_run_built_in_toggled")],
		["Log", Callable(self, "_run_built_in_log")],
		["Warning", Callable(self, "_run_built_in_warning")],
		["Error", Callable(self, "_run_built_in_error")],
		["Hold", Callable(self, "_run_built_in_hold")],
		["Swipe", Callable(self, "_run_built_in_swipe")],
	]
	for pair in fallbacks:
		_set_callable_property(pair[0], _adopt_connected_callable(pair[0], pair[1]))

func _set_callable_property(name: String, callable: Callable) -> void:
	match name:
		"Pressed": PressedAction = callable
		"Released": ReleasedAction = callable
		"HoverIn": HoverInAction = callable
		"HoverOut": HoverOutAction = callable
		"Toggled": ToggledAction = callable
		"Log": LogAction = callable
		"Warning": WarningAction = callable
		"Error": ErrorAction = callable
		"Hold": HoldAction = callable
		"Swipe": SwipeAction = callable

func _connect_signals() -> void:
	var pairs := [
		["pressed", PressedAction],
		["released", ReleasedAction],
		["hover_in", HoverInAction],
		["hover_out", HoverOutAction],
		["toggled", ToggledAction],
		["log", LogAction],
		["warning", WarningAction],
		["error", ErrorAction],
		["hold", HoldAction],
		["swipe", SwipeAction],
	]
	for p in pairs:
		var sig: StringName = p[0]
		var cb: Callable = p[1]
		if has_signal(sig) and get_signal_connection_list(sig).is_empty():
			connect(sig, cb)

func _connect_if_not_connected(signal_name: String, callable: Callable) -> void:
	if has_signal(signal_name) and not is_connected(signal_name, callable):
		connect(signal_name, callable)

func _disconnect_all_signal_handlers() -> void:
	if Engine.is_editor_hint():
		return
	for sig in ["pressed","toggled","released","log","warning","error","hover_in","hover_out","hold","swipe"]:
		for conn in get_signal_connection_list(sig):
			var c: Callable = conn["callable"]
			if c.get_object() == self and is_connected(sig, c):
				disconnect(sig, c)

func _adopt_connected_callable(sig_name: String, fallback: Callable) -> Callable:
	if not has_signal(sig_name):
		return fallback
	var conns := get_signal_connection_list(sig_name)
	if conns.size() > 0:
		return conns[0]["callable"]
	return fallback

func _run_built_in_pressed() -> void: pass
func _run_built_in_released() -> void: pass
func _run_built_in_hover_in() -> void: pass
func _run_built_in_hover_out() -> void: pass
func _run_built_in_toggled(v: bool) -> void: pass
func _run_built_in_log(message: String) -> void: print("[OmniButton] ", message)
func _run_built_in_warning(message: String) -> void: push_warning(message)
func _run_built_in_error(message: String) -> void: push_error(message)
func _run_built_in_hold() -> void: pass
func _run_built_in_swipe(direction: Vector2) -> void: pass
