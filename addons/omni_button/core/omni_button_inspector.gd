@tool
extends EditorInspectorPlugin
## inspector plugin: nicer labels, tooltips and custom editors for the OmniButton settings.

const ACTION_TOOLTIPS := {
	"enable_pressed_actions": "sends pressed and runs pressed_action when the button gets pressed.",
	"enable_released_actions": "sends released and runs released_action when the button gets let go.",
	"enable_hover_actions": "sends hover_in and hover_out (and runs their actions) as the pointer comes and goes.",
	"enable_toggle_actions": "sends toggled and runs toggled_action when the button flips on or off.",
	"enable_hold_actions": "sends hold and runs hold_action once the hold fills up.",
	"enable_swipe_actions": "sends swipe and swipe_ended (and runs their actions) when it sees a swipe.",
	"enable_log_actions": "turns on the log signal and log_action for messages sent through this button.",
	"enable_warning_actions": "turns on the warning signal and warning_action for warnings sent through this button.",
	"enable_error_actions": "turns on the error signal and error_action for errors sent through this button.",
}

const PROPERTY_LABELS := {
	"enable_pressed_actions": "Press",
	"enable_released_actions": "Release",
	"enable_hover_actions": "Hover",
	"enable_toggle_actions": "Toggle",
	"enable_hold_actions": "Hold",
	"enable_swipe_actions": "Swipe",
	"enable_log_actions": "Log",
	"enable_warning_actions": "Warning",
	"enable_error_actions": "Error",
	"background_type": "Background Type",
	"label_type": "Label Type",
	"disabled": "Disabled",
	"disabled_modulate": "Disabled Modulate",
	"invert_modes": "Invert Modes",
	"hover_scale": "Scale",
	"hover_lerp_speed": "Lerp Speed",
	"selected_color": "Selected Color",
	"activation_action": "InFocus Action",
	"output_action": "Output Action",
	"bounds_source": "Bounds Source",
	"hit_slop": "Hit Slop",
	"clamp_to_bounds": "Clamp To Bounds",
	"follow_mode": "Follow Mode",
	"clamp_shape": "Clamp Shape",
	"joystick_radius_px": "Joystick Radius Px",
	"joystick_rect_size_px": "Joystick Rect Size Px",
	"joystick_deadzone": "Joystick Deadzone",
	"joystick_snap_to_input": "Joystick Snap To Input",
	"joystick_hide_when_inactive": "Joystick Hide When Inactive",
	"joystick_reset_on_release": "Joystick Reset On Release",
	"enable_joystick_area": "Enable Joystick Area",
	"joystick_area_persistent": "Joystick Area Persistent",
	"joystick_area_color": "Joystick Area Color",
	"joystick_area_thickness": "Joystick Area Thickness",
	"joystick_area_use_rect_for_clamp": "Joystick Area Use Rect For Clamp",
	"joystick_area_external_path": "Joystick Area External Path",
	"enable_default_thumb": "Enable Default Thumb",
	"default_thumb_size_ratio": "Default Thumb Size Ratio",
	"default_thumb_color": "Default Thumb Color",
	"icon_texture": "Texture",
	"icon_expand_mode": "Expand",
	"icon_stretch_mode": "Stretch",
	"icon_flip_h": "Flip H",
	"icon_flip_v": "Flip V",
	"icon_modulate": "Modulate",
	"hold_duration": "Duration",
	"hold_fill_color": "Fill Color",
	"hold_fill_direction": "Fill Direction",
	"swipe_threshold": "Threshold",
	"touch_swipe_init": "Touch Init",
	"touch_swipe_exit": "Touch Exit",
	"mouse_swipe_init": "Mouse Init",
	"mouse_swipe_exit": "Mouse Exit",
	"interaction_mode": "Interaction Mode",
	"cooldown_trigger": "Trigger",
	"cooldown_start_delay": "Start Delay",
	"cooldown_duration": "Duration",
	"cooldown_start_filled": "Start Filled",
	"cooldown_color": "Color",
	"cooldown_fill_direction": "Fill Direction",
	"invert_on_cooldown": "Invert During",
	"cooldown_invert_duration": "Invert Delay",
	"suspend_hover_scale_during_cooldown": "Stop Hover Scale",
	"allow_hold_during_cooldown": "Allow Hold During Cooldown",
	"hide_cooldown_during_hold_build_up": "Hide During Buildup",
	"text": "Text",
	"label_uppercase": "Uppercase",
	"label_clip_text": "Clip",
	"label_text_overrun": "Overrun",
	"label_font": "Font",
	"label_text_color": "Color",
	"text_modulate": "Modulate",
	"label_horizontal_alignment": "Horizontal",
	"label_vertical_alignment": "Vertical",
	"label_autowrap": "Autowrap",
	"rich_label_use_bbcode": "Rich Label Use BB Code",
	"rich_text_fit_content": "Rich Text Fit Content",
	"rich_text_scroll_active": "Rich Text Scroll Active",
	"rich_text_scroll_following": "Rich Text Scroll Following",
	"rich_text_selection_enabled": "Rich Text Selection Enabled",
	"rich_text_context_menu_enabled": "Rich Text Context Menu Enabled",
	"text_fit_padding": "Text Fit Padding",
	"min_font_size": "Min Font Size",
	"max_font_size": "Max Font Size",
	"fixed_font_size": "Fixed Font Size",
	"enable_text_auto_size": "Enable Text Auto Size",
	"label_padding": "Label Padding",
	"label_additional_padding_left": "Left",
	"label_additional_padding_top": "Top",
	"label_additional_padding_right": "Right",
	"label_additional_padding_bottom": "Bottom",
	"text_to_type": "Text To Type",
	"suspend_hover_during_typewriter": "Suspend Hover During Typewriter",
	"delay_effect_tags_during_typewriter": "Delay Effect Tags During Typewriter",
	"finish_typewriter_on_press": "Finish Typewriter On Press",
	"panel_theme_variation": "Panel Theme Variation",
	"panel_style_box": "Panel Style Box",
	"panel_hover_style_box": "Panel Hover Style Box",
	"panel_pressed_style_box": "Panel Pressed Style Box",
	"panel_disabled_style_box": "Panel Disabled Style Box",
	"panel_focus_style_box": "Panel Focus Style Box",
	"panel_modulate": "Panel Modulate",
	"texture": "Texture",
	"expand_mode": "Expand",
	"stretch_mode": "Stretch",
	"flip_h": "Flip H",
	"flip_v": "Flip V",
	"background_modulate": "Background Modulate",
	"managed_draw_on_top": "Managed Draw On Top",
	"selected": "Selected",
	"is_toggled": "Is Toggled",
	"is_pressed": "Is Pressed",
	"is_hovering": "Is Hovering",
	"is_holding": "Is Holding",
	"debugger_log": "Debugger Log",
}

