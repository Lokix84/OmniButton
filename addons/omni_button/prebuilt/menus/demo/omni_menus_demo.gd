extends Control
## a tiny "game" that uses all three menus. the title screen opens first, Start starts playing, esc or
## start on the controller pauses, Options changes settings, and Quit to title goes back.
## open this scene and hit F6. the three menus share one options screen (their Options Menu setting).
##
## so you can actually see every setting doing something, the demo also:
## - plays a soft music loop on a "Music" bus and a click on an "SFX" bus (it adds those two buses
##   while it runs if the project doesn't have them), so you can hear the volume sliders
## - shows a line of dialogue on T (or Y on a controller), typed at whatever text speed you picked
## - lists the current settings on the left edge, with the audio bus levels they set
## - adds a "Demo" tab to the options screen (two settings of its own, made with OmniSettings.define)
##   to switch between the panel menus and the full screen stylized ones, and between the looks

const STYLIZED := {
	"title": "res://addons/omni_button/prebuilt/menus/screens/omni_title_menu_stylized.tscn",
	"pause": "res://addons/omni_button/prebuilt/menus/screens/omni_pause_menu_stylized.tscn",
	"options": "res://addons/omni_button/prebuilt/menus/screens/omni_options_menu_stylized.tscn",
}
const LOOKS := {
	"modern": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres",
	"retro": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_retro.tres",
	"bold": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_bold.tres",
}
const TALK_KEY := KEY_T
const TALK_BUTTON := JOY_BUTTON_Y
const LINES := [
	"Try changing the text speed in Options, then talk to me again.",
	"Slow, Normal, Fast or Instant: every dialog window in the game follows it.",
	"The music and the menu clicks follow the volume sliders, too.",
]

var _velocity := Vector2(220, 160)
var _music: AudioStreamPlayer
var _click: AudioStreamPlayer
var _dialogue: OmniDialogueBox
var _readout: Label
var _line := 0
var _playing := false
## the two menu sets: "panel" (the scene's own menus) and "stylized" (made in code).
var _sets := {}
var _style := "panel"

func _ready() -> void:
	_add_gamepad_accept()
	_ensure_bus(&"Music")
	_ensure_bus(&"SFX")
	# the settings got applied before these buses existed (at startup), so apply them again.
	OmniSettings.ensure_loaded()
	OmniSettings.apply_all()
	_make_sounds()
	_make_readout()
	_dialogue = load(OmniDialogAutoload.scene_path("dialogue_scene")).instantiate()
	add_child(_dialogue)

	_sets["panel"] = {"title": %Title, "pause": %Pause, "options": %Options}
	_sets["stylized"] = _make_stylized_set()
	for set: Dictionary in _sets.values():
		set.title.start_pressed.connect(_start)
		set.title.continue_pressed.connect(_start)
		set.pause.quit_to_title.connect(_back_to_title)
		set.options.closed.connect(_on_options_closed)
		for menu in [set.title, set.pause]:
			menu.item_pressed.connect(func(_item): _click.play())

	# two settings just for the demo, they get a "Demo" tab on the options screen.
	OmniSettings.define("demo/look", "modern", {"page": "Demo", "label": "Look",
		"choices": [["Modern", "modern"], ["Retro", "retro"], ["Bold", "bold"]], "apply": _apply_look})
	OmniSettings.define("demo/menu_style", "panel", {"page": "Demo", "label": "Menu style",
		"choices": [["Panel", "panel"], ["Stylized", "stylized"]], "apply": func(_v): _switch_style_when_free()})
	_apply_look(str(OmniSettings.get_value("demo/look", "modern")))
	OmniSettings.watch(_on_setting_changed)
	_update_readout()
	_switch_style(str(OmniSettings.get_value("demo/menu_style", "panel")))
	_current().title.open()

func _exit_tree() -> void:
	OmniSettings.unwatch(_on_setting_changed)

