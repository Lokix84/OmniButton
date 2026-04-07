# OmniButton (C#) — Full Reference

Universal, highly configurable Control for Godot 4 (.NET) that unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. All features are editor-friendly and driven by exported properties and signals.

Minimum Godot: 4.x (.NET)

Contents
- Signals
- Exported Properties (by group)
- Debugger Log
- Accessors (ergonomic helpers)
- Behavior notes and examples
- Migration notes
- Troubleshooting

## Signals
- Pressed — Emitted on press when enabled by ActionMaskBits.
- Released — Emitted on release when enabled.
- Toggled(bool pressed) — Emitted when InteractionMode toggles on/off.
- HoverIn, HoverOut — Emitted on pointer enter/exit when enabled.
- Hold — Emitted once after HoldDuration build-up completes.
- Swipe(Vector2 direction) — Emitted with a normalized direction during swipe.
- SwipeEnded() — Emitted when a swipe session ends.
- JoystickStarted, JoystickAxis(Vector2 axis), JoystickEnded — Virtual joystick lifecycle and axes.
- Log(string), Warning(string), Error(string) — Optional logging signals.
- TypewriterCompleted — Raised when typewriter text finishes (also fires when SkipTypewriter() is called).

Tip: Use OmniButton.SignalName.* for refactor-safe signal names.

## Exported Properties

### Debugger Log
- DebuggerLog — `Off` (default) or `Basic`. When set to `Basic`, OmniButton prints a detailed per-button trace to the Godot output console covering autosize decisions, hover/toggle transitions, swipe and joystick events, cooldown/hold/typewriter lifecycles, etc. Use this to diagnose a single button without spamming the whole UI.

### State
- Disabled — Blocks input and visual reactions.
- Selected — Shows overlay when enabled.
- IsToggled — Current toggle state.
- IsPressed, IsHovering, IsHolding — Live state flags.

### Presets
- PresetSelection — Apply a preset (Basic, Toggle, Hold, Swipe, Draggable, VirtualJoystick). Any edits switch to Custom.

### Content Display
- BackgroundType — None | UsePanel | UseTexture
- IconTexture — Optional icon texture.
- LabelType — Label | RichTextLabel
- Text — Multiline content for either label type.
- RichLabelUseBBCode — Interpret Text as BBCode when LabelType = RichTextLabel.
- EnableSelectedOverlay — Show overlay when Selected or IsToggled.
- SelectedColor — Overlay color.

### Background Settings
- PanelThemeVariation, PanelStyleBox
- BackgroundTexture, BackgroundExpandMode, BackgroundStretchMode, BackgroundFlipH, BackgroundFlipV
- PanelModulate, BackgroundModulate

### Icon Settings
- IconExpandMode, IconStretchMode, IconFlipH, IconFlipV, IconModulate

### Label Settings
- LabelFont (override), LabelTextColor, TextModulate
- EnableTextAutoSize, FixedFontSize, MinFontSize, MaxFontSize, TextFitPadding
- LabelHorizontalAlignment, LabelVerticalAlignment, LabelAutowrap
- LabelPadding and per-side paddings (Left/Top/Right/Bottom)

### Invert Display
- InvertModes — Flags: Press | Toggle | Hover | Hold. Applies a simple invert shader to children while active.

### Hover Scaling
- EnableHoverScale — Enable hover zoom.
- HoverScale — Target scale (e.g., 1.15).
- HoverLerpSpeed — Interpolation speed.
- When enabled, hover scale lerps the managed panel, background `TextureRect` (if any), icon, labels, and overlay together (pivot-centered).

### Actions
- ActionMaskBits — Flags that determine which actions emit: Pressed, Released, Hover, Toggle, Hold, Swipe, Log, Warning, Error.
- ActionMask — Typed enum wrapper for ActionMaskBits.
- Optional callables invoked when assigned: PressedAction, ReleasedAction, HoverInAction, HoverOutAction, ToggledAction, HoldAction, SwipeAction, LogAction, WarningAction, ErrorAction.
- InteractionMode — Momentary | ToggleOnPress | ToggleOnRelease.

### Input bounds / drag & virtual joystick
- BoundsSource — optional control whose global rect is used for hit tests instead of the OmniButton’s own rect
- HitSlop — grow that rect on each side (pixels)
- FollowMode — None | FollowBoth | VirtualJoystick (while pressed: stationary, draggable, or joystick)
- ClampShape — Circle | Rectangle
- JoystickRadiusPx, JoystickRectSizePx, JoystickDeadzone, JoystickSnapToInput
- JoystickHideWhenInactive, JoystickResetOnRelease
- EnableJoystickArea, JoystickAreaPersistent/Color/Thickness, JoystickAreaUseRectForClamp
- EnableDefaultThumb, DefaultThumbSizeRatio, DefaultThumbColor

### Cooldown
- EnableCooldown, CooldownTrigger (OnPress | OnRelease | OnPressAndRelease)
- CooldownDuration, CooldownStartFilled, CooldownColor, CooldownFillDirection
- SuspendHoverScaleDuringCooldown, AllowHoldDuringCooldown, HideCooldownDuringHoldBuildUp

### Typewriter
- TextToType, DelayEffectTagsDuringTypewriter, SuspendHoverDuringTypewriter, FinishTypewriterOnPress
- StartTypewriter(cps, byWord, preserveBBCodeTags), SkipTypewriter(), StopTypewriter()

