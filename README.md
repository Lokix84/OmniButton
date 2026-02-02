OmniButton for Godot 4
Universal, highly configurable button/joystick control available in both C# and GDScript. OmniButton unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, optional panel/overlay visuals, and a virtual joystick mode into a single, editor-friendly node.

Why OmniButton
- Single node, many behaviors: press/release/toggle/hold/swipe/invert/cooldown.
- Editor-friendly: properties update live in the Inspector; safe defaults.
- C# and GDScript parity: same features and signals in both variants.
- Drop-in UI: full-rect children, crisp icon filtering, theme variations.

Repository layout
- addons/omni_button/CS/OmniButton.cs — C# implementation
- addons/omni_button/GD/omni_button.gd — GDScript implementation
- addons/omni_button/test/ — simple scenes/scripts demonstrating features

Signals
- Pressed, Released, Toggled(bool), HoverIn, HoverOut, Hold, Swipe(Vector2), SwipeEnded()
- JoystickStarted, JoystickAxis(Vector2), JoystickEnded
- Log(string), Warning(string), Error(string)

Updates and version notes
- Unified label API: use LabelType (Label or RichTextLabel) + multiline Text. Legacy LabelText/RichLabelText still work but map to Text + LabelType.
- Modulate properties live in their relevant groups: PanelModulate/BackgroundModulate (Background Settings), IconModulate (Icon Settings), TextModulate (Label Settings).
- Accessors for ergonomic code:
  - C#: LabelNode, IconNode, BackgroundNode, PanelNode, OverlayNode, CooldownNode, ChargeUpNode.
  - GDScript: lowercase accessors label, icon, background, panel, overlay, cooldown, charge_up.
