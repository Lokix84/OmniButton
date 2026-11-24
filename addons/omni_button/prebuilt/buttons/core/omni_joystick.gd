class_name OmniJoystick
extends Control
## an on screen joystick for touch and mouse, made out of an [OmniButton] in virtual joystick mode.
##
## the scene is three parts: this node (the area that takes the touches), [code]Base[/code] (the
## ring) and [code]Base/Thumb[/code] (the [OmniButton] that follows your finger). read [member axis],
## connect [signal axis_changed], or fill in the [code]action_*[/code] settings so the joystick holds
## down input map actions and [method Input.get_vector] works just like it does with a gamepad stick.[br][br]
## [b]fixed[/b] ([member floating] off): the ring stays where you put it, touch anywhere on it to
## start.[br]
## [b]floating[/b] ([member floating] on): this node is a touch zone (like the left half of the
## screen). the ring shows up wherever the finger lands and hides again when it lifts.

## the joystick started, a finger or the mouse went down on it.
signal started
## the stick moved. [param axis] goes -1 to 1 on each axis (up is negative y), dead zone already taken out.
signal axis_changed(axis: Vector2)
## the finger lifted. [member axis] is back to zero.
signal ended

## the ring shows up wherever the finger lands inside this node instead of staying put.
@export var floating := false
## floating only: hides the ring while nobody's touching the zone.
@export var hide_when_idle := true

@export_group("Input Actions")
## held down (as hard as the stick is pushed) while it points left. empty does nothing.
@export var action_left: StringName = &""
## held down (as hard as the stick is pushed) while it points right. empty does nothing.
@export var action_right: StringName = &""
## held down (as hard as the stick is pushed) while it points up. empty does nothing.
@export var action_up: StringName = &""
## held down (as hard as the stick is pushed) while it points down. empty does nothing.
@export var action_down: StringName = &""

## where the stick is right now: -1 to 1 on each axis, zero when let go.
var axis := Vector2.ZERO

## the ring. its size is how far the thumb can go.
@onready var base: Control = $Base
## the [OmniButton] that follows the finger. its joystick settings (dead zone, radius) are on it.
@onready var thumb: OmniButton = $Base/Thumb

const _NONE := -2
const _MOUSE := -1
## which pointer is driving the stick: _NONE, _MOUSE, or a touch index.
var _pointer := _NONE
var _warned_actions := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# this node handles all the touches, so the thumb never takes input itself.
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.joystick_axis.connect(_on_thumb_axis)
	if floating and hide_when_idle:
		base.visible = false

## true while a finger (or the mouse) is on the stick.
func is_active() -> bool:
	return _pointer != _NONE

func _gui_input(event: InputEvent) -> void:
	if _pointer != _NONE:
		return
	if event is InputEventScreenTouch and event.pressed:
		_begin(event.index, get_global_transform() * event.position)
		accept_event()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT \
			and event.device != InputEvent.DEVICE_ID_EMULATION:
		_begin(_MOUSE, get_global_transform() * event.position)
		accept_event()

## moves and releases get tracked over the whole screen, so the stick keeps working when the finger
## slides off this node.
func _input(event: InputEvent) -> void:
	if _pointer == _NONE:
		return
	if event is InputEventScreenDrag and event.index == _pointer:
		thumb.update_virtual_joystick(_to_canvas(event.position))
	elif event is InputEventScreenTouch and not event.pressed and event.index == _pointer:
		_end()
	elif _pointer == _MOUSE and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event is InputEventMouseMotion:
			thumb.update_virtual_joystick(_to_canvas(event.position))
		elif event is InputEventMouseButton and not event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE or (what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree()):
		if _pointer != _NONE:
			_end()

func _begin(pointer: int, global_point: Vector2) -> void:
	_pointer = pointer
	if floating:
		# center the ring on the finger, but keep it inside this node.
		var local := get_global_transform().affine_inverse() * global_point
		var top_left := local - base.size * 0.5
		base.position = Vector2(
			clampf(top_left.x, 0.0, maxf(0.0, size.x - base.size.x)),
			clampf(top_left.y, 0.0, maxf(0.0, size.y - base.size.y)))
		base.visible = true
	thumb.position = (base.size - thumb.size) * 0.5
	thumb.start_virtual_joystick_at(global_point)
	started.emit()

func _end() -> void:
	_pointer = _NONE
	thumb.stop_virtual_joystick()
	thumb.position = (base.size - thumb.size) * 0.5
	if axis != Vector2.ZERO:
		_on_thumb_axis(Vector2.ZERO)
	if floating and hide_when_idle:
		base.visible = false
	ended.emit()

func _on_thumb_axis(value: Vector2) -> void:
	if value == axis:
		return
	axis = value
	_hold(action_left, maxf(0.0, -value.x))
	_hold(action_right, maxf(0.0, value.x))
	_hold(action_up, maxf(0.0, -value.y))
	_hold(action_down, maxf(0.0, value.y))
	axis_changed.emit(value)

func _hold(action: StringName, strength: float) -> void:
	if action == &"":
		return
	if not InputMap.has_action(action):
		if not _warned_actions.has(action):
			_warned_actions[action] = true
			push_warning("OmniJoystick '%s': action '%s' is not in the InputMap (Project Settings > Input Map)." % [name, action])
		return
	if strength > 0.0:
		Input.action_press(action, strength)
	else:
		Input.action_release(action)

func _to_canvas(viewport_point: Vector2) -> Vector2:
	return get_canvas_transform().affine_inverse() * viewport_point
