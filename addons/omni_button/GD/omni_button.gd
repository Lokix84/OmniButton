@tool
class_name Omni_Button
extends Control
## Flexible UI control (press/hover/toggle/hold/swipe, cooldown, optional virtual joystick).
## User decorations: add as direct children (siblings of the internal _Managed node), not inside _Managed.
## Reserved names (purged on refresh): Panel, Background, Icon, Label, RichLabel, Overlay, HoldFill, Cooldown, DefaultThumb, JoystickArea.
## Use ManagedDrawOnTop for draw order; on decorative children set mouse_filter to IGNORE or PASS so input still reaches the button.

const _accessors = preload("res://addons/omni_button/GD/omni_button_accessors.gd")
const _visuals_script = preload("res://addons/omni_button/GD/omni_button_visuals.gd")

# Signals (parity with C# OmniButton)
signal pressed
signal released
signal hover_in
signal hover_out
signal toggled(pressed: bool)
signal typewriter_completed
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
enum DebuggerLogMode {OFF = 0, BASIC = 1}
## Which modality owns the current press (mouse vs native touch) when emulate_mouse_from_touch is on.
enum PointerGestureSource {None = 0, Mouse = 1, NativeTouch = 2}

func _debug(message: String) -> void:
	if not Engine.is_editor_hint() and DebuggerLog != DebuggerLogMode.OFF:
		print("[OmniButton:%s] %s" % [name, message])

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

# Presets (Essentials)
var _preset := Preset.None
@export_category("Essentials")
@export_group("Presets")
@export var PresetSelection: Preset:
	get: return _preset
	set(value):
		if _preset == value:
			return
		_preset = value
		if _preset == Preset.Custom or _preset == Preset.None:
			return
		_apply_preset(_preset)

# State
@export_group("State")
var _disabled := false
@export var Disabled: bool:
	get: return _disabled
	set(value):
		_disabled = value
		_invalidate_visual_state()

var _selected := false
@export var Selected: bool:
	get: return _selected
	set(value):
		if _selected == value:
			return
		_selected = value
		_debug("Selected=%s" % str(value))
		_update_overlay()
		_invalidate_visual_state()

var _is_toggled := false
@export var IsToggled: bool:
	get: return _is_toggled
	set(value):
		if _is_toggled == value:
			return
		_is_toggled = value
		_debug("IsToggled=%s" % str(value))
		_update_overlay()
		_invalidate_visual_state()

var _is_pressed := false
@export var IsPressed: bool:
	get: return _is_pressed
	set(value):
		if _is_pressed == value:
			_invalidate_visual_state()
			return
		var was := _is_pressed
		_is_pressed = value
		_debug("IsPressed=%s" % str(value))
		if (not was) and _is_pressed and EnableHoldBuildUp and not _is_holding:
			_hold_timer = 0.0
			_ensure_hold_fill_rect()
			_update_hold_fill_visual()
			if is_instance_valid(_hold_fill):
				_hold_fill.visible = true
			set_process(true)
		elif was and (not _is_pressed):
			_remove_hold_fill()
		_invalidate_visual_state()

var _is_hovering := false
@export var IsHovering: bool:
	get: return _is_hovering
	set(value):
		if _is_hovering == value:
			return
		_is_hovering = value
		_debug("IsHovering=%s" % str(value))
		_invalidate_visual_state()

var _is_holding := false
@export var IsHolding: bool:
	get: return _is_holding
	set(value):
		var was := _is_holding
		_is_holding = value
		if (not was) and _is_holding:
			_remove_hold_fill()
		if was != value:
			_debug("IsHolding=%s" % str(value))
		_invalidate_visual_state()

# Appearance
@export_category("Appearance")
@export_group("Background")
var _background_mode := BackgroundMode.None
@export var BackgroundType: BackgroundMode:
	get: return _background_mode
	set(value):
		_background_mode = value
		_setup_children()
		_apply_panel_styling()
		_invalidate_visual_state()

var _icon_texture: Texture2D

enum LabelKind {Label = 0, RichTextLabel = 1}
var _label_type: LabelKind = LabelKind.Label
var _text: String = ""

@export_subgroup("Panel & Texture")
@export var PanelThemeVariation: String = ""
@export var PanelStyleBox: StyleBox
@export var BackgroundTexture: Texture2D
@export var BackgroundExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var BackgroundStretchMode: int = TextureRect.STRETCH_SCALE
@export var BackgroundFlipH: bool = false
@export var BackgroundFlipV: bool = false
@export var PanelModulate: Color = Color.WHITE
@export var BackgroundModulate: Color = Color.WHITE

@export_group("Icon")
@export var IconTexture: Texture2D:
	get: return _icon_texture
	set(value):
		_icon_texture = value
		queue_refresh(true, false, true)
@export var IconExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var IconStretchMode: int = TextureRect.STRETCH_SCALE
@export var IconFlipH: bool = false
@export var IconFlipV: bool = false
@export var IconModulate: Color = Color.WHITE

@export_group("Text")
@export var LabelType: LabelKind:
	get: return _label_type
	set(value):
		_label_type = value
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

@export_multiline var Text: String:
	get: return _text
	set(value):
		_text = value if value != null else ""
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

@export_subgroup("Legacy Scenes")
@export_multiline var LabelText: String:
	get: return _text if _label_type == LabelKind.Label else ""
	set(value):
		_text = value if value != null else ""
		_label_type = LabelKind.Label
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

@export_multiline var RichLabelText: String:
	get: return _text if _label_type == LabelKind.RichTextLabel else ""
	set(value):
		_text = value if value != null else ""
		_label_type = LabelKind.RichTextLabel
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

@export_multiline var TextToType: String = ""

@export_group("Label")
@export_subgroup("Typography")
@export var LabelFont: Font
@export var LabelTextColor: Color = Color.WHITE
@export var TextModulate: Color = Color.WHITE
@export var LabelHorizontalAlignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var LabelVerticalAlignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
var _label_autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
@export var LabelAutowrap: TextServer.AutowrapMode:
	get: return _label_autowrap
	set(value):
		if _label_autowrap == value:
			return
		_label_autowrap = value
		_invalidate_autosize_state()
		_invalidate_visual_state()
		_schedule_fit_label()

