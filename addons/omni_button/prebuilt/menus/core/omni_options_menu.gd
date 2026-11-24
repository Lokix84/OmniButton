@tool
class_name OmniOptionsMenu
extends OmniOverlay
## The options screen: one tab per settings page, one row per setting, built from [OmniSettings].
##
## Rows come from the setting definitions, so settings your game adds with [method OmniSettings.define]
## (with a [code]page[/code]) appear here on their own. Changes apply at once; they are saved when the
## screen closes.[br][br]
## Controls: the d-pad / arrows move between rows. On a slider, left / right changes it; on a choice
## or an On / Off row, left / right steps through the values and confirm steps forward. The shoulder
## buttons switch tabs. Cancel or [b]Back[/b] closes.

## A setting was changed on this screen.
signal setting_changed(key: String, value: Variant)

## Text at the top. Empty hides it.
@export var title: String = "Options":
	set(value):
		title = value
		if is_node_ready():
			_apply_title()
## Width of the control on the right of each row (slider, choice, On / Off).
@export var control_width: float = 260.0
## Button scene used for tabs, choices and On / Off rows (styled by the look).
@export var option_button_scene: PackedScene = preload("res://addons/omni_button/prebuilt/dialog/parts/omni_option_button.tscn")

## The [Label] showing [member title].
@onready var title_label: Label = get_node_or_null("%Title")
## The tab row ([OmniTabBar]); built from the settings pages.
@onready var tabs: OmniTabBar = %Tabs
## The container holding one page per tab.
@onready var pages: Container = %Pages
## The button that closes the screen.
@onready var back_button: Omni_Button = %Back
## The button that puts the current page back to its defaults.
@onready var reset_button: Omni_Button = %Reset

## Setting key -> the control showing it.
var _controls := {}
var _page_names: PackedStringArray = []

func _ready() -> void:
	super()
	_apply_title()
	if Engine.is_editor_hint():
		return
	tabs.pages = pages
	back_button.pressed.connect(func(): if is_top(): close())
	reset_button.pressed.connect(_on_reset_pressed)
	tabs.tab_changed.connect(func(_i: int): _focus_first_row())

## Rebuilds the tabs and rows from the current definitions and values.
func rebuild() -> void:
	OmniSettings.ensure_loaded()
	var keep_tab := tabs.current_tab
	for c in tabs.get_children():
		tabs.remove_child(c)
		c.queue_free()
	for c in pages.get_children():
		pages.remove_child(c)
		c.queue_free()
	_controls.clear()
	_page_names = OmniSettings.get_pages()
	var t := get_dialog_theme()
	for page in _page_names:
		var tab := _make_button(page, t)
		tab.custom_minimum_size.x = 120.0
		tabs.add_child(tab)
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 8)
		pages.add_child(box)
		for def in OmniSettings.get_definitions(page):
			box.add_child(_make_row(def, t))
	tabs.refresh()
	tabs.current_tab = clampi(keep_tab, 0, maxi(0, _page_names.size() - 1))
	if t != null:
		t.style_option(back_button)
		t.style_option(reset_button)
		# One font size per group, like a popup's buttons.
		var tab_buttons: Array[Control] = []
		for c in tabs.get_children():
			tab_buttons.append(c)
		t.fit_option_group(tab_buttons)
		t.fit_option_group([reset_button, back_button] as Array[Control])

## The page name of the tab that is showing.
func get_current_page() -> String:
	return _page_names[tabs.current_tab] if tabs.current_tab < _page_names.size() else ""

## The control showing setting [param key] (an [HSlider] or an [Omni_Button]), or [code]null[/code].
func get_control(key: String) -> Control:
	var c = _controls.get(key)
	return c if is_instance_valid(c) else null

func _on_open() -> void:
	rebuild()

func _on_close() -> void:
	OmniSettings.save()

func _get_default_focus() -> Control:
	var first := _first_row_control()
	return first if first != null else back_button

func _unhandled_input(event: InputEvent) -> void:
	if is_top() and event is InputEventJoypadButton and event.pressed and _page_names.size() > 1:
		var step := 0
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			step = -1
		elif event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			step = 1
		if step != 0:
			tabs.current_tab = wrapi(tabs.current_tab + step, 0, _page_names.size())
			get_viewport().set_input_as_handled()
			return
	super(event)

func _on_reset_pressed() -> void:
	if not is_top():
		return
	OmniSettings.reset_to_defaults(get_current_page())
	for def in OmniSettings.get_definitions(get_current_page()):
		setting_changed.emit(def["key"], OmniSettings.get_value(def["key"]))
	rebuild()
	_focus_first_row()

#region Rows