func _process(delta: float) -> void:
	# a paused game stops here, this node isn't set to keep going while paused.
	var sword: Control = %Sword
	sword.position += _velocity * delta
	var area: Vector2 = %Game.size - sword.size
	if sword.position.x < 0.0 or sword.position.x > area.x:
		_velocity.x = -_velocity.x
	if sword.position.y < 90.0 or sword.position.y > area.y:
		_velocity.y = -_velocity.y
	sword.position = sword.position.clamp(Vector2(0, 90), area)

func _unhandled_input(event: InputEvent) -> void:
	var talk: bool = (event is InputEventKey and event.pressed and not event.echo and event.keycode == TALK_KEY) \
		or (event is InputEventJoypadButton and event.pressed and event.button_index == TALK_BUTTON)
	if talk and _playing and OmniOverlay.get_top() == null and not get_tree().paused:
		get_viewport().set_input_as_handled()
		_talk()

func _talk() -> void:
	var text: String = LINES[_line % LINES.size()]
	_line += 1
	await _dialogue.say("Guide", text)

func _current() -> Dictionary:
	return _sets[_style]

func _make_stylized_set() -> Dictionary:
	var title: OmniTitleMenu = load(STYLIZED.title).instantiate()
	title.start_open = false
	title.title = "OmniButton Menus"
	var pause: OmniPauseMenu = load(STYLIZED.pause).instantiate()
	pause.open_on_pause = false
	var options: OmniOptionsMenu = load(STYLIZED.options).instantiate()
	for menu in [options, pause, title]:
		add_child(menu)
	title.options_menu = options
	pause.options_menu = options
	return {"title": title, "pause": pause, "options": options}

## menu style changes wait until the options screen (where you changed it) has closed.
func _switch_style_when_free() -> void:
	if _sets.is_empty():
		return
	for set: Dictionary in _sets.values():
		if set.options.is_open():
			return
	_switch_style(str(OmniSettings.get_value("demo/menu_style", "panel")))

func _on_options_closed() -> void:
	_switch_style_when_free.call_deferred()

## swaps which menus are in use, keeping whatever was showing (the title screen or the pause menu).
func _switch_style(to: String) -> void:
	if not _sets.has(to) or to == _style:
		return
	var old: Dictionary = _current()
	var new: Dictionary = _sets[to]
	_style = to
	old.pause.open_on_pause = false
	new.pause.open_on_pause = true
	new.title.can_continue = old.title.can_continue
	if old.title.is_open():
		await _close_now(old.title)
		new.title.open()
	elif old.pause.is_open():
		await _close_now(old.pause)
		new.pause.pause()

static func _close_now(menu: OmniOverlay) -> void:
	var duration := menu.animation_duration
	menu.animation_duration = 0.0
	await menu.close()
	menu.animation_duration = duration

func _apply_look(look: String) -> void:
	ProjectSettings.set_setting(OmniDialogTheme.SETTING, LOOKS.get(look, LOOKS.modern))
	if _sets.is_empty():
		return
	for set: Dictionary in _sets.values():
		for menu: OmniOverlay in set.values():
			menu.apply_dialog_theme()
			var stylizer := menu.get_node_or_null("Stylizer") as OmniMenuStylizer
			if stylizer != null:
				stylizer.apply_look()
	if _dialogue != null:
		_dialogue.apply_dialog_theme()

func _start() -> void:
	_playing = true
	%Hint.text = "Playing. Esc (or Start) pauses: the sword stops.\nT (or Y) talks: the text types at your text speed."

func _back_to_title() -> void:
	_playing = false
	# a real game would save here, then show Continue on the title screen.
	_current().title.can_continue = true
	_current().title.open()

func _on_setting_changed(key: String, _value: Variant) -> void:
	_update_readout()
	if key == "audio/sfx" or key == "audio/master":
		if not _click.playing:
			_click.play() # so you hear the new level while dragging the slider

#region Sounds

func _ensure_bus(bus: StringName) -> void:
	if AudioServer.get_bus_index(bus) >= 0:
		return
	AudioServer.add_bus()
	var index := AudioServer.bus_count - 1
	AudioServer.set_bus_name(index, bus)
	AudioServer.set_bus_send(index, &"Master")

