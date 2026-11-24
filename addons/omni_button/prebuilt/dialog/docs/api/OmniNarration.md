# OmniNarration

**Inherits:** [OmniTextWindow](./OmniTextWindow.md)

Full-screen narration: centered typing text over an opaque backdrop, with an optional background image.

## Description

Clicking anywhere moves on. A line without a background keeps the one already showing; the background is cleared when narration closes.

```gdscript
await $Narration.narrate("The city of Vell.", "res://backgrounds/vell.png")
await $Narration.narrate("Three days after the fire...")
```

## Properties

| Type | Name | Default |
|---|---|---|
| `TextureRect` | [`background`](#background) |  |
| `Control` | [`shade`](#shade) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`narrate`](#narrate)(text: String, background_image: Variant = null) |
| `int` | [`show_text`](#show_text)(text: String, background_image: Variant = null, options: PackedStringArray = PackedStringArray(), speed: float = 0.0) |

## Property descriptions

### background

`TextureRect` `background`

`TextureRect` for the background image (cover-scaled).

### shade

`Control` `shade`

Dark layer over the background so the text stays readable.

## Method descriptions

### narrate

`void` `narrate(text: String, background_image: Variant = null)`

Shows one narration line, then closes unless another line follows straight away. `background_image` is a `Texture2D` or a resource path; `null` keeps the current one.

### show_text

`int` `show_text(text: String, background_image: Variant = null, options: PackedStringArray = PackedStringArray(), speed: float = 0.0)`

Shows one narration line and leaves narration open; call `OmniTextWindow.close_if_idle()` after the last one. Returns the answer picked, or `-1` when there are no `options`.
