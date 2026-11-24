extends SceneTree
# checks the menus (prebuilt/menus/): OmniSettings (define, apply, save / load, reset), the title
# screen, the pause menu (opening on esc / start, pausing, confirming before quitting), the options
# screen (rows built from the settings, sliders, choices, tabs, reset, saving), the OmniMenus autoload
# script and the demo. input goes through Input.parse_input_event like a real keyboard or controller.
# usage: godot --headless --path . -s res://addons/omni_button/prebuilt/menus/dev/OmniMenusValidation.gd

const M := "res://addons/omni_button/prebuilt/menus/"
const TEST_SETTINGS := "user://omni_menus_validation.cfg"

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	root.size = Vector2i(1152, 648)
	# never touch the real settings file.
	ProjectSettings.set_setting(OmniSettings.PATH_SETTING, TEST_SETTINGS)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
	_add_gamepad_accept()

	_check_settings()
	await _check_title()
	await _check_pause()
	await _check_options()
	await _check_autoload()
	await _check_stylized()
	await _check_demo()

	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	if _failures.is_empty():
		print("OmniMenus validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniMenus validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _check_settings() -> void:
	_check(OmniSettings.get_pages() == PackedStringArray(["Audio", "Display", "Gameplay"]), "settings: built-in pages in order")
	_check(OmniSettings.get_value("audio/music") == 0.8 and OmniSettings.get_value("gameplay/text_speed") == 1.0, "settings: built-in defaults")
	var seen := []
	var watcher := func(key: String, value: Variant): seen.append([key, value])
	OmniSettings.watch(watcher)
	OmniSettings.set_value("audio/music", 0.5)
	var db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_check(absf(db - linear_to_db(0.5)) < 0.01, "settings: a volume applies to its audio bus")
	OmniSettings.set_value("audio/music", 0.0)
	_check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "settings: zero volume mutes the bus")
	OmniSettings.set_value("gameplay/text_speed", 2.0)
	_check(OmniTextWindow.text_speed_scale == 2.0, "settings: text speed applies to the dialog windows")
	_check(seen.size() == 3 and seen[2] == ["gameplay/text_speed", 2.0], "settings: watchers hear every change")
	OmniSettings.unwatch(watcher)

	var applied := [null]
	OmniSettings.define("gameplay/screen_shake", true, {"page": "Gameplay", "label": "Screen shake", "apply": func(v): applied[0] = v})
	_check(OmniSettings.get_definition("gameplay/screen_shake")["kind"] == OmniSettings.Kind.TOGGLE, "settings: a bool setting is shown as a toggle")
	OmniSettings.set_value("gameplay/screen_shake", false)
	_check(applied[0] == false, "settings: a game-defined setting calls its apply function")
	var keys := OmniSettings.get_definitions("Gameplay").map(func(d): return d["key"])
	_check(keys == ["gameplay/text_speed", "gameplay/screen_shake"], "settings: game-defined settings join their page, in order")

	OmniSettings.save()
	OmniSettings.set_value("audio/music", 0.9)
	OmniSettings.load_settings()
	_check(OmniSettings.get_value("audio/music") == 0.0 and OmniSettings.get_value("gameplay/screen_shake") == false, "settings: save and load round-trip")
	OmniSettings.reset_to_defaults("Audio")
	_check(OmniSettings.get_value("audio/music") == 0.8 and OmniSettings.get_value("gameplay/text_speed") == 2.0, "settings: reset_to_defaults only resets that page")
	OmniSettings.reset_to_defaults()
	_check(OmniTextWindow.text_speed_scale == 1.0 and applied[0] == true, "settings: a full reset applies every default")

	# a setting defined after the file loaded (the normal case for a game's own settings).
	var file := ConfigFile.new()
	file.set_value("game", "late", 7)
	file.set_value("game", "never_defined", "keep me")
	file.save(TEST_SETTINGS)
	OmniSettings.load_settings()
	var late := [null]
	OmniSettings.define("game/late", 1, {"apply": func(v): late[0] = v})
	_check(OmniSettings.get_value("game/late") == 7 and late[0] == 7, "settings: defining after load picks up the saved value and applies it")
	OmniSettings.save()
	var saved := ConfigFile.new()
	saved.load(TEST_SETTINGS)
	_check(saved.get_value("game", "never_defined", "") == "keep me", "settings: saving keeps saved settings nothing has defined yet")

