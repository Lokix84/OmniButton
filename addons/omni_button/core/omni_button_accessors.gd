## Scripting accessors behind button.label, .icon, .background, .panel, .overlay, .cooldown and
## .charge_up. Each forwards to the button's settings for one visual part.

## Text settings of an [Omni_Button] ([member Omni_Button.label]).
class OmniLabelAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.Text].
	var text: String:
		get: return _o.Text
		set(value): _o.Text = value
	## Same as [member Omni_Button.LabelType].
	var type: Omni_Button.LabelKind:
		get: return _o.LabelType
		set(value): _o.LabelType = value
	## Same as [member Omni_Button.TextModulate].
	var modulate: Color:
		get: return _o.TextModulate
		set(value): _o.TextModulate = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.LabelFont].
	var font: Font:
		get: return _o.LabelFont
		set(value): _o.LabelFont = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelTextColor].
	var color: Color:
		get: return _o.LabelTextColor
		set(value): _o.LabelTextColor = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.TextFitPadding].
	var fit_padding: Vector2:
		get: return _o.TextFitPadding
		set(value): _o.TextFitPadding = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.MinFontSize].
	var min_font_size: int:
		get: return _o.MinFontSize
		set(value): _o.MinFontSize = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.MaxFontSize].
	var max_font_size: int:
		get: return _o.MaxFontSize
		set(value): _o.MaxFontSize = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.FixedFontSize].
	var fixed_font_size: int:
		get: return _o.FixedFontSize
		set(value): _o.FixedFontSize = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.EnableTextAutoSize].
	var auto_size: bool:
		get: return _o.EnableTextAutoSize
		set(value): _o.EnableTextAutoSize = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelHorizontalAlignment].
	var h_align: HorizontalAlignment:
		get: return _o.LabelHorizontalAlignment
		set(value): _o.LabelHorizontalAlignment = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.LabelVerticalAlignment].
	var v_align: VerticalAlignment:
		get: return _o.LabelVerticalAlignment
		set(value): _o.LabelVerticalAlignment = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.LabelPadding].
	var padding: Vector2:
		get: return _o.LabelPadding
		set(value): _o.LabelPadding = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelAdditionalPaddingLeft].
	var pad_left: float:
		get: return _o.LabelAdditionalPaddingLeft
		set(value): _o.LabelAdditionalPaddingLeft = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelAdditionalPaddingTop].
	var pad_top: float:
		get: return _o.LabelAdditionalPaddingTop
		set(value): _o.LabelAdditionalPaddingTop = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelAdditionalPaddingRight].
	var pad_right: float:
		get: return _o.LabelAdditionalPaddingRight
		set(value): _o.LabelAdditionalPaddingRight = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelAdditionalPaddingBottom].
	var pad_bottom: float:
		get: return _o.LabelAdditionalPaddingBottom
		set(value): _o.LabelAdditionalPaddingBottom = value; _o.queue_refresh(false, false, true)
	## Same as [member Omni_Button.LabelAutowrap].
	var autowrap: TextServer.AutowrapMode:
		get: return _o.LabelAutowrap
		set(value): _o.LabelAutowrap = value; _o.queue_refresh(false, false, true)

## Icon settings of an [Omni_Button] ([member Omni_Button.icon]).
class OmniIconAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.IconTexture].
	var tex: Texture2D:
		get: return _o.IconTexture
		set(value): _o.IconTexture = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.IconExpandMode].
	var expand_mode: int:
		get: return _o.IconExpandMode
		set(value): _o.IconExpandMode = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.IconStretchMode].
	var stretch_mode: int:
		get: return _o.IconStretchMode
		set(value): _o.IconStretchMode = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.IconFlipH].
	var flip_h: bool:
		get: return _o.IconFlipH
		set(value): _o.IconFlipH = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.IconFlipV].
	var flip_v: bool:
		get: return _o.IconFlipV
		set(value): _o.IconFlipV = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.IconModulate].
	var modulate: Color:
		get: return _o.IconModulate
		set(value): _o.IconModulate = value; _o.queue_refresh(false, false, false)

## Background texture settings of an [Omni_Button] ([member Omni_Button.background]).
class OmniBackgroundAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.BackgroundType].
	var mode: Omni_Button.BackgroundMode:
		get: return _o.BackgroundType
		set(value): _o.BackgroundType = value; _o.queue_refresh(true, true, true)
	## Same as [member Omni_Button.texture].
	var tex: Texture2D:
		get: return _o.texture
		set(value): _o.texture = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.expand_mode].
	var expand_mode: int:
		get: return _o.expand_mode
		set(value): _o.expand_mode = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.stretch_mode].
	var stretch_mode: int:
		get: return _o.stretch_mode
		set(value): _o.stretch_mode = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.flip_h].
	var flip_h: bool:
		get: return _o.flip_h
		set(value): _o.flip_h = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.flip_v].
	var flip_v: bool:
		get: return _o.flip_v
		set(value): _o.flip_v = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.BackgroundModulate].
	var modulate: Color:
		get: return _o.BackgroundModulate
		set(value): _o.BackgroundModulate = value; _o.queue_refresh(false, false, false)

