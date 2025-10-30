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
signal swipe_ended
signal log(message: String)
signal warning(message: String)
signal error(message: String)
signal joystick_started
signal joystick_axis(axis: Vector2)
signal joystick_ended

# Enums to match C# API
enum CooldownDirection {BottomToTop = 0, TopToBottom = 1, LeftToRight = 2, RightToLeft = 3}
enum BackgroundMode {None = 0, UsePanel = 1, UseTexture = 2}
enum Preset {None = 0, Basic = 1, Toggle = 2, Hold = 3, Swipe = 4, Draggable = 5, VirtualJoystick = 6, Custom = 99}
enum FollowModeEnum {None = 0, FollowBoth = 3, VirtualJoystick = 4}
enum JoystickClampShape {Circle = 0, Rectangle = 1}
enum SwipeInitMode {OnHoverIn = 0, OnPressed = 1}
enum SwipeExitMode {OnHoverOut = 0, OnReleased = 1}
enum CooldownTriggerEnum {None = 0, OnPress = 1, OnRelease = 2, OnPressAndRelease = 3}

# InvertModes and ActionMask bit flags
const INVERT_PRESS := 1
const INVERT_TOGGLE := 2
const INVERT_HOVER := 4
const INVERT_HOLD := 8

const ACT_PRESSED := 1
const ACT_RELEASED := 2
const ACT_HOVER := 4
const ACT_TOGGLE := 8
const ACT_HOLD := 16
const ACT_SWIPE := 32
const ACT_LOG := 64
const ACT_WARNING := 128
const ACT_ERROR := 256

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

# Presets
var _preset := Preset.None
@export_group("Presets")
@export var PresetSelection: Preset:
	get: return _preset
	set(value):
		if _preset == value: return
		_preset = value
		if _preset == Preset.Custom or _preset == Preset.None: return
		_apply_preset(_preset)

# Content Display
@export_group("Content Display")
var _background_mode := BackgroundMode.None
@export var Background: BackgroundMode:
	get: return _background_mode
	set(value):
		_background_mode = value
		_setup_children()
		_apply_panel_styling()
		_apply_visual_state()

var _icon_texture: Texture2D
@export var IconTexture: Texture2D:
	get: return _icon_texture
	set(value):
		_icon_texture = value
		_ensure_icon()
		_apply_visual_state(); _fit_label_text()

var _label_text: String = ""
@export var LabelText: String:
	get: return _label_text
	set(value):
		_label_text = value if value != null else ""
		_set_label_text()
		_apply_visual_state()
		_fit_label_text()

var _rich_label_text: String = ""
@export var RichLabelText: String:
	get: return _rich_label_text
	set(value):
		_rich_label_text = value if value != null else ""
		_set_label_text()
		_apply_visual_state()
		_fit_label_text()

@export var RichLabelUseBBCode: bool = true

var _enable_selected_overlay := false
@export var EnableSelectedOverlay: bool:
	get: return _enable_selected_overlay
	set(value):
		if _enable_selected_overlay == value: return
		_enable_selected_overlay = value
		_update_overlay(); _apply_visual_state()
@export var SelectedColor: Color = Color(1, 1, 1, 0.3)

# Background Settings
@export_subgroup("Background Settings")
@export var PanelThemeType: String = "Panel"
@export var PanelThemeVariation: String = ""
@export var PanelStyleBox: StyleBox
@export var BackgroundTexture: Texture2D
@export var BackgroundExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var BackgroundStretchMode: int = TextureRect.STRETCH_SCALE
@export var BackgroundFlipH: bool = false
@export var BackgroundFlipV: bool = false

# Icon Settings
@export_subgroup("Icon Settings")
@export var IconExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var IconStretchMode: int = TextureRect.STRETCH_SCALE
@export var IconFlipH: bool = false
@export var IconFlipV: bool = false

# Label Settings
@export_subgroup("Label Settings")
@export var LabelFont: Font
@export var LabelTextColor: Color = Color.WHITE
@export var EnableTextAutoSize: bool = true
@export var TextFitPadding: Vector2 = Vector2(12, 4)
@export_range(6, 300, 1) var MinFontSize: int = 6
@export_range(6, 300, 1) var MaxFontSize: int = 100
@export_range(0, 300, 1) var FixedFontSize: int = 0
@export var LabelHorizontalAlignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var LabelVerticalAlignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
@export var LabelAutowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
@export var LabelPadding: Vector2 = Vector2.ZERO
@export_range(0, 4096, 1) var LabelAdditionalPaddingLeft: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingTop: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingRight: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingBottom: float = 0.0

# Invert Display
@export_subgroup("Invert Display")
@export_flags("Press", "Toggle", "Hover", "Hold") var InvertModes: int = 0

# Hover Scaling
@export_subgroup("Hover Scaling")
@export var EnableHoverScale: bool = false
@export_range(1.0, 3.0, 0.01) var HoverScale: float = 1.25
@export_range(0.0, 100.0, 0.1) var HoverLerpSpeed: float = 25.0

# Actions
@export_group("Actions")
@export_flags("Pressed", "Released", "Hover", "Toggle", "Hold", "Swipe", "Log", "Warning", "Error") var ActionMaskBits: int = 0
@export var PressedAction: Callable
@export var ReleasedAction: Callable
@export var HoverInAction: Callable
@export var HoverOutAction: Callable
@export var ToggledAction: Callable
@export_subgroup("Hold Build-Up")
@export var HoldAction: Callable
@export_range(0.05, 5.0, 0.05) var HoldDuration: float = 0.5
@export var EnableHoldBuildUp: bool = false
@export var HoldFillColor: Color = Color(1, 1, 1, 0.25)
@export var HoldFillDirection: int = CooldownDirection.BottomToTop
@export_subgroup("Swipe")
@export var SwipeAction: Callable
@export_range(0.0, 1000.0, 1.0) var SwipeThreshold: float = 20.0
@export var TouchSwipeInit: SwipeInitMode = SwipeInitMode.OnHoverIn
@export var TouchSwipeExit: SwipeExitMode = SwipeExitMode.OnHoverOut
@export var MouseSwipeInit: SwipeInitMode = SwipeInitMode.OnPressed
@export var MouseSwipeExit: SwipeExitMode = SwipeExitMode.OnReleased

