extends RefCounted
class_name OmniButtonTypewriter
## the typewriter. one per button, made the first time it's needed.
##
## it works off Label/RichTextLabel.visible_characters. the label gets the whole text once (no
## rebuilding the string, reshaping or reparsing bbcode every character) and each step just bumps
## how many characters are visible. with VC_CHARS_AFTER_SHAPING (set in configure_label) the text
## is already laid out where it'll end up, so words don't jump to the next line halfway through.
##
## timing tags, only the typewriter knows about these and they get pulled out before the label sees the text:
##   [pause=0.5]  wait half a second when the reveal gets here
##   [speed=12]   go 12 characters (or words) a second from here on
##   [/speed]     go back to the speed start_typewriter got

## stand in that marks where a timing tag was while the other tags get stripped.
const _MARKER := ""
static var _timing_tag_regex: RegEx

var _o: OmniButton

# reveal state. only _tw_active lives on the button, since _process checks it every frame.
## the text being revealed, the way it'll be set when the reveal finishes or gets skipped.
var full_text: String = ""
## what's on the label during the reveal (full_text, minus effect tags if those are held back).
var display_text: String = ""
## how many characters the reveal goes through.
var total_chars: int = 0
## characters shown so far.
var visible_chars: int = 0
var _bbcode_aware := false
var _by_word := false
var _cps: float = 30.0
var _accum: float = 0.0
## by word mode: index into _word_ends, and the running visible character count at the end of each word.
var _word_index: int = 0
var _word_ends := PackedInt32Array()
## the speed start_typewriter got. [/speed] goes back to this.
var _base_cps: float = 30.0
## seconds left on the current [pause].
var _pause_left: float = 0.0
## the timing tags in order: { "pos": visible character count, "pause": seconds } or { "pos", "speed": cps (0 = base) }.
var _timing: Array[Dictionary] = []
var _timing_index: int = 0
## the characters that get revealed, for typewriter_char_revealed.
var _plain_text: String = ""
## goes up on every start and stop, so if a signal handler restarted or stopped the reveal we don't keep going with the old one.
var _run_id: int = 0

func _init(o: OmniButton) -> void:
	_o = o

func start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	# an empty string cancels, it doesn't fall back to text_to_type.
	if final_text == null or final_text == "":
		skip_typewriter()
		return
	if preserve_bbcode_tags and _o._label_type != _o.LabelKind.RICH_TEXT_LABEL:
		_o.label_type = _o.LabelKind.RICH_TEXT_LABEL
	elif _o._label_type == _o.LabelKind.NONE:
		_o.label_type = _o.LabelKind.LABEL
	var want_bb := preserve_bbcode_tags and _o._label_type == _o.LabelKind.RICH_TEXT_LABEL
	# swap the timing tags for markers first, strip_bbcode would leave unknown tags in as text.
	var timing_values: Array[Dictionary] = []
	var marked := _mark_timing_tags(final_text, timing_values)
	var content := marked if want_bb else OmniButtonText.strip_bbcode(_o, marked)
	content = _resolve_timing_positions(content, want_bb, timing_values)
	if _o._dbg: _o._debug("Typewriter start len=%d cps=%.2f by_word=%s bbcode=%s timing_tags=%d" % [content.length(), cps, str(by_word), str(want_bb), _timing.size()])
	_run_id += 1
	_bbcode_aware = want_bb
	full_text = content
	_by_word = by_word and not want_bb
	_cps = max(1.0, cps)
	_base_cps = _cps
	_accum = 0.0
	_pause_left = 0.0
	_timing_index = 0
	_word_index = 0
	visible_chars = 0
	# effects like [wave] animate letters that are already showing, so hold them back until the reveal is done.
	display_text = _strip_effect_tags(content) if (want_bb and _o.delay_effect_tags_during_typewriter) else content
	_o._tw_active = true
	# the prefit only needs the label node to exist. a full setup_children() would throw away and
	# remake every visual each time the typewriter starts.
	_o._set_label_text()
	_prefit_for_text(content)
	total_chars = _count_revealable_chars()
	_plain_text = _revealable_text()
	_word_ends = _word_end_offsets(content) if _by_word else PackedInt32Array()
	_apply_visible_chars(0)
	_o.set_process(true)
	if total_chars <= 0:
		_stop_typewriter_internal(true)
		return
	_apply_timing_up_to(0)

