@tool
class_name Omni_Button
extends Control
## Flexible UI control (press/hover/toggle/hold/swipe, cooldown, optional virtual joystick).
## User decorations: add as direct children (siblings of the internal _Managed node), not inside _Managed.
## Reserved names (purged on refresh): Panel, Background, Icon, Label, RichLabel, Overlay, HoldFill, Cooldown, DefaultThumb, JoystickArea.
## Use ManagedDrawOnTop for draw order; on decorative children set mouse_filter to IGNORE or PASS so input still reaches the button.

## File layout (each #region folds in the script editor):
##   Constants, signals and enums
##   Settings: one region per Inspector category, in Inspector order. A setting's private
##     backing variable sits directly above it.
##   Runtime state: private per-button state, grouped by feature
##   Scripting accessors, Lifecycle, Public API, Overridable hooks, Internal
## Behaviour lives in the static helper files (OmniButtonVisuals, Input, Timing, Text, State,
## Signals, Editor), which take the button as their first argument.


#region Constants, signals and enums
const _accessors = preload("res://addons/omni_button/omni_button_accessors.gd")
## Loaded once per project instead of a ResourceLoader.exists() + load() in every button's _ready.
const _INVERT_MATERIAL = preload("res://addons/omni_button/Shader/InvertColor.tres")

signal pressed
signal released
signal hover_in
signal hover_out
signal toggled(pressed: bool)
signal typewriter_completed
## Emitted for each character the typewriter reveals (not for characters skipped past).
signal typewriter_char_revealed(index: int, character: String)
signal hold
signal swipe(direction: Vector2)
signal swipe_ended
signal log(message: String)
signal warning(message: String)
signal error(message: String)
signal joystick_started
signal joystick_axis(axis: Vector2)
signal joystick_ended

enum CooldownDirection {BottomToTop = 0, TopToBottom = 1, LeftToRight = 2, RightToLeft = 3}
enum BackgroundMode {None = 0, UsePanel = 1, UseTexture = 2}
enum FollowModeEnum {None = 0, FollowBoth = 3, VirtualJoystick = 4}
enum JoystickClampShape {Circle = 0, Rectangle = 1}
enum SwipeInitMode {OnHoverIn = 0, OnPressed = 1}
enum SwipeExitMode {OnHoverOut = 0, OnReleased = 1}
enum CooldownTriggerEnum {None = 0, OnPress = 1, OnRelease = 2, OnPressAndRelease = 3}
enum DebuggerLogMode {OFF = 0, BASIC = 1}
enum LabelKind {None = 2, Label = 0, RichTextLabel = 1}
enum InteractionModeEnum {Momentary = 0, ToggleOnPress = 1, ToggleOnRelease = 2}
## Which modality owns the current press (mouse vs native touch) when emulate_mouse_from_touch is on.
enum PointerGestureSource {None = 0, Mouse = 1, NativeTouch = 2}

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

const TYPEWRITER_EFFECT_TAGS := {
	"wave": true,
	"rainbow": true,
	"tornado": true,
	"pulse": true,
	"shake": true,
	"fade": true
}
#endregion


#region Settings: actions, background, label type, visual effects
@export_subgroup("Actions")
var _action_mask_bits: int = 0
## Emits the Pressed signal and runs its connected action when this button is pressed.
@export var EnablePressedActions: bool:
	get: return _action_enabled(ACT_PRESSED)
	set(value):
		_set_action_enabled(ACT_PRESSED, value)

## Emits the Released signal and runs its connected action when this button is released.
@export var EnableReleasedActions: bool:
	get: return _action_enabled(ACT_RELEASED)
	set(value):
		_set_action_enabled(ACT_RELEASED, value)

## Emits HoverIn and HoverOut and runs their connected actions as the pointer enters or leaves.
@export var EnableHoverActions: bool:
	get: return _action_enabled(ACT_HOVER)
	set(value):
		_set_action_enabled(ACT_HOVER, value)

## Emits Toggled and runs its connected action when the button changes toggle state.
@export var EnableToggleActions: bool:
	get: return _action_enabled(ACT_TOGGLE)
	set(value):
		_set_action_enabled(ACT_TOGGLE, value)

## Emits Hold and runs its connected action when the configured hold duration completes.
@export var EnableHoldActions: bool:
	get: return _action_enabled(ACT_HOLD)
	set(value):
		_set_action_enabled(ACT_HOLD, value)

## Emits Swipe and SwipeEnded and runs their connected actions for recognized swipe gestures.
@export var EnableSwipeActions: bool:
	get: return _action_enabled(ACT_SWIPE)
	set(value):
		var was_on := _action_enabled(ACT_SWIPE)
		_set_action_enabled(ACT_SWIPE, value)
		if was_on != _action_enabled(ACT_SWIPE): _notify_inspector()

## Enables the Log signal and connected action for messages sent through this button.
@export var EnableLogActions: bool:
	get: return _action_enabled(ACT_LOG)
	set(value):
		_set_action_enabled(ACT_LOG, value)

## Enables the Warning signal and connected action for warnings sent through this button.
@export var EnableWarningActions: bool:
	get: return _action_enabled(ACT_WARNING)
	set(value):
		_set_action_enabled(ACT_WARNING, value)

## Enables the Error signal and connected action for errors sent through this button.
@export var EnableErrorActions: bool:
	get: return _action_enabled(ACT_ERROR)
	set(value):
		_set_action_enabled(ACT_ERROR, value)