const CUSTOM_PROPERTY_EDITORS := {
	"activation_action": true,
	"output_action": true,
	"label_font": true,
	"label_text_color": true,
	"text_modulate": true,
	"label_horizontal_alignment": true,
	"label_vertical_alignment": true,
	"label_autowrap": true,
	"label_uppercase": true,
	"label_clip_text": true,
	"label_text_overrun": true,
	"label_additional_padding_left": true,
	"label_additional_padding_top": true,
	"label_additional_padding_right": true,
	"label_additional_padding_bottom": true,
	"hover_scale": true,
	"hover_lerp_speed": true,
	"icon_texture": true,
	"icon_expand_mode": true,
	"icon_stretch_mode": true,
	"icon_flip_h": true,
	"icon_flip_v": true,
	"icon_modulate": true,
	"hold_duration": true,
	"hold_fill_color": true,
	"hold_fill_direction": true,
	"swipe_threshold": true,
	"touch_swipe_init": true,
	"touch_swipe_exit": true,
	"mouse_swipe_init": true,
	"mouse_swipe_exit": true,
	"cooldown_trigger": true,
	"cooldown_start_delay": true,
	"cooldown_duration": true,
	"cooldown_start_filled": true,
	"cooldown_color": true,
	"cooldown_fill_direction": true,
	"invert_on_cooldown": true,
	"cooldown_invert_duration": true,
	"suspend_hover_scale_during_cooldown": true,
	"hide_cooldown_during_hold_build_up": true,
}

