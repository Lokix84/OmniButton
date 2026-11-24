# Button presets

*Part of OmniButton. New to the plugin? Start with [Getting started](../../GETTING_STARTED.md).*

Ready-made `OmniButton`s for the jobs most games need. Each preset is one scene with its settings already filled in: drag it into your scene, change its text or icon, and connect its signal.

To see them all, open `demo/omni_button_presets_demo.tscn` and press F6. The **Buttons**, **Touch controls** and **More** tabs at the top switch pages (they are an `omni_tab_bar.tscn` themselves). Every control logs its signal, and the demo's script shows the code each one needs.

## Buttons

| Scene (in `presets/`) | Use it for | Signal to connect | Settings that make it work |
|---|---|---|---|
| `omni_menu_button.tscn` | Main menus, dialogs, any text button | `pressed` | `enable_pressed_actions`, `hover_scale` 1.05 |
| `omni_toggle_button.tscn` | On/off options: music, fullscreen, subtitles | `toggled(on)` | `interaction_mode` Toggle On Press, `enable_toggle_actions` |
| `omni_icon_button.tscn` | Pause, close, settings: an icon with no text | `pressed` | `icon_texture`, `label_type` None, a tooltip |
| `omni_item_button.tscn` | Inventory slots, shop items, hotbars | `pressed` | `icon_texture`, `text` at the bottom (`label_vertical_alignment` Bottom) |
| `omni_hold_button.tscn` | Actions that need a "are you sure?": quit, delete save, skip | `hold` | `hold_duration` 1 s, `enable_hold_actions` (and **not** `enable_pressed_actions`) |
| `omni_cooldown_button.tscn` | Abilities and skills | `pressed` | `cooldown_trigger` On Press, `cooldown_duration` 3 s |

How each one behaves:

- **Every preset:** grows a little on hover, gets a gold border when it has keyboard or gamepad focus, turns blue while pressed, and fades when `disabled` is on: the panel switches to the disabled style, and the text and icon fade by `disabled_modulate`. Enter / Space (the `ui_accept` action) presses the focused button. Godot's `ui_accept` has no controller button, so for gamepads add one (usually A, "Joypad Button 0") to `ui_accept` in **Project Settings > Input Map**.
- **Toggle:** stays blue while on. Its text doesn't change by itself, so update it in your handler (see the example below).
- **Hold:** fills from left to right while held. Letting go early does nothing; `hold` fires once when the fill completes.
- **Cooldown:** after a press it darkens, and the dark part drains over `cooldown_duration`. Presses during the cooldown are ignored.
- **Icon and item:** the pixel-art icons use nearest filtering (`texture_filter` Nearest), so they stay crisp when scaled up. Set it back to Inherit for smooth icons.

## Touch controls

For phones and tablets. They work with the mouse too, so you can test them on your computer. Each one tracks its own finger, so a player can steer with one thumb and press buttons with the other.

| Scene (in `presets/`) | Use it for | Read it with |
|---|---|---|
| `omni_joystick.tscn` | Movement, aiming: a stick that stays where you put it | `axis`, `axis_changed(axis)`, or Input actions |
| `omni_floating_joystick.tscn` | Movement in mobile games: the stick appears where the thumb lands | same as above |
| `omni_swipe_pad.tscn` | Dashes, dodges, card swipes, swipe menus | `swiped(direction)` |
| `omni_action_button.tscn` | Jump, attack, interact: a big round button for thumbs | `pressed` / `released`, or `output_action` |

How each one behaves:

- **Joystick:** touch anywhere on the ring and drag. The thumb follows your finger up to the ring's edge, and `axis` goes from -1 to 1 on each axis (up is negative y, like Godot's `Input.get_vector`). A small dead zone in the middle reads as zero. Letting go snaps the thumb back and `axis` to zero. Resize the node to resize the ring.
- **Floating joystick:** the node is a touch zone. Size and anchor it to cover the area the player's thumb rests on, usually the left half of the screen. The ring appears under the finger and hides when it lifts.
- **Swipe pad:** sends `swiped` once per swipe, as soon as the finger has moved `swipe_threshold` pixels (40), snapped to `Vector2.LEFT`, `RIGHT`, `UP` or `DOWN`. Turn off `four_way` for the exact direction.
- **Action button:** round, with no hover effect. Set `output_action` to an InputMap action and the button holds that action down while pressed, the same as a key would.

### Hooking them up to your game

The easiest way is through Godot's **Input Map**, so the same game code works with keyboard, gamepad and touch:

1. In **Project Settings > Input Map**, add the actions your game uses (for example `move_left`, `move_right`, `move_up`, `move_down`, `jump`) and give them keys and gamepad buttons as usual.
2. On a joystick, set **Input Actions > Action Left / Right / Up / Down** to those actions. On an action button, set **Output Action** (under **Input & Motion**) to `jump`.
3. Your movement code doesn't change:

```gdscript
func _physics_process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * speed
	if Input.is_action_just_pressed("jump"):
		jump()
	move_and_slide()
```

Or read them directly:

