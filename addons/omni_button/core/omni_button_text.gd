@tool
extends RefCounted
class_name OmniButtonText
## Label text, BBCode handling and font autosizing (with a fit cache shared by all buttons).
## Static: every function takes the button as its first argument (_o).

static func invalidate_autosize_state(_o: Omni_Button) -> void:
	_o._fit_cache_sig = []
	_o._last_fit_font_size = -1
	_o._rich_current_font_size = -1
	_o._rich_verify_passes = 0

const BBCODE_KNOWN_TAGS := {
	"b": true,
	"i": true,
	"u": true,
	"s": true,
	"code": true,
	"url": true,
	"color": true,
	"center": true,
	"left": true,
	"right": true,
	"p": true,
	"br": true,
	"wave": true,
	"rainbow": true,
	"tornado": true,
	"pulse": true,
	"shake": true,
	"fade": true,
	"font": true,
	"img": true,
	"table": true,
	"cell": true,
	"ol": true,
	"ul": true,
	"li": true,
	"indent": true,
	"quote": true
}
const BBCODE_BREAK_TAGS := {
	"br": true,
	"p": true
}

static func set_label_text(_o: Omni_Button) -> void:
	if _o._label_type == _o.LabelKind.None:
		for node in [_o._label, _o._rich_label]:
			if node != null and is_instance_valid(node):
				var parent: Node = node.get_parent()
				if parent != null and is_instance_valid(parent):
					parent.remove_child(node)
				node.queue_free()
		_o._label = null
		_o._rich_label = null
		return
	var display_text := _o._text
	if _o._tw_active:
		# Reveal progress lives in visible_characters (re-applied below), not in the string.
		display_text = _o._typewriter.display_text
	# Remove both if empty unless a selected label or pending typewriter needs a node.
	# A RichTextLabel with no Text yet keeps its node, and so does any label during a typewriter reveal.
	# (The typewriter's text fields are only non-empty while _tw_active is true.)
	if display_text == "":
		var need_label := _o._tw_active or (_o._label_type == _o.LabelKind.RichTextLabel)
		if not need_label:
			if _o._label != null and is_instance_valid(_o._label):
				var p1 := _o._label.get_parent(); if p1 != null and is_instance_valid(p1): p1.remove_child(_o._label)
				_o._label.queue_free(); _o._label = null
			if _o._rich_label != null and is_instance_valid(_o._rich_label):
				var p2 := _o._rich_label.get_parent(); if p2 != null and is_instance_valid(p2): p2.remove_child(_o._rich_label)
				_o._rich_label.queue_free(); _o._rich_label = null
			return
	# Create one based on LabelType.
	if _o._label_type == _o.LabelKind.Label:
		if _o._rich_label != null and is_instance_valid(_o._rich_label):
			var pr := _o._rich_label.get_parent(); if pr != null and is_instance_valid(pr): pr.remove_child(_o._rich_label)
			_o._rich_label.queue_free(); _o._rich_label = null
		if _o._label == null or not is_instance_valid(_o._label):
			_o._label = Label.new(); _o._label.name = "Label"; OmniButtonVisuals.managed_add_child(_o, _o._label)
	elif _o._label_type == _o.LabelKind.RichTextLabel:
		if _o._label != null and is_instance_valid(_o._label):
			var pl := _o._label.get_parent(); if pl != null and is_instance_valid(pl): pl.remove_child(_o._label)
			_o._label.queue_free(); _o._label = null
		if _o._rich_label == null or not is_instance_valid(_o._rich_label):
			_o._rich_label = RichTextLabel.new(); _o._rich_label.name = "RichLabel"; OmniButtonVisuals.managed_add_child(_o, _o._rich_label)
	# Configure once here (new or existing label); layout_content() would only repeat this.
	if _o._label != null and is_instance_valid(_o._label): OmniButtonVisuals.configure_label(_o, _o._label)
	if _o._rich_label != null and is_instance_valid(_o._rich_label): OmniButtonVisuals.configure_rich_label(_o, _o._rich_label)
	# Text after configure, so a new RichTextLabel parses it once with the right bbcode setting.
	if _o._label != null and is_instance_valid(_o._label): _o._label.text = display_text
	if _o._rich_label != null and is_instance_valid(_o._rich_label): _o._rich_label.text = display_text
	var shown := _o._typewriter.visible_chars if _o._tw_active else -1
	if _o._label != null and is_instance_valid(_o._label): _o._label.visible_characters = shown
	if _o._rich_label != null and is_instance_valid(_o._rich_label): _o._rich_label.visible_characters = shown

