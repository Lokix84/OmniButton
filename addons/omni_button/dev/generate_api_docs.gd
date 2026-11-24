extends SceneTree
## Turns the doc comments in OmniButton's scripts into Markdown pages, so the reference can be read
## outside the editor (in the editor, press F1 and search a class name). Each system's pages go in
## its own folder: the button's in addons/omni_button/docs/api/, the dialog system's in
## addons/omni_button/prebuilt/dialog/docs/api/, the menus' in addons/omni_button/prebuilt/menus/docs/api/. Pages link to each other across folders.
##
## Run from the project folder, in two steps:
##   godot --headless --path . --doctool <temp_dir> --gdscript-docs res://addons/omni_button
##   godot --headless --path . -s res://addons/omni_button/dev/generate_api_docs.gd -- <temp_dir>

## One entry per system: where its pages go, the index title, and its classes by section, in index
## order. Internal helpers, demos and tests are left out. Add a system (menus, ...) here.
const SYSTEMS := [
	{
		"dir": "res://addons/omni_button/docs/api",
		"title": "OmniButton API reference",
		"sections": {
			"Button": ["Omni_Button", "OmniLabelAccessor", "OmniIconAccessor", "OmniBackgroundAccessor",
				"OmniPanelAccessor", "OmniOverlayAccessor", "OmniCooldownAccessor", "OmniChargeUpAccessor"],
			"Presets (prebuilt/buttons)": ["OmniJoystick", "OmniSwipePad", "OmniTypewriterButton", "OmniTabBar"],
			"Companion (prebuilt/cursor)": ["OmniVirtualCursor"],
		},
		"see_also": "Dialog windows built on OmniButton have their own reference: [dialog API reference](%s).",
		"see_also_dir": "res://addons/omni_button/prebuilt/dialog/docs/api",
	},
	{
		"dir": "res://addons/omni_button/prebuilt/dialog/docs/api",
		"title": "OmniButton dialog API reference",
		"sections": {
			"Dialog windows": ["OmniPopup", "OmniToast", "OmniDialogueBox", "OmniNarration"],
			"Dialog system": ["OmniDialogAutoload", "OmniDialogRunner", "OmniDialogFile", "OmniDialogValidator", "OmniDialogTheme",
				"OmniOverlay", "OmniTextWindow"],
		},
		"see_also": "The windows are built from [Omni_Button](%s); see the [OmniButton API reference](%s). Usage guide: [dialog README](%s).",
		"see_also_dir": "res://addons/omni_button/docs/api",
	},
	{
		"dir": "res://addons/omni_button/prebuilt/menus/docs/api",
		"title": "OmniButton menus API reference",
		"sections": {
			"Menus": ["OmniTitleMenu", "OmniPauseMenu", "OmniOptionsMenu", "OmniMenu"],
			"Stylized menus": ["OmniMenuStylizer", "OmniMenuBands", "OmniStaircaseContainer"],
			"Settings": ["OmniSettings", "OmniMenusAutoload"],
		},
		"see_also": "The menus are dialog windows underneath ([OmniOverlay](%s)), styled by the same looks; see the [dialog API reference](%s). Usage guide: [menus README](%s).",
		"see_also_dir": "res://addons/omni_button/prebuilt/dialog/docs/api",
	},
]

