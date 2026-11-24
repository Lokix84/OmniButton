@tool
class_name OmniButton
extends Control
## a button that does pretty much everything a game needs: press, release, toggle, hover, hold,
## swipe, cooldowns, typewriter text, and it can even be a virtual joystick. works with mouse,
## touch, keyboard and gamepad.
##
## turn stuff on in the inspector and only the settings for what's on show up. the rest keep
## their values, they're just hidden. to react to it, connect a signal like [signal pressed],
## [signal toggled] or [signal hold], or set one of the [code]*_action[/code] callables like
## [member pressed_action]. if you connect a signal before the button is ready it flips that
## action's checkbox on for you.
## the text sizes itself to fit the button (or uses [member fixed_font_size] if you set one), can be
## a [Label] or a [RichTextLabel] with bbcode, and can type itself out with [method start_typewriter].
## the typewriter also gets the timing tags [code][pause=0.5][/code], [code][speed=10][/code] and
## [code][/speed][/code].
## [codeblock]
## var button := OmniButton.new()
## button.text = "Start"
## button.size = Vector2(200, 60)
## button.pressed.connect(func(): print("Start pressed"))
## add_child(button)
## [/codeblock]
## if you want your own decorations on it, add them as direct children of the button, next to the
## internal [code]_Managed[/code] node, not inside it. [member managed_draw_on_top] picks which draws
## on top, and set [member Control.mouse_filter] to Ignore or Pass on them so clicks still get to the
## button. don't use these names for your own children, the button makes nodes with them and clears
## them out on refresh: Panel, Background, Icon, Label, RichLabel, Overlay, HoldFill, Cooldown,
## DefaultThumb, JoystickArea.

# how this file is laid out (every #region folds up in the script editor):
#   constants, signals and enums up top
#   then the settings, one region per inspector category, same order you see them in.
#     each setting's private backing var sits right above it
#   then runtime state, grouped by feature
#   then accessors, lifecycle, public api, hooks you can override, internal stuff
# most of the real work happens in the static helpers in core/ (OmniButtonVisuals, Input, Timing,
# Text, State, Signals, Editor). they all take the button as their first argument.


#region Constants, signals and enums
const _Accessors = preload("res://addons/omni_button/core/omni_button_accessors.gd")
## loaded once for the whole project so every button doesn't do its own exists() + load() in _ready.
const _INVERT_MATERIAL = preload("res://addons/omni_button/core/shader/InvertColor.tres")

## fires when the button gets pressed: mouse, touch, or [member activation_action] while it has focus. needs [member enable_pressed_actions] on.
signal pressed
## fires when the button gets let go. needs [member enable_released_actions] on.
signal released
## fires when the pointer moves onto the button. needs the hover action on.
signal hover_in
## fires when the pointer leaves the button. needs the hover action on.
signal hover_out
## fires when the button flips on or off (see [member interaction_mode]). [param pressed] is the new state.
signal toggled(pressed: bool)
## fires when the typewriter finishes. also fires if [method skip_typewriter] or [method stop_typewriter] cut it short.
signal typewriter_completed
## fires for every character the typewriter shows. skipped characters don't count.
signal typewriter_char_revealed(index: int, character: String)
## fires once when the hold fills up (so [member hold_duration] has to be above zero). needs the hold action on.
signal hold
## fires while swiping, [param direction] is normalized. needs the swipe action on.
signal swipe(direction: Vector2)
## fires when a swipe is over.
signal swipe_ended
## fires from [method print_log] when the log action is on.
signal log(message: String)
## fires from [method print_warn] when the warning action is on.
signal warning(message: String)
## fires from [method print_err] when the error action is on.
signal error(message: String)
## fires when someone starts dragging the virtual joystick.
signal joystick_started
## fires while the virtual joystick moves. [param axis] goes -1 to 1 on each axis, deadzone already taken out.
signal joystick_axis(axis: Vector2)
## fires when the virtual joystick gets let go.
signal joystick_ended

enum CooldownDirection {BOTTOM_TO_TOP = 0, TOP_TO_BOTTOM = 1, LEFT_TO_RIGHT = 2, RIGHT_TO_LEFT = 3}
enum BackgroundMode {NONE = 0, USE_PANEL = 1, USE_TEXTURE = 2}
enum FollowMode {NONE = 0, FOLLOW_BOTH = 3, VIRTUAL_JOYSTICK = 4}
enum JoystickClampShape {CIRCLE = 0, RECTANGLE = 1}
enum SwipeInitMode {ON_HOVER_IN = 0, ON_PRESSED = 1}
enum SwipeExitMode {ON_HOVER_OUT = 0, ON_RELEASED = 1}
enum CooldownTrigger {NONE = 0, ON_PRESS = 1, ON_RELEASE = 2, ON_PRESS_AND_RELEASE = 3}
enum DebuggerLogMode {OFF = 0, BASIC = 1}
enum LabelKind {NONE = 2, LABEL = 0, RICH_TEXT_LABEL = 1}
enum InteractionMode {MOMENTARY = 0, TOGGLE_ON_PRESS = 1, TOGGLE_ON_RELEASE = 2}
## who owns the current press (mouse or real touch) when emulate_mouse_from_touch is on.
enum PointerGestureSource {NONE = 0, MOUSE = 1, NATIVE_TOUCH = 2}

# invert_modes and ActionMask bit flags
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
## sends [signal pressed] and runs [member pressed_action] when the button gets pressed.
@export var enable_pressed_actions: bool:
	get: return _action_enabled(ACT_PRESSED)
	set(value):
		_set_action_enabled(ACT_PRESSED, value)

## sends [signal released] and runs [member released_action] when the button gets let go.
@export var enable_released_actions: bool:
	get: return _action_enabled(ACT_RELEASED)
	set(value):
		_set_action_enabled(ACT_RELEASED, value)

