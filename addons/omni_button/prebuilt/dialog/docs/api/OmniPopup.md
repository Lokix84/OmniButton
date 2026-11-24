# OmniPopup

**Inherits:** [OmniOverlay](./OmniOverlay.md)

A centered window with a title, a message and buttons: alert, confirm and choice in one scene.

## Description

Two buttons sit in a row; more stack vertically (see `max_buttons_in_row`). All buttons share one font size, and long button text wraps. Every call can be awaited and returns once the popup has closed. One popup shows one question at a time: a call made while it is busy waits for its turn.

```gdscript
await $Popup.alert("Saved.")
if await $Popup.confirm("Quit to the title screen?"):
    get_tree().quit()
var pick := await $Popup.choose("Pick a class", ["Warrior", "Mage", "Rogue"])
```

Dropped into a scene, it can also be set up entirely in the Inspector (`title`, `message`, `buttons`) and shown with `await $Popup.show_configured()`.

## Properties

| Type | Name | Default |
|---|---|---|
| `String` | [`title`](#title) | `""` |
| `String` | [`message`](#message) | `""` |
| `PackedStringArray` | [`buttons`](#buttons) | `[...]` |
| `int` | [`default_button`](#default_button) | `0` |
| `bool` | [`type_message`](#type_message) | `false` |
| `float` | [`message_speed`](#message_speed) | `60.0` |
| `bool` | [`allow_cancel`](#allow_cancel) | `true` |
| `int` | [`cancel_index`](#cancel_index) | `-1` |
| `int` | [`max_buttons_in_row`](#max_buttons_in_row) | `2` |
| `PackedScene` | [`option_button_scene`](#option_button_scene) | `<Object>` |
| `Label` | [`title_label`](#title_label) |  |
| `Control` | [`message_label`](#message_label) |  |
| `HBoxContainer` | [`button_row`](#button_row) |  |
| `VBoxContainer` | [`button_column`](#button_column) |  |

## Methods

| Returns | Method |
|---|---|
| `int` | [`ask`](#ask)(text: String, options: PackedStringArray, title_text: String = "", default_index: int = 0, cancel: int = -1) |
| `void` | [`alert`](#alert)(text: String, title_text: String = "", ok: String = "OK") |
| `bool` | [`confirm`](#confirm)(text: String, title_text: String = "", yes: String = "Yes", no: String = "No") |
| `int` | [`choose`](#choose)(text: String, options: PackedStringArray, title_text: String = "") |
| `int` | [`show_configured`](#show_configured)() |
| `bool` | [`is_busy`](#is_busy)() |
| `void` | [`cancel`](#cancel)() |

## Signals

### button_pressed(index: int, text: String)

A button was picked (not emitted on cancel).

### _answered(index: int)

### _released()

## Property descriptions

### title

`String` `title` = `""`

Title above the message. Empty hides it.

### message

`String` `message` = `""`

The message. BBCode is allowed. Long messages wrap and then shrink to fit.

### buttons

`PackedStringArray` `buttons` = `[...]`

Button labels, left to right (or top to bottom when stacked).

### default_button

`int` `default_button` = `0`

Index of the button focused when the popup opens.

### type_message

`bool` `type_message` = `false`

Type the message out with the typewriter instead of showing it at once. Clicking the message shows the rest.

### message_speed

`float` `message_speed` = `60.0`

Typing speed when `type_message` is on.

### allow_cancel

`bool` `allow_cancel` = `true`

The cancel action and backdrop clicks answer the popup with `cancel_index`.

### cancel_index

`int` `cancel_index` = `-1`

Index returned when the popup is canceled. `-1` means none of the buttons.

### max_buttons_in_row

`int` `max_buttons_in_row` = `2`

With more buttons than this, they stack vertically instead of sitting in a row.

### option_button_scene

`PackedScene` `option_button_scene` = `<Object>`

Scene each button is made from. Must be an `Omni_Button` (or have a `pressed` signal and a `Text` property).

### title_label

`Label` `title_label`

`Label` for the title (type variation `OmniDialogTitle`).

### message_label

`Control` `message_label`

The message, an `Omni_Button`: long text shrinks to fit its fixed height.

### button_row

`HBoxContainer` `button_row`

Holds the buttons when there are `max_buttons_in_row` or fewer.

### button_column

`VBoxContainer` `button_column`

Holds the buttons when there are more than `max_buttons_in_row`.

## Method descriptions

### ask

`int` `ask(text: String, options: PackedStringArray, title_text: String = "", default_index: int = 0, cancel: int = -1)`

Shows `text` with `options` as buttons and returns the index picked, or `cancel` when canceled. **Note:** this is the general popup question; `OmniDialogAutoload.ask()` asks in the dialogue box.

### alert

`void` `alert(text: String, title_text: String = "", ok: String = "OK")`

Shows `text` with a single acknowledge button.

### confirm

`bool` `confirm(text: String, title_text: String = "", yes: String = "Yes", no: String = "No")`

Asks a Yes / No question. Returns `true` for Yes. Canceling counts as No.

### choose

`int` `choose(text: String, options: PackedStringArray, title_text: String = "")`

Asks a question with several `options`. Returns the index picked, or `-1` when canceled.

### show_configured

`int` `show_configured()`

Shows the popup with the `title`, `message` and `buttons` set in the Inspector. Returns the index picked.

### is_busy

`bool` `is_busy()`

Returns `true` while a question is showing or waiting to show.

### cancel

`void` `cancel()`

Answers the popup with `cancel_index` and closes it, if `allow_cancel` is on.
