extends RefCounted
class_name OmniButtonEditor
## Editor-only: Inspector visibility rules and change detection.
## Static: every function takes the button as its first argument (_o).

## Which Inspector group each conditional property belongs to. One constant lookup per property
## instead of building six arrays and scanning them on every _validate_property call.
enum _Group {SHARED_TEXT, LABEL, RICH_TEXT, EXTRA_TEXT, PANEL, TEXTURE_RECT,
	HOVER, BOUNDS, JOYSTICK, JOYSTICK_AREA, JOYSTICK_THUMB, ICON, HOLD, SWIPE,
	COOLDOWN, COOLDOWN_INVERT, COOLDOWN_HOVER, COOLDOWN_HOLD}
const _PROPERTY_GROUPS := {
	&"Text": _Group.SHARED_TEXT, &"LabelFont": _Group.SHARED_TEXT, &"LabelTextColor": _Group.SHARED_TEXT,
	&"TextModulate": _Group.SHARED_TEXT, &"LabelHorizontalAlignment": _Group.SHARED_TEXT,
	&"LabelVerticalAlignment": _Group.SHARED_TEXT, &"LabelAutowrap": _Group.SHARED_TEXT,
	&"LabelUppercase": _Group.LABEL, &"LabelClipText": _Group.LABEL, &"LabelTextOverrun": _Group.LABEL,
	&"RichLabelUseBBCode": _Group.RICH_TEXT, &"RichTextFitContent": _Group.RICH_TEXT,
	&"RichTextScrollActive": _Group.RICH_TEXT, &"RichTextScrollFollowing": _Group.RICH_TEXT,
	&"RichTextSelectionEnabled": _Group.RICH_TEXT, &"RichTextContextMenuEnabled": _Group.RICH_TEXT,
	&"TextFitPadding": _Group.EXTRA_TEXT, &"MinFontSize": _Group.EXTRA_TEXT, &"MaxFontSize": _Group.EXTRA_TEXT,
	&"FixedFontSize": _Group.EXTRA_TEXT, &"EnableTextAutoSize": _Group.EXTRA_TEXT, &"LabelPadding": _Group.EXTRA_TEXT,
	&"LabelAdditionalPaddingLeft": _Group.EXTRA_TEXT, &"LabelAdditionalPaddingTop": _Group.EXTRA_TEXT,
	&"LabelAdditionalPaddingRight": _Group.EXTRA_TEXT, &"LabelAdditionalPaddingBottom": _Group.EXTRA_TEXT,
	&"TextToType": _Group.EXTRA_TEXT, &"SuspendHoverDuringTypewriter": _Group.EXTRA_TEXT,
	&"DelayEffectTagsDuringTypewriter": _Group.EXTRA_TEXT, &"FinishTypewriterOnPress": _Group.EXTRA_TEXT,
	&"PanelThemeVariation": _Group.PANEL, &"PanelStyleBox": _Group.PANEL, &"PanelHoverStyleBox": _Group.PANEL,
	&"PanelPressedStyleBox": _Group.PANEL, &"PanelDisabledStyleBox": _Group.PANEL,
	&"PanelFocusStyleBox": _Group.PANEL, &"PanelModulate": _Group.PANEL,
	&"texture": _Group.TEXTURE_RECT, &"expand_mode": _Group.TEXTURE_RECT, &"stretch_mode": _Group.TEXTURE_RECT,
	&"flip_h": _Group.TEXTURE_RECT, &"flip_v": _Group.TEXTURE_RECT, &"BackgroundModulate": _Group.TEXTURE_RECT,
	# Feature settings: shown only while their feature switch is on (values stay saved when hidden).
	&"HoverLerpSpeed": _Group.HOVER,
	&"ClampToBounds": _Group.BOUNDS,
	&"ClampShape": _Group.JOYSTICK, &"JoystickRadiusPx": _Group.JOYSTICK, &"JoystickRectSizePx": _Group.JOYSTICK,
	&"JoystickDeadzone": _Group.JOYSTICK, &"JoystickSnapToInput": _Group.JOYSTICK,
	&"JoystickHideWhenInactive": _Group.JOYSTICK, &"JoystickResetOnRelease": _Group.JOYSTICK,
	&"EnableJoystickArea": _Group.JOYSTICK, &"EnableDefaultThumb": _Group.JOYSTICK,
	&"JoystickAreaPersistent": _Group.JOYSTICK_AREA, &"JoystickAreaColor": _Group.JOYSTICK_AREA,
	&"JoystickAreaThickness": _Group.JOYSTICK_AREA, &"JoystickAreaUseRectForClamp": _Group.JOYSTICK_AREA,
	&"JoystickAreaExternalPath": _Group.JOYSTICK_AREA,
	&"DefaultThumbSizeRatio": _Group.JOYSTICK_THUMB, &"DefaultThumbColor": _Group.JOYSTICK_THUMB,
	&"IconExpandMode": _Group.ICON, &"IconStretchMode": _Group.ICON, &"IconFlipH": _Group.ICON,
	&"IconFlipV": _Group.ICON, &"IconModulate": _Group.ICON,
	&"HoldFillColor": _Group.HOLD, &"HoldFillDirection": _Group.HOLD,
	&"SwipeThreshold": _Group.SWIPE, &"TouchSwipeInit": _Group.SWIPE, &"TouchSwipeExit": _Group.SWIPE,
	&"MouseSwipeInit": _Group.SWIPE, &"MouseSwipeExit": _Group.SWIPE,
	&"CooldownStartDelay": _Group.COOLDOWN, &"CooldownDuration": _Group.COOLDOWN,
	&"CooldownStartFilled": _Group.COOLDOWN, &"CooldownColor": _Group.COOLDOWN,
	&"CooldownFillDirection": _Group.COOLDOWN, &"InvertOnCooldown": _Group.COOLDOWN,
	&"CooldownInvertDuration": _Group.COOLDOWN_INVERT,
	&"SuspendHoverScaleDuringCooldown": _Group.COOLDOWN_HOVER,
	&"AllowHoldDuringCooldown": _Group.COOLDOWN_HOLD, &"HideCooldownDuringHoldBuildUp": _Group.COOLDOWN_HOLD,
}