## sends [signal hover_in] and [signal hover_out] (and runs their actions) as the pointer comes and goes.
@export var enable_hover_actions: bool:
	get: return _action_enabled(ACT_HOVER)
	set(value):
		_set_action_enabled(ACT_HOVER, value)

## sends [signal toggled] and runs [member toggled_action] when the button flips on or off.
@export var enable_toggle_actions: bool:
	get: return _action_enabled(ACT_TOGGLE)
	set(value):
		_set_action_enabled(ACT_TOGGLE, value)

## sends [signal hold] and runs [member hold_action] once the hold fills up.
@export var enable_hold_actions: bool:
	get: return _action_enabled(ACT_HOLD)
	set(value):
		_set_action_enabled(ACT_HOLD, value)

## sends [signal swipe] and [signal swipe_ended] (and runs their actions) when it sees a swipe.
@export var enable_swipe_actions: bool:
	get: return _action_enabled(ACT_SWIPE)
	set(value):
		var was_on := _action_enabled(ACT_SWIPE)
		_set_action_enabled(ACT_SWIPE, value)
		if was_on != _action_enabled(ACT_SWIPE): _notify_inspector()

## turns on [signal log] and [member log_action] for messages sent through this button.
@export var enable_log_actions: bool:
	get: return _action_enabled(ACT_LOG)
	set(value):
		_set_action_enabled(ACT_LOG, value)

## turns on [signal warning] and [member warning_action] for warnings sent through this button.
@export var enable_warning_actions: bool:
	get: return _action_enabled(ACT_WARNING)
	set(value):
		_set_action_enabled(ACT_WARNING, value)

## turns on [signal error] and [member error_action] for errors sent through this button.
@export var enable_error_actions: bool:
	get: return _action_enabled(ACT_ERROR)
	set(value):
		_set_action_enabled(ACT_ERROR, value)

## runs after [signal pressed] goes out. if you set it, it replaces the built in [code]_run_built_in_pressed[/code] hook.
var pressed_action: Callable
## runs after [signal released]. if you set it, it replaces the built in released hook.
var released_action: Callable
## runs after [signal hover_in]. if you set it, it replaces the built in hover in hook.
var hover_in_action: Callable
## runs after [signal hover_out]. if you set it, it replaces the built in hover out hook.
var hover_out_action: Callable
## runs after [signal toggled]. if you set it, it replaces the built in toggled hook.
var toggled_action: Callable
## runs after [signal hold]. if you set it, it replaces the built in hold hook.
var hold_action: Callable
## runs after [signal swipe]. if you set it, it replaces the built in swipe hook.
var swipe_action: Callable
## runs after [signal log] in [method print_log]. if you set it, it's used instead of the normal [method @GlobalScope.print].
var log_action: Callable
## runs after [signal warning] in [method print_warn]. if you set it, it's used instead of the normal [method @GlobalScope.push_warning].
var warning_action: Callable
## runs after [signal error] in [method print_err]. if you set it, it's used instead of the normal [method @GlobalScope.push_error].
var error_action: Callable

@export_group("")
var _background_mode := BackgroundMode.NONE
## none means no background. use panel draws a styled panel, use texture draws a texture.
@export var background_type: BackgroundMode:
	get: return _background_mode
	set(value):
		var changed := _background_mode != value
		_background_mode = value
		if changed:
			notify_property_list_changed()
		_setup_children()
		_apply_panel_styling()
		_invalidate_visual_state()

var _label_type: LabelKind = LabelKind.NONE
## none means no text at all. label is plain text, rich text label lets you use bbcode and effects.
@export var label_type: LabelKind:
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
## stops the button from taking clicks and switches it to the disabled look.
@export var disabled: bool:
	get: return _disabled
	set(value):
		_disabled = value
		_invalidate_visual_state()
## gets multiplied into the text and icon colors while [member disabled] is on so it looks greyed out. white leaves them alone.
@export var disabled_modulate: Color = Color(1, 1, 1, 0.45):
	set(value):
		disabled_modulate = value
		_invalidate_visual_state()

@export_group("Visual Effects")
@export_subgroup("Invert Display")
## which states flip the button's colors: press, toggle, hover, hold. pick as many as you want.
@export_flags("Press", "Toggle", "Hover", "Hold") var invert_modes: int = 0
@export_subgroup("Hover")
var _hover_scale := 0.0
## how big the button gets on hover. 1.2 is 120%, zero turns it off. it won't grow past the edge of the screen.
@export_range(0.0, 3.0, 0.01) var hover_scale: float:
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

## how fast it grows and shrinks between normal and hover size.
@export_range(0.0, 100.0, 0.1) var hover_lerp_speed: float = 25.0
@export_subgroup("Selection")
## tint for the selected overlay.
@export var selected_color: Color = Color(1, 1, 1, 0.3)
#endregion


#region Settings: Input & Motion

@export_category("Input & Motion")
## input map action that presses this button while it has focus. leave it empty and focus does nothing.
@export var activation_action: StringName = &"ui_accept"
## input map action that gets held down while this button is pressed, same idea as TouchScreenButton's action. so an on screen "jump" button works with [code]Input.is_action_pressed("jump")[/code] and [code]_input()[/code]. empty does nothing.
@export var output_action: StringName = &"":
	set(value):
		if value == output_action: return
		OmniButtonState.release_output_action(self)
		output_action = value
## the output_action we're holding down right now, so we can always let go of it.
var _held_output_action: StringName = &""