func start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	# use text_to_type if it's set, otherwise the main text.
	var src := _o.text_to_type if _o.text_to_type != "" else _o._text
	start_typewriter(src, cps, by_word, preserve_bbcode_tags)

func skip_typewriter() -> void:
	if full_text == "":
		stop_typewriter()
		return
	if _o._dbg: _o._debug("Typewriter skipped to end")
	_stop_typewriter_internal(true)

func stop_typewriter() -> void:
	_stop_typewriter_internal(false)

## skipped or finished normally: set the whole final text.
## cancelled (from_skip false while active): only keep what's been shown so far.
func _stop_typewriter_internal(_from_skip: bool) -> void:
	var was_active: bool = _o._tw_active
	if was_active:
		var final_text: String = full_text if _from_skip else _revealed_text()
		_o._tw_active = false
		_set_typewriter_visible_text(final_text)
		if final_text != "":
			_o._text = final_text
	_o._tw_active = false
	_run_id += 1
	_accum = 0.0
	_pause_left = 0.0
	_timing.clear()
	_timing_index = 0
	_plain_text = ""
	_word_index = 0
	_word_ends = PackedInt32Array()
	total_chars = 0
	visible_chars = 0
	full_text = ""
	display_text = ""
	_bbcode_aware = false
	if was_active:
		_o._schedule_fit_label()
		_o.emit_signal("typewriter_completed")
		if _o._dbg: _o._debug("Typewriter completed")

## puts the full text on the live label(s) and clears any half done reveal.
func _set_typewriter_visible_text(s: String) -> void:
	if _o._label != null and is_instance_valid(_o._label):
		_o._label.text = s
		_o._label.visible_characters = -1
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		_o._rich_label.text = s
		_o._rich_label.visible_characters = -1
	if not _o._tw_active:
		_o._text = s

func _apply_visible_chars(count: int) -> void:
	if _o._label != null and is_instance_valid(_o._label):
		_o._label.visible_characters = count
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		_o._rich_label.visible_characters = count

## the characters visible_characters steps through. for rich labels that's the parsed text with no tags.
func _count_revealable_chars() -> int:
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		var parsed: int = _o._rich_label.get_parsed_text().length()
		if parsed > 0:
			return parsed
		if _bbcode_aware:
			return int(_tokenize_bbcode(display_text)["plain"])
	return display_text.length()

## running character count at the end of each word (word plus the spaces after it).
func _word_end_offsets(s: String) -> PackedInt32Array:
	var ends := PackedInt32Array()
	var total := 0
	for word in _tokenize_words(s):
		total += word.length()
		ends.append(total)
	return ends

## the partial text for a cancelled reveal (only worked out once, when it stops).
func _revealed_text() -> String:
	var shown := visible_chars
	if _bbcode_aware:
		var info := _tokenize_bbcode(full_text)
		return _build_visible_from_tokens(info["tokens"], shown)
	return full_text.substr(0, shown)

func _strip_effect_tags(src: String) -> String:
	var out := ""
	for token in _tokenize_bbcode(src)["tokens"]:
		var content: String = token["content"]
		if token["is_tag"] and _is_effect_tag(content):
			continue
		out += content
	return out

func process_typewriter(delta: float) -> void:
	if not _o._tw_active:
		return
	_accum += delta
	var before := visible_chars
	var done := false
	# one character (or word) per loop, so [pause] and [speed] kick in right where they were written.
	while true:
		if _pause_left > 0.0:
			if _accum < _pause_left:
				_pause_left -= _accum
				_accum = 0.0
				break
			_accum -= _pause_left
			_pause_left = 0.0
		if visible_chars >= total_chars:
			done = true
			break
		var step: float = 1.0 / _cps
		if _accum < step:
			break
		_accum -= step
		_advance_one()
		_apply_timing_up_to(visible_chars)
	if visible_chars != before:
		_apply_visible_chars(visible_chars)
		var run := _run_id
		_emit_revealed(before, visible_chars, run)
		if run != _run_id:
			return # a handler skipped, stopped or restarted it
	if done:
		_stop_typewriter_internal(true)