var PressedAction: Callable
var ReleasedAction: Callable
var HoverInAction: Callable
var HoverOutAction: Callable
var ToggledAction: Callable
var HoldAction: Callable
var SwipeAction: Callable
var LogAction: Callable
var WarningAction: Callable
var ErrorAction: Callable

@export_group("")
var _background_mode := BackgroundMode.None
## None draws no generated background; UsePanel draws a styled Panel; UseTexture draws a TextureRect background.
@export var BackgroundType: BackgroundMode:
	get: return _background_mode
	set(value):
		var changed := _background_mode != value
		_background_mode = value
		if changed:
			notify_property_list_changed()
		_setup_children()
		_apply_panel_styling()
		_invalidate_visual_state()

var _label_type: LabelKind = LabelKind.None
## None creates no text node; Label uses plain text; RichTextLabel supports BBCode and rich text behavior.
@export var LabelType: LabelKind:
	get: return _label_type
	set(value):
		if _label_type == value:
			return
		if _tw_active:
			_typewriter.stop_typewriter()
		_label_type = value
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()
		OmniButtonEditor.refresh_label_type_inspector(self)

var _disabled := false
## Blocks pointer interaction and applies the disabled visual state.
@export var Disabled: bool:
	get: return _disabled
	set(value):
		_disabled = value
		_invalidate_visual_state()

@export_group("Visual Effects")
@export_subgroup("Invert Display")
## Selects the states that invert the button colors: Press, Toggle, Hover, and/or Hold.
@export_flags("Press", "Toggle", "Hover", "Hold") var InvertModes: int = 0
@export_subgroup("Hover")
var _hover_scale := 0.0
## Scale of the button while hovered: 1.2 means 120% of normal size. Zero disables hover scaling. The scale is capped so the button stays inside the viewport.
@export_range(0.0, 3.0, 0.01) var HoverScale: float:
	get: return _hover_scale
	set(value):
		var updated := maxf(0.0, value)
		if is_equal_approx(_hover_scale, updated):
			return
		var was_on := _hover_scale > 0.0
		_hover_scale = updated
		if was_on != (updated > 0.0): _notify_inspector()
		if _hover_scale <= 0.0:
			_hover_target_scale = 1.0
			_enable_top_level(false)
		elif _is_hovering:
			_hover_target_scale = OmniButtonTiming.hover_target_for_viewport(self)
			set_process(true)
		_invalidate_visual_state()

## Speed at which the hover scale transitions between normal and hovered size.
@export_range(0.0, 100.0, 0.1) var HoverLerpSpeed: float = 25.0
@export_subgroup("Selection")
## Tint used by the selected-state overlay.
@export var SelectedColor: Color = Color(1, 1, 1, 0.3)
#endregion


#region Settings: Input & Motion

@export_category("Input & Motion")
## InputMap action that activates this button while it has keyboard focus. Set to empty to disable focused input.
@export var ActivationAction: StringName = &"ui_accept"

@export_group("Hit Area")
## Optional Control whose global rectangle replaces this button's own rectangle for hit-testing (whether a release counts as inside). Drag and virtual joystick movement are also clamped to it.
@export var BoundsSource: Control
## Expands the code-level hit-test rectangle in pixels: x controls left/right and y controls top/bottom. Godot still routes pointer events by this Control's rectangle.
@export var HitSlop: Vector2 = Vector2.ZERO

@export_group("Drag & virtual joystick")
var _follow_mode: FollowModeEnum = FollowModeEnum.None
## None stays in place; FollowBoth moves with the pointer; VirtualJoystick emits joystick axes while the pointer moves within its clamp area. The settings for the chosen mode appear below it.
@export var FollowMode: FollowModeEnum:
	get: return _follow_mode
	set(value):
		if _follow_mode == value:
			return
		_follow_mode = value
		if _follow_mode == FollowModeEnum.None:
			ClampToBounds = true
		if _follow_mode != FollowModeEnum.VirtualJoystick:
			ClampShape = JoystickClampShape.Circle
			JoystickRadiusPx = 0
			JoystickRectSizePx = Vector2.ZERO
			JoystickDeadzone = 0.1
			JoystickSnapToInput = true
			JoystickHideWhenInactive = false
			JoystickResetOnRelease = true
		notify_property_list_changed()
		queue_refresh(true, false, false)

## In FollowBoth mode, keeps the moving button inside its follow clamp rectangle; disabling it allows movement beyond the rectangle.
@export var ClampToBounds: bool = true
## Shorthand for FollowMode == VirtualJoystick, kept for scripts and for scenes saved before
## FollowMode became the single switch. Not shown in the Inspector and not saved.
var EnableVirtualJoystick: bool:
	get: return _follow_mode == FollowModeEnum.VirtualJoystick
	set(value):
		if value:
			FollowMode = FollowModeEnum.VirtualJoystick
		elif _follow_mode == FollowModeEnum.VirtualJoystick:
			FollowMode = FollowModeEnum.None

@export_subgroup("Virtual Joystick")
## Circle constrains movement to a radius; Rectangle constrains movement to the configured width and height.
@export var ClampShape: JoystickClampShape = JoystickClampShape.Circle
## Radius in pixels for circular joystick movement. Zero uses the control size to determine the radius.
@export_range(0, 4096, 1) var JoystickRadiusPx: int = 0
## Width and height in pixels of the rectangular joystick movement area.
@export var JoystickRectSizePx: Vector2 = Vector2.ZERO
## Normalized center radius where joystick input is treated as zero.
@export_range(0.0, 1.0, 0.01) var JoystickDeadzone: float = 0.1
## Moves the virtual joystick control with the pointer while the gesture is active.
@export var JoystickSnapToInput: bool = true
## Hides the control while the virtual joystick is not being used.
@export var JoystickHideWhenInactive: bool = false
## Returns the joystick thumb and axis to neutral when the pointer is released.
@export var JoystickResetOnRelease: bool = true
@export_subgroup("Virtual Joystick Area")
## Draws a visual guide for the joystick movement area.
@export var EnableJoystickArea: bool = false:
	set(value):
		if EnableJoystickArea == value: return
		EnableJoystickArea = value
		_notify_inspector()

