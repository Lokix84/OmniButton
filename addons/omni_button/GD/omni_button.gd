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
enum DebuggerLogMode {OFF = 0, BASIC = 1}

@export var DebuggerLog: DebuggerLogMode = DebuggerLogMode.OFF

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

# State
@export_group("State")
var _disabled := false
@export var Disabled: bool:
	get: return _disabled
	set(value): _disabled = value; _invalidate_visual_state()

var _selected := false
@export var Selected: bool:
	get: return _selected
	set(value):
		if _selected == value:
			return
		_selected = value
		_debug("Selected=%s" % str(value))
		_update_overlay()
		_apply_visual_state()

var _is_toggled := false
@export var IsToggled: bool:
	get: return _is_toggled
	set(value):
		if _is_toggled == value:
			return
		_is_toggled = value
		_debug("IsToggled=%s" % str(value))
		_update_overlay()
		_apply_visual_state()

var _is_pressed := false
@export var IsPressed: bool:
	get: return _is_pressed
	set(value):
		if _is_pressed == value:
			_apply_visual_state();
			return
		var was := _is_pressed
		_is_pressed = value
		_debug("IsPressed=%s" % str(value))
		if (not was) and _is_pressed and EnableHoldBuildUp and not _is_holding:
			_hold_timer = 0.0; _ensure_hold_fill_rect(); _update_hold_fill_visual(); if is_instance_valid(_hold_fill): _hold_fill.visible = true; set_process(true)
		elif was and (not _is_pressed):
			_remove_hold_fill()
		_apply_visual_state()

var _is_hovering := false
@export var IsHovering: bool:
	get: return _is_hovering
	set(value):
		if _is_hovering == value:
			return
		_is_hovering = value
		_debug("IsHovering=%s" % str(value))
		_apply_visual_state()

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
@export var BackgroundType: BackgroundMode:
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

enum LabelKind {Label = 0, RichTextLabel = 1}
var _label_type: LabelKind = LabelKind.Label
@export var LabelType: LabelKind:
	get: return _label_type
	set(value):
		_label_type = value
		_set_label_text()
		_apply_visual_state()
		_fit_label_text()

var _text: String = ""
@export_multiline var Text: String:
	get: return _text
	set(value):
		_text = value if value != null else ""
		_set_label_text()
		_apply_visual_state()
		_fit_label_text()

# Back-compat exports (deprecated). Routed to Text + LabelType
@export var LabelText: String:
	get: return _text if _label_type == LabelKind.Label else ""
	set(value):
		_text = value if value != null else ""
		_label_type = LabelKind.Label
		_set_label_text(); _apply_visual_state(); _fit_label_text()

@export var RichLabelText: String:
	get: return _text if _label_type == LabelKind.RichTextLabel else ""
	set(value):
		_text = value if value != null else ""
		_label_type = LabelKind.RichTextLabel
		_set_label_text(); _apply_visual_state(); _fit_label_text()

@export var RichLabelUseBBCode: bool = true
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
@export var PanelModulate: Color = Color.WHITE
@export var BackgroundModulate: Color = Color.WHITE

# Icon Settings
@export_subgroup("Icon Settings")
@export var IconExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
@export var IconStretchMode: int = TextureRect.STRETCH_SCALE
@export var IconFlipH: bool = false
@export var IconFlipV: bool = false
@export var IconModulate: Color = Color.WHITE

# Label Settings
@export_subgroup("Label Settings")
@export var LabelFont: Font
@export var LabelTextColor: Color = Color.WHITE
@export var TextModulate: Color = Color.WHITE
@export var EnableTextAutoSize: bool = true
@export var TextFitPadding: Vector2 = Vector2(12, 4)
@export_range(6, 300, 1) var MinFontSize: int = 6
@export_range(6, 300, 1) var MaxFontSize: int = 100
@export_range(0, 300, 1) var FixedFontSize: int = 0
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
		_apply_visual_state()
		_fit_label_text()
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
var _enable_hold_build_up := false
@export var EnableHoldBuildUp: bool:
	get: return _enable_hold_build_up
	set(value):
		if _enable_hold_build_up == value:
			return
		_enable_hold_build_up = value
		_invalidate_autosize_state()
		_apply_visual_state()
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

# Cache the last chosen autosize to accelerate append cases
var _last_fit_font_size: int = -1
var _rich_current_font_size: int = -1