const PROPERTY_TOOLTIPS := {
	"background_type": "none means no background. use panel draws a styled panel, use texture draws a texture.",
	"label_type": "none means no text at all. label is plain text, rich text label lets you use bbcode and effects.",
	"label_font": "font for the text.",
	"label_text_color": "color of the text.",
	"text_modulate": "extra color multiplied on top of the text.",
	"disabled_modulate": "gets multiplied into the text and icon colors while disabled is on so it looks greyed out. white leaves them alone.",
	"label_horizontal_alignment": "left, center or right inside the label.",
	"label_vertical_alignment": "top, center or bottom inside the label.",
	"label_autowrap": "off never wraps, arbitrary wraps anywhere, word wraps between words, smart tries words first but will break a long word if it has to.",
	"label_uppercase": "shows plain label text in all caps without actually changing the text.",
	"label_clip_text": "cuts off plain label text at the edge of the label.",
	"label_text_overrun": "none leaves the text alone. trim character/word cuts off what doesn't fit, ellipsis adds \"...\", and trim word with ellipsis cuts at a word and adds \"...\".",
	"label_additional_padding_left": "extra space taken off the left of the text area.",
	"label_additional_padding_top": "extra space taken off the top of the text area.",
	"label_additional_padding_right": "extra space taken off the right of the text area.",
	"label_additional_padding_bottom": "extra space taken off the bottom of the text area.",
	"interaction_mode": "momentary is only pressed while you hold it. toggle on press flips on press, toggle on release flips on release.",
	"hover_scale": "how big the button gets on hover. 1.2 is 120%, zero turns it off. it won't grow past the edge of the screen.",
	"hover_lerp_speed": "how fast it grows and shrinks between normal and hover size.",
	"icon_texture": "the icon texture. it sits behind the text.",
	"icon_expand_mode": "keep size uses the texture's own size, ignore size ignores it, fit width/height lock that side, and the proportional ones keep the aspect ratio.",
	"icon_stretch_mode": "how the icon gets drawn: scaled, tiled, native size, centered, or fit/cover keeping the aspect ratio.",
	"icon_flip_h": "flips the icon left to right.",
	"icon_flip_v": "flips the icon upside down.",
	"icon_modulate": "gets multiplied into the icon's colors.",
	"hold_duration": "how long you have to hold the button before the hold action fires. zero turns hold off.",
	"hold_fill_color": "color of the fill that grows while you're holding.",
	"hold_fill_direction": "which way the hold fill grows: 0 bottom to top, 1 top to bottom, 2 left to right, 3 right to left.",
	"swipe_threshold": "how far in pixels the pointer has to move before it counts as a swipe.",
	"touch_swipe_init": "on hover in starts tracking a touch swipe as soon as the finger moves onto it, on pressed waits for the touch to press it.",
	"touch_swipe_exit": "on hover out ends a touch swipe when the finger leaves, on released ends it when the finger lifts.",
	"mouse_swipe_init": "on hover in starts tracking a mouse swipe when the pointer moves onto it, on pressed waits for a click.",
	"mouse_swipe_exit": "on hover out ends a mouse swipe when the pointer leaves, on released ends it when the mouse button comes up.",
	"cooldown_trigger": "none means no cooldown. on press starts it on press, on release on release, on press and release on both.",
	"follow_mode": "none stays put. follow both moves with the pointer. virtual joystick sends joystick axes while the pointer moves inside its area.",
	"clamp_shape": "circle keeps the stick inside a radius, rectangle keeps it inside a width and height.",
	"debugger_log": "prints what this button is doing to the output. off is off, basic turns it on.",
	"output_action": "input map action that gets held down while this button is pressed, so game code can use Input.is_action_pressed() (same idea as TouchScreenButton). empty does nothing.",
	"activation_action": "input map action that presses this button while it has focus. leave it empty and focus does nothing. players remap it through the input map.",
	"cooldown_start_delay": "how long to wait after the trigger before the cooldown fill starts.",
	"cooldown_duration": "how long the cooldown lasts after that wait.",
	"cooldown_start_filled": "starts the cooldown fill full and drains it, instead of filling it up from empty.",
	"cooldown_color": "color of the cooldown overlay.",
	"cooldown_fill_direction": "which way the cooldown overlay moves: 0 bottom to top, 1 top to bottom, 2 left to right, 3 right to left.",
	"invert_on_cooldown": "flips the button's colors while the cooldown is running.",
	"cooldown_invert_duration": "how long that color flip takes. zero is instant.",
	"suspend_hover_scale_during_cooldown": "puts the button back to normal size while the cooldown is running.",
	"allow_hold_during_cooldown": "lets hold keep building while the cooldown is running.",
	"hide_cooldown_during_hold_build_up": "hides the cooldown overlay while the hold fill is showing.",
}

