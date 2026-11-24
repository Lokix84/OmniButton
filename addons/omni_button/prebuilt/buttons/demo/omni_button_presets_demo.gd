extends Control
## shows every ready made button in [code]prebuilt/buttons/presets/[/code] and logs the signals they send.
## open this scene and hit F6. each card is just an instance of a preset scene with its text or icon
## changed, so the handlers below are all the code a preset needs. the page buttons at the top are an
## OmniTabBar preset, its pages setting shows the right page without any code.

## the screen size this demo is laid out for, it scales to fit smaller or bigger windows.
const REFERENCE_SIZE := Vector2(1152, 648)
const MAX_LOG_LINES := 14
## input map action the "A" action button holds down (see its output_action). it gets added while
## running if the project doesn't have it, so the demo works anywhere.
const JUMP_ACTION := &"jump"

var _lines: PackedStringArray = []

func _ready() -> void:
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	if not InputMap.has_action(JUMP_ACTION):
		InputMap.add_action(JUMP_ACTION)
	_add_gamepad_accept()

	%Tabs.tab_changed.connect(_on_page_changed)

	# buttons page
	%Start.pressed.connect(_add_log.bind("Start: pressed"))
	%Music.toggled.connect(_on_music_toggled)
	%Fullscreen.toggled.connect(func(on: bool): _add_log("Fullscreen: toggled %s" % ("on" if on else "off")))
	%Settings.pressed.connect(_add_log.bind("Settings icon: pressed"))
	%Pause.pressed.connect(_add_log.bind("Pause icon: pressed"))
	%Close.pressed.connect(_add_log.bind("Close icon: pressed"))
	%Potion.pressed.connect(_add_log.bind("Potion item: pressed"))
	%Sword.pressed.connect(_add_log.bind("Sword item: pressed"))
	%Quit.hold.connect(_add_log.bind("Hold to Quit: hold (confirmed)"))
	%Attack.pressed.connect(_add_log.bind("Attack: pressed, cooling down for 3 s"))
	%Dash.pressed.connect(_add_log.bind("Dash: pressed, cooling down for 1 s"))

	# touch controls page
	%Stick.started.connect(_add_log.bind("Joystick: started"))
	%Stick.ended.connect(_add_log.bind("Joystick: ended"))
	%Stick.axis_changed.connect(func(axis: Vector2): %StickAxis.text = "axis (%.2f, %.2f)" % [axis.x, axis.y])
	%FloatStick.started.connect(_add_log.bind("Floating joystick: started"))
	%FloatStick.ended.connect(_add_log.bind("Floating joystick: ended"))
	%Swipe.swiped.connect(_on_swiped)
	%ActionA.pressed.connect(_add_log.bind("A: pressed"))
	%ActionA.released.connect(_add_log.bind("A: released"))
	%ActionB.pressed.connect(_add_log.bind("B: pressed"))

	# more page
	%Title.pressed.connect(_add_log.bind("Press Start: pressed"))
	%Title.typewriter_completed.connect(_add_log.bind("Press Start: typing done"))
	%Replay.pressed.connect(%Title.play)
	%Flash.pressed.connect(_add_log.bind("Fight: pressed"))
	%Flash2.pressed.connect(_add_log.bind("Run: pressed"))
	%DemoTabs.tab_changed.connect(func(i: int): _add_log("Tab bar: tab %d" % i))

	%Start.grab_focus()
	_add_log("Hover, click, or use the keyboard / gamepad (arrows + Enter).")

func _process(_delta: float) -> void:
	# what your game code sees: the A button holds "jump" down just like a keyboard key would.
	%JumpState.text = "jump: held" if Input.is_action_pressed(JUMP_ACTION) else "jump: up"

func _on_page_changed(index: int) -> void:
	match index:
		0:
			%Start.grab_focus()
		2:
			%Title.play()

## godot's ui_accept has enter and space but no controller button, so A can't press a focused
## button. this adds A while the demo runs. in your game add it under project settings > input map.
func _add_gamepad_accept() -> void:
	for e in InputMap.action_get_events(&"ui_accept"):
		if e is InputEventJoypadButton:
			return
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.device = -1
	InputMap.action_add_event(&"ui_accept", a)

## a toggle's text doesn't change on its own, update it in the toggled handler.
func _on_music_toggled(on: bool) -> void:
	%Music.text = "Music: On" if on else "Music: Off"
	_add_log("Music: toggled %s" % ("on" if on else "off"))

func _on_swiped(direction: Vector2) -> void:
	var dir_name: String = {Vector2.LEFT: "left", Vector2.RIGHT: "right", Vector2.UP: "up", Vector2.DOWN: "down"}.get(direction, str(direction))
	%SwipeResult.text = "Last swipe: %s" % dir_name
	_add_log("Swipe pad: swiped %s" % dir_name)

func _add_log(line: String) -> void:
	_lines.append(line)
	while _lines.size() > MAX_LOG_LINES:
		_lines.remove_at(0)
	%Log.text = "\n".join(_lines)

## scales the page so it fits any window, down to 320x180.
func _fit_to_screen() -> void:
	var margin: Control = $Margin
	var screen := get_viewport().get_visible_rect().size
	var s := minf(screen.x / REFERENCE_SIZE.x, screen.y / REFERENCE_SIZE.y)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2(s, s)
	margin.position = Vector2.ZERO
	margin.size = screen / s
