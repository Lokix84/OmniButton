# OmniSwipePad

**Inherits:** [Omni_Button](./Omni_Button.md)

An [Omni_Button](./Omni_Button.md) that reports one direction per swipe, for dashes, card swipes and menus.

## Description

`Omni_Button.swipe` fires again and again while the finger keeps moving; `swiped` fires once per gesture, as soon as the finger has travelled `Omni_Button.SwipeThreshold` pixels, with the direction snapped to left / right / up / down (or exact, with `four_way` off).

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`four_way`](#four_way) | `true` |

## Methods

| Returns | Method |
|---|---|
| `Vector2` | [`snap`](#snap)(direction: Vector2) static |

## Signals

### swiped(direction: Vector2)

One swipe happened. With `four_way` on, `direction` is `Vector2.LEFT`, `RIGHT`, `UP` or `DOWN`; otherwise it is the exact unit direction.

## Property descriptions

### four_way

`bool` `four_way` = `true`

Snap each swipe to the nearest of left / right / up / down.

## Method descriptions

### snap

`Vector2` `snap(direction: Vector2)` static

Nearest of left / right / up / down to `direction`.
