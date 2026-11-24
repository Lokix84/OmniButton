# OmniTypewriterButton

**Inherits:** [Omni_Button](./Omni_Button.md)

An [Omni_Button](./Omni_Button.md) that types its `Omni_Button.Text` out when the scene starts, for title screens ("Press Start"), intros and prompts.

## Description

The first press while it is still typing only finishes the text; presses after that emit `Omni_Button.pressed` as usual. With `blink_when_done` on, the text pulses once it has finished typing, so it reads as "waiting for you".

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`autoplay`](#autoplay) | `true` |
| `float` | [`characters_per_second`](#characters_per_second) | `24.0` |
| `bool` | [`by_word`](#by_word) | `false` |
| `float` | [`start_delay`](#start_delay) | `0.3` |
| `bool` | [`blink_when_done`](#blink_when_done) | `true` |
| `float` | [`blink_period`](#blink_period) | `1.4` |
| `float` | [`blink_min_alpha`](#blink_min_alpha) | `0.3` |

## Methods

| Returns | Method |
|---|---|
| `void` | [`play`](#play)() |
| `bool` | [`is_typing`](#is_typing)() |

## Property descriptions

### autoplay

`bool` `autoplay` = `true`

Start typing as soon as the scene starts. Off: call `play()` yourself.

### characters_per_second

`float` `characters_per_second` = `24.0`

Typing speed.

### by_word

`bool` `by_word` = `false`

Reveal whole words instead of letters.

### start_delay

`float` `start_delay` = `0.3`

Wait this long before typing starts.

### blink_when_done

`bool` `blink_when_done` = `true`

Pulse the button once the text is fully shown.

### blink_period

`float` `blink_period` = `1.4`

Seconds for one full pulse (fade out and back in).

### blink_min_alpha

`float` `blink_min_alpha` = `0.3`

How faint the text gets at the bottom of each pulse (0 = invisible, 1 = no pulse).

## Method descriptions

### play

`void` `play()`

Types `Omni_Button.Text` from the start (also restarts it).

### is_typing

`bool` `is_typing()`

Whether the text is still being typed.
