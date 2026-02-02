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
var _up_left: Omni_Button
var _up_right: Omni_Button
var _down_left: Omni_Button
var _down_right: Omni_Button
var _last_hover: Omni_Button

var _output: Omni_Button
var _output2: Omni_Button
var _selected_container: Node
var _selected_buttons: Array = []
var _used_button: Omni_Button

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
		_output.LabelType = Omni_Button.LabelKind.RichTextLabel
		_output.Text = "Logger ready"
		_connect_all_buttons_to_output(_output)

	# Optional selected-item container
	_selected_container = get_node_or_null("UI/HotbarHUD/SingleSelectList")
	if _selected_container == null:
		_selected_container = get_node_or_null("SelectedItems")
	_used_button = get_node_or_null("UI/Actions/UseItem")
	if is_instance_valid(_used_button):
		_used_button.Selected = true
		_used_button.Disabled = true
	if _selected_container != null:
		_wire_selected_items(_selected_container)

	# Optional static TextBlock (typewriter demo)
	_output2 = get_node_or_null("%TextBlock")
	if _output2 == null:
		_output2 = get_node_or_null("TextBlock")
	if _output2 == null:
		var blocks := get_tree().get_nodes_in_group("Block")
		if blocks.size() > 0 and blocks[0] is Omni_Button:
			_output2 = blocks[0]
	if is_instance_valid(_output2):
		var content := _output2.TextToType if _output2.TextToType != "" else _output2.Text
		if content != "":
			_output2.TextToType = content
			_output2.DelayEffectTagsDuringTypewriter = false
			if is_instance_valid(_output):
				_output2.connect("typewriter_completed", func():
					_output.LabelType = Omni_Button.LabelKind.RichTextLabel
					_output.Text = "Typing complete"
				)
			_output2.start_typewriter_from_text_to_type(40.0, false, true)

func _find_nodes() -> void:
	_move_area = get_node_or_null("TouchArea/Move")
	_look_area = get_node_or_null("TouchArea/Look")
	_gamepad = get_node_or_null("Gamepad")
	_center = get_node_or_null("Gamepad/Center")
	_lookjoystick = get_node_or_null("LookJoystick")
	_lookcenter = get_node_or_null("LookJoystick/Center")
	if is_instance_valid(_center):
		OmniButtonPresets.apply_virtual_joystick(_center)
	if is_instance_valid(_lookcenter):
		OmniButtonPresets.apply_virtual_joystick(_lookcenter)
	_up = get_node_or_null("Gamepad/Up")
	_down = get_node_or_null("Gamepad/Down")
	_left = get_node_or_null("Gamepad/Left")
	_right = get_node_or_null("Gamepad/Right")
	_up_left = get_node_or_null("Gamepad/UpLeft")
	_up_right = get_node_or_null("Gamepad/UpRight")
	_down_left = get_node_or_null("Gamepad/DownLeft")
	_down_right = get_node_or_null("Gamepad/DownRight")

	if is_instance_valid(_move_area):
		_move_area.mouse_filter = Control.MOUSE_FILTER_STOP
	if is_instance_valid(_look_area):
		_look_area.mouse_filter = Control.MOUSE_FILTER_STOP

	# Set bounds for joysticks like CSharpTest
	if is_instance_valid(_center) and is_instance_valid(_gamepad):
		_center.BoundsSource = _gamepad
		_center.EnableJoystickArea = true
		_center.JoystickAreaUseRectForClamp = true
		_center.JoystickAreaPersistent = false
		_center.JoystickAreaExternalPath = NodePath("../Border")
		_center.JoystickAreaThickness = 0
		_center.EnableDefaultThumb = false
	if is_instance_valid(_lookcenter) and is_instance_valid(_lookjoystick):
		_lookcenter.BoundsSource = _lookjoystick
		_lookcenter.JoystickHideWhenInactive = true
		_lookcenter.EnableJoystickArea = true
	if is_instance_valid(_lookjoystick):
		_lookjoystick.visible = false

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
	# Place gamepad centered on input, clamped to its parent/container.
	var parent := _gamepad.get_parent()
	var clamp: Rect2 = parent.get_global_rect() if parent is Control else get_viewport_rect()
	var half := _gamepad.size * 0.5
	var desired := global_point - half
	_gamepad.global_position = Vector2(
		clampf(desired.x, clamp.position.x, clamp.end.x - _gamepad.size.x),
		clampf(desired.y, clamp.position.y, clamp.end.y - _gamepad.size.y)
	)
	_center.position = (_gamepad.size - _center.size) / 2.0
	_center.start_virtual_joystick_at(global_point)

func _begin_look_at(global_point: Vector2) -> void:
	_look_active = true
	if not is_instance_valid(_lookjoystick) or not is_instance_valid(_lookcenter):
		return
	_lookjoystick.visible = true
	var parent := _lookjoystick.get_parent()
	var clamp: Rect2 = parent.get_global_rect() if parent is Control else get_viewport_rect()
	var half := _lookjoystick.size * 0.5
	var desired := global_point - half
	var clamped := Vector2(
		clampf(desired.x, clamp.position.x, clamp.position.x + clamp.size.x - _lookjoystick.size.x),
		clampf(desired.y, clamp.position.y, clamp.position.y + clamp.size.y - _lookjoystick.size.y)
	)
	_lookjoystick.global_position = clamped
	_lookcenter.position = (_lookjoystick.size - _lookcenter.size) / 2.0
	_lookcenter.start_virtual_joystick_at(global_point)

