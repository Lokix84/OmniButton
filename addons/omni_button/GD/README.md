OmniButton (GDScript)
Universal, highly configurable Control-based button. Unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. Editor-friendly (`@tool`).

Quick start

```gdscript
func _ready() -> void:
    var btn: Omni_Button = $OmniButton

    # Signals
    btn.pressed.connect(_on_pressed)
    btn.toggled.connect(func(p): _on_toggled(p))
    btn.hover_in.connect(_on_hover_in)
    btn.hover_out.connect(_on_hover_out)
    btn.swipe.connect(func(dir): _on_swipe(dir))
    btn.hold.connect(_on_hold)

    # Display
    btn.LabelType = Omni_Button.LabelKind.Label
    btn.Text = "Play"
    btn.IconTexture = preload("res://icon.png") # Icon child auto-created

    # Behavior
    btn.ActionMaskBits |= Omni_Button.ACT_PRESSED
    btn.ActionMaskBits |= Omni_Button.ACT_RELEASED
    btn.ActionMaskBits |= Omni_Button.ACT_TOGGLE
    btn.ActionMaskBits |= Omni_Button.ACT_HOVER
    btn.EnableHoverScale = true        # visual zoom (independent of hover signals)
    btn.ActionMaskBits |= Omni_Button.ACT_SWIPE
    btn.ActionMaskBits |= Omni_Button.ACT_HOLD
    btn.EnableCooldown = true
    btn.CooldownTrigger = Omni_Button.CooldownTriggerEnum.OnPress
    btn.CooldownDuration = 2.0
    btn.CooldownStartFilled = false
    btn.CooldownColor = Color(0,0,0,0.4)

    # Visual details
    btn.HoverScale = 1.2
    btn.HoverLerpSpeed = 25.0
    btn.InvertModes = Omni_Button.INVERT_HOVER
    btn.LabelTextColor = Color(1, 1, 0) # yellow text
```

Signals

- pressed, released, toggled(bool)
- hover_in, hover_out
- swipe(Vector2 direction), swipe_ended, hold
- log(message), warning(message), error(message)

What's included

- Unified text: LabelType (Label or RichTextLabel) + multiline Text; RichLabelUseBBCode for BBCode.
- Text autosizing: fits within control bounds between MinFontSize..MaxFontSize; FixedFontSize bypasses autosize.
- Icon: creates/updates a TextureRect; nearest filtering for crisp pixel art.
- Hover scaling: EnableHoverScale to scale visuals; scale clamped to viewport practical max.
- Invert display: InvertModes flags apply a simple invert to child visuals.
- Swipe & Hold: mouse and touch swipes; hold emits after HoldDuration.
- Hit testing: BoundsSource and HitSlop.

Key properties (by group)

- Content Display: Background, IconTexture, LabelType, Text, RichLabelUseBBCode, EnableSelectedOverlay, SelectedColor
- Background Settings: PanelThemeType, PanelThemeVariation, PanelStyleBox, BackgroundTexture, Expand/Stretch/Flip, PanelModulate, BackgroundModulate
- Icon Settings: Expand/Stretch/Flip, IconModulate
- Label Settings: LabelFont, LabelTextColor, TextModulate, Min/Max/FixedFontSize, TextFitPadding, LabelHorizontalAlignment, LabelVerticalAlignment, LabelAutowrap, LabelPadding (+ per-side)
- Invert Display: InvertModes
- Hover Scaling: EnableHoverScale, HoverScale, HoverLerpSpeed
- Actions: ActionMaskBits (+ callable exports), InteractionMode
- Input/Follow/Virtual Joystick: BoundsSource, HitSlop, FollowMode, joystick and area settings
- Cooldown: EnableCooldown, CooldownTrigger, Duration/Color/Direction, SuspendHoverScaleDuringCooldown, AllowHoldDuringCooldown, HideCooldownDuringHoldBuildUp

Accessors (ergonomic code)
- $OmniButton.label.text, $OmniButton.icon.tex, $OmniButton.background.mode, $OmniButton.panel.style_box, $OmniButton.overlay.enabled, $OmniButton.cooldown.enabled, $OmniButton.charge_up.enabled

Tips

- Use EnableHoverScale without hover signals if you only want the visual zoom.
- For touch, increase HitSlop to improve usability.
- Action bits auto-enable once when you connect external handlers; you can still disable them manually and they will remain off.

Troubleshooting

- Nothing happens: ensure Disabled == false and the node has size; confirm parents aren't consuming input.
- Hover not scaling: set EnableHoverScale = true. Hover signals are optional.
- Swipe not firing: include ACT_SWIPE in ActionMaskBits and drag beyond SwipeThreshold.
- Toggle visuals: set InteractionMode to a toggle mode and include ACT_TOGGLE in ActionMaskBits.