# Typewriter support
var _tw_active := false
var _tw_by_word := false
var _tw_cps: float = 30.0
var _tw_accum: float = 0.0
var _tw_final_text: String = ""
var _tw_index: int = 0
var _tw_tokens: Array[String] = []
var _tw_buffer: String = ""

func _invalidate_autosize_state() -> void:
	_fit_cache_sig = ""
	_last_fit_font_size = -1
	_rich_current_font_size = -1

# Convenience per-action toggles to mirror inspector usage seen in tests
@export var EnablePressedActions: bool:
	get: return _action_enabled(ACT_PRESSED)
	set(value):
		if value:
			ActionMaskBits |= ACT_PRESSED
		else:
			ActionMaskBits &= ~ACT_PRESSED

@export var EnableReleasedActions: bool:
	get: return _action_enabled(ACT_RELEASED)
	set(value):
		if value:
			ActionMaskBits |= ACT_RELEASED
		else:
			ActionMaskBits &= ~ACT_RELEASED

@export var EnableHoverActions: bool:
	get: return _action_enabled(ACT_HOVER)
	set(value):
		if value:
			ActionMaskBits |= ACT_HOVER
		else:
			ActionMaskBits &= ~ACT_HOVER

@export var EnableToggleActions: bool:
	get: return _action_enabled(ACT_TOGGLE)
	set(value):
		if value:
			ActionMaskBits |= ACT_TOGGLE
		else:
			ActionMaskBits &= ~ACT_TOGGLE

@export var EnableHoldActions: bool:
	get: return _action_enabled(ACT_HOLD)
	set(value):
		if value:
			ActionMaskBits |= ACT_HOLD
		else:
			ActionMaskBits &= ~ACT_HOLD

@export var EnableSwipeActions: bool:
	get: return _action_enabled(ACT_SWIPE)
	set(value):
		if value:
			ActionMaskBits |= ACT_SWIPE
		else:
			ActionMaskBits &= ~ACT_SWIPE

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
var _auto_action_once_bits := 0
var __editor_last_sig: String = ""
var __editor_poll_accum := 0.0
const __EDITOR_POLL_INTERVAL := 0.2
var _fit_cache_sig: String = ""
var _managed_root: Control
var _managed_draw_on_top := true

@export var ManagedDrawOnTop: bool:
	get: return _managed_draw_on_top
	set(value):
		_managed_draw_on_top = value
		_position_managed_root()

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
func _editor_build_signature() -> String:
	# Build a signature of key exported properties to detect editor changes
	return "%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s|%s" % [
		str(Disabled),
		str(Selected),
		str(IsToggled),
		str(PresetSelection),
		str(BackgroundType),
		str(IconTexture),
		str(LabelType),
		Text,
		str(PanelThemeType),
		str(PanelThemeVariation),
		str(BackgroundTexture),
		str(InvertModes),
		str(EnableHoverScale),
		str(ActionMaskBits),
		str(EnableHoldBuildUp),
		str(EnableCooldown),
		str(EnableVirtualJoystick)
	]
# Lifecycle
func _enter_tree() -> void:
	_initialize_callables()
	if not Engine.is_editor_hint():
		_connect_signals()
	_connect_mouse_events()

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	if Selected and BackgroundType == BackgroundMode.None:
		BackgroundType = BackgroundMode.UsePanel
	var shader_path = "res://addons/omni_button/Shader/InvertColor.tres"
	_apply_panel_styling()
	_apply_visual_state()
	_fit_label_text()
	_auto_enable_actions_once_from_connections()
	if not Engine.is_editor_hint() and EnableVirtualJoystick and JoystickHideWhenInactive:
		visible = false

@onready var label = OmniLabelAccessor.new(self)
@onready var icon = OmniIconAccessor.new(self)
@onready var background = OmniBackgroundAccessor.new(self)
@onready var panel = OmniPanelAccessor.new(self)
@onready var overlay = OmniOverlayAccessor.new(self)
@onready var cooldown = OmniCooldownAccessor.new(self)
@onready var charge_up = OmniChargeUpAccessor.new(self)

func _exit_tree() -> void:
	_disconnect_all_signal_handlers()
	_panel = null; _background_tex = null; _icon = null; _label = null; _rich_label = null; _overlay = null; _cooldown = null; _hold_fill = null