## Autosize cache must track the string actually shown on the label (typewriter updates the label, not _o._text).
static func _text_for_fit_signature(_o: Omni_Button) -> String:
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		return _o._rich_label.text
	if _o._label != null and is_instance_valid(_o._label):
		return _o._label.text
	return _o._text

static func fit_label_text(_o: Omni_Button) -> void:
	if _o._fitting_label or _o._tw_active:
		return
	# Typed values compared element-wise: no str()/format work on every resize/refit check.
	# Covers every input the fit depends on, so runtime refit frames are free when nothing changed.
	# The label instance ids matter: setup_children() can replace the Label/RichTextLabel with a fresh
	# node (theme-default font size) while text and size stay identical.
	var label_id := _o._label.get_instance_id() if (_o._label != null and is_instance_valid(_o._label)) else 0
	var rich_id := _o._rich_label.get_instance_id() if (_o._rich_label != null and is_instance_valid(_o._rich_label)) else 0
	var sig := [
		label_id, rich_id,
		_text_for_fit_signature(_o), _o.size, _o.LabelPadding,
		_o.LabelAdditionalPaddingLeft, _o.LabelAdditionalPaddingTop, _o.LabelAdditionalPaddingRight, _o.LabelAdditionalPaddingBottom,
		_o.LabelAutowrap, _o.FixedFontSize, _o._label_type,
		_o.MinFontSize, _o.MaxFontSize, _o.TextFitPadding, _o.LabelFont, _o.EnableTextAutoSize
	]
	if sig == _o._fit_cache_sig:
		return
	if _o._dbg: _o._debug("Autosize begin size=%s type=%s wrap=%s text='%s'" % [str(_o.size), str(_o.LabelType), str(_o.LabelAutowrap), _text_for_fit_signature(_o)])
	if _o.FixedFontSize > 0:
		if _o._label != null and is_instance_valid(_o._label):
			set_plain_font(_o, null, _o.FixedFontSize)
		if _o._rich_label != null and is_instance_valid(_o._rich_label):
			apply_rich_label_font_sizes(_o, _o.FixedFontSize)
			_o._rich_label.update_minimum_size()
		_o._last_fit_font_size = _o.FixedFontSize
		_o._rich_current_font_size = _o.FixedFontSize
		_o._fit_cache_sig = sig
		return
	if not _o.EnableTextAutoSize:
		return
	_o._fitting_label = true
	var did_fit := false
	if _o._rich_label != null and is_instance_valid(_o._rich_label) and _o._rich_label.text != "":
		did_fit = _fit_rich_text_label(_o)
	elif _o._label != null and is_instance_valid(_o._label) and _o._label.text != "":
		did_fit = _fit_plain_label(_o)
	_o._fitting_label = false
	if did_fit:
		_o._fit_cache_sig = sig
	else:
		_o._fit_cache_sig = []

static func _fit_plain_label_uncached(_o: Omni_Button) -> bool:
	var wrap_enabled := _o.LabelAutowrap != TextServer.AUTOWRAP_OFF
	var avail := calculate_available_area(_o)
	if avail.x <= 1.0 or avail.y <= 1.0:
		# Resize notifications and runtime refit retry after layout assigns a usable size.
		return false
	if _o._label == null or not is_instance_valid(_o._label):
		return false
	var fnt: Font = _o._label.get_theme_font("font") if _o._label.get_theme_font("font") != null else ThemeDB.fallback_font
	if fnt == null:
		return false
	var wrap_w := avail.x if wrap_enabled else -1.0
	var text := _o._label.text
	if _o._last_fit_font_size > 0:
		var sz0 := _measure_paragraph(_o, fnt, text, wrap_w, _o._last_fit_font_size)
		if _fits_within(_o, sz0, avail, wrap_enabled):
			var grown := grow_font_size(_o, fnt, text, avail, wrap_w, wrap_enabled, _o._last_fit_font_size)
			set_plain_font(_o, fnt, grown)
			_o._last_fit_font_size = grown
			if _o._dbg: _o._debug("Autosize plain fast -> %d" % grown)
			return true
		var s := _o._last_fit_font_size
		var guard := 0
		while s > _o.MinFontSize and guard < 16:
			s -= 1
			var sz1 := _measure_paragraph(_o, fnt, text, wrap_w, s)
			if _fits_within(_o, sz1, avail, wrap_enabled):
				set_plain_font(_o, fnt, s)
				_o._last_fit_font_size = s
				return true
			guard += 1
	var best := find_best_font_size(_o, fnt, text, avail, wrap_w, wrap_enabled)
	best = grow_font_size(_o, fnt, text, avail, wrap_w, wrap_enabled, best)
	set_plain_font(_o, fnt, best)
	var guard2 := 0
	while best > _o.MinFontSize and guard2 < 64:
		var sz := _measure_paragraph(_o, fnt, text, wrap_w, best)
		if _fits_within(_o, sz, avail, wrap_enabled):
			break
		best -= 1
		set_plain_font(_o, fnt, best)
		guard2 += 1
	_o._last_fit_font_size = best
	if _o._dbg: _o._debug("Autosize plain fitted size=%d avail=%s" % [best, str(avail)])
	return true