@export_subgroup("Logging")
@export var LogAction: Callable
@export var WarningAction: Callable
@export var ErrorAction: Callable

# Toggle Behavior
enum InteractionModeEnum {Momentary = 0, ToggleOnPress = 1, ToggleOnRelease = 2}
@export_subgroup("Toggle Behavior")
@export var InteractionMode: InteractionModeEnum = InteractionModeEnum.Momentary

# Input
@export_group("Input")
@export var BoundsSource: Control
@export var HitSlop: Vector2 = Vector2.ZERO

# Follow Input
@export_group("Follow Input")
@export var FollowMode: FollowModeEnum = FollowModeEnum.None

# Virtual Joystick
@export_subgroup("Virtual Joystick")
@export var EnableVirtualJoystick: bool = false
@export var ClampShape: JoystickClampShape = JoystickClampShape.Circle
@export_range(0, 4096, 1) var JoystickRadiusPx: int = 0
@export var JoystickRectSizePx: Vector2 = Vector2.ZERO
@export_range(0.0, 1.0, 0.01) var JoystickDeadzone: float = 0.1
@export var JoystickSnapToInput: bool = true
@export var JoystickHideWhenInactive: bool = false
@export var JoystickResetOnRelease: bool = true
@export_subgroup("Virtual Joystick Area")
@export var EnableJoystickArea: bool = false
@export var JoystickAreaPersistent: bool = false
@export var JoystickAreaColor: Color = Color(1, 1, 1, 0.25)
@export_range(0, 64, 1) var JoystickAreaThickness: int = 2
@export var JoystickAreaUseRectForClamp: bool = false
@export var JoystickAreaExternalPath: NodePath
@export_subgroup("Virtual Joystick Thumb")
@export var EnableDefaultThumb: bool = true
@export_range(0.1, 1.0, 0.01) var DefaultThumbSizeRatio: float = 0.6
@export var DefaultThumbColor: Color = Color(1, 1, 1, 0.9)

# Legacy Flags (Compat)
@export_subgroup("Legacy Flags (Compat)")
@export var ClampToBounds: bool = true

# Cooldown
@export_group("Cooldown")
@export var EnableCooldown: bool = false
@export_range(0.05, 60.0, 0.05) var CooldownDuration: float = 1.0
@export var CooldownTrigger: CooldownTriggerEnum = CooldownTriggerEnum.None
@export var CooldownStartFilled: bool = false
@export var CooldownColor: Color = Color(0, 0, 0, 0.4)
@export var CooldownFillDirection: int = CooldownDirection.BottomToTop
@export var SuspendHoverScaleDuringCooldown: bool = false
@export var AllowHoldDuringCooldown: bool = false
@export var HideCooldownDuringHoldBuildUp: bool = true

# Theme Variations
@export_group("Theme Variations")
@export var ThemeTypeName: String = "OmniButton"
@export var VariantNormal: String = "normal"
@export var VariantPressed: String = "pressed"
@export var VariantHover: String = "hover"
@export var VariantToggled: String = "toggled"
@export var VariantSelected: String = "selected"
@export var VariantDisabled: String = "disabled"

# Private state and caches
var _hover_target_scale := 1.0
var _hold_timer := 0.0
var _cooldown_active := false
var _cooldown_time_left := 0.0
var _swipe_start := Vector2.ZERO
var _swipe_origin := Vector2.ZERO
var _is_swiping := false
var _touch_swipe_eligible := false
var _hover_top_level_active := false
var _saved_global_pos := Vector2.ZERO
var _vj_active := false
var _vj_home_global := Vector2.ZERO
var _vj_saved_mouse_filter := MOUSE_FILTER_STOP
var _panel: Panel
var _background_tex: TextureRect
var _icon: TextureRect
var _label: Label
var _rich_label: RichTextLabel
var _overlay: ColorRect
var _cooldown: ColorRect
var _hold_fill: ColorRect
var _invert_material: ShaderMaterial
var _default_thumb: Panel
var _vj_area_panel: Panel
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
	if EnableSelectedOverlay and Selected and Background == BackgroundMode.None:
		Background = BackgroundMode.UsePanel
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
	_panel = null; _background_tex = null; _icon = null; _label = null; _rich_label = null; _overlay = null; _cooldown = null; _hold_fill = null