## tooltips for dropdown options. "property/Option" is checked first since words like None mean
## different things on different settings, then just "Option".
const OPTION_TOOLTIPS := {
	"Keep Size": "uses the icon texture's own size.",
	"Ignore Size": "ignores the icon texture's minimum size when laying it out.",
	"Fit Width": "fits the icon to the width it has.",
	"Fit Width Proportional": "fits to the width it has and keeps the aspect ratio.",
	"Fit Height": "fits the icon to the height it has.",
	"Fit Height Proportional": "fits to the height it has and keeps the aspect ratio.",
	"Scale": "stretches the texture to fill the rect.",
	"Tile": "repeats the texture at its own size.",
	"Keep": "draws it at its own size from the top left corner.",
	"Keep Centered": "draws it at its own size in the middle.",
	"Keep Aspect": "fits it inside and keeps the aspect ratio.",
	"Keep Aspect Centered": "fits it inside, centered, and keeps the aspect ratio.",
	"Keep Aspect Covered": "covers the whole rect and keeps the aspect ratio. some of the texture might get cut off.",
	"On Hover In": "starts tracking when the pointer moves onto the button.",
	"On Pressed": "starts tracking when the press starts.",
	"On Hover Out": "stops tracking when the pointer leaves the button.",
	"On Released": "stops tracking when the press lets go.",
	"On Press": "starts the cooldown when the button gets pressed.",
	"On Release": "starts the cooldown when the button gets let go.",
	"On Press And Release": "starts the cooldown on both press and release.",
	"Use Panel": "draws a styled panel as the background.",
	"Use Texture": "draws a texture as the background.",
	"Label": "plain text.",
	"Rich Text Label": "rich text, can use bbcode and effects.",
	"Momentary": "only pressed while you're holding it down.",
	"Toggle On Press": "flips on or off every time it gets pressed.",
	"Toggle On Release": "flips on or off every time it gets let go.",
	"Follow Both": "moves the button along with the pointer while it's pressed.",
	"Virtual Joystick": "sends joystick axes while the pointer moves inside its area.",
	"Circle": "keeps the stick inside a circle.",
	"Rectangle": "keeps the stick inside a rectangle.",
	"Arbitrary": "wraps at any character when it hits the edge of the label.",
	"Word": "wraps between words.",
	"Word (Smart)": "tries to wrap between words but breaks a long word if it has to.",
	"Trim Character": "cuts off the characters that don't fit.",
	"Trim Word": "cuts off at a word.",
	"Ellipsis": "puts \"...\" where the text gets cut off.",
	"Trim Word with Ellipsis": "cuts off at a word and adds \"...\".",
	"background_type/None": "no background.",
	"label_type/None": "no text.",
	"cooldown_trigger/None": "no cooldown.",
	"follow_mode/None": "stays put.",
	"label_text_overrun/None": "leaves text that doesn't fit alone.",
	"label_autowrap/Off": "never wraps.",
	"debugger_log/Off": "no logging.",
	"debugger_log/Basic": "prints what this button is doing to the output.",
}

func _can_handle(object: Object) -> bool:
	return object is OmniButton

func _parse_property(
	_object: Object,
	_type: Variant.Type,
	name: String,
	_hint_type: PropertyHint,
	_hint_string: String,
	_usage_flags: int,
	_wide: bool
) -> bool:
	if ACTION_TOOLTIPS.has(name):
		add_property_editor(
			name,
			_ActionCheckboxEditor.new(ACTION_TOOLTIPS[name]),
			false,
			String(PROPERTY_LABELS[name])
		)
		return true
	if CUSTOM_PROPERTY_EDITORS.has(name) or (_type == TYPE_INT and _hint_type == PROPERTY_HINT_ENUM):
		var label := String(PROPERTY_LABELS.get(name, ""))
		var description := String(PROPERTY_TOOLTIPS.get(name, ""))
		add_property_editor(
			name,
			_ConcisePropertyEditor.new(
				name,
				_type,
				_hint_type,
				_hint_string,
				description
			),
			false,
			label
		)
		return true
	return false

