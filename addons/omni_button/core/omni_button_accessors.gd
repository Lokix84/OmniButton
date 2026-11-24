## the scripting accessors behind button.label, .icon, .background, .panel, .overlay, .cooldown
## and .charge_up. each one just passes through to the button's settings for one part.

## the text settings of an [OmniButton] ([member label]).
class OmniLabelAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member text].
	var text: String:
		get: return _o.text
		set(value): _o.text = value
	## same as [member label_type].
	var type: OmniButton.LabelKind:
		get: return _o.label_type
		set(value): _o.label_type = value
	## same as [member text_modulate].
	var modulate: Color:
		get: return _o.text_modulate
		set(value): _o.text_modulate = value; _o.queue_refresh(false, false, false)
	## same as [member label_font].
	var font: Font:
		get: return _o.label_font
		set(value): _o.label_font = value; _o.queue_refresh(false, false, true)
	## same as [member label_text_color].
	var color: Color:
		get: return _o.label_text_color
		set(value): _o.label_text_color = value; _o.queue_refresh(false, false, false)
	## same as [member text_fit_padding].
	var fit_padding: Vector2:
		get: return _o.text_fit_padding
		set(value): _o.text_fit_padding = value; _o.queue_refresh(false, false, true)
	## same as [member min_font_size].
	var min_font_size: int:
		get: return _o.min_font_size
		set(value): _o.min_font_size = value; _o.queue_refresh(false, false, true)
	## same as [member max_font_size].
	var max_font_size: int:
		get: return _o.max_font_size
		set(value): _o.max_font_size = value; _o.queue_refresh(false, false, true)
	## same as [member fixed_font_size].
	var fixed_font_size: int:
		get: return _o.fixed_font_size
		set(value): _o.fixed_font_size = value; _o.queue_refresh(false, false, true)
	## same as [member enable_text_auto_size].
	var auto_size: bool:
		get: return _o.enable_text_auto_size
		set(value): _o.enable_text_auto_size = value; _o.queue_refresh(false, false, true)
	## same as [member label_horizontal_alignment].
	var h_align: HorizontalAlignment:
		get: return _o.label_horizontal_alignment
		set(value): _o.label_horizontal_alignment = value; _o.queue_refresh(false, false, false)
	## same as [member label_vertical_alignment].
	var v_align: VerticalAlignment:
		get: return _o.label_vertical_alignment
		set(value): _o.label_vertical_alignment = value; _o.queue_refresh(false, false, false)
	## same as [member label_padding].
	var padding: Vector2:
		get: return _o.label_padding
		set(value): _o.label_padding = value; _o.queue_refresh(false, false, true)
	## same as [member label_additional_padding_left].
	var pad_left: float:
		get: return _o.label_additional_padding_left
		set(value): _o.label_additional_padding_left = value; _o.queue_refresh(false, false, true)
	## same as [member label_additional_padding_top].
	var pad_top: float:
		get: return _o.label_additional_padding_top
		set(value): _o.label_additional_padding_top = value; _o.queue_refresh(false, false, true)
	## same as [member label_additional_padding_right].
	var pad_right: float:
		get: return _o.label_additional_padding_right
		set(value): _o.label_additional_padding_right = value; _o.queue_refresh(false, false, true)
	## same as [member label_additional_padding_bottom].
	var pad_bottom: float:
		get: return _o.label_additional_padding_bottom
		set(value): _o.label_additional_padding_bottom = value; _o.queue_refresh(false, false, true)
	## same as [member label_autowrap].
	var autowrap: TextServer.AutowrapMode:
		get: return _o.label_autowrap
		set(value): _o.label_autowrap = value; _o.queue_refresh(false, false, true)

## the icon settings of an [OmniButton] ([member icon]).
class OmniIconAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member icon_texture].
	var tex: Texture2D:
		get: return _o.icon_texture
		set(value): _o.icon_texture = value; _o.queue_refresh(false, false, false)
	## same as [member icon_expand_mode].
	var expand_mode: int:
		get: return _o.icon_expand_mode
		set(value): _o.icon_expand_mode = value; _o.queue_refresh(false, false, false)
	## same as [member icon_stretch_mode].
	var stretch_mode: int:
		get: return _o.icon_stretch_mode
		set(value): _o.icon_stretch_mode = value; _o.queue_refresh(false, false, false)
	## same as [member icon_flip_h].
	var flip_h: bool:
		get: return _o.icon_flip_h
		set(value): _o.icon_flip_h = value; _o.queue_refresh(false, false, false)
	## same as [member icon_flip_v].
	var flip_v: bool:
		get: return _o.icon_flip_v
		set(value): _o.icon_flip_v = value; _o.queue_refresh(false, false, false)
	## same as [member icon_modulate].
	var modulate: Color:
		get: return _o.icon_modulate
		set(value): _o.icon_modulate = value; _o.queue_refresh(false, false, false)

