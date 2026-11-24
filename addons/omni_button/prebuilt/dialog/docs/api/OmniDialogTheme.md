# OmniDialogTheme

**Inherits:** `Resource`

One complete look for the dialog windows.

## Description

A look styles every window at once. `theme` is an ordinary Godot `Theme`, applied to each window's `%Root`: it styles the window panels (`PanelContainer`), text (`Label`, `RichTextLabel`), fonts, and these type variations: `OmniDialogTitle` (popup titles), `OmniDialogName` (speaker names), `OmniDialogIndicator` (the blinking continue marker) and `OmniDialogToast` (each toast). The other properties style the `Omni_Button` parts a Godot Theme can't reach: option buttons, and the text of the dialogue box, narration, popup message and toasts. Inside the windows, the look always wins over styles set in the `parts/` scenes. Which look a window uses: its own `OmniOverlay.dialog_theme` if set, otherwise **Project Settings > omni_button/dialog/theme** (`omni_dialog_modern.tres` by default). `OmniDialogAutoload.set_dialog_theme()` switches the autoload's windows at runtime. To make a look, duplicate a file in `themes/`, drag it into `demo/omni_dialog_demo.tscn`'s `Your Look`, run the demo and pick it with the Look button. Edit and save the file: the running demo reloads it when you click back into it.

## Properties

| Type | Name | Default |
|---|---|---|
| `Theme` | [`theme`](#theme) |  |
| `StyleBox` | [`option_normal`](#option_normal) |  |
| `StyleBox` | [`option_hover`](#option_hover) |  |
| `StyleBox` | [`option_pressed`](#option_pressed) |  |
| `StyleBox` | [`option_focus`](#option_focus) |  |
| `StyleBox` | [`option_disabled`](#option_disabled) |  |
| `Color` | [`option_text_color`](#option_text_color) | `Color(0.94, 0.95, 0.97, 1)` |
| `Font` | [`option_font`](#option_font) |  |
| `float` | [`option_height`](#option_height) | `44.0` |
| `int` | [`option_max_font_size`](#option_max_font_size) | `22` |
| `int` | [`option_min_font_size`](#option_min_font_size) | `14` |
| `bool` | [`option_wrap`](#option_wrap) | `true` |
| `Vector2` | [`option_text_padding`](#option_text_padding) | `Vector2(12, 2)` |
| `Color` | [`text_color`](#text_color) | `Color(0.94, 0.95, 0.97, 1)` |
| `Font` | [`text_font`](#text_font) |  |
| `Color` | [`accent_color`](#accent_color) | `Color(0.36, 0.55, 0.9, 1)` |
| `Color` | [`accent_text_color`](#accent_text_color) | `Color(1, 1, 1, 1)` |
| `Color` | [`menu_background_color`](#menu_background_color) | `Color(0.05, 0.06, 0.09, 1)` |
| `Color` | [`menu_band_color`](#menu_band_color) | `Color(0.11, 0.15, 0.25, 1)` |
| `Color` | [`menu_text_color`](#menu_text_color) | `Color(0.94, 0.95, 0.97, 1)` |
| `Font` | [`menu_font`](#menu_font) |  |

## Methods

| Returns | Method |
|---|---|
| [OmniDialogTheme](./OmniDialogTheme.md) | [`get_default`](#get_default)() static |
| `void` | [`style_option`](#style_option)(button: Control) |
| `void` | [`fit_option_group`](#fit_option_group)(buttons: Control[]) |
| `void` | [`style_text`](#style_text)(body: Control) |

## Constants and enums

- `SETTING = "omni_button/dialog/theme"`: Project Setting that holds the project-wide look.
- `DEFAULT_PATH = "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres"`: The look used when the Project Setting is empty.
- `OPTION_TEXT_MARGIN = 6.0`: Room kept above and below option text when an option grows to fit it.

## Property descriptions

### theme

`Theme` `theme`

Godot `Theme` for panels, labels, fonts and the `OmniDialog*` type variations.

### option_normal

`StyleBox` `option_normal`

Option button style when idle.

### option_hover

`StyleBox` `option_hover`

Option button style under the mouse.

### option_pressed

`StyleBox` `option_pressed`

Option button style while pressed.

### option_focus

`StyleBox` `option_focus`

Option button style when it has keyboard / gamepad focus.

### option_disabled

`StyleBox` `option_disabled`

Option button style when disabled.

### option_text_color

`Color` `option_text_color` = `Color(0.94, 0.95, 0.97, 1)`

Text color of option buttons.

### option_font

`Font` `option_font`

Empty uses the theme's default font.

### option_height

`float` `option_height` = `44.0`

Normal height of an option button. Options with more text grow taller.

### option_max_font_size

`int` `option_max_font_size` = `22`

Largest font size option text grows to.

### option_min_font_size

`int` `option_min_font_size` = `14`

Smallest font size option text shrinks to. Text that still doesn't fit makes that option taller.

### option_wrap

`bool` `option_wrap` = `true`

Long option text wraps onto more lines before it shrinks.

### option_text_padding

`Vector2` `option_text_padding` = `Vector2(12, 2)`

Space kept between option text and the button's edges (left/right, top/bottom).

### text_color

`Color` `text_color` = `Color(0.94, 0.95, 0.97, 1)`

Text color of the dialogue box and narration body.

### text_font

`Font` `text_font`

Empty uses the theme's default font.

### accent_color

`Color` `accent_color` = `Color(0.36, 0.55, 0.9, 1)`

The full-screen stylized menus (`prebuilt/menus/screens/*_stylized.tscn`): the shape behind the selected item and the thin stripes.

### accent_text_color

`Color` `accent_text_color` = `Color(1, 1, 1, 1)`

Text color of the selected item, on top of `accent_color`.

### menu_background_color

`Color` `menu_background_color` = `Color(0.05, 0.06, 0.09, 1)`

The screen behind the stylized menus.

### menu_band_color

`Color` `menu_band_color` = `Color(0.11, 0.15, 0.25, 1)`

The big angled bands of the stylized menus.

### menu_text_color

`Color` `menu_text_color` = `Color(0.94, 0.95, 0.97, 1)`

Text color of the items that aren't selected.

### menu_font

`Font` `menu_font`

Font of the stylized menus' title and items. Empty: the theme's default font, made bold and slanted.

## Method descriptions

### get_default

[OmniDialogTheme](./OmniDialogTheme.md) `get_default()` static

Returns the project-wide look (**Project Settings > omni_button/dialog/theme**), loaded once.

### style_option

`void` `style_option(button: Control)`

Applies the option button settings to `button` (an `Omni_Button`).

### fit_option_group

`void` `fit_option_group(buttons: Control[])`

Gives a group of options (one question's answers, or one popup's buttons) a single font size: the largest at which every option fits, never below `option_min_font_size`. An option whose text still doesn't fit is made taller. Waits a few frames for layout, so call it after the buttons are in the tree.

### style_text

`void` `style_text(body: Control)`

Applies the text body settings (`text_color`, `text_font`) to `body` (an `Omni_Button`).