func _process(delta: float) -> void:
	# Hold progression
	if _is_pressed and (not EnableCooldown or not _cooldown_active or AllowHoldDuringCooldown or EnableHoldBuildUp):
		_hold_timer += delta
		if not _is_holding and _hold_timer >= HoldDuration:
			_is_holding = true
			if _action_enabled(ACT_HOLD): emit_signal("hold"); if HoldAction.is_valid(): HoldAction.call()
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
			_lerp_scale_to(_background_tex, Vector2.ONE, t_reset)
			_lerp_scale_to(_icon, Vector2.ONE, t_reset)
			_lerp_scale_to(_label, Vector2.ONE, t_reset)
			_lerp_scale_to(_rich_label, Vector2.ONE, t_reset)
			_lerp_scale_to(_overlay, Vector2.ONE, t_reset)
			_enable_top_level(false)
		else:
			var target := Vector2.ONE * _hover_target_scale
			var t := min(1.0, delta * HoverLerpSpeed)
			var any := false
			any = _lerp_scale_to(_panel, target, t) or any
			any = _lerp_scale_to(_background_tex, target, t) or any
			any = _lerp_scale_to(_icon, target, t) or any
			any = _lerp_scale_to(_label, target, t) or any
			any = _lerp_scale_to(_rich_label, target, t) or any
			any = _lerp_scale_to(_overlay, target, t) or any
			var hold_build := EnableHoldBuildUp and _is_pressed and not _is_holding
			if not any and not _is_hovering and not (_cooldown_active and EnableCooldown) and not hold_build:
				set_process(false)
				_enable_top_level(false)
	else:
		var t2 := min(1.0, delta * HoverLerpSpeed)
		var any2 := false
		any2 = _lerp_scale_to(_panel, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_background_tex, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_icon, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_label, Vector2.ONE, t2) or any2
		any2 = _lerp_scale_to(_rich_label, Vector2.ONE, t2) or any2
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

	# Keep exported state properties in sync (editor friendliness)
	Selected = _selected
	IsToggled = _is_toggled
	IsPressed = _is_pressed
	IsHovering = _is_hovering
	IsHolding = _is_holding

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_fit_label_text()
			if Background == BackgroundMode.UsePanel: queue_redraw()
			if _default_thumb != null and is_instance_valid(_default_thumb): _update_default_thumb_visual()
			if _is_hovering and EnableHoverScale:
				_update_hover_pivots(); _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_THEME_CHANGED:
			if theme != null: _apply_theme_to_children()
			_last_visual_state = ""; _apply_theme_now(); _apply_panel_styling(); _fit_label_text()
			if _default_thumb != null and is_instance_valid(_default_thumb): _update_default_thumb_visual()
			if _is_hovering and EnableHoverScale: _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree(): _is_pressed = false; _is_hovering = false; _is_holding = false; _is_swiping = false; _invalidate_visual_state()
		NOTIFICATION_PREDELETE:
			_exit_tree()