## Keeps the joystick area guide visible when the joystick is inactive.
@export var JoystickAreaPersistent: bool = false
## Color of the joystick area guide.
@export var JoystickAreaColor: Color = Color(1, 1, 1, 0.25)
## Line thickness in pixels for the joystick area guide.
@export_range(0, 64, 1) var JoystickAreaThickness: int = 2
## Uses the configured rectangular joystick area when clamping movement.
@export var JoystickAreaUseRectForClamp: bool = false
## Optional path to an external Control used to draw the joystick area guide.
@export var JoystickAreaExternalPath: NodePath
@export_subgroup("Virtual Joystick Thumb")
var _enable_default_thumb := true
## Creates the built-in joystick thumb when no custom thumb is supplied.
@export var EnableDefaultThumb: bool:
	get: return _enable_default_thumb
	set(value):
		if _enable_default_thumb == value:
			return
		_enable_default_thumb = value
		_notify_inspector()
		queue_refresh(true, false, false)

## Default thumb size relative to the joystick movement area.
@export_range(0.1, 1.0, 0.01) var DefaultThumbSizeRatio: float = 0.6
## Color of the built-in joystick thumb.
@export var DefaultThumbColor: Color = Color(1, 1, 1, 0.9)
#endregion


#region Settings: Button

@export_category("Button")

@export_group("Icon")
var _icon_texture: Texture2D
## Texture displayed in the icon layer, behind the button text.
@export var IconTexture: Texture2D:
	get: return _icon_texture
	set(value):
		var had := _icon_texture != null
		_icon_texture = value
		if had != (value != null): _notify_inspector()
		if OmniButtonVisuals.try_sync_icon_in_place(self):
			queue_refresh(false, false, false)
		else:
			queue_refresh(true, false, true)

## Keep Size uses the texture's native dimensions; Ignore Size ignores its minimum size; Fit Width/Height constrain that dimension, with Proportional variants preserving aspect ratio.
@export_enum("Keep Size", "Ignore Size", "Fit Width", "Fit Width Proportional", "Fit Height", "Fit Height Proportional")
var IconExpandMode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
## Chooses scaling, tiling, native-size placement, centering, or aspect-preserving fit/cover behavior for the icon.
@export_enum("Scale", "Tile", "Keep", "Keep Centered", "Keep Aspect", "Keep Aspect Centered", "Keep Aspect Covered")
var IconStretchMode: int = TextureRect.STRETCH_SCALE
## Mirrors the icon texture horizontally.
@export var IconFlipH: bool = false
## Mirrors the icon texture vertically.
@export var IconFlipV: bool = false
## Multiplies the icon texture colors by this color.
@export var IconModulate: Color = Color.WHITE

@export_group("Hold Build-Up")
var _hold_duration := 0.0
## Time the button must remain pressed before the Hold action fires. Zero disables hold build-up.
@export_range(0.0, 5.0, 0.05) var HoldDuration: float:
	get: return _hold_duration
	set(value):
		var updated := maxf(0.0, value)
		if is_equal_approx(_hold_duration, updated):
			return
		var was_on := _hold_duration > 0.0
		_hold_duration = updated
		if was_on != (updated > 0.0): _notify_inspector()
		OmniButtonState.hold_duration_changed(self)
		_invalidate_visual_state()

## Color of the progress fill shown while the button is building up a hold.
@export var HoldFillColor: Color = Color(1, 1, 1, 0.25)
## Direction the hold progress fill advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.
@export var HoldFillDirection: int = CooldownDirection.BottomToTop

@export_group("Swipe")
## Minimum pointer travel in pixels required to recognize a swipe.
@export_range(0.0, 1000.0, 1.0) var SwipeThreshold: float = 20.0
## OnHoverIn begins touch swipe tracking on pointer entry; OnPressed begins tracking on touch press.
@export var TouchSwipeInit: SwipeInitMode = SwipeInitMode.OnHoverIn
## OnHoverOut ends touch swipe tracking when leaving the bounds; OnReleased ends it when the touch is released.
@export var TouchSwipeExit: SwipeExitMode = SwipeExitMode.OnHoverOut
## OnHoverIn begins mouse swipe tracking on pointer entry; OnPressed begins tracking on mouse press.
@export var MouseSwipeInit: SwipeInitMode = SwipeInitMode.OnPressed
## OnHoverOut ends mouse swipe tracking when leaving the bounds; OnReleased ends it when the mouse button is released.
@export var MouseSwipeExit: SwipeExitMode = SwipeExitMode.OnReleased

@export_group("Toggle Behavior")
## Momentary is pressed only while held; Toggle On Press switches state on press; Toggle On Release switches state on release.
@export var InteractionMode: InteractionModeEnum = InteractionModeEnum.Momentary

