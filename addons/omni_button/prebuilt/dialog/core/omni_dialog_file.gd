extends RefCounted
class_name OmniDialogFile
## loads dialog json files and caches them.
##
## a file holds a bunch of entries by key. an entry is a list of lines, or an object with [code]"lines"[/code] plus options for the whole entry:
## [codeblock]
## {
##   "gate":     [ { "type": "say", "name": "Guard", "text": "Halt!" } ],
##   "tutorial": { "lines": [ { "type": "narrate", "text": "Welcome." } ] }
## }
## [/codeblock]
## [code]res://[/code] files load as godot [JSON] resources so they work in exported games, [code]user://[/code] files get read straight off disk. [OmniDialogRunner] uses this, you only need it yourself to list keys or clear the cache.

static var _cache: Dictionary = {}

## returns the whole file at [param path] as a Dictionary of entries, or an empty one (and prints an error) if it can't be read.
static func load_file(path: String) -> Dictionary:
	if _cache.has(path):
		return _cache[path]
	var json: JSON
	if path.begins_with("res://") and ResourceLoader.exists(path, "JSON"):
		# godot imports res:// .json files as JSON resources and exported games only have the
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

## returns one entry as [code]{ "lines": Array, "skippable": bool }[/code], or an empty Dictionary if the file or [param key] isn't there.
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

## returns every entry key in the file at [param path].
static func get_keys(path: String) -> PackedStringArray:
	return PackedStringArray(load_file(path).keys())

## forgets the cached files. call it after editing a dialog file while the game's running.
static func clear_cache() -> void:
	_cache.clear()
