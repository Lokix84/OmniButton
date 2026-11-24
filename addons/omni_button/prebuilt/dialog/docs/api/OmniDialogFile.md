# OmniDialogFile

**Inherits:** `RefCounted`

Loads dialog JSON files and caches them.

## Description

A file holds many entries by key. An entry is a list of lines, or an object with `"lines"` plus entry-wide options:

```gdscript
{
  "gate":     [ { "type": "say", "name": "Guard", "text": "Halt!" } ],
  "tutorial": { "lines": [ { "type": "narrate", "text": "Welcome." } ] }
}
```

`res://` files are loaded as Godot `JSON` resources, so they work in exported games; `user://` files are read directly. [OmniDialogRunner](./OmniDialogRunner.md) uses this class; you only need it to list keys or clear the cache.

## Methods

| Returns | Method |
|---|---|
| `Dictionary` | [`load_file`](#load_file)(path: String) static |
| `Dictionary` | [`get_entry`](#get_entry)(path: String, key: String) static |
| `PackedStringArray` | [`get_keys`](#get_keys)(path: String) static |
| `void` | [`clear_cache`](#clear_cache)() static |

## Method descriptions

### load_file

`Dictionary` `load_file(path: String)` static

Returns the whole file at `path` as a Dictionary of entries, or an empty Dictionary (with an error printed) if it can't be read.

### get_entry

`Dictionary` `get_entry(path: String, key: String)` static

Returns one entry as `{ "lines": Array, "skippable": bool }`, or an empty Dictionary if the file or `key` is missing.

### get_keys

`PackedStringArray` `get_keys(path: String)` static

Returns every entry key in the file at `path`.

### clear_cache

`void` `clear_cache()` static

Forgets cached files. Call it after editing a dialog file while the game runs.
