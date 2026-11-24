extends RefCounted
class_name OmniButtonJoystick
## virtual joystick and follow both dragging. one per button, made the first time it's needed.

var _o: OmniButton

func _init(o: OmniButton) -> void:
	_o = o

## the built in thumb: a rounded StyleBoxFlat drawn on a canvas item (z 2, same spot as the icon).
func ensure_default_thumb() -> void:
	if _o._default_thumb == null or not _o._default_thumb.is_alive():
		var thumb := OmniButtonVisuals.new_item(_o, OmniDrawItem.Kind.STYLE, "DefaultThumb", OmniButtonVisuals.Z_ICON, false)
		var style := StyleBoxFlat.new()
		style.bg_color = _o.default_thumb_color
		thumb.style = style
		_o._default_thumb = thumb

func update_default_thumb_visual() -> void:
	if _o._default_thumb == null or not _o._default_thumb.is_alive():
		return
	var side := max(1.0, min(_o.size.x, _o.size.y) * _o.default_thumb_size_ratio)
	_o._default_thumb.size = Vector2(side, side)
	_o._default_thumb.position = (_o.size - _o._default_thumb.size) / 2.0
	var flat := _o._default_thumb.style as StyleBoxFlat
	if flat != null:
		var radius := int(round(side / 2.0))
		flat.bg_color = _o.default_thumb_color
		flat.corner_radius_top_left = radius
		flat.corner_radius_top_right = radius
		flat.corner_radius_bottom_left = radius
		flat.corner_radius_bottom_right = radius

## the button's scale on screen (its parents' scale included).
func global_scale() -> Vector2:
	return _o.get_global_transform().get_scale()

## where the middle of the button is on screen.
func center_global() -> Vector2:
	return _o.get_global_transform() * (_o.size * 0.5)

## moves the button so its middle is at [param point] (screen coordinates).
func place_center(point: Vector2) -> void:
	var delta := point - center_global()
	var parent := _o.get_parent() as CanvasItem
	if not _o.top_level and parent != null:
		# position is in the parent's space, which might be scaled or rotated.
		delta = parent.get_global_transform().affine_inverse().basis_xform(delta)
	_o.position += delta

## joystick_radius_px and joystick_rect_size_px are in the button's own pixels, these scale them to the screen.
func _radius_px() -> float:
	return float(_o.joystick_radius_px) * global_scale().x

func _rect_half_px() -> Vector2:
	return _o.joystick_rect_size_px * global_scale() / 2.0

func get_follow_clamp_rect() -> Rect2:
	if is_instance_valid(_o.bounds_source) and _o.bounds_source != null:
		return _o.bounds_source.get_global_rect()
	if _o.get_parent() is Control:
		return (_o.get_parent() as Control).get_global_rect()
	return _o.get_viewport_rect()

func move_to_global(global_point: Vector2) -> void:
	var half := _o.size * global_scale() * 0.5
	if _o._vj_active and _o.clamp_shape == _o.JoystickClampShape.CIRCLE:
		var circle_bounds := get_follow_clamp_rect()
		var circle_pointer := global_point
		var radius: float = _radius_px() if _o.joystick_radius_px > 0 else compute_auto_joystick_radius(_o._vj_home_global, circle_bounds)
		var delta := circle_pointer - _o._vj_home_global
		var length := delta.length()
		if length > radius and length > 0.0001:
			circle_pointer = _o._vj_home_global + delta / length * radius
		circle_pointer.x = clampf(circle_pointer.x, circle_bounds.position.x, circle_bounds.position.x + circle_bounds.size.x)
		circle_pointer.y = clampf(circle_pointer.y, circle_bounds.position.y, circle_bounds.position.y + circle_bounds.size.y)
		place_center(circle_pointer)
		return

	if _o._vj_active and _o.clamp_shape == _o.JoystickClampShape.RECTANGLE:
		var rectangle_bounds := get_follow_clamp_rect()
		var rectangle_pointer := global_point
		var half_extents := _rect_half_px() if _o.joystick_rect_size_px != Vector2.ZERO else compute_auto_joystick_half_extents(_o._vj_home_global, rectangle_bounds)
		rectangle_pointer.x = clampf(rectangle_pointer.x, _o._vj_home_global.x - half_extents.x, _o._vj_home_global.x + half_extents.x)
		rectangle_pointer.y = clampf(rectangle_pointer.y, _o._vj_home_global.y - half_extents.y, _o._vj_home_global.y + half_extents.y)
		rectangle_pointer.x = clampf(rectangle_pointer.x, rectangle_bounds.position.x, rectangle_bounds.position.x + rectangle_bounds.size.x)
		rectangle_pointer.y = clampf(rectangle_pointer.y, rectangle_bounds.position.y, rectangle_bounds.position.y + rectangle_bounds.size.y)
		place_center(rectangle_pointer)
		return

	var desired := global_point
	if _o.clamp_to_bounds:
		var bounds := get_follow_clamp_rect()
		desired.x = clampf(desired.x, bounds.position.x + half.x, maxf(bounds.position.x + half.x, bounds.end.x - half.x))
		desired.y = clampf(desired.y, bounds.position.y + half.y, maxf(bounds.position.y + half.y, bounds.end.y - half.y))
	place_center(desired)

