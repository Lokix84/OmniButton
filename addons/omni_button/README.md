# OmniButton (GDScript) — Full Reference

Universal, highly configurable Control for Godot 4 (GDScript) that unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. All features are editor-friendly (`@tool`) and driven by exported properties and signals.

Minimum Godot: 4.x

Contents
- Signals
- Exported Properties (by group)
- Code organization
- Debugger Log
- Accessors (ergonomic helpers)
- Behavior notes and examples
- Troubleshooting

## Signals
- Pressed — Emitted on press when EnablePressedActions is on.
- Released — Emitted on release when EnableReleasedActions is on.
- Toggled(bool pressed) — Emitted when InteractionMode toggles on/off.
- HoverIn, HoverOut — Emitted on pointer enter/exit when EnableHoverActions is on.
- Hold — Emitted once after HoldDuration build-up completes when EnableHoldActions is on.
- Swipe(Vector2 direction) — Emitted with a normalized direction during swipe when EnableSwipeActions is on.
- SwipeEnded() — Emitted when a swipe session ends.
- JoystickStarted, JoystickAxis(Vector2 axis), JoystickEnded — Virtual joystick lifecycle and axes.
- Log(string), Warning(string), Error(string) — Optional logging signals.
- TypewriterCompleted — Raised when typewriter text finishes (also fires when SkipTypewriter() is called).

Connect signals with the standard GDScript syntax, for example `button.pressed.connect(_on_pressed)`.

Each event runs in this order: the signal is emitted (connected handlers run once), then the matching Action Callable runs if one is set (`PressedAction`, `ReleasedAction`, `HoverInAction`, `HoverOutAction`, `ToggledAction`, `HoldAction`, `SwipeAction`), otherwise the overridable `_run_built_in_*` hook. `print_log`, `print_warn`, and `print_err` work the same way: emit `Log`/`Warning`/`Error`, then run `LogAction`/`WarningAction`/`ErrorAction`, or fall back to the default print, `push_warning`, or `push_error`.

## Code organization

`omni_button.gd` is the scene-facing Control. It owns every exported property, all runtime state, and the public API. The file is split into foldable `#region` blocks: constants, signals and enums; one Settings region per Inspector category, in Inspector order, with each setting's private backing variable directly above it; runtime state grouped by feature; scripting accessors; lifecycle; public API; overridable hooks; and internal methods.

The core modules below are stateless: they contain only static functions that take the button as their first argument, so a button allocates no helper objects for them. The button and other modules call these functions directly (for example `OmniButtonTiming.start_cooldown(button)`), rather than through wrapper methods on the button. A leading underscore marks a function that is used only inside its own file; functions without one are called from other files. The button keeps a method only when it is part of the public API, an engine callback, an overridable hook, or a `call_deferred` target, or when it adds a check, such as skipping work before `_ready`.
- `omni_button_text.gd` — creates and updates Label/RichTextLabel children, parses BBCode for helper behavior, and measures/fits text.
- `omni_button_typewriter.gd` — tokenizes and reveals text over time, and holds the reveal state. Only `_tw_active` stays on the button, because `_process` checks it every frame.
- `omni_button_state.gd` — owns selected/toggle/press/hover/hold state changes and press-session reset behavior.
- `omni_button_input.gd` — handles pointer/focused InputMap actions, active-touch matching, and hit testing.
- `omni_button_editor.gd` — editor-only: decides which Inspector properties are visible and detects property changes when the editor's undo/redo history changes.
- `omni_button_inspector.gd` — supplies custom Inspector editors, labels, and tooltips.
- `omni_button_visuals.gd` — manages the `_Managed` layer, creates and lays out the generated visuals, and applies per-state styling.
- `omni_button_draw_item.gd` — `OmniDrawItem`, one generated visual (panel, background, icon, selection overlay, cooldown fill, hold fill, or joystick thumb) drawn directly on a RenderingServer canvas item instead of a Control node. It redraws once per frame at most, and only when one of its properties or its StyleBox/Texture changes.
- `omni_button_signals.gd` — turns on the action checkboxes for signals that were connected before the button was ready.
- `omni_button_timing.gd` — schedules hold/cooldown behavior, updates their fill visuals, and owns hover-scale bounds, pivots, and animation.
- `omni_button_joystick.gd` — manages joystick clamping/movement, its display area, and the built-in thumb.