@export_group("Hit Area")
## optional Control to use for hit testing instead of the button's own rect (decides if a release counts as inside). dragging and the virtual joystick also stay inside it.
@export var bounds_source: Control
## grows the hit test rect by this many pixels, x for left and right, y for top and bottom. godot still sends events by the Control's real rect though.
@export var hit_slop: Vector2 = Vector2.ZERO

@export_group("Drag & virtual joystick")
var _follow_mode: FollowMode = FollowMode.NONE
## none stays put. follow both moves with the pointer. virtual joystick sends joystick axes while the pointer moves inside its area. the settings for whichever you pick show up under it.
@export var follow_mode: FollowMode:
	get: return _follow_mode
	set(value):
		if _follow_mode == value:
			return
		_follow_mode = value
		if _follow_mode == FollowMode.NONE:
			clamp_to_bounds = true
		if _follow_mode != FollowMode.VIRTUAL_JOYSTICK:
			clamp_shape = JoystickClampShape.CIRCLE
			joystick_radius_px = 0
			joystick_rect_size_px = Vector2.ZERO
			joystick_deadzone = 0.1
			joystick_snap_to_input = true
			joystick_hide_when_inactive = false
			joystick_reset_on_release = true
		notify_property_list_changed()
		queue_refresh(true, false, false)

## in follow both, keeps the button inside its follow area. turn it off and it can go anywhere.
@export var clamp_to_bounds: bool = true
## shortcut for follow_mode == VIRTUAL_JOYSTICK. it's still here for scripts and for scenes saved
## before follow_mode was the one switch. not shown in the inspector and not saved.
var enable_virtual_joystick: bool:
	get: return _follow_mode == FollowMode.VIRTUAL_JOYSTICK
	set(value):
		if value:
			follow_mode = FollowMode.VIRTUAL_JOYSTICK
		elif _follow_mode == FollowMode.VIRTUAL_JOYSTICK:
			follow_mode = FollowMode.NONE

@export_subgroup("Virtual Joystick")
## circle keeps the stick inside a radius, rectangle keeps it inside a width and height.
@export var clamp_shape: JoystickClampShape = JoystickClampShape.CIRCLE
## radius in pixels for the circle. zero works it out from the button's size.
@export_range(0, 4096, 1) var joystick_radius_px: int = 0
## width and height in pixels for the rectangle.
@export var joystick_rect_size_px: Vector2 = Vector2.ZERO
## how much of the middle counts as zero, 0 to 1.
@export_range(0.0, 1.0, 0.01) var joystick_deadzone: float = 0.1
## moves the joystick along with the pointer while it's being used.
@export var joystick_snap_to_input: bool = true
## hides the joystick when nobody's using it.
@export var joystick_hide_when_inactive: bool = false
## snaps the thumb and axis back to the middle when you let go.
@export var joystick_reset_on_release: bool = true
@export_subgroup("Virtual Joystick Area")
## draws an outline of the area the joystick can move in.
@export var enable_joystick_area: bool = false:
	set(value):
		if enable_joystick_area == value: return
		enable_joystick_area = value
		_notify_inspector()

## keeps that outline showing even when the joystick isn't being used.
@export var joystick_area_persistent: bool = false
## color of the outline.
@export var joystick_area_color: Color = Color(1, 1, 1, 0.25)
## how thick the outline is in pixels.
@export_range(0, 64, 1) var joystick_area_thickness: int = 2
## clamps the stick to the rectangle area you set up.
@export var joystick_area_use_rect_for_clamp: bool = false
## optional path to some other Control to draw the outline on.
@export var joystick_area_external_path: NodePath
@export_subgroup("Virtual Joystick Thumb")
var _enable_default_thumb := true
## makes a built in thumb if you didn't give it one.
@export var enable_default_thumb: bool:
	get: return _enable_default_thumb
	set(value):
		if _enable_default_thumb == value:
			return
		_enable_default_thumb = value
		_notify_inspector()
		queue_refresh(true, false, false)

## size of the built in thumb compared to the joystick area.
@export_range(0.1, 1.0, 0.01) var default_thumb_size_ratio: float = 0.6
## color of the built in thumb.
@export var default_thumb_color: Color = Color(1, 1, 1, 0.9)
#endregion


#region Settings: Button

@export_category("Button")

@export_group("Icon")
var _icon_texture: Texture2D
## the icon texture. it sits behind the text.
@export var icon_texture: Texture2D:
	get: return _icon_texture
	set(value):
		var had := _icon_texture != null
		_icon_texture = value
		if had != (value != null): _notify_inspector()
		if OmniButtonVisuals.try_sync_icon_in_place(self):
			queue_refresh(false, false, false)
		else:
			queue_refresh(true, false, true)

## keep size uses the texture's own size, ignore size ignores it, fit width/height lock that side, and the proportional ones keep the aspect ratio.
@export_enum("Keep Size", "Ignore Size", "Fit Width", "Fit Width Proportional", "Fit Height", "Fit Height Proportional")
var icon_expand_mode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
## how the icon gets drawn: scaled, tiled, native size, centered, or fit/cover keeping the aspect ratio.
@export_enum("Scale", "Tile", "Keep", "Keep Centered", "Keep Aspect", "Keep Aspect Centered", "Keep Aspect Covered")
var icon_stretch_mode: int = TextureRect.STRETCH_SCALE
## flips the icon left to right.
@export var icon_flip_h: bool = false
## flips the icon upside down.
@export var icon_flip_v: bool = false
## gets multiplied into the icon's colors.
@export var icon_modulate: Color = Color.WHITE

@export_group("Hold Build-Up")
var _hold_duration := 0.0
## how long you have to hold the button before the hold action fires. zero turns hold off.
@export_range(0.0, 5.0, 0.05) var hold_duration: float:
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