## the background texture settings of an [OmniButton] ([member background]).
class OmniBackgroundAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member background_type].
	var mode: OmniButton.BackgroundMode:
		get: return _o.background_type
		set(value): _o.background_type = value; _o.queue_refresh(true, true, true)
	## same as [member texture].
	var tex: Texture2D:
		get: return _o.texture
		set(value): _o.texture = value; _o.queue_refresh(false, false, false)
	## same as [member expand_mode].
	var expand_mode: int:
		get: return _o.expand_mode
		set(value): _o.expand_mode = value; _o.queue_refresh(false, false, false)
	## same as [member stretch_mode].
	var stretch_mode: int:
		get: return _o.stretch_mode
		set(value): _o.stretch_mode = value; _o.queue_refresh(false, false, false)
	## same as [member flip_h].
	var flip_h: bool:
		get: return _o.flip_h
		set(value): _o.flip_h = value; _o.queue_refresh(false, false, false)
	## same as [member flip_v].
	var flip_v: bool:
		get: return _o.flip_v
		set(value): _o.flip_v = value; _o.queue_refresh(false, false, false)
	## same as [member background_modulate].
	var modulate: Color:
		get: return _o.background_modulate
		set(value): _o.background_modulate = value; _o.queue_refresh(false, false, false)

## the panel style settings of an [OmniButton] ([member panel]).
class OmniPanelAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member panel_modulate].
	var modulate: Color:
		get: return _o.panel_modulate
		set(value): _o.panel_modulate = value; _o.queue_refresh(false, false, false)
	## same as [member panel_theme_variation].
	var theme_variation: String:
		get: return _o.panel_theme_variation
		set(value): _o.panel_theme_variation = value; _o.queue_refresh(false, true, false)
	## same as [member panel_style_box].
	var style_box: StyleBox:
		get: return _o.panel_style_box
		set(value): _o.panel_style_box = value; _o.queue_refresh(false, true, false)

## the cooldown settings of an [OmniButton] ([member cooldown]).
class OmniCooldownAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member cooldown_start_delay].
	var start_delay: float:
		get: return _o.cooldown_start_delay
		set(value): _o.cooldown_start_delay = value
	## same as [member cooldown_duration].
	var duration: float:
		get: return _o.cooldown_duration
		set(value): _o.cooldown_duration = value
	## same as [member cooldown_trigger].
	var trigger: OmniButton.CooldownTrigger:
		get: return _o.cooldown_trigger
		set(value): _o.cooldown_trigger = value
	## same as [member cooldown_start_filled].
	var start_filled: bool:
		get: return _o.cooldown_start_filled
		set(value): _o.cooldown_start_filled = value
	## same as [member cooldown_color].
	var color: Color:
		get: return _o.cooldown_color
		set(value): _o.cooldown_color = value; _o._invalidate_visual_state()
	## same as [member cooldown_fill_direction].
	var direction: int:
		get: return _o.cooldown_fill_direction
		set(value): _o.cooldown_fill_direction = value
	## same as [member invert_on_cooldown].
	var invert_on_cooldown: bool:
		get: return _o.invert_on_cooldown
		set(value): _o.invert_on_cooldown = value; _o._invalidate_visual_state()
	## same as [member cooldown_invert_duration].
	var invert_duration: float:
		get: return _o.cooldown_invert_duration
		set(value): _o.cooldown_invert_duration = value; _o._invalidate_visual_state()
	## same as [member suspend_hover_scale_during_cooldown].
	var suspend_hover_scale: bool:
		get: return _o.suspend_hover_scale_during_cooldown
		set(value): _o.suspend_hover_scale_during_cooldown = value
	## same as [member allow_hold_during_cooldown].
	var allow_hold_during: bool:
		get: return _o.allow_hold_during_cooldown
		set(value): _o.allow_hold_during_cooldown = value
	## same as [member hide_cooldown_during_hold_build_up].
	var hide_during_charge_up: bool:
		get: return _o.hide_cooldown_during_hold_build_up
		set(value): _o.hide_cooldown_during_hold_build_up = value

## the hold settings of an [OmniButton] ([member charge_up]).
class OmniChargeUpAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member hold_duration].
	var duration: float:
		get: return _o.hold_duration
		set(value): _o.hold_duration = value
	## same as [member hold_fill_color].
	var color: Color:
		get: return _o.hold_fill_color
		set(value): _o.hold_fill_color = value; _o._invalidate_visual_state()
	## same as [member hold_fill_direction].
	var direction: int:
		get: return _o.hold_fill_direction
		set(value): _o.hold_fill_direction = value

## the selected overlay settings of an [OmniButton] ([member overlay]).
class OmniOverlayAccessor:
	var _o: OmniButton
	func _init(o: OmniButton) -> void: _o = o
	## same as [member selected].
	var enabled: bool:
		get: return _o.selected
		set(value): _o.selected = value; _o.queue_refresh(false, false, false)
	## same as [member selected_color].
	var color: Color:
		get: return _o.selected_color
		set(value): _o.selected_color = value; _o.queue_refresh(false, false, false)