static func _fit_rich_text_label_uncached(_o: Omni_Button) -> bool:
	# Measure paragraphs during search/grow without mutating RichTextLabel in the binary search.
	var wrap_enabled := _o.LabelAutowrap != TextServer.AUTOWRAP_OFF
	var avail := calculate_available_area(_o)
	if avail.x <= 1.0 or avail.y <= 1.0:
		# Resize notifications and runtime refit retry after layout assigns a usable size.
		return false
	if _o._rich_label == null or not is_instance_valid(_o._rich_label):
		return false
	var fnt: Font = get_rich_fit_font(_o)
	if fnt == null:
		return false
	var plain := strip_bbcode(_o, _o._rich_label.text)
	var wrap_w := avail.x if wrap_enabled else -1.0
	var seed := _o._rich_current_font_size if _o._rich_current_font_size > 0 else _o._last_fit_font_size
	if seed > 0:
		var sz0 := _measure_paragraph(_o, fnt, plain, wrap_w, seed)
		if _fits_within(_o, sz0, avail, wrap_enabled):
			var grown := grow_font_size(_o, fnt, plain, avail, wrap_w, wrap_enabled, seed)
			apply_rich_label_font_sizes(_o, grown)
			_o._rich_label.update_minimum_size()
			_o._rich_label.queue_redraw()
			_o._rich_current_font_size = grown
			_o._last_fit_font_size = grown
			if _o._dbg: _o._debug("Autosize rich fast -> %d" % grown)
			return true
		var s := seed
		var guard := 0
		while s > _o.MinFontSize and guard < 16:
			s -= 1
			var sz1 := _measure_paragraph(_o, fnt, plain, wrap_w, s)
			if _fits_within(_o, sz1, avail, wrap_enabled):
				apply_rich_label_font_sizes(_o, s)
				_o._rich_label.update_minimum_size()
				_o._rich_label.queue_redraw()
				_o._rich_current_font_size = s
				_o._last_fit_font_size = s
				return true
			guard += 1
	var best := find_best_font_size(_o, fnt, plain, avail, wrap_w, wrap_enabled)
	best = grow_font_size(_o, fnt, plain, avail, wrap_w, wrap_enabled, best)
	apply_rich_label_font_sizes(_o, best)
	_o._rich_label.update_minimum_size()
	_o._rich_label.queue_redraw()
	_o._rich_current_font_size = best
	# Quickly reject text that exceeds the available height or paragraph width.
	var guard_r := 0
	while best > _o.MinFontSize and guard_r < 32:
		var over_h := _rich_height_exceeds_avail(_o, avail.y, fnt, plain, wrap_w, best)
		var sz_chk := _measure_paragraph(_o, fnt, plain, wrap_w, best)
		var over_w := not _fits_within(_o, sz_chk, avail, wrap_enabled) and sz_chk.x > avail.x
		if not over_h and not over_w:
			break
		best -= 1
		apply_rich_label_font_sizes(_o, best)
		_o._rich_label.update_minimum_size()
		_o._rich_label.queue_redraw()
		_o._rich_current_font_size = best
		guard_r += 1
	_o._last_fit_font_size = _o._rich_current_font_size
	if _o._dbg: _o._debug("Autosize rich fitted size=%d avail=%s" % [_o._rich_current_font_size, str(avail)])
	_o._rich_verify_passes = 0
	_o.call_deferred("_verify_rich_text_fit")
	return true