@export_subgroup("Sizing & Fit")
@export var TextFitPadding: Vector2 = Vector2(12, 4)
## Autosize binary search cost scales with log2(MaxFontSize - MinFontSize). Keep the range tight for UI perf.
@export_range(6, 300, 1) var MinFontSize: int = 6
@export_range(6, 300, 1) var MaxFontSize: int = 100
@export_range(0, 300, 1) var FixedFontSize: int = 0
@export var EnableTextAutoSize: bool = true
@export var LabelPadding: Vector2 = Vector2.ZERO
@export_range(0, 4096, 1) var LabelAdditionalPaddingLeft: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingTop: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingRight: float = 0.0
@export_range(0, 4096, 1) var LabelAdditionalPaddingBottom: float = 0.0

@export_group("Typewriter")
@export var SuspendHoverDuringTypewriter: bool = true
@export var DelayEffectTagsDuringTypewriter: bool = true
@export var FinishTypewriterOnPress: bool = true

@export_group("Visual Effects")
@export_subgroup("Invert Display")
@export_flags("Press", "Toggle", "Hover", "Hold") var InvertModes: int = 0

@export_subgroup("Hover Scaling")
@export var EnableHoverScale: bool = false
@export_range(1.0, 3.0, 0.01) var HoverScale: float = 1.25
@export_range(0.0, 100.0, 0.1) var HoverLerpSpeed: float = 25.0

@export_group("Selection")
@export var SelectedColor: Color = Color(1, 1, 1, 0.3)

# Behavior
@export_category("Behavior")
@export_group("Actions")
@export_flags("Pressed", "Released", "Hover", "Toggle", "Hold", "Swipe", "Log", "Warning", "Error") var ActionMaskBits: int = 0
var PressedAction: Callable
var ReleasedAction: Callable
var HoverInAction: Callable
var HoverOutAction: Callable
var ToggledAction: Callable
var HoldAction: Callable
@export_subgroup("Hold Build-Up")
@export_range(0.05, 5.0, 0.05) var HoldDuration: float = 0.5
var _enable_hold_build_up := false
@export var EnableHoldBuildUp: bool:
	get: return _enable_hold_build_up
	set(value):
		if _enable_hold_build_up == value:
			return
		_enable_hold_build_up = value
		_invalidate_autosize_state()
		_invalidate_visual_state()
@export var HoldFillColor: Color = Color(1, 1, 1, 0.25)
@export var HoldFillDirection: int = CooldownDirection.BottomToTop
var SwipeAction: Callable
@export_subgroup("Swipe")
@export_range(0.0, 1000.0, 1.0) var SwipeThreshold: float = 20.0
@export var TouchSwipeInit: SwipeInitMode = SwipeInitMode.OnHoverIn
@export var TouchSwipeExit: SwipeExitMode = SwipeExitMode.OnHoverOut
@export var MouseSwipeInit: SwipeInitMode = SwipeInitMode.OnPressed
@export var MouseSwipeExit: SwipeExitMode = SwipeExitMode.OnReleased
var LogAction: Callable
var WarningAction: Callable
var ErrorAction: Callable

# Convenience toggles (script-only) mirroring prior inspector helpers.
var EnablePressedActions: bool:
	get: return _action_enabled(ACT_PRESSED)
	set(value):
		if value: ActionMaskBits |= ACT_PRESSED
		else: ActionMaskBits &= ~ACT_PRESSED

var EnableReleasedActions: bool:
	get: return _action_enabled(ACT_RELEASED)
	set(value):
		if value: ActionMaskBits |= ACT_RELEASED
		else: ActionMaskBits &= ~ACT_RELEASED

var EnableHoverActions: bool:
	get: return _action_enabled(ACT_HOVER)
	set(value):
		if value: ActionMaskBits |= ACT_HOVER
		else: ActionMaskBits &= ~ACT_HOVER

var EnableToggleActions: bool:
	get: return _action_enabled(ACT_TOGGLE)
	set(value):
		if value: ActionMaskBits |= ACT_TOGGLE
		else: ActionMaskBits &= ~ACT_TOGGLE

var EnableHoldActions: bool:
	get: return _action_enabled(ACT_HOLD)
	set(value):
		if value: ActionMaskBits |= ACT_HOLD
		else: ActionMaskBits &= ~ACT_HOLD

var EnableSwipeActions: bool:
	get: return _action_enabled(ACT_SWIPE)
	set(value):
		if value: ActionMaskBits |= ACT_SWIPE
		else: ActionMaskBits &= ~ACT_SWIPE

var EnableLogActions: bool:
	get: return _action_enabled(ACT_LOG)
	set(value):
		if value: ActionMaskBits |= ACT_LOG
		else: ActionMaskBits &= ~ACT_LOG

var EnableWarningActions: bool:
	get: return _action_enabled(ACT_WARNING)
	set(value):
		if value: ActionMaskBits |= ACT_WARNING
		else: ActionMaskBits &= ~ACT_WARNING

var EnableErrorActions: bool:
	get: return _action_enabled(ACT_ERROR)
	set(value):
		if value: ActionMaskBits |= ACT_ERROR
		else: ActionMaskBits &= ~ACT_ERROR

# Cache the last chosen autosize to accelerate append cases
var _last_fit_font_size: int = -1
var _rich_current_font_size: int = -1
var _rich_verify_passes: int = 0

# Typewriter support
const TYPEWRITER_EFFECT_TAGS := {
	"wave": true,
	"rainbow": true,
	"tornado": true,
	"pulse": true,
	"shake": true,
	"fade": true
}
const BBCODE_KNOWN_TAGS := {
	"b": true,
	"i": true,
	"u": true,
	"s": true,
	"code": true,
	"url": true,
	"color": true,
	"center": true,
	"left": true,
	"right": true,
	"p": true,
	"br": true,
	"wave": true,
	"rainbow": true,
	"tornado": true,
	"pulse": true,
	"shake": true,
	"fade": true,
	"font": true,
	"img": true,
	"table": true,
	"cell": true,
	"ol": true,
	"ul": true,
	"li": true,
	"indent": true,
	"quote": true
}
const BBCODE_BREAK_TAGS := {
	"br": true,
	"p": true
}
var _tw_active := false
var _tw_by_word := false
var _tw_cps: float = 30.0
var _tw_accum: float = 0.0
var _tw_final_text: String = ""
var _tw_index: int = 0
var _tw_tokens: Array[String] = []
var _tw_builder: String = ""
var _tw_bbcode_aware := false
var _tw_bb_tokens: Array = []
var _tw_total_plain_chars: int = 0
var _tw_visible_plain_chars: int = 0

