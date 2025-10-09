# OmniButton (C#)

Universal, highly configurable button control for Godot 4 (C#). OmniButton extends Control and provides:

- Signals and callables for Press/Release/Toggle/Hover/Hold/Swipe and logging
- Auto-managed children: Panel, Icon, Label, Selected/Toggled Overlay, Cooldown, Hold buildup
- Visual helpers: invert on press/toggle/hover, hover scaling, auto-fit label
- Input helpers: bounds source, hit slop, follow-on-press, follow-while-held
- Built-in virtual joystick mode (plug-and-play)

Minimum Godot: 4.x (mono)

## Quick start

- Add an OmniButton to your scene (Add Node → OmniButton).
- Optional visuals: EnablePanel, LabelText, IconTexture, EnableSelectedOverlay.
- Optional behavior: EnablePressedActions, EnableReleasedActions, EnableToggleActions, EnableHoverActions, EnableHoldActions, EnableSwipeActions, EnableLogActions, etc.
- Connect signals using strongly-typed names.

Example

```csharp
public override void _Ready()
{
    var btn = GetNode<OmniButton>("%Play");

    // Connect signals
    btn.Connect(OmniButton.SignalName.Pressed,  Callable.From(OnPressed));
    btn.Connect(OmniButton.SignalName.Released, Callable.From(OnReleased));
    btn.Connect(OmniButton.SignalName.Toggled,  Callable.From<bool>(OnToggled));
    btn.Connect(OmniButton.SignalName.HoverIn,  Callable.From(OnHoverIn));
    btn.Connect(OmniButton.SignalName.HoverOut, Callable.From(OnHoverOut));
    btn.Connect(OmniButton.SignalName.Swipe,    Callable.From<Vector2>(OnSwipe));

    // Visuals
    btn.LabelText = "Play";
    btn.EnablePanel = true;                       // adds a Panel child (full rect)
    btn.EnableSelectedOverlay = true;             // overlay when Selected or IsToggled
    btn.Selected = true;                          // show overlay immediately

    // Behavior toggles
    btn.EnablePressedActions = true;
    btn.EnableReleasedActions = true;
    btn.EnableToggleActions = true;
    btn.EnableHoverActions = true;
    btn.EnableSwipeActions = true;
    btn.EnableHoldActions = true;
}
```

## Signals

- Pressed, Released
- Toggled(bool pressed)
- HoverIn, HoverOut
- Hold (after HoldDuration while pressed)
- Swipe(Vector2 direction)
- Log(string message), Warning(string message), Error(string message)
- Virtual Joystick: JoystickStarted, JoystickAxis(Vector2 axis), JoystickEnded

Tip: Use OmniButton.SignalName.\* for robust names.

## Inspector overview

State

- Disabled
- Selected, IsToggled, IsPressed, IsHovering, IsHolding (runtime visual flags; prefer using actions/signals to drive logic)

Content Display

- EnablePanel: adds a Panel child (full-rect). Styled by theme or PanelStyleBox override.
- IconTexture: shows a TextureRect child.
- LabelText: shows a Label child.
- EnableSelectedOverlay: shows an overlay ColorRect when Selected or IsToggled.
- SelectedColor, UnselectedColor: overlay tint colors.

Panel Settings

- PanelThemeVariation: Theme type-variation used by the child Panel (e.g., “primary”).
- PanelStyleBox: optional hard override of the Panel’s “panel” stylebox.
- PanelThemeType: exported for completeness; Godot uses the Panel class for lookups.

Icon Settings

- IconExpandMode, IconStretchMode, IconFlipH, IconFlipV.

Label Settings

- LabelFont (optional), LabelTextColor
- MinFontSize, MaxFontSize (auto-fit limits)
- LabelHorizontalAlignment, LabelVerticalAlignment, LabelAutowrap

Invert Display

- InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover
  Note: Panel isn’t tinted; overlay/icon/label get visual effects so theme styles remain intact.

Input

- BoundsSource: Control whose rect constrains movement and hit tests; falls back to parent or viewport.
- HitSlop: grows hit bounds for touch comfort.

Swipe & Hold

- SwipeThreshold (pixels)
- HoldDuration (sec), EnableHoldBuildUp, HoldFillColor, HoldFillDirection (Top/Bottom/Left/Right)

Follow Input

- FollowOnPress: jump under pointer on press.
- FollowWhileHeld: follow pointer while held.
- ClampToBounds: keep within BoundsSource/parent/viewport.

Cooldown

- EnableCooldown, CooldownDuration
- CooldownOnPress, CooldownOnRelease
- CooldownStartFilled, CooldownColor, CooldownFillDirection
- SuspendHoverScaleDuringCooldown
- AllowHoldDuringCooldown
- HideCooldownDuringHoldBuildUp

Theme Variations

- ThemeTypeName, VariantNormal/Pressed/Hover/Toggled/Selected/Disabled
  Note: These are available for theme binding; Panel styling is handled via PanelThemeVariation or PanelStyleBox.

## Display details

- Panel: full-rect Panel (Theme-driven; not tinted). Set PanelStyleBox to override.
- Label: auto-fit between MinFontSize..MaxFontSize into the control’s padded area.
- Overlay: ColorRect for selected/toggled tint. Use SelectedColor/UnselectedColor.
- Cooldown: ColorRect fill, direction and color configurable.
- Hold buildup: ColorRect grow fill during hold buildup.

## Behavior examples

Toggle

```csharp
btn.EnableToggleActions = true;
btn.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(on => GD.Print($"Toggled: {on}")));
```

Hold (with buildup)

```csharp
btn.EnableHoldActions = true;
btn.EnableHoldBuildUp = true;
btn.HoldDuration = 1.0f;
btn.Connect(OmniButton.SignalName.Hold, Callable.From(() => GD.Print("Hold!")));
```

Swipe

```csharp
btn.EnableSwipeActions = true;
btn.SwipeThreshold = 32f;
btn.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(dir => GD.Print($"Swipe {dir}")));
```

Cooldown

```csharp
btn.EnableCooldown = true;
btn.CooldownOnPress = true;     // or CooldownOnRelease
btn.CooldownDuration = 2.0f;
btn.CooldownFillDirection = OmniButton.CooldownDirection.LeftToRight;
```

Follow input

```csharp
btn.BoundsSource = GetNode<Control>("%TouchArea");
btn.FollowOnPress = true;
btn.FollowWhileHeld = true;
btn.ClampToBounds = true; // default
```

## Virtual Joystick (built-in)

Two ways to use:

A) Zero-code, automatic mode

