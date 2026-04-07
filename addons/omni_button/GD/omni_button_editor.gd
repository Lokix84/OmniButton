extends RefCounted
class_name OmniButtonEditor

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func process_editor(delta: float) -> void:
	_o.__editor_poll_accum += delta
	if _o.__editor_poll_accum < _o.__EDITOR_POLL_INTERVAL:
		return
	_o.__editor_poll_accum = 0.0
	_o._ensure_signals()
	_o._signals.auto_enable_actions_once_from_connections()
	var sig := build_signature()
	if sig != _o.__editor_last_sig:
		_o.__editor_last_sig = sig
		_o.queue_refresh(true, true, true)

## Editor-only: detect export/property changes without str() on Objects or huge containers.
## Unstable signatures used to fire queue_refresh every poll → repeated setup_children() → OOM.
func build_signature() -> String:
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

func _sig_value(val: Variant) -> String:
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