@export_group("Cooldown")
var _cooldown_trigger := CooldownTriggerEnum.None
## None disables cooldown; OnPress starts it on press; OnRelease starts it on release; OnPressAndRelease starts it on both events.
@export var CooldownTrigger: CooldownTriggerEnum:
	get: return _cooldown_trigger
	set(value):
		if _cooldown_trigger == value:
			return
		var was_on := _cooldown_trigger != CooldownTriggerEnum.None
		_cooldown_trigger = value
		if was_on != (value != CooldownTriggerEnum.None): _notify_inspector()
		if _cooldown_trigger == CooldownTriggerEnum.None:
			_cooldown_active = false
			_cooldown_time_left = 0.0
			_cooldown_delay_pending = false
			_cooldown_delay_left = 0.0
			_cooldown_elapsed = 0.0
			if _cooldown != null and is_instance_valid(_cooldown):
				_cooldown.visible = false
				_cooldown.size = Vector2.ZERO
				_cooldown.position = Vector2.ZERO
		_invalidate_visual_state()

## Wait time after the selected trigger before the cooldown fill begins.
@export_range(0.0, 10.0, 0.01) var CooldownStartDelay: float = 0.0
## Time the cooldown remains active after its start delay.
@export_range(0.05, 60.0, 0.05) var CooldownDuration: float = 1.0
## Shows the cooldown fill as full at the start and drains it, instead of filling from empty.
@export var CooldownStartFilled: bool = false
## Color of the cooldown overlay.
@export var CooldownColor: Color = Color(0, 0, 0, 0.4)
## Direction the cooldown overlay advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.
@export var CooldownFillDirection: int = CooldownDirection.BottomToTop
## Inverts the button colors while cooldown is active.
@export var InvertOnCooldown: bool = false:
	set(value):
		if InvertOnCooldown == value: return
		InvertOnCooldown = value
		_notify_inspector()

## Duration of the cooldown color-inversion transition. Zero applies it immediately.
@export_range(0.0, 10.0, 0.01) var CooldownInvertDuration: float = 0.0
## Temporarily returns the button to normal scale while cooldown is active.
@export var SuspendHoverScaleDuringCooldown: bool = false
## Allows hold build-up while cooldown is active.
@export var AllowHoldDuringCooldown: bool = false
## Hides the cooldown overlay while hold build-up is visible.
@export var HideCooldownDuringHoldBuildUp: bool = true
#endregion


#region Settings: Text

@export_category("Text")
var _text: String = ""
## Text displayed on the button. Setting non-empty text automatically selects the plain Label if LabelType is None.
@export_multiline var Text: String:
	get: return _text
	set(value):
		_text = value if value != null else ""
		if _label_type == LabelKind.None and _text != "":
			_label_type = LabelKind.Label
			OmniButtonEditor.refresh_label_type_inspector(self)
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

## Displays plain Label text in uppercase without changing the Text property.
@export var LabelUppercase: bool = false:
	set(value):
		LabelUppercase = value
		queue_refresh(false, false, false)

## Clips plain Label text at the label boundary.
@export var LabelClipText: bool = false:
	set(value):
		LabelClipText = value
		queue_refresh(false, false, false)

## None keeps text unchanged; Trim Character/Word removes overflow; Ellipsis adds an ellipsis; Trim Word with Ellipsis trims at a word boundary and adds an ellipsis.
@export_enum("None", "Trim Character", "Trim Word", "Ellipsis", "Trim Word with Ellipsis") var LabelTextOverrun: int = 0:
	set(value):
		LabelTextOverrun = value
		queue_refresh(false, false, false)

@export_group("Typography")
## Font resource used to draw button text.
@export var LabelFont: Font
## Base color used to draw the button text.
@export var LabelTextColor: Color = Color.WHITE
## Additional color modulation applied to the text.
@export var TextModulate: Color = Color.WHITE
## Horizontal alignment of the text inside its label.
@export var LabelHorizontalAlignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## Vertical alignment of the text inside its label.
@export var LabelVerticalAlignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
var _label_autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
## Off never wraps; Arbitary wraps anywhere; Word wraps at word boundaries; Smart favors word boundaries but can break long words.
@export var LabelAutowrap: TextServer.AutowrapMode:
	get: return _label_autowrap
	set(value):
		if _label_autowrap == value:
			return
		_label_autowrap = value
		OmniButtonText.invalidate_autosize_state(self)
		_invalidate_visual_state()
		_schedule_fit_label()

@export_category("RichTextLabel")

@export_group("Text Behavior")
## Parses BBCode tags in RichTextLabel text when enabled; otherwise tags are shown literally.
@export var RichLabelUseBBCode: bool = true:
	set(value):
		RichLabelUseBBCode = value
		queue_refresh(false, false, false)

## Makes the RichTextLabel size to its content instead of clipping to its assigned rectangle.
@export var RichTextFitContent: bool = false:
	set(value):
		RichTextFitContent = value
		queue_refresh(false, false, false)

## Allows the RichTextLabel to be scrolled.
@export var RichTextScrollActive: bool = false:
	set(value):
		RichTextScrollActive = value
		queue_refresh(false, false, false)

## Automatically scrolls to the newest content as text is added.
@export var RichTextScrollFollowing: bool = false:
	set(value):
		RichTextScrollFollowing = value
		queue_refresh(false, false, false)

## Allows users to select text in the RichTextLabel.
@export var RichTextSelectionEnabled: bool = false:
	set(value):
		RichTextSelectionEnabled = value
		queue_refresh(false, false, false)

## Shows the RichTextLabel context menu for text actions.
@export var RichTextContextMenuEnabled: bool = true:
	set(value):
		RichTextContextMenuEnabled = value
		queue_refresh(false, false, false)

@export_category("Extra")

