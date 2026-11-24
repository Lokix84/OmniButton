# OmniTextWindow

**Inherits:** [OmniOverlay](./OmniOverlay.md)

Shared base of [OmniDialogueBox](./OmniDialogueBox.md) and [OmniNarration](./OmniNarration.md): typing text, answers and moving on.

## Description

A line is typed out in `body` (an `Omni_Button`). Pressing the body or `advance_action` while text is appearing shows the rest at once; pressing again moves on (`advance()` does the same from code). When a line has answers, they appear in `options_box` once the text is fully shown, and the line ends when one is picked. Each line can be awaited and returns the answer picked, or `-1`. Lines asked for while one is showing wait their turn. The window stays open between lines; `close_if_idle()` closes it at the end of the frame unless another line has started, so back-to-back lines don't flicker. Text supports BBCode and the typewriter's timing tags: `[pause=0.5]`, `[speed=10]` and `[/speed]`.

## Properties

| Type | Name | Default |
|---|---|---|
| `float` | [`text_speed_scale`](#text_speed_scale) | `1.0` |
| `float` | [`characters_per_second`](#characters_per_second) | `40.0` |
| `float` | [`auto_advance_delay`](#auto_advance_delay) | `0.0` |
| `StringName` | [`advance_action`](#advance_action) | `&"ui_accept"` |
| `AudioStream` | [`typing_sound`](#typing_sound) |  |
| `int` | [`typing_sound_every`](#typing_sound_every) | `2` |
| `float` | [`typing_pitch_variation`](#typing_pitch_variation) | `0.05` |
| `StringName` | [`typing_sound_bus`](#typing_sound_bus) | `&"Master"` |
| `bool` | [`show_skip_button`](#show_skip_button) | `true` |
| `float` | [`skip_hold_time`](#skip_hold_time) | `0.8` |
| `StringName` | [`skip_action`](#skip_action) | `&""` |
| `PackedScene` | [`option_button_scene`](#option_button_scene) | `<Object>` |
| `Control` | [`body`](#body) |  |
| `Container` | [`options_box`](#options_box) | `get_node_or_null(...)` |
| `Control` | [`continue_indicator`](#continue_indicator) | `get_node_or_null(...)` |
| `Control` | [`skip_button`](#skip_button) | `get_node_or_null(...)` |
| `int` | [`state`](#state) | `0` |

## Methods

| Returns | Method |
|---|---|
| `void` | [`advance`](#advance)() |
| `void` | [`end_line`](#end_line)() |
| `void` | [`set_skip_available`](#set_skip_available)(on: bool) |
| `void` | [`close_if_idle`](#close_if_idle)() |
| `bool` | [`is_busy`](#is_busy)() |
| `Texture2D` | [`to_texture`](#to_texture)(value: Variant) static |

## Signals

### line_started(text: String)

A line started typing.

### line_revealed()

All of the current line's text is showing. Answers, if any, appear now.

### line_finished(result: int)

The current line ended. `result` is the answer picked, or `-1`.

### skip_requested()

The player asked to skip: held `skip_button`, or pressed `skip_action`. An [OmniDialogRunner](./OmniDialogRunner.md) playing a skippable entry on this window listens to this and fast-forwards.

### _line_done(result: int)

### _released()

## Constants and enums

- enum **State**: `IDLE = 0`
- enum **State**: `REVEALING = 1`
- enum **State**: `WAITING = 2`
- enum **State**: `CHOOSING = 3`

## Property descriptions

### text_speed_scale

`float` `text_speed_scale` = `1.0`

Player text-speed setting for every dialog window: `1` is normal, `2` types twice as fast, `0.5` half as fast, and `0` shows each line at once. It multiplies each window's `characters_per_second` (and the popup's message speed). Typically set from a game's options menu: `OmniDialog.text_speed_scale = 2.0`. Speeds set inside the text with `[speed=...]` are not scaled.

### characters_per_second

`float` `characters_per_second` = `40.0`

Typewriter speed. A line can override it.

### auto_advance_delay

`float` `auto_advance_delay` = `0.0`

Move on by itself this many seconds after a line is fully shown. 0 waits for input.

### advance_action

`StringName` `advance_action` = `&"ui_accept"`

InputMap action that skips the reveal / moves on (also works while %Body has focus).

### typing_sound

`AudioStream` `typing_sound`

Played while text appears. Empty = silent.

### typing_sound_every

`int` `typing_sound_every` = `2`

Play the sound every N visible characters.

### typing_pitch_variation

`float` `typing_pitch_variation` = `0.05`

Random pitch change per blip (0.05 = ±5%).

### typing_sound_bus

`StringName` `typing_sound_bus` = `&"Master"`

Audio bus the typing sound plays on.

### show_skip_button

`bool` `show_skip_button` = `true`

Show `skip_button` while a skippable story entry is playing on this window.

### skip_hold_time

`float` `skip_hold_time` = `0.8`

Seconds the skip button has to be held.

### skip_action

`StringName` `skip_action` = `&""`

InputMap action that skips (pressed once). Empty turns it off.

### option_button_scene

`PackedScene` `option_button_scene` = `<Object>`

Scene each option is made from. Must be an Omni_Button (or have a `pressed` signal and `Text`).

### body

`Control` `body`

The `Omni_Button` the text types into.

### options_box

`Container` `options_box` = `get_node_or_null(...)`

`Container` that answers are added to.

### continue_indicator

`Control` `continue_indicator` = `get_node_or_null(...)`

Marker that blinks once a line is fully shown.

### skip_button

`Control` `skip_button` = `get_node_or_null(...)`

Hold-to-skip button (an `Omni_Button` using its hold build-up). Shown only while a skippable entry is playing; see `set_skip_available()`.

### state

`int` `state` = `0`

What the window is doing right now. See `State`.

## Method descriptions

### advance

`void` `advance()`

Shows the rest of the current line at once, or moves on if it is already showing.

### end_line

`void` `end_line()`

Ends the line showing now as if it had been read (an answer-less line returns `-1`). A line with answers is never ended this way: if it is still typing, the rest of it and its answers are shown instead. Used by `OmniDialogRunner.skip()`.

### set_skip_available

`void` `set_skip_available(on: bool)`

Shows or hides `skip_button`. An [OmniDialogRunner](./OmniDialogRunner.md) turns it on while it plays a skippable entry on this window.

### close_if_idle

`void` `close_if_idle()`

Closes the window at the end of this frame, unless a new line has started by then.

### is_busy

`bool` `is_busy()`

Returns `true` while a line is showing or waiting to show.

### to_texture

`Texture2D` `to_texture(value: Variant)` static

Returns `value` as a `Texture2D`: a texture is returned as is, a resource path is loaded, anything else gives `null`.
