extends RefCounted
class_name OmniButtonState

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func reset_press_state(clear_swipe_start:=true, emit_swipe_ended:=false) -> void:
	_o.IsPressed = false
	_o.IsHolding = false
	if _o._is_swiping and emit_swipe_ended:
		_o.emit_signal("swipe_ended")
	_o._is_swiping = false
	if clear_swipe_start:
		_o._swipe_start = Vector2.ZERO
	if is_instance_valid(_o._hold_fill):
		_o._remove_hold_fill()