# Input and hover handlers
func _gui_input(event: InputEvent) -> void:
	if _disabled: return
	var inside := _input_inside(event)
	if EnableCooldown and _cooldown_active: return

	# Screen touch swipe eligibility tracking
	if event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_touch_swipe_eligible = _input_inside(st)
			if TouchSwipeInit == SwipeInitMode.OnPressed and _touch_swipe_eligible:
				_swipe_origin = st.position
				_is_swiping = false
				_swipe_start = Vector2.ZERO
		else:
			if TouchSwipeExit == SwipeExitMode.OnReleased:
				_is_swiping = false
				emit_signal("swipe_ended")
			_swipe_start = Vector2.ZERO
			_touch_swipe_eligible = false

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if not inside: return
			_is_pressed = true
			_hold_timer = 0.0
			_is_holding = false
			_is_swiping = false
			_swipe_origin = mb.position

			if EnableVirtualJoystick or FollowMode == FollowModeEnum.VirtualJoystick:
				_vj_active = true
				_vj_home_global = global_position + size * 0.5
				_enable_top_level(true)
				if JoystickSnapToInput: _move_to_global(mb.global_position)
				if JoystickHideWhenInactive: visible = true
				emit_signal("joystick_started")
				_emit_joystick_axis_for(mb.global_position)
				if EnableJoystickArea:
					_ensure_and_refresh_joystick_area(_vj_home_global)
					_set_joystick_area_visible(true)
			elif FollowMode == FollowModeEnum.FollowBoth:
				_enable_top_level(true)
				_move_to_global(mb.global_position)

			if _action_enabled(ACT_SWIPE) and MouseSwipeInit == SwipeInitMode.OnPressed:
				_swipe_start = mb.position
			if _action_enabled(ACT_PRESSED):
				emit_signal("pressed")
				if PressedAction.is_valid(): PressedAction.call()
			# Toggle on press for explicit ToggleOnPress, or momentary+Toggle action
			if InteractionMode == InteractionModeEnum.ToggleOnPress or (InteractionMode == InteractionModeEnum.Momentary and _action_enabled(ACT_TOGGLE)):
				_is_toggled = not _is_toggled
				_update_overlay()
				emit_signal("toggled", _is_toggled)
				if ToggledAction.is_valid(): ToggledAction.call(_is_toggled)
			if EnableCooldown and (CooldownTrigger == CooldownTriggerEnum.OnPress or CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease):
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
			_is_holding = false
			_is_swiping = false
			_swipe_start = Vector2.ZERO
			if _action_enabled(ACT_RELEASED) and inside:
				emit_signal("released")
				if ReleasedAction.is_valid(): ReleasedAction.call()
			if EnableCooldown and (CooldownTrigger == CooldownTriggerEnum.OnRelease or CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease):
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
				if EnableJoystickArea and not JoystickAreaPersistent:
					_set_joystick_area_visible(false)
			_enable_top_level(false)
			# Toggle on release regardless of inside to mirror C# behavior
			if InteractionMode == InteractionModeEnum.ToggleOnRelease:
				_is_toggled = not _is_toggled
				_update_overlay()
				emit_signal("toggled", _is_toggled)
				if ToggledAction.is_valid(): ToggledAction.call(_is_toggled)
			_apply_visual_state()

	elif _is_pressed and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (EnableVirtualJoystick or FollowMode == FollowModeEnum.VirtualJoystick) and _vj_active:
			if JoystickSnapToInput:
				_move_to_global(mm.global_position)
			_emit_joystick_axis_for(mm.global_position)
		elif FollowMode == FollowModeEnum.FollowBoth:
			_move_to_global(mm.global_position)
		# Swipe detection while pressed (mouse motion)
		if _action_enabled(ACT_SWIPE):
			if _swipe_start == Vector2.ZERO:
				_swipe_start = mm.position
			else:
				var direction := mm.position - _swipe_start
				if direction.length() > SwipeThreshold:
					emit_signal("swipe", direction.normalized())
					if SwipeAction.is_valid(): SwipeAction.call(direction.normalized())
					_swipe_start = Vector2.ZERO
		# Update swiping state
		_is_swiping = (mm.position - _swipe_origin).length() > SwipeThreshold

	elif _is_pressed and event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if (EnableVirtualJoystick or FollowMode == FollowModeEnum.VirtualJoystick) and _vj_active:
			if JoystickSnapToInput:
				_move_to_global(sd.position)
			_emit_joystick_axis_for(sd.position)
		elif FollowMode == FollowModeEnum.FollowBoth:
			_move_to_global(sd.position)
		# Swipe detection while pressed (touch drag)
		if _action_enabled(ACT_SWIPE):
			var inside_drag := _input_inside(sd)
			var allow_swipe := _touch_swipe_eligible if TouchSwipeInit == SwipeInitMode.OnPressed else inside_drag
			var end_on_hover_out := (TouchSwipeExit == SwipeExitMode.OnHoverOut)
			if (not allow_swipe) or (end_on_hover_out and not inside_drag):
				_is_swiping = false
				emit_signal("swipe_ended")
				_swipe_start = Vector2.ZERO
			else:
				if _swipe_start == Vector2.ZERO:
					_swipe_start = sd.position
				else:
					var direction3 := sd.position - _swipe_start
					if direction3.length() > SwipeThreshold:
						emit_signal("swipe", direction3.normalized())
						if SwipeAction.is_valid(): SwipeAction.call(direction3.normalized())
						_swipe_start = Vector2.ZERO
		# Update swiping state
		_is_swiping = _input_inside(sd) and (sd.position - _swipe_origin).length() > SwipeThreshold

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var gp := st.position
		if st.pressed and inside:
			_is_pressed = true
			_hold_timer = 0.0
			_is_holding = false
			if EnableVirtualJoystick or FollowMode == FollowModeEnum.VirtualJoystick:
				_vj_active = true
				_vj_home_global = global_position + size * 0.5
				_enable_top_level(true)
				if JoystickSnapToInput: _move_to_global(gp)
				if JoystickHideWhenInactive: visible = true
				emit_signal("joystick_started")
				_emit_joystick_axis_for(gp)
				if EnableJoystickArea:
					_ensure_and_refresh_joystick_area(_vj_home_global)
					_set_joystick_area_visible(true)
			elif FollowMode == FollowModeEnum.FollowBoth:
				_enable_top_level(true)
				_move_to_global(gp)
			if _action_enabled(ACT_PRESSED):
				emit_signal("pressed")
				if PressedAction.is_valid(): PressedAction.call()
			_apply_visual_state()
		elif not st.pressed:
			_is_pressed = false
			_is_holding = false
			_is_swiping = false
			_swipe_start = Vector2.ZERO
			if _action_enabled(ACT_RELEASED) and inside:
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
				if EnableJoystickArea and not JoystickAreaPersistent:
					_set_joystick_area_visible(false)
			_enable_top_level(false)
			_apply_visual_state()

	# Swipe via drag or motion
	if _action_enabled(ACT_SWIPE) and event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _swipe_start == Vector2.ZERO:
			_swipe_start = drag.position
		else:
			var direction := drag.position - _swipe_start
			if direction.length() > SwipeThreshold:
				emit_signal("swipe", direction.normalized())
				if SwipeAction.is_valid(): SwipeAction.call(direction.normalized())
				_swipe_start = Vector2.ZERO
	elif _action_enabled(ACT_SWIPE) and _is_pressed and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _swipe_start == Vector2.ZERO:
			_swipe_start = motion.position
		else:
			var direction2 := motion.position - _swipe_start
			if direction2.length() > SwipeThreshold:
				emit_signal("swipe", direction2.normalized())
				if SwipeAction.is_valid(): SwipeAction.call(direction2.normalized())
				_swipe_start = Vector2.ZERO
	elif _action_enabled(ACT_SWIPE) and MouseSwipeInit == SwipeInitMode.OnHoverIn and event is InputEventMouseMotion:
		var hover_motion := event as InputEventMouseMotion
		var inside_move := _input_inside(hover_motion)
		if not inside_move:
			if MouseSwipeExit == SwipeExitMode.OnHoverOut:
				_is_swiping = false
				_swipe_start = Vector2.ZERO
				emit_signal("swipe_ended")
		else:
			if _swipe_start == Vector2.ZERO:
				_swipe_start = hover_motion.global_position
				_swipe_origin = hover_motion.global_position
			else:
				var directionh := hover_motion.global_position - _swipe_start
				if directionh.length() > SwipeThreshold:
					emit_signal("swipe", directionh.normalized())
					# Keep session alive by advancing the anchor
					_swipe_start = hover_motion.global_position
			# remain in swiping state while inside; exit controlled by MouseSwipeExit
			_is_swiping = true

func _unhandled_input(event: InputEvent) -> void:
	# End active interactions on off-control mouse release (parity with C#)
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		if _is_pressed or _vj_active or _is_swiping:
			_is_pressed = false
			_is_holding = false
			_is_swiping = false
			emit_signal("swipe_ended")
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

func _connect_mouse_events() -> void:
	_connect_if_not_connected("mouse_entered", Callable(self, "_on_mouse_entered"))
	_connect_if_not_connected("mouse_exited", Callable(self, "_on_mouse_exited"))

