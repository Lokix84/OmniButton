extends RefCounted
class_name OmniButtonInput

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func gui_input(event: InputEvent) -> void:
	if _o.FinishTypewriterOnPress and _o._tw_active and _o._is_press_input(event):
		_o.skip_typewriter()
	if _o._disabled:
		return
	if _o.EnableCooldown and _o._cooldown_active and not _o._is_pressed:
		return
	var inside := input_inside(event)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if not inside:
				return
			if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.NativeTouch:
				return
			_o._pointer_gesture_source = Omni_Button.PointerGestureSource.Mouse
			_o._active_touch_index = -1
			_begin_press_state()
			_o._is_swiping = false
			_o._swipe_origin = mb.position

			_begin_follow_or_joystick(mb.global_position, "mouse")

			if _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeInit == _o.SwipeInitMode.OnPressed:
				_o._swipe_start = mb.position
			_emit_pressed("mouse")
			# Toggle on press for explicit ToggleOnPress, or momentary+Toggle action
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
				_o._is_toggled = not _o._is_toggled
				_o._update_overlay()
				_o.emit_signal("toggled", _o._is_toggled)
				if _o.ToggledAction.is_valid():
					_o.ToggledAction.call(_o._is_toggled)
				_o._debug("Toggled -> %s (mouse press)" % str(_o._is_toggled))
			if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnPress or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
				_o.call_deferred("_start_cooldown")
			if _o.EnableHoldBuildUp and not _o._is_holding:
				_o._hold_timer = 0.0
				_o._ensure_hold_fill_rect()
				_o._update_hold_fill_visual()
				if is_instance_valid(_o._hold_fill):
					_o._hold_fill.visible = true
				_o.set_process(true)
			_finish_press_visuals()
		else:
			if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.NativeTouch:
				return
			_o._state.reset_press_state(true, false)
			_emit_released("mouse", inside)
			if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnRelease or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
				_o._start_cooldown()

			if _o._vj_active:
				_end_joystick_if_active("mouse release")
			# Toggle on release regardless of inside to mirror C# behavior
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
				_o._is_toggled = not _o._is_toggled
				_o._update_overlay()
				_o.emit_signal("toggled", _o._is_toggled)
				if _o.ToggledAction.is_valid():
					_o.ToggledAction.call(_o._is_toggled)
				_o._debug("Toggled -> %s (mouse release)" % str(_o._is_toggled))
			_finish_release_visuals()

	elif _o._is_pressed and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if (_o.EnableVirtualJoystick or _o.FollowMode == _o.FollowModeEnum.VirtualJoystick) and _o._vj_active:
			if _o.JoystickSnapToInput:
				_o._move_to_global(mm.global_position)
			_o._joystick.emit_axis_for(mm.global_position)
		elif _o.FollowMode == _o.FollowModeEnum.FollowBoth:
			_o._move_to_global(mm.global_position)
		# Swipe detection while pressed (mouse motion)
		if _o._action_enabled(_o.ACT_SWIPE):
			_swipe_step(mm.position, "MouseMotion")
		# Update swiping state
		_o._is_swiping = (mm.position - _o._swipe_origin).length() > _o.SwipeThreshold

	elif _o._is_pressed and event is InputEventScreenDrag and _o._screen_drag_matches_active_touch(event as InputEventScreenDrag):
		var sd := event as InputEventScreenDrag
		if (_o.EnableVirtualJoystick or _o.FollowMode == _o.FollowModeEnum.VirtualJoystick) and _o._vj_active:
			if _o.JoystickSnapToInput:
				_o._move_to_global(sd.position)
			_o._joystick.emit_axis_for(sd.position)
		elif _o.FollowMode == _o.FollowModeEnum.FollowBoth:
			_o._move_to_global(sd.position)
		# Swipe detection while pressed (touch drag)
		if _o._action_enabled(_o.ACT_SWIPE):
			var inside_drag := input_inside(sd)
			var allow_swipe := _o._touch_swipe_eligible if _o.TouchSwipeInit == _o.SwipeInitMode.OnPressed else inside_drag
			var end_on_hover_out := (_o.TouchSwipeExit == _o.SwipeExitMode.OnHoverOut)
			if (not allow_swipe) or (end_on_hover_out and not inside_drag):
				_end_swipe(true)
			else:
				_swipe_step(sd.position, "TouchDrag")
		# Update swiping state
		_o._is_swiping = input_inside(sd) and (sd.position - _o._swipe_origin).length() > _o.SwipeThreshold

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var gp := st.position
		if st.pressed:
			_o._touch_swipe_eligible = input_inside(st)
			if _o.TouchSwipeInit == _o.SwipeInitMode.OnPressed and _o._touch_swipe_eligible:
				_o._swipe_origin = st.position
				_o._is_swiping = false
				_o._swipe_start = Vector2.ZERO
			if not inside:
				pass
			else:
				if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.Mouse:
					return
				_o._pointer_gesture_source = Omni_Button.PointerGestureSource.NativeTouch
				_o._active_touch_index = st.index
				_begin_press_state()
				_o._is_swiping = false
				_o._swipe_origin = st.position
				_begin_follow_or_joystick(gp, "touch")
				if _o._action_enabled(_o.ACT_SWIPE) and _o.TouchSwipeInit == _o.SwipeInitMode.OnPressed:
					_o._swipe_start = st.position
				_emit_pressed("touch")
				if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
					_o._is_toggled = not _o._is_toggled
					_o._update_overlay()
					_o.emit_signal("toggled", _o._is_toggled)
					if _o.ToggledAction.is_valid():
						_o.ToggledAction.call(_o._is_toggled)
					_o._debug("Toggled -> %s (touch press)" % str(_o._is_toggled))
				if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnPress or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
					_o.call_deferred("_start_cooldown")
				if _o.EnableHoldBuildUp and not _o._is_holding:
					_o._hold_timer = 0.0
					_o._ensure_hold_fill_rect()
					_o._update_hold_fill_visual()
					if is_instance_valid(_o._hold_fill):
						_o._hold_fill.visible = true
					_o.set_process(true)
				_finish_press_visuals()
		elif _o._active_touch_index >= 0 and st.index == _o._active_touch_index:
			if _o._pointer_gesture_source != Omni_Button.PointerGestureSource.NativeTouch:
				return
			if _o.TouchSwipeExit == _o.SwipeExitMode.OnReleased:
				_o._is_swiping = false
				_o.emit_signal("swipe_ended")
				_o._swipe_start = Vector2.ZERO
			_o._touch_swipe_eligible = false
			_o._state.reset_press_state(true, false)
			_emit_released("touch", inside)
			if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnRelease or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
				_o._start_cooldown()
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
				_o._is_toggled = not _o._is_toggled
				_o._update_overlay()
				_o.emit_signal("toggled", _o._is_toggled)
				if _o.ToggledAction.is_valid():
					_o.ToggledAction.call(_o._is_toggled)
				_o._debug("Toggled -> %s (touch release)" % str(_o._is_toggled))
			if _o._vj_active:
				_end_joystick_if_active("touch release")
			_finish_release_visuals()

	# Swipe via drag or motion
	if _o._action_enabled(_o.ACT_SWIPE) and event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _o._screen_drag_matches_active_touch(drag):
			_swipe_step(drag.position, "TouchDrag")
	elif _o._action_enabled(_o.ACT_SWIPE) and _o._is_pressed and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_swipe_step(motion.position, "MouseMotion")
	elif _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeInit == _o.SwipeInitMode.OnHoverIn and event is InputEventMouseMotion:
		var hover_motion := event as InputEventMouseMotion
		var inside_move := input_inside(hover_motion)
		if not inside_move:
			if _o.MouseSwipeExit == _o.SwipeExitMode.OnHoverOut:
				_end_swipe(true)
		else:
			if _o._swipe_start == Vector2.ZERO:
				_o._swipe_start = hover_motion.global_position
				_o._swipe_origin = hover_motion.global_position
			else:
				_swipe_step(hover_motion.global_position, "Hover", false)
			# remain in swiping state while inside; exit controlled by MouseSwipeExit
			_o._is_swiping = true
	elif try_process_ui_accept(event):
		pass

