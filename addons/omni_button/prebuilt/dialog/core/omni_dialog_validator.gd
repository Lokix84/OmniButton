extends RefCounted
class_name OmniDialogValidator
## Checks dialog JSON files for mistakes before the game runs them.
##
## A typo in a dialog file (a [code]next[/code] that points to a missing entry, a question without an
## [code]id[/code], a misspelled field) doesn't stop the game: the line just behaves wrongly. This finds
## those problems and says where they are.
## [codeblock]
## var problems := OmniDialogValidator.check_file("res://story/chapter1.json")
## print(OmniDialogValidator.format_report("res://story/chapter1.json", problems))
## [/codeblock]
## In the editor, [b]Project > Tools > Check OmniButton dialog files[/b] checks every dialog file in the
## project and prints the report to the Output panel.
## Each problem is a Dictionary: [code]{ "severity": "error" or "warning", "entry": String,
## "line": int (1-based, 0 for the entry itself), "message": String }[/code]. Errors break the
## dialog; warnings are probably mistakes but might be on purpose.

## Fields each line type uses (besides [constant COMMON_FIELDS]).
const LINE_FIELDS := {
	"say": ["name", "text", "portrait", "side", "choices", "speed"],
	"narrate": ["text", "background", "choices", "speed"],
	"toast": ["text", "duration"],
	"alert": ["text", "title", "button"],
	"confirm": ["id", "text", "title", "yes", "no", "on_yes", "on_no"],
	"choice": ["text", "title", "choices"],
	"event": ["name", "args", "wait"],
	"wait": ["seconds"],
	"goto": ["next"],
	"end": [],
}
## Fields any line can have.
const COMMON_FIELDS := ["type", "if", "if_not", "set", "event"]
## Fields an option in a [code]choices[/code] group can have.
const OPTION_FIELDS := ["text", "value", "next", "set", "if", "if_not", "event"]
## Fields an entry written as an object can have.
const ENTRY_FIELDS := ["lines", "skippable"]

## Checks the dialog file at [param path] and returns its problems (empty when it's fine).
static func check_file(path: String) -> Array[Dictionary]:
	var problems: Array[Dictionary] = []
	var entries := OmniDialogFile.load_file(path)
	if entries.is_empty():
		_add(problems, "error", "", 0, "The file can't be read, isn't valid JSON, or has no entries (see the error above).")
		return problems
	var stored := _stored_ids(entries)
	for key in entries:
		var raw: Variant = entries[key]
		var lines: Variant = null
		if raw is Array:
			lines = raw
		elif raw is Dictionary:
			lines = raw.get("lines")
			for field in raw:
				if not field in ENTRY_FIELDS:
					_add(problems, "warning", key, 0, "Unknown entry field \"%s\"." % field)
			if raw.has("skippable") and not raw["skippable"] is bool:
				_add(problems, "error", key, 0, "\"skippable\" must be true or false.")
		if not lines is Array:
			_add(problems, "error", key, 0, "An entry must be a list of lines, or an object with a \"lines\" list.")
			continue
		if (lines as Array).is_empty():
			_add(problems, "warning", key, 0, "The entry has no lines.")
		for i in lines.size():
			_check_line(problems, entries, stored, str(key), i + 1, lines[i])
	return problems

## Checks every [code].json[/code] file under [param folder] that looks like a dialog file. Returns
## [code]{ path: problems }[/code] for each file checked.
static func check_folder(folder: String = "res://") -> Dictionary:
	var results := {}
	for path in _json_files(folder):
		if _looks_like_dialog(path):
			results[path] = check_file(path)
	return results

## Turns [param problems] into readable text, one problem per line.
static func format_report(path: String, problems: Array[Dictionary]) -> String:
	if problems.is_empty():
		return "%s: no problems found." % path
	var errors := problems.filter(func(p): return p["severity"] == "error").size()
	var lines := PackedStringArray(["%s: %d error(s), %d warning(s)" % [path, errors, problems.size() - errors]])
	for p in problems:
		var where: String = p["entry"]
		if where == "":
			where = "file"
		elif p["line"] > 0:
			where = "%s, line %d" % [p["entry"], p["line"]]
		lines.append("  %s  %s: %s" % ["ERROR  " if p["severity"] == "error" else "warning", where, p["message"]])
	return "\n".join(lines)

#region Lines

static func _check_line(problems: Array[Dictionary], entries: Dictionary, stored: Dictionary, key: String, n: int, line: Variant) -> void:
	if not line is Dictionary:
		_add(problems, "error", key, n, "A line must be an object like { \"type\": \"say\", \"text\": \"...\" }.")
		return
	var type := str(line.get("type", "say"))
	if not LINE_FIELDS.has(type):
		_add(problems, "error", key, n, "Unknown type \"%s\" (use %s)." % [type, ", ".join(LINE_FIELDS.keys())])
		return
	for field in line:
		if not field in LINE_FIELDS[type] and not field in COMMON_FIELDS:
			_add(problems, "warning", key, n, "Field \"%s\" isn't used by a \"%s\" line (a typo?)." % [field, type])
	# Required fields.
	if type in ["say", "narrate", "toast", "alert", "confirm", "choice"] and str(line.get("text", "")).strip_edges() == "":
		_add(problems, "warning" if type == "say" else "error", key, n, "\"%s\" line has no \"text\"." % type)
	match type:
		"confirm":
			if str(line.get("id", "")) == "":
				_add(problems, "warning", key, n, "confirm without an \"id\": the answer isn't stored.")
			for f in ["on_yes", "on_no"]:
				_check_jump(problems, entries, key, n, line.get(f), f)
		"choice":
			if not line.get("choices") is Dictionary:
				_add(problems, "error", key, n, "choice line needs \"choices\": { \"id\": ..., \"options\": [ ... ] }.")
		"event":
			if str(line.get("name", "")) == "":
				_add(problems, "error", key, n, "event line has no \"name\".")
			if line.has("args") and not line["args"] is Array:
				_add(problems, "error", key, n, "\"args\" must be a list.")
		"wait":
			if not (line.get("seconds") is float or line.get("seconds") is int):
				_add(problems, "error", key, n, "wait line needs \"seconds\" as a number.")
		"goto":
			if str(line.get("next", "")) == "":
				_add(problems, "error", key, n, "goto line has no \"next\".")
			else:
				_check_jump(problems, entries, key, n, line.get("next"), "next")
	if line.has("side") and not str(line["side"]) in ["left", "right"]:
		_add(problems, "error", key, n, "\"side\" must be \"left\" or \"right\".")
	for f in ["portrait", "background"]:
		if line.get(f) is String and line[f] != "" and not ResourceLoader.exists(line[f]):
			_add(problems, "error", key, n, "%s not found: %s" % [f, line[f]])
	if line.has("choices"):
		_check_choices(problems, entries, stored, key, n, line["choices"])
	_check_common(problems, stored, key, n, line)

