# OmniSettings

**Inherits:** `RefCounted`

The game's player settings (volume, window mode, text speed...): defined once, saved to a file, and applied to the game whenever they change. Static: use it from anywhere, no node needed.

## Description

Each setting has a key (`"audio/music"`), a default, and optionally a function that applies it. The options screen ([OmniOptionsMenu](./OmniOptionsMenu.md)) builds its rows from these definitions, so a setting your game adds with `define()` shows up there with no extra UI work:

```gdscript
OmniSettings.define("gameplay/screen_shake", true, {
    "page": "Gameplay", "label": "Screen shake",
    "apply": func(on: bool): Camera.shake_enabled = on,
})
var shake: bool = OmniSettings.get_value("gameplay/screen_shake")
```

Settings are loaded and applied when the game starts by the `OmniMenus` autoload, or by the first menu that needs them (`ensure_loaded()`). They are saved to `user://settings.cfg` (**Project Settings > omni_button/menus/settings_path**).

## Methods

| Returns | Method |
|---|---|
| `void` | [`define`](#define)(key: String, default_value: Variant, options: Dictionary = {}) static |
| `bool` | [`has_setting`](#has_setting)(key: String) static |
| `Dictionary` | [`get_definition`](#get_definition)(key: String) static |
| `Dictionary[]` | [`get_definitions`](#get_definitions)(page: String) static |
| `PackedStringArray` | [`get_pages`](#get_pages)() static |
| `Variant` | [`get_value`](#get_value)(key: String, fallback: Variant = null) static |
| `void` | [`set_value`](#set_value)(key: String, value: Variant) static |
| `void` | [`watch`](#watch)(callback: Callable) static |
| `void` | [`unwatch`](#unwatch)(callback: Callable) static |
| `void` | [`reset_to_defaults`](#reset_to_defaults)(page: String = "") static |
| `String` | [`get_path`](#get_path)() static |
| `void` | [`load_settings`](#load_settings)(path: String = "") static |
| `void` | [`save`](#save)(path: String = "") static |
| `void` | [`ensure_loaded`](#ensure_loaded)() static |
| `void` | [`apply_all`](#apply_all)() static |

## Constants and enums

- enum **Kind**: `SLIDER = 0`: A 0-100 % slider (values 0 to 1, or `min` to `max`).
- enum **Kind**: `TOGGLE = 1`: On / Off.
- enum **Kind**: `CHOICE = 2`: One of a list (the `choices` option).
- `PATH_SETTING = "omni_button/menus/settings_path"`: Project Setting with the settings file path.
- `DEFAULT_PATH = "user://settings.cfg"`: Settings file used when the Project Setting is empty.

## Method descriptions

### define

`void` `define(key: String, default_value: Variant, options: Dictionary = {})` static

Adds a setting (or updates its definition; a value already set or loaded is kept). Defining a setting after the settings file was loaded (the usual case for your game's own settings) picks up its saved value and applies it. `options` (all optional):[br]- `page`: options-screen tab, e.g. `"Audio"`. Empty: not shown on the options screen.[br]- `label`: row text. Default: made from the key.[br]- `kind`: a `Kind`. Default: TOGGLE for bools, CHOICE when `choices` is given, otherwise SLIDER.[br]- `choices`: for CHOICE, an Array of `[label, value]` pairs.[br]- `min`, `max`, `step`: for SLIDER (default 0, 1, 0.05; shown as a percentage).[br]- `apply`: `Callable` called with the value whenever it is set or loaded.[br]- `hidden`: `true` keeps it off the options screen (e.g. a platform that can't use it).

### has_setting

`bool` `has_setting(key: String)` static

Whether `key` has been defined.

### get_definition

`Dictionary` `get_definition(key: String)` static

A setting's definition: the `options` passed to `define()`, plus `key`, `default`, `kind` and `label`.

### get_definitions

`Dictionary[]` `get_definitions(page: String)` static

Definitions shown on `page` of the options screen, in the order they were defined.

### get_pages

`PackedStringArray` `get_pages()` static

The options-screen pages, in the order their first setting was defined.

### get_value

`Variant` `get_value(key: String, fallback: Variant = null)` static

The current value of `key`, or `fallback` when it isn't defined.

### set_value

`void` `set_value(key: String, value: Variant)` static

Changes a setting and applies it. Call `save()` to keep it (the options screen saves when it closes).

### watch

`void` `watch(callback: Callable)` static

Calls `callback` with `(key, value)` whenever a setting changes.

### unwatch

`void` `unwatch(callback: Callable)` static

Stops calling `callback`.

### reset_to_defaults

`void` `reset_to_defaults(page: String = "")` static

Puts settings back to their defaults (only those on `page`, when given) and applies them.

### get_path

`String` `get_path()` static

The settings file path (**Project Settings > omni_button/menus/settings_path**).

### load_settings

`void` `load_settings(path: String = "")` static

Loads the settings file (missing values keep their defaults) and applies every setting.

### save

`void` `save(path: String = "")` static

Writes every setting to the settings file.

### ensure_loaded

`void` `ensure_loaded()` static

Loads and applies the settings the first time it is called; does nothing after that.

### apply_all

`void` `apply_all()` static

Applies every setting to the game (volumes, window, text speed, your own apply functions).