func _invalidate_autosize_state() -> void:
	_fit_cache_sig = ""
	_last_fit_font_size = -1
	_rich_current_font_size = -1
	_rich_verify_passes = 0

# Toggle Behavior
enum InteractionModeEnum {Momentary = 0, ToggleOnPress = 1, ToggleOnRelease = 2}
@export_subgroup("Toggle Behavior")
@export var InteractionMode: InteractionModeEnum = InteractionModeEnum.Momentary

# Cooldown
@export_group("Cooldown")
var _enable_cooldown := false
@export var EnableCooldown: bool:
	get: return _enable_cooldown
	set(value):
		if _enable_cooldown == value:
			return
		_enable_cooldown = value
		if not _enable_cooldown:
			CooldownTrigger = CooldownTriggerEnum.None
			CooldownStartDelay = 0.0
			CooldownDuration = 1.0
			CooldownStartFilled = false
			CooldownColor = Color(0, 0, 0, 0.4)
			CooldownFillDirection = CooldownDirection.BottomToTop
			InvertOnCooldown = false
			CooldownInvertDuration = 0.0
			SuspendHoverScaleDuringCooldown = false
			AllowHoldDuringCooldown = false
			HideCooldownDuringHoldBuildUp = true
			_cooldown_active = false
			_cooldown_time_left = 0.0
			_cooldown_delay_pending = false
			_cooldown_delay_left = 0.0
			_cooldown_elapsed = 0.0
			if _cooldown != null and is_instance_valid(_cooldown):
				_cooldown.visible = false
				_cooldown.size = Vector2.ZERO
				_cooldown.position = Vector2.ZERO
@export var CooldownTrigger: CooldownTriggerEnum = CooldownTriggerEnum.None
@export_range(0.0, 10.0, 0.01) var CooldownStartDelay: float = 0.0
@export_range(0.05, 60.0, 0.05) var CooldownDuration: float = 1.0
@export var CooldownStartFilled: bool = false
@export var CooldownColor: Color = Color(0, 0, 0, 0.4)
@export var CooldownFillDirection: int = CooldownDirection.BottomToTop
@export var InvertOnCooldown: bool = false
@export_range(0.0, 10.0, 0.01) var CooldownInvertDuration: float = 0.0
@export var SuspendHoverScaleDuringCooldown: bool = false
@export var AllowHoldDuringCooldown: bool = false
@export var HideCooldownDuringHoldBuildUp: bool = true

# Input & Motion
@export_category("Input & Motion")
@export_group("Input bounds")
## If set, hit tests use this control's global rect instead of the OmniButton's (larger target, match parent, etc.).
@export var BoundsSource: Control
## Pixels to grow the hit rect on each side (x = left/right, y = top/bottom).
@export var HitSlop: Vector2 = Vector2.ZERO

# Drag / joystick while pointer is held
@export_group("Drag & virtual joystick")
var _follow_mode: FollowModeEnum = FollowModeEnum.None
## While pressed: None = stays put; FollowBoth = moves with pointer; VirtualJoystick = axis signals (see subgroup below).
@export var FollowMode: FollowModeEnum:
	get: return _follow_mode
	set(value):
		if _follow_mode == value:
			return
		_follow_mode = value
		if _follow_mode == FollowModeEnum.None:
			ClampToBounds = true
		if _follow_mode != FollowModeEnum.VirtualJoystick and not EnableVirtualJoystick:
			ClampShape = JoystickClampShape.Circle
			JoystickRadiusPx = 0
			JoystickRectSizePx = Vector2.ZERO
			JoystickDeadzone = 0.1
			JoystickSnapToInput = true
			JoystickHideWhenInactive = false
			JoystickResetOnRelease = true
		notify_property_list_changed()
		queue_refresh(true, false, false)

# Virtual Joystick
@export_subgroup("Virtual Joystick")
var _enable_virtual_joystick := false
@export var EnableVirtualJoystick: bool:
	get: return _enable_virtual_joystick
	set(value):
		if _enable_virtual_joystick == value:
			return
		_enable_virtual_joystick = value
		if not _enable_virtual_joystick and _follow_mode != FollowModeEnum.VirtualJoystick:
			ClampShape = JoystickClampShape.Circle
			JoystickRadiusPx = 0
			JoystickRectSizePx = Vector2.ZERO
			JoystickDeadzone = 0.1
			JoystickSnapToInput = true
			JoystickHideWhenInactive = false
			JoystickResetOnRelease = true
		notify_property_list_changed()
		queue_refresh(true, false, false)
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
var _enable_default_thumb := true
@export var EnableDefaultThumb: bool:
	get: return _enable_default_thumb
	set(value):
		if _enable_default_thumb == value:
			return
		_enable_default_thumb = value
		queue_refresh(true, false, false)
@export_range(0.1, 1.0, 0.01) var DefaultThumbSizeRatio: float = 0.6
@export var DefaultThumbColor: Color = Color(1, 1, 1, 0.9)

# Legacy Flags (Compat)
@export_subgroup("Legacy Flags (Compat)")
@export var ClampToBounds: bool = true

# Private state and caches
var _hover_target_scale := 1.0
var _hold_timer := 0.0
var _cooldown_active := false
var _cooldown_time_left := 0.0
var _cooldown_delay_pending := false
var _cooldown_delay_left := 0.0
var _cooldown_elapsed := 0.0
var _swipe_start := Vector2.ZERO
var _swipe_origin := Vector2.ZERO
var _is_swiping := false
var _touch_swipe_eligible := false
## -1 = mouse session; >= 0 = finger index for native touch press on this control
var _active_touch_index := -1
var _pointer_gesture_source: PointerGestureSource = PointerGestureSource.None
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
var _auto_action_once_bits := 0
var __editor_last_sig: String = ""
var __editor_poll_accum := 0.0
const __EDITOR_POLL_INTERVAL := 0.2
var _fit_cache_sig: String = ""
var _managed_root: Control
var _managed_draw_on_top := true
var _runtime_refit_frames := 0
var _signals: OmniButtonSignals

@export_category("Composition")
@export var ManagedDrawOnTop: bool:
	get: return _managed_draw_on_top
	set(value):
		_managed_draw_on_top = value
		_position_managed_root()

@export_category("Debug")
@export_enum("Off", "Basic") var DebuggerLog: int = DebuggerLogMode.OFF

