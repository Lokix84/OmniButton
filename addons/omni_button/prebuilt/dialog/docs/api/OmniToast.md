# OmniToast

**Inherits:** [OmniOverlay](./OmniOverlay.md)

Short messages near the top of the screen that disappear on their own.

## Description

Toasts never take focus or react to cancel, so a popup open at the same time keeps working. Several can show at once, newest at the bottom. Each toast is an `Omni_Button` made from `item_scene`: its panel comes from the look's `OmniDialogToast` style, long text wraps and shrinks to fit, and clicking it dismisses it.

```gdscript
$Toast.toast("Game saved")
$Toast.toast("Achievement unlocked", 4.0)
```

## Properties

| Type | Name | Default |
|---|---|---|
| `float` | [`default_duration`](#default_duration) | `2.0` |
| `int` | [`max_visible`](#max_visible) | `4` |
| `float` | [`fade_time`](#fade_time) | `0.2` |
| `bool` | [`dismiss_on_click`](#dismiss_on_click) | `true` |
| `PackedScene` | [`item_scene`](#item_scene) | `<Object>` |
| `VBoxContainer` | [`toast_list`](#toast_list) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`show_toast`](#show_toast)(text: String, duration: float = -1.0) |
| `void` | [`toast`](#toast)(text: String, duration: float = -1.0) |
| `int` | [`count`](#count)() |
| `void` | [`clear`](#clear)() |

## Property descriptions

### default_duration

`float` `default_duration` = `2.0`

Seconds a toast stays up when no duration is given.

### max_visible

`int` `max_visible` = `4`

Oldest toasts are removed when more than this many are showing.

### fade_time

`float` `fade_time` = `0.2`

Seconds each toast takes to fade in and out.

### dismiss_on_click

`bool` `dismiss_on_click` = `true`

Clicking or tapping a toast dismisses it. Off: toasts let clicks through to the game.

### item_scene

`PackedScene` `item_scene` = `<Object>`

Scene each toast is made from (`parts/omni_toast_item.tscn`). Edit it, or point this at your own, to restyle or resize toasts.

### toast_list

`VBoxContainer` `toast_list`

`VBoxContainer` the toasts are added to.

## Method descriptions

### show_toast

`void` `show_toast(text: String, duration: float = -1.0)`

Same as `toast()`.

### toast

`void` `toast(text: String, duration: float = -1.0)`

Shows `text` for `duration` seconds (`default_duration` when negative). Await it only to wait until it's gone. Not affected by pausing or `Engine.time_scale`.

### count

`int` `count()`

Returns how many toasts are showing.

### clear

`void` `clear()`

Removes every toast at once.
