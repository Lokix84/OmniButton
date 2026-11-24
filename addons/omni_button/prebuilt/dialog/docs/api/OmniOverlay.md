# OmniOverlay

**Inherits:** `CanvasLayer`

Base of every dialog window: opening and closing, backdrop, focus, cancel and pausing.

## Description

[OmniPopup](./OmniPopup.md), [OmniToast](./OmniToast.md), [OmniDialogueBox](./OmniDialogueBox.md) and [OmniNarration](./OmniNarration.md) all inherit `omni_overlay.tscn`. To make your own kind of window (a shop, an inventory, a pause screen), make a **New Inherited Scene** from it and put your controls under `Root/Panel/Content`. It opens and closes with a short animation (`open()`, `close()`, both awaitable), can dim the game and block clicks behind it, keeps keyboard and gamepad focus inside while open, closes on the cancel action, and can pause the game. Several windows can be open at once, such as a popup over a dialogue box. The most recently opened one is on top: only it reacts to cancel and keeps focus, and closing it hands focus back to the one underneath.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`start_open`](#start_open) | `false` |
| `bool` | [`modal`](#modal) | `true` |
| `bool` | [`pause_tree`](#pause_tree) | `false` |
| `bool` | [`fit_to_screen`](#fit_to_screen) | `true` |
| [OmniDialogTheme](./OmniDialogTheme.md) | [`dialog_theme`](#dialog_theme) |  |
| `int` | [`open_animation`](#open_animation) | `1` |
| `int` | [`close_animation`](#close_animation) | `1` |
| `float` | [`animation_duration`](#animation_duration) | `0.15` |
| `float` | [`slide_distance`](#slide_distance) | `48.0` |
| `bool` | [`show_backdrop`](#show_backdrop) | `true` |
| `Color` | [`backdrop_color`](#backdrop_color) | `Color(0, 0, 0, 0.5)` |
| `bool` | [`close_on_backdrop_click`](#close_on_backdrop_click) | `false` |
| `bool` | [`close_on_cancel`](#close_on_cancel) | `true` |
| `StringName` | [`cancel_action`](#cancel_action) | `&"ui_cancel"` |
| `bool` | [`trap_focus`](#trap_focus) | `true` |
| `Control` | [`root_control`](#root_control) |  |
| `ColorRect` | [`backdrop`](#backdrop) |  |
| `Control` | [`panel`](#panel) |  |
| `Control` | [`content`](#content) |  |

## Methods

| Returns | Method |
|---|---|
| `bool` | [`is_open`](#is_open)() |
| [OmniOverlay](./OmniOverlay.md) | [`get_top`](#get_top)() static |
| `bool` | [`is_top`](#is_top)() |
| `void` | [`open`](#open)() |
| `void` | [`close`](#close)() |
| `void` | [`cancel`](#cancel)() |
| [OmniDialogTheme](./OmniDialogTheme.md) | [`get_dialog_theme`](#get_dialog_theme)() |
| `void` | [`apply_dialog_theme`](#apply_dialog_theme)() |
| `Vector2` | [`get_reference_size`](#get_reference_size)() static |
| `float` | [`get_screen_scale`](#get_screen_scale)() |
| `void` | [`refresh_focus`](#refresh_focus)() |

## Signals

### opening()

Emitted when `open()` starts, before the animation.

### opened()

Emitted when the open animation has finished.

### closing()

Emitted when `close()` starts, before the animation.

### closed()

Emitted when the window is hidden after the close animation.

### canceled()

Emitted by `cancel()`: the cancel action, a backdrop click (when enabled), or a call from code.

### _animation_ended()

Emitted when an open/close animation ends or is cut short by the next one.

## Constants and enums

- enum **OverlayAnimation**: `None = 0`
- enum **OverlayAnimation**: `Fade = 1`
- enum **OverlayAnimation**: `Scale = 2`
- enum **OverlayAnimation**: `SlideUp = 3`
- enum **OverlayAnimation**: `SlideDown = 4`
- `REFERENCE_SIZE_SETTING = "omni_button/dialog/reference_size"`: Project setting with the screen size the windows are laid out for.
- `DEFAULT_REFERENCE_SIZE = Vector2i(1152, 648)`: Screen size the prebuilt windows are laid out for.

## Property descriptions

### start_open

`bool` `start_open` = `false`

Open as soon as the scene is ready.

### modal

`bool` `modal` = `true`

Modal overlays join the open-overlay stack: they take focus, react to the cancel action and can pause the game. Non-modal ones (toasts) only show and hide, and never take input.

### pause_tree

`bool` `pause_tree` = `false`

Pause the game (SceneTree.paused) while open. The overlay keeps running.

### fit_to_screen

`bool` `fit_to_screen` = `true`

Scale the window to the game's resolution, so it takes the same share of the screen at any size (320x180, 640x360, 1920x1080...). The window is laid out for **Project Settings > omni_button/dialog/reference_size** and scaled from there. Turn off to lay the window out in the game's own pixels.

### dialog_theme

[OmniDialogTheme](./OmniDialogTheme.md) `dialog_theme`

The look of this window. Empty uses Project Settings > omni_button/dialog/theme.

### open_animation

`int` `open_animation` = `1`

Animation played by `open()`.

### close_animation

`int` `close_animation` = `1`

Animation played by `close()`.

### animation_duration

`float` `animation_duration` = `0.15`

Length of the open and close animations, in seconds. `0` shows and hides at once.

### slide_distance

`float` `slide_distance` = `48.0`

Distance in pixels the panel travels for SlideUp/SlideDown.

### show_backdrop

`bool` `show_backdrop` = `true`

Dim the game and block clicks to it while open.

### backdrop_color

`Color` `backdrop_color` = `Color(0, 0, 0, 0.5)`

Color of the backdrop behind the panel.

### close_on_backdrop_click

`bool` `close_on_backdrop_click` = `false`

Clicking the backdrop (outside the panel) cancels.

### close_on_cancel

`bool` `close_on_cancel` = `true`

The cancel action closes the overlay (after emitting canceled).

### cancel_action

`StringName` `cancel_action` = `&"ui_cancel"`

InputMap action that cancels. Empty turns it off.

### trap_focus

`bool` `trap_focus` = `true`

Keyboard/gamepad focus stays inside the overlay while it is the top one.

### root_control

`Control` `root_control`

Full-screen `Control` that holds the backdrop and the panel. The look's `Theme` is applied here.

### backdrop

`ColorRect` `backdrop`

Full-screen `ColorRect` that dims the game and blocks clicks to it.

### panel

`Control` `panel`

The window's panel (`PanelContainer` in the prebuilt scenes).

### content

`Control` `content`

Where a window's own controls go.

## Method descriptions

### is_open

`bool` `is_open()`

Returns `true` from `open()` until `close()` starts.

### get_top

[OmniOverlay](./OmniOverlay.md) `get_top()` static

Returns the modal window on top (the one that reacts to cancel and keeps focus), or `null` when none is open.

### is_top

`bool` `is_top()`

Returns `true` while this is the most recently opened window, the one that reacts to cancel and keeps focus.

### open

`void` `open()`

Shows the window and focuses its default control. Awaitable: returns once the animation ends.

### close

`void` `close()`

Hides the window and gives focus back to whatever had it before. Awaitable: returns once the animation ends.

### cancel

`void` `cancel()`

Emits `canceled`, then closes when `close_on_cancel` is on.

### get_dialog_theme

[OmniDialogTheme](./OmniDialogTheme.md) `get_dialog_theme()`

Returns the look in use: `dialog_theme`, or the project default.

### apply_dialog_theme

`void` `apply_dialog_theme()`

Applies the current look: its `Theme` on `root_control`, then the window's own `Omni_Button` parts.

### get_reference_size

`Vector2` `get_reference_size()` static

Returns the screen size windows are laid out for: **Project Settings > omni_button/dialog/reference_size** (`(0, 0)` turns scaling off for every window).

### get_screen_scale

`float` `get_screen_scale()`

Returns how much the window is scaled to fit the game's resolution (1 when it isn't).

### refresh_focus

`void` `refresh_focus()`

Focuses the default control again, for windows that change their content while open.