static func _check_choices(problems: Array[Dictionary], entries: Dictionary, stored: Dictionary, key: String, n: int, group: Variant) -> void:
	if not group is Dictionary:
		_add(problems, "error", key, n, "\"choices\" must be an object: { \"id\": ..., \"options\": [ ... ] }.")
		return
	if str(group.get("id", "")) == "":
		_add(problems, "warning", key, n, "choices without an \"id\": the answer isn't stored.")
	var options: Variant = group.get("options")
	if not options is Array or (options as Array).is_empty():
		_add(problems, "error", key, n, "choices need a non-empty \"options\" list.")
		return
	for i in options.size():
		var o: Variant = options[i]
		if o is String:
			continue
		if not o is Dictionary:
			_add(problems, "error", key, n, "Option %d must be text or an object." % (i + 1))
			continue
		if str(o.get("text", "")) == "":
			_add(problems, "error", key, n, "Option %d has no \"text\"." % (i + 1))
		for field in o:
			if not field in OPTION_FIELDS:
				_add(problems, "warning", key, n, "Option %d: field \"%s\" isn't used by options (a typo?)." % [i + 1, field])
		_check_jump(problems, entries, key, n, o.get("next"), "option %d next" % (i + 1))
		_check_common(problems, stored, key, n, o)

## Conditions, set and event, shared by lines and options.
static func _check_common(problems: Array[Dictionary], stored: Dictionary, key: String, n: int, item: Dictionary) -> void:
	for f in ["if", "if_not"]:
		if not item.has(f):
			continue
		if not item[f] is Dictionary:
			_add(problems, "error", key, n, "\"%s\" must be an object like { \"id\": value }." % f)
			continue
		for id in item[f]:
			if not stored.has(id):
				_add(problems, "warning", key, n, "\"%s\" checks \"%s\", which nothing in this file stores (fine if game code sets it)." % [f, id])
	if item.has("set") and not item["set"] is Dictionary:
		_add(problems, "error", key, n, "\"set\" must be an object like { \"id\": value }.")
	if item.has("event"):
		var e: Variant = item["event"]
		if not (e is String or (e is Dictionary and str(e.get("name", "")) != "")):
			_add(problems, "error", key, n, "\"event\" must be a name or { \"name\": ..., \"args\": [ ... ] }.")

static func _check_jump(problems: Array[Dictionary], entries: Dictionary, key: String, n: int, target: Variant, label: String) -> void:
	if target == null or str(target) == "":
		return
	if not entries.has(str(target)):
		_add(problems, "error", key, n, "%s points to \"%s\", which isn't an entry in this file." % [label, target])

## Every id a question or `set` in the file stores.
static func _stored_ids(entries: Dictionary) -> Dictionary:
	var ids := {}
	var visit := func(item: Variant, visit: Callable) -> void:
		if item is Dictionary:
			if item.get("set") is Dictionary:
				for id in item["set"]:
					ids[str(id)] = true
			if item.get("type") == "confirm" and str(item.get("id", "")) != "":
				ids[str(item["id"])] = true
			if item.get("choices") is Dictionary and str(item["choices"].get("id", "")) != "":
				ids[str(item["choices"]["id"])] = true
			for v in item.values():
				visit.call(v, visit)
		elif item is Array:
			for v in item:
				visit.call(v, visit)
	visit.call(entries, visit)
	return ids

#endregion

#region Files

static func _json_files(folder: String) -> PackedStringArray:
	var out := PackedStringArray()
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	for f in dir.get_files():
		if f.ends_with(".json"):
			out.append(folder.path_join(f))
	for d in dir.get_directories():
		if d.begins_with("."):
			continue
		out.append_array(_json_files(folder.path_join(d)))
	return out

## A dialog file is a JSON object whose values are lists of objects with a "type", or {"lines": ...}.
static func _looks_like_dialog(path: String) -> bool:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary or (data as Dictionary).is_empty():
		return false
	for v in data.values():
		var lines: Variant = v if v is Array else (v.get("lines") if v is Dictionary else null)
		if lines is Array:
			for line in lines:
				if line is Dictionary and line.has("type"):
					return true
	return false

static func _add(problems: Array[Dictionary], severity: String, entry: String, line: int, message: String) -> void:
	problems.append({"severity": severity, "entry": entry, "line": line, "message": message})

#endregion