## color of the fill that grows while you're holding.
@export var hold_fill_color: Color = Color(1, 1, 1, 0.25)
## which way the hold fill grows: 0 bottom to top, 1 top to bottom, 2 left to right, 3 right to left.
@export var hold_fill_direction: int = CooldownDirection.BOTTOM_TO_TOP

@export_group("Swipe")
## how far in pixels the pointer has to move before it counts as a swipe.
@export_range(0.0, 1000.0, 1.0) var swipe_threshold: float = 20.0
## on hover in starts tracking a touch swipe as soon as the finger moves onto it, on pressed waits for the touch to press it.
@export var touch_swipe_init: SwipeInitMode = SwipeInitMode.ON_HOVER_IN
## on hover out ends a touch swipe when the finger leaves, on released ends it when the finger lifts.
@export var touch_swipe_exit: SwipeExitMode = SwipeExitMode.ON_HOVER_OUT
## on hover in starts tracking a mouse swipe when the pointer moves onto it, on pressed waits for a click.
@export var mouse_swipe_init: SwipeInitMode = SwipeInitMode.ON_PRESSED
## on hover out ends a mouse swipe when the pointer leaves, on released ends it when the mouse button comes up.
@export var mouse_swipe_exit: SwipeExitMode = SwipeExitMode.ON_RELEASED

@export_group("Toggle Behavior")
## momentary is only pressed while you hold it. toggle on press flips on press, toggle on release flips on release.
@export var interaction_mode: InteractionMode = InteractionMode.MOMENTARY

@export_group("Cooldown")
var _cooldown_trigger := CooldownTrigger.NONE
## none means no cooldown. on press starts it on press, on release on release, on press and release on both.
@export var cooldown_trigger: CooldownTrigger:
	get: return _cooldown_trigger
	set(value):
		if _cooldown_trigger == value:
			return
		var was_on := _cooldown_trigger != CooldownTrigger.NONE
		_cooldown_trigger = value
		if was_on != (value != CooldownTrigger.NONE): _notify_inspector()
		if _cooldown_trigger == CooldownTrigger.NONE:
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

## how long to wait after the trigger before the cooldown fill starts.
@export_range(0.0, 10.0, 0.01) var cooldown_start_delay: float = 0.0
## how long the cooldown lasts after that wait.
@export_range(0.05, 60.0, 0.05) var cooldown_duration: float = 1.0
## starts the cooldown fill full and drains it, instead of filling it up from empty.
@export var cooldown_start_filled: bool = false
## color of the cooldown overlay.
@export var cooldown_color: Color = Color(0, 0, 0, 0.4)
## which way the cooldown overlay moves: 0 bottom to top, 1 top to bottom, 2 left to right, 3 right to left.
@export var cooldown_fill_direction: int = CooldownDirection.BOTTOM_TO_TOP
## flips the button's colors while the cooldown is running.
@export var invert_on_cooldown: bool = false:
	set(value):
		if invert_on_cooldown == value: return
		invert_on_cooldown = value
		_notify_inspector()

## how long that color flip takes. zero is instant.
@export_range(0.0, 10.0, 0.01) var cooldown_invert_duration: float = 0.0
## puts the button back to normal size while the cooldown is running.
@export var suspend_hover_scale_during_cooldown: bool = false
## lets hold keep building while the cooldown is running.
@export var allow_hold_during_cooldown: bool = false
## hides the cooldown overlay while the hold fill is showing.
@export var hide_cooldown_during_hold_build_up: bool = true
#endregion


#region Settings: Text

@export_category("Text")
var _text: String = ""
## the text on the button. if label_type is none and you give it some text it switches to a plain label for you.
@export_multiline var text: String:
	get: return _text
	set(value):
		_text = value if value != null else ""
		if _label_type == LabelKind.NONE and _text != "":
			_label_type = LabelKind.LABEL
			OmniButtonEditor.refresh_label_type_inspector(self)
		if _tw_active:
			_invalidate_visual_state()
			return
		_set_label_text()
		_invalidate_visual_state()
		_schedule_fit_label()

## shows plain label text in all caps without actually changing [member text].
@export var label_uppercase: bool = false:
	set(value):
		label_uppercase = value
		queue_refresh(false, false, false)

## cuts off plain label text at the edge of the label.
@export var label_clip_text: bool = false:
	set(value):
		label_clip_text = value
		queue_refresh(false, false, false)

## none leaves the text alone. trim character/word cuts off what doesn't fit, ellipsis adds "...", and trim word with ellipsis cuts at a word and adds "...".
@export_enum("None", "Trim Character", "Trim Word", "Ellipsis", "Trim Word with Ellipsis") var label_text_overrun: int = 0:
	set(value):
		label_text_overrun = value
		queue_refresh(false, false, false)

@export_group("Typography")
## font for the text.
@export var label_font: Font
## color of the text.
@export var label_text_color: Color = Color.WHITE
## extra color multiplied on top of the text.
@export var text_modulate: Color = Color.WHITE
## left, center or right inside the label.
@export var label_horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
## top, center or bottom inside the label.
@export var label_vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
var _label_autowrap: TextServer.AutowrapMode = TextServer.AUTOWRAP_OFF
## off never wraps, arbitrary wraps anywhere, word wraps between words, smart tries words first but will break a long word if it has to.
@export var label_autowrap: TextServer.AutowrapMode:
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
## reads the bbcode tags in rich text when on. off shows the tags as plain text.
@export var rich_label_use_bbcode: bool = true:
	set(value):
		rich_label_use_bbcode = value
		queue_refresh(false, false, false)

## lets the rich text label grow to fit what's in it instead of getting cut off.
@export var rich_text_fit_content: bool = false:
	set(value):
		rich_text_fit_content = value
		queue_refresh(false, false, false)