@export_group("Text Sizing")
## Extra horizontal and vertical space reserved when calculating an autosized font.
@export var TextFitPadding: Vector2 = Vector2(12, 4)
## Smallest font size considered by text autosizing. A wider MinFontSize-to-MaxFontSize range increases fit-search work.
@export_range(6, 300, 1) var MinFontSize: int = 6
## Largest font size considered by text autosizing.
@export_range(6, 300, 1) var MaxFontSize: int = 100
## Forces this font size when positive; zero lets autosizing choose the size.
@export_range(0, 300, 1) var FixedFontSize: int = 0
## Automatically fits text to the available label area.
@export var EnableTextAutoSize: bool = true
## Uniform internal padding applied around the label text.
@export var LabelPadding: Vector2 = Vector2.ZERO
@export_subgroup("Additional Padding")
## Additional left-side space excluded from the label text area.
@export_range(0, 4096, 1) var LabelAdditionalPaddingLeft: float = 0.0
## Additional top-side space excluded from the label text area.
@export_range(0, 4096, 1) var LabelAdditionalPaddingTop: float = 0.0
## Additional right-side space excluded from the label text area.
@export_range(0, 4096, 1) var LabelAdditionalPaddingRight: float = 0.0
## Additional bottom-side space excluded from the label text area.
@export_range(0, 4096, 1) var LabelAdditionalPaddingBottom: float = 0.0

@export_group("Typewriter")
## Text used by StartTypewriter when no text argument is provided.
@export var TextToType: String = ""
## Temporarily returns the button to normal scale while typewriter text is active.
@export var SuspendHoverDuringTypewriter: bool = true
## Delays supported RichTextLabel effect tags until their text is revealed.
@export var DelayEffectTagsDuringTypewriter: bool = true
## Finishes the active typewriter effect when the button is pressed.
@export var FinishTypewriterOnPress: bool = true
#endregion


#region Settings: Panel and TextureRect backgrounds

@export_category("Panel")
## Theme variation applied to the generated Panel background.
@export var PanelThemeVariation: String = ""
## Default Panel style. State-specific styles use this when they are not assigned.
@export var PanelStyleBox: StyleBox
## Panel style used while the pointer hovers over the button; falls back to PanelStyleBox.
@export var PanelHoverStyleBox: StyleBox:
	set(value):
		PanelHoverStyleBox = value
		queue_refresh(false, true, false)

## Panel style used while the button is pressed; falls back to PanelStyleBox.
@export var PanelPressedStyleBox: StyleBox:
	set(value):
		PanelPressedStyleBox = value
		queue_refresh(false, true, false)

## Panel style used while Disabled is true; falls back to PanelStyleBox.
@export var PanelDisabledStyleBox: StyleBox:
	set(value):
		PanelDisabledStyleBox = value
		queue_refresh(false, true, false)

## Panel style used while the button has keyboard focus; falls back to PanelStyleBox.
@export var PanelFocusStyleBox: StyleBox:
	set(value):
		PanelFocusStyleBox = value
		queue_refresh(false, true, false)

## Color modulation applied to the generated Panel background.
@export var PanelModulate: Color = Color.WHITE

@export_category("TextureRect")
var _background_texture: Texture2D
## Texture displayed by the TextureRect background when BackgroundType is UseTexture.
@export var texture: Texture2D:
	get: return _background_texture
	set(value):
		_background_texture = value
		_queue_background_refresh()

var _background_expand_mode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
## Controls how the background texture affects the TextureRect minimum size.
@export var expand_mode: int:
	get: return _background_expand_mode
	set(value):
		_background_expand_mode = value
		_queue_background_refresh()

var _background_stretch_mode: int = TextureRect.STRETCH_SCALE
## Controls how the background texture is fitted or drawn inside its rectangle.
@export var stretch_mode: int:
	get: return _background_stretch_mode
	set(value):
		_background_stretch_mode = value
		_queue_background_refresh()

var _background_flip_h := false
## Mirrors the background texture horizontally.
@export var flip_h: bool:
	get: return _background_flip_h
	set(value):
		_background_flip_h = value
		queue_refresh(false, false, false)

var _background_flip_v := false
## Mirrors the background texture vertically.
@export var flip_v: bool:
	get: return _background_flip_v
	set(value):
		_background_flip_v = value
		queue_refresh(false, false, false)

## Color modulation applied to the TextureRect background.
@export var BackgroundModulate: Color = Color.WHITE
#endregion


#region Settings: Composition and Debug

@export_category("Composition")
var _managed_draw_on_top := true
## Draws OmniButton-generated visuals above other direct children when enabled; disable to draw user children on top.
@export var ManagedDrawOnTop: bool:
	get: return _managed_draw_on_top
	set(value):
		_managed_draw_on_top = value
		OmniButtonVisuals.position_managed_root(self)

@export_category("Debug")
@export_subgroup("State")
var _selected := false
## Sets the selected visual state programmatically.
@export var Selected: bool:
	get: return _selected
	set(value):
		OmniButtonState.set_selected(self, value)

var _is_toggled := false
## Gets or sets the current toggle state programmatically.
@export var IsToggled: bool:
	get: return _is_toggled
	set(value):
		OmniButtonState.set_toggled(self, value)

var _is_pressed := false
## Gets or sets the current pressed state programmatically.
@export var IsPressed: bool:
	get: return _is_pressed
	set(value):
		OmniButtonState.set_pressed(self, value)

var _is_hovering := false
## Gets or sets the current hover state programmatically.
@export var IsHovering: bool:
	get: return _is_hovering
	set(value):
		OmniButtonState.set_hovering(self, value)