## Panel style settings of an [Omni_Button] ([member Omni_Button.panel]).
class OmniPanelAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.PanelModulate].
	var modulate: Color:
		get: return _o.PanelModulate
		set(value): _o.PanelModulate = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.PanelThemeVariation].
	var theme_variation: String:
		get: return _o.PanelThemeVariation
		set(value): _o.PanelThemeVariation = value; _o.queue_refresh(false, true, false)
	## Same as [member Omni_Button.PanelStyleBox].
	var style_box: StyleBox:
		get: return _o.PanelStyleBox
		set(value): _o.PanelStyleBox = value; _o.queue_refresh(false, true, false)

## Cooldown settings of an [Omni_Button] ([member Omni_Button.cooldown]).
class OmniCooldownAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.CooldownStartDelay].
	var start_delay: float:
		get: return _o.CooldownStartDelay
		set(value): _o.CooldownStartDelay = value
	## Same as [member Omni_Button.CooldownDuration].
	var duration: float:
		get: return _o.CooldownDuration
		set(value): _o.CooldownDuration = value
	## Same as [member Omni_Button.CooldownTrigger].
	var trigger: Omni_Button.CooldownTriggerEnum:
		get: return _o.CooldownTrigger
		set(value): _o.CooldownTrigger = value
	## Same as [member Omni_Button.CooldownStartFilled].
	var start_filled: bool:
		get: return _o.CooldownStartFilled
		set(value): _o.CooldownStartFilled = value
	## Same as [member Omni_Button.CooldownColor].
	var color: Color:
		get: return _o.CooldownColor
		set(value): _o.CooldownColor = value; _o._invalidate_visual_state()
	## Same as [member Omni_Button.CooldownFillDirection].
	var direction: int:
		get: return _o.CooldownFillDirection
		set(value): _o.CooldownFillDirection = value
	## Same as [member Omni_Button.InvertOnCooldown].
	var invert_on_cooldown: bool:
		get: return _o.InvertOnCooldown
		set(value): _o.InvertOnCooldown = value; _o._invalidate_visual_state()
	## Same as [member Omni_Button.CooldownInvertDuration].
	var invert_duration: float:
		get: return _o.CooldownInvertDuration
		set(value): _o.CooldownInvertDuration = value; _o._invalidate_visual_state()
	## Same as [member Omni_Button.SuspendHoverScaleDuringCooldown].
	var suspend_hover_scale: bool:
		get: return _o.SuspendHoverScaleDuringCooldown
		set(value): _o.SuspendHoverScaleDuringCooldown = value
	## Same as [member Omni_Button.AllowHoldDuringCooldown].
	var allow_hold_during: bool:
		get: return _o.AllowHoldDuringCooldown
		set(value): _o.AllowHoldDuringCooldown = value
	## Same as [member Omni_Button.HideCooldownDuringHoldBuildUp].
	var hide_during_charge_up: bool:
		get: return _o.HideCooldownDuringHoldBuildUp
		set(value): _o.HideCooldownDuringHoldBuildUp = value

## Hold build-up settings of an [Omni_Button] ([member Omni_Button.charge_up]).
class OmniChargeUpAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.HoldDuration].
	var duration: float:
		get: return _o.HoldDuration
		set(value): _o.HoldDuration = value
	## Same as [member Omni_Button.HoldFillColor].
	var color: Color:
		get: return _o.HoldFillColor
		set(value): _o.HoldFillColor = value; _o._invalidate_visual_state()
	## Same as [member Omni_Button.HoldFillDirection].
	var direction: int:
		get: return _o.HoldFillDirection
		set(value): _o.HoldFillDirection = value

## Selection overlay settings of an [Omni_Button] ([member Omni_Button.overlay]).
class OmniOverlayAccessor:
	var _o: Omni_Button
	func _init(o: Omni_Button) -> void: _o = o
	## Same as [member Omni_Button.Selected].
	var enabled: bool:
		get: return _o.Selected
		set(value): _o.Selected = value; _o.queue_refresh(false, false, false)
	## Same as [member Omni_Button.SelectedColor].
	var color: Color:
		get: return _o.SelectedColor
		set(value): _o.SelectedColor = value; _o.queue_refresh(false, false, false)
