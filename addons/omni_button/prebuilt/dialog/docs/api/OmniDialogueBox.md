# OmniDialogueBox

**Inherits:** [OmniTextWindow](./OmniTextWindow.md)

RPG-style dialogue box: speaker name, portrait on either side, typing text and answers.

## Description

A wide panel along the bottom of the screen that keeps the same size the whole time. Every line sets its own name and portrait, so the speaker can change from line to line; an empty name or no portrait hides that part. On a line with answers, the question types out on the left and the answers appear in a column on the right; long answers wrap, share one font size, and scroll if there are many. Use it through the autoload (`OmniDialogAutoload.say()`) or drop `omni_dialogue_box.tscn` into a scene and call the same methods on it:

```gdscript
await $DialogueBox.say("Guard", "Halt! Who goes there?", "res://portraits/guard.png")
var pick := await $DialogueBox.ask("Guard", "State your business.", ["Trade", "Leave"])
```

## Properties

| Type | Name | Default |
|---|---|---|
| `Label` | [`name_label`](#name_label) |  |
| `TextureRect` | [`portrait_left`](#portrait_left) |  |
| `TextureRect` | [`portrait_right`](#portrait_right) |  |
| `Control` | [`options_column`](#options_column) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`say`](#say)(speaker: String, text: String, portrait: Variant = null, side: String = "left") |
| `int` | [`ask`](#ask)(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") |
| `int` | [`show_line`](#show_line)(speaker: String, text: String, portrait: Variant = null, side: String = "left", options: PackedStringArray = PackedStringArray(), speed: float = 0.0) |

## Property descriptions

### name_label

`Label` `name_label`

`Label` showing the speaker's name (type variation `OmniDialogName`).

### portrait_left

`TextureRect` `portrait_left`

Portrait shown for speakers on the left.

### portrait_right

`TextureRect` `portrait_right`

Portrait shown for speakers on the right.

### options_column

`Control` `options_column`

Right-hand column for answers. It is shown for the whole of a line that has answers, so nothing moves when they appear, and scrolls if there are more than fit.

## Method descriptions

### say

`void` `say(speaker: String, text: String, portrait: Variant = null, side: String = "left")`

Shows one line, then closes unless another line follows straight away (so a run of `say()` calls reads as one conversation). `portrait` is a `Texture2D` or a resource path; `side` is `"left"` or `"right"`.

### ask

`int` `ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left")`

Shows a line with `options` as answers and returns the index picked.

### show_line

`int` `show_line(speaker: String, text: String, portrait: Variant = null, side: String = "left", options: PackedStringArray = PackedStringArray(), speed: float = 0.0)`

Shows one line and leaves the box open; call `OmniTextWindow.close_if_idle()` after the last one. Returns the answer picked, or `-1` when the line has no `options`. `speed` overrides `OmniTextWindow.characters_per_second` for this line.
