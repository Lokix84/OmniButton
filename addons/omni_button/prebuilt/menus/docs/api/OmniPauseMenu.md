# OmniPauseMenu

**Inherits:** [OmniMenu](./OmniMenu.md)

The pause menu: Resume, Options and Quit to title, opened by Esc or the gamepad Start button.

## Description

Drop `omni_pause_menu.tscn` into your level (or player) scene. During play, the pause action opens it and pauses the game; pressing it again, cancel or Resume closes it and unpauses. It only opens while nothing else is open on screen (a dialog, another menu) and the game isn't already paused. Quit to title asks first, then changes to `title_scene` or emits `quit_to_title`.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`open_on_pause`](#open_on_pause) | `true` |
| `StringName` | [`pause_action`](#pause_action) | `&"ui_cancel"` |
| `int` | [`pause_button`](#pause_button) | `6` |
| `String` | [`title_scene`](#title_scene) | `""` |
| `bool` | [`confirm_quit`](#confirm_quit) | `true` |
| `String` | [`quit_question`](#quit_question) | `"Quit to the title screen?\nUnsaved progress will be lost."` |
| `bool` | [`show_quit_game`](#show_quit_game) | `false` |
| [OmniOptionsMenu](./OmniOptionsMenu.md) | [`options_menu`](#options_menu) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`pause`](#pause)() |
| `void` | [`resume`](#resume)() |
| `void` | [`cancel`](#cancel)() |

## Signals

### resumed()

The menu closed and the game resumed.

### quit_to_title()

Quit to title was confirmed. Emitted after the menu closed and the game unpaused.

### quit_game()

Quit game was confirmed.

## Property descriptions

### open_on_pause

`bool` `open_on_pause` = `true`

Open the menu with `pause_action` / `pause_button` during play.

### pause_action

`StringName` `pause_action` = `&"ui_cancel"`

InputMap action that opens and closes the menu (Esc by default).

### pause_button

`int` `pause_button` = `6`

Controller button that opens and closes the menu.

### title_scene

`String` `title_scene` = `""`

Scene to change to after Quit to title is confirmed. Empty: only `quit_to_title` is emitted.

### confirm_quit

`bool` `confirm_quit` = `true`

Ask before quitting.

### quit_question

`String` `quit_question` = `"Quit to the title screen?\nUnsaved progress will be lost."`

Question asked before Quit to title.

### show_quit_game

`bool` `show_quit_game` = `false`

Show a Quit game item too (off by default; hidden on the web and phones).

### options_menu

[OmniOptionsMenu](./OmniOptionsMenu.md) `options_menu`

The options screen opened by Options. Empty: one is made from **Project Settings > omni_button/menus/options_scene** the first time.

## Method descriptions

### pause

`void` `pause()`

Opens the menu and pauses the game (same as pressing the pause action).

### resume

`void` `resume()`

Closes the menu and resumes the game.

### cancel

`void` `cancel()`
