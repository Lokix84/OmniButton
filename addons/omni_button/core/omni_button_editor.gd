extends RefCounted
class_name OmniButtonEditor
## editor only stuff: what shows in the inspector and noticing when things change.
## static, every function takes the button as the first argument (_o).

## which inspector group each conditional setting is in. one lookup per setting instead of building
## six arrays and searching them on every _validate_property call.
enum _Group {SHARED_TEXT, LABEL, RICH_TEXT, EXTRA_TEXT, PANEL, TEXTURE_RECT,
	HOVER, BOUNDS, JOYSTICK, JOYSTICK_AREA, JOYSTICK_THUMB, ICON, HOLD, SWIPE,
	COOLDOWN, COOLDOWN_INVERT, COOLDOWN_HOVER, COOLDOWN_HOLD}
const _PROPERTY_GROUPS := {
	&"text": _Group.SHARED_TEXT, &"label_font": _Group.SHARED_TEXT, &"label_text_color": _Group.SHARED_TEXT,
	&"text_modulate": _Group.SHARED_TEXT, &"label_horizontal_alignment": _Group.SHARED_TEXT,
	&"label_vertical_alignment": _Group.SHARED_TEXT, &"label_autowrap": _Group.SHARED_TEXT,
	&"label_uppercase": _Group.LABEL, &"label_clip_text": _Group.LABEL, &"label_text_overrun": _Group.LABEL,
	&"rich_label_use_bbcode": _Group.RICH_TEXT, &"rich_text_fit_content": _Group.RICH_TEXT,
	&"rich_text_scroll_active": _Group.RICH_TEXT, &"rich_text_scroll_following": _Group.RICH_TEXT,
	&"rich_text_selection_enabled": _Group.RICH_TEXT, &"rich_text_context_menu_enabled": _Group.RICH_TEXT,
	&"text_fit_padding": _Group.EXTRA_TEXT, &"min_font_size": _Group.EXTRA_TEXT, &"max_font_size": _Group.EXTRA_TEXT,
	&"fixed_font_size": _Group.EXTRA_TEXT, &"enable_text_auto_size": _Group.EXTRA_TEXT, &"label_padding": _Group.EXTRA_TEXT,
	&"label_additional_padding_left": _Group.EXTRA_TEXT, &"label_additional_padding_top": _Group.EXTRA_TEXT,
	&"label_additional_padding_right": _Group.EXTRA_TEXT, &"label_additional_padding_bottom": _Group.EXTRA_TEXT,
	&"text_to_type": _Group.EXTRA_TEXT, &"suspend_hover_during_typewriter": _Group.EXTRA_TEXT,
	&"delay_effect_tags_during_typewriter": _Group.EXTRA_TEXT, &"finish_typewriter_on_press": _Group.EXTRA_TEXT,
	&"panel_theme_variation": _Group.PANEL, &"panel_style_box": _Group.PANEL, &"panel_hover_style_box": _Group.PANEL,
	&"panel_pressed_style_box": _Group.PANEL, &"panel_disabled_style_box": _Group.PANEL,
	&"panel_focus_style_box": _Group.PANEL, &"panel_modulate": _Group.PANEL,
	&"texture": _Group.TEXTURE_RECT, &"expand_mode": _Group.TEXTURE_RECT, &"stretch_mode": _Group.TEXTURE_RECT,
	&"flip_h": _Group.TEXTURE_RECT, &"flip_v": _Group.TEXTURE_RECT, &"background_modulate": _Group.TEXTURE_RECT,
	# feature settings only show while their feature is on (they still save when hidden).
	&"hover_lerp_speed": _Group.HOVER,
	&"clamp_to_bounds": _Group.BOUNDS,
	&"clamp_shape": _Group.JOYSTICK, &"joystick_radius_px": _Group.JOYSTICK, &"joystick_rect_size_px": _Group.JOYSTICK,
	&"joystick_deadzone": _Group.JOYSTICK, &"joystick_snap_to_input": _Group.JOYSTICK,
	&"joystick_hide_when_inactive": _Group.JOYSTICK, &"joystick_reset_on_release": _Group.JOYSTICK,
	&"enable_joystick_area": _Group.JOYSTICK, &"enable_default_thumb": _Group.JOYSTICK,
	&"joystick_area_persistent": _Group.JOYSTICK_AREA, &"joystick_area_color": _Group.JOYSTICK_AREA,
	&"joystick_area_thickness": _Group.JOYSTICK_AREA, &"joystick_area_use_rect_for_clamp": _Group.JOYSTICK_AREA,
	&"joystick_area_external_path": _Group.JOYSTICK_AREA,
	&"default_thumb_size_ratio": _Group.JOYSTICK_THUMB, &"default_thumb_color": _Group.JOYSTICK_THUMB,
	&"icon_expand_mode": _Group.ICON, &"icon_stretch_mode": _Group.ICON, &"icon_flip_h": _Group.ICON,
	&"icon_flip_v": _Group.ICON, &"icon_modulate": _Group.ICON,
	&"hold_fill_color": _Group.HOLD, &"hold_fill_direction": _Group.HOLD,
	&"swipe_threshold": _Group.SWIPE, &"touch_swipe_init": _Group.SWIPE, &"touch_swipe_exit": _Group.SWIPE,
	&"mouse_swipe_init": _Group.SWIPE, &"mouse_swipe_exit": _Group.SWIPE,
	&"cooldown_start_delay": _Group.COOLDOWN, &"cooldown_duration": _Group.COOLDOWN,
	&"cooldown_start_filled": _Group.COOLDOWN, &"cooldown_color": _Group.COOLDOWN,
	&"cooldown_fill_direction": _Group.COOLDOWN, &"invert_on_cooldown": _Group.COOLDOWN,
	&"cooldown_invert_duration": _Group.COOLDOWN_INVERT,
	&"suspend_hover_scale_during_cooldown": _Group.COOLDOWN_HOVER,
	&"allow_hold_during_cooldown": _Group.COOLDOWN_HOLD, &"hide_cooldown_during_hold_build_up": _Group.COOLDOWN_HOLD,
}

