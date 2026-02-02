extends RefCounted
class_name OmniButtonTiming

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func process_runtime(delta: float) -> void:
	var hover_suspended := _o._tw_active and _o.SuspendHoverDuringTypewriter
	if hover_suspended:
		var t_reset0 := min(1.0, delta * _o.HoverLerpSpeed)
		_o._lerp_scale_to(_o._panel, Vector2.ONE, t_reset0)
		_o._lerp_scale_to(_o._background_tex, Vector2.ONE, t_reset0)
		_o._lerp_scale_to(_o._icon, Vector2.ONE, t_reset0)
		_o._lerp_scale_to(_o._label, Vector2.ONE, t_reset0)
		_o._lerp_scale_to(_o._rich_label, Vector2.ONE, t_reset0)
		_o._lerp_scale_to(_o._overlay, Vector2.ONE, t_reset0)
		_o._enable_top_level(false)
	else:
		# Hold progression
		if _o._is_pressed and (not _o.EnableCooldown or not _o._cooldown_active or _o.AllowHoldDuringCooldown or _o.EnableHoldBuildUp):
			_o._hold_timer += delta
			if not _o._is_holding and _o._hold_timer >= _o.HoldDuration:
				_o.IsHolding = true
				if _o._action_enabled(_o.ACT_HOLD):
					_o.emit_signal("hold")
					_o._debug("Hold signal emitted")
					if _o.HoldAction.is_valid():
						_o.HoldAction.call()
				_o._remove_hold_fill()
			elif _o.EnableHoldBuildUp and not _o._is_holding:
				_o._update_hold_fill_visual()
		elif _o.EnableHoldBuildUp:
			_o._remove_hold_fill()

		# Hover scaling
		if _o.EnableHoverScale:
			if _o.EnableCooldown and _o._cooldown_active and _o.SuspendHoverScaleDuringCooldown:
				var t_reset := min(1.0, delta * _o.HoverLerpSpeed)
				_o._lerp_scale_to(_o._panel, Vector2.ONE, t_reset)
				_o._lerp_scale_to(_o._background_tex, Vector2.ONE, t_reset)
				_o._lerp_scale_to(_o._icon, Vector2.ONE, t_reset)
				_o._lerp_scale_to(_o._label, Vector2.ONE, t_reset)
				_o._lerp_scale_to(_o._rich_label, Vector2.ONE, t_reset)
				_o._lerp_scale_to(_o._overlay, Vector2.ONE, t_reset)
				_o._enable_top_level(false)
			else:
				var target := Vector2.ONE * _o._hover_target_scale
				var t := min(1.0, delta * _o.HoverLerpSpeed)
				var any := false
				any = _o._lerp_scale_to(_o._panel, target, t) or any
				any = _o._lerp_scale_to(_o._background_tex, target, t) or any
				any = _o._lerp_scale_to(_o._icon, target, t) or any
				any = _o._lerp_scale_to(_o._label, target, t) or any
				any = _o._lerp_scale_to(_o._rich_label, target, t) or any
				any = _o._lerp_scale_to(_o._overlay, target, t) or any
				var hold_build := _o.EnableHoldBuildUp and _o._is_pressed and not _o._is_holding
				if not any and not _o._is_hovering and not (_o._cooldown_active and _o.EnableCooldown) and not hold_build:
					_o.set_process(false)
					_o._enable_top_level(false)
		else:
			var t2 := min(1.0, delta * _o.HoverLerpSpeed)
			var any2 := false
			any2 = _o._lerp_scale_to(_o._panel, Vector2.ONE, t2) or any2
			any2 = _o._lerp_scale_to(_o._background_tex, Vector2.ONE, t2) or any2
			any2 = _o._lerp_scale_to(_o._icon, Vector2.ONE, t2) or any2
			any2 = _o._lerp_scale_to(_o._label, Vector2.ONE, t2) or any2
			any2 = _o._lerp_scale_to(_o._rich_label, Vector2.ONE, t2) or any2
			any2 = _o._lerp_scale_to(_o._overlay, Vector2.ONE, t2) or any2
			var hold_build2 := _o.EnableHoldBuildUp and _o._is_pressed and not _o._is_holding
			if not any2 and not (_o._cooldown_active and _o.EnableCooldown) and not hold_build2:
				_o.set_process(false)
				_o._enable_top_level(false)

	# Hide cooldown during buildup
	if _o.HideCooldownDuringHoldBuildUp and is_instance_valid(_o._cooldown):
		var hold_active := _o.EnableHoldBuildUp and _o._is_pressed and not _o._is_holding
		if hold_active:
			_o._cooldown.visible = false
		elif _o._cooldown_active:
			_o._cooldown.visible = true

	# Cooldown delay tick
	if _o._cooldown_delay_pending:
		_o._cooldown_delay_left = max(0.0, _o._cooldown_delay_left - delta)
		if _o._cooldown_delay_left <= 0.0:
			_o._cooldown_delay_pending = false
			_o._begin_cooldown_now()

	# Cooldown tick
	if _o._cooldown_active:
		_o._cooldown_elapsed += delta
		_o._cooldown_time_left = max(0.0, _o._cooldown_time_left - delta)
		_o._update_cooldown_visual()
		if _o._cooldown_time_left <= 0.0:
			_o._cooldown_active = false
			_o._cooldown_elapsed = 0.0
			_o._debug("Cooldown completed")
			if is_instance_valid(_o._cooldown):
				_o._cooldown.visible = false
				_o._cooldown.size = Vector2.ZERO
				_o._cooldown.position = Vector2.ZERO
			_o._invalidate_visual_state()
		elif _o.InvertOnCooldown and _o.CooldownInvertDuration > 0.0:
			if _o._cooldown_elapsed >= _o.CooldownInvertDuration and _o._cooldown_elapsed - delta < _o.CooldownInvertDuration:
				_o._invalidate_visual_state()
