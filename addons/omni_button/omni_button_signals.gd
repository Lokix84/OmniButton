extends RefCounted
class_name OmniButtonSignals
## Turns on an Action switch when a handler was connected to its signal before _ready.
## Static: every function takes the button as its first argument (_o).

static func auto_enable_actions_once_from_connections(_o: Omni_Button) -> void:
	var map := {
		"pressed": _o.ACT_PRESSED,
		"released": _o.ACT_RELEASED,
		"hover_in": _o.ACT_HOVER,
		"hover_out": _o.ACT_HOVER,
		"toggled": _o.ACT_TOGGLE,
		"hold": _o.ACT_HOLD,
		"swipe": _o.ACT_SWIPE,
		"log": _o.ACT_LOG,
		"warning": _o.ACT_WARNING,
		"error": _o.ACT_ERROR,
	}
	for sig in map.keys():
		var bit: int = map[sig]
		if (_o._auto_action_once_bits & bit) != 0:
			continue
		if not _o.has_signal(sig):
			continue
		var conns := _o.get_signal_connection_list(sig)
		var has_external := false
		for conn in conns:
			var cb: Callable = conn["callable"]
			if cb.get_object() != _o:
				has_external = true
				break
		if has_external:
			_o._set_action_enabled(bit, true)
			_o._auto_action_once_bits |= bit