static func refresh_label_type_inspector(_o: OmniButton) -> void:
	_o.notify_property_list_changed()
	if Engine.is_editor_hint():
		_o.call_deferred("notify_property_list_changed")

static func validate_property(_o: OmniButton, property: Dictionary) -> void:
	var property_name: StringName = property.get("name", &"")
	var usage := int(property.get("usage", 0))
	var has_text_type := _o._label_type != OmniButton.LabelKind.NONE
	if usage & PROPERTY_USAGE_CATEGORY:
		var category_visible := true
		match property_name:
			&"Text", &"Extra":
				category_visible = has_text_type
			&"Label":
				category_visible = _o._label_type == OmniButton.LabelKind.LABEL
			&"RichTextLabel":
				category_visible = _o._label_type == OmniButton.LabelKind.RICH_TEXT_LABEL
		if not category_visible:
			property.usage = 0
		return

	var group: int = _PROPERTY_GROUPS.get(property_name, -1)
	if group < 0:
		return
	var visible := true
	match group:
		_Group.SHARED_TEXT, _Group.EXTRA_TEXT:
			visible = has_text_type
		_Group.LABEL:
			visible = _o._label_type == OmniButton.LabelKind.LABEL
		_Group.RICH_TEXT:
			visible = _o._label_type == OmniButton.LabelKind.RICH_TEXT_LABEL
		_Group.PANEL:
			visible = _o._background_mode == OmniButton.BackgroundMode.USE_PANEL
		_Group.TEXTURE_RECT:
			visible = _o._background_mode == OmniButton.BackgroundMode.USE_TEXTURE
		_Group.HOVER:
			visible = _o._hover_scale > 0.0
		_Group.BOUNDS:
			visible = _o._follow_mode != OmniButton.FollowMode.NONE
		_Group.JOYSTICK:
			visible = _joystick_on(_o)
		_Group.JOYSTICK_AREA:
			visible = _joystick_on(_o) and _o.enable_joystick_area
		_Group.JOYSTICK_THUMB:
			visible = _joystick_on(_o) and _o._enable_default_thumb
		_Group.ICON:
			visible = _o._icon_texture != null
		_Group.HOLD:
			visible = _o._hold_duration > 0.0
		_Group.SWIPE:
			visible = _o._action_enabled(OmniButton.ACT_SWIPE)
		_Group.COOLDOWN:
			visible = _cooldown_on(_o)
		_Group.COOLDOWN_INVERT:
			visible = _cooldown_on(_o) and _o.invert_on_cooldown
		_Group.COOLDOWN_HOVER:
			visible = _cooldown_on(_o) and _o._hover_scale > 0.0
		_Group.COOLDOWN_HOLD:
			visible = _cooldown_on(_o) and _o._hold_duration > 0.0
	if not visible:
		property.usage = usage & ~PROPERTY_USAGE_EDITOR