func _check_title() -> void:
	var title: OmniTitleMenu = load(M + "screens/omni_title_menu.tscn").instantiate()
	title.animation_duration = 0.0
	root.add_child(title)
	await _frames(3)
	_check(title.is_open(), "title: opens by itself")
	_check(not title.get_item(&"continue").visible and title.get_item(&"start").visible, "title: Continue is hidden until can_continue")
	title.can_continue = true
	_check(title.get_item(&"continue").visible, "title: can_continue shows Continue")
	_check(root.gui_get_focus_owner() == title.get_item(&"start"), "title: Start has focus")
	var started := [0]
	title.start_pressed.connect(func(): started[0] += 1)
	_action(&"ui_accept")
	await _frames(3)
	_check(started[0] == 1 and not title.is_open(), "title: confirm on Start emits start_pressed and closes")
	title.open()
	await _frames(2)
	title.get_item(&"options").pressed.emit()
	await _frames(3)
	_check(title.options_menu != null and title.options_menu.is_open() and title.options_menu.layer > title.layer, "title: Options opens the options screen above it")
	_action(&"ui_cancel")
	await _frames(3)
	_check(not title.options_menu.is_open() and title.is_open(), "title: cancel closes the options screen and stays on the title")
	_action(&"ui_cancel")
	await _frames(2)
	_check(title.is_open(), "title: cancel doesn't close the title screen")
	title.queue_free()
	await _frames(1)

func _check_pause() -> void:
	var pause: OmniPauseMenu = load(M + "screens/omni_pause_menu.tscn").instantiate()
	pause.animation_duration = 0.0
	root.add_child(pause)
	await _frames(2)
	_check(not pause.is_open() and not pause.get_item(&"quit_game").visible, "pause: closed at start, Quit game hidden")
	_action(&"ui_cancel")
	await _frames(2)
	_check(pause.is_open() and paused, "pause: Esc opens it and pauses the game")
	var resumed := [0]
	pause.resumed.connect(func(): resumed[0] += 1)
	_action(&"ui_cancel")
	await _frames(3)
	_check(not pause.is_open() and not paused and resumed[0] == 1, "pause: Esc again resumes")
	_joy(JOY_BUTTON_START)
	await _frames(2)
	_check(pause.is_open() and paused, "pause: the controller's Start button opens it")
	_joy(JOY_BUTTON_START)
	await _frames(3)
	_check(not pause.is_open() and not paused, "pause: Start again resumes")

	# doesn't open over another window.
	var popup: OmniPopup = load("res://addons/omni_button/prebuilt/dialog/windows/popup/omni_popup.tscn").instantiate()
	popup.animation_duration = 0.0
	root.add_child(popup)
	var answer := func(): return await popup.confirm("Busy?")
	answer.call()
	await _frames(2)
	_joy(JOY_BUTTON_START)
	await _frames(2)
	_check(not pause.is_open(), "pause: doesn't open while a dialog window is open")
	popup.cancel()
	await _frames(2)

	# Quit to title asks first.
	var quits := [0]
	pause.quit_to_title.connect(func(): quits[0] += 1)
	pause.pause()
	await _frames(2)
	pause.get_item(&"quit_to_title").pressed.emit()
	await _frames(3)
	var ask: OmniPopup = pause._popup
	_check(ask != null and ask.is_open() and ask.layer > pause.layer, "pause: Quit to title asks in a popup above the menu")
	ask._button_nodes[1].pressed.emit() # Cancel
	await _frames(3)
	_check(pause.is_open() and quits[0] == 0, "pause: answering Cancel keeps the menu open")
	await create_timer(0.3).timeout # let the popup finish closing before asking again
	pause.get_item(&"quit_to_title").pressed.emit()
	await _frames(3)
	_check(ask.is_open(), "pause: asking again after Cancel shows the popup again")
	ask._button_nodes[0].pressed.emit() # Quit
	await create_timer(0.3).timeout # the answer comes once the popup's closed
	_check(not pause.is_open() and quits[0] == 1 and not paused, "pause: confirming closes, unpauses and emits quit_to_title")
	pause.queue_free()
	popup.queue_free()
	await _frames(1)

