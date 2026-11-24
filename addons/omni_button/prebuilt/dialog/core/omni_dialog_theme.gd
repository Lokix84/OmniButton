@tool
extends Resource
class_name OmniDialogTheme
## one whole look for the dialog windows.
##
## a look styles every window at once. [member theme] is a normal godot [Theme] that goes on each window's [code]%Root[/code]. it styles the window panels ([PanelContainer]), text ([Label], [RichTextLabel]), fonts, and these type variations: [code]OmniDialogTitle[/code] (popup titles), [code]OmniDialogName[/code] (speaker names), [code]OmniDialogIndicator[/code] (the blinking continue marker) and [code]OmniDialogToast[/code] (each toast). the rest of the properties style the [code]OmniButton[/code] parts a godot Theme can't get to: option buttons, and the text of the dialogue box, narration, popup message and toasts. inside the windows the look always wins over styles set in the [code]parts/[/code] scenes.
## which look a window uses: its own [member OmniOverlay.dialog_theme] if it has one, otherwise [b]Project Settings > omni_button/dialog/theme[/b] ([code]omni_dialog_modern.tres[/code] by default). [method OmniDialogAutoload.set_dialog_theme] switches the autoload's windows while the game runs.
## to make a look, duplicate a file in [code]themes/[/code], drag it into [code]Your Look[/code] on [code]demo/omni_dialog_demo.tscn[/code], run the demo and pick it with the Look button. edit and save the file and the running demo reloads it when you click back into it.

## project setting that holds the look for the whole project.
const SETTING := "omni_button/dialog/theme"
## the look to use when the project setting is empty.
const DEFAULT_PATH := "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres"
## room left above and below option text when an option grows to fit it.
const OPTION_TEXT_MARGIN := 6.0

## godot [Theme] for panels, labels, fonts and the [code]OmniDialog*[/code] type variations.
@export var theme: Theme

@export_group("Option Buttons")
## option button style when it's just sitting there.
@export var option_normal: StyleBox
## option button style under the mouse.
@export var option_hover: StyleBox
## option button style while pressed.
@export var option_pressed: StyleBox
## option button style when it has keyboard / gamepad focus.
@export var option_focus: StyleBox
## option button style when disabled.
@export var option_disabled: StyleBox
## text color on option buttons.
@export var option_text_color: Color = Color(0.94, 0.95, 0.97)
## empty uses the theme's default font.
@export var option_font: Font
## normal height of an option button. options with more text get taller.
@export_range(16, 200, 1, "suffix:px") var option_height: float = 44.0
## biggest font size option text goes up to.
@export_range(6, 100, 1) var option_max_font_size: int = 22
## smallest font size option text goes down to. if it still doesn't fit, that option gets taller.
@export_range(6, 100, 1) var option_min_font_size: int = 14
## long option text wraps onto more lines before it shrinks.
@export var option_wrap: bool = true
## space between the option text and the button's edges (left/right, top/bottom).
@export var option_text_padding: Vector2 = Vector2(12, 2)

@export_group("Text Body")
## text color for the dialogue box and narration.
@export var text_color: Color = Color(0.94, 0.95, 0.97)
## empty uses the theme's default font.
@export var text_font: Font

@export_group("Stylized Menus")
## for the full screen stylized menus ([code]prebuilt/menus/screens/*_stylized.tscn[/code]): the shape
## behind the selected item and the thin stripes.
@export var accent_color: Color = Color(0.36, 0.55, 0.9)
## text color of the selected item, on top of [member accent_color].
@export var accent_text_color: Color = Color(1, 1, 1)
## the screen behind the stylized menus.
@export var menu_background_color: Color = Color(0.05, 0.06, 0.09)
## the big angled bands on the stylized menus.
@export var menu_band_color: Color = Color(0.11, 0.15, 0.25)
## text color of the items that aren't selected.
@export var menu_text_color: Color = Color(0.94, 0.95, 0.97)
## font for the stylized menus' title and items. empty uses the theme's default font, made bold and slanted.
@export var menu_font: Font

static var _default: OmniDialogTheme
static var _default_path := ""

## returns the look for the whole project ([b]Project Settings > omni_button/dialog/theme[/b]), loaded once.
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

## puts the option button settings on [param button] (an [code]OmniButton[/code]).
func style_option(button: Control) -> void:
	if button == null:
		return
	button.set("panel_style_box", option_normal)
	button.set("panel_hover_style_box", option_hover)
	button.set("panel_pressed_style_box", option_pressed)
	button.set("panel_focus_style_box", option_focus)
	button.set("panel_disabled_style_box", option_disabled)
	button.set("label_text_color", option_text_color)
	button.set("label_font", option_font)
	button.set("max_font_size", option_max_font_size)
	button.set("min_font_size", mini(option_min_font_size, option_max_font_size))
	button.set("label_autowrap", TextServer.AUTOWRAP_WORD_SMART if option_wrap else TextServer.AUTOWRAP_OFF)
	button.set("fixed_font_size", 0)
	button.set("label_padding", option_text_padding)
	button.custom_minimum_size.y = option_height
	_refresh(button)

## gives a group of options (one question's answers, or one popup's buttons) one font size: the biggest one where every option fits, but never below [member option_min_font_size]. an option that still doesn't fit gets taller. it waits a few frames for layout, so call it after the buttons are in the tree.
func fit_option_group(buttons: Array[Control]) -> void:
	var live := buttons.filter(func(b): return is_instance_valid(b) and b.is_inside_tree())
	if live.is_empty():
		return
	var tree: SceneTree = live[0].get_tree()
	# let the containers size the buttons and each button fit its own text.
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
		b.set("fixed_font_size", shared)
		b.custom_minimum_size.y = option_height
		_refresh(b)
	# let the labels lay out at the shared size, then grow any option whose text needs more room.
	# growing can make every option narrower (a scrollbar shows up in a scrolling column), which
	# rewraps the text, so keep going until nothing changes.
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

## how tall an option needs to be for all its text, with a little room above and below.
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

## puts the text body settings ([member text_color], [member text_font]) on [param body] (an [code]OmniButton[/code]).
func style_text(body: Control) -> void:
	if body == null:
		return
	body.set("label_text_color", text_color)
	body.set("label_font", text_font)
	_refresh(body)

static func _refresh(button: Control) -> void:
	if button.has_method("queue_refresh"):
		button.call("queue_refresh", true, true, true)
