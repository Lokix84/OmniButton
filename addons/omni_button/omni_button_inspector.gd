@tool
extends EditorInspectorPlugin
## Inspector plugin: friendly labels, tooltips and custom editors for Omni_Button properties.

const ACTION_TOOLTIPS := {
	"EnablePressedActions": "Emits the Pressed signal and runs its connected action when this button is pressed.",
	"EnableReleasedActions": "Emits the Released signal and runs its connected action when this button is released.",
	"EnableHoverActions": "Emits HoverIn and HoverOut and runs their connected actions as the pointer enters or leaves.",
	"EnableToggleActions": "Emits Toggled and runs its connected action when the button changes toggle state.",
	"EnableHoldActions": "Emits Hold and runs its connected action when the configured hold duration completes.",
	"EnableSwipeActions": "Emits Swipe and SwipeEnded and runs their connected actions for recognized swipe gestures.",
	"EnableLogActions": "Enables the Log signal and connected action for messages sent through this button.",
	"EnableWarningActions": "Enables the Warning signal and connected action for warnings sent through this button.",
	"EnableErrorActions": "Enables the Error signal and connected action for errors sent through this button.",
}

const PROPERTY_LABELS := {
	"EnablePressedActions": "Press",
	"EnableReleasedActions": "Release",
	"EnableHoverActions": "Hover",
	"EnableToggleActions": "Toggle",
	"EnableHoldActions": "Hold",
	"EnableSwipeActions": "Swipe",
	"EnableLogActions": "Log",
	"EnableWarningActions": "Warning",
	"EnableErrorActions": "Error",
	"BackgroundType": "Background Type",
	"LabelType": "Label Type",
	"Disabled": "Disabled",
	"InvertModes": "Invert Modes",
	"HoverScale": "Scale",
	"HoverLerpSpeed": "Lerp Speed",
	"SelectedColor": "Selected Color",
	"ActivationAction": "InFocus Action",
	"BoundsSource": "Bounds Source",
	"HitSlop": "Hit Slop",
	"ClampToBounds": "Clamp To Bounds",
	"FollowMode": "Follow Mode",
	"ClampShape": "Clamp Shape",
	"JoystickRadiusPx": "Joystick Radius Px",
	"JoystickRectSizePx": "Joystick Rect Size Px",
	"JoystickDeadzone": "Joystick Deadzone",
	"JoystickSnapToInput": "Joystick Snap To Input",
	"JoystickHideWhenInactive": "Joystick Hide When Inactive",
	"JoystickResetOnRelease": "Joystick Reset On Release",
	"EnableJoystickArea": "Enable Joystick Area",
	"JoystickAreaPersistent": "Joystick Area Persistent",
	"JoystickAreaColor": "Joystick Area Color",
	"JoystickAreaThickness": "Joystick Area Thickness",
	"JoystickAreaUseRectForClamp": "Joystick Area Use Rect For Clamp",
	"JoystickAreaExternalPath": "Joystick Area External Path",
	"EnableDefaultThumb": "Enable Default Thumb",
	"DefaultThumbSizeRatio": "Default Thumb Size Ratio",
	"DefaultThumbColor": "Default Thumb Color",
	"IconTexture": "Texture",
	"IconExpandMode": "Expand",
	"IconStretchMode": "Stretch",
	"IconFlipH": "Flip H",
	"IconFlipV": "Flip V",
	"IconModulate": "Modulate",
	"HoldDuration": "Duration",
	"HoldFillColor": "Fill Color",
	"HoldFillDirection": "Fill Direction",
	"SwipeThreshold": "Threshold",
	"TouchSwipeInit": "Touch Init",
	"TouchSwipeExit": "Touch Exit",
	"MouseSwipeInit": "Mouse Init",
	"MouseSwipeExit": "Mouse Exit",
	"InteractionMode": "Interaction Mode",
	"CooldownTrigger": "Trigger",
	"CooldownStartDelay": "Start Delay",
	"CooldownDuration": "Duration",
	"CooldownStartFilled": "Start Filled",
	"CooldownColor": "Color",
	"CooldownFillDirection": "Fill Direction",
	"InvertOnCooldown": "Invert During",
	"CooldownInvertDuration": "Invert Delay",
	"SuspendHoverScaleDuringCooldown": "Stop Hover Scale",
	"AllowHoldDuringCooldown": "Allow Hold During Cooldown",
	"HideCooldownDuringHoldBuildUp": "Hide During Buildup",
	"Text": "Text",
	"LabelUppercase": "Uppercase",
	"LabelClipText": "Clip",
	"LabelTextOverrun": "Overrun",
	"LabelFont": "Font",
	"LabelTextColor": "Color",
	"TextModulate": "Modulate",
	"LabelHorizontalAlignment": "Horizontal",
	"LabelVerticalAlignment": "Vertical",
	"LabelAutowrap": "Autowrap",
	"RichLabelUseBBCode": "Rich Label Use BB Code",
	"RichTextFitContent": "Rich Text Fit Content",
	"RichTextScrollActive": "Rich Text Scroll Active",
	"RichTextScrollFollowing": "Rich Text Scroll Following",
	"RichTextSelectionEnabled": "Rich Text Selection Enabled",
	"RichTextContextMenuEnabled": "Rich Text Context Menu Enabled",
	"TextFitPadding": "Text Fit Padding",
	"MinFontSize": "Min Font Size",
	"MaxFontSize": "Max Font Size",
	"FixedFontSize": "Fixed Font Size",
	"EnableTextAutoSize": "Enable Text Auto Size",
	"LabelPadding": "Label Padding",
	"LabelAdditionalPaddingLeft": "Left",
	"LabelAdditionalPaddingTop": "Top",
	"LabelAdditionalPaddingRight": "Right",
	"LabelAdditionalPaddingBottom": "Bottom",
	"TextToType": "Text To Type",
	"SuspendHoverDuringTypewriter": "Suspend Hover During Typewriter",
	"DelayEffectTagsDuringTypewriter": "Delay Effect Tags During Typewriter",
	"FinishTypewriterOnPress": "Finish Typewriter On Press",
	"PanelThemeVariation": "Panel Theme Variation",
	"PanelStyleBox": "Panel Style Box",
	"PanelHoverStyleBox": "Panel Hover Style Box",
	"PanelPressedStyleBox": "Panel Pressed Style Box",
	"PanelDisabledStyleBox": "Panel Disabled Style Box",
	"PanelFocusStyleBox": "Panel Focus Style Box",
	"PanelModulate": "Panel Modulate",
	"texture": "Texture",
	"expand_mode": "Expand",
	"stretch_mode": "Stretch",
	"flip_h": "Flip H",
	"flip_v": "Flip V",
	"BackgroundModulate": "Background Modulate",
	"ManagedDrawOnTop": "Managed Draw On Top",
	"Selected": "Selected",
	"IsToggled": "Is Toggled",
	"IsPressed": "Is Pressed",
	"IsHovering": "Is Hovering",
	"IsHolding": "Is Holding",
	"DebuggerLog": "Debugger Log",
}

