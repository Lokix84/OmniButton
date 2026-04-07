extends RefCounted
class_name OmniButtonJoystick

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func get_external_joystick_area() -> Control:
	if _o.JoystickAreaExternalPath == null or _o.JoystickAreaExternalPath == NodePath(""):
		return null
	return _o.get_node_or_null(_o.JoystickAreaExternalPath) as Control

func ensure_and_refresh_joystick_area(home_center_global: Vector2) -> void:
	if not _o.EnableJoystickArea:
		return
	var target := get_external_joystick_area()
	if target == null:
		if _o._vj_area_panel == null or not is_instance_valid(_o._vj_area_panel):
			_o._vj_area_panel = Panel.new()
			_o._vj_area_panel.name = "JoystickArea"
			_o._vj_area_panel.top_level = true
			_o._vj_area_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_o._vj_area_panel.z_index = -1000
			_o._managed_add_child(_o._vj_area_panel)
		target = _o._vj_area_panel
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = _o.JoystickAreaColor
		sb.border_width_top = _o.JoystickAreaThickness
		sb.border_width_bottom = _o.JoystickAreaThickness
		sb.border_width_left = _o.JoystickAreaThickness
		sb.border_width_right = _o.JoystickAreaThickness
		_o._vj_area_panel.add_theme_stylebox_override("panel", sb)
	var use_circle := (_o.ClampShape == _o.JoystickClampShape.Circle) and not _o.JoystickAreaUseRectForClamp
	var clamp_rect := _o._get_follow_clamp_rect()
	if use_circle:
		var radius := float(_o.JoystickRadiusPx) if _o.JoystickRadiusPx > 0 else compute_auto_joystick_radius(home_center_global, clamp_rect)
		if target is Panel:
			var p := target as Panel
			var flat := p.get_theme_stylebox("panel")
			if flat is StyleBoxFlat:
				var r := int(round(radius))
				flat.corner_radius_top_left = r
				flat.corner_radius_top_right = r
				flat.corner_radius_bottom_left = r
				flat.corner_radius_bottom_right = r
		target.global_position = home_center_global - Vector2.ONE * radius
		target.size = Vector2.ONE * radius * 2.0
	else:
		var half_ext := (_o.JoystickRectSizePx / 2.0) if _o.JoystickRectSizePx != Vector2.ZERO else compute_auto_joystick_half_extents(home_center_global, clamp_rect)
		if target is Panel:
			var p2 := target as Panel
			var flat2 := p2.get_theme_stylebox("panel")
			if flat2 is StyleBoxFlat:
				flat2.corner_radius_top_left = 0
				flat2.corner_radius_top_right = 0
				flat2.corner_radius_bottom_left = 0
				flat2.corner_radius_bottom_right = 0
		target.global_position = home_center_global - half_ext
		target.size = half_ext * 2.0

func set_joystick_area_visible(vis: bool) -> void:
	var external := get_external_joystick_area()
	if external != null:
		external.visible = vis
	elif _o._vj_area_panel != null and is_instance_valid(_o._vj_area_panel):
		_o._vj_area_panel.visible = vis

## Matches C# EmitJoystickAxisFor: clamp pointer to follow rect, then axis from home (see OmniButton.Joystick.cs).
func emit_axis_for(pointer_global: Vector2) -> void:
	if not _o._vj_active:
		return
	var clamp_rect := _o._get_follow_clamp_rect()
	var clamped := Vector2(
		clampf(pointer_global.x, clamp_rect.position.x, clamp_rect.position.x + clamp_rect.size.x),
		clampf(pointer_global.y, clamp_rect.position.y, clamp_rect.position.y + clamp_rect.size.y)
	)
	var delta := clamped - _o._vj_home_global
	var use_circle := (_o.ClampShape == _o.JoystickClampShape.Circle)
	var axis: Vector2
	if use_circle:
		var radius: float = float(_o.JoystickRadiusPx) if _o.JoystickRadiusPx > 0 else compute_auto_joystick_radius(_o._vj_home_global, clamp_rect)
		var len := delta.length()
		if len < 1e-4 or radius < 1e-4:
			axis = Vector2.ZERO
		else:
			axis = delta / radius
			if axis.length() > 1.0:
				axis = axis.normalized()
	else:
		var half_ext := (_o.JoystickRectSizePx / 2.0) if _o.JoystickRectSizePx != Vector2.ZERO else compute_auto_joystick_half_extents(_o._vj_home_global, clamp_rect)
		var hx := maxf(1e-4, half_ext.x)
		var hy := maxf(1e-4, half_ext.y)
		axis = Vector2(clampf(delta.x / hx, -1.0, 1.0), clampf(delta.y / hy, -1.0, 1.0))
	if axis.length() < _o.JoystickDeadzone:
		axis = Vector2.ZERO
	_o.emit_signal("joystick_axis", axis)

