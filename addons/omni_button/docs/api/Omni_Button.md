# Omni_Button

**Inherits:** `Control`

A Control that does everything a button needs: press, release, toggle, hover, hold, swipe, cooldowns, typewriter text and a virtual joystick, with mouse, touch, keyboard and gamepad.

## Description

Turn features on in the Inspector; each feature's settings appear only while it is on, and keep their values when it is off. React to the button by connecting its signals (`pressed`, `toggled`, `hold`, ...) or by setting the matching `*Action` Callable (`PressedAction`, ...). Connecting a signal before the button is ready turns its Action checkbox on automatically. The text autosizes to fit the button (or uses `FixedFontSize`), can be a `Label` or a `RichTextLabel` with BBCode, and can type out with `start_typewriter()`, including the timing tags `[pause=0.5]`, `[speed=10]` and `[/speed]`.

```gdscript
var button := Omni_Button.new()
button.Text = "Start"
button.size = Vector2(200, 60)
button.pressed.connect(func(): print("Start pressed"))
add_child(button)
```

Add your own decorations as direct children of the button (siblings of the internal `_Managed` node), not inside `_Managed`. Use `ManagedDrawOnTop` for draw order, and set `Control.mouse_filter` to Ignore or Pass on decorations so input still reaches the button. Names reserved for generated nodes (purged on refresh): Panel, Background, Icon, Label, RichLabel, Overlay, HoldFill, Cooldown, DefaultThumb, JoystickArea.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`EnablePressedActions`](#enablepressedactions) |  |
| `bool` | [`EnableReleasedActions`](#enablereleasedactions) |  |
| `bool` | [`EnableHoverActions`](#enablehoveractions) |  |
| `bool` | [`EnableToggleActions`](#enabletoggleactions) |  |
| `bool` | [`EnableHoldActions`](#enableholdactions) |  |
| `bool` | [`EnableSwipeActions`](#enableswipeactions) |  |
| `bool` | [`EnableLogActions`](#enablelogactions) |  |
| `bool` | [`EnableWarningActions`](#enablewarningactions) |  |
| `bool` | [`EnableErrorActions`](#enableerroractions) |  |
| `Callable` | [`PressedAction`](#pressedaction) |  |
| `Callable` | [`ReleasedAction`](#releasedaction) |  |
| `Callable` | [`HoverInAction`](#hoverinaction) |  |
| `Callable` | [`HoverOutAction`](#hoveroutaction) |  |
| `Callable` | [`ToggledAction`](#toggledaction) |  |
| `Callable` | [`HoldAction`](#holdaction) |  |
| `Callable` | [`SwipeAction`](#swipeaction) |  |
| `Callable` | [`LogAction`](#logaction) |  |
| `Callable` | [`WarningAction`](#warningaction) |  |
| `Callable` | [`ErrorAction`](#erroraction) |  |
| `int` | [`BackgroundType`](#backgroundtype) |  |
| `int` | [`LabelType`](#labeltype) |  |
| `bool` | [`Disabled`](#disabled) |  |
| `Color` | [`DisabledModulate`](#disabledmodulate) | `Color(1, 1, 1, 0.45)` |
| `int` | [`InvertModes`](#invertmodes) | `0` |
| `float` | [`HoverScale`](#hoverscale) |  |
| `float` | [`HoverLerpSpeed`](#hoverlerpspeed) | `25.0` |
| `Color` | [`SelectedColor`](#selectedcolor) | `Color(1, 1, 1, 0.3)` |
| `StringName` | [`ActivationAction`](#activationaction) | `&"ui_accept"` |
| `StringName` | [`OutputAction`](#outputaction) | `&""` |
| `Control` | [`BoundsSource`](#boundssource) |  |
| `Vector2` | [`HitSlop`](#hitslop) | `Vector2(0, 0)` |
| `int` | [`FollowMode`](#followmode) |  |
| `bool` | [`ClampToBounds`](#clamptobounds) | `true` |
| `bool` | [`EnableVirtualJoystick`](#enablevirtualjoystick) |  |
| `int` | [`ClampShape`](#clampshape) | `0` |
| `int` | [`JoystickRadiusPx`](#joystickradiuspx) | `0` |
| `Vector2` | [`JoystickRectSizePx`](#joystickrectsizepx) | `Vector2(0, 0)` |
| `float` | [`JoystickDeadzone`](#joystickdeadzone) | `0.1` |
| `bool` | [`JoystickSnapToInput`](#joysticksnaptoinput) | `true` |
| `bool` | [`JoystickHideWhenInactive`](#joystickhidewheninactive) | `false` |
| `bool` | [`JoystickResetOnRelease`](#joystickresetonrelease) | `true` |
| `bool` | [`EnableJoystickArea`](#enablejoystickarea) | `false` |
| `bool` | [`JoystickAreaPersistent`](#joystickareapersistent) | `false` |
| `Color` | [`JoystickAreaColor`](#joystickareacolor) | `Color(1, 1, 1, 0.25)` |
| `int` | [`JoystickAreaThickness`](#joystickareathickness) | `2` |
| `bool` | [`JoystickAreaUseRectForClamp`](#joystickareauserectforclamp) | `false` |
| `NodePath` | [`JoystickAreaExternalPath`](#joystickareaexternalpath) |  |
| `bool` | [`EnableDefaultThumb`](#enabledefaultthumb) |  |
| `float` | [`DefaultThumbSizeRatio`](#defaultthumbsizeratio) | `0.6` |
| `Color` | [`DefaultThumbColor`](#defaultthumbcolor) | `Color(1, 1, 1, 0.9)` |
| `Texture2D` | [`IconTexture`](#icontexture) |  |
| `int` | [`IconExpandMode`](#iconexpandmode) | `3` |
| `int` | [`IconStretchMode`](#iconstretchmode) | `0` |
| `bool` | [`IconFlipH`](#iconfliph) | `false` |
| `bool` | [`IconFlipV`](#iconflipv) | `false` |
| `Color` | [`IconModulate`](#iconmodulate) | `Color(1, 1, 1, 1)` |
| `float` | [`HoldDuration`](#holdduration) |  |
| `Color` | [`HoldFillColor`](#holdfillcolor) | `Color(1, 1, 1, 0.25)` |
| `int` | [`HoldFillDirection`](#holdfilldirection) | `0` |
| `float` | [`SwipeThreshold`](#swipethreshold) | `20.0` |
| `int` | [`TouchSwipeInit`](#touchswipeinit) | `0` |
| `int` | [`TouchSwipeExit`](#touchswipeexit) | `0` |
| `int` | [`MouseSwipeInit`](#mouseswipeinit) | `1` |
| `int` | [`MouseSwipeExit`](#mouseswipeexit) | `1` |
| `int` | [`InteractionMode`](#interactionmode) | `0` |
| `int` | [`CooldownTrigger`](#cooldowntrigger) |  |
| `float` | [`CooldownStartDelay`](#cooldownstartdelay) | `0.0` |
| `float` | [`CooldownDuration`](#cooldownduration) | `1.0` |
| `bool` | [`CooldownStartFilled`](#cooldownstartfilled) | `false` |
| `Color` | [`CooldownColor`](#cooldowncolor) | `Color(0, 0, 0, 0.4)` |
| `int` | [`CooldownFillDirection`](#cooldownfilldirection) | `0` |
| `bool` | [`InvertOnCooldown`](#invertoncooldown) | `false` |
| `float` | [`CooldownInvertDuration`](#cooldowninvertduration) | `0.0` |
| `bool` | [`SuspendHoverScaleDuringCooldown`](#suspendhoverscaleduringcooldown) | `false` |
| `bool` | [`AllowHoldDuringCooldown`](#allowholdduringcooldown) | `false` |
| `bool` | [`HideCooldownDuringHoldBuildUp`](#hidecooldownduringholdbuildup) | `true` |
| `String` | [`Text`](#text) |  |
| `bool` | [`LabelUppercase`](#labeluppercase) | `false` |
| `bool` | [`LabelClipText`](#labelcliptext) | `false` |
| `int` | [`LabelTextOverrun`](#labeltextoverrun) | `0` |
| `Font` | [`LabelFont`](#labelfont) |  |
| `Color` | [`LabelTextColor`](#labeltextcolor) | `Color(1, 1, 1, 1)` |
| `Color` | [`TextModulate`](#textmodulate) | `Color(1, 1, 1, 1)` |
| `int` | [`LabelHorizontalAlignment`](#labelhorizontalalignment) | `1` |
| `int` | [`LabelVerticalAlignment`](#labelverticalalignment) | `1` |
| `int` | [`LabelAutowrap`](#labelautowrap) |  |
| `bool` | [`RichLabelUseBBCode`](#richlabelusebbcode) | `true` |
| `bool` | [`RichTextFitContent`](#richtextfitcontent) | `false` |
| `bool` | [`RichTextScrollActive`](#richtextscrollactive) | `false` |
| `bool` | [`RichTextScrollFollowing`](#richtextscrollfollowing) | `false` |
| `bool` | [`RichTextSelectionEnabled`](#richtextselectionenabled) | `false` |
| `bool` | [`RichTextContextMenuEnabled`](#richtextcontextmenuenabled) | `true` |
| `Vector2` | [`TextFitPadding`](#textfitpadding) | `Vector2(12, 4)` |
| `int` | [`MinFontSize`](#minfontsize) | `6` |
| `int` | [`MaxFontSize`](#maxfontsize) | `100` |
| `int` | [`FixedFontSize`](#fixedfontsize) | `0` |
| `bool` | [`EnableTextAutoSize`](#enabletextautosize) | `true` |
| `Vector2` | [`LabelPadding`](#labelpadding) | `Vector2(0, 0)` |
| `float` | [`LabelAdditionalPaddingLeft`](#labeladditionalpaddingleft) | `0.0` |
| `float` | [`LabelAdditionalPaddingTop`](#labeladditionalpaddingtop) | `0.0` |
| `float` | [`LabelAdditionalPaddingRight`](#labeladditionalpaddingright) | `0.0` |
| `float` | [`LabelAdditionalPaddingBottom`](#labeladditionalpaddingbottom) | `0.0` |
| `String` | [`TextToType`](#texttotype) | `""` |
| `bool` | [`SuspendHoverDuringTypewriter`](#suspendhoverduringtypewriter) | `true` |
| `bool` | [`DelayEffectTagsDuringTypewriter`](#delayeffecttagsduringtypewriter) | `true` |
| `bool` | [`FinishTypewriterOnPress`](#finishtypewriteronpress) | `true` |
| `String` | [`PanelThemeVariation`](#panelthemevariation) | `""` |
| `StyleBox` | [`PanelStyleBox`](#panelstylebox) |  |
| `StyleBox` | [`PanelHoverStyleBox`](#panelhoverstylebox) |  |
| `StyleBox` | [`PanelPressedStyleBox`](#panelpressedstylebox) |  |
| `StyleBox` | [`PanelDisabledStyleBox`](#paneldisabledstylebox) |  |
| `StyleBox` | [`PanelFocusStyleBox`](#panelfocusstylebox) |  |
| `Color` | [`PanelModulate`](#panelmodulate) | `Color(1, 1, 1, 1)` |
| `Texture2D` | [`texture`](#texture) |  |
| `int` | [`expand_mode`](#expand_mode) |  |
| `int` | [`stretch_mode`](#stretch_mode) |  |
| `bool` | [`flip_h`](#flip_h) |  |
| `bool` | [`flip_v`](#flip_v) |  |
| `Color` | [`BackgroundModulate`](#backgroundmodulate) | `Color(1, 1, 1, 1)` |
| `bool` | [`ManagedDrawOnTop`](#manageddrawontop) |  |
| `bool` | [`Selected`](#selected) |  |
| `bool` | [`IsToggled`](#istoggled) |  |
| `bool` | [`IsPressed`](#ispressed) |  |
| `bool` | [`IsHovering`](#ishovering) |  |
| `bool` | [`IsHolding`](#isholding) |  |
| `int` | [`DebuggerLog`](#debuggerlog) | `0` |
| [OmniLabelAccessor](./OmniLabelAccessor.md) | [`label`](#label) |  |
| [OmniIconAccessor](./OmniIconAccessor.md) | [`icon`](#icon) |  |
| [OmniBackgroundAccessor](./OmniBackgroundAccessor.md) | [`background`](#background) |  |
| [OmniPanelAccessor](./OmniPanelAccessor.md) | [`panel`](#panel) |  |
| [OmniOverlayAccessor](./OmniOverlayAccessor.md) | [`overlay`](#overlay) |  |
| [OmniCooldownAccessor](./OmniCooldownAccessor.md) | [`cooldown`](#cooldown) |  |
| [OmniChargeUpAccessor](./OmniChargeUpAccessor.md) | [`charge_up`](#charge_up) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`queue_refresh`](#queue_refresh)(children: bool = false, panel_styling: bool = false, fit_label: bool = true) |
| `void` | [`start_typewriter`](#start_typewriter)(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) |
| `void` | [`start_typewriter_from_text_to_type`](#start_typewriter_from_text_to_type)(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) |
| `void` | [`skip_typewriter`](#skip_typewriter)() |
| `void` | [`stop_typewriter`](#stop_typewriter)() |
| `void` | [`start_virtual_joystick_at`](#start_virtual_joystick_at)(global_point: Vector2) |
| `void` | [`update_virtual_joystick`](#update_virtual_joystick)(global_point: Vector2) |
| `void` | [`stop_virtual_joystick`](#stop_virtual_joystick)() |
| `void` | [`start_cooldown`](#start_cooldown)() |
| `void` | [`print_log`](#print_log)(message: String) |
| `void` | [`print_warn`](#print_warn)(message: String) |
| `void` | [`print_err`](#print_err)(message: String) |

## Signals

### pressed()

Emitted when the button is pressed (mouse, touch, or `ActivationAction` while focused). Needs the Press action on (`EnablePressedActions`).

### released()

Emitted when the button is released. Needs the Release action on (`EnableReleasedActions`).

### hover_in()

Emitted when the pointer enters the button. Needs the Hover action on.

### hover_out()

Emitted when the pointer leaves the button. Needs the Hover action on.

### toggled(pressed: bool)

Emitted when the button toggles on or off (`InteractionMode`). `pressed` is the new state.

### typewriter_completed()

Emitted when typewriter text finishes, including when `skip_typewriter()` or `stop_typewriter()` ends it.

### typewriter_char_revealed(index: int, character: String)

Emitted for each character the typewriter reveals (not for characters skipped past).

### hold()

Emitted once when the hold build-up completes (`HoldDuration` greater than zero). Needs the Hold action on.

### swipe(direction: Vector2)

Emitted during a swipe with the normalized swipe `direction`. Needs the Swipe action on.

### swipe_ended()

Emitted when a swipe ends.

### log(message: String)

Emitted by `print_log()` when the Log action is on.

### warning(message: String)

Emitted by `print_warn()` when the Warning action is on.

### error(message: String)

Emitted by `print_err()` when the Error action is on.

### joystick_started()

Emitted when the virtual joystick starts being dragged.

### joystick_axis(axis: Vector2)

Emitted while the virtual joystick moves. `axis` goes from -1 to 1 on each axis, after the deadzone.

### joystick_ended()

Emitted when the virtual joystick is released.

## Constants and enums

- enum **CooldownDirection**: `BottomToTop = 0`
- enum **CooldownDirection**: `TopToBottom = 1`
- enum **CooldownDirection**: `LeftToRight = 2`
- enum **CooldownDirection**: `RightToLeft = 3`
- enum **BackgroundMode**: `None = 0`
- enum **BackgroundMode**: `UsePanel = 1`
- enum **BackgroundMode**: `UseTexture = 2`
- enum **FollowModeEnum**: `None = 0`
- enum **FollowModeEnum**: `FollowBoth = 3`
- enum **FollowModeEnum**: `VirtualJoystick = 4`
- enum **JoystickClampShape**: `Circle = 0`
- enum **JoystickClampShape**: `Rectangle = 1`
- enum **SwipeInitMode**: `OnHoverIn = 0`
- enum **SwipeInitMode**: `OnPressed = 1`
- enum **SwipeExitMode**: `OnHoverOut = 0`
- enum **SwipeExitMode**: `OnReleased = 1`
- enum **CooldownTriggerEnum**: `None = 0`
- enum **CooldownTriggerEnum**: `OnPress = 1`
- enum **CooldownTriggerEnum**: `OnRelease = 2`
- enum **CooldownTriggerEnum**: `OnPressAndRelease = 3`
- enum **DebuggerLogMode**: `OFF = 0`
- enum **DebuggerLogMode**: `BASIC = 1`
- enum **LabelKind**: `None = 2`
- enum **LabelKind**: `Label = 0`
- enum **LabelKind**: `RichTextLabel = 1`
- enum **InteractionModeEnum**: `Momentary = 0`
- enum **InteractionModeEnum**: `ToggleOnPress = 1`
- enum **InteractionModeEnum**: `ToggleOnRelease = 2`
- enum **PointerGestureSource**: `None = 0`
- enum **PointerGestureSource**: `Mouse = 1`
- enum **PointerGestureSource**: `NativeTouch = 2`
- `INVERT_PRESS = 1`
- `INVERT_TOGGLE = 2`
- `INVERT_HOVER = 4`
- `INVERT_HOLD = 8`
- `ACT_PRESSED = 1`
- `ACT_RELEASED = 2`
- `ACT_HOVER = 4`
- `ACT_TOGGLE = 8`
- `ACT_HOLD = 16`
- `ACT_SWIPE = 32`
- `ACT_LOG = 64`
- `ACT_WARNING = 128`
- `ACT_ERROR = 256`
- `TYPEWRITER_EFFECT_TAGS = {"fade": true, "pulse": true, "rainbow": true, "shake": true, "tornado": true, "wave": true}`

## Property descriptions

### EnablePressedActions

`bool` `EnablePressedActions`

Emits the Pressed signal and runs its connected action when this button is pressed.

### EnableReleasedActions

`bool` `EnableReleasedActions`

Emits the Released signal and runs its connected action when this button is released.

### EnableHoverActions

`bool` `EnableHoverActions`

Emits HoverIn and HoverOut and runs their connected actions as the pointer enters or leaves.

### EnableToggleActions

`bool` `EnableToggleActions`

Emits Toggled and runs its connected action when the button changes toggle state.

### EnableHoldActions

`bool` `EnableHoldActions`

Emits Hold and runs its connected action when the configured hold duration completes.

### EnableSwipeActions

`bool` `EnableSwipeActions`

Emits Swipe and SwipeEnded and runs their connected actions for recognized swipe gestures.

### EnableLogActions

`bool` `EnableLogActions`

Enables the Log signal and connected action for messages sent through this button.

### EnableWarningActions

`bool` `EnableWarningActions`

Enables the Warning signal and connected action for warnings sent through this button.

### EnableErrorActions

`bool` `EnableErrorActions`

Enables the Error signal and connected action for errors sent through this button.

### PressedAction

`Callable` `PressedAction`

Runs after `pressed` is emitted. When set, it replaces the built-in `_run_built_in_pressed` hook.

### ReleasedAction

`Callable` `ReleasedAction`

Runs after `released`. When set, it replaces the built-in released hook.

### HoverInAction

`Callable` `HoverInAction`

Runs after `hover_in`. When set, it replaces the built-in hover-in hook.

### HoverOutAction

`Callable` `HoverOutAction`

Runs after `hover_out`. When set, it replaces the built-in hover-out hook.

### ToggledAction

`Callable` `ToggledAction`

Runs after `toggled`. When set, it replaces the built-in toggled hook.

### HoldAction

`Callable` `HoldAction`

Runs after `hold`. When set, it replaces the built-in hold hook.

### SwipeAction

`Callable` `SwipeAction`

Runs after `swipe`. When set, it replaces the built-in swipe hook.

### LogAction

`Callable` `LogAction`

Runs after `log` in `print_log()`. When set, it replaces the default `@GlobalScope.print()`.

### WarningAction

`Callable` `WarningAction`

Runs after `warning` in `print_warn()`. When set, it replaces the default `@GlobalScope.push_warning()`.

### ErrorAction

`Callable` `ErrorAction`

Runs after `error` in `print_err()`. When set, it replaces the default `@GlobalScope.push_error()`.

### BackgroundType

`int` `BackgroundType`

None draws no generated background; UsePanel draws a styled Panel; UseTexture draws a TextureRect background.

### LabelType

`int` `LabelType`

None creates no text node; Label uses plain text; RichTextLabel supports BBCode and rich text behavior.

### Disabled

`bool` `Disabled`

Blocks pointer interaction and applies the disabled visual state.

### DisabledModulate

`Color` `DisabledModulate` = `Color(1, 1, 1, 0.45)`

Multiplies the text and icon colors while `Disabled` is on, so a disabled button reads as unavailable. White leaves them unchanged.

### InvertModes

`int` `InvertModes` = `0`

Selects the states that invert the button colors: Press, Toggle, Hover, and/or Hold.

### HoverScale

`float` `HoverScale`

Scale of the button while hovered: 1.2 means 120% of normal size. Zero disables hover scaling. The scale is capped so the button stays inside the viewport.

### HoverLerpSpeed

`float` `HoverLerpSpeed` = `25.0`

Speed at which the hover scale transitions between normal and hovered size.

### SelectedColor

`Color` `SelectedColor` = `Color(1, 1, 1, 0.3)`

Tint used by the selected-state overlay.

### ActivationAction

`StringName` `ActivationAction` = `&"ui_accept"`

InputMap action that activates this button while it has keyboard focus. Set to empty to disable focused input.

### OutputAction

`StringName` `OutputAction` = `&""`

InputMap action held down while this button is pressed, like TouchScreenButton's action: an on-screen "jump" button then works with `Input.is_action_pressed("jump")` and `_input()`. Empty does nothing.

### BoundsSource

`Control` `BoundsSource`

Optional Control whose global rectangle replaces this button's own rectangle for hit-testing (whether a release counts as inside). Drag and virtual joystick movement are also clamped to it.

### HitSlop

`Vector2` `HitSlop` = `Vector2(0, 0)`

Expands the code-level hit-test rectangle in pixels: x controls left/right and y controls top/bottom. Godot still routes pointer events by this Control's rectangle.

### FollowMode

`int` `FollowMode`

None stays in place; FollowBoth moves with the pointer; VirtualJoystick emits joystick axes while the pointer moves within its clamp area. The settings for the chosen mode appear below it.

### ClampToBounds

`bool` `ClampToBounds` = `true`

In FollowBoth mode, keeps the moving button inside its follow clamp rectangle; disabling it allows movement beyond the rectangle.

### EnableVirtualJoystick

`bool` `EnableVirtualJoystick`

Shorthand for FollowMode == VirtualJoystick, kept for scripts and for scenes saved before FollowMode became the single switch. Not shown in the Inspector and not saved.

### ClampShape

`int` `ClampShape` = `0`

Circle constrains movement to a radius; Rectangle constrains movement to the configured width and height.

### JoystickRadiusPx

`int` `JoystickRadiusPx` = `0`

Radius in pixels for circular joystick movement. Zero uses the control size to determine the radius.

### JoystickRectSizePx

`Vector2` `JoystickRectSizePx` = `Vector2(0, 0)`

Width and height in pixels of the rectangular joystick movement area.

### JoystickDeadzone

`float` `JoystickDeadzone` = `0.1`

Normalized center radius where joystick input is treated as zero.

### JoystickSnapToInput

`bool` `JoystickSnapToInput` = `true`

Moves the virtual joystick control with the pointer while the gesture is active.

### JoystickHideWhenInactive

`bool` `JoystickHideWhenInactive` = `false`

Hides the control while the virtual joystick is not being used.

### JoystickResetOnRelease

`bool` `JoystickResetOnRelease` = `true`

Returns the joystick thumb and axis to neutral when the pointer is released.

### EnableJoystickArea

`bool` `EnableJoystickArea` = `false`

Draws a visual guide for the joystick movement area.

### JoystickAreaPersistent

`bool` `JoystickAreaPersistent` = `false`

Keeps the joystick area guide visible when the joystick is inactive.

### JoystickAreaColor

`Color` `JoystickAreaColor` = `Color(1, 1, 1, 0.25)`

Color of the joystick area guide.

### JoystickAreaThickness

`int` `JoystickAreaThickness` = `2`

Line thickness in pixels for the joystick area guide.

### JoystickAreaUseRectForClamp

`bool` `JoystickAreaUseRectForClamp` = `false`

Uses the configured rectangular joystick area when clamping movement.

### JoystickAreaExternalPath

`NodePath` `JoystickAreaExternalPath`

Optional path to an external Control used to draw the joystick area guide.

### EnableDefaultThumb

`bool` `EnableDefaultThumb`

Creates the built-in joystick thumb when no custom thumb is supplied.

### DefaultThumbSizeRatio

`float` `DefaultThumbSizeRatio` = `0.6`

Default thumb size relative to the joystick movement area.

### DefaultThumbColor

`Color` `DefaultThumbColor` = `Color(1, 1, 1, 0.9)`

Color of the built-in joystick thumb.

### IconTexture

`Texture2D` `IconTexture`

Texture displayed in the icon layer, behind the button text.

### IconExpandMode

`int` `IconExpandMode` = `3`

Keep Size uses the texture's native dimensions; Ignore Size ignores its minimum size; Fit Width/Height constrain that dimension, with Proportional variants preserving aspect ratio.

### IconStretchMode

`int` `IconStretchMode` = `0`

Chooses scaling, tiling, native-size placement, centering, or aspect-preserving fit/cover behavior for the icon.

### IconFlipH

`bool` `IconFlipH` = `false`

Mirrors the icon texture horizontally.

### IconFlipV

`bool` `IconFlipV` = `false`

Mirrors the icon texture vertically.

### IconModulate

`Color` `IconModulate` = `Color(1, 1, 1, 1)`

Multiplies the icon texture colors by this color.

### HoldDuration

`float` `HoldDuration`

Time the button must remain pressed before the Hold action fires. Zero disables hold build-up.

### HoldFillColor

`Color` `HoldFillColor` = `Color(1, 1, 1, 0.25)`

Color of the progress fill shown while the button is building up a hold.

### HoldFillDirection

`int` `HoldFillDirection` = `0`

Direction the hold progress fill advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.

### SwipeThreshold

`float` `SwipeThreshold` = `20.0`

Minimum pointer travel in pixels required to recognize a swipe.

### TouchSwipeInit

`int` `TouchSwipeInit` = `0`

OnHoverIn begins touch swipe tracking on pointer entry; OnPressed begins tracking on touch press.

### TouchSwipeExit

`int` `TouchSwipeExit` = `0`

OnHoverOut ends touch swipe tracking when leaving the bounds; OnReleased ends it when the touch is released.

### MouseSwipeInit

`int` `MouseSwipeInit` = `1`

OnHoverIn begins mouse swipe tracking on pointer entry; OnPressed begins tracking on mouse press.

### MouseSwipeExit

`int` `MouseSwipeExit` = `1`

OnHoverOut ends mouse swipe tracking when leaving the bounds; OnReleased ends it when the mouse button is released.

### InteractionMode

`int` `InteractionMode` = `0`

Momentary is pressed only while held; Toggle On Press switches state on press; Toggle On Release switches state on release.

### CooldownTrigger

`int` `CooldownTrigger`

None disables cooldown; OnPress starts it on press; OnRelease starts it on release; OnPressAndRelease starts it on both events.

### CooldownStartDelay

`float` `CooldownStartDelay` = `0.0`

Wait time after the selected trigger before the cooldown fill begins.

### CooldownDuration

`float` `CooldownDuration` = `1.0`

Time the cooldown remains active after its start delay.

### CooldownStartFilled

`bool` `CooldownStartFilled` = `false`

Shows the cooldown fill as full at the start and drains it, instead of filling from empty.

### CooldownColor

`Color` `CooldownColor` = `Color(0, 0, 0, 0.4)`

Color of the cooldown overlay.

### CooldownFillDirection

`int` `CooldownFillDirection` = `0`

Direction the cooldown overlay advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.

### InvertOnCooldown

`bool` `InvertOnCooldown` = `false`

Inverts the button colors while cooldown is active.

### CooldownInvertDuration

`float` `CooldownInvertDuration` = `0.0`

Duration of the cooldown color-inversion transition. Zero applies it immediately.

### SuspendHoverScaleDuringCooldown

`bool` `SuspendHoverScaleDuringCooldown` = `false`

Temporarily returns the button to normal scale while cooldown is active.

### AllowHoldDuringCooldown

`bool` `AllowHoldDuringCooldown` = `false`

Allows hold build-up while cooldown is active.

### HideCooldownDuringHoldBuildUp

`bool` `HideCooldownDuringHoldBuildUp` = `true`

Hides the cooldown overlay while hold build-up is visible.

### Text

`String` `Text`

Text displayed on the button. Setting non-empty text automatically selects the plain Label if LabelType is None.

### LabelUppercase

`bool` `LabelUppercase` = `false`

Displays plain Label text in uppercase without changing the Text property.

### LabelClipText

`bool` `LabelClipText` = `false`

Clips plain Label text at the label boundary.

### LabelTextOverrun

`int` `LabelTextOverrun` = `0`

None keeps text unchanged; Trim Character/Word removes overflow; Ellipsis adds an ellipsis; Trim Word with Ellipsis trims at a word boundary and adds an ellipsis.

### LabelFont

`Font` `LabelFont`

Font resource used to draw button text.

### LabelTextColor

`Color` `LabelTextColor` = `Color(1, 1, 1, 1)`

Base color used to draw the button text.

### TextModulate

`Color` `TextModulate` = `Color(1, 1, 1, 1)`

Additional color modulation applied to the text.

### LabelHorizontalAlignment

`int` `LabelHorizontalAlignment` = `1`

Horizontal alignment of the text inside its label.

### LabelVerticalAlignment

`int` `LabelVerticalAlignment` = `1`

Vertical alignment of the text inside its label.

### LabelAutowrap

`int` `LabelAutowrap`

Off never wraps; Arbitary wraps anywhere; Word wraps at word boundaries; Smart favors word boundaries but can break long words.

### RichLabelUseBBCode

`bool` `RichLabelUseBBCode` = `true`

Parses BBCode tags in RichTextLabel text when enabled; otherwise tags are shown literally.

### RichTextFitContent

`bool` `RichTextFitContent` = `false`

Makes the RichTextLabel size to its content instead of clipping to its assigned rectangle.

### RichTextScrollActive

`bool` `RichTextScrollActive` = `false`

Allows the RichTextLabel to be scrolled.

### RichTextScrollFollowing

`bool` `RichTextScrollFollowing` = `false`

Automatically scrolls to the newest content as text is added.

### RichTextSelectionEnabled

`bool` `RichTextSelectionEnabled` = `false`

Allows users to select text in the RichTextLabel.

### RichTextContextMenuEnabled

`bool` `RichTextContextMenuEnabled` = `true`

Shows the RichTextLabel context menu for text actions.

### TextFitPadding

`Vector2` `TextFitPadding` = `Vector2(12, 4)`

Extra horizontal and vertical space reserved when calculating an autosized font.

### MinFontSize

`int` `MinFontSize` = `6`

Smallest font size considered by text autosizing. A wider MinFontSize-to-MaxFontSize range increases fit-search work.

### MaxFontSize

`int` `MaxFontSize` = `100`

Largest font size considered by text autosizing.

### FixedFontSize

`int` `FixedFontSize` = `0`

Forces this font size when positive; zero lets autosizing choose the size.

### EnableTextAutoSize

`bool` `EnableTextAutoSize` = `true`

Automatically fits text to the available label area.

### LabelPadding

`Vector2` `LabelPadding` = `Vector2(0, 0)`

Uniform internal padding applied around the label text.

### LabelAdditionalPaddingLeft

`float` `LabelAdditionalPaddingLeft` = `0.0`

Additional left-side space excluded from the label text area.

### LabelAdditionalPaddingTop

`float` `LabelAdditionalPaddingTop` = `0.0`

Additional top-side space excluded from the label text area.

### LabelAdditionalPaddingRight

`float` `LabelAdditionalPaddingRight` = `0.0`

Additional right-side space excluded from the label text area.

### LabelAdditionalPaddingBottom

`float` `LabelAdditionalPaddingBottom` = `0.0`

Additional bottom-side space excluded from the label text area.

### TextToType

`String` `TextToType` = `""`

Text used by StartTypewriter when no text argument is provided.

### SuspendHoverDuringTypewriter

`bool` `SuspendHoverDuringTypewriter` = `true`

Temporarily returns the button to normal scale while typewriter text is active.

### DelayEffectTagsDuringTypewriter

`bool` `DelayEffectTagsDuringTypewriter` = `true`

Delays supported RichTextLabel effect tags until their text is revealed.

### FinishTypewriterOnPress

`bool` `FinishTypewriterOnPress` = `true`

Finishes the active typewriter effect when the button is pressed.

### PanelThemeVariation

`String` `PanelThemeVariation` = `""`

Theme variation applied to the generated Panel background.

### PanelStyleBox

`StyleBox` `PanelStyleBox`

Default Panel style. State-specific styles use this when they are not assigned.

### PanelHoverStyleBox

`StyleBox` `PanelHoverStyleBox`

Panel style used while the pointer hovers over the button; falls back to PanelStyleBox.

### PanelPressedStyleBox

`StyleBox` `PanelPressedStyleBox`

Panel style used while the button is pressed; falls back to PanelStyleBox.

### PanelDisabledStyleBox

`StyleBox` `PanelDisabledStyleBox`

Panel style used while Disabled is true; falls back to PanelStyleBox.

### PanelFocusStyleBox

`StyleBox` `PanelFocusStyleBox`

Panel style used while the button has keyboard focus; falls back to PanelStyleBox.

### PanelModulate

`Color` `PanelModulate` = `Color(1, 1, 1, 1)`

Color modulation applied to the generated Panel background.

### texture

`Texture2D` `texture`

Texture displayed by the TextureRect background when BackgroundType is UseTexture.

### expand_mode

`int` `expand_mode`

Controls how the background texture affects the TextureRect minimum size.

### stretch_mode

`int` `stretch_mode`

Controls how the background texture is fitted or drawn inside its rectangle.

### flip_h

`bool` `flip_h`

Mirrors the background texture horizontally.

### flip_v

`bool` `flip_v`

Mirrors the background texture vertically.

### BackgroundModulate

`Color` `BackgroundModulate` = `Color(1, 1, 1, 1)`

Color modulation applied to the TextureRect background.

### ManagedDrawOnTop

`bool` `ManagedDrawOnTop`

Draws OmniButton-generated visuals above other direct children when enabled; disable to draw user children on top.

### Selected

`bool` `Selected`

Sets the selected visual state programmatically.

### IsToggled

`bool` `IsToggled`

Gets or sets the current toggle state programmatically.

### IsPressed

`bool` `IsPressed`

Gets or sets the current pressed state programmatically.

### IsHovering

`bool` `IsHovering`

Gets or sets the current hover state programmatically.

### IsHolding

`bool` `IsHolding`

Gets or sets the current hold state programmatically.

### DebuggerLog

`int` `DebuggerLog` = `0`

Writes per-button diagnostic messages to the output: Off disables logging; Basic enables it.

### label

[OmniLabelAccessor](./OmniLabelAccessor.md) `label`

Shortcut to the text settings: `button.label.text`, `.color`, `.font`, `.max_font_size`, ... Each forwards to the matching Inspector setting.

### icon

[OmniIconAccessor](./OmniIconAccessor.md) `icon`

Shortcut to the icon settings: `button.icon.texture`, `.modulate`, ...

### background

[OmniBackgroundAccessor](./OmniBackgroundAccessor.md) `background`

Shortcut to the background texture settings.

### panel

[OmniPanelAccessor](./OmniPanelAccessor.md) `panel`

Shortcut to the panel style settings: `button.panel.style`, ...

### overlay

[OmniOverlayAccessor](./OmniOverlayAccessor.md) `overlay`

Shortcut to the selection overlay settings.

### cooldown

[OmniCooldownAccessor](./OmniCooldownAccessor.md) `cooldown`

Shortcut to the cooldown settings: `button.cooldown.duration`, ...

### charge_up

[OmniChargeUpAccessor](./OmniChargeUpAccessor.md) `charge_up`

Shortcut to the hold build-up settings: `button.charge_up.duration`, ...

## Method descriptions

### queue_refresh

`void` `queue_refresh(children: bool = false, panel_styling: bool = false, fit_label: bool = true)`

Schedules a refresh for the next frame: `children` rebuilds the generated visuals, `panel_styling` re-applies the panel styles, and `fit_label` refits the text. Call it after changing settings from code that don't refresh on their own (for example `FixedFontSize`).

### start_typewriter

`void` `start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false)`

Types `final_text` out at `cps` characters per second (whole words when `by_word` is on). `preserve_bbcode_tags` keeps BBCode formatting and switches to a `RichTextLabel`. The timing tags `[pause=s]`, `[speed=cps]` and `[/speed]` are handled here and never shown. Emits `typewriter_char_revealed` per character and `typewriter_completed` at the end.

### start_typewriter_from_text_to_type

`void` `start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false)`

Same as `start_typewriter()`, typing `TextToType` (or `Text` when that is empty).

### skip_typewriter

`void` `skip_typewriter()`

Shows the rest of the typewriter text at once and emits `typewriter_completed`.

### stop_typewriter

`void` `stop_typewriter()`

Stops the typewriter, keeping only the text revealed so far, and emits `typewriter_completed`.

### start_virtual_joystick_at

`void` `start_virtual_joystick_at(global_point: Vector2)`

Starts the virtual joystick at `global_point`, as if it had been touched there.

### update_virtual_joystick

`void` `update_virtual_joystick(global_point: Vector2)`

Moves the virtual joystick to `global_point`.

### stop_virtual_joystick

`void` `stop_virtual_joystick()`

Releases the virtual joystick.

### start_cooldown

`void` `start_cooldown()`

Starts the cooldown now, as if its `CooldownTrigger` had happened.

### print_log

`void` `print_log(message: String)`

Emits `log` and runs `LogAction`, or prints `message` when no action is set.

### print_warn

`void` `print_warn(message: String)`

Emits `warning` and runs `WarningAction`, or calls `@GlobalScope.push_warning()` when no action is set.

### print_err

`void` `print_err(message: String)`

Emits `error` and runs `ErrorAction`, or calls `@GlobalScope.push_error()` when no action is set.