static func _joystick_on(_o: OmniButton) -> bool:
	return _o._follow_mode == OmniButton.FollowMode.VIRTUAL_JOYSTICK

static func _cooldown_on(_o: OmniButton) -> bool:
	return _o._cooldown_trigger != OmniButton.CooldownTrigger.NONE

static func process_editor(_o: OmniButton) -> void:
	OmniButtonSignals.auto_enable_actions_once_from_connections(_o)
	var sig := build_signature(_o)
	if sig != _o.__editor_last_sig:
		_o.__editor_last_sig = sig
		_o.queue_refresh(true, true, true)

## editor only: spots export/property changes without calling str() on objects or huge containers.
## when the signatures weren't stable it fired queue_refresh every poll, setup_children() over and over, out of memory.
static func build_signature(_o: OmniButton) -> String:
	const MAX_LEN := 65536
	var sb := ""
	var props := _o.get_property_list()
	for p in props:
		if sb.length() >= MAX_LEN:
			sb += "|...trunc|" + str(sb.hash())
			break
		if not p.has("usage"):
			continue
		var usage := int(p["usage"])
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var name := String(p["name"])
		var val = _o.get(name)
		sb += name + "=" + _sig_value(val) + "|"
	return sb

static func _sig_value(val: Variant) -> String:
	var t := typeof(val)
	match t:
		TYPE_NIL:
			return "nil"
		TYPE_BOOL, TYPE_INT, TYPE_FLOAT:
			return str(val)
		TYPE_STRING, TYPE_STRING_NAME:
			var s := str(val)
			if s.length() > 512:
				return "str:" + str(s.hash())
			return s
		TYPE_VECTOR2, TYPE_VECTOR2I, TYPE_VECTOR3, TYPE_VECTOR3I, TYPE_VECTOR4, TYPE_VECTOR4I, TYPE_RECT2, TYPE_RECT2I, TYPE_COLOR, TYPE_TRANSFORM2D, TYPE_TRANSFORM3D, TYPE_AABB, TYPE_PLANE, TYPE_QUATERNION:
			return str(val)
		TYPE_OBJECT:
			if val == null:
				return "null"
			var o := val as Object
			if not is_instance_valid(o):
				return "invalid"
			if o is Resource:
				var r := o as Resource
				if r.resource_path != "":
					return r.resource_path
				return "res:" + str(r.get_instance_id())
			return "obj:" + o.get_class() + ":" + str(o.get_instance_id())
		TYPE_ARRAY, TYPE_PACKED_BYTE_ARRAY, TYPE_PACKED_INT32_ARRAY, TYPE_PACKED_INT64_ARRAY, TYPE_PACKED_FLOAT32_ARRAY, TYPE_PACKED_FLOAT64_ARRAY, TYPE_PACKED_STRING_ARRAY, TYPE_PACKED_VECTOR2_ARRAY, TYPE_PACKED_VECTOR3_ARRAY, TYPE_PACKED_VECTOR4_ARRAY, TYPE_PACKED_COLOR_ARRAY, TYPE_DICTIONARY:
			return "h:" + str(hash(val))
		TYPE_CALLABLE, TYPE_SIGNAL:
			return "h:" + str(hash(val))
		_:
			var s := str(val)
			if s.length() > 512:
				return "x:" + str(s.hash())
			return s
