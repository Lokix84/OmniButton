extends SceneTree
# Checks the dialog looks (OmniDialogTheme): the project default, switching at runtime, and
# per-window overrides.
# Usage: godot --headless --path . -s res://addons/omni_button/prebuilt/dialog/dev/OmniDialogThemeValidation.gd

const DialogScript := preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")
const MODERN := preload("res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres")
const RETRO := preload("res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_retro.tres")
const BOLD := preload("res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_bold.tres")
const PopupScene := preload("res://addons/omni_button/prebuilt/dialog/windows/popup/omni_popup.tscn")

var _failures: Array[String] = []
var _checks := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_check(MODERN is OmniDialogTheme and RETRO is OmniDialogTheme and BOLD is OmniDialogTheme, "the shipped looks load as OmniDialogTheme")
	_check(OmniDialogTheme.get_default() == MODERN, "the project default is the modern look")
	for t: OmniDialogTheme in [MODERN, RETRO, BOLD]:
		var th := t.theme
		var complete := th != null and th.has_stylebox("panel", "PanelContainer") \
			and th.has_stylebox("panel", "OmniDialogToast") and th.has_font_size("font_size", "OmniDialogTitle") \
			and th.has_color("font_color", "OmniDialogName") and th.has_color("font_color", "OmniDialogIndicator") \
			and t.option_normal != null and t.option_hover != null and t.option_pressed != null and t.option_focus != null
		_check(complete, "%s defines panels, variations and option styles" % t.resource_path.get_file())

	var dlg = DialogScript.new()
	root.add_child(dlg)
	await process_frame
	var popup: OmniPopup = dlg.get_popup()
	popup.animation_duration = 0.0
	var box: OmniDialogueBox = dlg.get_dialogue()
	box.animation_duration = 0.0
	var toast: OmniToast = dlg.get_toast()

	# Default look
	_check(popup.root_control.theme == MODERN.theme and box.root_control.theme == MODERN.theme, "windows start with the default look")
	var run := func(c: Callable): await c.call()
	run.call(func(): return await dlg.confirm("Look test", "Title"))
	await process_frame
	_check(popup._button_nodes[0].PanelStyleBox == MODERN.option_normal and popup._button_nodes[0].PanelFocusStyleBox == MODERN.option_focus, "popup buttons use the look's option styles")
	_check(popup.title_label.get_theme_font_size("font_size") == MODERN.theme.get_font_size("font_size", "OmniDialogTitle"), "popup title uses the OmniDialogTitle variation")

	# Switch while the popup is open
	dlg.set_dialog_theme(RETRO)
	await process_frame
	_check(popup.root_control.theme == RETRO.theme and box.root_control.theme == RETRO.theme and toast.root_control.theme == RETRO.theme, "set_dialog_theme switches every managed window")
	_check(popup._button_nodes[0].PanelStyleBox == RETRO.option_normal and popup._button_nodes[0].LabelFont == RETRO.option_font, "open popup buttons are restyled")
	_check(popup.message_label.LabelFont == RETRO.text_font and popup.message_label.LabelTextColor == RETRO.text_color, "popup message uses the look's text settings")
	_check(popup.title_label.get_theme_font_size("font_size") == RETRO.theme.get_font_size("font_size", "OmniDialogTitle"), "title size follows the new look")
	popup._button_nodes[0].pressed.emit()
	await process_frame
	await process_frame

	# Buttons built after the switch
	run.call(func(): return await dlg.choose("After switch", PackedStringArray(["a", "b", "c"])))
	await process_frame
	_check(popup._button_nodes[2].PanelStyleBox == RETRO.option_normal and popup._button_nodes[2].custom_minimum_size.y == RETRO.option_height, "new buttons get the current look")
	popup.cancel()
	await process_frame
	await process_frame

	# Dialogue body and replies
	_check(box.body.LabelTextColor == RETRO.text_color and box.body.LabelFont == RETRO.text_font, "dialogue text uses the look's text settings")
	run.call(func(): return await dlg.ask("Guard", "Well?", PackedStringArray(["Yes", "No"])))
	await process_frame
	box.advance()
	await process_frame
	_check(box._option_nodes.size() == 2 and box._option_nodes[0].PanelStyleBox == RETRO.option_normal, "dialogue replies use the look's option styles")
	_check(box.name_label.get_theme_color("font_color") == RETRO.theme.get_color("font_color", "OmniDialogName"), "speaker name uses the OmniDialogName variation")
	box._option_nodes[0].pressed.emit()
	await process_frame
	await process_frame

	# Toasts take the look's text settings
	dlg.toast("Look toast", 5.0)
	await process_frame
	var item = toast.toast_list.get_child(toast.toast_list.get_child_count() - 1)
	_check(item.LabelFont == RETRO.text_font, "toasts use the look's text settings")
	toast.clear()

	# Windows created after the switch
	var narration: OmniNarration = dlg.get_narration()
	_check(narration.root_control.theme == RETRO.theme and narration.body.LabelFont == RETRO.text_font, "windows created later get the current look")

	# Back to the default
	dlg.set_dialog_theme(null)
	await process_frame
	_check(popup.root_control.theme == MODERN.theme and box.body.LabelTextColor == MODERN.text_color, "set_dialog_theme(null) goes back to the project default")

	# A window's own dialog_theme wins
	var own: OmniPopup = PopupScene.instantiate()
	own.dialog_theme = RETRO
	root.add_child(own)
	await process_frame
	_check(own.root_control.theme == RETRO.theme, "a window's own dialog_theme overrides the project default")
	own.queue_free()

	dlg.queue_free()
	await process_frame
	if _failures.is_empty():
		print("OmniDialogTheme validation passed (%d checks)." % _checks)
		quit(0)
	else:
		for failure in _failures:
			push_error(failure)
		print("OmniDialogTheme validation failed (%d/%d checks)." % [_failures.size(), _checks])
		quit(1)

func _check(condition: bool, description: String) -> void:
	_checks += 1
	if not condition:
		_failures.append(description)
