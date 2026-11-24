@tool
extends Resource
class_name OmniDialogTheme
## One complete look for the dialog windows.
##
## A look styles every window at once. [member theme] is an ordinary Godot [Theme], applied to each window's [code]%Root[/code]: it styles the window panels ([PanelContainer]), text ([Label], [RichTextLabel]), fonts, and these type variations: [code]OmniDialogTitle[/code] (popup titles), [code]OmniDialogName[/code] (speaker names), [code]OmniDialogIndicator[/code] (the blinking continue marker) and [code]OmniDialogToast[/code] (each toast). The other properties style the [code]Omni_Button[/code] parts a Godot Theme can't reach: option buttons, and the text of the dialogue box, narration, popup message and toasts. Inside the windows, the look always wins over styles set in the [code]parts/[/code] scenes.
## Which look a window uses: its own [member OmniOverlay.dialog_theme] if set, otherwise [b]Project Settings > omni_button/dialog/theme[/b] ([code]omni_dialog_modern.tres[/code] by default). [method OmniDialogAutoload.set_dialog_theme] switches the autoload's windows at runtime.
## To make a look, duplicate a file in [code]themes/[/code], drag it into [code]demo/omni_dialog_demo.tscn[/code]'s [code]Your Look[/code], run the demo and pick it with the Look button. Edit and save the file: the running demo reloads it when you click back into it.

## Project Setting that holds the project-wide look.
const SETTING := "omni_button/dialog/theme"
## The look used when the Project Setting is empty.
const DEFAULT_PATH := "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres"
## Room kept above and below option text when an option grows to fit it.
const OPTION_TEXT_MARGIN := 6.0

## Godot [Theme] for panels, labels, fonts and the [code]OmniDialog*[/code] type variations.
@export var theme: Theme

@export_group("Option Buttons")
## Option button style when idle.
@export var option_normal: StyleBox
## Option button style under the mouse.
@export var option_hover: StyleBox
## Option button style while pressed.
@export var option_pressed: StyleBox
## Option button style when it has keyboard / gamepad focus.
@export var option_focus: StyleBox
## Option button style when disabled.
@export var option_disabled: StyleBox
## Text color of option buttons.
@export var option_text_color: Color = Color(0.94, 0.95, 0.97)
## Empty uses the theme's default font.
@export var option_font: Font
## Normal height of an option button. Options with more text grow taller.
@export_range(16, 200, 1, "suffix:px") var option_height: float = 44.0
## Largest font size option text grows to.
@export_range(6, 100, 1) var option_max_font_size: int = 22
## Smallest font size option text shrinks to. Text that still doesn't fit makes that option taller.
@export_range(6, 100, 1) var option_min_font_size: int = 14
## Long option text wraps onto more lines before it shrinks.
@export var option_wrap: bool = true
## Space kept between option text and the button's edges (left/right, top/bottom).
@export var option_text_padding: Vector2 = Vector2(12, 2)

@export_group("Text Body")
## Text color of the dialogue box and narration body.
@export var text_color: Color = Color(0.94, 0.95, 0.97)
## Empty uses the theme's default font.
@export var text_font: Font

@export_group("Stylized Menus")
## The full-screen stylized menus ([code]prebuilt/menus/screens/*_stylized.tscn[/code]): the shape behind
## the selected item and the thin stripes.
@export var accent_color: Color = Color(0.36, 0.55, 0.9)
## Text color of the selected item, on top of [member accent_color].
@export var accent_text_color: Color = Color(1, 1, 1)
## The screen behind the stylized menus.
@export var menu_background_color: Color = Color(0.05, 0.06, 0.09)
## The big angled bands of the stylized menus.
@export var menu_band_color: Color = Color(0.11, 0.15, 0.25)
## Text color of the items that aren't selected.
@export var menu_text_color: Color = Color(0.94, 0.95, 0.97)
## Font of the stylized menus' title and items. Empty: the theme's default font, made bold and slanted.
@export var menu_font: Font

static var _default: OmniDialogTheme
static var _default_path := ""

