# OmniButton menus API reference

Generated from the doc comments in the scripts by `addons/omni_button/dev/generate_api_docs.gd`. In the Godot editor, the same docs open with F1 (Search Help) or Ctrl+click on a class or method name.

The menus are dialog windows underneath ([OmniOverlay](../../../dialog/docs/api/OmniOverlay.md)), styled by the same looks; see the [dialog API reference](../../../dialog/docs/api/README.md). Usage guide: [menus README](../../README.md).

## Menus

- [OmniTitleMenu](OmniTitleMenu.md): The title screen: the game's title with Start, Continue, Options and Quit.
- [OmniPauseMenu](OmniPauseMenu.md): The pause menu: Resume, Options and Quit to title, opened by Esc or the gamepad Start button.
- [OmniOptionsMenu](OmniOptionsMenu.md): The options screen: one tab per settings page, one row per setting, built from [OmniSettings](./OmniSettings.md).
- [OmniMenu](OmniMenu.md): Base of the menu screens ([OmniTitleMenu](./OmniTitleMenu.md), [OmniPauseMenu](./OmniPauseMenu.md)): an [OmniOverlay](../../../dialog/docs/api/OmniOverlay.md) with a title and a column of buttons.

## Stylized menus

- [OmniMenuStylizer](OmniMenuStylizer.md): Turns a menu into the full-screen stylized version: put it as a child of an [OmniMenu](./OmniMenu.md) or [OmniOptionsMenu](./OmniOptionsMenu.md) scene. It colors `bands` from the look's **Stylized Menus** colors, sets the title and items in a bold slanted font, puts a slanted `OmniDialogTheme.accent_color` shape behind the selected item, and plays the entrance: the bands sweep in and the items appear one after another. The menu's own behavior (items, signals, input, pausing) is unchanged.
- [OmniMenuBands](OmniMenuBands.md): The angled background of the stylized menus: bold slanted bands with a thin accent stripe, drawn in code so they stay sharp at any size. `progress` sweeps them in (0 = off screen to the left, 1 = in place); [OmniMenuStylizer](./OmniMenuStylizer.md) animates it when the menu opens and closes.
- [OmniStaircaseContainer](OmniStaircaseContainer.md): Stacks its children like a `VBoxContainer`, shifting each one sideways by `step`, so a list follows a slant (the stylized menus line their items up with the angled bands).

## Settings

- [OmniSettings](OmniSettings.md): The game's player settings (volume, window mode, text speed...): defined once, saved to a file, and applied to the game whenever they change. Static: use it from anywhere, no node needed.
- [OmniMenusAutoload](OmniMenusAutoload.md): The optional `OmniMenus` autoload: loads and applies the player's settings when the game starts, and opens the options screen from anywhere.
