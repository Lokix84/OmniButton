# OmniDialogAutoload

**Inherits:** `Node`

The `OmniDialog` autoload: shows OmniButton's dialog windows from any script.

## Description

The OmniButton plugin registers this script as the `OmniDialog` autoload. Using it is optional: every window also works dropped into a scene ([OmniPopup](./OmniPopup.md), [OmniToast](./OmniToast.md), [OmniDialogueBox](./OmniDialogueBox.md), [OmniNarration](./OmniNarration.md)), and an [OmniDialogRunner](./OmniDialogRunner.md) plays dialog files without it. Each window is created the first time it's needed and then reused. Which scene a window uses comes from **Project Settings > omni_button/dialog/popup_scene** (`toast_scene`, `dialogue_scene`, `narration_scene`), and its look from `omni_button/dialog/theme`.

```gdscript
OmniDialog.toast("Game saved")
if await OmniDialog.confirm("Quit to the title screen?"):
    get_tree().quit()
await OmniDialog.say("Guard", "Halt!", "res://portraits/guard.png")
var pick := await OmniDialog.ask("Guard", "Your business?", ["Trade", "Leave"])
await OmniDialog.narrate("Three days later...")
var answers := await OmniDialog.play("res://story/chapter1.json", "gate")
```

## Properties