The joystick and typewriter helpers keep per-feature state, so they are objects, created only when their features are first used (through `_ensure_joystick()` and `_ensure_typewriter()`, which return the instance). Each button has three nodes: the button, its `_Managed` layer, and the Label or RichTextLabel when text is enabled.

## Exported Properties

Exported properties have Inspector hover descriptions explaining their purpose and, where applicable, the available modes and their effects. Property rows use a consistent 50/50 label/value split; dropdown values are shortened in the row when needed, while the popup retains the full option names.
The Inspector's `PROPERTY_LABELS` table contains a display-name entry for all 113 exported OmniButton properties. Properties without a custom value editor continue to use Godot's native Inspector control.

Feature settings appear only while their feature is on, so unused features don't crowd the Inspector. Hidden settings keep their values and are still saved; turning the feature back on shows them as you left them.

| Turn on | Shows |
|---|---|
| `HoverScale` > 0 | `HoverLerpSpeed` |
| `FollowMode` = FollowBoth or VirtualJoystick | `ClampToBounds` |
| `FollowMode` = VirtualJoystick | Virtual Joystick settings, plus the Area and Thumb switches |
| `EnableJoystickArea` / `EnableDefaultThumb` | Area / Thumb settings |
| `IconTexture` set | Icon expand, stretch, flips, and modulate |
| `HoldDuration` > 0 | Hold fill color and direction |
| Swipe action checkbox | Swipe threshold and init/exit modes |
| `CooldownTrigger` ≠ None | Cooldown settings (`CooldownInvertDuration` also needs `InvertOnCooldown`; the hover and hold options also need hover scaling or hold build-up) |
| `LabelType` / `BackgroundType` | The matching Text, Label, RichTextLabel, Extra, Panel, or TextureRect sections |

### Initial OmniButton section
- Actions — individual checkboxes labeled Press, Release, Hover, Toggle, Hold, Swipe, Log, Warning, and Error. Their script property names retain the `Enable...Actions` names. Connecting a matching signal handler automatically enables its checkbox once.
- BackgroundType — None | UsePanel | UseTexture. Selects which background child is active and which background Inspector section is shown.
- LabelType — None | Label | RichTextLabel. None hides the Text, Label, RichTextLabel, and Extra categories and creates no label; setting non-empty Text in code selects Label automatically.
- Disabled — Blocks input and visual reactions.
- Visual Effects — InvertModes, Hover → Scale and Lerp Speed, and SelectedColor. Scale is the size while hovered (1.2 = 120%); it defaults to 0, which turns hover scaling off.
- Input & Motion — ActivationAction, then Hit Area (BoundsSource, HitSlop), then Drag & virtual joystick, where `FollowMode` is the single switch for drag and joystick behavior.
- Actions is the first section in the built-in OmniButton Inspector category.

### Button
- IconTexture renders as a full-size layer behind the full-size text node.
- Icon properties use concise Inspector labels: Texture, Expand, Stretch, Flip H, Flip V, and Modulate. Expand and Stretch retain the named TextureRect choices.
- Hold Build-Up — Duration, Fill Color, Fill Direction. A duration greater than zero enables hold build-up; zero disables it.
- Swipe — Threshold, Touch Init/Exit, Mouse Init/Exit.
- Toggle Behavior — InteractionMode.
- Cooldown — Trigger (None disables cooldown; OnPress, OnRelease, or OnPressAndRelease enables it), Start Delay, Duration, Start Filled, Color, Fill Direction, and hold/hover behavior.

### Text
- Text content is followed by the plain-label options Uppercase, Clip, and Overrun in the base section.
- Typography labels are shortened to Font, Color, Modulate, Horizontal, Vertical, and Autowrap. These settings apply to the selected Label or RichTextLabel where supported.

### RichTextLabel
- Shown only when LabelType is RichTextLabel: BBCode, fit-content, scrolling, selection, and context-menu options. `RichLabelUseBBCode` must be on for markup to be interpreted.