# ===== Typewriter API =====
func start_typewriter(final_text: String, cps: float = 30.0, by_word: bool = false) -> void:
	if final_text == "":
		skip_typewriter(); return
	_tw_final_text = final_text
	_tw_by_word = by_word
	_tw_cps = max(1.0, cps)
	_tw_accum = 0.0
	_tw_index = 0
	_tw_buffer = ""
	_setup_children()
	_prefit_for_text(final_text)
	if _tw_by_word:
		_tw_tokens = _tokenize_words(final_text)
	else:
		_tw_tokens = []
	_set_typewriter_visible_text("")
	_tw_active = true
	set_process(true)

func skip_typewriter() -> void:
	if _tw_final_text != "": _set_typewriter_visible_text(_tw_final_text)
	_stop_typewriter()

func stop_typewriter() -> void:
	_stop_typewriter()

func _stop_typewriter() -> void:
	_tw_active = false
	_tw_tokens = []

func _set_typewriter_visible_text(s: String) -> void:
	if _label != null and is_instance_valid(_label): _label.text = s
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.text = s
	if not _tw_active: _text = s

# Helper: simple whitespace test (space, tab, newline, carriage return)
func _is_whitespace(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\n" or ch == "\r"

func _tokenize_words(s: String) -> Array[String]:
	var out: Array[String] = []
	var i := 0
	while i < s.length():
		var start := i
		while i < s.length() and not _is_whitespace(s[i]): i += 1
		var word_end := i
		while i < s.length() and _is_whitespace(s[i]): i += 1
		var end := i
		if end > start:
			out.append(s.substr(start, end - start))
	return out

func _prefit_for_text(content: String) -> void:
	var ep := _get_effective_label_padding()
	var avail := Vector2(
		max(1.0, size.x - max(0.0, TextFitPadding.x) - max(0.0, ep.x) - max(0.0, ep.z)),
		max(1.0, size.y - max(0.0, TextFitPadding.y) - max(0.0, ep.y) - max(0.0, ep.w))
	)
	if avail.x <= 1.0 or avail.y <= 1.0: return
	if _label_type == LabelKind.RichTextLabel and _rich_label != null and is_instance_valid(_rich_label):
		var base_font: Font = _rich_label.get_theme_font("normal_font") if _rich_label.get_theme_font("normal_font") != null else ThemeDB.fallback_font
		if base_font == null: return
		var plain := _strip_bbcode(content)
		var wrap_w := avail.x if LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
		var lo := MinFontSize
		var hi := MaxFontSize
		var best := lo
		while lo <= hi:
			var mid := int((lo + hi) / 2)
			var ts := base_font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, mid)
			if ts.x <= avail.x and ts.y <= avail.y:
				best = mid; lo = mid + 1
			else:
				hi = mid - 1
		_apply_rich_label_font_overrides(base_font, best)
		_last_fit_font_size = best
	elif _label_type == LabelKind.Label and _label != null and is_instance_valid(_label):
		var fnt: Font = _label.get_theme_font("font") if _label.get_theme_font("font") != null else ThemeDB.fallback_font
		if fnt == null: return
		var wrap_w2 := avail.x if LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
		var lo2 := MinFontSize
		var hi2 := MaxFontSize
		var best2 := lo2
		while lo2 <= hi2:
			var mid2 := int((lo2 + hi2) / 2)
			var ts2 := fnt.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, wrap_w2, mid2)
			if ts2.x <= avail.x and ts2.y <= avail.y:
				best2 = mid2; lo2 = mid2 + 1
			else:
				hi2 = mid2 - 1
		_label.add_theme_font_override("font", fnt)
		_label.add_theme_font_size_override("font_size", best2)
		_last_fit_font_size = best2