func _ensure_managed_root() -> void:
	if _managed_root != null and is_instance_valid(_managed_root):
		return
	_managed_root = Control.new()
	_managed_root.name = "_Managed"
	add_child(_managed_root)
	_ensure_full_rect(_managed_root)
	_managed_root.mouse_filter = MOUSE_FILTER_PASS
	_position_managed_root()

func _position_managed_root() -> void:
	if _managed_root == null or not is_instance_valid(_managed_root):
		return
	var parent := self
	if _managed_draw_on_top:
		parent.move_child(_managed_root, parent.get_child_count() - 1)
	else:
		parent.move_child(_managed_root, 0)

func _managed_add_child(n: Node) -> void:
	_ensure_managed_root()
	_managed_root.add_child(n)
var _pending_children_refresh := false
var _pending_panel_styling := false
var _pending_visual_refresh := false
var _pending_fit_label := false

func queue_refresh(children:=false, panel_styling:=false, fit_label:=true) -> void:
	_pending_children_refresh = _pending_children_refresh or children
	_pending_panel_styling = _pending_panel_styling or panel_styling
	_pending_visual_refresh = true
	_pending_fit_label = _pending_fit_label or fit_label
	set_process(true)

## Runtime: coalesce autosize with the next _process pass (after ApplyVisualState). Editor: fit immediately for inspector.
func _schedule_fit_label() -> void:
	if Engine.is_editor_hint():
		_fit_label_text()
	else:
		_pending_fit_label = true
		set_process(true)

func _editor_build_signature() -> String:
	return _editor.build_signature()

func _enter_tree() -> void:
	_ensure_signals()
	_signals.initialize_callables()
	if not Engine.is_editor_hint():
		_signals.connect_signals()
	_connect_mouse_events()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	if Selected and BackgroundType == BackgroundMode.None:
		BackgroundType = BackgroundMode.UsePanel
	var shader_path = "res://addons/omni_button/Shader/InvertColor.tres"
	if ResourceLoader.exists(shader_path):
		var mat = load(shader_path)
		if mat is ShaderMaterial:
			_invert_material = mat
	else:
		_invert_material = null
	_apply_panel_styling()
	_apply_visual_state()
	_fit_label_text()
	# Runtime layout often settles after _ready; refit once deferred and for a few frames.
	call_deferred("_fit_label_text")
	if not Engine.is_editor_hint():
		_runtime_refit_frames = 4
	_signals.auto_enable_actions_once_from_connections()
	if not Engine.is_editor_hint() and EnableVirtualJoystick and JoystickHideWhenInactive:
		visible = false

@onready var label = _accessors.OmniLabelAccessor.new(self )
@onready var icon = _accessors.OmniIconAccessor.new(self )
@onready var background = _accessors.OmniBackgroundAccessor.new(self )
@onready var panel = _accessors.OmniPanelAccessor.new(self )
@onready var overlay = _accessors.OmniOverlayAccessor.new(self )
@onready var cooldown = _accessors.OmniCooldownAccessor.new(self )
@onready var charge_up = _accessors.OmniChargeUpAccessor.new(self )
@onready var _input = OmniButtonInput.new(self )
@onready var _timing = OmniButtonTiming.new(self )
@onready var _visuals = _visuals_script.new(self )
@onready var _typewriter = OmniButtonTypewriter.new(self )
@onready var _state = OmniButtonState.new(self )
@onready var _joystick = OmniButtonJoystick.new(self )
@onready var _editor = OmniButtonEditor.new(self )

func _exit_tree() -> void:
	_ensure_signals()
	_signals.disconnect_all_signal_handlers()
	_panel = null; _background_tex = null; _icon = null; _label = null; _rich_label = null; _overlay = null; _cooldown = null; _hold_fill = null

# ===== Typewriter API =====
func start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_typewriter.start_typewriter(final_text, cps, by_word, preserve_bbcode_tags)

func start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_typewriter.start_typewriter_from_text_to_type(cps, by_word, preserve_bbcode_tags)

func skip_typewriter() -> void:
	_typewriter.skip_typewriter()

func stop_typewriter() -> void:
	_typewriter.stop_typewriter()

func _stop_typewriter_internal(_from_skip: bool) -> void:
	_typewriter._stop_typewriter_internal(_from_skip)

func _set_typewriter_visible_text(s: String) -> void:
	_typewriter._set_typewriter_visible_text(s)

func _process_typewriter(delta: float) -> void:
	_typewriter.process_typewriter(delta)

func _is_whitespace(ch: String) -> bool:
	return _typewriter._is_whitespace(ch)

func _tokenize_words(s: String) -> Array[String]:
	return _typewriter._tokenize_words(s)

func _tokenize_bbcode(src: String) -> Dictionary:
	return _typewriter._tokenize_bbcode(src)

func _build_visible_from_tokens(tokens: Array, visible_plain_chars: int) -> String:
	return _typewriter._build_visible_from_tokens(tokens, visible_plain_chars)

func _is_effect_tag(tag: String) -> bool:
	return _typewriter._is_effect_tag(tag)

func _prefit_for_text(content: String) -> void:
	_typewriter._prefit_for_text(content)

func _process(delta: float) -> void:
	# Editor: throttle polling to reduce overhead
	if Engine.is_editor_hint():
		_editor.process_editor(delta)
	# Apply any pending refresh in a single coalesced pass
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_fit_label:
		if _pending_children_refresh:
			_setup_children(); _pending_children_refresh = false
		if _pending_panel_styling:
			_apply_panel_styling(); _pending_panel_styling = false
		if _pending_visual_refresh:
			_apply_visual_state(); _pending_visual_refresh = false
		if _pending_fit_label:
			_fit_label_text(); _pending_fit_label = false
	_timing.process_runtime(delta)
	# Typewriter progression
	if _tw_active:
		_process_typewriter(delta)
	# Runtime: allow a few frames of refit while layout settles.
	if not Engine.is_editor_hint() and _runtime_refit_frames > 0:
		_runtime_refit_frames -= 1
		_fit_cache_sig = ""
		_fit_label_text()

	_try_stop_process_when_fully_idle()
	# Do not reassign exported state properties every frame; avoids extra setter work
	# Properties are updated at the time state changes (press/hover/toggle/hold)

func _managed_hover_scales_match(target: Vector2, eps := 0.001) -> bool:
	for n in [_panel, _background_tex, _icon, _label, _rich_label, _overlay]:
		if n != null and is_instance_valid(n):
			if n.scale.distance_to(target) >= eps:
				return false
	return true