func _update_center_follow(global_point: Vector2) -> void:
	_center.update_virtual_joystick(global_point)
	var gp := _gamepad.get_global_rect()
	var probe := Vector2(
		clampf(global_point.x, gp.position.x, gp.end.x),
		clampf(global_point.y, gp.position.y, gp.end.y)
	)
	_update_directional_hover(probe)

func _update_look_follow(global_point: Vector2) -> void:
	_lookcenter.update_virtual_joystick(global_point)

func _end_move() -> void:
	if not _move_active:
		return
	_move_active = false
	_active_touch_index = -1
	if is_instance_valid(_last_hover):
		_last_hover.IsHovering = false
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
	elif is_instance_valid(_up_left) and _is_point_in_node(_up_left, global_point):
		hit = _up_left
	elif is_instance_valid(_up_right) and _is_point_in_node(_up_right, global_point):
		hit = _up_right
	elif is_instance_valid(_down_left) and _is_point_in_node(_down_left, global_point):
		hit = _down_left
	elif is_instance_valid(_down_right) and _is_point_in_node(_down_right, global_point):
		hit = _down_right

	if hit == _last_hover:
		return
	if is_instance_valid(_last_hover):
		_last_hover.IsHovering = false
	if is_instance_valid(hit):
		hit.IsHovering = true
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
			output.LabelType = Omni_Button.LabelKind.RichTextLabel
			output.Text = msg

	_safe_connect(b, "pressed", func(): _set_out.call("[b][%s][/b] Pressed" % b.name))
	_safe_connect(b, "released", func(): _set_out.call("[b][%s][/b] Released" % b.name))
	_safe_connect(b, "toggled", func(v): _set_out.call("[b][%s][/b] Toggled: %s" % [b.name, str(v)]))
	_safe_connect(b, "hover_in", func(): _set_out.call("[b][%s][/b] HoverIn" % b.name))
	_safe_connect(b, "hover_out", func(): _set_out.call("[b][%s][/b] HoverOut" % b.name))
	_safe_connect(b, "hold", func(): _set_out.call("[b][%s][/b] Hold" % b.name))
	_safe_connect(b, "swipe", func(dir): _set_out.call("[b][%s][/b] Swipe: %s" % [b.name, str(dir)]))
	_safe_connect(b, "joystick_started", func(): _set_out.call("[b][%s][/b] JoystickStarted" % b.name))
	_safe_connect(b, "joystick_axis", func(axis): _set_out.call("[b][%s][/b] JoystickAxis: %s" % [b.name, str(axis)]))
	_safe_connect(b, "joystick_ended", func(): _set_out.call("[b][%s][/b] JoystickEnded" % b.name))
	_safe_connect(b, "log", func(m): _set_out.call("[b][%s][/b] Log: %s" % [b.name, m]))
	_safe_connect(b, "warning", func(m): _set_out.call("[b][%s][/b] Warn: %s" % [b.name, m]))
	_safe_connect(b, "error", func(m): _set_out.call("[b][%s][/b] Error: %s" % [b.name, m]))

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
			ob.BoundsSource = ob
			_safe_connect(ob, "pressed", func(): _on_selected_item_pressed(ob))

func _on_selected_item_pressed(clicked: Omni_Button) -> void:
	if is_instance_valid(_used_button):
		_used_button.Selected = true
		_used_button.Disabled = true
	for b in _selected_buttons:
		if not is_instance_valid(b):
			continue
		b.Selected = (b == clicked)
		if b == clicked and is_instance_valid(_used_button):
			_used_button.Selected = false
			_used_button.Disabled = false

func _on_swipe_button_swipe(direction: Vector2) -> void:
	var source := get_node_or_null("UI/Icons/SwipeButton") as Omni_Button
	var d := direction
	var path := ""
	if abs(d.x) >= abs(d.y):
		path = "res://addons/omni_button/test/icons/Icon-RightArrow1.png" if d.x >= 0.0 else "res://addons/omni_button/test/icons/Icon-LeftArrow1.png"
	else:
		path = "res://addons/omni_button/test/icons/Icon-DownArrow1.png" if d.y <= 0.0 else "res://addons/omni_button/test/icons/Icon-UpArrow1.png"
	if is_instance_valid(source):
		source.IconTexture = load(path)
	if is_instance_valid(_output):
		_output.LabelType = Omni_Button.LabelKind.RichTextLabel
		_output.Text = "[SwipeButton] Swipe: %s -> %s" % [str(direction), path.get_file().get_basename()]

func _on_swipe_button_swipe_ended() -> void:
	var source := get_node_or_null("UI/Icons/SwipeButton") as Omni_Button
	if is_instance_valid(source):
		source.IconTexture = load("res://addons/omni_button/test/icons/Icon-Circle5.png")
	if is_instance_valid(_output):
		_output.LabelType = Omni_Button.LabelKind.RichTextLabel
		_output.Text = "[SwipeButton] Swipe Ended"
