# OmniButton (C#) — Full Reference

Universal, highly configurable Control for Godot 4 (.NET) that unifies press/release/toggle, hover scaling, invert‑on‑state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. All features are editor‑friendly and driven by exported properties and signals.

Minimum Godot: 4.x (.NET)

Contents
- Signals
- Exported Properties (by group)
- Public API (functions)
- Behavior Notes and Examples
- Panel/Theme Styling
- Troubleshooting

## Signals
- `Pressed` — Emitted on press when enabled by `ActionMaskBits`.
- `Released` — Emitted on release when enabled.
- `Toggled(bool pressed)` — Emitted when InteractionMode toggles on/off.
- `HoverIn`, `HoverOut` — Emitted on pointer enter/exit when enabled.
- `Hold` — Emitted once after `HoldDuration` build‑up completes.
- `Swipe(Vector2 direction)` — Emitted with a normalized direction during swipe.
- `SwipeEnded()` — Emitted when a swipe session ends.
- `JoystickStarted`, `JoystickAxis(Vector2 axis)`, `JoystickEnded` — Virtual joystick lifecycle and axes (−1..1).
- `Log(string)`, `Warning(string)`, `Error(string)` — Optional logging signals.

Tip: Use `OmniButton.SignalName.*` for robust, refactor‑safe signal names.

## Exported Properties

### State
- `Disabled` — Blocks input and visual reactions.
- `Selected` — Marks selected; shows overlay when enabled.
- `IsToggled` — Current toggle state.
- `IsPressed`, `IsHovering`, `IsHolding` — Live state flags; primarily driven by input but may be set to force visuals.

### Presets
- `PresetSelection` — Apply a preset (Basic, Toggle, Hold, Swipe, Draggable, VirtualJoystick). Any edits switch to Custom.

### Content Display
- `Background` — `None | UsePanel | UseTexture`.
- `IconTexture` — Optional icon texture.
- `LabelText` — Plain `Label` text. Use this or Rich.
- `RichLabelText` — `RichTextLabel` content; pair with `RichLabelUseBBCode`.
- `RichLabelUseBBCode` — Interpret `RichLabelText` as BBCode.
- `EnableSelectedOverlay` — Show overlay when `Selected` or `IsToggled`.
- `SelectedColor` — Overlay color.

### Background Settings
- `PanelThemeType` — Theme class (default "Panel").
- `PanelThemeVariation` — Theme type variation.
- `PanelStyleBox` — Explicit style override for the panel (optional).
- `BackgroundTexture` — Texture when `Background = UseTexture`.
- `BackgroundExpandMode`, `BackgroundStretchMode` — TextureRect sizing.
- `BackgroundFlipH`, `BackgroundFlipV` — Flip background texture.

### Icon Settings
- `IconExpandMode`, `IconStretchMode` — Icon sizing modes.
- `IconFlipH`, `IconFlipV` — Flip icon.

### Label Settings
- `LabelFont` — Font override for Label/RichTextLabel.
- `LabelTextColor` — Label font color; RichTextLabel `default_color`.
- `EnableTextAutoSize` — Autosize text to fit the available area.
- `FixedFontSize` — If > 0, force this size and bypass autosize.
- `MinFontSize`, `MaxFontSize` — Autosize bounds.
- `TextFitPadding` — Symmetric margin reserved by autosize (reduces available area before measuring).
- `LabelHorizontalAlignment`, `LabelVerticalAlignment`, `LabelAutowrap` — Layout and wrap.
- `LabelPadding` — Universal padding for text (X adds to left+right, Y adds to top+bottom).
- `LabelAdditionalPaddingLeft`, `LabelAdditionalPaddingTop`, `LabelAdditionalPaddingRight`, `LabelAdditionalPaddingBottom` — Additional per‑side padding added cumulatively on top of `LabelPadding`.
- RichText BBCode reference — https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html

Effect: Increasing any padding reduces the measured area for autosize (smaller font) and insets the rendered text away from the edges.

### Invert Display
- `InvertModes` — Flags: `Press | Toggle | Hover | Hold`. Applies a simple invert shader to children (icon/label/overlay) while active.

### Hover Scaling
- `EnableHoverScale` — Enable hover zoom.
- `HoverScale` — Target scale (e.g., 1.15).
- `HoverLerpSpeed` — Interpolation speed.

### Actions
- `ActionMaskBits` — Flags that determine which actions emit:
  `Pressed, Released, Hover, Toggle, Hold, Swipe, Log, Warning, Error`.
- `ActionMask` — Typed enum wrapper for `ActionMaskBits`.
- Optional callables invoked when assigned: `PressedAction`, `ReleasedAction`, `HoverInAction`, `HoverOutAction`, `ToggledAction`, `HoldAction`, `SwipeAction`, `LogAction`, `WarningAction`, `ErrorAction`.
- `InteractionMode` — `Momentary | ToggleOnPress | ToggleOnRelease`.

### Input
- `BoundsSource` — Optional `Control` whose rect clamps hit/follow/joystick; falls back to parent or viewport.
- `HitSlop` — Extra pixels around the hit rect.