static func verify_rich_text_fit(_o: Omni_Button) -> void:
	if _o._rich_label == null or not is_instance_valid(_o._rich_label):
		return
	var avail := calculate_available_area(_o)
	avail = Vector2(max(1.0, avail.x - 2.0), max(1.0, avail.y - 2.0))
	if avail.x <= 1.0 or avail.y <= 1.0:
		return
	var fnt: Font = get_rich_fit_font(_o)
	if fnt == null:
		return
	var plain := strip_bbcode(_o, _o._rich_label.text)
	var wrap_enabled := _o.LabelAutowrap != TextServer.AUTOWRAP_OFF
	var wrap_w := avail.x if wrap_enabled else -1.0
	var size_px := _o._rich_current_font_size if _o._rich_current_font_size > 0 else _o.MinFontSize
	var guard := 0
	_o._rich_label.update_minimum_size()
	_o._rich_label.queue_redraw()
	while size_px > _o.MinFontSize and guard < 64:
		var over_h := _rich_height_exceeds_avail(_o, avail.y, fnt, plain, wrap_w, size_px)
		var measured := _measure_paragraph(_o, fnt, plain, wrap_w, size_px)
		var over_w := not _fits_within(_o, measured, avail, wrap_enabled)
		if not over_h and not over_w:
			break
		size_px -= 1
		apply_rich_label_font_sizes(_o, size_px)
		_o._rich_label.update_minimum_size()
		_o._rich_label.queue_redraw()
		_o._rich_current_font_size = size_px
		guard += 1
	var still_over := _rich_height_exceeds_avail(_o, avail.y, fnt, plain, wrap_w, size_px) or not _fits_within(_o, _measure_paragraph(_o, fnt, plain, wrap_w, size_px), avail, wrap_enabled)
	if still_over and _o._rich_verify_passes < 8:
		_o._rich_verify_passes += 1
		_o.call_deferred("_verify_rich_text_fit")
	else:
		_o._last_fit_font_size = _o._rich_current_font_size

static func calculate_available_area(_o: Omni_Button) -> Vector2:
	var tp := _o.TextFitPadding
	var ep := get_effective_label_padding(_o)
	var horiz: float = max(0.0, tp.x) + max(0.0, ep.x) + max(0.0, ep.z)
	var vert: float = max(0.0, tp.y) + max(0.0, ep.y) + max(0.0, ep.w)
	return Vector2(max(1.0, _o.size.x - horiz), max(1.0, _o.size.y - vert))

## One reusable shaping buffer per button: the binary search measures ~15-20 sizes per fit, and
## allocating a TextParagraph for each was most of the fit's allocation churn.
static var _para: TextParagraph

static func _measure_paragraph(_o: Omni_Button, fnt: Font, text: String, wrap_width: float, font_size: int) -> Vector2:
	# One line with no wrapping: the font's own (cached) string measurement gives the same size
	# without building a paragraph. Wrapped or multi-line text still goes through TextParagraph.
	if wrap_width <= 0.0 and not text.contains("\n"):
		return fnt.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	if _para == null:
		_para = TextParagraph.new()
	var para := _para
	para.clear()
	para.alignment = _o.LabelHorizontalAlignment
	para.direction = TextServer.DIRECTION_AUTO
	para.orientation = TextServer.ORIENTATION_HORIZONTAL
	para.justification_flags = TextServer.JUSTIFICATION_NONE
	para.break_flags = _get_line_break_flags(_o)
	para.width = wrap_width if wrap_width > 0.0 else 0.0
	para.add_string(text, fnt, font_size)
	return para.get_size()

static func _get_line_break_flags(_o: Omni_Button) -> int:
	# Use local fallback constants for Godot versions where TextServer.LINE_BREAK_FLAG_* are absent.
	# Removed AUTOWRAP_TRIM / AUTOWRAP_TRIM_WORD cases for compatibility with engine versions that do not define them.
	const LB_NONE := 0
	const LB_WORD := 2
	const LB_GRAPHEME := 4
	const LB_ADAPTIVE := 128
	# const LB_TRIM_EDGE := 256  # Not used without trim modes
	match _o.LabelAutowrap:
		TextServer.AUTOWRAP_WORD:
			return LB_WORD
		TextServer.AUTOWRAP_WORD_SMART:
			return LB_WORD | LB_ADAPTIVE
		# Treat ARBITRARY as grapheme wrapping for this engine version.
		TextServer.AUTOWRAP_ARBITRARY:
			return LB_GRAPHEME
		_:
			return LB_NONE

