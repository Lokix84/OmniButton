extends RefCounted
class_name OmniButtonTypewriter

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func start_typewriter(final_text: String = "", cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	var target := final_text
	if target == null or target == "":
		target = _o.TextToType
	if target == "":
		skip_typewriter()
		return
	var want_bb := preserve_bbcode_tags and _o._label_type == _o.LabelKind.RichTextLabel
	var content := target if want_bb else _o._strip_bbcode(target)
	_o._debug("Typewriter start len=%d cps=%.2f by_word=%s bbcode=%s" % [content.length(), cps, str(by_word), str(want_bb)])
	_o._tw_bbcode_aware = want_bb
	_o._tw_final_text = content
	_o._tw_by_word = by_word
	_o._tw_cps = max(1.0, cps)
	_o._tw_accum = 0.0
	_o._tw_index = 0
	_o._tw_visible_plain_chars = 0
	_o._tw_total_plain_chars = 0
	_o._tw_tokens = []
	_o._tw_bb_tokens = []
	_o._tw_builder = ""
	_o._setup_children()
	_prefit_for_text(content)
	if _o._tw_bbcode_aware:
		var info := _tokenize_bbcode(target)
		_o._tw_bb_tokens = info["tokens"]
		_o._tw_total_plain_chars = info["plain"]
		_set_typewriter_visible_text(_build_visible_from_tokens(_o._tw_bb_tokens, 0))
	else:
		if _o._tw_by_word:
			_o._tw_tokens = _tokenize_words(content)
		else:
			_o._tw_tokens = []
		_set_typewriter_visible_text("")
	_o._tw_active = true
	_o.set_process(true)

func start_typewriter_from_text_to_type(cps: float = 30.0, by_word: bool = false, preserve_bbcode_tags: bool = false) -> void:
	start_typewriter(_o.TextToType, cps, by_word, preserve_bbcode_tags)

func skip_typewriter() -> void:
	if _o._tw_final_text == "":
		stop_typewriter()
		return
	_set_typewriter_visible_text(_o._tw_final_text)
	_o._debug("Typewriter skipped to end")
	_stop_typewriter_internal(true)

func stop_typewriter() -> void:
	_stop_typewriter_internal(false)

func _stop_typewriter_internal(_from_skip: bool) -> void:
	var was_active: bool = _o._tw_active
	var current_text := ""
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		current_text = _o._rich_label.text
	elif _o._label != null and is_instance_valid(_o._label):
		current_text = _o._label.text
	_o._tw_active = false
	if current_text != "":
		_o._text = current_text
	_o._tw_accum = 0.0
	_o._tw_index = 0
	_o._tw_tokens = []
	_o._tw_bb_tokens = []
	_o._tw_builder = ""
	_o._tw_total_plain_chars = 0
	_o._tw_visible_plain_chars = 0
	_o._tw_final_text = ""
	_o._tw_bbcode_aware = false
	if was_active:
		_o.emit_signal("typewriter_completed")
		_o._debug("Typewriter completed")

func _set_typewriter_visible_text(s: String) -> void:
	if _o._label != null and is_instance_valid(_o._label):
		_o._label.text = s
	if _o._rich_label != null and is_instance_valid(_o._rich_label):
		_o._rich_label.text = s
	if not _o._tw_active:
		_o._text = s

func process_typewriter(delta: float) -> void:
	if not _o._tw_active:
		return
	var step: float = 1.0 / max(1.0, _o._tw_cps)
	_o._tw_accum += delta
	var changed := false
	if _o._tw_bbcode_aware and _o._tw_bb_tokens.size() > 0:
		while _o._tw_accum >= step and _o._tw_visible_plain_chars < _o._tw_total_plain_chars:
			_o._tw_accum -= step
			_o._tw_visible_plain_chars += 1
			changed = true
		if changed:
			_set_typewriter_visible_text(_build_visible_from_tokens(_o._tw_bb_tokens, _o._tw_visible_plain_chars))
		if _o._tw_visible_plain_chars >= _o._tw_total_plain_chars:
			_stop_typewriter_internal(false)
	elif _o._tw_by_word and _o._tw_tokens.size() > 0:
		while _o._tw_accum >= step and _o._tw_index < _o._tw_tokens.size():
			_o._tw_accum -= step
			_o._tw_builder += _o._tw_tokens[_o._tw_index]
			_o._tw_index += 1
			changed = true
		if changed:
			_set_typewriter_visible_text(_o._tw_builder)
		if _o._tw_index >= _o._tw_tokens.size():
			_stop_typewriter_internal(false)
	else:
		while _o._tw_accum >= step and _o._tw_index < _o._tw_final_text.length():
			_o._tw_accum -= step
			_o._tw_builder += _o._tw_final_text[_o._tw_index]
			_o._tw_index += 1
			changed = true
		if changed:
			_set_typewriter_visible_text(_o._tw_builder)
		if _o._tw_index >= _o._tw_final_text.length():
			_stop_typewriter_internal(false)

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
			# treat unmatched '[' as literal
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
			if _o.DelayEffectTagsDuringTypewriter and visible_plain_chars < _o._tw_total_plain_chars and _is_effect_tag(content):
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

func _prefit_for_text(content: String) -> void:
	var ep := _o._get_effective_label_padding()
	var avail := Vector2(
		max(1.0, _o.size.x - max(0.0, _o.TextFitPadding.x) - max(0.0, ep.x) - max(0.0, ep.z)),
		max(1.0, _o.size.y - max(0.0, _o.TextFitPadding.y) - max(0.0, ep.y) - max(0.0, ep.w))
	)
	if avail.x <= 1.0 or avail.y <= 1.0: return
	if _o._label_type == _o.LabelKind.RichTextLabel and _o._rich_label != null and is_instance_valid(_o._rich_label):
		var base_font: Font = _o._rich_label.get_theme_font("normal_font") if _o._rich_label.get_theme_font("normal_font") != null else ThemeDB.fallback_font
		if base_font == null: return
		var plain := _o._strip_bbcode(content)
		var wrap_w := avail.x if _o.LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
		var lo := _o.MinFontSize
		var hi := _o.MaxFontSize
		var best := lo
		while lo <= hi:
			var mid := int((lo + hi) / 2)
			var ts := base_font.get_string_size(plain, HORIZONTAL_ALIGNMENT_LEFT, wrap_w, mid)
			if ts.x <= avail.x and ts.y <= avail.y:
				best = mid; lo = mid + 1
			else:
				hi = mid - 1
		_o._apply_rich_label_font_overrides(base_font, best)
		_o._last_fit_font_size = best
	elif _o._label_type == _o.LabelKind.Label and _o._label != null and is_instance_valid(_o._label):
		var fnt: Font = _o._label.get_theme_font("font") if _o._label.get_theme_font("font") != null else ThemeDB.fallback_font
		if fnt == null: return
		var wrap_w2 := avail.x if _o.LabelAutowrap != TextServer.AUTOWRAP_OFF else -1
		var lo2 := _o.MinFontSize
		var hi2 := _o.MaxFontSize
		var best2 := lo2
		while lo2 <= hi2:
			var mid2 := int((lo2 + hi2) / 2)
			var ts2 := fnt.get_string_size(content, HORIZONTAL_ALIGNMENT_LEFT, wrap_w2, mid2)
			if ts2.x <= avail.x and ts2.y <= avail.y:
				best2 = mid2; lo2 = mid2 + 1
			else:
				hi2 = mid2 - 1
		_o._label.add_theme_font_override("font", fnt)
		_o._label.add_theme_font_size_override("font_size", best2)
		_o._last_fit_font_size = best2