func _check_options() -> void:
	var opts: OmniOptionsMenu = load(M + "screens/omni_options_menu.tscn").instantiate()
	opts.animation_duration = 0.0
	root.add_child(opts)
	await _frames(2)
	opts.open()
	await _frames(3)
	_check(opts.tabs.get_tabs().size() == 3 and opts.pages.get_child_count() == 3, "options: one tab and page per settings page")
	_check(opts.pages.get_child(0).visible and not opts.pages.get_child(1).visible, "options: only the first page shows")
	_check(opts.pages.get_child(0).get_child_count() == 3, "options: one row per Audio setting")
	var slider := opts.get_control("audio/music") as HSlider
	_check(slider != null and is_equal_approx(slider.value, 80.0), "options: the music slider shows 80 %")
	_check(root.gui_get_focus_owner() == opts.get_control("audio/master"), "options: the first row has focus")
	var changes := []
	opts.setting_changed.connect(func(k, v): changes.append(k))
	slider.value = 30.0
	_check(is_equal_approx(OmniSettings.get_value("audio/music"), 0.3) and changes == ["audio/music"], "options: moving a slider changes the setting")
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(2)
	_joy(JOY_BUTTON_RIGHT_SHOULDER)
	await _frames(3)
	_check(opts.get_current_page() == "Gameplay", "options: the shoulder buttons switch tabs")
	var speed := opts.get_control("gameplay/text_speed") as OmniButton
	_check(speed != null and speed.text.contains("Normal"), "options: text speed shows Normal")
	_check(root.gui_get_focus_owner() == speed, "options: switching tabs focuses the first row")
	_action(&"ui_right")
	await _frames(2)
	_check(OmniSettings.get_value("gameplay/text_speed") == 2.0 and speed.text.contains("Fast"), "options: right on a choice steps forward")
	_action(&"ui_left")
	_action(&"ui_left")
	await _frames(2)
	_check(OmniSettings.get_value("gameplay/text_speed") == 0.5, "options: left steps back")
	speed.pressed.emit()
	await _frames(1)
	_check(OmniSettings.get_value("gameplay/text_speed") == 1.0, "options: confirm on a choice steps forward")
	var shake := opts.get_control("gameplay/screen_shake") as OmniButton
	_check(shake != null and shake.text.contains("On"), "options: a game-defined toggle appears on its page")
	shake.pressed.emit()
	_check(OmniSettings.get_value("gameplay/screen_shake") == false and shake.text.contains("Off"), "options: pressing a toggle flips it")
	OmniSettings.set_value("gameplay/text_speed", 0.0)
	opts.reset_button.pressed.emit()
	await _frames(2)
	_check(OmniSettings.get_value("gameplay/text_speed") == 1.0 and OmniSettings.get_value("gameplay/screen_shake") == true and is_equal_approx(OmniSettings.get_value("audio/music"), 0.3), "options: Reset to defaults resets the current page only")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS))
	opts.back_button.pressed.emit()
	await _frames(3)
	_check(not opts.is_open() and FileAccess.file_exists(TEST_SETTINGS), "options: Back closes the screen and saves the settings")
	opts.queue_free()
	await _frames(1)

func _check_stylized() -> void:
	var title: OmniTitleMenu = load(M + "screens/omni_title_menu_stylized.tscn").instantiate()
	root.add_child(title)
	await _frames(3)
	var look := title.get_dialog_theme()
	var stylizer: OmniMenuStylizer = title.get_node("Stylizer")
	_check(title.is_open() and not title.style_items, "stylized title: opens and styles its own items")
	var start := title.get_item(&"start")
	_check(start.panel_style_box is StyleBoxEmpty and (start.panel_focus_style_box as StyleBoxFlat).bg_color == look.accent_color and (start.panel_focus_style_box as StyleBoxFlat).skew.x > 0.0, "stylized title: items are text with a slanted accent shape when selected")
	_check(root.gui_get_focus_owner() == start and start.label_text_color == look.accent_text_color, "stylized title: the selected item's text uses accent_text_color")
	_check(title.get_item(&"options").label_text_color == look.menu_text_color, "stylized title: other items use menu_text_color")
	_check(title.title_label.has_theme_font_override("font") and title.title_label.get_theme_font_size("font_size") == stylizer.title_size, "stylized title: the title uses the big slanted font")
	var stair := title.items_box as OmniStaircaseContainer
	_check(stair != null and start.position.x > title.get_item(&"options").position.x, "stylized title: each lower item steps along the slant")
	await create_timer(0.6).timeout
	_check(is_equal_approx(stylizer.bands.progress, 1.0) and start.modulate.a > 0.99, "stylized title: the bands sweep in and the items appear")
	_check(stylizer.bands.band_color == look.menu_band_color and stylizer.bands.background_color == look.menu_background_color, "stylized title: the bands use the look's colors")
	title.get_item(&"options").pressed.emit()
	await _frames(3)
	var opts := title.options_menu
	_check(opts != null and opts.scene_file_path.ends_with("omni_options_menu_stylized.tscn") and opts.is_open(), "stylized title: Options opens the stylized options screen")
	_check(opts.panel.has_theme_stylebox_override("panel"), "stylized options: the panel is a slanted plate")
	opts.close()
	await create_timer(0.4).timeout
	title.queue_free()

	var pause: OmniPauseMenu = load(M + "screens/omni_pause_menu_stylized.tscn").instantiate()
	pause.animation_duration = 0.0
	root.add_child(pause)
	await _frames(2)
	_action(&"ui_cancel")
	await _frames(2)
	_check(pause.is_open() and paused and (pause.get_node("Stylizer") as OmniMenuStylizer).bands.shape == OmniMenuBands.Shape.SPLIT, "stylized pause: Esc pauses, with the split layout")
	_action(&"ui_cancel")
	await _frames(2)
	_check(not pause.is_open() and not paused, "stylized pause: Esc resumes")
	pause.queue_free()
	await _frames(1)