func _make_sounds() -> void:
	_music = AudioStreamPlayer.new()
	_music.stream = _music_loop()
	_music.bus = &"Music"
	_music.process_mode = Node.PROCESS_MODE_ALWAYS # keeps playing in the pause menu
	add_child(_music)
	_music.play()
	_click = AudioStreamPlayer.new()
	_click.stream = _click_sound()
	_click.bus = &"SFX"
	_click.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_click)

const RATE := 22050

## a gentle four chord arpeggio, made in code so the demo doesn't need any audio files.
static func _music_loop() -> AudioStreamWAV:
	var chords := [[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]]
	var note_len := 0.25
	var samples := PackedFloat32Array()
	for chord in chords:
		for step in 8:
			var freq: float = chord[[0, 1, 2, 1][step % 4]] * (2.0 if step >= 4 else 1.0)
			var n := int(note_len * RATE)
			for i in n:
				var t := float(i) / RATE
				var env := minf(1.0, t * 40.0) * exp(-t * 6.0)
				samples.append(sin(TAU * freq * t) * env * 0.18 + sin(TAU * chord[0] * 0.5 * t) * 0.05)
	return _to_wav(samples, true)

## a short soft click.
static func _click_sound() -> AudioStreamWAV:
	var samples := PackedFloat32Array()
	var n := int(0.06 * RATE)
	for i in n:
		var t := float(i) / RATE
		samples.append(sin(TAU * 1200.0 * t) * exp(-t * 70.0) * 0.5)
	return _to_wav(samples, false)

static func _to_wav(samples: PackedFloat32Array, loop: bool) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.data = data
	if loop:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = samples.size()
	return wav

#endregion

#region Settings readout

func _make_readout() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 40 # above every menu so you see changes while the options screen is open
	add_child(layer)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0.6)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(10)
	panel.add_theme_stylebox_override("panel", style)
	# left edge, out of the way of the menus in the middle.
	panel.offset_left = 12.0
	panel.offset_right = 222.0
	panel.offset_top = 12.0
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(panel)
	_readout = Label.new()
	_readout.add_theme_font_size_override("font_size", 13)
	_readout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(_readout)

func _update_readout() -> void:
	if _readout == null:
		return
	var lines := PackedStringArray(["Settings (live)", "Volume (bus level):"])
	for key in ["audio/master", "audio/music", "audio/sfx"]:
		var bus: String = {"audio/master": "Master", "audio/music": "Music", "audio/sfx": "SFX"}[key]
		var index := AudioServer.get_bus_index(bus)
		var level := "muted" if AudioServer.is_bus_mute(index) else "%.1f dB" % AudioServer.get_bus_volume_db(index)
		lines.append("%s: %d%%  (%s)" % [bus, roundi(float(OmniSettings.get_value(key)) * 100.0), level])
	lines.append("Window mode: %s" % OmniSettings.get_value("display/window_mode"))
	lines.append("VSync: %s" % ("on" if OmniSettings.get_value("display/vsync") else "off"))
	lines.append("Text speed: x%s" % OmniSettings.get_value("gameplay/text_speed"))
	lines.append("Look: %s, menus: %s" % [OmniSettings.get_value("demo/look", "modern"), OmniSettings.get_value("demo/menu_style", "panel")])
	if Engine.is_embedded_in_editor():
		lines.append("Window mode and VSync apply when the game runs in its own window (Game tab: turn off Embed Game on Next Play).")
	_readout.text = "\n".join(lines)

#endregion

## godot's ui_accept has enter and space but no controller button, so A couldn't press a menu item.
## this adds A while the demo runs. in your game add it under project settings > input map.
func _add_gamepad_accept() -> void:
	for e in InputMap.action_get_events(&"ui_accept"):
		if e is InputEventJoypadButton:
			return
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.device = -1
	InputMap.action_add_event(&"ui_accept", a)