- Set on the OmniButton:

  - EnableVirtualJoystick = true
  - BoundsSource = the Control that defines the joystick area (or leave null to use parent/viewport)
  - JoystickDeadzone = 0.1 (adjust)
  - JoystickRadiusPx = 0 (auto) or a pixel radius
  - JoystickResetOnRelease = true

- Connect these signals:

```csharp
btn.Connect(OmniButton.SignalName.JoystickStarted, Callable.From(() => GD.Print("Joystick start")));
btn.Connect(OmniButton.SignalName.JoystickAxis,    Callable.From<Vector2>(axis => MoveCharacter(axis)));
btn.Connect(OmniButton.SignalName.JoystickEnded,   Callable.From(() => GD.Print("Joystick end")));
```

Behavior:

- On press inside the button, it jumps under the pointer and follows while held.
- Axis is normalized to -1..1 (unit circle), with deadzone. Clamped to BoundsSource/parent/viewport.
- On release, it emits JoystickAxis(Vector2.Zero), JoystickEnded, and snaps back if JoystickResetOnRelease is true.

B) Programmatic control (for composite gamepads)
Use the public API if you need to spawn or centralize logic:

```csharp
// Center OmniButton in your gamepad container
center.EnableVirtualJoystick = true;
center.BoundsSource = GetNode<Control>("%Gamepad");

// When user taps your Move area:
center.StartVirtualJoystickAt(GetViewport().GetMousePosition());

// Each drag/motion:
center.UpdateVirtualJoystick(globalPointer);

// On release:
center.StopVirtualJoystick();
```

Notes:

- OmniButton internally sets MouseFilter during joystick sessions so hover on other controls can still work.
- Axis is computed from the “home” center (at press time) to the clamped pointer position.
- Use BoundsSource to constrain movement inside a specific container (e.g., your gamepad background).

## Panel styling with Theme

- Assign a Theme to your OmniButton (Inspector → Theme).
- In your Theme resource, define class Panel → Styles → panel, and optional Variations (e.g., “primary”).
- On the OmniButton, set:
  - EnablePanel = true
  - PanelThemeVariation = "primary" (or leave empty for default)
  - PanelStyleBox empty to use the Theme (set it only to hard-override)

Tip: Overlay color can obscure borders; lower SelectedColor alpha if needed.

## Tips

- EnableHoverScale for a lightweight visual zoom even if you don’t need HoverIn/Out signals.
- HitSlop adds padding to improve touchability.
- Use BoundsSource whenever you want constrained movement, including FollowOnPress/FollowWhileHeld and Virtual Joystick.
- Avoid manually tinting the Panel; use Overlay or invert effects on icon/label/overlay.

## Troubleshooting

- Scene parse errors at line 1: ensure .tscn is saved as UTF-8 (no BOM) and first char is “[”.
- “Signal not found”: connect with OmniButton.SignalName.\* (not the delegate type).
- Panel style “looks wrong”: Panel isn’t tinted; Theme must provide Panel → Styles → panel or set PanelStyleBox.
- ObjectDisposedException on save/reload: update to the latest OmniButton (managed children are not serialized; references are cleared when freed).