func _process(delta: float) -> void:
	# Editor: throttle polling to reduce overhead
	if Engine.is_editor_hint():
		__editor_poll_accum += delta
		if __editor_poll_accum >= __EDITOR_POLL_INTERVAL:
			__editor_poll_accum = 0.0
			_auto_enable_actions_once_from_connections()
			var sig := _editor_build_signature()
			if sig != __editor_last_sig:
				__editor_last_sig = sig
				queue_refresh(true, true, true)
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
	# Hold progression
	if _is_pressed and (not EnableCooldown or not _cooldown_active or AllowHoldDuringCooldown or EnableHoldBuildUp):
		_hold_timer += delta
	if not _is_holding and _hold_timer >= HoldDuration:
		_is_holding = true
		if _action_enabled(ACT_HOLD):
			emit_signal("hold")
			_debug("Hold signal emitted")
			if HoldAction.is_valid(): HoldAction.call()
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
			_debug("Cooldown completed")
			if is_instance_valid(_cooldown): _cooldown.visible = false
			if is_instance_valid(_cooldown): _cooldown.size = Vector2.ZERO; _cooldown.position = Vector2.ZERO

	# Typewriter progression
	if _tw_active:
		var step: float = 1.0 / max(1.0, _tw_cps)
		_tw_accum += delta
		var changed := false
		if _tw_by_word and _tw_tokens.size() > 0:
			while _tw_accum >= step and _tw_index < _tw_tokens.size():
				_tw_accum -= step
				_tw_buffer += _tw_tokens[_tw_index]
				_tw_index += 1
				changed = true
			if changed: _set_typewriter_visible_text(_tw_buffer)
			if _tw_index >= _tw_tokens.size(): _stop_typewriter()
		else:
			while _tw_accum >= step and _tw_index < _tw_final_text.length():
				_tw_accum -= step
				_tw_buffer += _tw_final_text[_tw_index]
				_tw_index += 1
				changed = true
			if changed: _set_typewriter_visible_text(_tw_buffer)
			if _tw_index >= _tw_final_text.length(): _stop_typewriter()

	# Do not reassign exported state properties every frame; avoids extra setter work
	# Properties are updated at the time state changes (press/hover/toggle/hold)

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
				_debug("JoystickStarted (mouse)")
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
				_debug("Pressed signal emitted (mouse)")
				if PressedAction.is_valid(): PressedAction.call()
			else:
				_debug("Pressed skipped (mouse ActionMask)")
			# Toggle on press for explicit ToggleOnPress, or momentary+Toggle action
			if InteractionMode == InteractionModeEnum.ToggleOnPress or (InteractionMode == InteractionModeEnum.Momentary and _action_enabled(ACT_TOGGLE)):
				_is_toggled = not _is_toggled
				_update_overlay()
				emit_signal("toggled", _is_toggled)
				if ToggledAction.is_valid(): ToggledAction.call(_is_toggled)
				_debug("Toggled -> %s (mouse press)" % str(_is_toggled))
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
				_debug("Released signal emitted (mouse)")
				if ReleasedAction.is_valid(): ReleasedAction.call()
			elif not _action_enabled(ACT_RELEASED):
				_debug("Released skipped (mouse ActionMask)")
			if EnableCooldown and (CooldownTrigger == CooldownTriggerEnum.OnRelease or CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease):
				_start_cooldown()
			if is_instance_valid(_hold_fill): _remove_hold_fill()

			if _vj_active:
				emit_signal("joystick_axis", Vector2.ZERO)
				_debug("JoystickAxis zero (mouse release)")
				emit_signal("joystick_ended")
				_debug("JoystickEnded (mouse release)")
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
				_debug("Toggled -> %s (mouse release)" % str(_is_toggled))
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
					var dir_norm := direction.normalized()
					emit_signal("swipe", dir_norm)
					_debug("Swipe emitted dir=%s source=MouseMotion" % str(dir_norm))
					if SwipeAction.is_valid(): SwipeAction.call(dir_norm)
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
						var dir_norm3 := direction3.normalized()
						emit_signal("swipe", dir_norm3)
						_debug("Swipe emitted dir=%s source=TouchDrag" % str(dir_norm3))
						if SwipeAction.is_valid(): SwipeAction.call(dir_norm3)
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
				if JoystickSnapToInput:
					_move_to_global(gp)
				if JoystickHideWhenInactive:
					visible = true
				emit_signal("joystick_started")
				_debug("JoystickStarted (touch)")
				_emit_joystick_axis_for(gp)
				if EnableJoystickArea:
					_ensure_and_refresh_joystick_area(_vj_home_global)
					_set_joystick_area_visible(true)
			elif FollowMode == FollowModeEnum.FollowBoth:
				_enable_top_level(true)
				_move_to_global(gp)
			if _action_enabled(ACT_PRESSED):
				emit_signal("pressed")
				_debug("Pressed signal emitted (touch)")
				if PressedAction.is_valid():
					PressedAction.call()
			else:
				_debug("Pressed skipped (touch ActionMask)")
			_apply_visual_state()
		elif not st.pressed:
			_is_pressed = false
			_is_holding = false
			_is_swiping = false
			_swipe_start = Vector2.ZERO
			if _action_enabled(ACT_RELEASED) and inside:
				emit_signal("released")
				_debug("Released signal emitted (touch)")
				if ReleasedAction.is_valid():
					ReleasedAction.call()
			elif not _action_enabled(ACT_RELEASED):
				_debug("Released skipped (touch ActionMask)")
			if _vj_active:
				emit_signal("joystick_axis", Vector2.ZERO)
				_debug("JoystickAxis zero (touch release)")
				emit_signal("joystick_ended")
				_debug("JoystickEnded (touch release)")
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
				var dir_norm := direction.normalized()
				emit_signal("swipe", dir_norm)
				_debug("Swipe emitted dir=%s source=TouchDrag" % str(dir_norm))
				if SwipeAction.is_valid(): SwipeAction.call(dir_norm)
				_swipe_start = Vector2.ZERO
	elif _action_enabled(ACT_SWIPE) and _is_pressed and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		if _swipe_start == Vector2.ZERO:
			_swipe_start = motion.position
		else:
			var direction2 := motion.position - _swipe_start
			if direction2.length() > SwipeThreshold:
				var dir_norm2 := direction2.normalized()
				emit_signal("swipe", dir_norm2)
				_debug("Swipe emitted dir=%s source=MouseMotion" % str(dir_norm2))
				if SwipeAction.is_valid(): SwipeAction.call(dir_norm2)
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
					var dir_normh := directionh.normalized()
					emit_signal("swipe", dir_normh)
					_debug("Swipe emitted dir=%s source=Hover" % str(dir_normh))
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
	# Free only managed nodes; leave user-added children intact
	for n in [_panel, _background_tex, _icon, _label, _rich_label, _overlay, _cooldown, _hold_fill, _default_thumb, _vj_area_panel]:
		if n != null and is_instance_valid(n):
			var p = n.get_parent()
			if p == self or (p != null and is_instance_valid(p) and p == _managed_root):
				p.remove_child(n)
			n.queue_free()
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

	if BackgroundType == BackgroundMode.UsePanel:
		_panel = Panel.new()
		_panel.name = "Panel"
		_managed_add_child(_panel)
		_ensure_full_rect(_panel)
		_panel.mouse_filter = MOUSE_FILTER_PASS

	if BackgroundType == BackgroundMode.UseTexture and BackgroundTexture != null:
		_background_tex = TextureRect.new()
		_background_tex.name = "Background"
		_background_tex.texture = BackgroundTexture
		_background_tex.expand_mode = BackgroundExpandMode
		_background_tex.stretch_mode = BackgroundStretchMode
		_background_tex.flip_h = BackgroundFlipH
		_background_tex.flip_v = BackgroundFlipV
		_background_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_managed_add_child(_background_tex)
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
		_managed_add_child(_icon)
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
	var need := _selected
	var alive := _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == self
	if need and not alive:
		_overlay = ColorRect.new()
		_overlay.name = "Overlay"
		_overlay.color = SelectedColor
		_overlay.mouse_filter = MOUSE_FILTER_PASS
		_managed_add_child(_overlay)
		_ensure_full_rect(_overlay)
	elif (not need) and alive:
		var p := _overlay.get_parent()
		if p != null and is_instance_valid(p): p.remove_child(_overlay)
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
	if _background_tex != null: move_child(_background_tex, idx); idx += 1
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