## lets the rich text label scroll.
@export var rich_text_scroll_active: bool = false:
	set(value):
		rich_text_scroll_active = value
		queue_refresh(false, false, false)

## scrolls down to the newest text as it gets added.
@export var rich_text_scroll_following: bool = false:
	set(value):
		rich_text_scroll_following = value
		queue_refresh(false, false, false)

## lets players select the rich text.
@export var rich_text_selection_enabled: bool = false:
	set(value):
		rich_text_selection_enabled = value
		queue_refresh(false, false, false)

## shows the right click menu (copy, select all) on the rich text.
@export var rich_text_context_menu_enabled: bool = true:
	set(value):
		rich_text_context_menu_enabled = value
		queue_refresh(false, false, false)

@export_category("Extra")

@export_group("Text Sizing")
## extra room left over on each side when working out the auto font size.
@export var text_fit_padding: Vector2 = Vector2(12, 4)
## smallest font size autosizing will try. the bigger the gap to max_font_size the more sizes it has to try.
@export_range(6, 300, 1) var min_font_size: int = 6
## biggest font size autosizing will try.
@export_range(6, 300, 1) var max_font_size: int = 100
## anything above zero forces that font size. zero lets autosizing pick.
@export_range(0, 300, 1) var fixed_font_size: int = 0
## sizes the text to fit the space it has.
@export var enable_text_auto_size: bool = true
## padding all the way around the text.
@export var label_padding: Vector2 = Vector2.ZERO
@export_subgroup("Additional Padding")
## extra space taken off the left of the text area.
@export_range(0, 4096, 1) var label_additional_padding_left: float = 0.0
## extra space taken off the top of the text area.
@export_range(0, 4096, 1) var label_additional_padding_top: float = 0.0
## extra space taken off the right of the text area.
@export_range(0, 4096, 1) var label_additional_padding_right: float = 0.0
## extra space taken off the bottom of the text area.
@export_range(0, 4096, 1) var label_additional_padding_bottom: float = 0.0

@export_group("Typewriter")
## what [method start_typewriter_from_text_to_type] types out. if it's empty it uses [member text].
@export var text_to_type: String = ""
## puts the button back to normal size while the typewriter is going.
@export var suspend_hover_during_typewriter: bool = true
## holds off on rich text effect tags until the typewriter gets to them.
@export var delay_effect_tags_during_typewriter: bool = true
## pressing the button while it's typing shows the rest of the text right away.
@export var finish_typewriter_on_press: bool = true
#endregion


#region Settings: Panel and TextureRect backgrounds

@export_category("Panel")
## theme variation used on the panel background.
@export var panel_theme_variation: String = ""
## the normal panel style. any state style you leave empty uses this one.
@export var panel_style_box: StyleBox
## panel style while hovered. empty uses panel_style_box.
@export var panel_hover_style_box: StyleBox:
	set(value):
		panel_hover_style_box = value
		queue_refresh(false, true, false)

## panel style while pressed. empty uses panel_style_box.
@export var panel_pressed_style_box: StyleBox:
	set(value):
		panel_pressed_style_box = value
		queue_refresh(false, true, false)

## panel style while [member disabled] is on. empty uses panel_style_box.
@export var panel_disabled_style_box: StyleBox:
	set(value):
		panel_disabled_style_box = value
		queue_refresh(false, true, false)

## panel style while it has focus. empty uses panel_style_box.
@export var panel_focus_style_box: StyleBox:
	set(value):
		panel_focus_style_box = value
		queue_refresh(false, true, false)

## color multiplied over the panel background.
@export var panel_modulate: Color = Color.WHITE

@export_category("TextureRect")
var _background_texture: Texture2D
## the background texture, used when background_type is use texture.
@export var texture: Texture2D:
	get: return _background_texture
	set(value):
		_background_texture = value
		_queue_background_refresh()

var _background_expand_mode: int = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
## how the background texture affects the minimum size.
@export var expand_mode: int:
	get: return _background_expand_mode
	set(value):
		_background_expand_mode = value
		_queue_background_refresh()

var _background_stretch_mode: int = TextureRect.STRETCH_SCALE
## how the background texture gets fit or drawn in its rect.
@export var stretch_mode: int:
	get: return _background_stretch_mode
	set(value):
		_background_stretch_mode = value
		_queue_background_refresh()

var _background_flip_h := false
## flips the background texture left to right.
@export var flip_h: bool:
	get: return _background_flip_h
	set(value):
		_background_flip_h = value
		queue_refresh(false, false, false)

var _background_flip_v := false
## flips the background texture upside down.
@export var flip_v: bool:
	get: return _background_flip_v
	set(value):
		_background_flip_v = value
		queue_refresh(false, false, false)

## color multiplied over the background texture.
@export var background_modulate: Color = Color.WHITE
#endregion


#region Settings: Composition and Debug

@export_category("Composition")
var _managed_draw_on_top := true
## on draws the button's own visuals over your child nodes. turn it off to put your children on top.
@export var managed_draw_on_top: bool:
	get: return _managed_draw_on_top
	set(value):
		_managed_draw_on_top = value
		OmniButtonVisuals.position_managed_root(self)

@export_category("Debug")
@export_subgroup("State")
var _selected := false
## turns the selected look on or off from code.
@export var selected: bool:
	get: return _selected
	set(value):
		OmniButtonState.set_selected(self, value)

var _is_toggled := false
## the toggle state. read it or set it from code.
@export var is_toggled: bool:
	get: return _is_toggled
	set(value):
		OmniButtonState.set_toggled(self, value)

var _is_pressed := false
## the pressed state. read it or set it from code.
@export var is_pressed: bool:
	get: return _is_pressed
	set(value):
		OmniButtonState.set_pressed(self, value)

