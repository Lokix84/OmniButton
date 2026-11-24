# OmniDialogRunner

**Inherits:** `RefCounted`

Plays dialog entries from JSON files on dialog windows, one line at a time.

## Description

The `OmniDialog` autoload owns one runner (`OmniDialogAutoload.play()` uses it), but a runner works on its own too, with windows you dropped into your scene:

```gdscript
var runner := OmniDialogRunner.new()
runner.dialogue_box = $DialogueBox
runner.narration = $Narration
runner.popup = $Popup
runner.toast = $Toast
var answers := await runner.play("res://story/chapter1.json", "gate")
```

Answers to questions are stored by id in `answers` (save and load that Dictionary), and `play()` returns the answers given during that entry. Lines can check answers (`if` / `if_not`), store values (`set`), jump to other entries (`next` / `goto`), and fire events that game code handles (`register_event()`). The dialog README describes every line type and field.

## Properties

| Type | Name | Default |
|---|---|---|
| [OmniDialogueBox](./OmniDialogueBox.md) | [`dialogue_box`](#dialogue_box) |  |
| [OmniNarration](./OmniNarration.md) | [`narration`](#narration) |  |
| [OmniPopup](./OmniPopup.md) | [`popup`](#popup) |  |
| [OmniToast](./OmniToast.md) | [`toast`](#toast) |  |
| `Callable` | [`window_provider`](#window_provider) |  |
| `Dictionary` | [`answers`](#answers) | `{}` |
| `int` | [`max_lines_per_play`](#max_lines_per_play) | `10000` |

## Methods

| Returns | Method |
|---|---|
| `Dictionary` | [`play`](#play)(file: String, key: String) |
| `void` | [`skip`](#skip)() |
| `bool` | [`is_skipping`](#is_skipping)() |
| `void` | [`stop`](#stop)() |
| `bool` | [`is_running`](#is_running)() |
| `Variant` | [`get_answer`](#get_answer)(id: String, default: Variant = null) |
| `void` | [`set_answer`](#set_answer)(id: String, value: Variant) |
| `Dictionary` | [`get_answers`](#get_answers)() |
| `void` | [`set_answers`](#set_answers)(values: Dictionary) |
| `void` | [`register_event`](#register_event)(event_name: String, handler: Callable) |
| `void` | [`unregister_event`](#unregister_event)(event_name: String) |

## Signals

### started(file: String, key: String)

An entry started playing.

### line_started(line: Dictionary)

A line is about to run (after its conditions passed). `line` is the Dictionary from the file.

### event_triggered(event_name: String, args: Array)

An event line, or a line's / option's "event", fired. Also runs any handler registered for it.

### choice_made(id: String, value: Variant)

A question was answered (or a value was set by `set`).

### finished(file: String, key: String, entry_answers: Dictionary)

An entry finished. `entry_answers` are the answers given during it.

### skip_started(file: String, key: String)

Skipping started: the rest of the entry fast-forwards (see `skip()`).

### skip_stopped(file: String, key: String)

Skipping ended: a question was reached, or the entry finished.

### _released()

## Property descriptions

### dialogue_box

[OmniDialogueBox](./OmniDialogueBox.md) `dialogue_box`

Window for `say` lines. Leave empty to have `window_provider` create it.

### narration

[OmniNarration](./OmniNarration.md) `narration`

Window for `narrate` lines.

### popup

[OmniPopup](./OmniPopup.md) `popup`

Window for `alert`, `confirm` and `choice` lines.

### toast

[OmniToast](./OmniToast.md) `toast`

Window for `toast` lines.

### window_provider

`Callable` `window_provider`

Optional. Called with `"dialogue_box"`, `"narration"`, `"popup"` or `"toast"` when that window property is empty, and should return the window. The `OmniDialog` autoload uses it to create its windows the first time they're needed.

### answers

`Dictionary` `answers` = `{}`

Every answer and `set` value so far, by id. Save and restore it with your game (`get_answers()` / `set_answers()`).

### max_lines_per_play

`int` `max_lines_per_play` = `10000`

Safety limit: an entry that runs more lines than this (a `goto` loop) is stopped with an error.

## Method descriptions

### play

`Dictionary` `play(file: String, key: String)`

Plays the entry `key` from `file` and returns the answers given during it. A call made while another entry is playing waits for its turn.

### skip

`void` `skip()`

Fast-forwards the rest of the running entry. Lines are not shown, but their `set` values, conditions and jumps still apply, so the game ends up where it would have; `wait` lines and toasts are dropped, and events still run (handlers can check `is_skipping()` and jump to their end state). Skipping stops at the next question, which shows normally. Does nothing for an entry with `"skippable": false`. The windows' hold-to-skip button and `OmniTextWindow.skip_action` call this.

### is_skipping

`bool` `is_skipping()`

Returns `true` while the entry is being skipped. Event handlers use it to jump to their end state instead of animating.

### stop

`void` `stop()`

Stops the running entry: the line showing now ends (a question counts as canceled) and its windows close.

### is_running

`bool` `is_running()`

Returns `true` while an entry is playing.

### get_answer

`Variant` `get_answer(id: String, default: Variant = null)`

Returns the answer stored under `id`, or `default` if there is none.

### set_answer

`void` `set_answer(id: String, value: Variant)`

Stores `value` under `id`. Lines can check it with `if` / `if_not`.

### get_answers

`Dictionary` `get_answers()`

Returns a deep copy of `answers`.

### set_answers

`void` `set_answers(values: Dictionary)`

Replaces `answers` with a deep copy of `values`.

### register_event

`void` `register_event(event_name: String, handler: Callable)`

Runs `handler` (with the event's `args`) whenever an event named `event_name` fires. If the handler awaits, the dialog waits for it unless the event says `"wait": false`. **Note:** don't bind this runner into its own handler (`_f.bind(runner)`): the runner keeps its handlers, so it would never be freed.

### unregister_event

`void` `unregister_event(event_name: String)`

Stops running the handler registered for `event_name`.
