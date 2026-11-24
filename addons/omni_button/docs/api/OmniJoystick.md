# OmniJoystick

**Inherits:** `Control`

An on-screen joystick for touch and mouse, built from an [Omni_Button](./Omni_Button.md) in virtual-joystick mode.

## Description

The scene has three parts: this node (the area that reacts to touches), `Base` (the ring) and `Base/Thumb` (the [Omni_Button](./Omni_Button.md) that follows the finger). Read `axis`, connect `axis_changed`, or set the `action_*` properties so the joystick holds down InputMap actions and `Input.get_vector()` works as it does with a gamepad stick.

**Fixed** (`floating` off): the ring stays where you placed it; touching anywhere on it starts the joystick.[br]**Floating** (`floating` on): this node is a touch zone (for example the left half of the screen). The ring appears where the finger lands and hides again when it lifts.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`floating`](#floating) | `false` |
| `bool` | [`hide_when_idle`](#hide_when_idle) | `true` |
| `StringName` | [`action_left`](#action_left) | `&""` |
| `StringName` | [`action_right`](#action_right) | `&""` |
| `StringName` | [`action_up`](#action_up) | `&""` |
| `StringName` | [`action_down`](#action_down) | `&""` |
| `Vector2` | [`axis`](#axis) | `Vector2(0, 0)` |
| `Control` | [`base`](#base) |  |
| [Omni_Button](./Omni_Button.md) | [`thumb`](#thumb) |  |

## Methods

| Returns | Method |
|---|---|
| `bool` | [`is_active`](#is_active)() |

## Signals

### started()

The joystick started: a finger or the mouse went down on it.

### axis_changed(axis: Vector2)

The stick moved. `axis` goes from -1 to 1 on each axis (up is negative y), after the dead zone.

### ended()

The finger lifted. `axis` is back to zero.

## Property descriptions

### floating

`bool` `floating` = `false`

The ring appears where the finger lands, anywhere inside this node, instead of staying in place.

### hide_when_idle

`bool` `hide_when_idle` = `true`

Floating only: hide the ring while nobody is touching the zone.

### action_left

`StringName` `action_left` = `&""`

Held down with the stick's strength while it points left. Empty does nothing.

### action_right

`StringName` `action_right` = `&""`

Held down with the stick's strength while it points right. Empty does nothing.

### action_up

`StringName` `action_up` = `&""`

Held down with the stick's strength while it points up. Empty does nothing.

### action_down

`StringName` `action_down` = `&""`

Held down with the stick's strength while it points down. Empty does nothing.

### axis

`Vector2` `axis` = `Vector2(0, 0)`

Current stick position: -1 to 1 on each axis, zero when released.

### base

`Control` `base`

The ring. Its size sets how far the thumb can travel.

### thumb

[Omni_Button](./Omni_Button.md) `thumb`

The [Omni_Button](./Omni_Button.md) that follows the finger. Its joystick settings (dead zone, radius) live on it.

## Method descriptions

### is_active

`bool` `is_active()`

Whether a finger (or the mouse) is on the stick.