func _advance_one() -> void:
	if _by_word and _word_ends.size() > 0:
		_word_index = mini(_word_index + 1, _word_ends.size())
		visible_chars = mini(_word_ends[_word_index - 1], total_chars)
		if _word_index >= _word_ends.size():
			visible_chars = total_chars
	else:
		visible_chars += 1

## runs every timing tag the reveal has gotten to (pos <= count), in the order they were written.
func _apply_timing_up_to(count: int) -> void:
	while _timing_index < _timing.size() and int(_timing[_timing_index]["pos"]) <= count:
		var t: Dictionary = _timing[_timing_index]
		_timing_index += 1
		if t.has("pause"):
			_pause_left += float(t["pause"])
		elif t.has("speed"):
			var s := float(t["speed"])
			_cps = _base_cps if s <= 0.0 else max(1.0, s)

func _emit_revealed(from: int, to: int, run: int) -> void:
	if _o.typewriter_char_revealed.get_connections().is_empty():
		return
	for i in range(from, mini(to, _plain_text.length())):
		_o.typewriter_char_revealed.emit(i, _plain_text[i])
		if run != _run_id:
			return

## the characters visible_characters steps through, in order.
func _revealable_text() -> String:
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		var parsed: String = _o._rich_label.get_parsed_text()
		if parsed != "":
			return parsed
	return display_text

## swaps each [pause=…] / [speed=…] / [/speed] for _MARKER and adds its value to `values`.
func _mark_timing_tags(src: String, values: Array[Dictionary]) -> String:
	if src.find("[") == -1:
		return src
	if _timing_tag_regex == null:
		_timing_tag_regex = RegEx.create_from_string("(?i)\\[\\s*(?:(pause|speed)\\s*=\\s*([0-9]*\\.?[0-9]+)|(/speed))\\s*\\]")
	var out := ""
	var last := 0
	for m in _timing_tag_regex.search_all(src):
		out += src.substr(last, m.get_start() - last) + _MARKER
		last = m.get_end()
		if m.get_string(3) != "":
			values.append({"speed": 0.0})
		elif m.get_string(1).to_lower() == "pause":
			values.append({"pause": maxf(0.0, m.get_string(2).to_float())})
		else:
			values.append({"speed": m.get_string(2).to_float()})
	return out + src.substr(last)

## turns each marker into a reveal position (how many characters show before it), fills _timing,
## and gives back the text with the markers taken out. in bbcode mode characters inside tags don't count.
func _resolve_timing_positions(src: String, bbcode: bool, values: Array[Dictionary]) -> String:
	_timing.clear()
	if values.is_empty():
		return src
	var out := ""
	var plain := 0
	var k := 0
	var i := 0
	while i < src.length():
		var ch := src[i]
		if ch == _MARKER:
			if k < values.size():
				var t: Dictionary = values[k].duplicate()
				t["pos"] = plain
				_timing.append(t)
				k += 1
			i += 1
			continue
		if bbcode and ch == "[":
			var closing := src.find("]", i + 1)
			if closing != -1:
				out += src.substr(i, closing - i + 1)
				i = closing + 1
				continue
		out += ch
		plain += 1
		i += 1
	return out

func _is_whitespace(ch: String) -> bool:
	return ch == " " or ch == "\t" or ch == "\n" or ch == "\r"

func _tokenize_words(s: String) -> Array[String]:
	var out: Array[String] = []
	var i := 0
	while i < s.length():
		var start := i
		while i < s.length() and not _is_whitespace(s[i]): i += 1
		var word_end := i
		while i < s.length() and _is_whitespace(s[i]): i += 1
		var end := i
		if end > start:
			out.append(s.substr(start, end - start))
	return out

