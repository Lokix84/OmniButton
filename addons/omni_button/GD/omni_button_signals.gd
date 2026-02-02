extends RefCounted
class_name OmniButtonSignals

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func initialize_callables() -> void:
	var fallbacks := [
		["pressed", Callable(_o, "_run_built_in_pressed")],
		["released", Callable(_o, "_run_built_in_released")],
		["hover_in", Callable(_o, "_run_built_in_hover_in")],
		["hover_out", Callable(_o, "_run_built_in_hover_out")],
		["toggled", Callable(_o, "_run_built_in_toggled")],
		["log", Callable(_o, "_run_built_in_log")],
		["warning", Callable(_o, "_run_built_in_warning")],
		["error", Callable(_o, "_run_built_in_error")],
		["hold", Callable(_o, "_run_built_in_hold")],
		["swipe", Callable(_o, "_run_built_in_swipe")],
	]
	for pair in fallbacks:
		set_callable_property(pair[0], adopt_connected_callable(pair[0], pair[1]))

func set_callable_property(name: String, callable: Callable) -> void:
	match name:
		"pressed": _o.PressedAction = callable
		"released": _o.ReleasedAction = callable
		"hover_in": _o.HoverInAction = callable
		"hover_out": _o.HoverOutAction = callable
		"toggled": _o.ToggledAction = callable
		"log": _o.LogAction = callable
		"warning": _o.WarningAction = callable
		"error": _o.ErrorAction = callable
		"hold": _o.HoldAction = callable
		"swipe": _o.SwipeAction = callable

func connect_signals() -> void:
	var pairs := [
		["pressed", _o.PressedAction],
		["released", _o.ReleasedAction],
		["hover_in", _o.HoverInAction],
		["hover_out", _o.HoverOutAction],
		["toggled", _o.ToggledAction],
		["log", _o.LogAction],
		["warning", _o.WarningAction],
		["error", _o.ErrorAction],
		["hold", _o.HoldAction],
		["swipe", _o.SwipeAction],
	]
	for p in pairs:
		var sig: StringName = p[0]
		var cb: Callable = p[1]
		if not cb.is_valid():
			continue
		if _o.has_signal(sig) and not _o.is_connected(sig, cb):
			_o.connect(sig, cb)

func connect_if_not_connected(signal_name: String, callable: Callable) -> void:
	if _o.has_signal(signal_name) and not _o.is_connected(signal_name, callable):
		_o.connect(signal_name, callable)

func disconnect_all_signal_handlers() -> void:
	if Engine.is_editor_hint():
		return
	for sig in ["pressed", "toggled", "released", "log", "warning", "error", "hover_in", "hover_out", "hold", "swipe"]:
		for conn in _o.get_signal_connection_list(sig):
			var c: Callable = conn["callable"]
			if c.get_object() == _o and _o.is_connected(sig, c):
				_o.disconnect(sig, c)

func adopt_connected_callable(sig_name: String, fallback: Callable) -> Callable:
	if not _o.has_signal(sig_name):
		return fallback
	var conns := _o.get_signal_connection_list(sig_name)
	if conns.size() > 0:
		return conns[0]["callable"]
	return fallback

func auto_enable_actions_once_from_connections() -> void:
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
			_o.ActionMaskBits |= bit
			_o._auto_action_once_bits |= bit