const CUSTOM_PROPERTY_EDITORS := {
	"ActivationAction": true,
	"LabelFont": true,
	"LabelTextColor": true,
	"TextModulate": true,
	"LabelHorizontalAlignment": true,
	"LabelVerticalAlignment": true,
	"LabelAutowrap": true,
	"LabelUppercase": true,
	"LabelClipText": true,
	"LabelTextOverrun": true,
	"LabelAdditionalPaddingLeft": true,
	"LabelAdditionalPaddingTop": true,
	"LabelAdditionalPaddingRight": true,
	"LabelAdditionalPaddingBottom": true,
	"HoverScale": true,
	"HoverLerpSpeed": true,
	"IconTexture": true,
	"IconExpandMode": true,
	"IconStretchMode": true,
	"IconFlipH": true,
	"IconFlipV": true,
	"IconModulate": true,
	"HoldDuration": true,
	"HoldFillColor": true,
	"HoldFillDirection": true,
	"SwipeThreshold": true,
	"TouchSwipeInit": true,
	"TouchSwipeExit": true,
	"MouseSwipeInit": true,
	"MouseSwipeExit": true,
	"CooldownTrigger": true,
	"CooldownStartDelay": true,
	"CooldownDuration": true,
	"CooldownStartFilled": true,
	"CooldownColor": true,
	"CooldownFillDirection": true,
	"InvertOnCooldown": true,
	"CooldownInvertDuration": true,
	"SuspendHoverScaleDuringCooldown": true,
	"HideCooldownDuringHoldBuildUp": true,
}

