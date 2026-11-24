# Virtual cursor

*Part of OmniButton. New to the plugin? Start with [Getting started](../../GETTING_STARTED.md).*

`omni_virtual_cursor.tscn` is a controller cursor for menus: a ring moved by a joystick that clicks whatever is under it, like the menus in Destiny or The First Descendant.

It's a companion to OmniButton rather than part of it. It isn't made of OmniButtons; it works *with* them, and with any other Control. Menus built from OmniButtons (for example the [button presets](../buttons/README.md)) are what it's made for.

To try it, open `demo/omni_cursor_demo.tscn`, press F6, plug in a controller and move the left stick.

## Using it

Drag `omni_virtual_cursor.tscn` into a menu scene. That's all: it draws above everything (it is a `CanvasLayer` on layer 100) and only exists while that scene is open. To turn it on and off from code, set `active`.

```gdscript
func _ready() -> void:
	$OmniVirtualCursor.clicked.connect(func(at: Vector2): $ClickSound.play())

func open_menu() -> void:
	$OmniVirtualCursor.active = true
```

## How it behaves

- **It drives the mouse.** Moving the ring sends Godot ordinary mouse motion, and clicking sends a left click at its center, so everything under it reacts as it would to a mouse: OmniButtons show their hover look and scale, and Godot's own `Button`s, sliders and scroll containers work too. Hold the click to hold it (hold-to-confirm buttons and slider drags work).
- **Only the stick moves it.** It appears when the stick (left by default) moves. The d-pad keeps its normal job: pressing it (or the arrow keys) hides the ring and goes back to focus navigation. Moving the real mouse or touching the screen hides it too, so only one pointer is ever active.
- **Clicking.** The controller's A button clicks under the ring (`click_button`), and so do Enter / Space (`click_action`, `ui_accept`). Showing the ring releases keyboard / gamepad focus, so a click never also presses the focused button.
- **Sticky buttons.** Over anything clickable the ring slows down (`hover_slowdown`) and is pulled toward its center (`snap_strength`, 0 = off). The pull eases off while the stick is pushed, so it never fights the player.
- **The other stick scrolls** whatever is under the ring (`scroll_speed`, 0 = off).
- **Same feel at any resolution.** `speed` is in screen heights per second, and `ring_size` is a fraction of the screen height.

Settings worth knowing: `active`, `stick`, `device` (-1 = any controller), `dead_zone`, `response_curve` (higher = finer control near the middle of the stick), `click_button`, `click_action`, `hide_mouse_pointer`.

Signals: `shown`, `hidden`, `clicked(position)`.

**Gamepad focus navigation.** Godot's `ui_accept` has Enter and Space but no controller button, so after the d-pad moves focus, A can't press the focused button. Add **Joypad Button 0** (A) to `ui_accept` in **Project Settings > Input Map**. (The ring's own clicks don't need this.)

## Changing the look

The ring is drawn by a shader (`core/omni_cursor_ring.gdshader`): bright along its middle and fading to transparent on both sides, like a glowing tube.

- Tune it on the `Ring` node's material: `radius`, `thickness`, `sharpness`.
- Change `ring_color` and `hover_color` (over something clickable) on the cursor.
- Set `ring_texture` to use your own picture instead, tinted by the same colors.
- For anything more, turn on **Editable Children** and change the `Ring` node.

## Controller not detected?

Steam controllers (Steam Deck, Steam Controller) are taken over by Steam Input while Steam is running, and only games launched from Steam see them as a gamepad. When testing from the Godot editor, add Godot as a non-Steam game and start it from Steam (or quit Steam). Games you ship on Steam get Steam Input automatically. The demo shows which controllers Godot sees.

## Folders

```
cursor/
├── omni_virtual_cursor.tscn   the cursor
├── core/                      OmniVirtualCursor script and the ring shader
├── demo/                      omni_cursor_demo.tscn (uses a few button presets for its menu)
└── dev/                       automated tests (left out of downloads)
```