func _hover_scale_animation_pending() -> bool:
	if not EnableHoverScale:
		return false
	if _tw_active and SuspendHoverDuringTypewriter:
		return not _managed_hover_scales_match(Vector2.ONE)
	if EnableCooldown and _cooldown_active and SuspendHoverScaleDuringCooldown:
		return not _managed_hover_scales_match(Vector2.ONE)
	var ts := _hover_target_scale if _is_hovering else 1.0
	return not _managed_hover_scales_match(Vector2.ONE * ts)

func _try_stop_process_when_fully_idle() -> void:
	if Engine.is_editor_hint():
		return
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_fit_label:
		return
	if _runtime_refit_frames > 0:
		return
	if _tw_active or _cooldown_delay_pending:
		return
	if EnableCooldown and _cooldown_active:
		return
	if _is_pressed and (not EnableCooldown or not _cooldown_active or AllowHoldDuringCooldown or EnableHoldBuildUp):
		return
	if _hover_scale_animation_pending():
		return
	set_process(false)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_fit_label_text()
			if BackgroundType == BackgroundMode.UsePanel: queue_redraw()
			if _default_thumb != null and is_instance_valid(_default_thumb): _update_default_thumb_visual()
			if _is_hovering and EnableHoverScale:
				_update_hover_pivots(); _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_THEME_CHANGED:
			if theme != null: _apply_theme_to_children()
			_last_visual_state = ""; _apply_theme_now(); _apply_panel_styling(); _fit_label_text()
			if _default_thumb != null and is_instance_valid(_default_thumb): _update_default_thumb_visual()
			if _is_hovering and EnableHoverScale: _hover_target_scale = _hover_target_for_viewport(); set_process(true)
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree(): _state.reset_press_state(true, true); _is_hovering = false; _invalidate_visual_state()
		NOTIFICATION_TRANSFORM_CHANGED:
			if _is_hovering and EnableHoverScale:
				_update_hover_pivots()
				_hover_target_scale = _hover_target_for_viewport()
				set_process(true)
			_fit_label_text()
		NOTIFICATION_PREDELETE:
			_exit_tree()


# Input and hover handlers
func _gui_input(event: InputEvent) -> void:
	_ensure_input()
	_input.gui_input(event)

func _unhandled_input(event: InputEvent) -> void:
	_ensure_input()
	_input.unhandled_input(event)

func _connect_mouse_events() -> void:
	_ensure_input()
	_input.connect_mouse_events()

func _on_mouse_entered() -> void:
	_ensure_input()
	_input.on_mouse_entered()

func _on_mouse_exited() -> void:
	_ensure_input()
	_input.on_mouse_exited()

func _ensure_visuals() -> void:
	if _visuals == null:
		_visuals = _visuals_script.new(self )

func _setup_children() -> void:
	_ensure_visuals()
	_visuals.setup_children()

func _ensure_input() -> void:
	if _input == null:
		_input = OmniButtonInput.new(self )

func _ensure_signals() -> void:
	if _signals == null:
		_signals = OmniButtonSignals.new(self )

func _overlay_parent_matches(node: Node) -> bool:
	_ensure_visuals()
	return _visuals.overlay_parent_matches(node)

func _cleanup_extra_overlays() -> void:
	_ensure_visuals()
	_visuals.cleanup_extra_overlays()

func _update_overlay() -> void:
	_ensure_visuals()
	_visuals.update_overlay()

func _ensure_cooldown() -> void:
	_ensure_visuals()
	_visuals.ensure_cooldown()

func _ensure_hold_fill_rect() -> void:
	_ensure_visuals()
	_visuals.ensure_hold_fill_rect()

func _remove_hold_fill() -> void:
	_ensure_visuals()
	_visuals.remove_hold_fill()

func _reorder_children() -> void:
	_ensure_visuals()
	_visuals.reorder_children()

func _child_alive(parent: Node, node: Node) -> bool:
	_ensure_visuals()
	return _visuals.child_alive(parent, node)

func _configure_label(lbl: Label) -> void:
	_ensure_visuals()
	_visuals.configure_label(lbl)

func _configure_rich_label(rtl: RichTextLabel) -> void:
	_ensure_visuals()
	_visuals.configure_rich_label(rtl)

func _set_label_text() -> void:
	if _tw_active:
		return
	# Remove both if empty — unless a label is still required (C# SetupChildren parity):
	# RichTextLabel with no Text yet, BBCode typewriter about to run, or plain typewriter seeding from TextToType only.
	if _text == "":
		var need_label := (_label_type == LabelKind.RichTextLabel) or _tw_bbcode_aware \
			or ((_label_type == LabelKind.Label) and (_tw_final_text != "") and not _tw_bbcode_aware)
		if not need_label:
			if _label != null and is_instance_valid(_label):
				var p1 := _label.get_parent(); if p1 != null and is_instance_valid(p1): p1.remove_child(_label)
				_label.queue_free(); _label = null
			if _rich_label != null and is_instance_valid(_rich_label):
				var p2 := _rich_label.get_parent(); if p2 != null and is_instance_valid(p2): p2.remove_child(_rich_label)
				_rich_label.queue_free(); _rich_label = null
			return
	# Create one based on LabelType
	if _label_type == LabelKind.Label:
		if _rich_label != null and is_instance_valid(_rich_label):
			var pr := _rich_label.get_parent(); if pr != null and is_instance_valid(pr): pr.remove_child(_rich_label)
			_rich_label.queue_free(); _rich_label = null
		if _label == null or not is_instance_valid(_label):
			_label = Label.new(); _label.name = "Label"; _managed_add_child(_label); _configure_label(_label)
		_label.text = _text
	elif _label_type == LabelKind.RichTextLabel:
		if _label != null and is_instance_valid(_label):
			var pl := _label.get_parent(); if pl != null and is_instance_valid(pl): pl.remove_child(_label)
			_label.queue_free(); _label = null
		if _rich_label == null or not is_instance_valid(_rich_label):
			_rich_label = RichTextLabel.new(); _rich_label.name = "RichLabel"; _managed_add_child(_rich_label); _configure_rich_label(_rich_label)
		_rich_label.text = _text
	# reapply padding offsets to whichever label exists
	if _label != null and is_instance_valid(_label): _configure_label(_label)
	if _rich_label != null and is_instance_valid(_rich_label): _configure_rich_label(_rich_label)

