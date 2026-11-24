class_name OmniJoystick
extends Control
## An on-screen joystick for touch and mouse, built from an [Omni_Button] in virtual-joystick mode.
##
## The scene has three parts: this node (the area that reacts to touches), [code]Base[/code] (the
## ring) and [code]Base/Thumb[/code] (the [Omni_Button] that follows the finger). Read [member axis],
## connect [signal axis_changed], or set the [code]action_*[/code] properties so the joystick holds
## down InputMap actions and [method Input.get_vector] works as it does with a gamepad stick.[br][br]
## [b]Fixed[/b] ([member floating] off): the ring stays where you placed it; touching anywhere on it
## starts the joystick.[br]
## [b]Floating[/b] ([member floating] on): this node is a touch zone (for example the left half of the
## screen). The ring appears where the finger lands and hides again when it lifts.

## The joystick started: a finger or the mouse went down on it.
signal started
## The stick moved. [param axis] goes from -1 to 1 on each axis (up is negative y), after the dead zone.
signal axis_changed(axis: Vector2)
## The finger lifted. [member axis] is back to zero.
signal ended

## The ring appears where the finger lands, anywhere inside this node, instead of staying in place.
@export var floating := false
## Floating only: hide the ring while nobody is touching the zone.
@export var hide_when_idle := true

@export_group("Input Actions")
## Held down with the stick's strength while it points left. Empty does nothing.
@export var action_left: StringName = &""
## Held down with the stick's strength while it points right. Empty does nothing.
@export var action_right: StringName = &""
## Held down with the stick's strength while it points up. Empty does nothing.
@export var action_up: StringName = &""
## Held down with the stick's strength while it points down. Empty does nothing.
@export var action_down: StringName = &""

## Current stick position: -1 to 1 on each axis, zero when released.
var axis := Vector2.ZERO

## The ring. Its size sets how far the thumb can travel.
@onready var base: Control = $Base
## The [Omni_Button] that follows the finger. Its joystick settings (dead zone, radius) live on it.
@onready var thumb: Omni_Button = $Base/Thumb

const _NONE := -2
const _MOUSE := -1
## Which pointer is driving the stick: _NONE, _MOUSE, or a touch index.
var _pointer := _NONE
var _warned_actions := {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# This node handles every touch, so the thumb never takes input itself.
	thumb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	thumb.joystick_axis.connect(_on_thumb_axis)
	if floating and hide_when_idle:
		base.visible = false

## Whether a finger (or the mouse) is on the stick.
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

## Moves and releases are followed everywhere on screen, so the stick keeps working when the finger
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
		# Center the ring on the finger, kept inside this node.
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