const PROPERTY_TOOLTIPS := {
	"BackgroundType": "None draws no generated background; UsePanel draws a styled Panel; UseTexture draws a TextureRect background.",
	"LabelType": "None creates no text node; Label uses plain text; RichTextLabel supports BBCode and rich text behavior.",
	"LabelFont": "Font resource used to draw button text.",
	"LabelTextColor": "Base color used to draw the button text.",
	"TextModulate": "Additional color modulation applied to the text.",
	"LabelHorizontalAlignment": "Horizontal alignment of the text inside its label.",
	"LabelVerticalAlignment": "Vertical alignment of the text inside its label.",
	"LabelAutowrap": "Off never wraps; Arbitrary wraps anywhere; Word wraps at word boundaries; Smart favors word boundaries but can break long words.",
	"LabelUppercase": "Displays plain Label text in uppercase without changing the Text property.",
	"LabelClipText": "Clips plain Label text at the label boundary.",
	"LabelTextOverrun": "None keeps text unchanged; Trim Character/Word removes overflow; Ellipsis adds an ellipsis; Trim Word with Ellipsis trims at a word boundary and adds an ellipsis.",
	"LabelAdditionalPaddingLeft": "Additional left-side space excluded from the label text area.",
	"LabelAdditionalPaddingTop": "Additional top-side space excluded from the label text area.",
	"LabelAdditionalPaddingRight": "Additional right-side space excluded from the label text area.",
	"LabelAdditionalPaddingBottom": "Additional bottom-side space excluded from the label text area.",
	"InteractionMode": "Momentary is pressed only while held; Toggle On Press switches state on press; Toggle On Release switches state on release.",
	"HoverScale": "Extra scale applied while hovered. Zero disables hover scaling; positive values enable it.",
	"HoverLerpSpeed": "Speed at which the hover scale transitions between normal and hovered size.",
	"IconTexture": "Texture displayed in the icon layer, behind the button text.",
	"IconExpandMode": "Keep Size uses the texture's native dimensions; Ignore Size ignores its minimum size; Fit Width/Height constrain that dimension, with Proportional variants preserving aspect ratio.",
	"IconStretchMode": "Chooses scaling, tiling, native-size placement, centering, or aspect-preserving fit/cover behavior for the icon.",
	"IconFlipH": "Mirrors the icon texture horizontally.",
	"IconFlipV": "Mirrors the icon texture vertically.",
	"IconModulate": "Multiplies the icon texture colors by this color.",
	"HoldDuration": "Time the button must remain pressed before the Hold action fires. Zero disables hold build-up.",
	"HoldFillColor": "Color of the progress fill shown while the button is building up a hold.",
	"HoldFillDirection": "Direction the hold progress fill advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.",
	"SwipeThreshold": "Minimum pointer travel in pixels required to recognize a swipe.",
	"TouchSwipeInit": "OnHoverIn begins touch swipe tracking on pointer entry; OnPressed begins tracking on touch press.",
	"TouchSwipeExit": "OnHoverOut ends touch swipe tracking when leaving the bounds; OnReleased ends it when the touch is released.",
	"MouseSwipeInit": "OnHoverIn begins mouse swipe tracking on pointer entry; OnPressed begins tracking on mouse press.",
	"MouseSwipeExit": "OnHoverOut ends mouse swipe tracking when leaving the bounds; OnReleased ends it when the mouse button is released.",
	"CooldownTrigger": "None disables cooldown; OnPress starts it on press; OnRelease starts it on release; OnPressAndRelease starts it on both events.",
	"FollowMode": "None stays in place; FollowBoth moves with the pointer; VirtualJoystick emits joystick axes while the pointer moves within its clamp area.",
	"ClampShape": "Circle constrains movement to a radius; Rectangle constrains movement to the configured width and height.",
	"DebuggerLog": "Writes per-button diagnostic messages to the output: Off disables logging; Basic enables it.",
	"ActivationAction": "InputMap action that activates this button while it has keyboard focus. Set to empty to disable focused input; player remapping is handled through InputMap.",
	"CooldownStartDelay": "Wait time after the selected trigger before the cooldown fill begins.",
	"CooldownDuration": "Time the cooldown remains active after its start delay.",
	"CooldownStartFilled": "Shows the cooldown fill as full at the start and drains it, instead of filling from empty.",
	"CooldownColor": "Color of the cooldown overlay.",
	"CooldownFillDirection": "Direction the cooldown overlay advances: 0 bottom-to-top, 1 top-to-bottom, 2 left-to-right, 3 right-to-left.",
	"InvertOnCooldown": "Inverts the button colors while cooldown is active.",
	"CooldownInvertDuration": "Duration of the cooldown color-inversion transition. Zero applies it immediately.",
	"SuspendHoverScaleDuringCooldown": "Temporarily returns the button to normal scale while cooldown is active.",
	"AllowHoldDuringCooldown": "Allows hold build-up while cooldown is active.",
	"HideCooldownDuringHoldBuildUp": "Hides the cooldown overlay while hold build-up is visible.",
}

