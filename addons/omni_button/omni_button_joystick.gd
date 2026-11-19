extends RefCounted
class_name OmniButtonJoystick
## Virtual joystick and FollowBoth drag movement. One instance per button, created on first use.

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

## Built-in thumb: a rounded StyleBoxFlat drawn on a canvas item (z 2, same slot as the icon).
func ensure_default_thumb() -> void:
	if _o._default_thumb == null or not _o._default_thumb.is_alive():
		var thumb := OmniButtonVisuals.new_item(_o, OmniDrawItem.Kind.STYLE, "DefaultThumb", OmniButtonVisuals.Z_ICON, false)
		var style := StyleBoxFlat.new()
		style.bg_color = _o.DefaultThumbColor
		thumb.style = style
		_o._default_thumb = thumb

func update_default_thumb_visual() -> void:
	if _o._default_thumb == null or not _o._default_thumb.is_alive():
		return
	var side := max(1.0, min(_o.size.x, _o.size.y) * _o.DefaultThumbSizeRatio)
	_o._default_thumb.size = Vector2(side, side)
	_o._default_thumb.position = (_o.size - _o._default_thumb.size) / 2.0
	var flat := _o._default_thumb.style as StyleBoxFlat
	if flat != null:
		var radius := int(round(side / 2.0))
		flat.bg_color = _o.DefaultThumbColor
		flat.corner_radius_top_left = radius
		flat.corner_radius_top_right = radius
		flat.corner_radius_bottom_left = radius
		flat.corner_radius_bottom_right = radius

func get_follow_clamp_rect() -> Rect2:
	if is_instance_valid(_o.BoundsSource) and _o.BoundsSource != null:
		return _o.BoundsSource.get_global_rect()
	if _o.get_parent() is Control:
		return (_o.get_parent() as Control).get_global_rect()
	return _o.get_viewport_rect()

func move_to_global(global_point: Vector2) -> void:
	var half := _o.size * 0.5
	if _o._vj_active and _o.ClampShape == _o.JoystickClampShape.Circle:
		var circle_bounds := get_follow_clamp_rect()
		var circle_pointer := global_point
		var radius: float = float(_o.JoystickRadiusPx) if _o.JoystickRadiusPx > 0 else compute_auto_joystick_radius(_o._vj_home_global, circle_bounds)
		var delta := circle_pointer - _o._vj_home_global
		var length := delta.length()
		if length > radius and length > 0.0001:
			circle_pointer = _o._vj_home_global + delta / length * radius
		circle_pointer.x = clampf(circle_pointer.x, circle_bounds.position.x, circle_bounds.position.x + circle_bounds.size.x)
		circle_pointer.y = clampf(circle_pointer.y, circle_bounds.position.y, circle_bounds.position.y + circle_bounds.size.y)
		_o.global_position = circle_pointer - half
		return

	if _o._vj_active and _o.ClampShape == _o.JoystickClampShape.Rectangle:
		var rectangle_bounds := get_follow_clamp_rect()
		var rectangle_pointer := global_point
		var half_extents := (_o.JoystickRectSizePx / 2.0) if _o.JoystickRectSizePx != Vector2.ZERO else compute_auto_joystick_half_extents(_o._vj_home_global, rectangle_bounds)
		rectangle_pointer.x = clampf(rectangle_pointer.x, _o._vj_home_global.x - half_extents.x, _o._vj_home_global.x + half_extents.x)
		rectangle_pointer.y = clampf(rectangle_pointer.y, _o._vj_home_global.y - half_extents.y, _o._vj_home_global.y + half_extents.y)
		rectangle_pointer.x = clampf(rectangle_pointer.x, rectangle_bounds.position.x, rectangle_bounds.position.x + rectangle_bounds.size.x)
		rectangle_pointer.y = clampf(rectangle_pointer.y, rectangle_bounds.position.y, rectangle_bounds.position.y + rectangle_bounds.size.y)
		_o.global_position = rectangle_pointer - half
		return

	var desired := global_point - half
	if _o.ClampToBounds:
		var bounds := get_follow_clamp_rect()
		desired.x = clampf(desired.x, bounds.position.x, bounds.position.x + bounds.size.x - _o.size.x)
		desired.y = clampf(desired.y, bounds.position.y, bounds.position.y + bounds.size.y - _o.size.y)
	_o.global_position = desired

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
			OmniButtonVisuals.managed_add_child(_o, _o._vj_area_panel)
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
	var clamp_rect := get_follow_clamp_rect()
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

## Clamp the pointer to the follow rect, then calculate the axis from the home position.
func emit_axis_for(pointer_global: Vector2) -> void:
	if not _o._vj_active:
		return
	var clamp_rect := get_follow_clamp_rect()
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

## Programmatic start (e.g. from a separate touch area): same as an input-driven start, plus it
## shows the pressed visuals and stops the control from intercepting the pointer while dragging.
func start_virtual_joystick_at(global_point: Vector2) -> void:
	if _o._follow_mode != _o.FollowModeEnum.VirtualJoystick:
		return
	OmniButtonState.set_pressed(_o, true, false)
	_o._vj_saved_mouse_filter = _o.mouse_filter
	_o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	begin_from_input(global_point)

func begin_from_input(global_point: Vector2, debug_tag: String = "") -> void:
	if _o._follow_mode != _o.FollowModeEnum.VirtualJoystick:
		return
	_o._vj_active = true
	_o._update_unhandled_input_processing()
	_o._vj_home_global = _o.global_position + _o.size * 0.5
	_o._enable_top_level(true)
	if _o.JoystickSnapToInput:
		move_to_global(global_point)
	if _o.JoystickHideWhenInactive:
		_o.visible = true
	_o.emit_signal("joystick_started")
	if debug_tag != "":
		if _o._dbg: _o._debug("JoystickStarted (%s)" % debug_tag)
	emit_axis_for(global_point)
	if _o.EnableJoystickArea:
		ensure_and_refresh_joystick_area(_o._vj_home_global)
		set_joystick_area_visible(true)

func update_virtual_joystick(global_point: Vector2) -> void:
	if not _o._vj_active:
		return
	if _o.JoystickSnapToInput:
		move_to_global(global_point)
	emit_axis_for(global_point)

func stop_virtual_joystick() -> void:
	if not _o._vj_active:
		return
	_o.emit_signal("joystick_axis", Vector2.ZERO)
	_o.emit_signal("joystick_ended")
	if _o.JoystickResetOnRelease:
		_o.global_position = _o._vj_home_global - _o.size * 0.5
	_o._vj_active = false
	_o._update_unhandled_input_processing()
	OmniButtonState.reset_press_state(_o, true, true)
	_o._invalidate_state_visuals()
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
		if _o._dbg: _o._debug("JoystickAxis zero (%s)" % debug_tag)
	_o.emit_signal("joystick_ended")
	if debug_tag != "":
		if _o._dbg: _o._debug("JoystickEnded (%s)" % debug_tag)
	if _o.JoystickResetOnRelease:
		_o.global_position = _o._vj_home_global - _o.size * 0.5
	if _o.JoystickHideWhenInactive:
		_o.visible = false
	_o._vj_active = false
	_o._update_unhandled_input_processing()
	if _o.EnableJoystickArea and not _o.JoystickAreaPersistent:
		set_joystick_area_visible(false)