## Class name -> folder its page is in.
var _page_dir: Dictionary = {}
## Folder of the page being written, for relative links.
var _current_dir := ""

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("Pass the folder --doctool wrote to: -- <temp_dir>")
		quit(1)
		return
	var xml_dir: String = args[0]
	var classes := {}
	for f in DirAccess.get_files_at(xml_dir):
		if not f.ends_with(".xml"):
			continue
		var c := _parse_class(xml_dir.path_join(f))
		var short := _short_name(str(c.get("name", "")))
		classes[short] = c
	for system in SYSTEMS:
		for section in system["sections"]:
			for name in system["sections"][section]:
				_page_dir[name] = system["dir"]
	var written := 0
	for system in SYSTEMS:
		var dir: String = system["dir"]
		_current_dir = dir
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
		var index := PackedStringArray(["# " + system["title"], "",
			"Generated from the doc comments in the scripts by `addons/omni_button/dev/generate_api_docs.gd`. In the Godot editor, the same docs open with F1 (Search Help) or Ctrl+click on a class or method name.", ""])
		var other := _rel(dir, system["see_also_dir"]).path_join("README.md")
		if system["dir"].contains("prebuilt/dialog"):
			index.append(system["see_also"] % [_rel(dir, system["see_also_dir"]).path_join("Omni_Button.md"), other, _rel(dir, "res://addons/omni_button/prebuilt/dialog").path_join("README.md")])
		elif system["dir"].contains("prebuilt/menus"):
			index.append(system["see_also"] % [_rel(dir, system["see_also_dir"]).path_join("OmniOverlay.md"), other, _rel(dir, "res://addons/omni_button/prebuilt/menus").path_join("README.md")])
		else:
			index.append(system["see_also"] % other)
		index.append("")
		for section in system["sections"]:
			index.append("## " + section)
			index.append("")
			for name in system["sections"][section]:
				if not classes.has(name):
					push_warning("No docs found for %s" % name)
					continue
				var c: Dictionary = classes[name]
				_write(dir.path_join(name + ".md"), _page(name, c))
				index.append("- [%s](%s.md): %s" % [name, name, _inline(c.get("brief", ""))])
				written += 1
			index.append("")
		_write(dir.path_join("README.md"), "
".join(index))
	print("Wrote %d class pages" % written)
	quit(0)

## "addons/.../omni_button_accessors.gd".OmniLabelAccessor -> OmniLabelAccessor
func _short_name(name: String) -> String:
	if name.contains("\"."):
		return name.get_slice("\".", 1)
	return name.trim_prefix("\"").trim_suffix("\"")

#region XML

func _parse_class(path: String) -> Dictionary:
	var p := XMLParser.new()
	p.open(path)
	var c := {"brief": "", "description": "", "methods": [], "members": [], "signals": [], "constants": []}
	var stack: Array[String] = []
	var current: Dictionary = {}
	while p.read() == OK:
		match p.get_node_type():
			XMLParser.NODE_ELEMENT:
				var tag := p.get_node_name()
				var attrs := {}
				for i in p.get_attribute_count():
					attrs[p.get_attribute_name(i)] = p.get_attribute_value(i)
				match tag:
					"class":
						c["name"] = attrs.get("name", "")
						c["inherits"] = attrs.get("inherits", "")
					"method", "signal":
						current = {"name": attrs.get("name", ""), "params": [], "return": "void", "description": "", "qualifiers": attrs.get("qualifiers", "")}
						c["methods" if tag == "method" else "signals"].append(current)
					"member":
						var default_value: String = attrs.get("default", "")
						if default_value == "<unknown>":
							default_value = ""  # @onready nodes have no default to show
						current = {"name": attrs.get("name", ""), "type": attrs.get("type", ""), "default": default_value, "description": ""}
						c["members"].append(current)
					"constant":
						current = {"name": attrs.get("name", ""), "value": attrs.get("value", ""), "enum": attrs.get("enum", ""), "description": ""}
						c["constants"].append(current)
					"return":
						if not current.is_empty():
							current["return"] = attrs.get("type", "void")
					"param":
						if not current.is_empty():
							var t: String = attrs.get("type", "")
							var d: String = attrs.get("default", "")
							current["params"].append("%s%s%s" % [attrs.get("name", ""), (": " + t) if t != "" else "", (" = " + d) if d != "" else ""])
				if not p.is_empty():
					stack.append(tag)
			XMLParser.NODE_ELEMENT_END:
				var tag := p.get_node_name()
				if not stack.is_empty():
					stack.pop_back()
				if tag in ["method", "signal", "member", "constant"]:
					current = {}
			XMLParser.NODE_TEXT, XMLParser.NODE_CDATA:
				var text := p.get_node_data().strip_edges()
				if text == "" or stack.is_empty():
					continue
				var tag: String = stack.back()
				match tag:
					"brief_description":
						if stack.size() == 2:
							c["brief"] = text
					"description":
						if stack.size() == 2:
							c["description"] = text
						elif not current.is_empty():
							current["description"] = text
					"member", "constant":
						if not current.is_empty():
							current["description"] = text
	return c

#endregion

#region Markdown

func _page(name: String, c: Dictionary) -> String:
	var lines := PackedStringArray()
	lines.append("# " + name)
	lines.append("")
	var inherits: String = c.get("inherits", "")
	if inherits != "":
		lines.append("**Inherits:** " + _class_ref(_short_name(inherits)))
		lines.append("")
	if c["brief"] != "":
		lines.append(_inline(c["brief"]))
		lines.append("")
	if c["description"] != "":
		lines.append("## Description")
		lines.append("")
		lines.append(_block(c["description"]))
		lines.append("")
	var members := (c["members"] as Array).filter(func(m): return not str(m["name"]).begins_with("_"))
	if not members.is_empty():
		lines.append("## Properties")
		lines.append("")
		lines.append("| Type | Name | Default |")
		lines.append("|---|---|---|")
		for m in members:
			lines.append("| %s | [`%s`](#%s) | %s |" % [_type(m["type"]), m["name"], _anchor(m["name"]), ("`%s`" % m["default"]) if m["default"] != "" else ""])
		lines.append("")
	var methods := (c["methods"] as Array).filter(func(m): return not str(m["name"]).begins_with("_"))
	if not methods.is_empty():
		lines.append("## Methods")
		lines.append("")
		lines.append("| Returns | Method |")
		lines.append("|---|---|")
		for m in methods:
			lines.append("| %s | [`%s`](#%s)(%s)%s |" % [_type(m["return"]), m["name"], _anchor(m["name"]), ", ".join(m["params"]), (" " + m["qualifiers"]) if m["qualifiers"] != "" else ""])
		lines.append("")
	var signals := c["signals"] as Array
	if not signals.is_empty():
		lines.append("## Signals")
		lines.append("")
		for s in signals:
			lines.append("### %s(%s)" % [s["name"], ", ".join(s["params"])])
			lines.append("")
			if s["description"] != "":
				lines.append(_block(s["description"]))
				lines.append("")
	var constants := (c["constants"] as Array).filter(func(k): return not str(k["name"]).begins_with("_"))
	if not constants.is_empty():
		lines.append("## Constants and enums")
		lines.append("")
		for k in constants:
			var prefix: String = ("enum **%s**: " % k["enum"]) if k["enum"] != "" else ""
			lines.append("- %s`%s = %s`%s" % [prefix, k["name"], k["value"], (": " + _inline(k["description"])) if k["description"] != "" else ""])
		lines.append("")
	if not members.is_empty():
		lines.append("## Property descriptions")
		lines.append("")
		for m in members:
			lines.append("### %s" % m["name"])
			lines.append("")
			lines.append("%s `%s`%s" % [_type(m["type"]), m["name"], (" = `%s`" % m["default"]) if m["default"] != "" else ""])
			lines.append("")
			if m["description"] != "":
				lines.append(_block(m["description"]))
				lines.append("")
	if not methods.is_empty():
		lines.append("## Method descriptions")
		lines.append("")
		for m in methods:
			lines.append("### %s" % m["name"])
			lines.append("")
			lines.append("%s `%s(%s)`%s" % [_type(m["return"]), m["name"], ", ".join(m["params"]), (" " + m["qualifiers"]) if m["qualifiers"] != "" else ""])
			lines.append("")
			if m["description"] != "":
				lines.append(_block(m["description"]))
				lines.append("")
	return "\n".join(lines)

func _anchor(s: String) -> String:
	return s.to_lower().replace(" ", "-")

func _type(t: String) -> String:
	if t == "":
		return ""
	return _class_ref(_short_name(t))

func _class_ref(name: String) -> String:
	if _page_dir.has(name):
		return "[%s](%s)" % [name, _rel(_current_dir, _page_dir[name]).path_join(name + ".md")]
	return "`%s`" % name

## Relative path from folder `from` to folder `to` (both res:// paths), "." when they're the same.
static func _rel(from: String, to: String) -> String:
	var a := from.trim_prefix("res://").split("/", false)
	var b := to.trim_prefix("res://").split("/", false)
	var common := 0
	while common < a.size() and common < b.size() and a[common] == b[common]:
		common += 1
	var parts := PackedStringArray()
	for i in a.size() - common:
		parts.append("..")
	for i in range(common, b.size()):
		parts.append(b[i])
	return "/".join(parts) if not parts.is_empty() else "."

## A description that may contain [codeblock]s: code becomes fenced blocks, the rest inline Markdown.
func _block(text: String) -> String:
	var out := PackedStringArray()
	var rest := text
	while rest.contains("[codeblock]"):
		var a := rest.find("[codeblock]")
		var b := rest.find("[/codeblock]", a)
		if b == -1:
			break
		out.append(_inline(rest.substr(0, a)))
		var code := rest.substr(a + 11, b - a - 11).strip_edges()
		out.append("```gdscript\n" + code + "\n```")
		rest = rest.substr(b + 12)
	out.append(_inline(rest))
	var joined := "\n\n".join(Array(out).filter(func(s): return str(s).strip_edges() != ""))
	return joined

## Godot doc markup to Markdown.
func _inline(text: String) -> String:
	var s := text.strip_edges()
	var re := RegEx.new()
	re.compile("\\[code\\](.*?)\\[/code\\]")
	s = re.sub(s, "`$1`", true)
	re.compile("\\[b\\](.*?)\\[/b\\]")
	s = re.sub(s, "**$1**", true)
	re.compile("\\[i\\](.*?)\\[/i\\]")
	s = re.sub(s, "*$1*", true)
	re.compile("\\[param ([\\w]+)\\]")
	s = re.sub(s, "`$1`", true)
	re.compile("\\[(member|signal|constant|enum) ([\\w@.]+)\\]")
	s = re.sub(s, "`$2`", true)
	re.compile("\\[method ([\\w@.]+)\\]")
	s = re.sub(s, "`$1()`", true)
	re.compile("\\[([A-Z][\\w]*)\\]")
	var result := ""
	var last := 0
	for m in re.search_all(s):
		result += s.substr(last, m.get_start() - last) + _class_ref(m.get_string(1))
		last = m.get_end()
	result += s.substr(last)
	return result.replace("\n", "\n\n")

func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text.strip_edges() + "\n")
	f.close()

#endregion
