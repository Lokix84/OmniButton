# OmniButton (GDScript) — Full Reference

Universal, highly configurable Control for Godot 4 (GDScript) that unifies press/release/toggle, hover scaling, invert-on-state, swipe, hold, cooldown fill, overlays, background panel/texture, and an optional virtual joystick. All features are editor-friendly (`@tool`) and driven by exported properties and signals.

Minimum Godot: 4.x

**New to the plugin?** Read [GETTING_STARTED.md](GETTING_STARTED.md) first: install, the demos, which piece to use for what, and a walkthrough that builds a small game's UI. This page is the full reference for the `OmniButton` node itself.

Ready-made buttons (menu, toggle, icon, item, hold-to-confirm, cooldown) touch controls (joystick, floating joystick, swipe pad, action button) and more (typewriter title, invert flash, tab bar) to drag into a scene are in `prebuilt/buttons/`; see [prebuilt/buttons/README.md](prebuilt/buttons/README.md).

A companion for controller-first menus, a joystick-driven cursor ring that clicks whatever is under it, is in `prebuilt/cursor/`; see [prebuilt/cursor/README.md](prebuilt/cursor/README.md).

Dialog windows (popups, toasts, dialogue box, narration) built on OmniButton ship in `prebuilt/dialog/`; see [prebuilt/dialog/README.md](prebuilt/dialog/README.md).

A title screen, pause menu and options screen (with saved player settings) built on the dialog windows ship in `prebuilt/menus/`; see [prebuilt/menus/README.md](prebuilt/menus/README.md).

Downloads from GitHub or the Asset Library leave out the `dev/` folders (`dev/` and each `prebuilt/*/dev/`: tests, benchmark, snapshot and the doc generator; see `.gitattributes` in the repository). They're only needed to develop the plugin.