| Type | Name | Default |
|---|---|---|
| [OmniDialogTheme](./OmniDialogTheme.md) | [`dialog_theme`](#dialog_theme) |  |
| `float` | [`text_speed_scale`](#text_speed_scale) |  |
| [OmniDialogRunner](./OmniDialogRunner.md) | [`runner`](#runner) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`toast`](#toast)(text: String, duration: float = -1.0) |
| `void` | [`alert`](#alert)(text: String, title: String = "", ok: String = "OK") |
| `bool` | [`confirm`](#confirm)(text: String, title: String = "", yes: String = "Yes", no: String = "No") |
| `int` | [`choose`](#choose)(text: String, options: PackedStringArray, title: String = "") |
| `void` | [`say`](#say)(speaker: String, text: String, portrait: Variant = null, side: String = "left") |
| `int` | [`ask`](#ask)(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") |
| `void` | [`narrate`](#narrate)(text: String, background: Variant = null) |
| `Dictionary` | [`play`](#play)(file: String, key: String) |
| `void` | [`stop`](#stop)() |
| `Dictionary[]` | [`check_file`](#check_file)(file: String) |
| `void` | [`skip_entry`](#skip_entry)() |
| `bool` | [`is_skipping`](#is_skipping)() |
| `bool` | [`is_playing`](#is_playing)() |
| `void` | [`register_event`](#register_event)(event_name: String, handler: Callable) |
| `void` | [`unregister_event`](#unregister_event)(event_name: String) |
| `Variant` | [`get_answer`](#get_answer)(id: String, default: Variant = null) |
| `void` | [`set_answer`](#set_answer)(id: String, value: Variant) |
| `Dictionary` | [`get_answers`](#get_answers)() |
| `void` | [`set_answers`](#set_answers)(values: Dictionary) |
| `void` | [`set_dialog_theme`](#set_dialog_theme)(t: OmniDialogTheme) |
| [OmniPopup](./OmniPopup.md) | [`get_popup`](#get_popup)() |
| [OmniToast](./OmniToast.md) | [`get_toast`](#get_toast)() |
| [OmniDialogueBox](./OmniDialogueBox.md) | [`get_dialogue`](#get_dialogue)() |
| [OmniNarration](./OmniNarration.md) | [`get_narration`](#get_narration)() |
| `String` | [`scene_path`](#scene_path)(key: String) static |

## Signals

### started(file: String, key: String)

An entry from a dialog file started playing (see `play()`).

### event_triggered(event_name: String, args: Array)

A dialog line fired an event. Handlers registered with `register_event()` also run.

### choice_made(id: String, value: Variant)

A question in a dialog file was answered, or a line's `set` stored a value.

### skip_started(file: String, key: String)

Skipping started (see `skip_entry()`).

### skip_stopped(file: String, key: String)

Skipping ended: a question was reached, or the entry finished.

### finished(file: String, key: String, entry_answers: Dictionary)

An entry finished. `entry_answers` holds the answers given during it.

## Constants and enums

- `SETTING_PREFIX = "omni_button/dialog/"`: Prefix of the Project Settings that choose each window's scene.
- `DEFAULT_SCENES = {"dialogue_scene": "res://addons/omni_button/prebuilt/dialog/windows/dialogue_box/omni_dialogue_box.tscn", "narration_scene": "res://addons/omni_button/prebuilt/dialog/windows/narration/omni_narration.tscn", "popup_scene": "res://addons/omni_button/prebuilt/dialog/windows/popup/omni_popup.tscn", "toast_scene": "res://addons/omni_button/prebuilt/dialog/windows/toast/omni_toast.tscn"}`: The prebuilt scene for each window, used when its Project Setting is empty.

## Property descriptions

### dialog_theme

[OmniDialogTheme](./OmniDialogTheme.md) `dialog_theme`

Look of the windows this autoload manages. `null` uses the project default (`omni_button/dialog/theme`). Change it with `set_dialog_theme()`.

### text_speed_scale

`float` `text_speed_scale`

Player text-speed setting for every dialog window, including dropped-in ones: `1` normal, `2` twice as fast, `0` instant. Same as `OmniTextWindow.text_speed_scale`. Save it with the player's settings; it isn't saved for you.

### runner

[OmniDialogRunner](./OmniDialogRunner.md) `runner`

The [OmniDialogRunner](./OmniDialogRunner.md) that `play()` uses, wired to this autoload's windows. Its answers are the ones `get_answer()` and `set_answers()` read and write.

## Method descriptions

### toast

`void` `toast(text: String, duration: float = -1.0)`

Shows a short message that disappears on its own after `duration` seconds (the toast's `OmniToast.default_duration` when negative). Doesn't block: await it only to wait until it's gone.

### alert

`void` `alert(text: String, title: String = "", ok: String = "OK")`

Shows `text` with one acknowledge button. Returns once it's dismissed.

### confirm

`bool` `confirm(text: String, title: String = "", yes: String = "Yes", no: String = "No")`

Asks a Yes / No question. Returns `true` for Yes. Canceling counts as No.

### choose

`int` `choose(text: String, options: PackedStringArray, title: String = "")`

Asks a question with several `options` in a popup. Returns the index picked, or `-1` when canceled.

### say

`void` `say(speaker: String, text: String, portrait: Variant = null, side: String = "left")`

Shows one line in the dialogue box. `portrait` is a `Texture2D` or a resource path; `side` is `"left"` or `"right"`. A run of `say()` calls reads as one conversation: the box stays open between lines.

### ask

`int` `ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left")`

Shows a dialogue line with answers in the dialogue box. Returns the index picked.

### narrate

`void` `narrate(text: String, background: Variant = null)`

Shows one full-screen narration line. `background` is a `Texture2D` or a resource path; `null` keeps the current one while narration stays open.

### play

`Dictionary` `play(file: String, key: String)`

Plays the entry `key` from the dialog JSON `file` and returns the answers given during it. Entries play one at a time: a call made while one is playing waits for its turn. See the dialog README for the file format.

### stop

`void` `stop()`

Ends the entry that is playing. The line showing now ends and its windows close.

### check_file

`Dictionary[]` `check_file(file: String)`

Checks a dialog file for mistakes and prints what it finds to the Output panel. Returns the problems (see [OmniDialogValidator](./OmniDialogValidator.md)); empty means the file is fine.

### skip_entry

`void` `skip_entry()`

Fast-forwards the rest of the playing entry, up to its next question. See `OmniDialogRunner.skip()`. The dialogue box and narration also have a hold-to-skip button that does this.

### is_skipping

`bool` `is_skipping()`

Returns `true` while the playing entry is being skipped. Event handlers can check it to jump straight to their end state.

### is_playing

`bool` `is_playing()`

Returns `true` while an entry from a dialog file is playing.

### register_event

`void` `register_event(event_name: String, handler: Callable)`

Runs `handler` whenever a dialog line fires the event `event_name`, passing the event's `args`. If the handler awaits something, the dialog waits for it (unless the event says `"wait": false`).

### unregister_event

`void` `unregister_event(event_name: String)`

Stops running the handler registered for `event_name`.

### get_answer

`Variant` `get_answer(id: String, default: Variant = null)`

Returns the answer stored under `id` by a question in a dialog file, or `default` if it hasn't been answered.

### set_answer

`void` `set_answer(id: String, value: Variant)`

Stores `value` under `id`, for example to let dialog lines check game state with `if`.

### get_answers

`Dictionary` `get_answers()`

Returns a copy of every stored answer. Save it with your game.

### set_answers

`void` `set_answers(values: Dictionary)`

Replaces every stored answer, for example with a Dictionary from a saved game.

### set_dialog_theme

`void` `set_dialog_theme(t: OmniDialogTheme)`

Switches the look of every window this autoload manages, now and later. `null` goes back to the project default.

### get_popup

[OmniPopup](./OmniPopup.md) `get_popup()`

The [OmniPopup](./OmniPopup.md) this autoload uses (created on first call).

### get_toast

[OmniToast](./OmniToast.md) `get_toast()`

The [OmniToast](./OmniToast.md) this autoload uses (created on first call).

### get_dialogue

[OmniDialogueBox](./OmniDialogueBox.md) `get_dialogue()`

The [OmniDialogueBox](./OmniDialogueBox.md) this autoload uses (created on first call).

### get_narration

[OmniNarration](./OmniNarration.md) `get_narration()`

The [OmniNarration](./OmniNarration.md) this autoload uses (created on first call).

### scene_path

`String` `scene_path(key: String)` static

Scene path for a window (`key` is a key of `DEFAULT_SCENES`), from Project Settings or the prebuilt default.
