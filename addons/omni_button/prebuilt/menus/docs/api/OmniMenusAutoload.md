# OmniMenusAutoload

**Inherits:** `Node`

The optional `OmniMenus` autoload: loads and applies the player's settings when the game starts, and opens the options screen from anywhere.

## Description

The menus work without it (each loads the settings when it first needs them); the autoload makes sure volumes, window mode and text speed are applied from the very first frame, even in a game that opens no menu before play. Turn it off with **Project Settings > omni_button/menus/enable_autoload**.

```gdscript
OmniMenus.open_options()
OmniMenus.setting_changed.connect(func(key, value): print(key, " = ", value))
```

## Methods

| Returns | Method |
|---|---|
| [OmniOptionsMenu](./OmniOptionsMenu.md) | [`open_options`](#open_options)() |
| `String` | [`scene_path`](#scene_path)(key: String) static |

## Signals

### setting_changed(key: String, value: Variant)

A setting changed (from the options screen or `OmniSettings.set_value()`).

## Constants and enums

- `SETTING_PREFIX = "omni_button/menus/"`: Project Setting prefix for the menu scenes.
- `DEFAULT_SCENES = {"options_scene": "res://addons/omni_button/prebuilt/menus/screens/omni_options_menu.tscn"}`: The prebuilt scene for each menu, used when its Project Setting is empty.
- `OPTIONS_LAYER = 30`: Layer of the options screen this autoload opens (above dialog windows and the pause menu).

## Method descriptions

### open_options

[OmniOptionsMenu](./OmniOptionsMenu.md) `open_options()`

Opens the options screen (created the first time). Returns it; await `OmniOverlay.closed` to wait for it.

### scene_path

`String` `scene_path(key: String)` static

Scene path for a menu (`key` is a key of `DEFAULT_SCENES`), from Project Settings or the prebuilt default.