# Accessor helper classes for ergonomic code usage ($OmniButton.Label.Text, etc.)
class OmniLabelAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var text:
		get: return _o.Text
		set(value): _o.Text = value
	var type:
		get: return _o.LabelType
		set(value): _o.LabelType = value
	var modulate:
		get: return _o.TextModulate
		set(value): _o.TextModulate = value; _o.queue_refresh(false, false, false)
	var font:
		get: return _o.LabelFont
		set(value): _o.LabelFont = value; _o.queue_refresh(false, false, true)
	var color:
		get: return _o.LabelTextColor
		set(value): _o.LabelTextColor = value; _o.queue_refresh(false, false, false)
	var fit_padding:
		get: return _o.TextFitPadding
		set(value): _o.TextFitPadding = value; _o.queue_refresh(false, false, true)
	var min_font_size:
		get: return _o.MinFontSize
		set(value): _o.MinFontSize = value; _o.queue_refresh(false, false, true)
	var max_font_size:
		get: return _o.MaxFontSize
		set(value): _o.MaxFontSize = value; _o.queue_refresh(false, false, true)
	var fixed_font_size:
		get: return _o.FixedFontSize
		set(value): _o.FixedFontSize = value; _o.queue_refresh(false, false, true)
	var auto_size:
		get: return _o.EnableTextAutoSize
		set(value): _o.EnableTextAutoSize = value; _o.queue_refresh(false, false, true)
	var h_align:
		get: return _o.LabelHorizontalAlignment
		set(value): _o.LabelHorizontalAlignment = value; _o.queue_refresh(false, false, false)
	var v_align:
		get: return _o.LabelVerticalAlignment
		set(value): _o.LabelVerticalAlignment = value; _o.queue_refresh(false, false, false)
	var padding:
		get: return _o.LabelPadding
		set(value): _o.LabelPadding = value; _o.queue_refresh(false, false, true)
	var pad_left:
		get: return _o.LabelAdditionalPaddingLeft
		set(value): _o.LabelAdditionalPaddingLeft = value; _o.queue_refresh(false, false, true)
	var pad_top:
		get: return _o.LabelAdditionalPaddingTop
		set(value): _o.LabelAdditionalPaddingTop = value; _o.queue_refresh(false, false, true)
	var pad_right:
		get: return _o.LabelAdditionalPaddingRight
		set(value): _o.LabelAdditionalPaddingRight = value; _o.queue_refresh(false, false, true)
	var pad_bottom:
		get: return _o.LabelAdditionalPaddingBottom
		set(value): _o.LabelAdditionalPaddingBottom = value; _o.queue_refresh(false, false, true)
	var autowrap:
		get: return _o.LabelAutowrap
		set(value): _o.LabelAutowrap = value; _o.queue_refresh(false, false, true)
	var bbcode:
		get: return _o.RichLabelUseBBCode
		set(value): _o.RichLabelUseBBCode = value; _o.queue_refresh(false, false, false)

class OmniIconAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var tex:
		get: return _o.IconTexture
		set(value): _o.IconTexture = value; _o.queue_refresh(false, false, false)
	var expand_mode:
		get: return _o.IconExpandMode
		set(value): _o.IconExpandMode = value; _o.queue_refresh(false, false, false)
	var stretch_mode:
		get: return _o.IconStretchMode
		set(value): _o.IconStretchMode = value; _o.queue_refresh(false, false, false)
	var flip_h:
		get: return _o.IconFlipH
		set(value): _o.IconFlipH = value; _o.queue_refresh(false, false, false)
	var flip_v:
		get: return _o.IconFlipV
		set(value): _o.IconFlipV = value; _o.queue_refresh(false, false, false)
	var modulate:
		get: return _o.IconModulate
		set(value): _o.IconModulate = value; _o.queue_refresh(false, false, false)

class OmniBackgroundAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var mode:
		get: return _o.Background
		set(value): _o.Background = value; _o.queue_refresh(true, true, true)
	var tex:
		get: return _o.BackgroundTexture
		set(value): _o.BackgroundTexture = value; _o.queue_refresh(false, false, false)
	var expand_mode:
		get: return _o.BackgroundExpandMode
		set(value): _o.BackgroundExpandMode = value; _o.queue_refresh(false, false, false)
	var stretch_mode:
		get: return _o.BackgroundStretchMode
		set(value): _o.BackgroundStretchMode = value; _o.queue_refresh(false, false, false)
	var flip_h:
		get: return _o.BackgroundFlipH
		set(value): _o.BackgroundFlipH = value; _o.queue_refresh(false, false, false)
	var flip_v:
		get: return _o.BackgroundFlipV
		set(value): _o.BackgroundFlipV = value; _o.queue_refresh(false, false, false)
	var modulate:
		get: return _o.BackgroundModulate
		set(value): _o.BackgroundModulate = value; _o.queue_refresh(false, false, false)

class OmniPanelAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var modulate:
		get: return _o.PanelModulate
		set(value): _o.PanelModulate = value; _o.queue_refresh(false, false, false)
	var theme_type:
		get: return _o.PanelThemeType
		set(value): _o.PanelThemeType = value; _o.queue_refresh(false, true, false)
	var theme_variation:
		get: return _o.PanelThemeVariation
		set(value): _o.PanelThemeVariation = value; _o.queue_refresh(false, true, false)
	var style_box:
		get: return _o.PanelStyleBox
		set(value): _o.PanelStyleBox = value; _o.queue_refresh(false, true, false)

class OmniCooldownAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.EnableCooldown
		set(value): _o.EnableCooldown = value; _o._apply_visual_state()
	var duration:
		get: return _o.CooldownDuration
		set(value): _o.CooldownDuration = value
	var trigger:
		get: return _o.CooldownTrigger
		set(value): _o.CooldownTrigger = value
	var start_filled:
		get: return _o.CooldownStartFilled
		set(value): _o.CooldownStartFilled = value
	var color:
		get: return _o.CooldownColor
		set(value): _o.CooldownColor = value; _o._apply_visual_state()
	var direction:
		get: return _o.CooldownFillDirection
		set(value): _o.CooldownFillDirection = value
	var suspend_hover_scale:
		get: return _o.SuspendHoverScaleDuringCooldown
		set(value): _o.SuspendHoverScaleDuringCooldown = value
	var allow_hold_during:
		get: return _o.AllowHoldDuringCooldown
		set(value): _o.AllowHoldDuringCooldown = value
	var hide_during_charge_up:
		get: return _o.HideCooldownDuringHoldBuildUp
		set(value): _o.HideCooldownDuringHoldBuildUp = value

class OmniChargeUpAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.EnableHoldBuildUp
		set(value): _o.EnableHoldBuildUp = value; _o._apply_visual_state()
	var duration:
		get: return _o.HoldDuration
		set(value): _o.HoldDuration = value
	var color:
		get: return _o.HoldFillColor
		set(value): _o.HoldFillColor = value; _o._apply_visual_state()
	var direction:
		get: return _o.HoldFillDirection
		set(value): _o.HoldFillDirection = value

class OmniOverlayAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.Selected
		set(value): _o.Selected = value; _o.queue_refresh(false, false, false)
	var color:
		get: return _o.SelectedColor
		set(value): _o.SelectedColor = value; _o.queue_refresh(false, false, false)

func _set_label_text() -> void:
	# Remove both if empty
	if _text == "":
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

func _fit_label_text() -> void:
	if _fitting_label:
		return
	var sig := "%s|%s|%s|%s|%s|%s|%s" % [
		_text,
		str(size),
		str(LabelPadding),
		"%s,%s,%s,%s" % [LabelAdditionalPaddingLeft, LabelAdditionalPaddingTop, LabelAdditionalPaddingRight, LabelAdditionalPaddingBottom],
		str(LabelAutowrap),
		str(FixedFontSize),
		str(LabelType)
	]
	if sig == _fit_cache_sig:
		return
	_debug("Autosize begin size=%s type=%s wrap=%s text='%s'" % [str(size), str(LabelType), str(LabelAutowrap), _text])
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
	_last_fit_font_size = best
	_debug("Autosize plain fitted size=%d avail=%s" % [best, str(avail)])
	return true