func _on_mouse_entered() -> void:
	if _disabled: return
	_is_hovering = true
	# Initialize hover-based swipe origin if enabled
	if MouseSwipeInit == SwipeInitMode.OnHoverIn:
		_swipe_origin = get_global_mouse_position()
		if _swipe_start == Vector2.ZERO:
			_swipe_start = get_global_mouse_position()
	if _action_enabled(ACT_HOVER) and not (EnableCooldown and _cooldown_active):
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
	if _action_enabled(ACT_HOVER) and not (EnableCooldown and _cooldown_active):
		emit_signal("hover_out")
		if HoverOutAction.is_valid(): HoverOutAction.call()
	if _action_enabled(ACT_SWIPE) and MouseSwipeExit == SwipeExitMode.OnHoverOut:
		_is_swiping = false
		_swipe_start = Vector2.ZERO
		emit_signal("swipe_ended")
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
	_background_tex = null
	_icon = null
	_label = null
	_rich_label = null
	_overlay = null
	_cooldown = null
	_hold_fill = null
	_default_thumb = null
	_vj_area_panel = null

	if Background == BackgroundMode.UsePanel:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
		_ensure_full_rect(_panel)
		_panel.mouse_filter = MOUSE_FILTER_PASS

	if Background == BackgroundMode.UseTexture and BackgroundTexture != null:
		_background_tex = TextureRect.new()
		_background_tex.name = "Background"
		_background_tex.texture = BackgroundTexture
		_background_tex.expand_mode = BackgroundExpandMode
		_background_tex.stretch_mode = BackgroundStretchMode
		_background_tex.flip_h = BackgroundFlipH
		_background_tex.flip_v = BackgroundFlipV
		_background_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		add_child(_background_tex)
		_ensure_full_rect(_background_tex)
		_background_tex.mouse_filter = MOUSE_FILTER_PASS

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
		_icon.mouse_filter = MOUSE_FILTER_PASS

	_set_label_text()

	# Default thumb for virtual joystick when no icon is provided
	var want_vj := (FollowMode == FollowModeEnum.VirtualJoystick) or EnableVirtualJoystick
	var need_default_thumb := want_vj and EnableDefaultThumb and _icon_texture == null
	if need_default_thumb:
		_ensure_default_thumb()
		_update_default_thumb_visual()

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
		_overlay.color = SelectedColor
		_overlay.mouse_filter = MOUSE_FILTER_PASS
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
	# Background (panel preferred over texture)
	if _panel != null: move_child(_panel, idx); idx += 1
	elif _background_tex != null: move_child(_background_tex, idx); idx += 1
	# Main content
	if _icon != null: move_child(_icon, idx); idx += 1
	elif _default_thumb != null: move_child(_default_thumb, idx); idx += 1
	if _label != null: move_child(_label, idx); idx += 1
	elif _rich_label != null: move_child(_rich_label, idx); idx += 1
	# Overlays
	if _overlay != null: move_child(_overlay, idx); idx += 1
	if _cooldown != null: move_child(_cooldown, idx); idx += 1
	if _hold_fill != null: move_child(_hold_fill, idx); idx += 1

func _configure_label(lbl: Label) -> void:
	# Fill parent and zero offsets so it truly stretches
	lbl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var ep := _get_effective_label_padding()
	lbl.offset_left = ep.x
	lbl.offset_top = ep.y
	lbl.offset_right = - ep.z
	lbl.offset_bottom = - ep.w
	lbl.size_flags_horizontal = SIZE_EXPAND_FILL
	lbl.size_flags_vertical = SIZE_EXPAND_FILL
	# Respect configured alignment and wrap
	lbl.horizontal_alignment = LabelHorizontalAlignment
	lbl.vertical_alignment = LabelVerticalAlignment
	lbl.autowrap_mode = LabelAutowrap
	# Apply optional font override
	if LabelFont != null:
		lbl.add_theme_font_override("font", LabelFont)
	lbl.mouse_filter = MOUSE_FILTER_PASS

func _configure_rich_label(rtl: RichTextLabel) -> void:
	rtl.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var ep := _get_effective_label_padding()
	rtl.offset_left = ep.x
	rtl.offset_top = ep.y
	rtl.offset_right = - ep.z
	rtl.offset_bottom = - ep.w
	rtl.size_flags_horizontal = SIZE_EXPAND_FILL
	rtl.size_flags_vertical = SIZE_EXPAND_FILL
	rtl.bbcode_enabled = RichLabelUseBBCode
	rtl.fit_content = true
	if LabelFont != null:
		rtl.add_theme_font_override("normal_font", LabelFont)
	rtl.mouse_filter = MOUSE_FILTER_PASS

func _set_label_text() -> void:
	if _label_text != "" and _rich_label_text == "":
		if _rich_label != null and is_instance_valid(_rich_label): remove_child(_rich_label); _rich_label.queue_free(); _rich_label = null
		if _label == null or not is_instance_valid(_label):
			_label = Label.new(); _label.name = "Label"; add_child(_label); _configure_label(_label)
		_label.text = _label_text
	elif _rich_label_text != "":
		if _label != null and is_instance_valid(_label): remove_child(_label); _label.queue_free(); _label = null
		if _rich_label == null or not is_instance_valid(_rich_label):
			_rich_label = RichTextLabel.new(); _rich_label.name = "RichLabel"; add_child(_rich_label); _configure_rich_label(_rich_label)
		_rich_label.text = _rich_label_text
	else:
		if _label != null and is_instance_valid(_label): remove_child(_label); _label.queue_free(); _label = null
		if _rich_label != null and is_instance_valid(_rich_label): remove_child(_rich_label); _rich_label.queue_free(); _rich_label = null
	# reapply padding offsets to whichever label exists
	if _label != null and is_instance_valid(_label): _configure_label(_label)
	if _rich_label != null and is_instance_valid(_rich_label): _configure_rich_label(_rich_label)

