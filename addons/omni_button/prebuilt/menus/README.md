# Menus

A title screen, a pause menu and an options screen, ready to drop into a game. They share the dialog windows' looks, so menus and dialogs always match, and the player's settings (volume, window mode, text speed) are saved and applied for you.

To see them, open `demo/omni_menus_demo.tscn` and press F6: a tiny game with a title screen, play, Esc or the controller's Start button to pause, Options, and Quit to title.

The demo shows every setting working:
- **Volume:** it plays a soft music loop on a "Music" bus and a click on an "SFX" bus. It adds those buses while it runs, if your project has none, so the sliders are audible.
- **Text speed:** T (or Y on a controller) shows a line of dialogue, typed at the speed you chose.
- **Live readout:** a panel at the left edge lists the current settings and the bus levels they set.
- **Style and look:** its options screen has a **Demo** tab (two settings of the demo's own) to switch between the panel menus and the full-screen stylized ones, and between the Modern, Retro and Bold looks.
- **Window mode and VSync:** these only change a game running in its own window, not the editor's embedded game view. To try them, turn off **Embed Game on Next Play** in the Game tab.

## The three menus

| Scene (in `screens/`) | What it does | Connect |
|---|---|---|
| `omni_title_menu.tscn` | Your game's title with Start, Continue, Options and Quit. Opens by itself, covers the screen. | `start_pressed`, `continue_pressed` |
| `omni_pause_menu.tscn` | Opens on Esc or the controller's Start button during play and pauses the game. Resume, Options, Quit to title (asks first). | `quit_to_title` (or set `title_scene`) |
| `omni_options_menu.tscn` | Tabs for Audio, Display and Gameplay. Changes apply at once and are saved when it closes. | nothing needed |

### Title screen

Drop `omni_title_menu.tscn` into your title scene and set **Title** to your game's name.

```gdscript
func _ready() -> void:
	$OmniTitleMenu.can_continue = SaveGame.exists()
	$OmniTitleMenu.start_pressed.connect(func(): get_tree().change_scene_to_file("res://level_1.tscn"))
	$OmniTitleMenu.continue_pressed.connect(SaveGame.load_and_play)
```

- **Continue** is hidden until you set `can_continue`.
- **Options** opens the options screen and **Quit** quits, with no code. Quit is hidden on the web and phones.
- Cancel doesn't close the title screen.
- `close_on_start` (on) closes it when Start or Continue is pressed. Turn it off if you change scenes yourself.

### Pause menu

Drop `omni_pause_menu.tscn` into your level (or player) scene. That's all: during play, Esc or the controller's Start button opens it and pauses the game (`get_tree().paused`). Esc / Start again, cancel or **Resume** closes it and unpauses.

- **Only when nothing else is open.** It won't open over a dialog window, a popup or another menu, or when the game is already paused.
- **Quit to title** asks first (`confirm_quit`, `quit_question`), then changes to **Title Scene** if you set one, and emits `quit_to_title`.
- **Quit game** is there but hidden (`show_quit_game`).
- Change the keys with `pause_action` (default `ui_cancel`, i.e. Esc) and `pause_button` (default Start). Call `pause()` / `resume()` from code. Turn off `open_on_pause` for cutscenes.

Remember that a paused game stops nodes that aren't set to keep running: things that must keep moving while paused (the pause menu itself does) need **Process > Mode > Always**.

### Options screen

The title and pause menus open it on their own: each makes one the first time (from **Project Settings > omni_button/menus/options_scene**). To share one, drop `omni_options_menu.tscn` into the scene and point both menus' **Options Menu** at it (the demo does this). From code, anywhere: `OmniMenus.open_options()`.

Controls: the d-pad / arrows move between rows. On a slider, left / right changes it. On a choice or an On / Off row, left / right steps through the values and confirm steps forward. The shoulder buttons switch tabs. Cancel or **Back** closes and saves. **Reset to defaults** resets the page that's showing.

## Stylized full-screen menus

Each menu also comes as a full-screen stylized version: bold angled bands sweep across the screen, the title and items are set in a big bold slanted font, the selected item gets a slanted accent shape behind it (with a little pop), and the items appear one after another when the menu opens.

| Scene (in `screens/`) | Layout |
|---|---|
| `omni_title_menu_stylized.tscn` | Full screen: the title at the top left, the items stepping down along the bands on the right. |
| `omni_pause_menu_stylized.tscn` | Angled split: a slanted plate on the left holds the menu, and the paused game stays visible on the right. |
| `omni_options_menu_stylized.tscn` | The options screen on a dark slanted plate over full-screen bands. |

They use the same scripts as the panel versions, so the signals, settings, input and behavior are identical: use one instead of the other and nothing else changes. The stylized title and pause menus open the stylized options screen (their **Options Scene** setting).

**Colors** come from the look's **Stylized Menus** group: `accent_color` (the selected-item shape and stripes), `accent_text_color`, `menu_background_color`, `menu_band_color`, `menu_text_color`, and `menu_font` (empty: the look's font, made bold and slanted). Modern (blue), Retro (gold, pixel font) and the high-contrast **Bold** look (red, black and white, with slanted buttons in dialogs too) all set them.