var _is_hovering := false
## the hover state. read it or set it from code.
@export var is_hovering: bool:
	get: return _is_hovering
	set(value):
		OmniButtonState.set_hovering(self, value)

var _is_holding := false
## the hold state. read it or set it from code.
@export var is_holding: bool:
	get: return _is_holding
	set(value):
		OmniButtonState.set_holding(self, value)

@export_subgroup("Logging")
## prints what this button is doing to the output. off is off, basic turns it on.
@export_enum("Off", "Basic") var debugger_log: int = DebuggerLogMode.OFF:
	set(value):
		debugger_log = value
		_dbg = value != DebuggerLogMode.OFF and not Engine.is_editor_hint()
#endregion


#region Runtime state

# build and refresh queue
## false until _ready. setters that run while the scene is loading just write down what changed
## and _ready builds everything once. it used to be the text setter made a label, icon_texture
## queued a rebuild that threw it away, and then _ready and the first frame both redid everything.
var _built := false
var _pending_children_refresh := false
var _pending_panel_styling := false
var _pending_visual_refresh := false
var _pending_fit_label := false
## the cheap refresh for state changes (hover/press/toggle/hold/focus/cooldown). only touches the
## invert material, panel style and selected overlay. full config redo goes through _pending_visual_refresh.
var _pending_state_refresh := false
var _runtime_refit_frames := 0

# logging and auto enabled actions
## cached "is logging on". callers check `if _dbg:` before building strings so logging off costs nothing.
var _dbg := false
var _auto_action_once_bits := 0

# pointer, hover and focus
var _hover_target_scale := 1.0
var _hover_top_level_active := false
var _saved_global_pos := Vector2.ZERO
var _saved_local_scale := Vector2.ONE
var _saved_local_rotation := 0.0
## -1 means a mouse press, 0 and up is the finger index of a real touch press on this button
var _active_touch_index := -1
var _pointer_gesture_source: PointerGestureSource = PointerGestureSource.NONE
var _active_activation_action: StringName = &""

# hold and cooldown
var _hold_timer := 0.0
var _cooldown_active := false
var _cooldown_time_left := 0.0
var _cooldown_delay_pending := false
var _cooldown_delay_left := 0.0
var _cooldown_elapsed := 0.0

# swipe
var _swipe_start := Vector2.ZERO
var _swipe_origin := Vector2.ZERO
var _is_swiping := false
## true once a swipe has fired in this gesture. swipe_ended only goes out if this is set.
var _swipe_emitted := false
var _touch_swipe_eligible := false

# text fitting
# remember the last autosize so adding text on the end goes quicker
var _last_fit_font_size: int = -1
var _rich_current_font_size: int = -1
var _rich_verify_passes: int = 0
var _fitting_label := false
var _fit_cache_sig: Array = []
var _theme_applying := false

# typewriter, the rest of its state is in OmniButtonTypewriter
var _tw_active := false

# virtual joystick
var _vj_active := false
var _vj_home_global := Vector2.ZERO
var _vj_saved_mouse_filter := MOUSE_FILTER_STOP

# managed root and the stuff we draw
var _managed_root: Control
## the visuals we draw (OmniDrawItem canvas items, not nodes). the label is still a node.
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

# feature objects made when first needed (they keep their own state) and editor change detection
var _typewriter: OmniButtonTypewriter
var _joystick: OmniButtonJoystick
var __editor_last_sig: String = ""
#endregion


#region Scripting accessors
## scripting accessors (button.label.color = ...). made the first time you use one instead of
## for every button in _ready, since most buttons never touch them.
var _accessor_cache := {}

func _accessor(key: StringName, script_class) -> RefCounted:
	var a: RefCounted = _accessor_cache.get(key)
	if a == null:
		a = script_class.new(self)
		_accessor_cache[key] = a
	return a

## shortcut to the text settings: [code]button.label.text[/code], [code].color[/code], [code].font[/code], [code].max_font_size[/code] and so on. each one just passes through to the inspector setting.
var label: _Accessors.OmniLabelAccessor:
	get: return _accessor(&"label", _Accessors.OmniLabelAccessor) as _Accessors.OmniLabelAccessor

## shortcut to the icon settings: [code]button.icon.texture[/code], [code].modulate[/code] and so on.
var icon: _Accessors.OmniIconAccessor:
	get: return _accessor(&"icon", _Accessors.OmniIconAccessor) as _Accessors.OmniIconAccessor

## shortcut to the background texture settings.
var background: _Accessors.OmniBackgroundAccessor:
	get: return _accessor(&"background", _Accessors.OmniBackgroundAccessor) as _Accessors.OmniBackgroundAccessor

## shortcut to the panel style settings: [code]button.panel.style[/code] and so on.
var panel: _Accessors.OmniPanelAccessor:
	get: return _accessor(&"panel", _Accessors.OmniPanelAccessor) as _Accessors.OmniPanelAccessor

## shortcut to the selected overlay settings.
var overlay: _Accessors.OmniOverlayAccessor:
	get: return _accessor(&"overlay", _Accessors.OmniOverlayAccessor) as _Accessors.OmniOverlayAccessor

## shortcut to the cooldown settings: [code]button.cooldown.duration[/code] and so on.
var cooldown: _Accessors.OmniCooldownAccessor:
	get: return _accessor(&"cooldown", _Accessors.OmniCooldownAccessor) as _Accessors.OmniCooldownAccessor

## shortcut to the hold settings: [code]button.charge_up.duration[/code] and so on.
var charge_up: _Accessors.OmniChargeUpAccessor:
	get: return _accessor(&"charge_up", _Accessors.OmniChargeUpAccessor) as _Accessors.OmniChargeUpAccessor
#endregion


#region Lifecycle and engine callbacks

