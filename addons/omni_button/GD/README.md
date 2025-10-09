OmniButton (GDScript)
Universal, highly configurable `Control`-based button. Unifies press, toggle, hover scaling, swipe, hold, dynamic label sizing, and icon visuals — works at runtime and in the editor (`@tool`).

Quick start

```gdscript
func _ready() -> void:
    var btn: OmniButton = $OmniButton

    # Signals
    btn.pressed.connect(_on_pressed)
    btn.toggled.connect(func(p): _on_toggled(p))
    btn.hover_in.connect(_on_hover_in)
    btn.hover_out.connect(_on_hover_out)
    btn.swipe.connect(func(dir): _on_swipe(dir))
    btn.hold.connect(_on_hold)

    # Display
    btn.text = "Play"
    btn.texture = preload("res://icon.png") # Icon child auto‑created

    # Behavior
    btn.enable_press_actions = true
    btn.enable_release_actions = true
    btn.enable_toggle_actions = true
    btn.enable_hover_actions = true      # signals only
    btn.enable_hover_scale = true        # visual zoom (independent of hover signals)
    btn.enable_swipe_actions = true
    btn.enable_hold_actions = true\n    btn.enable_cooldown = true\n    btn.cooldown_on_press = true\n    btn.cooldown_duration = 2.0\n    btn.cooldown_start_filled = false\n    btn.cooldown_color = Color(0,0,0,0.4)

    # Visual details
    btn.hover_scale = 1.2
    btn.hover_lerp_speed = 25.0
    btn.invert_on_hover = true
    btn.label_text_color = Color(1, 1, 0) # yellow text
```

Signals

- `pressed`, `released`, `toggled(bool)`
- `hover_in`, `hover_out`
- `swipe(Vector2 direction)`, `hold`
- `log(type, message)`, `warning(message)`, `error(message)`

What’s included

- Text & autosizing: setting `text` creates/updates a Label child; fonts auto‑fit within size limits.
- Icon: creates/updates a TextureRect child with `texture`; uses nearest filtering for crisp pixel art.
- Hover scaling: set `enable_hover_scale = true` to scale label/icon/overlay around their centers. Visuals may overflow parent containers, but scale is clamped to stay inside the main viewport.\n- Invert on hover: set `invert_on_hover = true` to invert visuals while hovering.
- Swipe & Hold: mouse and touch swipes with `swipe_threshold`; hold emits after `hold_duration` while pressed.
- Hit testing: change `bounds_source`, expand with `hit_slop`.

Key properties (by group)

- General: `button_disabled`
- Input & Hit Detection: `action_name`, `require_focus_for_action`, `bounds_source`, `hit_slop`
- Interaction & Actions: `enable_press_actions`, `pressed_action`, `enable_release_actions`, `released_action`, `enable_toggle_actions`, `toggle_pressed`, `toggled_action`
- Hover & Scaling: `enable_hover_actions`, `enable_hover_scale`, `hover_in_action`, `hover_out_action`, `hover_scale`, `hover_lerp_speed`
- Text & Font: `text`, `min_font_size`, `max_font_size`, `horizontal_alignment`, `vertical_alignment`, `autowrap_mode`, `invert_text_if_no_icon`, `label_text_color`
- Texture: `texture`, `pressed_texture`
- Theme & Visuals: `theme_type_name`, base/label/icon theme variation exports, `inherit_theme_to_children`
- Logging: `log_action`
- Swipe & Hold: `enable_swipe_actions`, `swipe_threshold`, `enable_hold_actions`, `hold_duration`
- Cooldown: `enable_cooldown`, `cooldown_duration`, `cooldown_on_press`, `cooldown_start_filled`, `cooldown_color`

Tips

- Use `enable_hover_scale` without `enable_hover_actions` if you only want the visual zoom.
- For touch, increase `hit_slop` to improve usability.
- Keep hover scale modest; hard clamping prevents overscaling past the viewport.

Troubleshooting

- “Nothing happens”: ensure `button_disabled == false` and the node has size; confirm parents aren’t consuming input.
- Hover not scaling: set `enable_hover_scale = true`. Hover signals are optional.
- Swipe not firing: enable `enable_swipe_actions` and drag while holding LMB (or touch drag). Adjust `swipe_threshold`.
- Toggle visuals: set `enable_toggle_actions = true`; use `toggle_pressed` to change state programmatically.