static func _fits_within(_o: Omni_Button, measured: Vector2, avail: Vector2, wrap_enabled: bool) -> bool:
	var width_ok := measured.x <= (avail.x + (0.5 if wrap_enabled else 0.0))
	return width_ok and measured.y <= avail.y

static func get_rich_fit_font(_o: Omni_Button) -> Font:
	if _o.LabelFont != null:
		return _o.LabelFont
	return ThemeDB.fallback_font

## Prefer RichTextLabel layout height when ready; otherwise TextParagraph (same frame as fit).
static func _rich_height_exceeds_avail(_o: Omni_Button, avail_y: float, fnt: Font, plain: String, wrap_w: float, size_px: int) -> bool:
	if _o._rich_label == null or not is_instance_valid(_o._rich_label):
		return false
	var gh: float = _o._rich_label.get_content_height()
	if gh > 0.5:
		return gh > avail_y
	return _measure_paragraph(_o, fnt, plain, wrap_w, size_px).y > avail_y

static func grow_font_size(_o: Omni_Button, fnt: Font, text: String, avail: Vector2, wrap_width: float, wrap_enabled: bool, current: int) -> int:
	# Refits (resize, refit frames) usually land on the size that fit last time: one probe at
	# current + 1 settles that instead of a full binary search up to MaxFontSize.
	if current >= _o.MaxFontSize or not _fits_within(_o, _measure_paragraph(_o, fnt, text, wrap_width, current + 1), avail, wrap_enabled):
		return current
	var lo := current + 1
	var hi := _o.MaxFontSize
	var best := current
	while lo <= hi:
		var mid := int((lo + hi) / 2)
		var sz := _measure_paragraph(_o, fnt, text, wrap_width, mid)
		if _fits_within(_o, sz, avail, wrap_enabled):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best

static func find_best_font_size(_o: Omni_Button, fnt: Font, text: String, avail: Vector2, wrap_width: float, wrap_enabled: bool) -> int:
	var lo := _o.MinFontSize
	var hi := _o.MaxFontSize
	var best := lo
	while lo <= hi:
		var mid := int((lo + hi) / 2)
		var sz := _measure_paragraph(_o, fnt, text, wrap_width, mid)
		if _fits_within(_o, sz, avail, wrap_enabled):
			best = mid
			lo = mid + 1
		else:
			hi = mid - 1
	return best

static func get_effective_label_padding(_o: Omni_Button) -> Vector4:
	var lr := max(0.0, _o.LabelPadding.x)
	var tb := max(0.0, _o.LabelPadding.y)
	var left: float = lr + max(0.0, _o.LabelAdditionalPaddingLeft)
	var right: float = lr + max(0.0, _o.LabelAdditionalPaddingRight)
	var top: float = tb + max(0.0, _o.LabelAdditionalPaddingTop)
	var bottom: float = tb + max(0.0, _o.LabelAdditionalPaddingBottom)
	return Vector4(left, top, right, bottom)

const _RICH_SIZE_KEYS: Array[StringName] = [&"normal_font_size", &"bold_font_size", &"italics_font_size", &"bold_italics_font_size", &"mono_font_size"]

## Theme override writes have no same-value early-out: each one re-themes the label and makes it
## re-shape its text. Refits (every resize, every refit frame) usually land on the same size, so
## only write what actually changes.
static func apply_rich_label_font_sizes(_o: Omni_Button, size_px: int) -> void:
	var rtl := _o._rich_label
	if rtl == null or not is_instance_valid(rtl):
		return
	for key in _RICH_SIZE_KEYS:
		if not rtl.has_theme_font_size_override(key) or rtl.get_theme_font_size(key) != size_px:
			rtl.add_theme_font_size_override(key, size_px)

static func set_plain_font(_o: Omni_Button, fnt: Font, size_px: int) -> void:
	var lbl := _o._label
	if lbl == null or not is_instance_valid(lbl):
		return
	var changed := false
	if fnt != null and (not lbl.has_theme_font_override("font") or lbl.get_theme_font("font") != fnt):
		lbl.add_theme_font_override("font", fnt)
		changed = true
	if not lbl.has_theme_font_size_override("font_size") or lbl.get_theme_font_size("font_size") != size_px:
		lbl.add_theme_font_size_override("font_size", size_px)
		changed = true
	if changed:
		lbl.update_minimum_size()
		lbl.queue_redraw()