## Returns the project-wide look ([b]Project Settings > omni_button/dialog/theme[/b]), loaded once.
static func get_default() -> OmniDialogTheme:
	var path := str(ProjectSettings.get_setting(SETTING, ""))
	if path == "":
		path = DEFAULT_PATH
	if _default == null or _default_path != path:
		_default = load(path) as OmniDialogTheme
		if _default == null and path != DEFAULT_PATH:
			push_error("OmniDialogTheme: '%s' is not an OmniDialogTheme; using the modern look." % path)
			_default = load(DEFAULT_PATH) as OmniDialogTheme
		_default_path = path
	return _default

## Applies the option button settings to [param button] (an [code]Omni_Button[/code]).
func style_option(button: Control) -> void:
	if button == null:
		return
	button.set("PanelStyleBox", option_normal)
	button.set("PanelHoverStyleBox", option_hover)
	button.set("PanelPressedStyleBox", option_pressed)
	button.set("PanelFocusStyleBox", option_focus)
	button.set("PanelDisabledStyleBox", option_disabled)
	button.set("LabelTextColor", option_text_color)
	button.set("LabelFont", option_font)
	button.set("MaxFontSize", option_max_font_size)
	button.set("MinFontSize", mini(option_min_font_size, option_max_font_size))
	button.set("LabelAutowrap", TextServer.AUTOWRAP_WORD_SMART if option_wrap else TextServer.AUTOWRAP_OFF)
	button.set("FixedFontSize", 0)
	button.set("LabelPadding", option_text_padding)
	button.custom_minimum_size.y = option_height
	_refresh(button)

## Gives a group of options (one question's answers, or one popup's buttons) a single font size: the largest at which every option fits, never below [member option_min_font_size]. An option whose text still doesn't fit is made taller. Waits a few frames for layout, so call it after the buttons are in the tree.
func fit_option_group(buttons: Array[Control]) -> void:
	var live := buttons.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	if live.is_empty():
		return
	var tree: SceneTree = live[0].get_tree()
	# Let containers size the buttons and each button fit its own text.
	await tree.process_frame
	await tree.process_frame
	live = live.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	if live.is_empty():
		return
	var shared := option_max_font_size
	for b in live:
		var fitted := int(b.get("_last_fit_font_size"))
		if fitted > 0:
			shared = mini(shared, fitted)
	shared = maxi(shared, mini(option_min_font_size, option_max_font_size))
	for b in live:
		b.set("FixedFontSize", shared)
		b.custom_minimum_size.y = option_height
		_refresh(b)
	# Let the labels lay out at the shared size, then grow any option whose text needs more room.
	# Growing can narrow every option (a scrollbar appears in a scrolling column), which re-wraps
	# the text, so repeat until nothing changes.
	for _pass in 4:
		await tree.process_frame
		await tree.process_frame
		var grew := false
		for b in live:
			if not is_instance_valid(b):
				continue
			var needed := _needed_height(b)
			if needed > b.size.y + 0.5:
				b.custom_minimum_size.y = needed
				grew = true
		if not grew:
			break

## Vertical space an option needs for all of its laid-out text, with a little room above and below.
static func _needed_height(b: Control) -> float:
	var label := b.get("_label") as Label
	if label == null or not is_instance_valid(label):
		var rich := b.get("_rich_label") as RichTextLabel
		if rich != null and is_instance_valid(rich):
			return ceilf(rich.get_content_height() + b.size.y - rich.size.y + OPTION_TEXT_MARGIN * 2.0)
		return 0.0
	var lines := label.get_line_count()
	var spacing := label.get_theme_constant("line_spacing")
	var text_h := lines * label.get_line_height() + maxi(0, lines - 1) * spacing
	return ceilf(text_h + b.size.y - label.size.y + OPTION_TEXT_MARGIN * 2.0)

## Applies the text body settings ([member text_color], [member text_font]) to [param body] (an [code]Omni_Button[/code]).
func style_text(body: Control) -> void:
	if body == null:
		return
	body.set("LabelTextColor", text_color)
	body.set("LabelFont", text_font)
	_refresh(body)

static func _refresh(button: Control) -> void:
	if button.has_method("queue_refresh"):
		button.call("queue_refresh", true, true, true)