**Tuning** is on the `Stylizer` node in each scene (`OmniMenuStylizer`): title and item size, how far the text leans (`slant`), item size, the sweep time, the delay between items, and the select pop. The bands are an `OmniMenuBands` node (`FULL` or `SPLIT` shape) and the item list an `OmniStaircaseContainer` (`step` sets the slant of the list). A menu's `animation_duration` of 0 turns all the motion off.

## Settings

The built-in settings:

| Key | Default | Shown as | Applies to |
|---|---|---|---|
| `audio/master` | 100 % | slider | the "Master" audio bus |
| `audio/music` | 80 % | slider | the "Music" bus |
| `audio/sfx` | 80 % | slider | the "SFX" bus |
| `display/window_mode` | Windowed | choice | the game window (hidden on the web and phones) |
| `display/vsync` | On | On / Off | VSync (hidden on the web and phones) |
| `gameplay/text_speed` | Normal | choice: Slow, Normal, Fast, Instant | how fast dialog text types |

**Audio buses:** name your buses "Music" and "SFX" in the **Audio** panel (at the bottom of the editor) and the volume sliders control them. A bus that doesn't exist is simply skipped.

**Your own settings** show up on the options screen with no extra UI work. Define them once, at startup (an autoload of your own is a good place); a setting defined after the settings file loaded still gets its saved value:

```gdscript
OmniSettings.define("gameplay/screen_shake", true, {
	"page": "Gameplay", "label": "Screen shake",
	"apply": func(on: bool): Camera.shake_enabled = on,
})
OmniSettings.define("gameplay/difficulty", "normal", {
	"page": "Gameplay", "label": "Difficulty",
	"choices": [["Easy", "easy"], ["Normal", "normal"], ["Hard", "hard"]],
})
OmniSettings.define("audio/voices", 1.0, {"page": "Audio", "label": "Voices",
	"apply": func(v: float): AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Voices"), linear_to_db(v))})
```

A bool becomes an On / Off row, a `choices` list a choice row, anything else a 0–100 % slider. A new `page` name adds a tab. Read a setting anywhere with `OmniSettings.get_value("gameplay/difficulty")`; change one with `OmniSettings.set_value(...)` (then `OmniSettings.save()`); hear changes with `OmniSettings.watch(callback)` or `OmniMenus.setting_changed`.

Settings are saved to `user://settings.cfg` (**Project Settings > omni_button/menus/settings_path**) and loaded and applied when the game starts by the `OmniMenus` autoload, or, without it, by the first menu that opens.

## Controllers

Godot's `ui_accept` has Enter and Space but no controller button, so A can't press a menu item until you add it: **Project Settings > Input Map > ui_accept**, add **Joypad Button 0**. (The demo adds it while it runs.) For a mouse-like pointer on the stick, add the [controller cursor](../cursor/README.md).

## Changing the look

The menus use the same look files as the dialog windows ([`../dialog/themes/README.md`](../dialog/themes/README.md)): panels, fonts and buttons all come from the look, so one file restyles dialogs and menus together. Menus also use two entries in the look's Theme:

- `OmniMenuTitle` (a Label type variation): the big title on the title and pause menus.
- `HSlider` styles (`slider`, `grabber_area`, `grabber_area_highlight`): the options screen's sliders.

To change a menu's layout, make a **New Inherited Scene** from it. Add, rename or hide items in `%Items`: each button's node name is its id (`QuitToTitle` → `quit_to_title`) in the `item_pressed` signal.

## The OmniMenus autoload

Optional. It loads and applies the settings on the first frame (so volumes are right even before any menu opens), and gives you `OmniMenus.open_options()` and `OmniMenus.setting_changed`. Turn it off with **Project Settings > omni_button/menus/enable_autoload**; the menus still work.

## Folders

```
menus/
├── screens/   omni_title_menu.tscn, omni_pause_menu.tscn, omni_options_menu.tscn,
│             and each one's *_stylized.tscn version
├── core/      OmniMenu (base), the three menus' scripts, OmniSettings, OmniMenus autoload,
│             OmniMenuStylizer, OmniMenuBands, OmniStaircaseContainer (the stylized versions)
├── demo/      omni_menus_demo.tscn
├── docs/      design notes and the API reference
└── dev/       automated tests (left out of downloads)
```