var _is_holding := false
## Gets or sets the current hold state programmatically.
@export var IsHolding: bool:
	get: return _is_holding
	set(value):
		OmniButtonState.set_holding(self, value)

@export_subgroup("Logging")
## Writes per-button diagnostic messages to the output: Off disables logging; Basic enables it.
@export_enum("Off", "Basic") var DebuggerLog: int = DebuggerLogMode.OFF:
	set(value):
		DebuggerLog = value
		_dbg = value != DebuggerLogMode.OFF and not Engine.is_editor_hint()
#endregion


#region Runtime state

# Build and refresh queue
## False until _ready: exported setters fired during scene instantiation only record what changed,
## and _ready builds every generated node once. Previously the Text setter built a Label, IconTexture
## queued a rebuild that freed it, and _ready plus the first frame each re-applied everything.
var _built := false
var _pending_children_refresh := false
var _pending_panel_styling := false
var _pending_visual_refresh := false
var _pending_fit_label := false
## Cheap refresh for interaction state (hover/press/toggle/hold/focus/cooldown): invert material,
## panel stylebox and selection overlay only. Full config re-application uses _pending_visual_refresh.
var _pending_state_refresh := false
var _runtime_refit_frames := 0

# Logging and auto-enabled actions
## Cached "logging on" flag. Call sites check `if _dbg:` before formatting so disabled logging costs no string work.
var _dbg := false
var _auto_action_once_bits := 0

# Pointer, hover and focus
var _hover_target_scale := 1.0
var _hover_top_level_active := false
var _saved_global_pos := Vector2.ZERO
## -1 = mouse session; >= 0 = finger index for native touch press on this control
var _active_touch_index := -1
var _pointer_gesture_source: PointerGestureSource = PointerGestureSource.None
var _active_activation_action: StringName = &""

# Hold and cooldown
var _hold_timer := 0.0
var _cooldown_active := false
var _cooldown_time_left := 0.0
var _cooldown_delay_pending := false
var _cooldown_delay_left := 0.0
var _cooldown_elapsed := 0.0

# Swipe
var _swipe_start := Vector2.ZERO
var _swipe_origin := Vector2.ZERO
var _is_swiping := false
## True once a swipe signal has fired in the current gesture; gates swipe_ended.
var _swipe_emitted := false
var _touch_swipe_eligible := false

# Text fitting
# Cache the last chosen autosize to accelerate append cases
var _last_fit_font_size: int = -1
var _rich_current_font_size: int = -1
var _rich_verify_passes: int = 0
var _fitting_label := false
var _fit_cache_sig: Array = []
var _theme_applying := false

# Typewriter: the rest of its state lives in OmniButtonTypewriter
var _tw_active := false

# Virtual joystick
var _vj_active := false
var _vj_home_global := Vector2.ZERO
var _vj_saved_mouse_filter := MOUSE_FILTER_STOP

# Managed root and generated visuals
var _managed_root: Control
## Generated visuals (OmniDrawItem canvas items, not nodes). The label stays a node.
var _panel: OmniDrawItem
var _background_tex: OmniDrawItem
var _icon: OmniDrawItem
var _label: Label
var _rich_label: RichTextLabel
var _overlay: OmniDrawItem
var _cooldown: OmniDrawItem
var _hold_fill: OmniDrawItem
var _invert_material: ShaderMaterial
var _default_thumb: OmniDrawItem
var _vj_area_panel: Panel

# Lazily created feature objects (they keep per-feature state) and editor change detection
var _typewriter: OmniButtonTypewriter
var _joystick: OmniButtonJoystick
var __editor_last_sig: String = ""
#endregion


#region Scripting accessors
## Scripting accessors (button.label.color = ...). Created on first use rather than for every
## button in _ready, since most buttons never touch them.
var _accessor_cache := {}

func _accessor(key: StringName, script_class) -> RefCounted:
	var a: RefCounted = _accessor_cache.get(key)
	if a == null:
		a = script_class.new(self)
		_accessor_cache[key] = a
	return a

var label: _accessors.OmniLabelAccessor:
	get: return _accessor(&"label", _accessors.OmniLabelAccessor) as _accessors.OmniLabelAccessor

var icon: _accessors.OmniIconAccessor:
	get: return _accessor(&"icon", _accessors.OmniIconAccessor) as _accessors.OmniIconAccessor

var background: _accessors.OmniBackgroundAccessor:
	get: return _accessor(&"background", _accessors.OmniBackgroundAccessor) as _accessors.OmniBackgroundAccessor

var panel: _accessors.OmniPanelAccessor:
	get: return _accessor(&"panel", _accessors.OmniPanelAccessor) as _accessors.OmniPanelAccessor

var overlay: _accessors.OmniOverlayAccessor:
	get: return _accessor(&"overlay", _accessors.OmniOverlayAccessor) as _accessors.OmniOverlayAccessor

var cooldown: _accessors.OmniCooldownAccessor:
	get: return _accessor(&"cooldown", _accessors.OmniCooldownAccessor) as _accessors.OmniCooldownAccessor

var charge_up: _accessors.OmniChargeUpAccessor:
	get: return _accessor(&"charge_up", _accessors.OmniChargeUpAccessor) as _accessors.OmniChargeUpAccessor
#endregion


#region Lifecycle and engine callbacks