### Extra
- OmniButton-specific text options shown when either text type is selected: autosizing and padding, plus typewriter properties and methods.
- EnableTextAutoSize, FixedFontSize, MinFontSize, MaxFontSize, TextFitPadding, and LabelPadding.
- Additional Padding subgroup: Left, Top, Right, and Bottom.
- Typewriter: TextToType, DelayEffectTagsDuringTypewriter, SuspendHoverDuringTypewriter, FinishTypewriterOnPress, and the Start/Skip/Stop methods.

### Panel
- PanelThemeVariation, PanelStyleBox, PanelHoverStyleBox, PanelPressedStyleBox, PanelDisabledStyleBox, PanelFocusStyleBox, PanelModulate.
- State-specific styles fall back to PanelStyleBox when unset.

### TextureRect
- Texture, ExpandMode, StretchMode, FlipH, FlipV, BackgroundModulate. The first five match the native TextureRect Inspector names.

### Input / Follow / Virtual Joystick
- Hit Area: BoundsSource, HitSlop. These apply to every button: they set the rectangle used to decide whether a release counts as inside. Drag and joystick movement are also clamped to `BoundsSource`.
- FollowMode — None | FollowBoth | VirtualJoystick. This is the one switch for drag and joystick behavior. `EnableVirtualJoystick` remains as script shorthand for `FollowMode == VirtualJoystick`; it is no longer shown in the Inspector or saved, and scenes saved with it still load as joysticks.
- ClampToBounds (FollowBoth and VirtualJoystick)
- ClampShape — Circle | Rectangle
- JoystickRadiusPx, JoystickRectSizePx, JoystickDeadzone, JoystickSnapToInput
- JoystickHideWhenInactive, JoystickResetOnRelease
- EnableJoystickArea, JoystickAreaPersistent/Color/Thickness, JoystickAreaUseRectForClamp
- EnableDefaultThumb, DefaultThumbSizeRatio, DefaultThumbColor

### Composition
- ManagedDrawOnTop controls whether OmniButton's internal `_Managed` layer is drawn above or below the control's other direct children. Keep decorative/user-added children as siblings of `_Managed`; set this false to draw those children over OmniButton's generated visuals.

### Debug
- State subgroup: Selected, IsToggled, IsPressed, IsHovering, and IsHolding expose live state and are mainly useful for debugging or programmatic control.
- Logging subgroup: DebuggerLog — `Off` (default) or `Basic`. When set to `Basic`, OmniButton prints a detailed per-button trace to the Godot output console covering autosize decisions, hover/toggle transitions, swipe and joystick events, cooldown/hold/typewriter lifecycles, etc. Use this to diagnose a single button without spamming the whole UI.

### Typewriter
- TextToType, DelayEffectTagsDuringTypewriter, SuspendHoverDuringTypewriter, FinishTypewriterOnPress
- StartTypewriter(cps, byWord, preserveBBCodeTags), SkipTypewriter(), StopTypewriter(). Setting `preserveBBCodeTags` to true selects RichTextLabel when needed; set `RichLabelUseBBCode` to true to render markup.

## Accessors
- `label`, `icon`, `background`, `panel`, `overlay`, `cooldown`, and `charge_up` group related settings under short names. Each accessor and each of its properties is typed, so autocomplete and type checking work through them (`var d := button.cooldown.duration` is a `float`). An accessor is created the first time a script uses it.
- Examples:
  ```gdscript
  button.label.text = "Hello"
  button.icon.tex = load("res://icon.png")
  button.background.mode = Omni_Button.BackgroundMode.UseTexture
  button.panel.theme_variation = "warning"
  button.cooldown.trigger = Omni_Button.CooldownTriggerEnum.OnPress
  button.charge_up.duration = 1.0
  ```

