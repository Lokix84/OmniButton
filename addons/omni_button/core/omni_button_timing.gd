extends RefCounted
class_name OmniButtonTiming
## Per-frame work: hover scale animation, hold build-up, cooldown timing and their fills.
## Static: every function takes the button as its first argument (_o).

## Hover scaling animates the single _Managed root (all generated visuals live under it)
## instead of each visual child separately: one transform write per frame, one pivot.
static func _hover_root(_o: Omni_Button) -> Control:
	var r := _o._managed_root
	if r != null and is_instance_valid(r):
		return r
	return null

static func managed_hover_scales_match(_o: Omni_Button, target: Vector2, eps := 0.001) -> bool:
	var r := _hover_root(_o)
	return r == null or r.scale.distance_to(target) < eps

static func hover_scale_animation_pending(_o: Omni_Button) -> bool:
	if _o._hover_scale <= 0.0:
		return false
	if _o._tw_active and _o.SuspendHoverDuringTypewriter:
		return not managed_hover_scales_match(_o, Vector2.ONE)
	if _o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown:
		return not managed_hover_scales_match(_o, Vector2.ONE)
	var target_scale := _o._hover_target_scale if _o._is_hovering else 1.0
	return not managed_hover_scales_match(_o, Vector2.ONE * target_scale)

static func update_hover_pivots(_o: Omni_Button) -> void:
	_o.pivot_offset = _o.size / 2.0
	var r := _hover_root(_o)
	if r != null:
		r.pivot_offset = r.size / 2.0

static func hover_target_for_viewport(_o: Omni_Button) -> float:
	var desired := _o._hover_scale
	var rect := _o.get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 1.0
	var viewport_rect := _o.get_viewport_rect()
	var center := rect.position + rect.size * 0.5
	var half_w := max(0.001, rect.size.x * 0.5)
	var half_h := max(0.001, rect.size.y * 0.5)
	var left_space := center.x - viewport_rect.position.x
	var right_space := viewport_rect.position.x + viewport_rect.size.x - center.x
	var top_space := center.y - viewport_rect.position.y
	var bottom_space := viewport_rect.position.y + viewport_rect.size.y - center.y
	var max_scale_x := min(left_space / half_w, right_space / half_w)
	var max_scale_y := min(top_space / half_h, bottom_space / half_h)
	return min(desired, max(1.0, min(max_scale_x, max_scale_y)))

static func lerp_scale_to(_o: Omni_Button, node: Control, target: Vector2, weight: float) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	if node.scale == target:
		return false
	var new_scale := node.scale.lerp(target, weight)
	var changed := new_scale.distance_to(target) >= 0.001
	node.scale = new_scale
	if not changed:
		node.scale = target
	return changed

