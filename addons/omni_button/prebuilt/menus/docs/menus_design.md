# Menus: design notes

Status: built (first version). Target: Godot 4.7, GDScript. User guide: [`../README.md`](../README.md).

## Scope (first version)

- **Title screen:** game title, Start, Continue (shown when the game says there is a save), Options, Quit.
- **Pause menu:** opens on Esc / the gamepad Start button during play, pauses the game. Resume, Options, Quit to title (asks first).
- **Options screen:** tabs for Audio (Master / Music / Sound volume), Display (window mode, VSync) and Gameplay (text speed). Changes apply at once and are saved.

- **Stylized full-screen versions** of all three (added after the first version): angled bands, bold slanted type, a slanted accent shape behind the selected item, staggered entrance. Same scripts as the panel versions; the visuals come from an `OmniMenuStylizer` node in each scene and the look's **Stylized Menus** colors. A third look, **Bold** (red / black / white), was added for them. The pause version is an angled split that leaves the paused game visible.

Later: controls remapping, save / load slots, credits.

## Decisions

- **Built on the dialog system's overlay.** Every menu is an `OmniOverlay` (`prebuilt/dialog/core/overlay/`), so menus get the same opening and closing animations, dimmed backdrop, focus trapping, cancel handling, pausing and screen scaling as the dialog windows, and stack with them (a confirm popup over the pause menu just works).
- **Same look files as the dialogs.** Menus use `OmniDialogTheme`; one look restyles dialogs and menus together. The looks gain an `OmniMenuTitle` type variation (big title text) and slider styles.
- **Buttons are the dialog's option buttons** (`parts/omni_option_button.tscn`), styled by the look like every popup button.
- **Scenes first, autoload optional.** Each menu is a scene you drop in and that works alone (signals, sensible defaults). The optional `OmniMenus` autoload only adds: settings loaded and applied when the game starts, and `OmniMenus.open_options()` from anywhere. Project Setting `omni_button/menus/enable_autoload` turns it off.
- **Settings live in `OmniSettings`** (static, no node needed): defined keys with defaults, saved to `user://settings.cfg`, applied on load and on change. Games add their own with `OmniSettings.define(...)`, and the options screen shows them automatically on the page they name.
- **The options screen is built from the setting definitions**, not laid out by hand: each definition says its page, label and kind (slider, toggle, choice). That is what lets game-defined settings appear with no extra UI work.

## Settings

| Key | Default | Kind | Applies to |
|---|---|---|---|
| `audio/master` | 1.0 | slider 0–100 % | bus "Master" |
| `audio/music` | 0.8 | slider | bus "Music" (skipped if the project has no such bus) |
| `audio/sfx` | 0.8 | slider | bus "SFX" (same) |
| `display/window_mode` | windowed | choice: windowed, fullscreen | the main window (not on web / mobile) |
| `display/vsync` | true | toggle | `DisplayServer.window_set_vsync_mode` |
| `gameplay/text_speed` | 1.0 | choice: slow 0.5, normal 1, fast 2, instant 0 | `OmniTextWindow.text_speed_scale` |

## Input

- **Pause:** the pause menu opens on `pause_action` (default `ui_cancel`, i.e. Esc) or the gamepad Start button, only while nothing else is open (no dialog window or menu on top) and the game isn't already paused. Cancel inside it resumes.
- **Options rows:** focus moves between rows with the d-pad / arrows. On a focused slider, left / right changes it (Godot's slider does this). On a focused choice or toggle, left / right steps through the values and confirm steps forward.
- **Gamepad confirm:** Godot's `ui_accept` has no controller button; the menus README tells games to add A, and the demo adds it while running.

## Build order

1. `OmniSettings` (define, get / set, apply, save / load, reset).
2. `OmniMenu` base (extends `OmniOverlay`): menu buttons by node, `item_pressed(id)`, look styling.
3. Title, pause, options scenes.
4. `OmniMenus` autoload + plugin registration and Project Settings.
5. Demo (a tiny "game": title → play → pause → options → quit to title), tests, README, API pages.
