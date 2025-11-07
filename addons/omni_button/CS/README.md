# OmniButton (C#) — Full Reference

Universal, highly configurable Control for Godot 4 (.NET) that unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. All features are editor-friendly and driven by exported properties and signals.

Minimum Godot: 4.x (.NET)

Contents
- Signals
- Exported Properties (by group)
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

Tip: Use OmniButton.SignalName.* for refactor-safe signal names.

## Exported Properties

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
- PanelThemeType, PanelThemeVariation, PanelStyleBox
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

### Actions
- ActionMaskBits — Flags that determine which actions emit: Pressed, Released, Hover, Toggle, Hold, Swipe, Log, Warning, Error.
- ActionMask — Typed enum wrapper for ActionMaskBits.
- Optional callables invoked when assigned: PressedAction, ReleasedAction, HoverInAction, HoverOutAction, ToggledAction, HoldAction, SwipeAction, LogAction, WarningAction, ErrorAction.
- InteractionMode — Momentary | ToggleOnPress | ToggleOnRelease.

### Input / Follow / Virtual Joystick
- BoundsSource, HitSlop
- FollowMode — None | FollowBoth | VirtualJoystick
- ClampShape — Circle | Rectangle
- JoystickRadiusPx, JoystickRectSizePx, JoystickDeadzone, JoystickSnapToInput
- JoystickHideWhenInactive, JoystickResetOnRelease
- EnableJoystickArea, JoystickAreaPersistent/Color/Thickness, JoystickAreaUseRectForClamp
- EnableDefaultThumb, DefaultThumbSizeRatio, DefaultThumbColor

### Cooldown
- EnableCooldown, CooldownTrigger (OnPress | OnRelease | OnPressAndRelease)
- CooldownDuration, CooldownStartFilled, CooldownColor, CooldownFillDirection
- SuspendHoverScaleDuringCooldown, AllowHoldDuringCooldown, HideCooldownDuringHoldBuildUp

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
- Action bits auto-enable once: when you first connect an external handler (editor or code) to a signal, the matching ActionMask bit turns on. If you disable it later, it remains off.
- Editor live refresh: inspector changes re-render immediately via editor-only polling of exported properties.

## Migration notes
- Prefer LabelType + Text over LabelText/RichLabelText. Legacy properties remain for compatibility but route to the new API.
- Modulate properties appear in their relevant sections: Panel/Background/Icon/Label.

## Troubleshooting
- Swipe not firing: enable Swipe in ActionMask and move beyond SwipeThreshold.
- No hover zoom: set EnableHoverScale = true (hover signals are independent).
- Draggable vs stationary: FollowMode = FollowBoth (drag), FollowMode = None (stationary).
