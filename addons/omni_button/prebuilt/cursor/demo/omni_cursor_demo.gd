extends Control
## try out OmniVirtualCursor on a small menu. open this scene, hit F6, plug in a controller and move
## the left stick. the menu is just normal Controls, the cursor works with any of them.

## the screen size this demo is laid out for, it scales to fit smaller or bigger windows.
const REFERENCE_SIZE := Vector2(1152, 648)

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_add_gamepad_accept()

	for button_name in ["Play", "Loadout", "Options", "Back"]:
		get_node("%" + button_name).pressed.connect(_show.bind("%s: pressed" % button_name))
	%Snap.toggled.connect(_on_snap_toggled)
	%Snap.is_toggled = true
	%Volume.value_changed.connect(func(v: float): _show("Volume: %d" % v))
	%Cursor.shown.connect(_show.bind("Cursor shown (stick moved)"))
	%Cursor.hidden.connect(_show.bind("Cursor hidden (mouse, touch or d-pad used)"))
	%Cursor.clicked.connect(func(at: Vector2): _show("Click at (%d, %d)" % [at.x, at.y]))
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool): _show_controllers())
	_show_controllers()

func _show(text: String) -> void:
	# the cursor also says "hidden" while the scene is closing, after the label's already gone.
	var label := get_node_or_null("%CursorState") as Label
	if label != null:
		label.text = text

## shows which controllers godot can see so it's easy to spot a missing one (steam controllers need
## steam input, see the README).
func _show_controllers() -> void:
	var names: PackedStringArray = []
	for d in Input.get_connected_joypads():
		names.append(Input.get_joy_name(d))
	if names.is_empty():
		_show("No controller found. Steam controllers: start Godot from Steam (see the README).")
	else:
		_show("Controllers: %s. Move the left stick." % ", ".join(names))

func _on_snap_toggled(on: bool) -> void:
	%Snap.text = "Snap: On" if on else "Snap: Off"
	%Cursor.snap_strength = 0.5 if on else 0.0

## godot's ui_accept has enter and space but no controller button, so after the d-pad moves focus
## A can't press the focused button. this adds A while the demo runs. in your game add it under
## project settings > input map.
func _add_gamepad_accept() -> void:
	for e in InputMap.action_get_events(&"ui_accept"):
		if e is InputEventJoypadButton:
			return
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.device = -1
	InputMap.action_add_event(&"ui_accept", a)

## scales the page so it fits any window, down to 320x180.
func _fit_to_screen() -> void:
	var margin: Control = $Margin
	var screen := get_viewport().get_visible_rect().size
	var s := minf(screen.x / REFERENCE_SIZE.x, screen.y / REFERENCE_SIZE.y)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2(s, s)
	margin.position = Vector2.ZERO
	margin.size = screen / s