const OPTION_TOOLTIPS := {
	"Keep Size": "Uses the icon texture's native size.",
	"Ignore Size": "Ignores the icon texture's minimum size when laying out the TextureRect.",
	"Fit Width": "Fits the icon to the available width.",
	"Fit Width Proportional": "Fits to the available width while preserving aspect ratio.",
	"Fit Height": "Fits the icon to the available height.",
	"Fit Height Proportional": "Fits to the available height while preserving aspect ratio.",
	"Scale": "Stretches the texture to fill the rectangle.",
	"Tile": "Repeats the texture at its native size.",
	"Keep": "Draws at native size from the rectangle's top-left corner.",
	"Keep Centered": "Draws at native size centered in the rectangle.",
	"Keep Aspect": "Fits inside the rectangle while preserving aspect ratio.",
	"Keep Aspect Centered": "Fits inside and centers while preserving aspect ratio.",
	"Keep Aspect Covered": "Covers the rectangle while preserving aspect ratio; some texture may be cropped.",
	"OnHoverIn": "Begins tracking when the pointer enters the button bounds.",
	"OnPressed": "Begins tracking when the pointer press starts.",
	"OnHoverOut": "Ends tracking when the pointer leaves the button bounds.",
	"OnReleased": "Ends tracking when the pointer is released.",
	"None": "Disables cooldown.",
	"OnPress": "Starts cooldown when the button is pressed.",
	"OnRelease": "Starts cooldown when the button is released.",
	"OnPressAndRelease": "Starts cooldown on both press and release.",
	"UsePanel": "Draws a styled Panel as the button background.",
	"UseTexture": "Draws a TextureRect as the button background.",
	"Label": "Creates a plain text Label.",
	"RichTextLabel": "Creates a RichTextLabel with optional BBCode and rich text behavior.",
	"Momentary": "The button is pressed only while the pointer is held down.",
	"ToggleOnPress": "Switches the toggle state each time the pointer presses the button.",
	"ToggleOnRelease": "Switches the toggle state each time the pointer releases the button.",
	"FollowBoth": "Moves the button with the pointer while it is pressed.",
	"VirtualJoystick": "Emits joystick axes while the pointer moves within the configured clamp area.",
	"Circle": "Constrains joystick movement to a circular radius.",
	"Rectangle": "Constrains joystick movement to a rectangular area.",
	"Off": "Disables text wrapping.",
	"Arbitrary": "Wraps text at any character when it reaches the label boundary.",
	"Word": "Wraps text at word boundaries.",
	"Word (Smart)": "Prefers word boundaries but can break long words when necessary.",
	"Trim Character": "Removes overflowing characters one at a time.",
	"Trim Word": "Removes overflowing text up to a word boundary.",
	"Ellipsis": "Replaces overflowing text with an ellipsis.",
	"Trim Word with Ellipsis": "Trims at a word boundary and adds an ellipsis.",
}