## no signal connections get made here. hover and focus come in as notifications (see
## _notification) and pressed/released/etc get to handlers through the signals on their own.
## every connection was about 0.6 KB per button, and the old self connections made handlers that
## got connected before the button hit the tree run twice per event.
func _enter_tree() -> void:
	if Engine.is_editor_hint():
		add_to_group("_omni_button_editor_poll")

func _ready() -> void:
	mouse_filter = MOUSE_FILTER_STOP
	if selected and background_type == BackgroundMode.NONE:
		background_type = BackgroundMode.USE_PANEL
	_invert_material = _INVERT_MATERIAL as ShaderMaterial
	_built = true
	OmniButtonVisuals.setup_children(self)
	_apply_visual_state()
	_fit_label_text()
	# whatever the setters queued before ready is already covered by the build above.
	_pending_children_refresh = false; _pending_panel_styling = false
	_pending_visual_refresh = false; _pending_state_refresh = false; _pending_fit_label = false
	# layout usually isn't settled yet at _ready, so refit once deferred and then for a few frames.
	call_deferred("_fit_label_text")
	if not Engine.is_editor_hint():
		_runtime_refit_frames = 4
	OmniButtonSignals.auto_enable_actions_once_from_connections(self)
	if not Engine.is_editor_hint() and _follow_mode == FollowMode.VIRTUAL_JOYSTICK and joystick_hide_when_inactive:
		visible = false
	_update_unhandled_input_processing()

func _exit_tree() -> void:
	if is_in_group("_omni_button_editor_poll"):
		remove_from_group("_omni_button_editor_poll")
	OmniButtonState.release_output_action(self)
	# the canvas items we draw stick around through a tree exit (reparenting keeps them under
	# _Managed). they go away when the button itself gets freed.

func _process(delta: float) -> void:
	# do whatever refresh is waiting, all in one go
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_state_refresh or _pending_fit_label:
		if _pending_children_refresh:
			_setup_children(); _pending_children_refresh = false
		if _pending_visual_refresh:
			# the full pass already does panel styling and state visuals.
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
	# typewriter
	if _tw_active:
		_typewriter.process_typewriter(delta)
	# at runtime give layout a few frames of refit to settle. the fit cache key has the size and every
	# fit input in it, so unless the layout actually moved these are just one array compare.
	if not Engine.is_editor_hint() and _runtime_refit_frames > 0:
		_runtime_refit_frames -= 1
		_fit_label_text()

	_try_stop_process_when_fully_idle()
	# don't set the exported state properties every frame, the setters cost something.
	# they get updated when the state actually changes (press/hover/toggle/hold)

func _try_stop_process_when_fully_idle() -> void:
	if _pending_children_refresh or _pending_panel_styling or _pending_visual_refresh or _pending_state_refresh or _pending_fit_label:
		return
	if _runtime_refit_frames > 0:
		return
	if _tw_active or _cooldown_delay_pending:
		return
	if _cooldown_trigger != CooldownTrigger.NONE and _cooldown_active:
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
			if _background_mode == BackgroundMode.USE_PANEL: queue_redraw()
			if _default_thumb != null and is_instance_valid(_default_thumb): _ensure_joystick().update_default_thumb_visual()
			if _is_hovering and _hover_scale > 0.0:
				OmniButtonTiming.update_hover_pivots(self); _hover_target_scale = OmniButtonTiming.hover_target_for_viewport(self); set_process(true)
		NOTIFICATION_THEME_CHANGED:
			# theme fonts aren't in the fit cache key so force a refit.
			_fit_cache_sig = []
			_apply_theme_now(); _apply_panel_styling(); _fit_label_text()
			if _default_thumb != null and is_instance_valid(_default_thumb): _ensure_joystick().update_default_thumb_visual()
			if _is_hovering and _hover_scale > 0.0: _hover_target_scale = OmniButtonTiming.hover_target_for_viewport(self); set_process(true)
		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				OmniButtonState.reset_press_state(self, true, true)
				is_hovering = false
		NOTIFICATION_PREDELETE:
			_exit_tree()

func _gui_input(event: InputEvent) -> void:
	OmniButtonInput.gui_input(self, event)

func _unhandled_input(event: InputEvent) -> void:
	OmniButtonInput.unhandled_input(self, event)

func _validate_property(property: Dictionary) -> void:
	OmniButtonEditor.validate_property(self, property)

## old scenes saved the settings as PascalCase (HoldDuration). this catches those on load and
## hands them to the snake_case version, then the scene saves with the new names next time.
func _set(property: StringName, value: Variant) -> bool:
	var old_name := String(property)
	if old_name.is_empty() or old_name[0] < "A" or old_name[0] > "Z":
		return false
	var new_name := old_name.replace("BBCode", "Bbcode").to_snake_case()
	if not new_name in self:
		return false
	set(new_name, value)
	return true

func _editor_poll() -> void:
	if not Engine.is_editor_hint() or not is_inside_tree():
		return
	OmniButtonEditor.process_editor(self)
#endregion


#region Public API

## queues a refresh for next frame. [param children] rebuilds the visuals, [param panel_styling] redoes the panel styles, [param fit_label] refits the text. call it after changing a setting from code that doesn't refresh on its own (like [member fixed_font_size]).
func queue_refresh(children:=false, panel_styling:=false, fit_label:=true) -> void:
	_pending_children_refresh = _pending_children_refresh or children
	_pending_panel_styling = _pending_panel_styling or panel_styling
	_pending_visual_refresh = true
	_pending_fit_label = _pending_fit_label or fit_label
	set_process(true)