static func refresh_label_type_inspector(_o: Omni_Button) -> void:
	_o.notify_property_list_changed()
	if Engine.is_editor_hint():
		_o.call_deferred("notify_property_list_changed")

static func validate_property(_o: Omni_Button, property: Dictionary) -> void:
	var property_name: StringName = property.get("name", &"")
	var usage := int(property.get("usage", 0))
	var has_text_type := _o._label_type != Omni_Button.LabelKind.None
	if usage & PROPERTY_USAGE_CATEGORY:
		var category_visible := true
		match property_name:
			&"Text", &"Extra":
				category_visible = has_text_type
			&"Label":
				category_visible = _o._label_type == Omni_Button.LabelKind.Label
			&"RichTextLabel":
				category_visible = _o._label_type == Omni_Button.LabelKind.RichTextLabel
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
			visible = _o._label_type == Omni_Button.LabelKind.Label
		_Group.RICH_TEXT:
			visible = _o._label_type == Omni_Button.LabelKind.RichTextLabel
		_Group.PANEL:
			visible = _o._background_mode == Omni_Button.BackgroundMode.UsePanel
		_Group.TEXTURE_RECT:
			visible = _o._background_mode == Omni_Button.BackgroundMode.UseTexture
		_Group.HOVER:
			visible = _o._hover_scale > 0.0
		_Group.BOUNDS:
			visible = _o._follow_mode != Omni_Button.FollowModeEnum.None
		_Group.JOYSTICK:
			visible = _joystick_on(_o)
		_Group.JOYSTICK_AREA:
			visible = _joystick_on(_o) and _o.EnableJoystickArea
		_Group.JOYSTICK_THUMB:
			visible = _joystick_on(_o) and _o._enable_default_thumb
		_Group.ICON:
			visible = _o._icon_texture != null
		_Group.HOLD:
			visible = _o._hold_duration > 0.0
		_Group.SWIPE:
			visible = _o._action_enabled(Omni_Button.ACT_SWIPE)
		_Group.COOLDOWN:
			visible = _cooldown_on(_o)
		_Group.COOLDOWN_INVERT:
			visible = _cooldown_on(_o) and _o.InvertOnCooldown
		_Group.COOLDOWN_HOVER:
			visible = _cooldown_on(_o) and _o._hover_scale > 0.0
		_Group.COOLDOWN_HOLD:
			visible = _cooldown_on(_o) and _o._hold_duration > 0.0
	if not visible:
		property.usage = usage & ~PROPERTY_USAGE_EDITOR

static func _joystick_on(_o: Omni_Button) -> bool:
	return _o._follow_mode == Omni_Button.FollowModeEnum.VirtualJoystick

static func _cooldown_on(_o: Omni_Button) -> bool:
	return _o._cooldown_trigger != Omni_Button.CooldownTriggerEnum.None

static func process_editor(_o: Omni_Button) -> void:
	OmniButtonSignals.auto_enable_actions_once_from_connections(_o)
	var sig := build_signature(_o)
	if sig != _o.__editor_last_sig:
		_o.__editor_last_sig = sig
		_o.queue_refresh(true, true, true)

## Editor-only: detect export/property changes without str() on Objects or huge containers.
## Unstable signatures used to fire queue_refresh every poll → repeated setup_children() → OOM.
static func build_signature(_o: Omni_Button) -> String:
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
