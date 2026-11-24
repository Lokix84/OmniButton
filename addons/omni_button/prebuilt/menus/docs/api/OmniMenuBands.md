# OmniMenuBands

**Inherits:** `Control`

The angled background of the stylized menus: bold slanted bands with a thin accent stripe, drawn in code so they stay sharp at any size. `progress` sweeps them in (0 = off screen to the left, 1 = in place); [OmniMenuStylizer](./OmniMenuStylizer.md) animates it when the menu opens and closes.

## Properties

| Type | Name | Default |
|---|---|---|
| `int` | [`shape`](#shape) | `0` |
| `Color` | [`background_color`](#background_color) | `Color(0.05, 0.06, 0.09, 1)` |
| `Color` | [`band_color`](#band_color) | `Color(0.11, 0.15, 0.25, 1)` |
| `Color` | [`accent_color`](#accent_color) | `Color(0.36, 0.55, 0.9, 1)` |
| `float` | [`progress`](#progress) | `1.0` |

## Constants and enums

- enum **Shape**: `FULL = 0`: Covers the whole screen: a solid background crossed by slanted bands (title, options).
- enum **Shape**: `SPLIT = 1`: A slanted plate over the left part of the screen; the rest stays see-through (pause).

## Property descriptions

### shape

`int` `shape` = `0`

### background_color

`Color` `background_color` = `Color(0.05, 0.06, 0.09, 1)`

### band_color

`Color` `band_color` = `Color(0.11, 0.15, 0.25, 1)`

### accent_color

`Color` `accent_color` = `Color(0.36, 0.55, 0.9, 1)`

### progress

`float` `progress` = `1.0`

How far the bands have swept in: 0 = gone, 1 = in place.