func _can_handle(object: Object) -> bool:
	return object is Omni_Button

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
			"HoverScale", "HoverLerpSpeed", "HoldDuration", "SwipeThreshold", "CooldownStartDelay", "CooldownDuration", "CooldownInvertDuration", "LabelAdditionalPaddingLeft", "LabelAdditionalPaddingTop", "LabelAdditionalPaddingRight", "LabelAdditionalPaddingBottom":
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
			"IconTexture", "LabelFont":
				var picker := EditorResourcePicker.new()
				picker.base_type = "Texture2D" if property_name == "IconTexture" else "Font"
				picker.resource_changed.connect(_on_resource_changed)
				_control = picker
			"ActivationAction":
				var line_edit := LineEdit.new()
				line_edit.text_changed.connect(_on_string_name_changed)
				_control = line_edit
			"IconExpandMode", "IconStretchMode", "TouchSwipeInit", "TouchSwipeExit", "MouseSwipeInit", "MouseSwipeExit", "CooldownTrigger":
				_control = _create_enum_editor(hint_string, property_name)
			"IconFlipH", "IconFlipV", "CooldownStartFilled", "InvertOnCooldown", "SuspendHoverScaleDuringCooldown", "HideCooldownDuringHoldBuildUp", "LabelUppercase", "LabelClipText":
				var checkbox := CheckBox.new()
				checkbox.toggled.connect(_on_value_changed)
				_control = checkbox
			"IconModulate", "HoldFillColor", "CooldownColor", "LabelTextColor", "TextModulate":
				var color_picker := ColorPickerButton.new()
				color_picker.color_changed.connect(_on_value_changed)
				_control = color_picker
			"HoldFillDirection", "CooldownFillDirection":
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
			popup.add_item(option, index)
			popup.set_item_tooltip(index, _enum_option_tooltip(option, property_name))
			_enum_values.append(value)
			_enum_option_texts.append(option)
		popup.id_pressed.connect(_on_option_selected)
		return menu_button

	func _enum_option_tooltip(option: String, property_name: String) -> String:
		if property_name == "LabelTextOverrun" and option == "None":
			return "Keeps overflowing text unchanged."
		return String(OPTION_TOOLTIPS.get(option, ""))

	func _enum_display_text(option: String, property_name: String) -> String:
		var display := option
		if property_name == "LabelHorizontalAlignment":
			display = display.trim_prefix("Horizontal Alignment ")
		elif property_name == "LabelVerticalAlignment":
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
			"HoverScale", "HoverLerpSpeed", "HoldDuration", "SwipeThreshold", "CooldownStartDelay", "CooldownDuration", "CooldownInvertDuration", "HoldFillDirection", "CooldownFillDirection", "LabelAdditionalPaddingLeft", "LabelAdditionalPaddingTop", "LabelAdditionalPaddingRight", "LabelAdditionalPaddingBottom":
				(_control as EditorSpinSlider).set_value_no_signal(float(value))
			"IconTexture", "LabelFont":
				(_control as EditorResourcePicker).edited_resource = value
			"ActivationAction":
				var line_edit := _control as LineEdit
				var text := String(value)
				if line_edit.text != text:
					line_edit.text = text
			"IconExpandMode", "IconStretchMode", "TouchSwipeInit", "TouchSwipeExit", "MouseSwipeInit", "MouseSwipeExit", "CooldownTrigger", "LabelHorizontalAlignment", "LabelVerticalAlignment", "LabelAutowrap", "LabelTextOverrun":
				_set_enum_selection(int(value))
			"IconFlipH", "IconFlipV", "CooldownStartFilled", "InvertOnCooldown", "SuspendHoverScaleDuringCooldown", "HideCooldownDuringHoldBuildUp", "LabelUppercase", "LabelClipText":
				(_control as CheckBox).set_pressed_no_signal(bool(value))
			"IconModulate", "HoldFillColor", "CooldownColor", "LabelTextColor", "TextModulate":
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