static func process_runtime(_o: Omni_Button, delta: float) -> void:
	var hover_suspended := _o._tw_active and _o.SuspendHoverDuringTypewriter
	var root := _hover_root(_o)
	var lerp_t := minf(1.0, delta * _o.HoverLerpSpeed)
	if hover_suspended:
		lerp_scale_to(_o, root, Vector2.ONE, lerp_t)
		_o._enable_top_level(false)
	else:
		# Hold progression
		if _o._is_pressed and _o._hold_duration > 0.0:
			_o._hold_timer += delta
			if not _o._is_holding and _o._hold_timer >= _o._hold_duration:
				_o.IsHolding = true
				if _o._action_enabled(_o.ACT_HOLD):
					_o.emit_signal("hold")
					if _o._dbg: _o._debug("Hold signal emitted")
					if _o.HoldAction.is_valid(): _o.HoldAction.call()
					else: _o._run_built_in_hold()
				OmniButtonVisuals.remove_hold_fill(_o)
			elif _o._hold_duration > 0.0 and not _o._is_holding:
				OmniButtonTiming.update_hold_fill_visual(_o)
		elif _o._hold_duration > 0.0:
			OmniButtonVisuals.remove_hold_fill(_o)

		# Hover scaling
		if _o._hover_scale > 0.0:
			if _o._cooldown_trigger != _o.CooldownTriggerEnum.None and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown:
				lerp_scale_to(_o, root, Vector2.ONE, lerp_t)
				_o._enable_top_level(false)
			else:
				var target := Vector2.ONE * _o._hover_target_scale
				var any := lerp_scale_to(_o, root, target, lerp_t)
				var hold_build := _o._hold_duration > 0.0 and _o._is_pressed and not _o._is_holding
				# Keep top_level active while hovering to avoid toggling it and generating spurious mouse_exited events.
				if not any and not hover_scale_animation_pending(_o) and not _o._is_hovering and not (_o._cooldown_active and _o._cooldown_trigger != _o.CooldownTriggerEnum.None) and not hold_build and not _o._tw_active:
					if not Engine.is_editor_hint():
						_o._enable_top_level(false)
		else:
			var any2 := lerp_scale_to(_o, root, Vector2.ONE, lerp_t)
			var hold_build2 := _o._hold_duration > 0.0 and _o._is_pressed and not _o._is_holding
			if not any2 and not (_o._cooldown_active and _o._cooldown_trigger != _o.CooldownTriggerEnum.None) and not hold_build2 and not _o._tw_active:
				if not Engine.is_editor_hint():
					_o._enable_top_level(false)

	# Hide cooldown during buildup
	if _o.HideCooldownDuringHoldBuildUp and is_instance_valid(_o._cooldown):
		var hold_active := _o._hold_duration > 0.0 and _o._is_pressed and not _o._is_holding
		if hold_active:
			_o._cooldown.visible = false
		elif _o._cooldown_active:
			_o._cooldown.visible = true

	# Cooldown delay tick
	if _o._cooldown_delay_pending:
		_o._cooldown_delay_left = max(0.0, _o._cooldown_delay_left - delta)
		if _o._cooldown_delay_left <= 0.0:
			_o._cooldown_delay_pending = false
			OmniButtonTiming.begin_cooldown_now(_o)

	# Cooldown tick
	if _o._cooldown_active:
		_o._cooldown_elapsed += delta
		_o._cooldown_time_left = max(0.0, _o._cooldown_time_left - delta)
		OmniButtonTiming.update_cooldown_visual(_o)
		if _o._cooldown_time_left <= 0.0:
			_o._cooldown_active = false
			_o._cooldown_elapsed = 0.0
			if _o._dbg: _o._debug("Cooldown completed")
			if is_instance_valid(_o._cooldown):
				_o._cooldown.visible = false
				_o._cooldown.size = Vector2.ZERO
				_o._cooldown.position = Vector2.ZERO
			_o._invalidate_state_visuals()
		elif _o.InvertOnCooldown and _o.CooldownInvertDuration > 0.0:
			if _o._cooldown_elapsed >= _o.CooldownInvertDuration and _o._cooldown_elapsed - delta < _o.CooldownInvertDuration:
				_o._invalidate_state_visuals()

# Cooldown and hold behavior.
static func start_cooldown(_o: Omni_Button) -> void:
	if _o._cooldown_trigger == _o.CooldownTriggerEnum.None: return
	_o._cooldown_active = false
	_o._cooldown_elapsed = 0.0
	_o._cooldown_time_left = 0.0
	_o._cooldown_delay_pending = _o.CooldownStartDelay > 0.0
	_o._cooldown_delay_left = _o.CooldownStartDelay
	if _o._dbg: _o._debug("Cooldown scheduled delay=%s duration=%s trigger=%s" % [str(_o.CooldownStartDelay), str(_o.CooldownDuration), str(_o._cooldown_trigger)])
	if _o._cooldown != null and is_instance_valid(_o._cooldown):
		_o._cooldown.visible = false
		_o._cooldown.size = Vector2.ZERO
		_o._cooldown.position = Vector2.ZERO
	_o.set_process(true)
	if not _o._cooldown_delay_pending:
		begin_cooldown_now(_o)

static func begin_cooldown_now(_o: Omni_Button) -> void:
	_o._cooldown_active = true
	_o._cooldown_elapsed = 0.0
	_o._cooldown_time_left = _o.CooldownDuration
	if _o._dbg: _o._debug("Cooldown started duration=%s trigger=%s" % [str(_o.CooldownDuration), str(_o._cooldown_trigger)])
	OmniButtonVisuals.ensure_cooldown(_o)
	OmniButtonTiming.update_cooldown_visual(_o)
	_o.call_deferred("_reset_pressed_visuals_after_cooldown_start")

