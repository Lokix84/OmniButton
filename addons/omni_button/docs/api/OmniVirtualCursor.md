# OmniVirtualCursor

**Inherits:** `CanvasLayer`

A controller cursor for menus: a ring moved by a joystick that clicks whatever is under it, like the menus in Destiny or The First Descendant.

## Description

The ring drives Godot's normal mouse input: moving it sends mouse motion, so buttons under it show their hover look, and the click action sends a left click at its center. Every Control works with it: [Omni_Button](./Omni_Button.md), Godot's `Button`, sliders, scroll containers.

Drop `omni_virtual_cursor.tscn` into a menu scene. It appears when the stick moves and hides when the mouse, a touch or the d-pad (focus navigation) is used, so only one way of pointing is active at a time. While it is shown, the click action clicks under the ring instead of pressing the focused button.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`active`](#active) | `true` |
| `int` | [`stick`](#stick) | `0` |
| `int` | [`device`](#device) | `-1` |
| `float` | [`dead_zone`](#dead_zone) | `0.2` |
| `float` | [`speed`](#speed) | `1.2` |
| `float` | [`response_curve`](#response_curve) | `2.0` |
| `int` | [`click_button`](#click_button) | `0` |
| `StringName` | [`click_action`](#click_action) | `&"ui_accept"` |
| `float` | [`hover_slowdown`](#hover_slowdown) | `0.45` |
| `float` | [`snap_strength`](#snap_strength) | `0.5` |
| `float` | [`scroll_speed`](#scroll_speed) | `12.0` |
| `float` | [`ring_size`](#ring_size) | `0.08` |
| `Color` | [`ring_color`](#ring_color) | `Color(1, 1, 1, 0.9)` |
| `Color` | [`hover_color`](#hover_color) | `Color(1, 0.82, 0.4, 1)` |
| `Texture2D` | [`ring_texture`](#ring_texture) |  |
| `bool` | [`hide_mouse_pointer`](#hide_mouse_pointer) | `true` |
| `Vector2` | [`cursor_position`](#cursor_position) | `Vector2(0, 0)` |

## Methods

| Returns | Method |
|---|---|
| `bool` | [`is_shown`](#is_shown)() |
| `void` | [`warp_to`](#warp_to)(point: Vector2) |
| `Control` | [`get_hovered_control`](#get_hovered_control)() |

## Signals

### shown()

The ring started showing (the stick moved).

### hidden()

The ring hid (mouse, touch or d-pad used, or `active` turned off).

### clicked(position: Vector2)

The ring clicked at `position` (in the viewport's coordinates).

## Constants and enums

- enum **Stick**: `LEFT = 0`
- enum **Stick**: `RIGHT = 1`
- `DEVICE_ID = -77`: Marks the mouse events this node makes, so it can tell them from a real mouse.

## Property descriptions

### active

`bool` `active` = `true`

Turn the cursor on or off. Off hides the ring and leaves all input alone.

### stick

`int` `stick` = `0`

Which stick moves the ring.

### device

`int` `device` = `-1`

Which controller: -1 listens to all of them.

### dead_zone

`float` `dead_zone` = `0.2`

Stick movement smaller than this is ignored.

### speed

`float` `speed` = `1.2`

Top speed, in screen heights per second, so it feels the same at any resolution.

### response_curve

`float` `response_curve` = `2.0`

Response curve: 1 = linear, higher = finer control near the middle of the stick, fast at full tilt.

### click_button

`int` `click_button` = `0`

Controller button that clicks under the ring (held = mouse button held).

### click_action

`StringName` `click_action` = `&"ui_accept"`

InputMap action that also clicks under the ring, for keys (Godot's ui_accept has Enter and Space, but no controller button). Empty: only `click_button` clicks.

### hover_slowdown

`float` `hover_slowdown` = `0.45`

Speed multiplier while over something clickable, so it's easy to stop on it (1 = no slowdown).

### snap_strength

`float` `snap_strength` = `0.5`

How hard the ring is pulled toward the center of the clickable thing under it (0 = off). The pull eases off while the stick is pushed, so it never fights the player.

### scroll_speed

`float` `scroll_speed` = `12.0`

The other stick scrolls whatever is under the ring. 0 turns it off.

### ring_size

`float` `ring_size` = `0.08`

Ring diameter as a fraction of the screen height.

### ring_color

`Color` `ring_color` = `Color(1, 1, 1, 0.9)`

Ring color at rest.

### hover_color

`Color` `hover_color` = `Color(1, 0.82, 0.4, 1)`

Ring color over something clickable.

### ring_texture

`Texture2D` `ring_texture`

Optional picture to use instead of the built-in ring (drawn at ring_size, tinted by the colors).

### hide_mouse_pointer

`bool` `hide_mouse_pointer` = `true`

Hide the system mouse pointer while the ring is shown.

### cursor_position

`Vector2` `cursor_position` = `Vector2(0, 0)`

Ring center, in the viewport's coordinates.

## Method descriptions

### is_shown

`bool` `is_shown()`

Whether the ring is on screen right now.

### warp_to

`void` `warp_to(point: Vector2)`

Moves the ring (viewport coordinates) and sends the matching mouse motion.

### get_hovered_control

`Control` `get_hovered_control()`

What is under the ring that it treats as clickable, or null.