func _make_row(def: Dictionary, t: OmniDialogTheme) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	var label := Label.new()
	label.text = def["label"]
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(label)
	var key: String = def["key"]
	var control: Control
	match def["kind"]:
		OmniSettings.Kind.SLIDER:
			control = _make_slider(def, row)
		OmniSettings.Kind.TOGGLE:
			control = _make_stepper(key, [["Off", false], ["On", true]], t)
			row.add_child(control)
		_:
			control = _make_stepper(key, def.get("choices", []), t)
			row.add_child(control)
	_controls[key] = control
	# Godot's slider shows no focus, so the focused row's label lights up instead.
	control.focus_entered.connect(func(): label.modulate = _focus_tint())
	control.focus_exited.connect(func(): label.modulate = Color.WHITE)
	return row

func _make_slider(def: Dictionary, row: HBoxContainer) -> HSlider:
	var key: String = def["key"]
	var lo: float = def.get("min", 0.0)
	var hi: float = def.get("max", 1.0)
	var holder := HBoxContainer.new()
	holder.custom_minimum_size.x = control_width
	holder.add_theme_constant_override("separation", 10)
	var slider := HSlider.new()
	slider.min_value = 0.0
	slider.max_value = 100.0
	slider.step = def.get("step", 0.05) / maxf(hi - lo, 0.0001) * 100.0
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.focus_mode = Control.FOCUS_ALL
	slider.value = inverse_lerp(lo, hi, float(OmniSettings.get_value(key, def["default"]))) * 100.0
	var shown := Label.new()
	shown.custom_minimum_size.x = 48.0
	shown.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	shown.text = "%d%%" % roundi(slider.value)
	slider.value_changed.connect(func(v: float):
		shown.text = "%d%%" % roundi(v)
		var value := lerpf(lo, hi, v / 100.0)
		OmniSettings.set_value(key, value)
		setting_changed.emit(key, value))
	holder.add_child(slider)
	holder.add_child(shown)
	row.add_child(holder)
	return slider

## A button that steps through [param choices] ([code][label, value][/code] pairs): confirm and
## right go forward, left goes back.
func _make_stepper(key: String, choices: Array, t: OmniDialogTheme) -> Omni_Button:
	var b := _make_button("", t)
	b.custom_minimum_size.x = control_width
	var show_current := func():
		var value = OmniSettings.get_value(key)
		var index := _choice_index(choices, value)
		b.Text = "‹  %s  ›" % (str(choices[index][0]) if index >= 0 else str(value))
	var step := func(dir: int):
		if choices.is_empty() or not is_top():
			return
		var index := _choice_index(choices, OmniSettings.get_value(key))
		var value = choices[wrapi(index + dir, 0, choices.size())][1]
		OmniSettings.set_value(key, value)
		setting_changed.emit(key, value)
		show_current.call()
	b.pressed.connect(step.bind(1))
	b.gui_input.connect(func(event: InputEvent):
		if event.is_action_pressed(&"ui_left", true):
			step.call(-1)
			b.accept_event()
		elif event.is_action_pressed(&"ui_right", true):
			step.call(1)
			b.accept_event())
	show_current.call()
	return b

static func _choice_index(choices: Array, value: Variant) -> int:
	for i in choices.size():
		if typeof(choices[i][1]) == typeof(value) and choices[i][1] == value:
			return i
		if (value is float or value is int) and (choices[i][1] is float or choices[i][1] is int) and is_equal_approx(float(choices[i][1]), float(value)):
			return i
	return -1

func _make_button(text: String, t: OmniDialogTheme) -> Omni_Button:
	var b: Omni_Button = option_button_scene.instantiate()
	b.Text = text
	b.size_flags_horizontal = Control.SIZE_SHRINK_END
	if t != null:
		t.style_option(b)
	return b

#endregion

func _first_row_control() -> Control:
	var index := tabs.current_tab
	if index < 0 or index >= pages.get_child_count():
		return null
	for row in pages.get_child(index).get_children():
		var c := row.get_child(row.get_child_count() - 1) as Control
		if c is HBoxContainer:
			c = c.get_child(0)
		if c != null and c.focus_mode != Control.FOCUS_NONE:
			return c
	return null

func _focus_first_row() -> void:
	if not is_open():
		return
	var c := _first_row_control()
	if c != null:
		c.grab_focus.call_deferred()

## Tint of a row label while its control has focus: the look's accent color, made light.
func _focus_tint() -> Color:
	var t := get_dialog_theme()
	return t.accent_color.lightened(0.35) if t != null else Color(1, 0.84, 0.45)

func _apply_title() -> void:
	if title_label != null:
		title_label.text = title
		title_label.visible = title != ""

func _on_dialog_theme(t: OmniDialogTheme) -> void:
	for b in [back_button, reset_button]:
		if b != null:
			t.style_option(b)
	for c in tabs.get_children() if tabs != null else []:
		if c is Omni_Button:
			t.style_option(c)
	for c: Control in _controls.values():
		if is_instance_valid(c) and c is Omni_Button:
			t.style_option(c)