## Autosize cache must track the string actually shown on the label (typewriter updates the label, not _text).
func _text_for_fit_signature() -> String:
	if _rich_label != null and is_instance_valid(_rich_label):
		return _rich_label.text
	if _label != null and is_instance_valid(_label):
		return _label.text
	return _text

func _fit_label_text() -> void:
	if _fitting_label:
		return
	var sig := "%s|%s|%s|%s|%s|%s|%s" % [
		_text_for_fit_signature(),
		str(size),
		str(LabelPadding),
		"%s,%s,%s,%s" % [LabelAdditionalPaddingLeft, LabelAdditionalPaddingTop, LabelAdditionalPaddingRight, LabelAdditionalPaddingBottom],
		str(LabelAutowrap),
		str(FixedFontSize),
		str(LabelType)
	]
	if sig == _fit_cache_sig:
		return
	_debug("Autosize begin size=%s type=%s wrap=%s text='%s'" % [str(size), str(LabelType), str(LabelAutowrap), _text_for_fit_signature()])
	if FixedFontSize > 0:
		if _label != null and is_instance_valid(_label):
			_label.add_theme_font_size_override("font_size", FixedFontSize)
			_label.update_minimum_size()
		if _rich_label != null and is_instance_valid(_rich_label):
			for key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
				_rich_label.add_theme_font_size_override(key, FixedFontSize)
			_rich_label.update_minimum_size()
		_last_fit_font_size = FixedFontSize
		_rich_current_font_size = FixedFontSize
		_fit_cache_sig = sig
		return
	if not EnableTextAutoSize:
		return
	_fitting_label = true
	var did_fit := false
	if _rich_label != null and is_instance_valid(_rich_label) and _rich_label.text != "":
		did_fit = _fit_rich_text_label()
	elif _label != null and is_instance_valid(_label) and _label.text != "":
		did_fit = _fit_plain_label()
	_fitting_label = false
	if did_fit:
		_fit_cache_sig = sig
	else:
		_fit_cache_sig = ""

func _fit_plain_label() -> bool:
	var wrap_enabled := LabelAutowrap != TextServer.AUTOWRAP_OFF
	var avail := _calculate_available_area()
	if avail.x <= 1.0 or avail.y <= 1.0:
		call_deferred("_fit_label_text")
		return false
	if _label == null or not is_instance_valid(_label):
		return false
	var fnt: Font = _label.get_theme_font("font") if _label.get_theme_font("font") != null else ThemeDB.fallback_font
	if fnt == null:
		return false
	var wrap_w := avail.x if wrap_enabled else -1.0
	var text := _label.text
	if _last_fit_font_size > 0:
		var sz0 := _measure_paragraph(fnt, text, wrap_w, _last_fit_font_size)
		if _fits_within(sz0, avail, wrap_enabled):
			var grown := _grow_font_size(fnt, text, avail, wrap_w, wrap_enabled, _last_fit_font_size)
			_label.add_theme_font_override("font", fnt)
			_label.add_theme_font_size_override("font_size", grown)
			_label.update_minimum_size()
			_label.queue_redraw()
			_last_fit_font_size = grown
			_debug("Autosize plain fast -> %d" % grown)
			return true
		var s := _last_fit_font_size
		var guard := 0
		while s > MinFontSize and guard < 16:
			s -= 1
			var sz1 := _measure_paragraph(fnt, text, wrap_w, s)
			if _fits_within(sz1, avail, wrap_enabled):
				_label.add_theme_font_override("font", fnt)
				_label.add_theme_font_size_override("font_size", s)
				_label.update_minimum_size()
				_label.queue_redraw()
				_last_fit_font_size = s
				return true
			guard += 1
	var best := _find_best_font_size(fnt, text, avail, wrap_w, wrap_enabled)
	best = _grow_font_size(fnt, text, avail, wrap_w, wrap_enabled, best)
	_label.add_theme_font_override("font", fnt)
	_label.add_theme_font_size_override("font_size", best)
	_label.update_minimum_size()
	_label.queue_redraw()
	var guard2 := 0
	while best > MinFontSize and guard2 < 64:
		var sz := _measure_paragraph(fnt, text, wrap_w, best)
		if _fits_within(sz, avail, wrap_enabled):
			break
		best -= 1
		_label.add_theme_font_override("font", fnt)
		_label.add_theme_font_size_override("font_size", best)
		_label.update_minimum_size()
		_label.queue_redraw()
		guard2 += 1
	_last_fit_font_size = best
	_debug("Autosize plain fitted size=%d avail=%s" % [best, str(avail)])
	return true

func _fit_rich_text_label() -> bool:
	# Match C# FitRichTextLabel: LabelFont ?? ThemeDB.FallbackFont; MeasureParagraph only for search/grow (no RTL mutation in binary search).
	var wrap_enabled := LabelAutowrap != TextServer.AUTOWRAP_OFF
	var avail := _calculate_available_area()
	if avail.x <= 1.0 or avail.y <= 1.0:
		call_deferred("_fit_label_text")
		return false
	if _rich_label == null or not is_instance_valid(_rich_label):
		return false
	var fnt: Font = _get_rich_fit_font()
	if fnt == null:
		return false
	var plain := _strip_bbcode(_rich_label.text)
	var wrap_w := avail.x if wrap_enabled else -1.0
	var seed := _rich_current_font_size if _rich_current_font_size > 0 else _last_fit_font_size
	if seed > 0:
		var sz0 := _measure_paragraph(fnt, plain, wrap_w, seed)
		if _fits_within(sz0, avail, wrap_enabled):
			var grown := _grow_font_size(fnt, plain, avail, wrap_w, wrap_enabled, seed)
			_apply_rich_label_font_overrides(fnt, grown)
			_rich_label.update_minimum_size()
			_rich_label.queue_redraw()
			_rich_current_font_size = grown
			_last_fit_font_size = grown
			_debug("Autosize rich fast -> %d" % grown)
			return true
		var s := seed
		var guard := 0
		while s > MinFontSize and guard < 16:
			s -= 1
			var sz1 := _measure_paragraph(fnt, plain, wrap_w, s)
			if _fits_within(sz1, avail, wrap_enabled):
				_apply_rich_label_font_overrides(fnt, s)
				_rich_label.update_minimum_size()
				_rich_label.queue_redraw()
				_rich_current_font_size = s
				_last_fit_font_size = s
				return true
			guard += 1
	var best := _find_best_font_size(fnt, plain, avail, wrap_w, wrap_enabled)
	best = _grow_font_size(fnt, plain, avail, wrap_w, wrap_enabled, best)
	_apply_rich_label_font_overrides(fnt, best)
	_rich_label.update_minimum_size()
	_rich_label.queue_redraw()
	_rich_current_font_size = best
	# Quick clamp (C#: GetContentHeight vs avail.Y; overW uses MeasureParagraph + FitsWithin && width)
	var guard_r := 0
	while best > MinFontSize and guard_r < 32:
		var over_h := _rich_height_exceeds_avail(avail.y, fnt, plain, wrap_w, best)
		var sz_chk := _measure_paragraph(fnt, plain, wrap_w, best)
		var over_w := not _fits_within(sz_chk, avail, wrap_enabled) and sz_chk.x > avail.x
		if not over_h and not over_w:
			break
		best -= 1
		_apply_rich_label_font_overrides(fnt, best)
		_rich_label.update_minimum_size()
		_rich_label.queue_redraw()
		_rich_current_font_size = best
		guard_r += 1
	_last_fit_font_size = _rich_current_font_size
	_debug("Autosize rich fitted size=%d avail=%s" % [_rich_current_font_size, str(avail)])
	_rich_verify_passes = 0
	call_deferred("_verify_rich_text_fit")
	return true