func get_external_joystick_area() -> Control:
	if _o.joystick_area_external_path == null or _o.joystick_area_external_path == NodePath(""):
		return null
	return _o.get_node_or_null(_o.joystick_area_external_path) as Control

func ensure_and_refresh_joystick_area(home_center_global: Vector2) -> void:
	if not _o.enable_joystick_area:
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
		sb.border_color = _o.joystick_area_color
		sb.border_width_top = _o.joystick_area_thickness
		sb.border_width_bottom = _o.joystick_area_thickness
		sb.border_width_left = _o.joystick_area_thickness
		sb.border_width_right = _o.joystick_area_thickness
		_o._vj_area_panel.add_theme_stylebox_override("panel", sb)
	var use_circle := (_o.clamp_shape == _o.JoystickClampShape.CIRCLE) and not _o.joystick_area_use_rect_for_clamp
	var clamp_rect := get_follow_clamp_rect()
	if use_circle:
		var radius := _radius_px() if _o.joystick_radius_px > 0 else compute_auto_joystick_radius(home_center_global, clamp_rect)
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
		var half_ext := _rect_half_px() if _o.joystick_rect_size_px != Vector2.ZERO else compute_auto_joystick_half_extents(home_center_global, clamp_rect)
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

## keeps the pointer inside the follow rect, then works out the axis from the home position.
func emit_axis_for(pointer_global: Vector2) -> void:
	if not _o._vj_active:
		return
	var clamp_rect := get_follow_clamp_rect()
	var clamped := Vector2(
		clampf(pointer_global.x, clamp_rect.position.x, clamp_rect.position.x + clamp_rect.size.x),
		clampf(pointer_global.y, clamp_rect.position.y, clamp_rect.position.y + clamp_rect.size.y)
	)
	var delta := clamped - _o._vj_home_global
	var use_circle := (_o.clamp_shape == _o.JoystickClampShape.CIRCLE)
	var axis: Vector2
	if use_circle:
		var radius: float = _radius_px() if _o.joystick_radius_px > 0 else compute_auto_joystick_radius(_o._vj_home_global, clamp_rect)
		var len := delta.length()
		if len < 1e-4 or radius < 1e-4:
			axis = Vector2.ZERO
		else:
			axis = delta / radius
			if axis.length() > 1.0:
				axis = axis.normalized()
	else:
		var half_ext := _rect_half_px() if _o.joystick_rect_size_px != Vector2.ZERO else compute_auto_joystick_half_extents(_o._vj_home_global, clamp_rect)
		var hx := maxf(1e-4, half_ext.x)
		var hy := maxf(1e-4, half_ext.y)
		axis = Vector2(clampf(delta.x / hx, -1.0, 1.0), clampf(delta.y / hy, -1.0, 1.0))
	if axis.length() < _o.joystick_deadzone:
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

## starting it from code (like from a separate touch area). same as starting it with input, but it
## also shows the pressed look and stops the control from grabbing the pointer while dragging.
func start_virtual_joystick_at(global_point: Vector2) -> void:
	if _o._follow_mode != _o.FollowMode.VIRTUAL_JOYSTICK:
		return
	OmniButtonState.set_pressed(_o, true, false)
	_o._vj_saved_mouse_filter = _o.mouse_filter
	_o.mouse_filter = Control.MOUSE_FILTER_IGNORE
	begin_from_input(global_point)

func begin_from_input(global_point: Vector2, debug_tag: String = "") -> void:
	if _o._follow_mode != _o.FollowMode.VIRTUAL_JOYSTICK:
		return
	_o._vj_active = true
	_o._update_unhandled_input_processing()
	_o._vj_home_global = center_global()
	_o._enable_top_level(true)
	if _o.joystick_snap_to_input:
		move_to_global(global_point)
	if _o.joystick_hide_when_inactive:
		_o.visible = true
	_o.emit_signal("joystick_started")
	if debug_tag != "":
		if _o._dbg: _o._debug("JoystickStarted (%s)" % debug_tag)
	emit_axis_for(global_point)
	if _o.enable_joystick_area:
		ensure_and_refresh_joystick_area(_o._vj_home_global)
		set_joystick_area_visible(true)

func update_virtual_joystick(global_point: Vector2) -> void:
	if not _o._vj_active:
		return
	if _o.joystick_snap_to_input:
		move_to_global(global_point)
	emit_axis_for(global_point)

func stop_virtual_joystick() -> void:
	if not _o._vj_active:
		return
	_o.emit_signal("joystick_axis", Vector2.ZERO)
	_o.emit_signal("joystick_ended")
	if _o.joystick_reset_on_release:
		place_center(_o._vj_home_global)
	_o._vj_active = false
	_o._update_unhandled_input_processing()
	OmniButtonState.reset_press_state(_o, true, true)
	_o._invalidate_state_visuals()
	_o.mouse_filter = _o._vj_saved_mouse_filter
	_o._enable_top_level(false)
	if _o.enable_joystick_area and not _o.joystick_area_persistent:
		set_joystick_area_visible(false)
	if _o.joystick_hide_when_inactive:
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
	if _o.joystick_reset_on_release:
		place_center(_o._vj_home_global)
	if _o.joystick_hide_when_inactive:
		_o.visible = false
	_o._vj_active = false
	_o._update_unhandled_input_processing()
	if _o.enable_joystick_area and not _o.joystick_area_persistent:
		set_joystick_area_visible(false)