class _ActionCheckboxEditor extends EditorProperty:
	var _checkbox: CheckBox

	func _init(description: String) -> void:
		name_split_ratio = 0.5
		tooltip_text = description
		_checkbox = CheckBox.new()
		_checkbox.tooltip_text = description
		_checkbox.toggled.connect(_on_toggled)
		add_child(_checkbox)
		add_focusable(_checkbox)

	func _update_property() -> void:
		var object := get_edited_object()
		var property_name := get_edited_property()
		if object != null:
			_checkbox.set_pressed_no_signal(bool(object.get(property_name)))

	func _on_toggled(value: bool) -> void:
		emit_changed(get_edited_property(), value)

class _ConcisePropertyEditor extends EditorProperty:
	var _control: Control
	var _property_name: String
	var _enum_values: Array[int] = []
	var _enum_option_texts: Array[String] = []
	var _description: String

	func _init(
		property_name: String,
		type: Variant.Type,
		hint_type: PropertyHint,
		hint_string: String,
		description: String
	) -> void:
		_property_name = property_name
		_description = description
		tooltip_text = description
		match property_name:
			"hover_scale", "hover_lerp_speed", "hold_duration", "swipe_threshold", "cooldown_start_delay", "cooldown_duration", "cooldown_invert_duration", "label_additional_padding_left", "label_additional_padding_top", "label_additional_padding_right", "label_additional_padding_bottom":
				var slider := EditorSpinSlider.new()
				var range_parts := hint_string.split(",")
				if range_parts.size() >= 3:
					slider.min_value = float(range_parts[0])
					slider.max_value = float(range_parts[1])
					slider.step = float(range_parts[2])
				if range_parts.size() > 3:
					slider.allow_greater = "or_greater" in range_parts.slice(3)
					slider.allow_lesser = "or_lesser" in range_parts.slice(3)
				slider.value_changed.connect(_on_value_changed)
				_control = slider
			"icon_texture", "label_font":
				var picker := EditorResourcePicker.new()
				picker.base_type = "Texture2D" if property_name == "icon_texture" else "Font"
				picker.resource_changed.connect(_on_resource_changed)
				_control = picker
			"activation_action", "output_action":
				var line_edit := LineEdit.new()
				line_edit.text_changed.connect(_on_string_name_changed)
				_control = line_edit
			"icon_expand_mode", "icon_stretch_mode", "touch_swipe_init", "touch_swipe_exit", "mouse_swipe_init", "mouse_swipe_exit", "cooldown_trigger":
				_control = _create_enum_editor(hint_string, property_name)
			"icon_flip_h", "icon_flip_v", "cooldown_start_filled", "invert_on_cooldown", "suspend_hover_scale_during_cooldown", "hide_cooldown_during_hold_build_up", "label_uppercase", "label_clip_text":
				var checkbox := CheckBox.new()
				checkbox.toggled.connect(_on_value_changed)
				_control = checkbox
			"icon_modulate", "hold_fill_color", "cooldown_color", "label_text_color", "text_modulate":
				var color_picker := ColorPickerButton.new()
				color_picker.color_changed.connect(_on_value_changed)
				_control = color_picker
			"hold_fill_direction", "cooldown_fill_direction":
				var slider := EditorSpinSlider.new()
				slider.editing_integer = true
				slider.step = 1.0
				slider.value_changed.connect(_on_value_changed)
				_control = slider
			_:
				if type == TYPE_INT and hint_type == PROPERTY_HINT_ENUM:
					_control = _create_enum_editor(hint_string, property_name)
		add_child(_control)
		_control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_control.tooltip_text = description
		add_focusable(_control)
		name_split_ratio = 0.5

	func _create_enum_editor(hint_string: String, property_name: String) -> MenuButton:
		var menu_button := MenuButton.new()
		menu_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		menu_button.custom_minimum_size.x = 0.0
		var popup := menu_button.get_popup()
		for index in hint_string.split(",").size():
			var option := hint_string.split(",")[index].strip_edges()
			var parts := option.split(":", false, 1)
			var value := index
			if parts.size() == 2:
				option = parts[0].strip_edges()
				value = int(parts[1].strip_edges())
			# script enums are SCREAMING_CASE, show them like the stock inspector does
			if option == option.to_upper():
				option = option.capitalize()
			popup.add_item(option, index)
			popup.set_item_tooltip(index, _enum_option_tooltip(option, property_name))
			_enum_values.append(value)
			_enum_option_texts.append(option)
		popup.id_pressed.connect(_on_option_selected)
		return menu_button

	func _enum_option_tooltip(option: String, property_name: String) -> String:
		return String(OPTION_TOOLTIPS.get(property_name + "/" + option, OPTION_TOOLTIPS.get(option, "")))

	func _enum_display_text(option: String, property_name: String) -> String:
		var display := option
		if property_name == "label_horizontal_alignment":
			display = display.trim_prefix("Horizontal Alignment ")
		elif property_name == "label_vertical_alignment":
			display = display.trim_prefix("Vertical Alignment ")
		const MAX_DISPLAY_CHARACTERS := 12
		if display.length() > MAX_DISPLAY_CHARACTERS:
			display = display.substr(0, MAX_DISPLAY_CHARACTERS - 1) + "…"
		return display

	func _set_enum_selection(value: int) -> void:
		var index := _enum_values.find(value)
		if index < 0 or index >= _enum_option_texts.size():
			return
		var menu_button := _control as MenuButton
		var option := _enum_option_texts[index]
		menu_button.text = _enum_display_text(option, _property_name)
		var option_tooltip := _enum_option_tooltip(option, _property_name)
		menu_button.tooltip_text = _description
		if option_tooltip != "":
			menu_button.tooltip_text += "\n" + option_tooltip

	func _update_property() -> void:
		var object := get_edited_object()
		if object == null:
			return
		var value: Variant = object.get(_property_name)
		match _property_name:
			"hover_scale", "hover_lerp_speed", "hold_duration", "swipe_threshold", "cooldown_start_delay", "cooldown_duration", "cooldown_invert_duration", "hold_fill_direction", "cooldown_fill_direction", "label_additional_padding_left", "label_additional_padding_top", "label_additional_padding_right", "label_additional_padding_bottom":
				(_control as EditorSpinSlider).set_value_no_signal(float(value))
			"icon_texture", "label_font":
				(_control as EditorResourcePicker).edited_resource = value
			"activation_action", "output_action":
				var line_edit := _control as LineEdit
				var text := String(value)
				if line_edit.text != text:
					line_edit.text = text
			"icon_expand_mode", "icon_stretch_mode", "touch_swipe_init", "touch_swipe_exit", "mouse_swipe_init", "mouse_swipe_exit", "cooldown_trigger", "label_horizontal_alignment", "label_vertical_alignment", "label_autowrap", "label_text_overrun":
				_set_enum_selection(int(value))
			"icon_flip_h", "icon_flip_v", "cooldown_start_filled", "invert_on_cooldown", "suspend_hover_scale_during_cooldown", "hide_cooldown_during_hold_build_up", "label_uppercase", "label_clip_text":
				(_control as CheckBox).set_pressed_no_signal(bool(value))
			"icon_modulate", "hold_fill_color", "cooldown_color", "label_text_color", "text_modulate":
				(_control as ColorPickerButton).color = value
			_:
				if _control is MenuButton:
					_set_enum_selection(int(value))

	func _on_value_changed(value: Variant) -> void:
		emit_changed(get_edited_property(), value)

	func _on_resource_changed(value: Resource) -> void:
		emit_changed(get_edited_property(), value)

	func _on_string_name_changed(value: String) -> void:
		emit_changed(get_edited_property(), StringName(value))

	func _on_option_selected(index: int) -> void:
		if index >= 0 and index < _enum_values.size():
			_set_enum_selection(_enum_values[index])
			emit_changed(get_edited_property(), _enum_values[index])
