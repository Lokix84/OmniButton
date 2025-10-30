extends Control

var _move_active := false
var _look_active := false
var _active_touch_index: int = -1
var _active_look_touch_index: int = -1

var _gamepad: Control
var _center: Omni_Button
var _move_area: Control

var _lookjoystick: Control
var _lookcenter: Omni_Button
var _look_area: Control

var _up: Omni_Button
var _down: Omni_Button
var _left: Omni_Button
var _right: Omni_Button
var _last_hover: Omni_Button

var _output: Omni_Button
var _selected_container: Node
var _selected_buttons: Array = []

func _ready() -> void:
	# Find nodes already present in the scene (mirrors CSharpTest)
	_find_nodes()
	_wire_handlers()

	# Logger button (unique name, name, or group fallback)
	_output = get_node_or_null("%ButtonOutput")
	if _output == null:
		_output = get_node_or_null("ButtonOutput")
	if _output == null:
		var outs := get_tree().get_nodes_in_group("Output")
		if outs.size() > 0 and outs[0] is Omni_Button:
			_output = outs[0]
	if is_instance_valid(_output):
		_output.LabelText = "Logger ready"
		_connect_all_buttons_to_output(_output)

	# Optional selected-item container
	_selected_container = get_node_or_null("UI/HotbarHUD/SingleSelectList")
	if _selected_container == null:
		_selected_container = get_node_or_null("SelectedItems")
	if _selected_container != null:
		_wire_selected_items(_selected_container)

func _find_nodes() -> void:
	_move_area = get_node_or_null("TouchArea/Move")
	_look_area = get_node_or_null("TouchArea/Look")
	_gamepad = get_node_or_null("Gamepad")
	_center = get_node_or_null("Gamepad/Center")
	_lookjoystick = get_node_or_null("LookJoystick")
	_lookcenter = get_node_or_null("LookJoystick/Center")
	_up = get_node_or_null("Gamepad/Up")
	_down = get_node_or_null("Gamepad/Down")
	_left = get_node_or_null("Gamepad/Left")
	_right = get_node_or_null("Gamepad/Right")

	# Set bounds for joysticks like CSharpTest
	if is_instance_valid(_center) and is_instance_valid(_gamepad):
		_center.BoundsSource = _gamepad
	if is_instance_valid(_lookcenter) and is_instance_valid(_lookjoystick):
		_lookcenter.BoundsSource = _lookjoystick

func _wire_handlers() -> void:
	if is_instance_valid(_move_area):
		_move_area.connect("gui_input", Callable(self, "_on_move_gui_input"))
	if is_instance_valid(_look_area):
		_look_area.connect("gui_input", Callable(self, "_on_look_gui_input"))

func _on_move_gui_input(ev: InputEvent) -> void:
	if _move_active:
		return
	if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		_active_touch_index = (ev as InputEventScreenTouch).index
		_begin_move_at((ev as InputEventScreenTouch).position)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_active_touch_index = -1
			_begin_move_at(mb.global_position)
			get_viewport().set_input_as_handled()

func _on_look_gui_input(ev: InputEvent) -> void:
	if _look_active:
		return
	if ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed:
		_active_look_touch_index = (ev as InputEventScreenTouch).index
		_begin_look_at((ev as InputEventScreenTouch).position)
		get_viewport().set_input_as_handled()
	elif ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_active_look_touch_index = -1
			_begin_look_at(mb.global_position)
			get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
	if not (_move_active or _look_active):
		return
	if event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		if _move_active and _active_touch_index >= 0 and sd.index == _active_touch_index:
			_update_center_follow(sd.position)
		if _look_active and _active_look_touch_index >= 0 and sd.index == _active_look_touch_index:
			_update_look_follow(sd.position)
	elif event is InputEventMouseMotion:
		var mm := event as InputEventMouseMotion
		if _move_active and _active_touch_index == -1:
			_update_center_follow(mm.global_position)
		if _look_active and _active_look_touch_index == -1:
			_update_look_follow(mm.global_position)
	elif event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed:
		var st := event as InputEventScreenTouch
		if _move_active and _active_touch_index >= 0 and st.index == _active_touch_index:
			_end_move()
		if _look_active and _active_look_touch_index >= 0 and st.index == _active_look_touch_index:
			_end_look()
	elif event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			if _move_active and _active_touch_index == -1:
				_end_move()
			if _look_active and _active_look_touch_index == -1:
				_end_look()

func _begin_move_at(global_point: Vector2) -> void:
	_move_active = true
	_gamepad.visible = true
	_center.start_virtual_joystick_at(global_point)
	_update_directional_hover(global_point)

func _begin_look_at(global_point: Vector2) -> void:
	_look_active = true
	_lookjoystick.visible = true
	_lookcenter.start_virtual_joystick_at(global_point)