func _fit_label_text() -> void:
	if _fitting_label:
		return
	_fitting_label = true
	# Fixed font size bypasses autosize
	if FixedFontSize > 0:
		if _label != null and is_instance_valid(_label):
			_label.add_theme_font_size_override("font_size", FixedFontSize)
			_label.update_minimum_size()
		if _rich_label != null and is_instance_valid(_rich_label):
			for sp in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
				_rich_label.add_theme_font_size_override(sp, FixedFontSize)
			_rich_label.update_minimum_size()
		_fitting_label = false
		return
	var ep := _get_effective_label_padding()
	var tp := TextFitPadding
	var avail := Vector2(
		max(1.0, size.x - max(0.0, tp.x) - max(0.0, ep.x) - max(0.0, ep.z)),
		max(1.0, size.y - max(0.0, tp.y) - max(0.0, ep.y) - max(0.0, ep.w))
	)
	if avail.x <= 1.0 or avail.y <= 1.0:
		_fitting_label = false
		return
	# Fit for plain Label
	if EnableTextAutoSize and _label != null and is_instance_valid(_label) and _label.text != "":
		var fnt: Font = _label.get_theme_font("font") if _label.get_theme_font("font") != null else ThemeDB.fallback_font
		if fnt != null:
			# binary search for best size
			var lo := MinFontSize
			var hi := MaxFontSize
			var best := lo
			while lo <= hi:
				var mid := int((lo + hi) / 2)
				var wrap_w := avail.x if LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
				var ts := fnt.get_string_size(_label.text, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, mid)
				if ts.x <= avail.x and ts.y <= avail.y:
					best = mid
					lo = mid + 1
				else:
					hi = mid - 1
			_label.add_theme_font_override("font", fnt)
			_label.add_theme_font_size_override("font_size", best)
	# Fit for RichTextLabel: approximate by stripping BBCode
	elif EnableTextAutoSize and _rich_label != null and is_instance_valid(_rich_label) and _rich_label.text != "":
		var base_font: Font = _rich_label.get_theme_font("normal_font") if _rich_label.get_theme_font("normal_font") != null else ThemeDB.fallback_font
		if base_font != null:
			var plain := _strip_bbcode(_rich_label.text)
			# binary search for best size
			var lo2 := MinFontSize
			var hi2 := MaxFontSize
			var best2 := lo2
			while lo2 <= hi2:
				var mid2 := int((lo2 + hi2) / 2)
				var wrap_w2 := avail.x if LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
				var ts2 := base_font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, wrap_w2, mid2)
				if ts2.x <= avail.x and ts2.y <= avail.y:
					best2 = mid2
					lo2 = mid2 + 1
				else:
					hi2 = mid2 - 1
			_apply_rich_label_font_overrides(base_font, best2)
	_fitting_label = false

# Returns Vector4(left, top, right, bottom)
func _get_effective_label_padding() -> Vector4:
	var lr := max(0.0, LabelPadding.x)
	var tb := max(0.0, LabelPadding.y)
	var left: float = lr + max(0.0, LabelAdditionalPaddingLeft)
	var right: float = lr + max(0.0, LabelAdditionalPaddingRight)
	var top: float = tb + max(0.0, LabelAdditionalPaddingTop)
	var bottom: float = tb + max(0.0, LabelAdditionalPaddingBottom)
	return Vector4(left, top, right, bottom)

func _apply_rich_label_font_overrides(fnt: Font, size_px: int) -> void:
	if _rich_label == null or not is_instance_valid(_rich_label):
		return
	for p in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		_rich_label.add_theme_font_override(p, fnt)
	for sp in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		_rich_label.add_theme_font_size_override(sp, size_px)

func _strip_bbcode(src: String) -> String:
	var out := ""
	var depth := 0
	for i in range(src.length()):
		var ch := src[i]
		if ch == "[": # '['
			depth += 1
		elif ch == "]" and depth > 0: # ']'
			depth = max(0, depth - 1)
		elif depth == 0:
			out += ch
	return out

