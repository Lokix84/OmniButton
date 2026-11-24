extends RefCounted
class_name OmniButtonState
## the state setters (selected, toggled, pressed, hovering, holding) and hold build up.
## static, every function takes the button as the first argument (_o).

static func set_selected(_o: OmniButton, value: bool) -> void:
	if _o._selected == value:
		return
	_o._selected = value
	if _o._dbg: _o._debug("Selected=%s" % str(value))
	_o._update_overlay()
	_o._invalidate_state_visuals()

static func set_toggled(_o: OmniButton, value: bool, log_change: bool = true) -> void:
	if _o._is_toggled == value:
		return
	_o._is_toggled = value
	if log_change:
		if _o._dbg: _o._debug("is_toggled=%s" % str(value))
	_o._update_overlay()
	_o._invalidate_state_visuals()

static func set_pressed(_o: OmniButton, value: bool, start_hold_build_up: bool = true) -> void:
	if _o._is_pressed == value:
		_o._invalidate_state_visuals()
		return
	var was := _o._is_pressed
	_o._is_pressed = value
	if _o._dbg: _o._debug("is_pressed=%s" % str(value))
	if start_hold_build_up and not was and value and _o._hold_duration > 0.0 and not _o._is_holding:
		begin_hold_build_up(_o)
	elif was and not value:
		OmniButtonVisuals.remove_hold_fill(_o)
	if value:
		press_output_action(_o)
	else:
		release_output_action(_o)
	_o._update_unhandled_input_processing()
	_o._invalidate_state_visuals()

## holds down output_action (only in game, and only if the input map has it).
static func press_output_action(_o: OmniButton) -> void:
	var action := _o.output_action
	if action == &"" or Engine.is_editor_hint() or _o._held_output_action != &"":
		return
	if not InputMap.has_action(action):
		push_warning("OmniButton '%s': output_action '%s' is not in the InputMap (Project Settings > Input Map)." % [_o.name, action])
		return
	_o._held_output_action = action
	Input.action_press(action)

## lets go of whatever press_output_action is holding, if anything.
static func release_output_action(_o: OmniButton) -> void:
	if _o._held_output_action == &"":
		return
	Input.action_release(_o._held_output_action)
	_o._held_output_action = &""

static func set_hovering(_o: OmniButton, value: bool) -> void:
	if _o._is_hovering == value:
		return
	_o._is_hovering = value
	if _o._dbg: _o._debug("is_hovering=%s" % str(value))
	_o._update_unhandled_input_processing()
	_o._invalidate_state_visuals()

static func set_holding(_o: OmniButton, value: bool) -> void:
	var was := _o._is_holding
	_o._is_holding = value
	if not was and value:
		OmniButtonVisuals.remove_hold_fill(_o)
	if was != value:
		if _o._dbg: _o._debug("is_holding=%s" % str(value))
	_o._invalidate_state_visuals()

static func hold_duration_changed(_o: OmniButton) -> void:
	if _o._hold_duration <= 0.0:
		_o._is_holding = false
		_o._hold_timer = 0.0
		OmniButtonVisuals.remove_hold_fill(_o)
	elif _o._is_pressed and not _o._is_holding:
		begin_hold_build_up(_o)

static func reset_press_state(_o: OmniButton, clear_swipe_start:=true, emit_swipe_ended:=false) -> void:
	_o._active_touch_index = -1
	_o._pointer_gesture_source = OmniButton.PointerGestureSource.NONE
	set_pressed(_o, false)
	set_holding(_o, false)
	if emit_swipe_ended:
		OmniButtonInput.emit_swipe_ended(_o)
	_o._is_swiping = false
	if clear_swipe_start:
		_o._swipe_start = Vector2.ZERO
	if is_instance_valid(_o._hold_fill):
		OmniButtonVisuals.remove_hold_fill(_o)

## every way of pressing comes through here (mouse, touch, input action, code), and so do hold_duration changes.
static func begin_hold_build_up(_o: OmniButton) -> void:
	_o._hold_timer = 0.0
	OmniButtonVisuals.ensure_hold_fill_rect(_o)
	OmniButtonTiming.update_hold_fill_visual(_o)
	if is_instance_valid(_o._hold_fill):
		_o._hold_fill.visible = true
	_o.set_process(true)