### Follow Input
- `FollowMode` — `None | FollowBoth | VirtualJoystick`.
  - None — Stationary; only state/visuals change.
  - FollowBoth — Follows pointer while pressed (within clamp rect).
  - VirtualJoystick — Engage joystick behavior (see below).

### Virtual Joystick
- `EnableVirtualJoystick` — Enables joystick behavior regardless of `FollowMode`.
- `ClampShape` — `Circle | Rectangle`.
- `JoystickRadiusPx` — Circle radius (0 = auto from clamp area).
- `JoystickRectSizePx` — Rectangle size (Zero = auto from clamp area).
- `JoystickDeadzone` — Axes below this magnitude read as zero.
- `JoystickSnapToInput` — Move button center to input while active.
- `JoystickHideWhenInactive` — Hide Control when not in a joystick session.
- `JoystickResetOnRelease` — Return to original position when released.
- Joystick Area ring (when present): `EnableJoystickArea`, `JoystickAreaPersistent`, `JoystickAreaUseRectForClamp`, `JoystickAreaClampInsetPx`, `JoystickAreaRadiusPx`, `JoystickAreaThicknessPx`, `JoystickAreaColor`.

### Cooldown
- `EnableCooldown` — Blocks input between triggers.
- `CooldownTrigger` — `OnPress | OnRelease | OnPressAndRelease`.
- `CooldownDuration` — Seconds.
- `CooldownStartFilled` — Starts filled then empties (or vice‑versa).
- `CooldownColor` — Fill color.
- `CooldownFillDirection` — Direction of fill.
- `SuspendHoverScaleDuringCooldown` — Optionally suspend hover scale during cooldown.
- `AllowHoldDuringCooldown` — Optionally allow hold during cooldown.
- `HideCooldownDuringHoldBuildUp` — Hide cooldown while hold fill overlay is visible.

### Theme Variations
- `VariantNormal`, `VariantPressed`, `VariantHover`, `VariantToggled`, `VariantSelected`, `VariantDisabled` — Theme type variations used if present in your Theme.

## Public API (Functions)
- `StartCooldown()` — Begins cooldown (if `EnableCooldown`), updates the cooldown fill and enables processing.
- `IsSwiping` (property) — True while a swipe session is active.
- `StartVirtualJoystickAt(Vector2 globalPoint)` — Begin a joystick session at a screen point. Emits `JoystickStarted` and the first `JoystickAxis`.
- `UpdateVirtualJoystick(Vector2 globalPoint)` — Update an active joystick session; emits `JoystickAxis`.
- `StopVirtualJoystick()` — End joystick session; emits zero axis and `JoystickEnded`. Optionally resets position and hides when configured.
- Logging helpers — `PrintLog(string)`, `DefaultLog(string)`, `PrintWarn(string)`; convenience wrappers that also emit logging signals.

Lifecycle (overrides; normally not called directly)
- `_EnterTree()` — Initialize internal state, connect handlers.
- `_ExitTree()` — Cleanup and clear references to transient children.
- `_Ready()` — Build children and apply visuals; editor‑safe.
- `_Process(double delta)` — Drives hover scaling and hold build‑up visuals.
- `_UnhandledInput(InputEvent)` — Ensures releases/swipe/joystick finalize even if cursor leaves the control.
- `_GuiInput(InputEvent)` — Central router for press/release/drag/hover/swipe/joystick.
- `_Notification(int what)` — React to resize/theme/visibility/editor hints and refresh visuals.

## Behavior Notes and Examples
- Toggle
  - `InteractionMode = ToggleOnPress; ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Toggled;`
- Hover Scale
  - Enable even if you don’t need hover signals for a subtle zoom: `EnableHoverScale = true; HoverScale = 1.15f;`
- Corner count label
  - Bottom‑right alignment plus padding:
    - `LabelHorizontalAlignment = Right; LabelVerticalAlignment = Bottom;`
    - `LabelPadding = new Vector2(0,0);`
    - `LabelAdditionalPaddingRight = 6; LabelAdditionalPaddingBottom = 6;`
- Swipe (mouse hover‑init)
  - `MouseSwipeInit = OnHoverIn; MouseSwipeExit = OnHoverOut; SwipeThreshold = 20f;`
- Cooldown on release
  - `EnableCooldown = true; CooldownTrigger = OnRelease; CooldownDuration = 1.5f;`
- Virtual joystick
  - `FollowMode = VirtualJoystick; ClampShape = Circle; JoystickDeadzone = 0.15f;`
  - Use `BoundsSource` to define the clamp region.

## Panel/Theme Styling
- Assign a Theme to OmniButton. The panel (when `Background = UsePanel`) resolves style from Theme class `Panel` with optional `ThemeTypeVariation`.
- Clear `PanelStyleBox` to let Theme drive the look; set it only when you need a hard override.
- Prefer using the overlay for selection color instead of tinting the panel.

## Troubleshooting
- No signals — Ensure `ActionMaskBits` includes them and `Disabled` is false.
- Text hugging edges — Increase `LabelPadding` and/or additional per‑side padding; autosize respects the cumulative padding.
- Editor visuals stale — Toggling a property forces a redraw; the control queues redraws on relevant inspector changes.
- Disposed object errors — The control validates child nodes before access and clears references during cleanup.