func _verify_rich_text_fit() -> void:
	if _rich_label == null or not is_instance_valid(_rich_label):
		return
	var avail := _calculate_available_area()
	avail = Vector2(max(1.0, avail.x - 2.0), max(1.0, avail.y - 2.0))
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	var fnt: Font = _get_rich_fit_font()
	if fnt == null:
		return
	var plain := _strip_bbcode(_rich_label.text)
	var wrap_enabled := LabelAutowrap != TextServer.AUTOWRAP_OFF
	var wrap_w := avail.x if wrap_enabled else -1.0
	var size_px := _rich_current_font_size if _rich_current_font_size > 0 else MinFontSize
	var guard := 0
	_rich_label.update_minimum_size()
	_rich_label.queue_redraw()
	while size_px > MinFontSize and guard < 64:
		var over_h := _rich_height_exceeds_avail(avail.y, fnt, plain, wrap_w, size_px)
		var measured := _measure_paragraph(fnt, plain, wrap_w, size_px)
		var over_w := not _fits_within(measured, avail, wrap_enabled)
		if not over_h and not over_w:
			break
		size_px -= 1
		_apply_rich_label_font_overrides(fnt, size_px)
		_rich_label.update_minimum_size()
		_rich_label.queue_redraw()
		_rich_current_font_size = size_px
		guard += 1
	var still_over := _rich_height_exceeds_avail(avail.y, fnt, plain, wrap_w, size_px) or not _fits_within(_measure_paragraph(fnt, plain, wrap_w, size_px), avail, wrap_enabled)
	if still_over and _rich_verify_passes < 8:
		_rich_verify_passes += 1
		call_deferred("_verify_rich_text_fit")
	else:
		_last_fit_font_size = _rich_current_font_size

func _calculate_available_area() -> Vector2:
	var tp := TextFitPadding
	var ep := _get_effective_label_padding()
	var horiz: float = max(0.0, tp.x) + max(0.0, ep.x) + max(0.0, ep.z)
	var vert: float = max(0.0, tp.y) + max(0.0, ep.y) + max(0.0, ep.w)
	return Vector2(max(1.0, size.x - horiz), max(1.0, size.y - vert))

func _measure_paragraph(fnt: Font, text: String, wrap_width: float, font_size: int) -> Vector2:
	var para := TextParagraph.new()
	para.alignment = LabelHorizontalAlignment
	para.direction = TextServer.DIRECTION_AUTO
	para.orientation = TextServer.ORIENTATION_HORIZONTAL
	para.justification_flags = TextServer.JUSTIFICATION_NONE
	para.break_flags = _get_line_break_flags()
	para.width = wrap_width if wrap_width > 0.0 else 0.0
	para.add_string(text, fnt, font_size)
	return para.get_size()

func _get_line_break_flags() -> int:
	# Use local fallback constants for Godot versions where TextServer.LINE_BREAK_FLAG_* are absent.
	# Removed AUTOWRAP_TRIM / AUTOWRAP_TRIM_WORD cases for compatibility with engine versions that do not define them.
	const LB_NONE := 0
	const LB_WORD := 2
	const LB_GRAPHEME := 4
	const LB_ADAPTIVE := 128
	# const LB_TRIM_EDGE := 256  # Not used without trim modes
	match LabelAutowrap:
		TextServer.AUTOWRAP_WORD:
			return LB_WORD
		TextServer.AUTOWRAP_WORD_SMART:
			return LB_WORD | LB_ADAPTIVE
		# Treat ARBITRARY as grapheme wrapping for this engine version.
		TextServer.AUTOWRAP_ARBITRARY:
			return LB_GRAPHEME
		_:
			return LB_NONE

func _fits_within(measured: Vector2, avail: Vector2, wrap_enabled: bool) -> bool:
	var width_ok := measured.x <= (avail.x + (0.5 if wrap_enabled else 0.0))
	return width_ok and measured.y <= avail.y

func _get_rich_fit_font() -> Font:
	if LabelFont != null:
		return LabelFont
	return ThemeDB.fallback_font

## Prefer RichTextLabel layout height when ready; otherwise TextParagraph (same frame as fit).
func _rich_height_exceeds_avail(avail_y: float, fnt: Font, plain: String, wrap_w: float, size_px: int) -> bool:
	if _rich_label == null or not is_instance_valid(_rich_label):
		return false
	var gh: float = _rich_label.get_content_height()
	if gh > 0.5:
		return gh > avail_y
	return _measure_paragraph(fnt, plain, wrap_w, size_px).y > avail_y

func _grow_font_size(fnt: Font, text: String, avail: Vector2, wrap_width: float, wrap_enabled: bool, current: int) -> int:
	var lo := current + 1
	var hi := MaxFontSize
	var best := current
	while lo <= hi:
		var mid := int((lo + hi) / 2)
		var sz := _measure_paragraph(fnt, text, wrap_width, mid)
		if _fits_within(sz, avail, wrap_enabled):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best