- Auto-enable actions once: when you connect a signal handler (editor or code) for the first time, the matching ActionMask bit turns on. If you turn it off later, it stays off.
- Editor live refresh: inspector changes re-render immediately via editor-only polling of exported properties (both GDScript and C#).

Quick start (C#)
- Add OmniButton, wire signals, and toggle features:

```csharp
public override void _Ready()
{
    var btn = GetNode<OmniButton>("%MyButton");
    btn.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed;
    btn.EnableHoverScale = true;
    btn.InvertModes |= OmniButton.InvertDisplayModes.Hover;
    btn.EnableSelectedOverlay = true;
    btn.SelectedColor = new Color(0, 1, 0, 0.5f);
    btn.Connect(OmniButton.SignalName.Pressed, Callable.From(() => GD.Print("Pressed")));
    btn.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(dir => GD.Print($"Swipe: {dir}")));
    btn.Connect(OmniButton.SignalName.SwipeEnded, Callable.From(() => GD.Print("SwipeEnded")));
}
```

Feature reference and examples

- State
  - Disabled, Selected, IsToggled, IsPressed, IsHovering, IsHolding
  - Example: set Selected to show overlay color.
    ```csharp
    btn.EnableSelectedOverlay = true;
    btn.Selected = true;
    btn.SelectedColor = new Color(0, 1, 0, 0.5f);
    ```

- Content Display
  - EnablePanel, IconTexture, LabelText
  - Example: icon + text with panel.
    ```csharp
    btn.EnablePanel = true;
    btn.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
    btn.LabelText = "Play";
    ```

- Actions
  - ActionMaskBits: flags for Pressed/Released/Hover/Toggle/Hold/Swipe/Log/Warning/Error
  - InteractionMode: Momentary | ToggleOnPress | ToggleOnRelease
  - Example: toggle button on press.
    ```csharp
    btn.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress;
    btn.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Toggled;
    ```

- Hold Build-Up
  - EnableHoldBuildUp, HoldDuration, HoldFillColor, HoldFillDirection
  - Example: 1s hold to trigger.
    ```csharp
    btn.EnableHoldBuildUp = true;
    btn.HoldDuration = 1.0f;
    btn.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hold;
    btn.Connect(OmniButton.SignalName.Hold, Callable.From(() => GD.Print("Hold!")));
    ```

- Swipe
  - SwipeThreshold: pixels before Swipe(Vector2) fires.
  - Swipe init/exit dropdowns (per-device):
    - TouchSwipeInit: OnHoverIn | OnPressed
    - TouchSwipeExit: OnHoverOut | OnReleased
    - MouseSwipeInit: OnPressed | OnHoverIn
    - MouseSwipeExit: OnReleased | OnHoverOut
  - Read-only state: IsSwiping
  - Events: Swipe(direction), SwipeEnded()
  - Example: arrow icon by swipe direction.
    ```csharp
    btn.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Swipe;
    btn.SwipeThreshold = 20f;
    btn.MouseSwipeInit = OmniButton.SwipeInitMode.OnHoverIn;
    btn.MouseSwipeExit = OmniButton.SwipeExitMode.OnHoverOut;
    btn.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(dir => btn.IconTexture = GD.Load<Texture2D>(
        dir.Abs().X >= dir.Abs().Y ? (dir.X >= 0 ? "res://addons/omni_button/test/icons/Icon-RightArrow1.png" : "res://addons/omni_button/test/icons/Icon-LeftArrow1.png")
                                   : (dir.Y >= 0 ? "res://addons/omni_button/test/icons/Icon-DownArrow1.png"  : "res://addons/omni_button/test/icons/Icon-UpArrow1.png")
    )));
    btn.Connect(OmniButton.SignalName.SwipeEnded, Callable.From(() => GD.Print("Swipe ended")));
    ```

- Input
  - BoundsSource: optional control to clamp hit/follow/joystick area.
  - HitSlop: extra pixels around the hit rect.
  - Example: clamp to parent container.
    ```csharp
    btn.BoundsSource = btn.GetParent<Control>();
    btn.HitSlop = new Vector2(8, 8);
    ```

- Follow Input
  - FollowMode = None | FollowBoth | VirtualJoystick
  - None: does not move when dragged (stationary)
  - FollowBoth: follows pointer within clamp rect
  - VirtualJoystick: see next section
  - Example: draggable button within parent.
    ```csharp
    btn.FollowMode = OmniButton.FollowModeEnum.FollowBoth;
    ```

- Virtual Joystick
  - EnableVirtualJoystick, ClampShape (Circle/Rectangle)
  - JoystickRadiusPx | JoystickRectSizePx (0/Zero = auto)
  - JoystickDeadzone, JoystickSnapToInput, JoystickHideWhenInactive, JoystickResetOnRelease
  - Events: JoystickStarted, JoystickAxis(Vector2), JoystickEnded
  - Example: simple stick.
    ```csharp
    btn.FollowMode = OmniButton.FollowModeEnum.VirtualJoystick;
    btn.ClampShape = OmniButton.JoystickClampShape.Circle;
    btn.JoystickDeadzone = 0.15f;
    btn.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(axis => GD.Print(axis)));
    ```

- Cooldown
  - EnableCooldown, CooldownTrigger (OnPress | OnRelease | OnPressAndRelease)
  - CooldownDuration, CooldownStartFilled, CooldownColor, CooldownFillDirection
  - SuspendHoverScaleDuringCooldown, AllowHoldDuringCooldown, HideCooldownDuringHoldBuildUp
  - Example: 1.5s cooldown on release.
    ```csharp
    btn.EnableCooldown = true;
    btn.CooldownTrigger = OmniButton.CooldownTriggerEnum.OnRelease;
    btn.CooldownDuration = 1.5f;
    ```

- Hover Scaling
  - EnableHoverScale, HoverScale, HoverLerpSpeed
  - Scaling stays centered; clamped to viewport to avoid clipping.
  - Example: subtle zoom.
    ```csharp
    btn.EnableHoverScale = true;
    btn.HoverScale = 1.15f;
    btn.HoverLerpSpeed = 20f;
    ```

- Label Settings
  - LabelFont, LabelTextColor, MinFontSize, MaxFontSize
  - LabelHorizontalAlignment, LabelVerticalAlignment, LabelAutowrap
  - RichLabelText for formatted text; enable RichLabelUseBBCode to parse BBCode.
    See BBCode reference: https://docs.godotengine.org/en/latest/tutorials/ui/bbcode_in_richtextlabel.html
  - Example: fit text within.
    ```csharp
    btn.LabelText = "Start";
    btn.MinFontSize = 10;
    btn.MaxFontSize = 64;
    ```

- Panel & Icon Settings
  - PanelThemeVariation, PanelStyleBox
  - IconExpandMode, IconStretchMode, IconFlipH, IconFlipV

- Invert Display
  - InvertModes flags: Press, Toggle, Hover, Hold
  - Example: invert on press & hover.
    ```csharp
    btn.InvertModes = OmniButton.InvertDisplayModes.Press | OmniButton.InvertDisplayModes.Hover;
    ```

Tips & troubleshooting
- Ensure ActionMaskBits includes the signals you want (e.g., Swipe, Pressed, Released).
- When using Mouse Swipe Init = OnHoverIn, swipe continues while inside and ends based on MouseSwipeExit.
- FollowMode = None ensures the button does not move when dragged.

Install
- Copy `addons/omni_button` into your project’s `addons/` folder.
- Use either C# or GDScript variant (or both). No extra setup is required.

Compatibility
- Godot 4.x (C# and GDScript). For C#, install Godot .NET support templates.

Contributing
- Issues and PRs welcome. Please keep C# and GDScript in feature parity.

License
- MIT. See LICENSE.