## Behavior notes
- **Actions auto-enable once:** When a handler is connected to a signal before the button is ready (in the editor, or in code before `add_child`), the matching action checkbox turns on. If you disable it later, it remains off. For handlers connected later in code, turn the checkbox on yourself.
- **Per-button debugger:** Flip `DebuggerLog` to `Basic` for any instance to print a trace of autosize decisions, pressed/hover/toggle transitions, swipe + joystick events, hold/cooldown/typewriter lifecycle, and signal emissions. This is invaluable for diagnosing a single button without spamming other buttons.
- **Text autosizing parity:** The autosizer now uses Godot’s TextParagraph pipeline and re-runs whenever wrap/padding/text changes. Cached font sizes are invalidated automatically and a secondary search “grows” the font back up when more room becomes available. If text still overflows, enable the debugger log to inspect measurements vs available space.
- **Hold build-up:** When `HoldDuration` is greater than zero, OmniButton draws a hold fill and animates it according to `HoldFillDirection`. The `Hold` signal fires once the timer reaches `HoldDuration`.
- **Cooldown:** `CooldownTrigger = None` disables cooldown. Choose OnPress, OnRelease, or OnPressAndRelease to enable it; no separate enable switch is needed.
- **Swipe handling:** Swipes respect per-device init/exit settings, the Swipe action checkbox, thresholds, and `HitSlop`. Runtime logs show whether the action is disabled or the pointer left bounds.
- **Follow / Virtual joystick:** `FollowMode` controls whether the button drags, stays put, or becomes a joystick. Joystick sessions clamp to circular/rectangular regions, emit axis values/started/ended signals, and optionally show a ring (`EnableJoystickArea`). The debugger logs start/stop events and clamp info.
- **Cooldowns:** Any triggerable cooldown automatically clears pressed visuals, can optionally suspend hover scale, and emits debugger logs when starting or finishing. You can hide the overlay during hold build-up for “charge + cooldown” combos.
- **Typewriter text:** `StartTypewriter()` respects BBCode, word mode, and CPS, and can defer effect tags. Skip/Stop log when they emit `TypewriterCompleted` so you can tell if a script cancelled unexpectedly.
- **Runtime/editor parity:** In the editor, buttons refresh when an edit is made (the plugin listens for undo/redo history changes and scene switches) instead of polling every frame, and then run the same rebuild and autosize code as at runtime.
- **Processing / idle:** At runtime, `_process` calls `set_process(false)` when nothing needs per-frame work (no pending refresh, refit frames, typewriter, cooldown delay or active cooldown, hold build-up while pressed, and hover scaling is off). Hover scaling keeps processing on only while the scale is still animating. Idle buttons do no per-frame work, and they also receive `_unhandled_input` only while focused with an activation action or in the middle of a gesture.
- **Mouse + touch together:** With `ProjectSettings` → `input_devices/pointing/emulate_mouse_from_touch` on, one touch can produce both screen-touch and mouse-button events. `PointerGestureSource` records which input **first** started the press; the other is ignored until the session ends, avoiding double press/release.
- **Multi-touch drags:** `InputEventScreenDrag` is honored only when `index` matches `_active_touch_index` for a native touch press; mouse sessions accept all drags.
- **Cooldown vs. in-flight press:** While cooldown is active, new presses are blocked, but `_gui_input` still runs if `_is_pressed` so drag/release can finish.
- **Unhandled cleanup:** After off-control reset, `get_viewport().set_input_as_handled()` is called.
- **Hover target:** The hover scale is capped so the button stays inside the viewport. The cap is recalculated when the pointer enters and when the button is resized while hovered.
- **Typewriter + text:** Changing text or label type during a typewriter keeps the generated label synchronized with the currently revealed text; visual refreshes preserve the partial output.
- **Focused input actions:** `ActivationAction` names a Godot InputMap action (defaults to `ui_accept`). The focused button responds to mapped keyboard or gamepad press/release events; player remapping is handled through InputMap. When `FinishTypewriterOnPress` is on, the action first skips active typewriter text. Joystick/follow modes skip focused activation.

## Troubleshooting
- Swipe not firing: enable the Swipe action checkbox and move beyond SwipeThreshold.
- No hover zoom: set HoverScale to a value greater than zero (hover signals are independent).
- Draggable vs stationary: FollowMode = FollowBoth (drag), FollowMode = None (stationary).