## types [param final_text] out at [param cps] characters a second (whole words if [param by_word] is on). [param preserve_bbcode_tags] keeps the bbcode formatting and switches to a [RichTextLabel]. the timing tags [code][pause=s][/code], [code][speed=cps][/code] and [code][/speed][/code] get handled here and never show up. sends [signal typewriter_char_revealed] for each character and [signal typewriter_completed] at the end.
func start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_ensure_typewriter().start_typewriter(final_text, cps, by_word, preserve_bbcode_tags)

## same as [method start_typewriter] but types [member text_to_type] (or [member text] if that's empty).
func start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	_ensure_typewriter().start_typewriter_from_text_to_type(cps, by_word, preserve_bbcode_tags)

## shows the rest of the typewriter text right away and sends [signal typewriter_completed].
func skip_typewriter() -> void:
	_ensure_typewriter().skip_typewriter()

## stops the typewriter where it is, keeps what's shown so far, and sends [signal typewriter_completed].
func stop_typewriter() -> void:
	_ensure_typewriter().stop_typewriter()

## starts the virtual joystick at [param global_point] like it got touched there.
func start_virtual_joystick_at(global_point: Vector2) -> void:
	_ensure_joystick().start_virtual_joystick_at(global_point)

## moves the virtual joystick to [param global_point].
func update_virtual_joystick(global_point: Vector2) -> void:
	_ensure_joystick().update_virtual_joystick(global_point)

## lets go of the virtual joystick.
func stop_virtual_joystick() -> void:
	_ensure_joystick().stop_virtual_joystick()

## starts the cooldown right now, like its [member cooldown_trigger] just happened.
func start_cooldown() -> void:
	OmniButtonTiming.start_cooldown(self)

## sends [signal log] and runs [member log_action], or just prints [param message] if there's no action set.
func print_log(message: String) -> void:
	emit_signal("log", message)
	if log_action.is_valid(): log_action.call(message)
	else: _run_built_in_log(message)

## sends [signal warning] and runs [member warning_action], or calls [method @GlobalScope.push_warning] if there's no action set.
func print_warn(message: String) -> void:
	warning.emit(message)
	if warning_action.is_valid(): warning_action.call(message)
	else: _run_built_in_warning(message)

## sends [signal error] and runs [member error_action], or calls [method @GlobalScope.push_error] if there's no action set.
func print_err(message: String) -> void:
	error.emit(message)
	if error_action.is_valid(): error_action.call(message)
	else: _run_built_in_error(message)
#endregion


#region Overridable hooks

# override these in a script that extends OmniButton. each one runs after its signal goes out,
# but only if the matching action (pressed_action and so on) isn't set.

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

## redraws the inspector when a feature gets switched on or off so its settings show or hide.
## only the on/off flip does it (not every slider tick), and never at runtime.
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

## full redo of config and state. use it when a setting changes.
func _invalidate_visual_state() -> void:
	# the theme gets to our children through normal Control inheritance, so _apply_theme_now() only
	# has to run on NOTIFICATION_THEME_CHANGED, not every time a property changes.
	if not _pending_visual_refresh:
		_pending_visual_refresh = true
		set_process(true)

## just a state change (hover/press/toggle/hold/focus/cooldown). gets batched into next frame.
func _invalidate_state_visuals() -> void:
	if not _pending_state_refresh:
		_pending_state_refresh = true
		set_process(true)

## at runtime the autosize waits for the next _process (after apply_visual_state). in the editor it fits right away for the inspector.
func _schedule_fit_label() -> void:
	if Engine.is_editor_hint():
		_fit_label_text()
	else:
		_pending_fit_label = true
		set_process(true)

## apply_visual_state() already pushes texture/expand/stretch/flip onto a live Background node,
## so we only need a full rebuild when that node has to be made or removed.
func _queue_background_refresh() -> void:
	var live := _background_tex != null and is_instance_valid(_background_tex)
	var wanted := _background_mode == BackgroundMode.USE_TEXTURE and _background_texture != null
	queue_refresh(live != wanted, false, false)

func _on_focus_changed() -> void:
	if not has_focus() and _active_activation_action != &"":
		OmniButtonInput.release_activation_action(self)
	_update_unhandled_input_processing()
	_invalidate_state_visuals()

## _unhandled_input only matters while focused (activation action) or mid gesture (letting go outside).
## leaving it off the rest of the time means idle buttons don't get every unhandled event.
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
	# top_level drops the parent's transform, so copy its scale and rotation over. that way a button
	# in a scaled container stays the same size and in the same spot while hovered or dragged.
	if enable and not _hover_top_level_active:
		var gt := get_global_transform()
		_saved_global_pos = gt.origin
		_saved_local_scale = scale
		_saved_local_rotation = rotation
		top_level = true
		scale = gt.get_scale()
		rotation = gt.get_rotation()
		position += gt.origin - get_global_transform().origin
		_hover_top_level_active = true
	elif (not enable) and _hover_top_level_active:
		var origin := get_global_transform().origin
		top_level = false
		scale = _saved_local_scale
		rotation = _saved_local_rotation
		var delta := origin - get_global_transform().origin
		var parent_item := get_parent() as CanvasItem
		if parent_item != null:
			# position is in the parent's space, which might be scaled or rotated.
			delta = parent_item.get_global_transform().affine_inverse().basis_xform(delta)
		position += delta
		_hover_top_level_active = false

func _apply_theme_now() -> void:
	if _theme_applying: return
	_theme_applying = true
	if _label != null and is_instance_valid(_label): _label.theme = theme
	if _rich_label != null and is_instance_valid(_rich_label): _rich_label.theme = theme
	_theme_applying = false

# the wrappers below don't do anything until _ready has built everything. _layout_content,
# _fit_label_text, _verify_rich_text_fit and _reset_pressed_visuals_after_cooldown_start also get
# called with call_deferred (by name), so they have to stay methods on the node.

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