func try_process_ui_accept(event: InputEvent) -> bool:
	if _o.focus_mode == Control.FOCUS_NONE or not _o.has_focus():
		return false
	if not event is InputEventKey:
		return false
	var ik := event as InputEventKey
	if not ik.pressed or ik.echo:
		return false
	if not event.is_action_pressed("ui_accept"):
		return false
	if _o.FinishTypewriterOnPress and _o._tw_active:
		_o.skip_typewriter()
		_o.accept_event()
		return true
	if _o._disabled:
		return false
	if (_o.EnableVirtualJoystick or _o.FollowMode == _o.FollowModeEnum.VirtualJoystick) or _o.FollowMode != _o.FollowModeEnum.None:
		return false
	if _o.EnableCooldown and _o._cooldown_active and not _o._is_pressed:
		return false
	if _o._is_pressed:
		return false
	_o.accept_event()
	_o._pointer_gesture_source = Omni_Button.PointerGestureSource.Mouse
	_o._active_touch_index = -1
	_begin_press_state()
	_emit_pressed("keyboard")
	if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
		_o._is_toggled = not _o._is_toggled
		_o._update_overlay()
		_o.emit_signal("toggled", _o._is_toggled)
		if _o.ToggledAction.is_valid():
			_o.ToggledAction.call(_o._is_toggled)
	if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnPress or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
		_o.call_deferred("_start_cooldown")
	if _o.EnableHoldBuildUp and not _o._is_holding:
		_o._hold_timer = 0.0
		_o._ensure_hold_fill_rect()
		_o._update_hold_fill_visual()
		if is_instance_valid(_o._hold_fill):
			_o._hold_fill.visible = true
		_o.set_process(true)
	_finish_press_visuals()
	_o._state.reset_press_state(true, false)
	_emit_released("keyboard", true)
	if _o.EnableCooldown and (_o.CooldownTrigger == _o.CooldownTriggerEnum.OnRelease or _o.CooldownTrigger == _o.CooldownTriggerEnum.OnPressAndRelease):
		_o._start_cooldown()
	if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
		_o._is_toggled = not _o._is_toggled
		_o._update_overlay()
		_o.emit_signal("toggled", _o._is_toggled)
		if _o.ToggledAction.is_valid():
			_o.ToggledAction.call(_o._is_toggled)
	_finish_release_visuals()
	return true

func unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.NativeTouch:
			return
		if _o._active_touch_index >= 0:
			return
		if _o._is_pressed or _o._vj_active or _o._is_swiping:
			_o._state.reset_press_state(true, true)
			if _o._vj_active:
				_end_joystick_if_active()
			_finish_release_visuals()
			_o.get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			return
		if _o._pointer_gesture_source != Omni_Button.PointerGestureSource.NativeTouch:
			return
		if _o._active_touch_index < 0 or st.index != _o._active_touch_index:
			return
		if _o._is_pressed or _o._vj_active or _o._is_swiping:
			_o._state.reset_press_state(true, true)
			if _o._vj_active:
				_end_joystick_if_active("_unhandled touch")
			_finish_release_visuals()
			_o.get_viewport().set_input_as_handled()

func connect_mouse_events() -> void:
	_o._signals.connect_if_not_connected("mouse_entered", Callable(_o, "_on_mouse_entered"))
	_o._signals.connect_if_not_connected("mouse_exited", Callable(_o, "_on_mouse_exited"))

func on_mouse_entered() -> void:
	if _o._disabled:
		return
	_o._is_hovering = true
	# Initialize hover-based swipe origin if enabled
	if _o.MouseSwipeInit == _o.SwipeInitMode.OnHoverIn:
		_o._swipe_origin = _o.get_global_mouse_position()
		if _o._swipe_start == Vector2.ZERO:
			_o._swipe_start = _o.get_global_mouse_position()
	if _o._action_enabled(_o.ACT_HOVER) and not (_o.EnableCooldown and _o._cooldown_active):
		_o.emit_signal("hover_in")
		if _o.HoverInAction.is_valid():
			_o.HoverInAction.call()
	if _o.EnableHoverScale:
		if not (_o.EnableCooldown and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown):
			_o._update_hover_pivots()
			_o._hover_target_scale = _o._hover_target_for_viewport()
			_o._enable_top_level(true)
		_o.set_process(true)
	_finish_hover_visuals()