## No signal connections are made here: hover and focus arrive as notifications (see
## _notification), and pressed/released/... reach handlers through the signals alone. Each
## connection cost ~0.6 KB per button, and the old self-connections made handlers that were
## connected before the button entered the tree run twice per event.
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		add_to_group("_omni_button_editor_poll")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	if Selected and BackgroundType == BackgroundMode.None:
		BackgroundType = BackgroundMode.UsePanel
	_invert_material = _INVERT_MATERIAL as ShaderMaterial
	_built = true
	OmniButtonVisuals.setup_children(self)
	_apply_visual_state()
	_fit_label_text()
	# Everything queued by pre-ready setters is covered by the build above.
	_pending_children_refresh = false; _pending_panel_styling = false
	_pending_visual_refresh = false; _pending_state_refresh = false; _pending_fit_label = false
	# Runtime layout often settles after _ready; refit once deferred and for a few frames.
	call_deferred("_fit_label_text")
	if not Engine.is_editor_hint():
		_runtime_refit_frames = 4
	OmniButtonSignals.auto_enable_actions_once_from_connections(self)
	if not Engine.is_editor_hint() and _follow_mode == FollowModeEnum.VirtualJoystick and JoystickHideWhenInactive:
		visible = false
	_update_unhandled_input_processing()

func _exit_tree() -> void:
	if is_in_group("_omni_button_editor_poll"):
		remove_from_group("_omni_button_editor_poll")
	# Generated canvas items survive a tree exit (reparenting keeps them under _Managed); they are
	# released when the button itself is freed and its references drop.

func _process(delta: float) -> void:
	# Apply any pending refresh in a single coalesced pass
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_state_refresh or _pending_fit_label:
		if _pending_children_refresh:
			_setup_children(); _pending_children_refresh = false
		if _pending_visual_refresh:
			# Full pass already includes panel styling and state visuals.
			_apply_visual_state()
			_pending_visual_refresh = false; _pending_panel_styling = false; _pending_state_refresh = false
		else:
			if _pending_panel_styling:
				_apply_panel_styling(); _pending_panel_styling = false
			if _pending_state_refresh:
				OmniButtonVisuals.apply_state_visuals(self); _pending_state_refresh = false
		if _pending_fit_label:
			_fit_label_text(); _pending_fit_label = false
	OmniButtonTiming.process_runtime(self, delta)
	# Typewriter progression
	if _tw_active:
		_typewriter.process_typewriter(delta)
	# Runtime: allow a few frames of refit while layout settles. The fit cache key includes size and
	# every fit input, so these passes cost one array compare unless layout actually moved.
	if not Engine.is_editor_hint() and _runtime_refit_frames > 0:
		_runtime_refit_frames -= 1
		_fit_label_text()

	_try_stop_process_when_fully_idle()
	# Do not reassign exported state properties every frame; avoids extra setter work
	# Properties are updated at the time state changes (press/hover/toggle/hold)

func _try_stop_process_when_fully_idle() -> void:
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_state_refresh or _pending_fit_label:
		return
	if _runtime_refit_frames > 0:
		return
	if _tw_active or _cooldown_delay_pending:
		return
	if _cooldown_trigger != CooldownTriggerEnum.None and _cooldown_active:
		return
	if _is_pressed and _hold_duration > 0.0 and not _is_holding:
		return
	if OmniButtonTiming.hover_scale_animation_pending(self):
		return
	set_process(false)

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_MOUSE_ENTER:
			OmniButtonInput.on_mouse_entered(self)
		NOTIFICATION_MOUSE_EXIT:
			OmniButtonInput.on_mouse_exited(self)
		NOTIFICATION_FOCUS_ENTER, NOTIFICATION_FOCUS_EXIT:
			_on_focus_changed()
		NOTIFICATION_RESIZED:
			_layout_content()
			_fit_label_text()
			if _background_mode == BackgroundMode.UsePanel: queue_redraw()
			if _default_thumb != null and is_instance_valid(_default_thumb): _ensure_joystick().update_default_thumb_visual()
			if _is_hovering and _hover_scale > 0.0:
				OmniButtonTiming.update_hover_pivots(self); _hover_target_scale = OmniButtonTiming.hover_target_for_viewport(self); set_process(true)
		NOTIFICATION_THEME_CHANGED:
			# Theme fonts are not part of the fit cache key; force one refit.
			_fit_cache_sig = []
			_apply_theme_now(); _apply_panel_styling(); _fit_label_text()
			if _default_thumb != null and is_instance_valid(_default_thumb): _ensure_joystick().update_default_thumb_visual()
			if _is_hovering and _hover_scale > 0.0: _hover_target_scale = OmniButtonTiming.hover_target_for_viewport(self); set_process(true)
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				OmniButtonState.reset_press_state(self, true, true)
				IsHovering = false
		NOTIFICATION_PREDELETE:
			_exit_tree()

func _gui_input(event: InputEvent) -> void:
	OmniButtonInput.gui_input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	OmniButtonInput.unhandled_input(self, event)

func _validate_property(property: Dictionary) -> void:
	OmniButtonEditor.validate_property(self, property)

func _editor_poll() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	OmniButtonEditor.process_editor(self)
#endregion


#region Public API

func queue_refresh(children:=false, panel_styling:=false, fit_label:=true) -> void:
	_pending_children_refresh = _pending_children_refresh or children
	_pending_panel_styling = _pending_panel_styling or panel_styling
	_pending_visual_refresh = true
	_pending_fit_label = _pending_fit_label or fit_label
	set_process(true)

func start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_ensure_typewriter().start_typewriter(final_text, cps, by_word, preserve_bbcode_tags)

func start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_ensure_typewriter().start_typewriter_from_text_to_type(cps, by_word, preserve_bbcode_tags)

func skip_typewriter() -> void:
	_ensure_typewriter().skip_typewriter()

func stop_typewriter() -> void:
	_ensure_typewriter().stop_typewriter()

