# OmniButton for Godot 4

OmniButton is a Godot 4 plugin, in GDScript, for game UI: one button node that handles mouse, touch, keyboard and gamepad, plus ready-made pieces built from it.

| Part | What it gives you |
|---|---|
| **OmniButton** | Press, release, toggle, hover scaling, hold build-up, swipe, cooldowns, typewriter text and a virtual joystick, all set up in the Inspector. |
| **Button presets** | Drag-and-drop buttons: menu, toggle, icon, item, hold-to-confirm, cooldown, joysticks, swipe pad, action button, typewriter title, tab bar. |
| **Dialog windows** | Popups, toasts, an RPG dialogue box and narration, from one line of code (`await OmniDialog.say(...)`), with conversations in JSON files. |
| **Menus** | Title screen, pause menu and options screen with saved player settings, in a panel style and a full-screen stylized style. |
| **Controller cursor** | A joystick-driven ring that clicks whatever is under it, for controller-first menus. |
| **Looks** | One file styles every dialog window and menu. Modern, Retro and Bold ship. |

**New here? Start with [Getting started](addons/omni_button/GETTING_STARTED.md):** install, a tour of the demos, a "which piece do I need" table, and a fifteen-minute walkthrough that builds a title screen, a level with a pause menu, dialogue, touch and controller input.

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

The [Getting started guide](addons/omni_button/GETTING_STARTED.md) covers every part. The smallest possible start: add an `OmniButton` node from the **Create Node** dialog, connect its `pressed` signal, and enable the matching action checkbox in the Inspector.

```gdscript
extends Control

func _ready() -> void:
    $OmniButton.pressed.connect(_on_omni_button_pressed)

func _on_omni_button_pressed() -> void:
    print("Pressed")
```

For Inspector sections, signals, accessors, behavior details, and troubleshooting, see the [GDScript reference](addons/omni_button/README.md).

## Demos

Open one and press F6. Running the project (F5) opens the first.

| Demo | Shows |
|---|---|
| `addons/omni_button/demo/omni_button_demo.tscn` | Every OmniButton feature |
| `addons/omni_button/prebuilt/buttons/demo/omni_button_presets_demo.tscn` | All the presets, with the code each needs |
| `addons/omni_button/prebuilt/dialog/demo/omni_dialog_demo.tscn` | Popups, toasts, dialogue, narration, a JSON story, the looks |
| `addons/omni_button/prebuilt/menus/demo/omni_menus_demo.tscn` | A tiny game: title, pause, options, both menu styles |
| `addons/omni_button/prebuilt/cursor/demo/omni_cursor_demo.tscn` | The controller cursor (plug in a controller) |

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