func _find_best_font_size(fnt: Font, text: String, avail: Vector2, wrap_width: float, wrap_enabled: bool) -> int:
	var lo := MinFontSize
	var hi := MaxFontSize
	var best := lo
	while lo <= hi:
		var mid := int((lo + hi) / 2)
		var sz := _measure_paragraph(fnt, text, wrap_width, mid)
		if _fits_within(sz, avail, wrap_enabled):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best

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
	if src == null or src == "":
		return ""
	var out := ""
	var i := 0
	while i < src.length():
		var ch := src[i]
		if ch == "[":
			var closing := src.find("]", i + 1)
			if closing != -1:
				var inner := src.substr(i + 1, closing - i - 1).strip_edges()
				if inner != "":
					var tag_name := inner
					var eq := tag_name.find("=")
					if eq != -1:
						tag_name = tag_name.substr(0, eq)
					tag_name = tag_name.strip_edges()
					if tag_name.begins_with("/"):
						tag_name = tag_name.substr(1, tag_name.length() - 1).strip_edges()
					var normalized := tag_name.to_lower()
					if BBCODE_KNOWN_TAGS.has(normalized):
						if BBCODE_BREAK_TAGS.has(normalized):
							out += " "
						i = closing + 1
						continue
			# Not a known tag or missing closing bracket; fall through as literal
		out += ch
		i += 1
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
		_managed_add_child(_icon)
		_ensure_full_rect(_icon)

func _get_or_create_label() -> Label:
	if _label == null or not is_instance_valid(_label):
		_label = Label.new()
		_label.name = "Label"
		_managed_add_child(_label)
		_configure_label(_label)
	return _label

func _input_inside(event: InputEvent) -> bool:
	return _input.input_inside(event)

func _screen_drag_matches_active_touch(sd: InputEventScreenDrag) -> bool:
	return _active_touch_index < 0 or sd.index == _active_touch_index

func _point_inside(global_point: Vector2) -> bool:
	var rect := get_global_rect()
	if is_instance_valid(BoundsSource) and BoundsSource != null:
		rect = BoundsSource.get_global_rect()
	if HitSlop != Vector2.ZERO:
		rect = rect.grow_individual(HitSlop.x, HitSlop.y, HitSlop.x, HitSlop.y)
	return rect.has_point(global_point)

func _is_press_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

# Virtual joystick helpers
func _ensure_default_thumb() -> void:
	if _default_thumb == null or not is_instance_valid(_default_thumb):
		_default_thumb = Panel.new()
		_default_thumb.name = "DefaultThumb"
		_default_thumb.mouse_filter = MOUSE_FILTER_PASS
		_default_thumb.z_index = 2
		_managed_add_child(_default_thumb)
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
	_default_thumb.z_index = 2
	var flat := _default_thumb.get_theme_stylebox("panel")
	if flat is StyleBoxFlat:
		var r := int(round(side / 2.0))
		flat.bg_color = DefaultThumbColor
		flat.corner_radius_top_left = r
		flat.corner_radius_top_right = r
		flat.corner_radius_bottom_left = r
		flat.corner_radius_bottom_right = r

func _get_external_joystick_area() -> Control:
	return _joystick.get_external_joystick_area()

func _ensure_and_refresh_joystick_area(home_center_global: Vector2) -> void:
	_joystick.ensure_and_refresh_joystick_area(home_center_global)

func _set_joystick_area_visible(vis: bool) -> void:
	_joystick.set_joystick_area_visible(vis)

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
	_joystick.emit_axis_for(pointer_global)

func _compute_auto_joystick_radius(home_center_global: Vector2, clamp_rect: Rect2) -> float:
	return _joystick.compute_auto_joystick_radius(home_center_global, clamp_rect)

func _compute_auto_joystick_half_extents(home_center_global: Vector2, clamp_rect: Rect2) -> Vector2:
	return _joystick.compute_auto_joystick_half_extents(home_center_global, clamp_rect)

func start_virtual_joystick_at(global_point: Vector2) -> void:
	_joystick.start_virtual_joystick_at(global_point)

func update_virtual_joystick(global_point: Vector2) -> void:
	_joystick.update_virtual_joystick(global_point)

func stop_virtual_joystick() -> void:
	_joystick.stop_virtual_joystick()


func _apply_visual_state() -> void:
	_ensure_visuals()
	_visuals.apply_visual_state()

func _apply_invert(node: CanvasItem, _on_press: bool = false, _on_toggle: bool = false, _on_hover: bool = false) -> void:
	_ensure_visuals()
	_visuals.apply_invert(node)

func _apply_panel_styling() -> void:
	_ensure_visuals()
	_visuals.apply_panel_styling()

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
	_pending_visual_refresh = true
	set_process(true)
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
			# Overlay visibility now follows Selected only
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
	_cooldown_active = false
	_cooldown_elapsed = 0.0
	_cooldown_time_left = 0.0
	_cooldown_delay_pending = CooldownStartDelay > 0.0
	_cooldown_delay_left = CooldownStartDelay
	_debug("Cooldown scheduled delay=%s duration=%s trigger=%s" % [str(CooldownStartDelay), str(CooldownDuration), str(CooldownTrigger)])
	if _cooldown != null and is_instance_valid(_cooldown):
		_cooldown.visible = false
		_cooldown.size = Vector2.ZERO
		_cooldown.position = Vector2.ZERO
	set_process(true)
	if not _cooldown_delay_pending:
		_begin_cooldown_now()

func _begin_cooldown_now() -> void:
	_cooldown_active = true
	_cooldown_elapsed = 0.0
	_cooldown_time_left = CooldownDuration
	_debug("Cooldown started duration=%s trigger=%s" % [str(CooldownDuration), str(CooldownTrigger)])
	_ensure_cooldown()
	_update_cooldown_visual()
	call_deferred("_reset_pressed_visuals_after_cooldown_start")

func start_cooldown() -> void:
	_start_cooldown()

func _reset_pressed_visuals_after_cooldown_start() -> void:
	# Clear pressed and transient states, but keep hover.
	_state.reset_press_state(true, true)
	_enable_top_level(false)
	_invalidate_visual_state()

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


func _set_callable_property(name: String, callable: Callable) -> void:
	_ensure_signals()
	_signals.set_callable_property(name, callable)

func _adopt_connected_callable(sig_name: String, fallback: Callable) -> Callable:
	_ensure_signals()
	return _signals.adopt_connected_callable(sig_name, fallback)

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