static func reset_pressed_visuals_after_cooldown_start(_o: Omni_Button) -> void:
	# Clear pressed and transient states, but keep hover.
	OmniButtonState.reset_press_state(_o, true, true)
	_o._enable_top_level(false)
	_o._invalidate_state_visuals()

static func update_cooldown_visual(_o: Omni_Button) -> void:
	if _o._cooldown_trigger == _o.CooldownTriggerEnum.None: return
	OmniButtonVisuals.ensure_cooldown(_o)
	if _o._cooldown == null or not is_instance_valid(_o._cooldown): return
	var total: float = max(0.0001, _o.CooldownDuration)
	var remaining: float = max(0.0, _o._cooldown_time_left)
	var progress: float = 1.0 - (remaining / total)
	var sz := _o.size
	match _o.CooldownFillDirection:
		_o.CooldownDirection.BottomToTop:
			if _o.CooldownStartFilled:
				var h := sz.y * (1.0 - progress)
				_o._cooldown.size = Vector2(sz.x, h)
				_o._cooldown.position = Vector2(0, 0)
				_o._cooldown.visible = h > 0.0
			else:
				var h2 := sz.y * progress
				_o._cooldown.size = Vector2(sz.x, h2)
				_o._cooldown.position = Vector2(0, sz.y - h2)
				_o._cooldown.visible = h2 > 0.0
		_o.CooldownDirection.TopToBottom:
			if _o.CooldownStartFilled:
				var h := sz.y * (1.0 - progress)
				_o._cooldown.size = Vector2(sz.x, h)
				_o._cooldown.position = Vector2(0, sz.y - h)
				_o._cooldown.visible = h > 0.0
			else:
				var h2 := sz.y * progress
				_o._cooldown.size = Vector2(sz.x, h2)
				_o._cooldown.position = Vector2(0, 0)
				_o._cooldown.visible = h2 > 0.0
		_o.CooldownDirection.LeftToRight:
			if _o.CooldownStartFilled:
				var w := sz.x * (1.0 - progress)
				_o._cooldown.size = Vector2(w, sz.y)
				_o._cooldown.position = Vector2(sz.x - w, 0)
				_o._cooldown.visible = w > 0.0
			else:
				var w2 := sz.x * progress
				_o._cooldown.size = Vector2(w2, sz.y)
				_o._cooldown.position = Vector2(0, 0)
				_o._cooldown.visible = w2 > 0.0
		_o.CooldownDirection.RightToLeft:
			if _o.CooldownStartFilled:
				var w := sz.x * (1.0 - progress)
				_o._cooldown.size = Vector2(w, sz.y)
				_o._cooldown.position = Vector2(0, 0)
				_o._cooldown.visible = w > 0.0
			else:
				var w2 := sz.x * progress
				_o._cooldown.size = Vector2(w2, sz.y)
				_o._cooldown.position = Vector2(sz.x - w2, 0)
				_o._cooldown.visible = w2 > 0.0

static func update_hold_fill_visual(_o: Omni_Button) -> void:
	if _o._hold_duration <= 0.0 or not _o._is_pressed: return
	OmniButtonVisuals.ensure_hold_fill_rect(_o)
	if _o._hold_fill == null or not is_instance_valid(_o._hold_fill): return
	var total: float = max(0.0001, _o._hold_duration)
	var progress: float = clamp(_o._hold_timer / total, 0.0, 1.0)
	_o._hold_fill.visible = true
	var sz := _o.size
	match _o.HoldFillDirection:
		_o.CooldownDirection.BottomToTop:
			var h := max(1.0, sz.y * progress)
			_o._hold_fill.size = Vector2(sz.x, h)
			_o._hold_fill.position = Vector2(0, sz.y - h)
		_o.CooldownDirection.TopToBottom:
			var h2 := max(1.0, sz.y * progress)
			_o._hold_fill.size = Vector2(sz.x, h2)
			_o._hold_fill.position = Vector2(0, 0)
		_o.CooldownDirection.LeftToRight:
			var w := max(1.0, sz.x * progress)
			_o._hold_fill.size = Vector2(w, sz.y)
			_o._hold_fill.position = Vector2(0, 0)
		_o.CooldownDirection.RightToLeft:
			var w2 := max(1.0, sz.x * progress)
			_o._hold_fill.size = Vector2(w2, sz.y)
			_o._hold_fill.position = Vector2(sz.x - w2, 0)


