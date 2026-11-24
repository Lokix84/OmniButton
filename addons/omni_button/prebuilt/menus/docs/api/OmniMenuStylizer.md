# OmniMenuStylizer

**Inherits:** `Node`

Turns a menu into the full-screen stylized version: put it as a child of an [OmniMenu](./OmniMenu.md) or [OmniOptionsMenu](./OmniOptionsMenu.md) scene. It colors `bands` from the look's **Stylized Menus** colors, sets the title and items in a bold slanted font, puts a slanted `OmniDialogTheme.accent_color` shape behind the selected item, and plays the entrance: the bands sweep in and the items appear one after another. The menu's own behavior (items, signals, input, pausing) is unchanged.

## Properties

| Type | Name | Default |
|---|---|---|
| [OmniMenuBands](./OmniMenuBands.md) | [`bands`](#bands) |  |
| `Label` | [`title_label`](#title_label) |  |
| `PanelContainer` | [`plate_panel`](#plate_panel) |  |
| `int` | [`title_size`](#title_size) | `84` |
| `int` | [`item_size`](#item_size) | `38` |
| `float` | [`slant`](#slant) | `0.2` |
| `float` | [`embolden`](#embolden) | `0.9` |
| `Vector2` | [`item_size_px`](#item_size_px) | `Vector2(380, 58)` |
| `float` | [`sweep_time`](#sweep_time) | `0.4` |
| `float` | [`stagger`](#stagger) | `0.05` |
| `float` | [`select_pop`](#select_pop) | `1.08` |

## Methods

| Returns | Method |
|---|---|
| `void` | [`apply_look`](#apply_look)() |

## Property descriptions

### bands

[OmniMenuBands](./OmniMenuBands.md) `bands`

The angled background.

### title_label

`Label` `title_label`

The menu title to set in the big slanted font. Optional.

### plate_panel

`PanelContainer` `plate_panel`

The panel to draw as a dark slanted plate (the options screen). Optional.

### title_size

`int` `title_size` = `84`

Size of the title text.

### item_size

`int` `item_size` = `38`

Size of the item text.

### slant

`float` `slant` = `0.2`

How far the text and the highlight lean (0 = upright).

### embolden

`float` `embolden` = `0.9`

How bold the default font is made (no effect with the look's own menu_font).

### item_size_px

`Vector2` `item_size_px` = `Vector2(380, 58)`

Width and height of each item.

### sweep_time

`float` `sweep_time` = `0.4`

Seconds for the bands to sweep in. The menu's animation_duration 0 skips all motion.

### stagger

`float` `stagger` = `0.05`

Delay between items appearing.

### select_pop

`float` `select_pop` = `1.08`

How much the selected item grows when it is selected.

## Method descriptions

### apply_look

`void` `apply_look()`

Re-applies the look's colors and fonts (called when the menu opens).
