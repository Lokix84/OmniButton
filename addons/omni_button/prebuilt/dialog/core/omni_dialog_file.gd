extends RefCounted
class_name OmniDialogFile
## Loads dialog JSON files and caches them.
##
## A file holds many entries by key. An entry is a list of lines, or an object with [code]"lines"[/code] plus entry-wide options:
## [codeblock]
## {
##   "gate":     [ { "type": "say", "name": "Guard", "text": "Halt!" } ],
##   "tutorial": { "lines": [ { "type": "narrate", "text": "Welcome." } ] }
## }
## [/codeblock]
## [code]res://[/code] files are loaded as Godot [JSON] resources, so they work in exported games; [code]user://[/code] files are read directly. [OmniDialogRunner] uses this class; you only need it to list keys or clear the cache.

static var _cache: Dictionary = {}

## Returns the whole file at [param path] as a Dictionary of entries, or an empty Dictionary (with an error printed) if it can't be read.
static func load_file(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var json: JSON
	if path.begins_with("res://") and ResourceLoader.exists(path, "JSON"):
		# Godot imports res:// .json files as JSON resources, and exported games only contain the
		# imported version, so load it as a resource.
		json = load(path) as JSON
		if json == null:
			push_error("OmniDialog: %s could not be read as JSON (check the Output panel for the parse error)." % path)
			return {}
	else:
		if not FileAccess.file_exists(path):
			push_error("OmniDialog: dialog file not found: %s" % path)
			return {}
		json = JSON.new()
		if json.parse(FileAccess.get_file_as_string(path)) != OK:
			push_error("OmniDialog: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
			return {}
	if not json.data is Dictionary:
		push_error("OmniDialog: %s must contain a JSON object of entries." % path)
		return {}
	_cache[path] = json.data
	return json.data

## Returns one entry as [code]{ "lines": Array, "skippable": bool }[/code], or an empty Dictionary if the file or [param key] is missing.
static func get_entry(path: String, key: String) -> Dictionary:
	var entries := load_file(path)
	if entries.is_empty():
		return {}
	if not entries.has(key):
		push_error("OmniDialog: no entry '%s' in %s." % [key, path])
		return {}
	var raw: Variant = entries[key]
	if raw is Array:
		return {"lines": raw, "skippable": true}
	if raw is Dictionary and raw.get("lines") is Array:
		return {"lines": raw["lines"], "skippable": bool(raw.get("skippable", true))}
	push_error("OmniDialog: entry '%s' in %s must be a list of lines or an object with \"lines\"." % [key, path])
	return {}

## Returns every entry key in the file at [param path].
static func get_keys(path: String) -> PackedStringArray:
	return PackedStringArray(load_file(path).keys())

## Forgets cached files. Call it after editing a dialog file while the game runs.
static func clear_cache() -> void:
	_cache.clear()
