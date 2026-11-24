# Getting started with OmniButton

This page gets you from "just installed it" to a working title screen, level, pause menu, dialogue and touch or controller input in about fifteen minutes. Each step links to the README with the full details.

## What's in the box

| Part | What it gives you | Try it (open, then F6) | Read |
|---|---|---|---|
| **OmniButton** | One button node for mouse, touch, keyboard and gamepad: press, toggle, hover scale, hold, swipe, cooldown, typewriter text, virtual joystick | `demo/omni_button_demo.tscn` | [README.md](README.md) |
| **Button presets** | Ready-made buttons to drag in: menu, toggle, icon, item, hold-to-confirm, cooldown, joysticks, swipe pad, action button, typewriter title, tab bar | `prebuilt/buttons/demo/omni_button_presets_demo.tscn` | [buttons README](prebuilt/buttons/README.md) |
| **Dialog windows** | Popups (alert, confirm, choice), toasts, an RPG dialogue box, full-screen narration, conversations written in JSON | `prebuilt/dialog/demo/omni_dialog_demo.tscn` | [dialog README](prebuilt/dialog/README.md) |
| **Menus** | Title screen, pause menu and options screen with saved player settings, in a panel style and a full-screen stylized style | `prebuilt/menus/demo/omni_menus_demo.tscn` | [menus README](prebuilt/menus/README.md) |
| **Controller cursor** | A ring on the joystick that clicks whatever is under it, for controller-first menus | `prebuilt/cursor/demo/omni_cursor_demo.tscn` | [cursor README](prebuilt/cursor/README.md) |
| **Looks** | One file that styles every dialog window and menu: Modern, Retro and Bold ship | (any dialog or menu demo: the **Look** button / Demo tab) | [looks README](prebuilt/dialog/themes/README.md) |

Every part is optional. Use only the buttons and the rest costs nothing.

## 1. Install

1. Copy the `addons/omni_button` folder into your project's `addons/` folder (make `addons/` if you don't have one).
2. Open **Project > Project Settings > Plugins** and tick **OmniButton**.

Enabling the plugin adds:

- the **OmniButton** node in the **Create Node** dialog;
- two autoloads, **OmniDialog** (show dialog windows from any script) and **OmniMenus** (loads and applies player settings at startup). Each can be turned off, see [Project Settings](#project-settings);
- an **omni_button** section in **Project Settings** (turn on **Advanced Settings** to see all of it);
- **Project > Tools > Check OmniButton dialog files**.

If the autoloads don't appear (for example after updating from an older version), untick the plugin and tick it again.

## 2. Look around the demos

Open each demo scene from the table above and press **F6** (Run Current Scene). Five minutes here shows you most of what's possible, and each demo's script is short, commented example code you can copy from.

## 3. Pick what you need

| I want to... | Use |
|---|---|
| Add a button that does something when clicked | `prebuilt/buttons/presets/omni_menu_button.tscn`, connect `pressed` |
| An on/off option | `omni_toggle_button.tscn`, connect `toggled(on)` |
| "Hold to confirm" for quit or delete | `omni_hold_button.tscn`, connect `hold` |
| An ability with a cooldown | `omni_cooldown_button.tscn` |
| Touch movement on phones | `omni_joystick.tscn` or `omni_floating_joystick.tscn`, set its Input actions |
| A jump / attack button on phones | `omni_action_button.tscn`, set **Output Action** |
| Tabs | `omni_tab_bar.tscn`, set **Pages** |
| A yes/no question | `await OmniDialog.confirm("Really quit?")` |
| A character talking | `await OmniDialog.say("Guard", "Halt!")` |
| A whole conversation with choices | a JSON file and `await OmniDialog.play(file, "entry")` |
| A short "Item saved" message | `OmniDialog.toast("Item saved")` |
| A title screen | `prebuilt/menus/screens/omni_title_menu.tscn` |
| Esc / Start pauses the game | drop `omni_pause_menu.tscn` into your level |
| Volume, fullscreen and text speed options | already in the options screen; add your own with `OmniSettings.define()` |
| Full-screen, high-energy menus | the `*_stylized.tscn` version of each menu |
| A mouse-like pointer on the controller stick | drop `prebuilt/cursor/omni_virtual_cursor.tscn` into the menu scene |
| My own button behavior | an `OmniButton` node, set up in the Inspector ([reference](README.md)) |
| My game's colors and fonts on every window | a look file ([looks README](prebuilt/dialog/themes/README.md)) |

## 4. Build a small game skeleton

This puts the pieces together: a title screen that starts a level, a level with a pause menu, a line of dialogue, and a setting of your own.

### Title scene

1. **Scene > New Scene**, pick **Other Node** and choose a plain `Node` as the root. Save it as `res://title.tscn`.
2. Drag `addons/omni_button/prebuilt/menus/screens/omni_title_menu.tscn` from the FileSystem dock onto the root.
3. Select it and set **Title** in the Inspector to your game's name.
4. Attach a script to the root:

```gdscript
extends Node

func _ready() -> void:
	$OmniTitleMenu.start_pressed.connect(func(): get_tree().change_scene_to_file("res://level.tscn"))
```

5. **Project > Project Settings > Application > Run > Main Scene**: pick `title.tscn`.

Options and Quit already work. Continue stays hidden until you set `$OmniTitleMenu.can_continue = true` (for example when a save file exists).

### Level scene

1. Make `res://level.tscn` with whatever root your game uses.
2. Drag `prebuilt/menus/screens/omni_pause_menu.tscn` into it, and set its **Title Scene** to `res://title.tscn`.

Press F5: Start goes to the level, Esc (or Start on a controller) pauses, and **Quit to title** asks first and goes back. Nodes that must keep running while paused need **Process > Mode > Always**; everything else stops, which is usually what you want.

### Dialogue

From any script, with no scene setup:

```gdscript
func _on_npc_talked_to() -> void:
	await OmniDialog.say("Guard", "Halt! Who goes there?")
	if await OmniDialog.confirm("Show your pass?"):
		OmniDialog.toast("The guard steps aside.")
```

Each call waits until the player has finished with the window, so the code reads in order. For longer conversations, write them in a JSON file: see [Dialog from JSON files](prebuilt/dialog/README.md#dialog-from-json-files).

### A setting of your own

Make an autoload of your own (**Project Settings > Globals > Autoload**) and define the setting there, once:

```gdscript
extends Node

func _ready() -> void:
	OmniSettings.define("gameplay/screen_shake", true, {"page": "Gameplay", "label": "Screen shake"})
```

It shows up on the options screen as an On / Off row, is saved with the other settings, and you read it anywhere with `OmniSettings.get_value("gameplay/screen_shake")`. Name your audio buses **Music** and **SFX** (Audio panel at the bottom of the editor) and the built-in volume sliders control them.

### Controllers

Godot's `ui_accept` action has Enter and Space but no controller button. Add one so A presses the focused button: **Project Settings > Input Map > ui_accept > +**, then press A on your controller (or add **Joypad Button 0**). The menus and dialogs already handle the d-pad, B (cancel) and Start (pause).

Optional: drop `prebuilt/cursor/omni_virtual_cursor.tscn` into a menu scene for a stick-driven pointer.

### Touch

1. Add a `CanvasLayer` to the level so the controls stay put when the camera moves.
2. Drag `omni_joystick.tscn` (bottom-left) and `omni_action_button.tscn` (bottom-right) into it, and anchor them to those corners.
3. On the joystick set **Action Left / Right / Up / Down** to your movement actions, and on the action button set **Output Action** to `jump`. Your existing `Input.get_vector(...)` and `Input.is_action_pressed("jump")` code now works with touch too.
4. Show them only on touch screens: `$CanvasLayer.visible = DisplayServer.is_touchscreen_available()`.

### Make it look like your game

1. Duplicate `prebuilt/dialog/themes/omni_dialog_modern.tres` to somewhere in your project.
2. Point **Project Settings > omni_button/dialog/theme** at your copy.
3. Edit its colors, fonts and styles. Every dialog window and menu follows it.

The [looks README](prebuilt/dialog/themes/README.md) lists what a look must contain and how to preview changes live.

## 5. Your own button from scratch

When no preset fits:

1. Add an **OmniButton** node (Create Node dialog, search "Omni").
2. In the Inspector, under **Actions**, tick the events you want (Press, Release, Hold, Swipe...).
3. Choose **Label Type** (Label for plain text) and type the **Text**. Choose **Background Type** (Use Panel) and give it a **Panel Style Box**.
4. Turn on the features you want: **Hover > Scale** (for example 1.05), **Hold Build-Up > Duration**, **Cooldown > Trigger**... Each feature's settings appear once it is on.
5. For keyboard and gamepad, set **Focus > Mode** to All.
6. Connect the signal in the **Node** dock, or in code: `$MyButton.pressed.connect(_on_pressed)`.

Inside a VBoxContainer or HBoxContainer, give it a **Custom Minimum Size**: it doesn't size itself from its text (the text fits whatever size the button has).

To reuse it, right-click it and choose **Save Branch as Scene**.

## Project Settings

All under **Project Settings > omni_button** (turn on **Advanced Settings** to see every one).

| Setting | Default | What it does |
|---|---|---|
| `dialog/enable_autoload` | On | Adds the `OmniDialog` autoload. Off removes it; dropped-in windows still work. |
| `dialog/theme` | the Modern look | The look every dialog window and menu uses. |
| `dialog/reference_size` | 1152 x 648 | The screen size windows are laid out for; they scale to your game's resolution. `(0, 0)` turns scaling off. |
| `dialog/popup_scene`, `toast_scene`, `dialogue_scene`, `narration_scene` | the shipped windows | Your own (inherited) window scenes for the autoload to use. |
| `menus/enable_autoload` | On | Adds the `OmniMenus` autoload. Off removes it; the menus still work and load settings when the first one opens. |
| `menus/options_scene` | the panel options screen | The options screen the title and pause menus open when they don't have one set. |
| `menus/settings_path` | `user://settings.cfg` | Where player settings are saved. |

For crisp text at any resolution, also set **Display > Window > Stretch > Mode** to `canvas_items`.

## Things that trip people up

- **A on the controller does nothing in menus.** Add a joypad button to `ui_accept` (see [Controllers](#controllers)).
- **Steam Deck or Steam Controller isn't detected** while testing from the editor. Steam Input hides it from programs not started by Steam: add Godot to Steam as a non-Steam game and launch it from there, or quit Steam.
- **Buttons collapse to nothing in a container.** Set **Custom Minimum Size**.
- **A signal handler never runs.** Its checkbox under **Actions** is off. Connecting in the editor turns it on; connecting from code after the button is ready doesn't.
- **The `OmniDialog` / `OmniMenus` autoload is missing.** Untick and re-tick the plugin, and check the `enable_autoload` settings.
- **Things freeze while the pause menu is open.** That's the pause. Set **Process > Mode > Always** on nodes that should keep moving.
- **Volume sliders don't change anything.** Your audio buses must be named **Music** and **SFX** (Master always exists).
- **Window mode does nothing** when the game runs inside the editor's Game tab. Turn off **Embed Game on Next Play**, or test an exported build.
- **Editing a preset changed all of them.** The presets share their style files. Use **Make Unique** on a style before editing it for one button.
- **Don't edit the shipped files** (presets, styles, looks, screens). Updating the plugin replaces them: duplicate or inherit them instead.

## Reference

- In the editor: press **F1** and type a class name (`OmniButton`, `OmniPopup`, `OmniTitleMenu`, `OmniSettings`...), or Ctrl+click a name in a script.
- Full guides: [OmniButton reference](README.md), [presets](prebuilt/buttons/README.md), [dialog windows](prebuilt/dialog/README.md), [looks](prebuilt/dialog/themes/README.md), [menus](prebuilt/menus/README.md), [controller cursor](prebuilt/cursor/README.md).