func _tokenize_bbcode(src: String) -> Dictionary:
	var tokens: Array = []
	var total_plain := 0
	var i := 0
	while i < src.length():
		var ch := src[i]
		if ch == "[":
			var closing := src.find("]", i + 1)
			if closing != -1:
				var tag := src.substr(i, closing - i + 1)
				tokens.append({"is_tag": true, "content": tag})
				i = closing + 1
				continue
			# a '[' with no match is just text
			i += 1
			total_plain += 1
			tokens.append({"is_tag": false, "content": "["})
			continue
		var start := i
		while i < src.length() and src[i] != "[":
			i += 1
		var text := src.substr(start, i - start)
		if text != "":
			tokens.append({"is_tag": false, "content": text})
			total_plain += text.length()
	return {"tokens": tokens, "plain": total_plain}

func _build_visible_from_tokens(tokens: Array, visible_plain_chars: int) -> String:
	var builder := ""
	var remain := max(0, visible_plain_chars)
	for token in tokens:
		var is_tag: bool = token.get("is_tag", false)
		var content: String = token.get("content", "")
		if is_tag:
			if _o.delay_effect_tags_during_typewriter and visible_plain_chars < total_chars and _is_effect_tag(content):
				continue
			builder += content
		else:
			if remain <= 0:
				continue
			var take := min(remain, content.length())
			builder += content.substr(0, take)
			remain -= take
	return builder

func _is_effect_tag(tag: String) -> bool:
	if tag == "":
		return false
	var start := tag.find("[")
	var end := tag.find("]")
	if start == -1 or end <= start:
		return false
	var inner := tag.substr(start + 1, end - start - 1).strip_edges()
	if inner.begins_with("/"):
		inner = inner.substr(1, inner.length() - 1).strip_edges()
	var split_space := inner.split(" ", false, 1)
	var name := split_space[0] if split_space.size() > 0 else inner
	var name_eq := name.split("=", false, 1)
	var normalized := name_eq[0].strip_edges().to_lower()
	return _o.TYPEWRITER_EFFECT_TAGS.has(normalized)

## sizes the label for the final text before the reveal starts so the font doesn't shrink halfway through.
## uses the same autosize search as omni_button_text.gd instead of having a second copy here.
func _prefit_for_text(content: String) -> void:
	# a fixed font size gets used as is, with autosizing off the label keeps its size.
	if _o.fixed_font_size > 0:
		if _o._label != null and is_instance_valid(_o._label):
			OmniButtonText.set_plain_font(_o, null, _o.fixed_font_size)
		if _o._rich_label != null and is_instance_valid(_o._rich_label):
			OmniButtonText.apply_rich_label_font_sizes(_o, _o.fixed_font_size)
		_o._last_fit_font_size = _o.fixed_font_size
		_o._rich_current_font_size = _o.fixed_font_size
		return
	if not _o.enable_text_auto_size:
		return
	var avail := OmniButtonText.calculate_available_area(_o)
	if avail.x <= 1.0 or avail.y <= 1.0: return
	var wrap_enabled := _o.label_autowrap != TextServer.AUTOWRAP_OFF
	var wrap_w := avail.x if wrap_enabled else -1.0
	if _o._label_type == _o.LabelKind.RICH_TEXT_LABEL and _o._rich_label != null and is_instance_valid(_o._rich_label):
		var fnt: Font = OmniButtonText.get_rich_fit_font(_o)
		if fnt == null: return
		var plain := OmniButtonText.strip_bbcode(_o, content)
		var best := OmniButtonText.find_best_font_size(_o, fnt, plain, avail, wrap_w, wrap_enabled)
		best = OmniButtonText.grow_font_size(_o, fnt, plain, avail, wrap_w, wrap_enabled, best)
		OmniButtonText.apply_rich_label_font_sizes(_o, best)
		_o._last_fit_font_size = best
		_o._rich_current_font_size = best
	elif _o._label_type == _o.LabelKind.LABEL and _o._label != null and is_instance_valid(_o._label):
		var theme_font := _o._label.get_theme_font("font")
		var fnt2: Font = theme_font if theme_font != null else ThemeDB.fallback_font
		if fnt2 == null: return
		var best2 := OmniButtonText.find_best_font_size(_o, fnt2, content, avail, wrap_w, wrap_enabled)
		best2 = OmniButtonText.grow_font_size(_o, fnt2, content, avail, wrap_w, wrap_enabled, best2)
		OmniButtonText.set_plain_font(_o, fnt2, best2)
		_o._last_fit_font_size = best2
