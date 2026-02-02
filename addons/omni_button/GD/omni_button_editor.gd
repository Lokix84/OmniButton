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
	_o._signals.auto_enable_actions_once_from_connections()
	var sig := build_signature()
	if sig != _o.__editor_last_sig:
		_o.__editor_last_sig = sig
		_o.queue_refresh(true, true, true)

func build_signature() -> String:
	var sb := ""
	var props := _o.get_property_list()
	for p in props:
		if not p.has("usage"):
			continue
		var usage := int(p["usage"])
		if (usage & PROPERTY_USAGE_EDITOR) == 0:
			continue
		var name := String(p["name"])
		var val := _o.get(name)
		sb += name + "=" + str(val) + "|"
	return sb