func start_virtual_joystick_at(global_point: Vector2) -> void:
	_ensure_joystick().start_virtual_joystick_at(global_point)

func update_virtual_joystick(global_point: Vector2) -> void:
	_ensure_joystick().update_virtual_joystick(global_point)

func stop_virtual_joystick() -> void:
	_ensure_joystick().stop_virtual_joystick()

func start_cooldown() -> void:
	OmniButtonTiming.start_cooldown(self)

func print_log(message: String) -> void:
	emit_signal("log", message)
	if LogAction.is_valid(): LogAction.call(message)
	else: _run_built_in_log(message)

func print_warn(message: String) -> void:
	warning.emit(message)
	if WarningAction.is_valid(): WarningAction.call(message)
	else: _run_built_in_warning(message)

func print_err(message: String) -> void:
	error.emit(message)
	if ErrorAction.is_valid(): ErrorAction.call(message)
	else: _run_built_in_error(message)
#endregion


#region Overridable hooks

# Override in a script that extends Omni_Button. Each hook runs after its signal is emitted,
# and only when the matching Action (PressedAction, ...) is not set.

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
#endregion


#region Internal

func _debug(message: String) -> void:
	if _dbg:
		print("[OmniButton:%s] %s" % [name, message])

## Rebuilds the Inspector when a feature switch flips, so that feature's settings show or hide.
## Only the on/off transition notifies (not every slider step), and never at runtime.
func _notify_inspector() -> void:
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _action_enabled(bit: int) -> bool:
	return (_action_mask_bits & bit) != 0

func _set_action_enabled(bit: int, enabled: bool) -> void:
	if enabled:
		_action_mask_bits |= bit
	else:
		_action_mask_bits &= ~bit

## Full re-application of configuration + state. Use for property/config changes.
func _invalidate_visual_state() -> void:
	# Theme reaches generated children through normal Control inheritance; _apply_theme_now() only
	# needs to run on NOTIFICATION_THEME_CHANGED, not on every property change.
	if not _pending_visual_refresh:
		_pending_visual_refresh = true
		set_process(true)

## Interaction-state change only (hover/press/toggle/hold/focus/cooldown). Coalesced into the next frame.
func _invalidate_state_visuals() -> void:
	if not _pending_state_refresh:
		_pending_state_refresh = true
		set_process(true)

## Runtime: coalesce autosize with the next _process pass (after ApplyVisualState). Editor: fit immediately for inspector.
func _schedule_fit_label() -> void:
	if Engine.is_editor_hint():
		_fit_label_text()
	else:
		_pending_fit_label = true
		set_process(true)

## apply_visual_state() already pushes texture/expand/stretch/flip onto a live Background node,
## so a full child rebuild is only needed when that node must be created or removed.
func _queue_background_refresh() -> void:
	var live := _background_tex != null and is_instance_valid(_background_tex)
	var wanted := _background_mode == BackgroundMode.UseTexture and _background_texture != null
	queue_refresh(live != wanted, false, false)

func _on_focus_changed() -> void:
	if not has_focus() and _active_activation_action != &"":
		OmniButtonInput.release_activation_action(self)
	_update_unhandled_input_processing()
	_invalidate_state_visuals()

## _unhandled_input only matters while focused (activation action) or mid-gesture (release outside).
## Keeping it off otherwise stops every idle button from receiving every unhandled event.
func _update_unhandled_input_processing() -> void:
	if Engine.is_editor_hint():
		return
	var needed: bool = (_is_pressed or _vj_active or _is_swiping or _is_hovering) \
		or (focus_mode != FOCUS_NONE and has_focus()) \
		or (_active_activation_action != &"")
	if needed != is_processing_unhandled_input():
		set_process_unhandled_input(needed)

func _ensure_typewriter() -> OmniButtonTypewriter:
	if _typewriter == null:
		_typewriter = OmniButtonTypewriter.new(self)
	return _typewriter

func _ensure_joystick() -> OmniButtonJoystick:
	if _joystick == null:
		_joystick = OmniButtonJoystick.new(self)
	return _joystick

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

func _apply_theme_now() -> void:
	if _theme_applying: return
	_theme_applying = true
	if _label != null and is_instance_valid(_label): _label.theme = theme
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.theme = theme
	_theme_applying = false

# The wrappers below skip work until _ready has built the generated nodes. _layout_content,
# _fit_label_text, _verify_rich_text_fit and _reset_pressed_visuals_after_cooldown_start are
# also call_deferred targets (called by name), so they stay methods on the node.

func _setup_children() -> void:
	if not _built: return
	OmniButtonVisuals.setup_children(self)
	call_deferred("_layout_content")

func _update_overlay() -> void:
	if not _built: return
	OmniButtonVisuals.update_overlay(self)

func _layout_content() -> void:
	if not _built: return
	OmniButtonVisuals.layout_content(self)

func _set_label_text() -> void:
	if not _built: return
	OmniButtonText.set_label_text(self)

func _fit_label_text() -> void:
	if not _built: return
	OmniButtonText.fit_label_text(self)

func _apply_visual_state() -> void:
	if not _built: return
	OmniButtonVisuals.apply_visual_state(self)

func _apply_panel_styling() -> void:
	if not _built: return
	OmniButtonVisuals.apply_panel_styling(self)

func _verify_rich_text_fit() -> void:
	OmniButtonText.verify_rich_text_fit(self)

func _reset_pressed_visuals_after_cooldown_start() -> void:
	OmniButtonTiming.reset_pressed_visuals_after_cooldown_start(self)
#endregion