## Accessors (ergonomic helpers)
- LabelNode, IconNode, BackgroundNode, PanelNode, OverlayNode, CooldownNode, ChargeUpNode
- Examples:
  ```csharp
  btn.LabelNode.Text = "Hello";
  btn.IconNode.Texture = GD.Load<Texture2D>("res://icon.png");
  btn.BackgroundNode.Mode = OmniButton.BackgroundMode.UseTexture;
  btn.PanelNode.ThemeVariation = "warning";
  btn.CooldownNode.Enabled = true;
  btn.ChargeUpNode.Enabled = true;
  ```

## Behavior notes
- **Action bits auto-enable once:** When you first connect an external handler (editor or code) to a signal, the matching ActionMask bit turns on. If you disable it later, it remains off.
- **Per-button debugger:** Flip `DebuggerLog` to `Basic` for any instance to print a trace of autosize decisions, pressed/hover/toggle transitions, swipe + joystick events, hold/cooldown/typewriter lifecycle, and signal emissions. This is invaluable for diagnosing a single button without spamming other buttons.
- **Text autosizing parity:** The autosizer now uses Godot’s TextParagraph pipeline and re-runs whenever wrap/padding/text changes. Cached font sizes are invalidated automatically and a secondary search “grows” the font back up when more room becomes available. If text still overflows, enable the debugger log to inspect measurements vs available space.
- **Hold build-up:** When `EnableHoldBuildUp` is true, OmniButton creates a `HoldFill` ColorRect and animates it according to `HoldFillDirection`. The `Hold` signal fires once the timer reaches `HoldDuration`.
- **Swipe handling:** Swipes respect per-device init/exit settings, ActionMask bits, thresholds, and `HitSlop`. Runtime logs show whether the swipe bit is disabled or the pointer left bounds.
- **Follow / Virtual joystick:** `FollowMode` controls whether the button drags, stays put, or becomes a joystick. Joystick sessions clamp to circular/rectangular regions, emit axis values/started/ended signals, and optionally show a ring (`EnableJoystickArea`). The debugger logs start/stop events and clamp info.
- **Cooldowns:** Any triggerable cooldown automatically clears pressed visuals, can optionally suspend hover scale, and emits debugger logs when starting or finishing. You can hide the overlay during hold build-up for “charge + cooldown” combos.
- **Typewriter text:** `StartTypewriter()` respects BBCode, word mode, and CPS, and can defer effect tags. Skip/Stop log when they emit `TypewriterCompleted` so you can tell if a script cancelled unexpectedly.
- **Runtime/editor parity:** Editor live refresh mirrors runtime by polling exported properties, rebuilding managed children, and running the autosizer immediately.
- **Processing / idle:** At runtime, `_Process` disables itself when nothing needs per-frame work (no pending child/layout refresh, refit frames, typewriter, cooldown delay or active cooldown, hold build-up while pressed, and hover scale is off). While `EnableHoverScale` is true, processing stays enabled so hover lerp can run. Idle shutdown never calls `SetProcess(false)` in the editor, so tool-mode polling keeps working.
- **Mouse + touch together:** With `ProjectSettings` → `input_devices/pointing/emulate_mouse_from_touch` enabled, Godot can deliver both `InputEventScreenTouch` and `InputEventMouseButton` for one physical touch. OmniButton records which modality **first** starts a press (`PointerGestureSource`: mouse vs native touch) and ignores the other until `ResetPressState` clears the session, so you do not get double press/release.
- **Multi-touch drags:** `InputEventScreenDrag` is only applied when `Index` matches the finger that started a native touch press (`_activePointerTouchIndex`). Mouse-driven sessions (`Index` not tracked) accept all drags.
- **Cooldown vs. in-flight press:** While cooldown is active, **new** presses are ignored, but `GuiInput` still runs so an existing press can receive motion, `ScreenDrag`, and release (avoids stuck state if cooldown starts mid-hold).
- **Unhandled cleanup:** Off-control release handling calls `Viewport.SetInputAsHandled()` after resetting a stuck interaction so the event is less likely to propagate to other listeners.
- **Hover clamp after layout moves:** `NotificationTransformChanged` refreshes `HoverTargetForViewport` and keeps processing when hover scaling is enabled, so parent transforms/layout changes can update the clamped hover scale without relying only on resize.
- **Typewriter + `Text` / `LabelType`:** Assigning `Text` or `LabelType` while the typewriter is active updates backing state and queues a visual refresh but skips `SetupChildren` / full rebuild so partial typewriter output is not wiped.
- **Keyboard / gamepad:** When the control has **focus** (`FocusMode` not `None`) and `ui_accept` fires, OmniButton performs a one-shot click (press + release in one step). Joystick and follow-drag modes skip keyboard activation. `FinishTypewriterOnPress` + `ui_accept` skips the typewriter first.
- **Focus outline:** Under **Accessibility → Keyboard focus**, `ShowKeyboardFocusOutline` draws a border in `_Draw()` while the control has focus (color/width exported). `FocusEntered` / `FocusExited` call `QueueRedraw` when the outline is enabled.

## Migration notes
- Prefer LabelType + Text over LabelText/RichLabelText. Legacy properties remain for compatibility but route to the new API.
- Modulate properties appear in their relevant sections: Panel/Background/Icon/Label.

## Troubleshooting
- Swipe not firing: enable Swipe in ActionMask and move beyond SwipeThreshold.
- No hover zoom: set EnableHoverScale = true (hover signals are independent).
- Draggable vs stationary: FollowMode = FollowBoth (drag), FollowMode = None (stationary).