func on_mouse_exited() -> void:
	if _o._disabled:
		return
	_o._is_hovering = false
	if _o._action_enabled(_o.ACT_HOVER) and not (_o.EnableCooldown and _o._cooldown_active):
		_o.emit_signal("hover_out")
		if _o.HoverOutAction.is_valid():
			_o.HoverOutAction.call()
	if _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeExit == _o.SwipeExitMode.OnHoverOut:
		_o._is_swiping = false
		_o._swipe_start = Vector2.ZERO
		_o.emit_signal("swipe_ended")
	if _o.EnableHoverScale:
		if not (_o.EnableCooldown and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown):
			_o._update_hover_pivots()
			_o._hover_target_scale = 1.0
		_o.set_process(true)
	_finish_hover_visuals()

func input_inside(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return _o._point_inside(mb.global_position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		return _o._point_inside(mm.global_position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		return _o._point_inside(st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		return _o._point_inside(sd.position)
	return false

func _begin_press_state() -> void:
	_o._hold_timer = 0.0
	_o.IsHolding = false
	_o.IsPressed = true

func _begin_follow_or_joystick(global_pos: Vector2, debug_tag: String) -> void:
	if _o.EnableVirtualJoystick or _o.FollowMode == _o.FollowModeEnum.VirtualJoystick:
		_o._joystick.begin_from_input(global_pos, debug_tag)
	elif _o.FollowMode == _o.FollowModeEnum.FollowBoth:
		_o._enable_top_level(true)
		_o._move_to_global(global_pos)

func _emit_pressed(source: String) -> void:
	if _o._action_enabled(_o.ACT_PRESSED):
		_o.emit_signal("pressed")
		_o._debug("Pressed signal emitted (%s)" % source)
		if _o.PressedAction.is_valid():
			_o.PressedAction.call()
	else:
		_o._debug("Pressed skipped (%s ActionMask)" % source)

func _emit_released(source: String, inside: bool) -> void:
	if _o._action_enabled(_o.ACT_RELEASED) and inside:
		_o.emit_signal("released")
		_o._debug("Released signal emitted (%s)" % source)
		if _o.ReleasedAction.is_valid():
			_o.ReleasedAction.call()
	elif not _o._action_enabled(_o.ACT_RELEASED):
		_o._debug("Released skipped (%s ActionMask)" % source)

func _end_joystick_if_active(debug_tag: String = "") -> void:
	if _o._vj_active:
		_o._joystick.end_from_input(debug_tag)

func _finish_press_visuals() -> void:
	_o._invalidate_visual_state()

func _finish_hover_visuals() -> void:
	_o._invalidate_visual_state()

func _finish_release_visuals() -> void:
	_o._enable_top_level(false)
	_o._invalidate_visual_state()

func _swipe_step(pos: Vector2, source: String, reset_to_zero: bool = true) -> void:
	if _o._swipe_start == Vector2.ZERO:
		_o._swipe_start = pos
	else:
		var direction := pos - _o._swipe_start
		if direction.length() > _o.SwipeThreshold:
			var dir_norm := direction.normalized()
			_o.emit_signal("swipe", dir_norm)
			_o._debug("Swipe emitted dir=%s source=%s" % [str(dir_norm), source])
			if _o.SwipeAction.is_valid():
				_o.SwipeAction.call(dir_norm)
			_o._swipe_start = Vector2.ZERO if reset_to_zero else pos

func _end_swipe(emit_ended: bool) -> void:
	_o._is_swiping = false
	if emit_ended:
		_o.emit_signal("swipe_ended")
	_o._swipe_start = Vector2.ZERO