static func strip_bbcode(_o: Omni_Button, src: String) -> String:
	if src == null or src == "":
		return ""
	var out := ""
	var i := 0
	while i < src.length():
		var ch := src[i]
		if ch == "[":
			var closing := src.find("]", i + 1)
			if closing != -1:
				var inner := src.substr(i + 1, closing - i - 1).strip_edges()
				if inner != "":
					var tag_name := inner
					var eq := tag_name.find("=")
					if eq != -1:
						tag_name = tag_name.substr(0, eq)
					tag_name = tag_name.strip_edges()
					if tag_name.begins_with("/"):
						tag_name = tag_name.substr(1, tag_name.length() - 1).strip_edges()
					var normalized := tag_name.to_lower()
					if BBCODE_KNOWN_TAGS.has(normalized):
						if BBCODE_BREAK_TAGS.has(normalized):
							out += " "
						i = closing + 1
						continue
			# Not a known tag or missing closing bracket; fall through as literal
		out += ch
		i += 1
	return out


# ---- Shared fit cache -------------------------------------------------------------------------
## Fitted font size by fit inputs, shared by every button: a hotbar of 30 "Use" slots runs the
## search once. The fit is a pure function of these inputs (the seeded fast path and the full
## search both land on the largest size that fits), so a hit is exactly what a search would return.
static var _fit_cache := {}
const _FIT_CACHE_LIMIT := 4096

static func _fit_cache_key(_o: Omni_Button, kind: int, text: String, fnt: Font, avail: Vector2) -> Array:
	return [kind, text, fnt.get_instance_id(), avail, _o.LabelAutowrap, _o.MinFontSize, _o.MaxFontSize]

static func _fit_cache_store(_o: Omni_Button, key: Array, size_px: int) -> void:
	if _fit_cache.size() >= _FIT_CACHE_LIMIT:
		_fit_cache.clear()
	_fit_cache[key] = size_px

static func _fit_plain_label(_o: Omni_Button) -> bool:
	var avail := calculate_available_area(_o)
	if avail.x <= 1.0 or avail.y <= 1.0 or _o._label == null or not is_instance_valid(_o._label):
		return _fit_plain_label_uncached(_o)
	var theme_font := _o._label.get_theme_font("font")
	var fnt: Font = theme_font if theme_font != null else ThemeDB.fallback_font
	if fnt == null:
		return _fit_plain_label_uncached(_o)
	var key := _fit_cache_key(_o, 0, _o._label.text, fnt, avail)
	var hit: Variant = _fit_cache.get(key)
	if hit != null:
		var size_px: int = hit
		set_plain_font(_o, fnt, size_px)
		_o._last_fit_font_size = size_px
		return true
	var ok := _fit_plain_label_uncached(_o)
	if ok:
		_fit_cache_store(_o, key, _o._last_fit_font_size)
	return ok

static func _fit_rich_text_label(_o: Omni_Button) -> bool:
	var avail := calculate_available_area(_o)
	if avail.x <= 1.0 or avail.y <= 1.0 or _o._rich_label == null or not is_instance_valid(_o._rich_label):
		return _fit_rich_text_label_uncached(_o)
	var fnt: Font = get_rich_fit_font(_o)
	if fnt == null:
		return _fit_rich_text_label_uncached(_o)
	# Raw text is the key: the plain-text strip is only needed when we actually search.
	var key := _fit_cache_key(_o, 1, _o._rich_label.text, fnt, avail)
	var hit: Variant = _fit_cache.get(key)
	if hit != null:
		var size_px: int = hit
		apply_rich_label_font_sizes(_o, size_px)
		_o._rich_label.update_minimum_size()
		_o._rich_current_font_size = size_px
		_o._last_fit_font_size = size_px
		# The measured fit is shared; the check against this label's real rendered height is not.
		_o._rich_verify_passes = 0
		_o.call_deferred("_verify_rich_text_fit")
		return true
	var ok := _fit_rich_text_label_uncached(_o)
	if ok:
		_fit_cache_store(_o, key, _o._rich_current_font_size)
	return ok