func _check_autoload() -> void:
	var menus := OmniMenusAutoload.new()
	root.add_child(menus)
	await _frames(1)
	var heard := []
	menus.setting_changed.connect(func(k, v): heard.append(k))
	OmniSettings.set_value("audio/sfx", 0.4)
	_check(heard == ["audio/sfx"], "autoload: relays setting changes")
	var opts := menus.open_options()
	await _frames(2)
	_check(opts != null and opts.is_open() and opts.layer == OmniMenusAutoload.OPTIONS_LAYER, "autoload: open_options opens the options screen on top")
	opts.close()
	await _frames(2)
	menus.queue_free()
	await _frames(1)

func _check_demo() -> void:
	var demo: Control = load(M + "demo/omni_menus_demo.tscn").instantiate()
	root.add_child(demo)
	await _frames(3)
	var title: OmniTitleMenu = demo.get_node("%Title")
	var pause: OmniPauseMenu = demo.get_node("%Pause")
	title.animation_duration = 0.0
	pause.animation_duration = 0.0
	_check(title.is_open() and title.options_menu == demo.get_node("%Options") and pause.options_menu == title.options_menu, "demo: title opens first, and both menus share one options screen")
	_action(&"ui_cancel")
	await _frames(2)
	_check(not pause.is_open(), "demo: Esc doesn't pause on the title screen")
	_check(AudioServer.get_bus_index("Music") >= 0 and AudioServer.get_bus_index("SFX") >= 0, "demo: Music and SFX buses exist while it runs")
	var music: AudioStreamPlayer = demo._music
	_check(music.playing and music.bus == &"Music" and demo._click.bus == &"SFX", "demo: music plays on the Music bus, clicks on SFX")
	OmniSettings.set_value("audio/music", 0.25)
	var music_db := AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music"))
	_check(absf(music_db - linear_to_db(0.25)) < 0.01 and demo._readout.text.contains("Music: 25%"), "demo: the Music slider changes the music's bus, and the readout shows it")
	_action(&"ui_accept")
	await _frames(3)
	_check(not title.is_open(), "demo: Start begins play")
	OmniSettings.set_value("gameplay/text_speed", 0.0)
	var t := InputEventKey.new()
	t.keycode = KEY_T
	t.pressed = true
	Input.parse_input_event(t)
	await _frames(3)
	var box: OmniDialogueBox = demo._dialogue
	_check(box.is_open() and not box.body.get("_tw_active"), "demo: T shows a line, typed at the text speed (Instant: all at once)")
	_action(&"ui_accept")
	await create_timer(0.4).timeout
	OmniSettings.reset_to_defaults()
	_joy(JOY_BUTTON_START)
	await _frames(2)
	_check(pause.is_open() and paused, "demo: Start on the controller pauses")
	pause.confirm_quit = false
	pause.get_item(&"quit_to_title").pressed.emit()
	await _frames(4)
	_check(title.is_open() and title.can_continue and not paused, "demo: Quit to title goes back to the title, with Continue")

	# the demo's own settings switch the menu style and the look.
	_check(OmniSettings.get_pages().has("Demo"), "demo: its own settings add a Demo tab")
	OmniSettings.set_value("demo/menu_style", "stylized")
	await _frames(3)
	var stylized_title: OmniTitleMenu = demo._sets["stylized"].title
	_check(not title.is_open() and stylized_title.is_open() and stylized_title.can_continue, "demo: switching to Stylized swaps the title screen")
	OmniSettings.set_value("demo/look", "bold")
	await _frames(2)
	var bands: OmniMenuBands = (stylized_title.get_node("Stylizer") as OmniMenuStylizer).bands
	_check(stylized_title.get_dialog_theme().resource_path.ends_with("omni_dialog_bold.tres") and bands.band_color == stylized_title.get_dialog_theme().menu_band_color, "demo: switching the look restyles the open menu")
	OmniSettings.set_value("demo/look", "modern")
	OmniSettings.set_value("demo/menu_style", "panel")
	await _frames(3)
	_check(title.is_open() and not stylized_title.is_open(), "demo: switching back to Panel swaps it back")
	demo.queue_free()
	await _frames(1)

func _action(action: StringName) -> void:
	for down in [true, false]:
		var e := InputEventAction.new()
		e.action = action
		e.pressed = down
		Input.parse_input_event(e)

func _joy(button: JoyButton) -> void:
	for down in [true, false]:
		var e := InputEventJoypadButton.new()
		e.device = 0
		e.button_index = button
		e.pressed = down
		Input.parse_input_event(e)

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _add_gamepad_accept() -> void:
	var a := InputEventJoypadButton.new()
	a.button_index = JOY_BUTTON_A
	a.device = -1
	InputMap.action_add_event(&"ui_accept", a)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
