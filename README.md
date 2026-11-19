# OmniButton for Godot 4

OmniButton is a GDScript `Control` plugin for configurable button and virtual-joystick behavior. It supports press/release/toggle, hover scaling, state effects, swipe, hold build-up, cooldowns, text and typewriter effects, and optional panel or texture backgrounds.

## Project layout

- `addons/omni_button/` — GDScript plugin and its full reference.
- `addons/omni_button/test/GodotTest.tscn` — interactive demo scene and examples.

## Install

Copy `addons/omni_button` into your Godot project's `addons/` directory, then enable **Godot-OmniButton** under **Project → Project Settings → Plugins**.

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

Run the project or open `res://addons/omni_button/test/GodotTest.tscn` to explore the included GDScript examples.

## Validation

Run the headless behavior checks with:

```powershell
godot --headless --path . --script res://addons/omni_button/test/OmniButtonValidation.gd
```

The checks cover input/state cleanup, missing joystick-area and freed-bounds fallbacks, and a 500-control idle-processing stress case. The printed setup time is a local smoke-test measurement, not a cross-device performance guarantee; use Godot's profiler with your actual HUD and target hardware for final budgets.

## Compatibility

Godot 4.x with GDScript.

## License

MIT. See [LICENSE](LICENSE).
