extends RefCounted
class_name OmniButtonInput
## Pointer, touch, keyboard-activation and swipe handling.
## Static: every function takes the button as its first argument (_o).

static func screen_drag_matches_active_touch(_o: Omni_Button, drag: InputEventScreenDrag) -> bool:
	return _o._active_touch_index < 0 or drag.index == _o._active_touch_index

static func point_inside(_o: Omni_Button, global_point: Vector2) -> bool:
	var rect := _o.get_global_rect()
	if is_instance_valid(_o.BoundsSource) and _o.BoundsSource != null:
		rect = _o.BoundsSource.get_global_rect()
	if _o.HitSlop != Vector2.ZERO:
		rect = rect.grow_individual(_o.HitSlop.x, _o.HitSlop.y, _o.HitSlop.x, _o.HitSlop.y)
	return rect.has_point(global_point)

static func is_press_input(_o: Omni_Button, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		return mouse_button.button_index == MOUSE_BUTTON_LEFT and mouse_button.pressed
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	return false

static func gui_input(_o: Omni_Button, event: InputEvent) -> void:
	# Godot hands _gui_input touch positions relative to the control; everything below (hit tests,
	# joystick, follow) works in screen coordinates, as _unhandled_input and mouse global_position do.
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		event = event.duplicate()
		event.position = _o.get_global_transform() * event.position
	if _try_handle_mouse_wheel_scroll(_o, event):
		return
	if _o.FinishTypewriterOnPress and _o._tw_active and is_press_input(_o, event):
		_o.skip_typewriter()
	if _o._disabled:
		return
	if _o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and not _o._is_pressed:
		return
	var inside := input_inside(_o, event)

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if not inside:
				return
			if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.NativeTouch:
				return
			_o._pointer_gesture_source = Omni_Button.PointerGestureSource.Mouse
			_o._active_touch_index = -1
			_begin_press_state(_o)
			_o._is_swiping = false
			_o._swipe_origin = mb.position

			_begin_follow_or_joystick(_o, mb.global_position, "mouse")

			if _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeInit == _o.SwipeInitMode.OnPressed:
				_o._swipe_start = mb.position
			_emit_pressed(_o, "mouse")
			# Toggle on press for explicit ToggleOnPress, or momentary+Toggle action
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
				_toggle_and_emit(_o, "mouse press")
			if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPress or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
				_o.call_deferred("start_cooldown")
			if _o._hold_duration > 0.0 and not _o._is_holding:
				OmniButtonState.begin_hold_build_up(_o)
			_finish_press_visuals(_o)
		else:
			if _o._pointer_gesture_source != Omni_Button.PointerGestureSource.Mouse or not _o._is_pressed:
				return
			# Mirror of the touch-release path: MouseSwipeExit = OnReleased ends the swipe on release.
			if _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeExit == _o.SwipeExitMode.OnReleased:
				_end_swipe(_o, true)
			OmniButtonState.reset_press_state(_o, true, false)
			_emit_released(_o, "mouse", inside)
			if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnRelease or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
				OmniButtonTiming.start_cooldown(_o)

			if _o._vj_active:
				_end_joystick_if_active(_o, "mouse release")
			# Toggle on release regardless of whether the pointer is still inside.
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
				_toggle_and_emit(_o, "mouse release")
			_finish_release_visuals(_o)

	elif _o._is_pressed and event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _o._follow_mode == _o.FollowModeEnum.VirtualJoystick and _o._vj_active:
			if _o.JoystickSnapToInput:
				_o._ensure_joystick().move_to_global(mm.global_position)
			_o._ensure_joystick().emit_axis_for(mm.global_position)
		elif _o._follow_mode == _o.FollowModeEnum.FollowBoth:
			_o._ensure_joystick().move_to_global(mm.global_position)
		# Swipe detection while pressed (mouse motion)
		if _o._action_enabled(_o.ACT_SWIPE):
			_swipe_step(_o, mm.position, "MouseMotion")
		# Update swiping state
		_o._is_swiping = (mm.position - _o._swipe_origin).length() > _o.SwipeThreshold

	elif _o._is_pressed and event is InputEventScreenDrag and screen_drag_matches_active_touch(_o, event as InputEventScreenDrag):
		var sd := event as InputEventScreenDrag
		if _o._follow_mode == _o.FollowModeEnum.VirtualJoystick and _o._vj_active:
			if _o.JoystickSnapToInput:
				_o._ensure_joystick().move_to_global(sd.position)
			_o._ensure_joystick().emit_axis_for(sd.position)
		elif _o._follow_mode == _o.FollowModeEnum.FollowBoth:
			_o._ensure_joystick().move_to_global(sd.position)
		# Swipe detection while pressed (touch drag)
		if _o._action_enabled(_o.ACT_SWIPE):
			var inside_drag := input_inside(_o, sd)
			var allow_swipe := _o._touch_swipe_eligible if _o.TouchSwipeInit == _o.SwipeInitMode.OnPressed else inside_drag
			var end_on_hover_out := (_o.TouchSwipeExit == _o.SwipeExitMode.OnHoverOut)
			if (not allow_swipe) or (end_on_hover_out and not inside_drag):
				_end_swipe(_o, true)
			else:
				_swipe_step(_o, sd.position, "TouchDrag")
		# Update swiping state
		_o._is_swiping = input_inside(_o, sd) and (sd.position - _o._swipe_origin).length() > _o.SwipeThreshold

	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		var gp := st.position
		if st.pressed:
			_o._touch_swipe_eligible = input_inside(_o, st)
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
				_begin_press_state(_o)
				_o._is_swiping = false
				_o._swipe_origin = st.position
				_begin_follow_or_joystick(_o, gp, "touch")
				if _o._action_enabled(_o.ACT_SWIPE) and _o.TouchSwipeInit == _o.SwipeInitMode.OnPressed:
					_o._swipe_start = st.position
				_emit_pressed(_o, "touch")
				if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
					_toggle_and_emit(_o, "touch press")
				if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPress or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
					_o.call_deferred("start_cooldown")
				if _o._hold_duration > 0.0 and not _o._is_holding:
					OmniButtonState.begin_hold_build_up(_o)
				_finish_press_visuals(_o)
		elif _o._active_touch_index >= 0 and st.index == _o._active_touch_index:
			if _o._pointer_gesture_source != Omni_Button.PointerGestureSource.NativeTouch:
				return
			if _o.TouchSwipeExit == _o.SwipeExitMode.OnReleased:
				_o._is_swiping = false
				emit_swipe_ended(_o)
				_o._swipe_start = Vector2.ZERO
			_o._touch_swipe_eligible = false
			OmniButtonState.reset_press_state(_o, true, false)
			_emit_released(_o, "touch", inside)
			if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnRelease or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
				OmniButtonTiming.start_cooldown(_o)
			if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
				_toggle_and_emit(_o, "touch release")
			if _o._vj_active:
				_end_joystick_if_active(_o, "touch release")
			_finish_release_visuals(_o)

	# Swipe via drag or motion
	if _o._action_enabled(_o.ACT_SWIPE) and event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if screen_drag_matches_active_touch(_o, drag):
			_swipe_step(_o, drag.position, "TouchDrag")
	elif _o._action_enabled(_o.ACT_SWIPE) and _o._is_pressed and event is InputEventMouseMotion:
		var motion := event as InputEventMouseMotion
		_swipe_step(_o, motion.position, "MouseMotion")
	elif _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeInit == _o.SwipeInitMode.OnHoverIn and event is InputEventMouseMotion:
		var hover_motion := event as InputEventMouseMotion
		var inside_move := input_inside(_o, hover_motion)
		if not inside_move:
			if _o.MouseSwipeExit == _o.SwipeExitMode.OnHoverOut:
				_end_swipe(_o, true)
		else:
			if _o._swipe_start == Vector2.ZERO:
				_o._swipe_start = hover_motion.global_position
				_o._swipe_origin = hover_motion.global_position
			else:
				_swipe_step(_o, hover_motion.global_position, "Hover", false)
			# remain in swiping state while inside; exit controlled by MouseSwipeExit
			_o._is_swiping = true
	elif try_process_activation_action(_o, event):
		pass

static func _try_handle_mouse_wheel_scroll(_o: Omni_Button, event: InputEvent) -> bool:
	if not event is InputEventMouseButton:
		return false
	var mouse_button := event as InputEventMouseButton
	if not mouse_button.pressed:
		return false

	var delta := 0
	match mouse_button.button_index:
		MOUSE_BUTTON_WHEEL_UP:
			delta = -96
		MOUSE_BUTTON_WHEEL_DOWN:
			delta = 96
		_:
			return false

	var parent: Node = _o.get_parent()
	while parent != null:
		if parent is ScrollContainer:
			var scroll := parent as ScrollContainer
			scroll.scroll_vertical = max(0, scroll.scroll_vertical + delta)
			return true
		parent = parent.get_parent()
	return false

static func try_process_activation_action(_o: Omni_Button, event: InputEvent) -> bool:
	if _o._active_activation_action != &"" and event.is_action_released(_o._active_activation_action):
		release_activation_action(_o)
		_o.get_viewport().set_input_as_handled()
		return true
	if _o.focus_mode == Control.FOCUS_NONE or not _o.has_focus() or not _o.is_visible_in_tree():
		return false
	var action := _o.ActivationAction
	if action == &"" or not event.is_action_pressed(action):
		return false
	if _o.FinishTypewriterOnPress and _o._tw_active:
		_o.skip_typewriter()
		_o.get_viewport().set_input_as_handled()
		return true
	if _o._disabled or _o._follow_mode != _o.FollowModeEnum.None:
		return false
	if _o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and not _o._is_pressed:
		return false
	if _o._is_pressed:
		return false
	_o._active_activation_action = action
	_begin_press_state(_o)
	_emit_pressed(_o, "input action")
	if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnPress or (_o.InteractionMode == _o.InteractionModeEnum.Momentary and _o._action_enabled(_o.ACT_TOGGLE)):
		_toggle_and_emit(_o, "input action")
	if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPress or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
		_o.call_deferred("start_cooldown")
	if _o._hold_duration > 0.0 and not _o._is_holding:
		OmniButtonState.begin_hold_build_up(_o)
	_finish_press_visuals(_o)
	_o.get_viewport().set_input_as_handled()
	return true

static func release_activation_action(_o: Omni_Button) -> void:
	if _o._active_activation_action == &"":
		return
	_o._active_activation_action = &""
	OmniButtonState.reset_press_state(_o, true, false)
	_emit_released(_o, "input action", true)
	if _o._cooldown_trigger == _o.CooldownTriggerEnum.OnRelease or _o._cooldown_trigger == _o.CooldownTriggerEnum.OnPressAndRelease:
		OmniButtonTiming.start_cooldown(_o)
	if _o._vj_active:
		_end_joystick_if_active(_o, "input action release")
	if _o.InteractionMode == _o.InteractionModeEnum.ToggleOnRelease:
		_toggle_and_emit(_o, "input action")
	_finish_release_visuals(_o)

static func unhandled_input(_o: Omni_Button, event: InputEvent) -> void:
	if try_process_activation_action(_o, event):
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not (event as InputEventMouseButton).pressed:
		if _o._pointer_gesture_source == Omni_Button.PointerGestureSource.NativeTouch:
			return
		if _o._active_touch_index >= 0:
			return
		if _o._is_pressed or _o._vj_active or _o._is_swiping:
			OmniButtonState.reset_press_state(_o, true, true)
			if _o._vj_active:
				_end_joystick_if_active(_o)
			_finish_release_visuals(_o)
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
			OmniButtonState.reset_press_state(_o, true, true)
			if _o._vj_active:
				_end_joystick_if_active(_o, "_unhandled touch")
			_finish_release_visuals(_o)
			_o.get_viewport().set_input_as_handled()

static func on_mouse_entered(_o: Omni_Button) -> void:
	if _o._disabled:
		return
	_o.IsHovering = true
	# Initialize hover-based swipe origin if enabled
	if _o.MouseSwipeInit == _o.SwipeInitMode.OnHoverIn:
		_o._swipe_origin = _o.get_global_mouse_position()
		if _o._swipe_start == Vector2.ZERO:
			_o._swipe_start = _o.get_global_mouse_position()
	if _o._action_enabled(_o.ACT_HOVER) and not (_o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active):
		_o.emit_signal("hover_in")
		if _o.HoverInAction.is_valid(): _o.HoverInAction.call()
		else: _o._run_built_in_hover_in()
	if _o._hover_scale > 0.0:
		if not (_o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown):
			OmniButtonTiming.update_hover_pivots(_o)
			_o._hover_target_scale = OmniButtonTiming.hover_target_for_viewport(_o)
			_o._enable_top_level(true)
		_o.set_process(true)
	_finish_hover_visuals(_o)

static func on_mouse_exited(_o: Omni_Button) -> void:
	if _o._disabled:
		return
	_o.IsHovering = false
	if _o._action_enabled(_o.ACT_HOVER) and not (_o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active):
		_o.emit_signal("hover_out")
		if _o.HoverOutAction.is_valid(): _o.HoverOutAction.call()
		else: _o._run_built_in_hover_out()
	if _o._action_enabled(_o.ACT_SWIPE) and _o.MouseSwipeExit == _o.SwipeExitMode.OnHoverOut:
		_o._is_swiping = false
		_o._swipe_start = Vector2.ZERO
		emit_swipe_ended(_o)
	if _o._hover_scale > 0.0:
		if not (_o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown):
			OmniButtonTiming.update_hover_pivots(_o)
			_o._hover_target_scale = 1.0
		_o.set_process(true)
	_finish_hover_visuals(_o)

static func input_inside(_o: Omni_Button, event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		return point_inside(_o, mb.global_position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		return point_inside(_o, mm.global_position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		return point_inside(_o, st.position)
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		return point_inside(_o, sd.position)
	return false

static func _begin_press_state(_o: Omni_Button) -> void:
	_o._hold_timer = 0.0
	_o.IsHolding = false
	_o.IsPressed = true

static func _begin_follow_or_joystick(_o: Omni_Button, global_pos: Vector2, debug_tag: String) -> void:
	if _o._follow_mode == _o.FollowModeEnum.VirtualJoystick:
		_o._ensure_joystick().begin_from_input(global_pos, debug_tag)
	elif _o._follow_mode == _o.FollowModeEnum.FollowBoth:
		_o._enable_top_level(true)
		_o._ensure_joystick().move_to_global(global_pos)

static func _emit_pressed(_o: Omni_Button, source: String) -> void:
	if _o._action_enabled(_o.ACT_PRESSED):
		_o.emit_signal("pressed")
		if _o._dbg: _o._debug("Pressed signal emitted (%s)" % source)
		if _o.PressedAction.is_valid(): _o.PressedAction.call()
		else: _o._run_built_in_pressed()
	else:
		if _o._dbg: _o._debug("Pressed skipped (%s ActionMask)" % source)

static func _emit_released(_o: Omni_Button, source: String, inside: bool) -> void:
	if _o._action_enabled(_o.ACT_RELEASED) and inside:
		_o.emit_signal("released")
		if _o._dbg: _o._debug("Released signal emitted (%s)" % source)
		if _o.ReleasedAction.is_valid(): _o.ReleasedAction.call()
		else: _o._run_built_in_released()
	elif not _o._action_enabled(_o.ACT_RELEASED):
		if _o._dbg: _o._debug("Released skipped (%s ActionMask)" % source)

static func _end_joystick_if_active(_o: Omni_Button, debug_tag: String = "") -> void:
	if _o._vj_active:
		_o._ensure_joystick().end_from_input(debug_tag)

static func _finish_press_visuals(_o: Omni_Button) -> void:
	_o._invalidate_state_visuals()

static func _finish_hover_visuals(_o: Omni_Button) -> void:
	_o._invalidate_state_visuals()

static func _finish_release_visuals(_o: Omni_Button) -> void:
	_o._enable_top_level(false)
	_o._invalidate_state_visuals()

static func _swipe_step(_o: Omni_Button, pos: Vector2, source: String, reset_to_zero: bool = true) -> void:
	if _o._swipe_start == Vector2.ZERO:
		_o._swipe_start = pos
	else:
		var direction := pos - _o._swipe_start
		if direction.length() > _o.SwipeThreshold:
			var dir_norm := direction.normalized()
			_o.emit_signal("swipe", dir_norm)
			_o._swipe_emitted = true
			if _o._dbg: _o._debug("Swipe emitted dir=%s source=%s" % [str(dir_norm), source])
			if _o.SwipeAction.is_valid(): _o.SwipeAction.call(dir_norm)
			else: _o._run_built_in_swipe(dir_norm)
			_o._swipe_start = Vector2.ZERO if reset_to_zero else pos

static func _end_swipe(_o: Omni_Button, emit_ended: bool) -> void:
	_o._is_swiping = false
	if emit_ended:
		emit_swipe_ended(_o)
	_o._swipe_start = Vector2.ZERO

## Flip the toggle state and emit toggled + ToggledAction (shared by mouse, touch and input-action paths).
static func _toggle_and_emit(_o: Omni_Button, source: String) -> void:
	OmniButtonState.set_toggled(_o, not _o._is_toggled, false)
	_o.emit_signal("toggled", _o._is_toggled)
	if _o.ToggledAction.is_valid(): _o.ToggledAction.call(_o._is_toggled)
	else: _o._run_built_in_toggled(_o._is_toggled)
	if _o._dbg: _o._debug("Toggled -> %s (%s)" % [str(_o._is_toggled), source])

## Single exit point for swipe_ended: only fires when swipe actions are enabled and a swipe
## actually fired during this gesture, so a plain press/release or hover never emits it.
static func emit_swipe_ended(_o: Omni_Button) -> void:
	var swiped := _o._swipe_emitted
	_o._swipe_emitted = false
	if swiped and _o._action_enabled(_o.ACT_SWIPE):
		_o.emit_signal("swipe_ended")
