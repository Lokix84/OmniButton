class_name OmniVirtualCursor
extends CanvasLayer
## a controller cursor for menus. a ring you move with a stick that clicks whatever's under it,
## like the menus in Destiny or The First Descendant.
##
## the ring runs through godot's normal mouse input. moving it sends mouse motion so buttons under
## it get their hover look, and the click action sends a left click at its center. so every Control
## works with it: [OmniButton], godot's [Button], sliders, scroll containers.[br][br]
## drop [code]omni_virtual_cursor.tscn[/code] into a menu scene. it shows up when the stick moves
## and hides when the mouse, a touch or the d-pad (focus navigation) gets used, so only one way of
## pointing is going at a time. while it's showing, the click action clicks under the ring instead
## of pressing the focused button.

## the ring showed up (the stick moved).
signal shown
## the ring hid (mouse, touch or d-pad got used, or [member active] got turned off).
signal hidden
## the ring clicked at [param position] (viewport coordinates).
signal clicked(position: Vector2)

enum Stick { LEFT, RIGHT }

## turns the cursor on or off. off hides the ring and leaves all input alone.
@export var active := true:
	set(value):
		active = value
		if not value and is_node_ready():
			_hide()
## which stick moves the ring.
@export var stick: Stick = Stick.LEFT
## which controller. -1 listens to all of them.
@export var device := -1
## stick movement smaller than this gets ignored.
@export_range(0.0, 0.9, 0.01) var dead_zone := 0.2
## top speed in screen heights per second, so it feels the same at any resolution.
@export_range(0.1, 5.0, 0.05) var speed := 1.2
## response curve. 1 is linear, higher gives finer control near the middle of the stick and still goes fast at full tilt.
@export_range(1.0, 4.0, 0.1) var response_curve := 2.0
## controller button that clicks under the ring (holding it holds the mouse button).
@export var click_button: JoyButton = JOY_BUTTON_A
## input map action that also clicks under the ring, for keys (godot's ui_accept has enter and space
## but no controller button). empty means only [member click_button] clicks.
@export var click_action: StringName = &"ui_accept"

@export_group("Sticky Buttons")
## speed multiplier while it's over something clickable so it's easy to stop on it (1 is no slowdown).
@export_range(0.1, 1.0, 0.05) var hover_slowdown := 0.45
## how hard the ring gets pulled toward the middle of whatever clickable thing is under it (0 is
## off). the pull lets up while the stick is pushed so it never fights the player.
@export_range(0.0, 1.0, 0.05) var snap_strength := 0.5

@export_group("Scrolling")
## the other stick scrolls whatever's under the ring. 0 turns that off.
@export_range(0.0, 40.0, 0.5) var scroll_speed := 12.0

@export_group("Look")
## ring size as a fraction of the screen height.
@export_range(0.01, 0.3, 0.005) var ring_size := 0.08
## ring color normally.
@export var ring_color := Color(1, 1, 1, 0.9)
## ring color over something clickable.
@export var hover_color := Color(1, 0.82, 0.4, 1)
## optional picture to use instead of the built in ring (drawn at ring_size and tinted by the colors).
@export var ring_texture: Texture2D:
	set(value):
		ring_texture = value
		if is_node_ready():
			_apply_look()
## hides the system mouse pointer while the ring is showing.
@export var hide_mouse_pointer := true

## middle of the ring, in viewport coordinates.
var cursor_position := Vector2.ZERO

## tags the mouse events this node makes so it can tell them apart from a real mouse.
const DEVICE_ID := -77
const _DPAD_ACTIONS := [&"ui_up", &"ui_down", &"ui_left", &"ui_right"]

@onready var _ring: ColorRect = $Ring
@onready var _picture: TextureRect = $Picture

var _visible := false
var _held := false
var _hovered: Control
var _saved_mouse_mode := Input.MOUSE_MODE_VISIBLE
var _pulse: Tween

func _ready() -> void:
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_apply_look()
	cursor_position = _screen().get_center()
	_set_ring_visible(false)

## true while the ring is on screen.
func is_shown() -> bool:
	return _visible

## moves the ring (viewport coordinates) and sends the mouse motion to go with it.
func warp_to(point: Vector2) -> void:
	cursor_position = _clamp(point)
	_place_ring()
	if _visible:
		_send_motion()

## the clickable thing under the ring, or null.
func get_hovered_control() -> Control:
	return _hovered

func _process(delta: float) -> void:
	if not active:
		return
	var move := _stick_vector(stick)
	if not _visible:
		if move != Vector2.ZERO:
			_show()
		else:
			return
	# mouse motion gets buffered until the end of the frame, so check what's under the ring here.
	_update_hovered()
	var screen := _screen()
	var step := speed * screen.size.y * delta
	if _hovered != null:
		step *= hover_slowdown
	var before := cursor_position
	cursor_position = _clamp(cursor_position + move * step)
	# snap: pull toward the middle of whatever's hovered, letting up as the stick gets pushed.
	if snap_strength > 0.0 and _hovered != null and is_instance_valid(_hovered):
		var center := _hovered.get_global_rect().get_center()
		var pull := snap_strength * (1.0 - clampf(move.length(), 0.0, 1.0))
		cursor_position = _clamp(cursor_position.lerp(center, 1.0 - exp(-pull * 12.0 * delta)))
	if cursor_position.distance_squared_to(before) > 0.0001:
		_place_ring()
		_send_motion()
	if scroll_speed > 0.0:
		_scroll(_stick_vector(Stick.RIGHT if stick == Stick.LEFT else Stick.LEFT), delta)

