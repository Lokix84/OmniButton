# OmniOptionsMenu

**Inherits:** [OmniOverlay](../../../dialog/docs/api/OmniOverlay.md)

The options screen: one tab per settings page, one row per setting, built from [OmniSettings](./OmniSettings.md).

## Description

Rows come from the setting definitions, so settings your game adds with `OmniSettings.define()` (with a `page`) appear here on their own. Changes apply at once; they are saved when the screen closes.

Controls: the d-pad / arrows move between rows. On a slider, left / right changes it; on a choice or an On / Off row, left / right steps through the values and confirm steps forward. The shoulder buttons switch tabs. Cancel or **Back** closes.

## Properties

| Type | Name | Default |
|---|---|---|
| `String` | [`title`](#title) | `"Options"` |
| `float` | [`control_width`](#control_width) | `260.0` |
| `PackedScene` | [`option_button_scene`](#option_button_scene) | `<Object>` |
| `Label` | [`title_label`](#title_label) | `get_node_or_null(...)` |
| [OmniTabBar](../../../../docs/api/OmniTabBar.md) | [`tabs`](#tabs) |  |
| `Container` | [`pages`](#pages) |  |
| [Omni_Button](../../../../docs/api/Omni_Button.md) | [`back_button`](#back_button) |  |
| [Omni_Button](../../../../docs/api/Omni_Button.md) | [`reset_button`](#reset_button) |  |

## Methods

| Returns | Method |
|---|---|
| `void` | [`rebuild`](#rebuild)() |
| `String` | [`get_current_page`](#get_current_page)() |
| `Control` | [`get_control`](#get_control)(key: String) |

## Signals

### setting_changed(key: String, value: Variant)

A setting was changed on this screen.

## Property descriptions

### title

`String` `title` = `"Options"`

Text at the top. Empty hides it.

### control_width

`float` `control_width` = `260.0`

Width of the control on the right of each row (slider, choice, On / Off).

### option_button_scene

`PackedScene` `option_button_scene` = `<Object>`

Button scene used for tabs, choices and On / Off rows (styled by the look).

### title_label

`Label` `title_label` = `get_node_or_null(...)`

The `Label` showing `title`.

### tabs

[OmniTabBar](../../../../docs/api/OmniTabBar.md) `tabs`

The tab row ([OmniTabBar](../../../../docs/api/OmniTabBar.md)); built from the settings pages.

### pages

`Container` `pages`

The container holding one page per tab.

### back_button

[Omni_Button](../../../../docs/api/Omni_Button.md) `back_button`

The button that closes the screen.

### reset_button

[Omni_Button](../../../../docs/api/Omni_Button.md) `reset_button`

The button that puts the current page back to its defaults.

## Method descriptions

### rebuild

`void` `rebuild()`

Rebuilds the tabs and rows from the current definitions and values.

### get_current_page

`String` `get_current_page()`

The page name of the tab that is showing.

### get_control

`Control` `get_control(key: String)`

The control showing setting `key` (an `HSlider` or an [Omni_Button](../../../../docs/api/Omni_Button.md)), or `null`.