func _fit_rich_text_label() -> bool:
	var wrap_enabled := LabelAutowrap != TextServer.AUTOWRAP_OFF
	var avail := _calculate_available_area()
	if avail.x <= 1.0 or avail.y <= 1.0:
		call_deferred("_fit_label_text")
		return false
	if _rich_label == null or not is_instance_valid(_rich_label):
		return false
	var base_font: Font = _rich_label.get_theme_font("normal_font") if _rich_label.get_theme_font("normal_font") != null else ThemeDB.fallback_font
	if base_font == null:
		return false
	var plain := _strip_bbcode(_rich_label.text)
	var wrap_w := avail.x if wrap_enabled else -1.0
	var seed := _rich_current_font_size if _rich_current_font_size > 0 else _last_fit_font_size
	if seed > 0:
		var sz0 := _measure_paragraph(base_font, plain, wrap_w, seed)
		if _fits_within(sz0, avail, wrap_enabled):
			var grown := _grow_font_size(base_font, plain, avail, wrap_w, wrap_enabled, seed)
			_apply_rich_label_font_overrides(base_font, grown)
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
			var sz1 := _measure_paragraph(base_font, plain, wrap_w, s)
			if _fits_within(sz1, avail, wrap_enabled):
				_apply_rich_label_font_overrides(base_font, s)
				_rich_label.update_minimum_size()
				_rich_label.queue_redraw()
				_rich_current_font_size = s
				_last_fit_font_size = s
				return true
			guard += 1
	var best := _find_best_font_size(base_font, plain, avail, wrap_w, wrap_enabled)
	best = _grow_font_size(base_font, plain, avail, wrap_w, wrap_enabled, best)
	_apply_rich_label_font_overrides(base_font, best)
	_rich_label.update_minimum_size()
	_rich_label.queue_redraw()
	_rich_current_font_size = best
	_last_fit_font_size = best
	_debug("Autosize rich fitted size=%d avail=%s" % [best, str(avail)])
	return true

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
			_managed_add_child(_vj_area_panel)
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
	if BackgroundType == BackgroundMode.UsePanel and _panel == null:
		_panel = Panel.new()
		_panel.name = "Panel"
		_managed_add_child(_panel)
		_ensure_full_rect(_panel)
		_apply_panel_styling()

	var overlay_alive := _overlay != null and is_instance_valid(_overlay) and _overlay.get_parent() == self
	if _selected and not overlay_alive:
		_overlay = ColorRect.new(); _overlay.name = "Overlay"; _managed_add_child(_overlay)

	if BackgroundType == BackgroundMode.UsePanel and _panel != null:
		_panel.visible = true
		_panel.modulate = PanelModulate
		_apply_invert(_panel)
		_panel.z_index = 0

	if BackgroundType == BackgroundMode.UseTexture and _background_tex != null:
		_background_tex.texture = BackgroundTexture
		_background_tex.flip_h = BackgroundFlipH
		_background_tex.flip_v = BackgroundFlipV
		_background_tex.expand_mode = BackgroundExpandMode
		_background_tex.stretch_mode = BackgroundStretchMode
		_background_tex.modulate = BackgroundModulate
		_apply_invert(_background_tex)
		_background_tex.z_index = 1

	if _icon != null:
		_icon.texture = _icon_texture
		_icon.flip_h = IconFlipH
		_icon.flip_v = IconFlipV
		_icon.expand_mode = IconExpandMode
		_icon.stretch_mode = IconStretchMode
		_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_icon.modulate = IconModulate
		_apply_invert(_icon)
		_icon.z_index = 2

	if _label != null:
		_label.text = _text
		_configure_label(_label)
		_label.add_theme_color_override("font_color", LabelTextColor)
		_label.modulate = TextModulate
		_apply_invert(_label)
		_label.z_index = 3
	if _rich_label != null:
		_rich_label.text = _text
		_configure_rich_label(_rich_label)
		_rich_label.modulate = TextModulate
		_apply_invert(_rich_label)
		_rich_label.z_index = 3

	if _overlay != null and is_instance_valid(_overlay):
		_overlay.visible = true
		_overlay.color = SelectedColor
		_apply_invert(_overlay)
		_overlay.z_index = 4

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
	if BackgroundType != BackgroundMode.UsePanel:
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
	_cooldown_active = true
	_cooldown_time_left = CooldownDuration
	_debug("Cooldown started duration=%s trigger=%s" % [str(CooldownDuration), str(CooldownTrigger)])
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
		if not cb.is_valid():
			continue
		if has_signal(sig) and not is_connected(sig, cb):
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

func _auto_enable_actions_once_from_connections() -> void:
	# Map signal names to action bits
	var map := {
		"pressed": ACT_PRESSED,
		"released": ACT_RELEASED,
		"hover_in": ACT_HOVER,
		"hover_out": ACT_HOVER,
		"toggled": ACT_TOGGLE,
		"hold": ACT_HOLD,
		"swipe": ACT_SWIPE,
		"log": ACT_LOG,
		"warning": ACT_WARNING,
		"error": ACT_ERROR,
	}
	for sig in map.keys():
		var bit: int = map[sig]
		if (_auto_action_once_bits & bit) != 0:
			continue
		if not has_signal(sig):
			continue
		var conns := get_signal_connection_list(sig)
		var has_external := false
		for conn in conns:
			var cb: Callable = conn["callable"]
			if cb.get_object() != self:
				has_external = true
				break
		if has_external:
			ActionMaskBits |= bit
			_auto_action_once_bits |= bit

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
