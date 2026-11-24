# OmniButton for Godot 4

OmniButton is a GDScript `Control` plugin for configurable button and virtual-joystick behavior. It supports press/release/toggle, hover scaling, state effects, swipe, hold build-up, cooldowns, text and typewriter effects, and optional panel or texture backgrounds.

It also ships a dialog system built from OmniButtons: popups (alert, confirm, choice), toasts, an RPG dialogue box and full-screen narration, usable from code through the optional `OmniDialog` autoload or as scenes dropped into your own. Conversations can be written in JSON files. See [the dialog README](addons/omni_button/prebuilt/dialog/README.md).

For a quick start, `prebuilt/buttons/` has ready-made buttons to drag into a scene: menu, toggle, icon, item, hold-to-confirm and cooldown buttons, touch controls (joystick, floating joystick, swipe pad, action button), a typewriter title, an invert-flash button and a tab bar. See [the presets README](addons/omni_button/prebuilt/buttons/README.md).

`prebuilt/menus/` has a title screen, a pause menu and an options screen with saved player settings (volume, window mode, text speed, plus your own). See [the menus README](addons/omni_button/prebuilt/menus/README.md).

A companion in `prebuilt/cursor/` adds a controller cursor for menus: a joystick-driven ring that clicks whatever is under it. See [the cursor README](addons/omni_button/prebuilt/cursor/README.md).

## Project layout

- `addons/omni_button/` — the plugin and its full reference.
- `addons/omni_button/demo/omni_button_demo.tscn` — button demo scene and examples (the project's main scene).
- `addons/omni_button/prebuilt/buttons/` — ready-made buttons; their demo is `demo/omni_button_presets_demo.tscn`.
- `addons/omni_button/prebuilt/menus/` — title, pause and options menus; its demo is `demo/omni_menus_demo.tscn`.
- `addons/omni_button/prebuilt/cursor/` — controller cursor for menus; its demo is `demo/omni_cursor_demo.tscn`.
- `addons/omni_button/prebuilt/dialog/` — the dialog system; its demo is `demo/omni_dialog_demo.tscn`.
- `addons/omni_button/dev/` and each `prebuilt/*/dev/` — tests and tools, left out of downloads.

## Install

Copy `addons/omni_button` into your Godot project's `addons/` directory, then enable **OmniButton** under **Project → Project Settings → Plugins**.

## Quick start

Add an `Omni_Button` node from the **Create Node** dialog, connect its `pressed` signal, and enable the matching action checkbox in the Inspector.

```gdscript
extends Control

func _ready() -> void:
    $OmniButton.pressed.connect(_on_omni_button_pressed)

func _on_omni_button_pressed() -> void:
    print("Pressed")
```

For Inspector sections, signals, accessors, behavior details, and troubleshooting, see the [GDScript reference](addons/omni_button/README.md).

## Demo

Run the project or open `res://addons/omni_button/demo/omni_button_demo.tscn` to explore the button examples. For the ready-made buttons, open `res://addons/omni_button/prebuilt/buttons/demo/omni_button_presets_demo.tscn`, and for the dialog windows `res://addons/omni_button/prebuilt/dialog/demo/omni_dialog_demo.tscn`; press F6.

## Validation

Run the headless behavior checks with:

```powershell
godot --headless --path . --script res://addons/omni_button/dev/OmniButtonValidation.gd
```

The dialog system's checks are in `addons/omni_button/prebuilt/dialog/dev/` (one script per part: overlay, popup, dialogue, look, data files), the presets' in `addons/omni_button/prebuilt/buttons/dev/OmniButtonPresetsValidation.gd`, the cursor's in `addons/omni_button/prebuilt/cursor/dev/OmniVirtualCursorValidation.gd`, and the menus' in `addons/omni_button/prebuilt/menus/dev/OmniMenusValidation.gd`, run the same way.

The checks cover input/state cleanup, missing joystick-area and freed-bounds fallbacks, and a 500-control idle-processing stress case. The printed setup time is a local smoke-test measurement, not a cross-device performance guarantee; use Godot's profiler with your actual HUD and target hardware for final budgets.

## Compatibility

Godot 4.x with GDScript.

## License

MIT. See [LICENSE](LICENSE).