Project Settings, autoloads and common problems across all the parts are listed in [GETTING_STARTED.md](GETTING_STARTED.md#project-settings).

API reference: in the Godot editor press F1 (Search Help) and type a class name (`OmniButton`, `OmniPopup`, `OmniDialogRunner`, ...), or Ctrl+click a name in the script editor.

Contents
- Signals
- Exported Properties (by group)
- Code organization
- Debugger Log
- Accessors (ergonomic helpers)
- Behavior notes and examples
- Troubleshooting

## Signals
- `pressed` — emitted on press when enable_pressed_actions is on.
- `released` — emitted on release when enable_released_actions is on.
- `toggled(pressed: bool)` — emitted when interaction_mode toggles on/off.
- `hover_in`, `hover_out` — emitted on pointer enter/exit when enable_hover_actions is on.
- `hold` — emitted once after the hold_duration build-up completes when enable_hold_actions is on.
- `swipe(direction: Vector2)` — emitted with a normalized direction during a swipe when enable_swipe_actions is on.
- `swipe_ended` — emitted when a swipe session ends.
- `joystick_started`, `joystick_axis(axis: Vector2)`, `joystick_ended` — virtual joystick lifecycle and axes.
- `log(message)`, `warning(message)`, `error(message)` — optional logging signals.
- `typewriter_completed` — emitted when typewriter text finishes (also when `skip_typewriter()` or `stop_typewriter()` ends it).
- `typewriter_char_revealed(index: int, character: String)` — emitted for each character the typewriter reveals, in order (useful for typing sounds). Characters passed over by a skip are not reported.

Connect signals with the standard GDScript syntax, for example `button.pressed.connect(_on_pressed)`.

Each event runs in this order: the signal is emitted (connected handlers run once), then the matching Action Callable runs if one is set (`pressed_action`, `released_action`, `hover_in_action`, `hover_out_action`, `toggled_action`, `hold_action`, `swipe_action`), otherwise the overridable `_run_built_in_*` hook. `print_log`, `print_warn`, and `print_err` work the same way: emit `Log`/`Warning`/`Error`, then run `log_action`/`warning_action`/`error_action`, or fall back to the default print, `push_warning`, or `push_error`.

## Code organization

```
omni_button/
├── plugin.cfg, omni_button_plugin.gd   the editor plugin (registers the node, settings, autoload)
├── omni_button.gd                       OmniButton, the node you use
├── core/                                what the button is made of (you don't need to open these)
│   ├── omni_button_*.gd                 helper modules, described below
│   └── shader/                          the invert-on-state shader
├── demo/                                omni_button_demo.tscn, the button demo (project main scene)
├── prebuilt/buttons/                    ready-made buttons (presets), with their own README
├── prebuilt/cursor/                     controller cursor for menus (a companion), with its own README
├── prebuilt/dialog/                     the dialog system, with its own README
├── prebuilt/menus/                      title, pause and options menus + player settings, with their own README
└── dev/                                 tests and tools, left out of downloads
```

`omni_button.gd` is the scene-facing Control. It owns every exported property, all runtime state, and the public API. The file is split into foldable `#region` blocks: constants, signals and enums; one Settings region per Inspector category, in Inspector order, with each setting's private backing variable directly above it; runtime state grouped by feature; scripting accessors; lifecycle; public API; overridable hooks; and internal methods.

Most modules in `core/` are stateless: they contain only static functions that take the button as their first argument, so a button allocates no helper objects for them. The button and other modules call these functions directly (for example `OmniButtonTiming.start_cooldown(button)`), rather than through wrapper methods on the button. A leading underscore marks a function that is used only inside its own file; functions without one are called from other files. The button keeps a method only when it is part of the public API, an engine callback, an overridable hook, or a `call_deferred` target, or when it adds a check, such as skipping work before `_ready`.
- `omni_button_accessors.gd` — the `label`, `icon`, `background`, ... accessor classes (see **Accessors**).
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
| `hover_scale` > 0 | `hover_lerp_speed` |
| `follow_mode` = `FOLLOW_BOTH` or `VIRTUAL_JOYSTICK` | `clamp_to_bounds` |
| `follow_mode` = `VIRTUAL_JOYSTICK` | Virtual Joystick settings, plus the Area and Thumb switches |
| `enable_joystick_area` / `enable_default_thumb` | Area / Thumb settings |
| `icon_texture` set | Icon expand, stretch, flips, and modulate |
| `hold_duration` > 0 | Hold fill color and direction |
| Swipe action checkbox | Swipe threshold and init/exit modes |
| `cooldown_trigger` ≠ `NONE` | Cooldown settings (`cooldown_invert_duration` also needs `invert_on_cooldown`; the hover and hold options also need hover scaling or hold build-up) |
| `label_type` / `background_type` | The matching Text, Label, RichTextLabel, Extra, Panel, or TextureRect sections |

### Initial OmniButton section
- Actions — individual checkboxes labeled Press, Release, Hover, Toggle, Hold, Swipe, Log, Warning, and Error. Their script property names are `enable_..._actions`. Connecting a matching signal handler automatically enables its checkbox once.
- background_type — `NONE` | `USE_PANEL` | `USE_TEXTURE`. Selects which background child is active and which background Inspector section is shown.
- label_type — None | Label | RichTextLabel. None hides the Text, Label, RichTextLabel, and Extra categories and creates no label; setting non-empty Text in code selects Label automatically.
- Disabled — Blocks input and visual reactions, switches to `panel_disabled_style_box`, and fades the text and icon by `disabled_modulate` (white turns the fade off).
- Visual Effects — invert_modes, Hover → Scale and Lerp Speed, and selected_color. Scale is the size while hovered (1.2 = 120%); it defaults to 0, which turns hover scaling off.
- Input & Motion — activation_action, output_action (an InputMap action held down while the button is pressed, like `TouchScreenButton`'s action), then Hit Area (bounds_source, hit_slop), then Drag & virtual joystick, where `follow_mode` is the single switch for drag and joystick behavior.
- Actions is the first section in the built-in OmniButton Inspector category.

### Button
- icon_texture renders as a full-size layer behind the full-size text node.
- Icon properties use concise Inspector labels: Texture, Expand, Stretch, Flip H, Flip V, and Modulate. Expand and Stretch retain the named TextureRect choices.
- Hold Build-Up — Duration, Fill Color, Fill Direction. A duration greater than zero enables hold build-up; zero disables it.
- Swipe — Threshold, Touch Init/Exit, Mouse Init/Exit.
- Toggle Behavior — interaction_mode.
- Cooldown — Trigger (None disables cooldown; `ON_PRESS`, `ON_RELEASE` or `ON_PRESS_AND_RELEASE` enables it), Start Delay, Duration, Start Filled, Color, Fill Direction, and hold/hover behavior. With a `StyleBoxFlat` panel, the cooldown and hold fills follow its rounded corners.

### Text
- Text content is followed by the plain-label options Uppercase, Clip, and Overrun in the base section.
- Typography labels are shortened to Font, Color, Modulate, Horizontal, Vertical, and Autowrap. These settings apply to the selected Label or RichTextLabel where supported.

### RichTextLabel
- Shown only when label_type is RichTextLabel: BBCode, fit-content, scrolling, selection, and context-menu options. `rich_label_use_bbcode` must be on for markup to be interpreted.

### Extra
- OmniButton-specific text options shown when either text type is selected: autosizing and padding, plus typewriter properties and methods.
- enable_text_auto_size, fixed_font_size, min_font_size, max_font_size, text_fit_padding, and label_padding.
- Additional Padding subgroup: Left, Top, Right, and Bottom.
- Typewriter: text_to_type, delay_effect_tags_during_typewriter, suspend_hover_during_typewriter, finish_typewriter_on_press, and the Start/Skip/Stop methods.

### Panel
- panel_theme_variation, panel_style_box, panel_hover_style_box, panel_pressed_style_box, panel_disabled_style_box, panel_focus_style_box, panel_modulate.
- State-specific styles fall back to panel_style_box when unset.

### TextureRect
- texture, expand_mode, stretch_mode, flip_h, flip_v, background_modulate. The first five use the same names as on a TextureRect.

### Input / Follow / Virtual Joystick
- Hit Area: bounds_source, hit_slop. These apply to every button: they set the rectangle used to decide whether a release counts as inside. Drag and joystick movement are also clamped to `bounds_source`.
- follow_mode — `NONE` | `FOLLOW_BOTH` | `VIRTUAL_JOYSTICK`. This is the one switch for drag and joystick behavior. `enable_virtual_joystick` remains as script shorthand for `follow_mode == VIRTUAL_JOYSTICK`; it is no longer shown in the Inspector or saved, and scenes saved with it still load as joysticks.
- clamp_to_bounds (`FOLLOW_BOTH` and `VIRTUAL_JOYSTICK`)
- clamp_shape — Circle | Rectangle
- joystick_radius_px, joystick_rect_size_px, joystick_deadzone, joystick_snap_to_input
- joystick_hide_when_inactive, joystick_reset_on_release
- enable_joystick_area, joystick_area_persistent/Color/Thickness, joystick_area_use_rect_for_clamp
- enable_default_thumb, default_thumb_size_ratio, default_thumb_color

### Composition
- managed_draw_on_top controls whether OmniButton's internal `_Managed` layer is drawn above or below the control's other direct children. Keep decorative/user-added children as siblings of `_Managed`; set this false to draw those children over OmniButton's generated visuals.

### Debug
- State subgroup: Selected, is_toggled, is_pressed, is_hovering, and is_holding expose live state and are mainly useful for debugging or programmatic control.
- Logging subgroup: debugger_log — `Off` (default) or `Basic`. When set to `Basic`, OmniButton prints a detailed per-button trace to the Godot output console covering autosize decisions, hover/toggle transitions, swipe and joystick events, cooldown/hold/typewriter lifecycles, etc. Use this to diagnose a single button without spamming the whole UI.

### Typewriter
- text_to_type, delay_effect_tags_during_typewriter, suspend_hover_during_typewriter, finish_typewriter_on_press
- `start_typewriter(final_text, cps, by_word, preserve_bbcode_tags)`, `skip_typewriter()`, `stop_typewriter()`. Setting `preserve_bbcode_tags` to true selects RichTextLabel when needed; set `rich_label_use_bbcode` to true to render markup.
- Inline timing tags, understood only by the typewriter and removed before the text reaches the label (they work with and without BBCode):
  - `[pause=0.5]` — wait 0.5 seconds once the reveal reaches this point. Skipping during a pause finishes the reveal immediately.
  - `[speed=12]` — reveal 12 characters (or words, in word mode) per second from here.
  - `[/speed]` — return to the speed passed to `start_typewriter`.
  - Example: `start_typewriter("Wait...[pause=0.8] [speed=8]really?[/speed] Fine.", 40.0)`.
  - Setting `text` directly (without the typewriter) does not interpret these tags.

## Accessors
- `label`, `icon`, `background`, `panel`, `overlay`, `cooldown`, and `charge_up` group related settings under short names. Each accessor and each of its properties is typed, so autocomplete and type checking work through them (`var d := button.cooldown.duration` is a `float`). An accessor is created the first time a script uses it.
- Examples:
  ```gdscript
  button.label.text = "Hello"
  button.icon.tex = load("res://icon.png")
  button.background.mode = OmniButton.BackgroundMode.USE_TEXTURE
  button.panel.theme_variation = "warning"
  button.cooldown.trigger = OmniButton.CooldownTrigger.ON_PRESS
  button.charge_up.duration = 1.0
  ```

## Behavior notes
- **Scenes from older versions:** settings used to be PascalCase (`HoldDuration`, `RichLabelUseBBCode`) and the class was `Omni_Button`. Scenes saved with the old setting names still load: each old name is mapped onto its snake_case version, and the scene is written with the new names the next time it's saved. Scripts that use the old names need updating by hand.
- **Actions auto-enable once:** When a handler is connected to a signal before the button is ready (in the editor, or in code before `add_child`), the matching action checkbox turns on. If you disable it later, it remains off. For handlers connected later in code, turn the checkbox on yourself.
- **Per-button debugger:** Flip `debugger_log` to `Basic` for any instance to print a trace of autosize decisions, pressed/hover/toggle transitions, swipe + joystick events, hold/cooldown/typewriter lifecycle, and signal emissions. This is invaluable for diagnosing a single button without spamming other buttons.
- **Text autosizing parity:** The autosizer now uses Godot’s TextParagraph pipeline and re-runs whenever wrap/padding/text changes. Cached font sizes are invalidated automatically and a secondary search “grows” the font back up when more room becomes available. If text still overflows, enable the debugger log to inspect measurements vs available space.
- **Hold build-up:** When `hold_duration` is greater than zero, OmniButton draws a hold fill and animates it according to `hold_fill_direction`. The `hold` signal fires once the timer reaches `hold_duration`.
- **Cooldown:** `cooldown_trigger = NONE` disables cooldown. Choose `ON_PRESS`, `ON_RELEASE` or `ON_PRESS_AND_RELEASE` to enable it; no separate enable switch is needed.
- **Swipe handling:** Swipes respect per-device init/exit settings, the Swipe action checkbox, thresholds, and `hit_slop`. Runtime logs show whether the action is disabled or the pointer left bounds.
- **Follow / Virtual joystick:** `follow_mode` controls whether the button drags, stays put, or becomes a joystick. Joystick sessions clamp to circular/rectangular regions, emit axis values/started/ended signals, and optionally show a ring (`enable_joystick_area`). The debugger logs start/stop events and clamp info.
- **Cooldowns:** Any triggerable cooldown automatically clears pressed visuals, can optionally suspend hover scale, and emits debugger logs when starting or finishing. You can hide the overlay during hold build-up for “charge + cooldown” combos.
- **Typewriter text:** `start_typewriter()` respects BBCode, word mode, and CPS, and can defer effect tags. Skip/Stop log when they emit `typewriter_completed` so you can tell if a script cancelled unexpectedly.
- **Runtime/editor parity:** In the editor, buttons refresh when an edit is made (the plugin listens for undo/redo history changes and scene switches) instead of polling every frame, and then run the same rebuild and autosize code as at runtime.
- **Processing / idle:** At runtime, `_process` calls `set_process(false)` when nothing needs per-frame work (no pending refresh, refit frames, typewriter, cooldown delay or active cooldown, hold build-up while pressed, and hover scaling is off). Hover scaling keeps processing on only while the scale is still animating. Idle buttons do no per-frame work, and they also receive `_unhandled_input` only while focused with an activation action or in the middle of a gesture.
- **Mouse + touch together:** With `ProjectSettings` → `input_devices/pointing/emulate_mouse_from_touch` on, one touch can produce both screen-touch and mouse-button events. `PointerGestureSource` records which input **first** started the press; the other is ignored until the session ends, avoiding double press/release.
- **Multi-touch drags:** `InputEventScreenDrag` is honored only when `index` matches `_active_touch_index` for a native touch press; mouse sessions accept all drags.
- **Cooldown vs. in-flight press:** While cooldown is active, new presses are blocked, but `_gui_input` still runs if `_is_pressed` so drag/release can finish.
- **Unhandled cleanup:** After off-control reset, `get_viewport().set_input_as_handled()` is called.
- **Hover target:** The hover scale is capped so the button stays inside the viewport. The cap is recalculated when the pointer enters and when the button is resized while hovered.
- **Typewriter + text:** Changing text or label type during a typewriter keeps the generated label synchronized with the currently revealed text; visual refreshes preserve the partial output.
- **Inside containers:** OmniButton does not report a minimum size from its text (its text autosizes to whatever size it is given), so set `custom_minimum_size` on buttons placed in a VBoxContainer/HBoxContainer, or they collapse to zero height.
- **Focus:** buttons default to `focus_mode = FOCUS_NONE` like any Control. Set it to `FOCUS_ALL` for keyboard/gamepad navigation; a focused button uses `panel_focus_style_box` and activates on `activation_action`.
- **Focused input actions:** `activation_action` names a Godot InputMap action (defaults to `ui_accept`). The focused button responds to mapped keyboard or gamepad press/release events; player remapping is handled through InputMap. When `finish_typewriter_on_press` is on, the action first skips active typewriter text. Joystick/follow modes skip focused activation.

## Troubleshooting
- Swipe not firing: enable the Swipe action checkbox and move beyond swipe_threshold.
- No hover zoom: set hover_scale to a value greater than zero (hover signals are independent).
- Draggable vs stationary: `follow_mode = FOLLOW_BOTH` (drag), `follow_mode = NONE` (stationary).
