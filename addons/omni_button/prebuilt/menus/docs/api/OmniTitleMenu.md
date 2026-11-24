# OmniTitleMenu

**Inherits:** [OmniMenu](./OmniMenu.md)

The title screen: the game's title with Start, Continue, Options and Quit.

## Description

Drop `omni_title_menu.tscn` into your title scene. It opens on its own, loads and applies the player's settings, and covers the screen. Connect `start_pressed` (and `continue_pressed` if you have saves) to start the game; Options opens the options screen and Quit quits, with no code. Rename, hide or add items in the scene ([OmniMenu](./OmniMenu.md)).

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`can_continue`](#can_continue) | `false` |
| `bool` | [`show_quit`](#show_quit) | `true` |
| `bool` | [`close_on_start`](#close_on_start) | `true` |
| [OmniOptionsMenu](./OmniOptionsMenu.md) | [`options_menu`](#options_menu) |  |

## Signals

### start_pressed()

Start was pressed.

### continue_pressed()

Continue was pressed.

## Property descriptions

### can_continue

`bool` `can_continue` = `false`

Show Continue (set it when the player has a save).

### show_quit

`bool` `show_quit` = `true`

Show Quit. Off by default on the web and phones, where games don't quit.

### close_on_start

`bool` `close_on_start` = `true`

Close the title screen when Start or Continue is pressed. Turn off if you change scenes yourself.

### options_menu

[OmniOptionsMenu](./OmniOptionsMenu.md) `options_menu`

The options screen opened by Options. Empty: one is made from **Project Settings > omni_button/menus/options_scene** the first time.