```gdscript
func _ready() -> void:
	$OmniJoystick.axis_changed.connect(func(axis: Vector2): aim_direction = axis)
	$OmniSwipePad.swiped.connect(_on_swiped)

func _process(delta: float) -> void:
	position += $OmniJoystick.axis * speed * delta

func _on_swiped(direction: Vector2) -> void:
	if direction == Vector2.LEFT:
		dodge_left()
```

**Tips:**
- **Show touch controls only on touch screens:** `visible = DisplayServer.is_touchscreen_available()`.
- **Place them on screen corners:** put them in a `CanvasLayer` so the camera doesn't move them, and anchor them (joystick bottom-left, buttons bottom-right).
- **Change the joystick's feel** on its `Thumb` child (an `OmniButton`): `joystick_deadzone` (0.15), `joystick_radius_px` (0 = up to the ring's edge), `clamp_shape`.

## More

| Scene (in `presets/`) | Use it for | Signal to connect |
|---|---|---|
| `omni_typewriter_button.tscn` | Title screens ("Press Start"), intros, prompts | `pressed`, `typewriter_completed` |
| `omni_invert_button.tscn` | A retro look: the colors flip while pressed | `pressed` |
| `omni_tab_bar.tscn` | Tabs, category filters, "pick one" choices | `tab_changed(index)` |
| `omni_tab_button.tscn` | One tab, for adding to a tab bar | (use the tab bar's signal) |

How each one behaves:

- **Typewriter:** types its `text` when the scene starts (`autoplay`, `characters_per_second`, `start_delay`), then pulses (`blink_when_done`). While it is still typing, the first press only shows the rest of the text and doesn't count as a press, so an impatient player doesn't skip the title screen. Call `play()` to type it again.
- **Invert flash:** `invert_modes` is set to Press, so the panel, text and icon flip to their opposite colors while held. Works with any style; the preset uses a square black-and-white one. Add Hover or Toggle in `invert_modes` to flip in those states too.
- **Tab bar:** an `HBoxContainer` whose `OmniButton` children are the tabs, in order. Exactly one is on (it uses the pressed style); clicking the one that's on keeps it on. Add a tab by duplicating one (Ctrl+D) and changing its text. To switch pages with no code, set **Pages** to a container whose children are the pages: only the child with the current tab's index is shown. Set `current_tab` from code to switch.

```gdscript
func _ready() -> void:
	$OmniTabBar.tab_changed.connect(func(index: int): print("Tab ", index))
	$OmniTabBar.current_tab = 1
```

To edit the three tabs of a dropped-in tab bar, right-click it in the Scene dock and turn on **Editable Children**.

## Controller cursor

For controller-first menus there's a companion: a joystick-driven ring that clicks whatever is under it. It works with these presets (and any Control), and lives in its own folder: see [`../cursor/README.md`](../cursor/README.md).

## Using a preset

1. In the FileSystem dock, drag a scene from `presets/` into your scene (or use **Instantiate Child Scene**).
2. In the Inspector, change `text`, or `icon_texture` for the icon, item and cooldown buttons. Resize it in the 2D view or with `custom_minimum_size`. The joysticks aren't single buttons: their settings are on the root node (`floating`, Input actions) and the `Thumb` child.
3. Connect its signal, in the **Node** dock or from code:

```gdscript
func _ready() -> void:
	$StartButton.pressed.connect(_on_start)
	$MusicButton.toggled.connect(_on_music_toggled)
	$QuitButton.hold.connect(get_tree().quit)

func _on_music_toggled(on: bool) -> void:
	$MusicButton.text = "Music: On" if on else "Music: Off"
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Music"), not on)
```

Settings you change on a dropped-in button only affect that button. The preset scene stays as it was.

## Changing the look

The presets share the styles in `styles/`:

| File | State |
|---|---|
| `button_normal.tres` | Idle |
| `button_hover.tres` | Under the mouse |
| `button_pressed.tres` | Pressed, and toggled on |
| `button_focus.tres` | Has keyboard / gamepad focus |
| `button_disabled.tres` | `disabled` is on |
| `round_normal.tres`, `round_pressed.tres` | Joystick thumbs and action buttons |
| `joystick_ring.tres` | The joystick ring |
| `retro_normal.tres`, `retro_focus.tres` | The invert flash button |

- **Restyle every preset at once:** edit these files. Make a copy of the `styles/` folder first if you might update the plugin, since an update replaces them.
- **Restyle one button:** in its Inspector, open the style under **Panel** and choose **Make Unique** before editing it. Otherwise you edit the shared file and every preset changes.
- **Rounded corners:** the cooldown and hold fills follow the corners of `button_normal.tres`, so they stay inside rounded buttons.

## Making your own preset

1. Drag a preset into a new scene, or add an `OmniButton` node.
2. Change its settings in the Inspector. The button's [README](../../README.md) explains each group.
3. Save it as its own scene (right-click the node > **Save Branch as Scene**), and drag that scene wherever you need it.

## Folders

```
buttons/
├── presets/   the preset scenes
├── core/      scripts some presets use: OmniJoystick, OmniSwipePad, OmniTypewriterButton, OmniTabBar
├── styles/    the shared panel styles
├── icons/     settings, pause and close icons (SVG), and two pixel-art item icons
├── demo/      omni_button_presets_demo.tscn
└── dev/       automated tests (left out of downloads)
```