func _ensure_full_rect(node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	node.size_flags_horizontal = SIZE_EXPAND_FILL
	node.size_flags_vertical = SIZE_EXPAND_FILL

func _update_hover_pivots() -> void:
	pivot_offset = size / 2.0
	if _panel != null and is_instance_valid(_panel): _panel.pivot_offset = _panel.size / 2.0
	if _background_tex != null and is_instance_valid(_background_tex): _background_tex.pivot_offset = _background_tex.size / 2.0
	if _icon != null and is_instance_valid(_icon): _icon.pivot_offset = _icon.size / 2.0
	if _label != null and is_instance_valid(_label): _label.pivot_offset = _label.size / 2.0
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.pivot_offset = _rich_label.size / 2.0
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
		return rect.has_point((event as InputEventScreenTouch).position)
	if event is InputEventScreenDrag:
		return rect.has_point((event as InputEventScreenDrag).position)
	return false

# Virtual joystick helpers
func _ensure_default_thumb() -> void:
	if _default_thumb == null or not is_instance_valid(_default_thumb):
		_default_thumb = Panel.new()
		_default_thumb.name = "DefaultThumb"
		_default_thumb.mouse_filter = MOUSE_FILTER_PASS
		add_child(_default_thumb)
		var sb := StyleBoxFlat.new()
		sb.bg_color = DefaultThumbColor
		_default_thumb.add_theme_stylebox_override("panel", sb)

func _update_default_thumb_visual() -> void:
	if _default_thumb == null or not is_instance_valid(_default_thumb):
		return
	var side := max(1.0, min(size.x, size.y) * DefaultThumbSizeRatio)
	_default_thumb.set_anchors_preset(PRESET_TOP_LEFT)
	_default_thumb.size = Vector2(side, side)
	_default_thumb.position = (size - _default_thumb.size) / 2.0
	var flat := _default_thumb.get_theme_stylebox("panel")
	if flat is StyleBoxFlat:
		var r := int(round(side / 2.0))
		flat.bg_color = DefaultThumbColor
		flat.corner_radius_top_left = r
		flat.corner_radius_top_right = r
		flat.corner_radius_bottom_left = r
		flat.corner_radius_bottom_right = r

func _get_external_joystick_area() -> Control:
	if JoystickAreaExternalPath == null or String(JoystickAreaExternalPath) == "":
		return null
	return get_node_or_null(JoystickAreaExternalPath) as Control

func _ensure_and_refresh_joystick_area(home_center_global: Vector2) -> void:
	if not EnableJoystickArea:
		return
	var target := _get_external_joystick_area()
	if target == null:
		if _vj_area_panel == null or not is_instance_valid(_vj_area_panel):
			_vj_area_panel = Panel.new()
			_vj_area_panel.name = "JoystickArea"
			_vj_area_panel.top_level = true
			_vj_area_panel.mouse_filter = MOUSE_FILTER_IGNORE
			_vj_area_panel.z_index = -1000
			add_child(_vj_area_panel)
		target = _vj_area_panel
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = JoystickAreaColor
		sb.border_width_top = JoystickAreaThickness
		sb.border_width_bottom = JoystickAreaThickness
		sb.border_width_left = JoystickAreaThickness
		sb.border_width_right = JoystickAreaThickness
		_vj_area_panel.add_theme_stylebox_override("panel", sb)
	var use_circle := (ClampShape == JoystickClampShape.Circle) and (not JoystickAreaUseRectForClamp)
	if use_circle:
		var radius := float(JoystickRadiusPx) if JoystickRadiusPx > 0 else _compute_auto_joystick_radius(home_center_global, _get_follow_clamp_rect())
		var sizev := Vector2(radius * 2.0, radius * 2.0)
		if target is Panel and (target as Panel).get_theme_stylebox("panel") is StyleBoxFlat:
			var flat2 := (target as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			var rr := int(round(radius))
			flat2.corner_radius_top_left = rr
			flat2.corner_radius_top_right = rr
			flat2.corner_radius_bottom_left = rr
			flat2.corner_radius_bottom_right = rr
		target.size = sizev
		target.global_position = home_center_global - sizev / 2.0
	else:
		var half_ext := (JoystickRectSizePx / 2.0) if JoystickRectSizePx != Vector2.ZERO else _compute_auto_joystick_half_extents(home_center_global, _get_follow_clamp_rect())
		var sizev2 := half_ext * 2.0
		if target is Panel and (target as Panel).get_theme_stylebox("panel") is StyleBoxFlat:
			var flat3 := (target as Panel).get_theme_stylebox("panel") as StyleBoxFlat
			flat3.corner_radius_top_left = 0
			flat3.corner_radius_top_right = 0
			flat3.corner_radius_bottom_left = 0
			flat3.corner_radius_bottom_right = 0
		target.size = sizev2
		target.global_position = home_center_global - sizev2 / 2.0

func _set_joystick_area_visible(vis: bool) -> void:
	var external := _get_external_joystick_area()
	if external != null:
		external.visible = vis
	elif _vj_area_panel != null and is_instance_valid(_vj_area_panel):
		_vj_area_panel.visible = vis

func _get_follow_clamp_rect() -> Rect2:
	if is_instance_valid(BoundsSource) and BoundsSource != null:
		return BoundsSource.get_global_rect()
	if get_parent() is Control:
		return (get_parent() as Control).get_global_rect()
	return get_viewport_rect()
func _move_to_global(global_point: Vector2) -> void:
	var half := size * 0.5
	if _vj_active and ClampShape == JoystickClampShape.Circle:
		var clamp := _get_follow_clamp_rect()
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

	if _vj_active and ClampShape == JoystickClampShape.Rectangle:
		var clamp2 := _get_follow_clamp_rect()
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
		var bounds := _get_follow_clamp_rect()
		desired.x = clampf(desired.x, bounds.position.x, bounds.position.x + bounds.size.x - size.x)
		desired.y = clampf(desired.y, bounds.position.y, bounds.position.y + bounds.size.y - size.y)
	global_position = desired

func _emit_joystick_axis_for(pointer_global: Vector2) -> void:
	var clamp_rect := _get_follow_clamp_rect()
	var clamped := Vector2(
		clampf(pointer_global.x, clamp_rect.position.x, clamp_rect.position.x + clamp_rect.size.x),
		clampf(pointer_global.y, clamp_rect.position.y, clamp_rect.position.y + clamp_rect.size.y)
	)
	var delta := clamped - _vj_home_global
	var axis := Vector2.ZERO
	if ClampShape == JoystickClampShape.Circle:
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
	# Keep visuals consistent with a press
	_enable_top_level(true)
	_vj_saved_mouse_filter = mouse_filter
	mouse_filter = MOUSE_FILTER_IGNORE
	if JoystickSnapToInput: _move_to_global(global_point)
	if JoystickHideWhenInactive: visible = true
	emit_signal("joystick_started")
	_emit_joystick_axis_for(global_point)
	if EnableJoystickArea:
		_ensure_and_refresh_joystick_area(_vj_home_global)
		_set_joystick_area_visible(true)

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
	mouse_filter = _vj_saved_mouse_filter
	_enable_top_level(false)
	if EnableJoystickArea and not JoystickAreaPersistent:
		_set_joystick_area_visible(false)
	if JoystickHideWhenInactive: visible = false

func StartVirtualJoystickAt(global_point: Vector2) -> void: start_virtual_joystick_at(global_point)
func UpdateVirtualJoystick(global_point: Vector2) -> void: update_virtual_joystick(global_point)
func StopVirtualJoystick() -> void: stop_virtual_joystick()

func _apply_visual_state() -> void:
	if Background == BackgroundMode.UsePanel and _panel == null:
		_panel = Panel.new()
		_panel.name = "Panel"
		add_child(_panel)
		_ensure_full_rect(_panel)
		_apply_panel_styling()

	var overlay_alive := _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == self
	if EnableSelectedOverlay and (_selected or _is_toggled) and not overlay_alive:
		_overlay = ColorRect.new(); _overlay.name = "Overlay"; add_child(_overlay)

	if Background == BackgroundMode.UsePanel and _panel != null:
		_panel.visible = true
		_panel.modulate = Color.WHITE
		_apply_invert(_panel)

	if Background == BackgroundMode.UseTexture and _background_tex != null:
		_background_tex.texture = BackgroundTexture
		_background_tex.flip_h = BackgroundFlipH
		_background_tex.flip_v = BackgroundFlipV
		_background_tex.expand_mode = BackgroundExpandMode
		_background_tex.stretch_mode = BackgroundStretchMode
		_apply_invert(_background_tex)

	if _icon != null:
		_icon.texture = _icon_texture
		_icon.flip_h = IconFlipH
		_icon.flip_v = IconFlipV
		_icon.expand_mode = IconExpandMode
		_icon.stretch_mode = IconStretchMode
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_apply_invert(_icon)

	if _label != null:
		_label.text = _label_text
		_configure_label(_label)
		_label.add_theme_color_override("font_color", LabelTextColor)
		_apply_invert(_label)
	if _rich_label != null:
		_rich_label.text = _rich_label_text
		_configure_rich_label(_rich_label)
		_apply_invert(_rich_label)

	if _enable_selected_overlay and _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = true
		_overlay.color = SelectedColor
		_apply_invert(_overlay)

	if _cooldown != null and is_instance_valid(_cooldown):
		_cooldown.color = CooldownColor
	if _hold_fill != null and is_instance_valid(_hold_fill):
		_hold_fill.color = HoldFillColor

func _apply_invert(node: CanvasItem, _on_press: bool = false, _on_toggle: bool = false, _on_hover: bool = false) -> void:
	var on_pressf := (InvertModes & INVERT_PRESS) != 0
	var on_togglef := (InvertModes & INVERT_TOGGLE) != 0
	var on_hoverf := (InvertModes & INVERT_HOVER) != 0
	var on_holdf := (InvertModes & INVERT_HOLD) != 0
	var should := (_is_pressed and on_pressf) or (_is_toggled and on_togglef) or (_is_hovering and on_hoverf) or (_is_holding and on_holdf)
	if _invert_material != null and should:
		node.material = _invert_material
	else:
		node.material = null

func _apply_panel_styling() -> void:
	if Background != BackgroundMode.UsePanel:
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
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.theme = theme
	if _icon != null and is_instance_valid(_icon): _icon.theme = theme

func _apply_theme_now() -> void:
	if _theme_applying: return
	_theme_applying = true
	if _label != null and is_instance_valid(_label): _label.theme = theme
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.theme = theme
	if _icon != null and is_instance_valid(_icon): _icon.theme = theme
	_theme_applying = false

func _invalidate_visual_state() -> void:
	_last_visual_state = ""
	_apply_visual_state()
	_apply_theme_now()

func _apply_preset(p: Preset) -> void:
	match p:
		Preset.Basic:
			InteractionMode = InteractionModeEnum.Momentary
			FollowMode = FollowModeEnum.None
			EnableHoverScale = false
			EnableCooldown = false
			InvertModes = 0
		Preset.Toggle:
			InteractionMode = InteractionModeEnum.ToggleOnPress
			EnableSelectedOverlay = true
		Preset.Hold:
			EnableHoldBuildUp = true
			if HoldDuration < 0.1:
				HoldDuration = 0.1
		Preset.Swipe:
			FollowMode = FollowModeEnum.None
			if SwipeThreshold < 1.0:
				SwipeThreshold = 1.0
			MouseSwipeInit = SwipeInitMode.OnHoverIn
			MouseSwipeExit = SwipeExitMode.OnHoverOut
			TouchSwipeInit = SwipeInitMode.OnPressed
			TouchSwipeExit = SwipeExitMode.OnReleased
		Preset.Draggable:
			FollowMode = FollowModeEnum.FollowBoth
			ClampToBounds = true
		Preset.VirtualJoystick:
			FollowMode = FollowModeEnum.VirtualJoystick
			ClampShape = JoystickClampShape.Circle
			JoystickDeadzone = 0.15
			JoystickSnapToInput = true
			JoystickHideWhenInactive = false
			JoystickResetOnRelease = true
			EnableJoystickArea = true
			JoystickAreaPersistent = false
			JoystickAreaColor = Color(1, 1, 1, 0.25)
			JoystickAreaThickness = 2
			JoystickAreaUseRectForClamp = false
			JoystickAreaExternalPath = NodePath("")
		_:
			pass

func _action_enabled(bit: int) -> bool:
	return (ActionMaskBits & bit) != 0

# Cooldown & Hold visuals
func _start_cooldown() -> void:
	if not EnableCooldown: return
	_cooldown_active = true
	_cooldown_time_left = CooldownDuration
	_ensure_cooldown()
	_update_cooldown_visual()
	set_process(true)
	call_deferred("_reset_pressed_visuals_after_cooldown_start")

func start_cooldown() -> void:
	_start_cooldown()

func StartCooldown() -> void:
	start_cooldown()

func _reset_pressed_visuals_after_cooldown_start() -> void:
	# Clear pressed and transient states, but keep hover.
	_is_pressed = false
	_is_holding = false
	if _is_swiping:
		_is_swiping = false
		emit_signal("swipe_ended")
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
	for sig in ["pressed", "toggled", "released", "log", "warning", "error", "hover_in", "hover_out", "hold", "swipe"]:
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

# Logging helpers (parity with C# convenience methods)
func print_log(message: String) -> void:
	if has_signal("log"):
		emit_signal("log", message)
	else:
		print("[OmniButton] ", message)

func print_warn(message: String) -> void:
	if has_signal("warning"):
		emit_signal("warning", message)
	else:
		push_warning("[OmniButton] " + message)

func print_err(message: String) -> void:
	if has_signal("error"):
		emit_signal("error", message)
	else:
		push_error("[OmniButton] " + message)