func _update_center_follow(global_point: Vector2) -> void:
	_center.update_virtual_joystick(global_point)
	_update_directional_hover(global_point)

func _update_look_follow(global_point: Vector2) -> void:
	_lookcenter.update_virtual_joystick(global_point)

func _end_move() -> void:
	if not _move_active:
		return
	_move_active = false
	_active_touch_index = -1
	if is_instance_valid(_last_hover):
		_last_hover._on_mouse_exited()
		_last_hover = null
	_center.stop_virtual_joystick()
	_gamepad.visible = false

func _end_look() -> void:
	if not _look_active:
		return
	_look_active = false
	_active_look_touch_index = -1
	_lookcenter.stop_virtual_joystick()
	_lookjoystick.visible = false

func _update_directional_hover(global_point: Vector2) -> void:
	var hit: Omni_Button = null
	if is_instance_valid(_up) and _is_point_in_node(_up, global_point):
		hit = _up
	elif is_instance_valid(_down) and _is_point_in_node(_down, global_point):
		hit = _down
	elif is_instance_valid(_left) and _is_point_in_node(_left, global_point):
		hit = _left
	elif is_instance_valid(_right) and _is_point_in_node(_right, global_point):
		hit = _right

	if hit == _last_hover:
		return
	if is_instance_valid(_last_hover):
		_last_hover._on_mouse_exited()
	if is_instance_valid(hit):
		hit._on_mouse_entered()
	_last_hover = hit

func _is_point_in_node(node: Control, global_point: Vector2) -> bool:
	return node.get_global_rect().has_point(global_point)

# ===== Logging wiring =====
func _connect_all_buttons_to_output(output: Omni_Button) -> void:
	var list: Array = []
	var grouped := get_tree().get_nodes_in_group("Button")
	if grouped.size() > 0:
		for n in grouped:
			if n is Omni_Button and n != output:
				list.append(n)
	else:
		_collect_omni_buttons(self, output, list)
	for b in list:
		_connect_button_for_log(b, output)

func _collect_omni_buttons(root: Node, skip: Omni_Button, dst: Array) -> void:
	for child in root.get_children():
		if child is Omni_Button and child != skip:
			dst.append(child)
		if child is Node:
			_collect_omni_buttons(child, skip, dst)

func _connect_button_for_log(b: Omni_Button, output: Omni_Button) -> void:
	var _set_out: Callable = func(msg: String) -> void:
		if is_instance_valid(output):
			output.LabelText = msg

	# Ensure signals will be emitted by enabling action flags

	b.EnablePressedActions = true
	b.EnableReleasedActions = true
	b.EnableHoverActions = true
	b.EnableToggleActions = true
	b.EnableHoldActions = true
	b.EnableSwipeActions = true

	_safe_connect(b, "pressed", func(): _set_out.call("[%s] Pressed" % b.name))
	_safe_connect(b, "released", func(): _set_out.call("[%s] Released" % b.name))
	_safe_connect(b, "toggled", func(v): _set_out.call("[%s] Toggled: %s" % [b.name, str(v)]))
	_safe_connect(b, "hover_in", func(): _set_out.call("[%s] HoverIn" % b.name))
	_safe_connect(b, "hover_out", func(): _set_out.call("[%s] HoverOut" % b.name))
	_safe_connect(b, "hold", func(): _set_out.call("[%s] Hold" % b.name))
	_safe_connect(b, "swipe", func(dir): _set_out.call("[%s] Swipe: %s" % [b.name, str(dir)]))
	_safe_connect(b, "joystick_started", func(): _set_out.call("[%s] JoystickStarted" % b.name))
	_safe_connect(b, "joystick_axis", func(axis): _set_out.call("[%s] JoystickAxis: %s" % [b.name, str(axis)]))
	_safe_connect(b, "joystick_ended", func(): _set_out.call("[%s] JoystickEnded" % b.name))
	_safe_connect(b, "log", func(m): _set_out.call("[%s] Log: %s" % [b.name, m]))
	_safe_connect(b, "warning", func(m): _set_out.call("[%s] Warn: %s" % [b.name, m]))
	_safe_connect(b, "error", func(m): _set_out.call("[%s] Error: %s" % [b.name, m]))

func _safe_connect(obj: Object, sig: StringName, callable: Callable) -> void:
	if not obj.is_connected(sig, callable):
		obj.connect(sig, callable)

# ===== Selected item helpers =====
func _wire_selected_items(container: Node) -> void:
	_selected_buttons.clear()
	for child in container.get_children():
		if child is Omni_Button:
			_selected_buttons.append(child)
			var ob: Omni_Button = child
			_safe_connect(ob, "pressed", func(): _on_selected_item_pressed(ob))

func _on_selected_item_pressed(clicked: Omni_Button) -> void:
	for b in _selected_buttons:
		if not is_instance_valid(b):
			continue
		b.Selected = (b == clicked)