func compute_auto_joystick_radius(home_center_global: Vector2, clamp_rect: Rect2) -> float:
	var left := home_center_global.x - clamp_rect.position.x
	var right := clamp_rect.end.x - home_center_global.x
	var top := home_center_global.y - clamp_rect.position.y
	var bottom := clamp_rect.end.y - home_center_global.y
	return max(1.0, min(left, right, top, bottom))

func compute_auto_joystick_half_extents(home_center_global: Vector2, clamp_rect: Rect2) -> Vector2:
	var left := home_center_global.x - clamp_rect.position.x
	var right := clamp_rect.end.x - home_center_global.x
	var top := home_center_global.y - clamp_rect.position.y
	var bottom := clamp_rect.end.y - home_center_global.y
	return Vector2(max(1.0, min(left, right)), max(1.0, min(top, bottom)))

func start_virtual_joystick_at(global_point: Vector2) -> void:
	if not _o.EnableVirtualJoystick and _o.FollowMode != _o.FollowModeEnum.VirtualJoystick:
		return
	_o._vj_active = true
	_o._vj_home_global = _o.global_position + _o.size * 0.5
	# Keep visuals consistent with a press
	_o._is_pressed = true
	_o._invalidate_visual_state()
	_o._vj_saved_mouse_filter = _o.mouse_filter
	_o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_o._enable_top_level(true)
	if _o.JoystickSnapToInput:
		_o._move_to_global(global_point)
	if _o.JoystickHideWhenInactive:
		_o.visible = true
	_o.emit_signal("joystick_started")
	_o._emit_joystick_axis_for(global_point)
	if _o.EnableJoystickArea:
		ensure_and_refresh_joystick_area(_o._vj_home_global)
		set_joystick_area_visible(true)

func begin_from_input(global_point: Vector2, debug_tag: String = "") -> void:
	if not _o.EnableVirtualJoystick and _o.FollowMode != _o.FollowModeEnum.VirtualJoystick:
		return
	_o._vj_active = true
	_o._vj_home_global = _o.global_position + _o.size * 0.5
	_o._enable_top_level(true)
	if _o.JoystickSnapToInput:
		_o._move_to_global(global_point)
	if _o.JoystickHideWhenInactive:
		_o.visible = true
	_o.emit_signal("joystick_started")
	if debug_tag != "":
		_o._debug("JoystickStarted (%s)" % debug_tag)
	emit_axis_for(global_point)
	if _o.EnableJoystickArea:
		ensure_and_refresh_joystick_area(_o._vj_home_global)
		set_joystick_area_visible(true)

func update_virtual_joystick(global_point: Vector2) -> void:
	if not _o._vj_active:
		return
	if _o.JoystickSnapToInput:
		_o._move_to_global(global_point)
	emit_axis_for(global_point)

func stop_virtual_joystick() -> void:
	if not _o._vj_active:
		return
	_o.emit_signal("joystick_axis", Vector2.ZERO)
	_o.emit_signal("joystick_ended")
	if _o.JoystickResetOnRelease:
		_o.global_position = _o._vj_home_global - _o.size * 0.5
	_o._vj_active = false
	_o._state.reset_press_state(true, true)
	_o._invalidate_visual_state()
	_o.mouse_filter = _o._vj_saved_mouse_filter
	_o._enable_top_level(false)
	if _o.EnableJoystickArea and not _o.JoystickAreaPersistent:
		set_joystick_area_visible(false)
	if _o.JoystickHideWhenInactive:
		_o.visible = false

func end_from_input(debug_tag: String = "") -> void:
	if not _o._vj_active:
		return
	_o.emit_signal("joystick_axis", Vector2.ZERO)
	if debug_tag != "":
		_o._debug("JoystickAxis zero (%s)" % debug_tag)
	_o.emit_signal("joystick_ended")
	if debug_tag != "":
		_o._debug("JoystickEnded (%s)" % debug_tag)
	if _o.JoystickResetOnRelease:
		_o.global_position = _o._vj_home_global - _o.size * 0.5
	if _o.JoystickHideWhenInactive:
		_o.visible = false
	_o._vj_active = false
	if _o.EnableJoystickArea and not _o.JoystickAreaPersistent:
		set_joystick_area_visible(false)