func _input(event: InputEvent) -> void:
	if not active or event.device == DEVICE_ID:
		return
	if _visible:
		# something else is pointing now, hide the ring.
		if (event is InputEventMouseMotion and event.relative.length_squared() > 0.0) \
				or event is InputEventScreenTouch or event is InputEventMouseButton:
			_hide()
			return
		# godot's default ui_* actions have the left stick in them too, only buttons and keys count here.
		for action in _DPAD_ACTIONS:
			if event.is_action_pressed(action) and not event is InputEventJoypadMotion:
				_hide()
				return
		if _is_click(event) and not event.is_echo():
			if event.is_pressed():
				_press(true)
			elif _held:
				_press(false)
			get_viewport().set_input_as_handled()
	elif _held and _is_click(event) and not event.is_pressed():
		_press(false)

func _is_click(event: InputEvent) -> bool:
	if event is InputEventJoypadButton and event.button_index == click_button:
		return device < 0 or event.device == device
	return click_action != &"" and InputMap.has_action(click_action) and event.is_action(click_action)

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_hide()

func _show() -> void:
	if _visible:
		return
	_visible = true
	_set_ring_visible(true)
	# the ring takes over from focus navigation while it's showing, so confirm can't press two things.
	get_viewport().gui_release_focus()
	if hide_mouse_pointer:
		_saved_mouse_mode = Input.mouse_mode
		if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
	_place_ring()
	_send_motion()
	shown.emit()

func _hide() -> void:
	if _held:
		_press(false)
	if not _visible:
		return
	_visible = false
	_hovered = null
	_set_ring_visible(false)
	if hide_mouse_pointer and Input.mouse_mode == Input.MOUSE_MODE_HIDDEN:
		Input.mouse_mode = _saved_mouse_mode
	hidden.emit()

func _press(down: bool) -> void:
	_held = down
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = down
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if down else 0
	_send(e)
	if down:
		clicked.emit(cursor_position)
		_play_pulse()

func _send_motion() -> void:
	var e := InputEventMouseMotion.new()
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if _held else 0
	_send(e)

func _scroll(v: Vector2, delta: float) -> void:
	if v == Vector2.ZERO:
		return
	for pair in [[v.y, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_UP], [v.x, MOUSE_BUTTON_WHEEL_RIGHT, MOUSE_BUTTON_WHEEL_LEFT]]:
		var amount: float = pair[0]
		if absf(amount) < 0.01:
			continue
		for down in [true, false]:
			var e := InputEventMouseButton.new()
			e.button_index = pair[1] if amount > 0.0 else pair[2]
			e.pressed = down
			e.factor = absf(amount) * scroll_speed * delta
			_send(e)

## sends a mouse event at the middle of the ring like a real mouse was there.
func _send(e: InputEventMouse) -> void:
	e.device = DEVICE_ID
	var window_point := get_viewport().get_final_transform() * cursor_position
	e.position = window_point
	e.global_position = window_point
	Input.parse_input_event(e)

func _update_hovered() -> void:
	if not _visible:
		_hovered = null
	else:
		_hovered = _clickable(get_viewport().gui_get_hovered_control())
	var color := hover_color if _hovered != null else ring_color
	if _picture.modulate != color:
		_ring.material.set_shader_parameter("ring_color", color)
		_picture.modulate = color

## the control itself, or the closest parent that takes clicks.
func _clickable(c: Control) -> Control:
	while c != null:
		if c is BaseButton or c is OmniButton or c is Range or c is LineEdit or c is TextEdit:
			return c if not (c is BaseButton and c.disabled) else null
		c = c.get_parent() as Control
	return null

func _stick_vector(which: Stick) -> Vector2:
	var axis_x := JOY_AXIS_LEFT_X if which == Stick.LEFT else JOY_AXIS_RIGHT_X
	var axis_y := JOY_AXIS_LEFT_Y if which == Stick.LEFT else JOY_AXIS_RIGHT_Y
	var v := Vector2.ZERO
	var devices: Array = [device] if device >= 0 else Input.get_connected_joypads()
	if device < 0 and devices.is_empty():
		devices = [0]
	for d in devices:
		var dv := Vector2(Input.get_joy_axis(d, axis_x), Input.get_joy_axis(d, axis_y))
		if dv.length() > v.length():
			v = dv
	var length := v.length()
	if length <= dead_zone:
		return Vector2.ZERO
	var t := clampf((length - dead_zone) / (1.0 - dead_zone), 0.0, 1.0)
	return v / length * pow(t, response_curve)

func _screen() -> Rect2:
	return get_viewport().get_visible_rect()

func _clamp(p: Vector2) -> Vector2:
	var r := _screen()
	return Vector2(clampf(p.x, r.position.x, r.end.x - 1.0), clampf(p.y, r.position.y, r.end.y - 1.0))

func _place_ring() -> void:
	var d := maxf(4.0, ring_size * _screen().size.y)
	for node: Control in [_ring, _picture]:
		node.size = Vector2(d, d)
		node.pivot_offset = node.size * 0.5
		node.position = cursor_position - node.size * 0.5

func _apply_look() -> void:
	_picture.texture = ring_texture
	_picture.modulate = Color(0, 0, 0, 0)
	_update_hovered()
	_set_ring_visible(_visible)

func _set_ring_visible(on: bool) -> void:
	_ring.visible = on and ring_texture == null
	_picture.visible = on and ring_texture != null

func _play_pulse() -> void:
	if _pulse != null and _pulse.is_valid():
		_pulse.kill()
	var node: Control = _picture if ring_texture != null else _ring
	node.scale = Vector2(0.8, 0.8)
	_pulse = create_tween()
	_pulse.tween_property(node, "scale", Vector2.ONE, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
