class OmniLabelAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var text:
		get: return _o.Text
		set(value): _o.Text = value
	var type:
		get: return _o.LabelType
		set(value): _o.LabelType = value
	var modulate:
		get: return _o.TextModulate
		set(value): _o.TextModulate = value; _o.queue_refresh(false, false, false)
	var font:
		get: return _o.LabelFont
		set(value): _o.LabelFont = value; _o.queue_refresh(false, false, true)
	var color:
		get: return _o.LabelTextColor
		set(value): _o.LabelTextColor = value; _o.queue_refresh(false, false, false)
	var fit_padding:
		get: return _o.TextFitPadding
		set(value): _o.TextFitPadding = value; _o.queue_refresh(false, false, true)
	var min_font_size:
		get: return _o.MinFontSize
		set(value): _o.MinFontSize = value; _o.queue_refresh(false, false, true)
	var max_font_size:
		get: return _o.MaxFontSize
		set(value): _o.MaxFontSize = value; _o.queue_refresh(false, false, true)
	var fixed_font_size:
		get: return _o.FixedFontSize
		set(value): _o.FixedFontSize = value; _o.queue_refresh(false, false, true)
	var auto_size:
		get: return _o.EnableTextAutoSize
		set(value): _o.EnableTextAutoSize = value; _o.queue_refresh(false, false, true)
	var h_align:
		get: return _o.LabelHorizontalAlignment
		set(value): _o.LabelHorizontalAlignment = value; _o.queue_refresh(false, false, false)
	var v_align:
		get: return _o.LabelVerticalAlignment
		set(value): _o.LabelVerticalAlignment = value; _o.queue_refresh(false, false, false)
	var padding:
		get: return _o.LabelPadding
		set(value): _o.LabelPadding = value; _o.queue_refresh(false, false, true)
	var pad_left:
		get: return _o.LabelAdditionalPaddingLeft
		set(value): _o.LabelAdditionalPaddingLeft = value; _o.queue_refresh(false, false, true)
	var pad_top:
		get: return _o.LabelAdditionalPaddingTop
		set(value): _o.LabelAdditionalPaddingTop = value; _o.queue_refresh(false, false, true)
	var pad_right:
		get: return _o.LabelAdditionalPaddingRight
		set(value): _o.LabelAdditionalPaddingRight = value; _o.queue_refresh(false, false, true)
	var pad_bottom:
		get: return _o.LabelAdditionalPaddingBottom
		set(value): _o.LabelAdditionalPaddingBottom = value; _o.queue_refresh(false, false, true)
	var autowrap:
		get: return _o.LabelAutowrap
		set(value): _o.LabelAutowrap = value; _o.queue_refresh(false, false, true)

class OmniIconAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var tex:
		get: return _o.IconTexture
		set(value): _o.IconTexture = value; _o.queue_refresh(false, false, false)
	var expand_mode:
		get: return _o.IconExpandMode
		set(value): _o.IconExpandMode = value; _o.queue_refresh(false, false, false)
	var stretch_mode:
		get: return _o.IconStretchMode
		set(value): _o.IconStretchMode = value; _o.queue_refresh(false, false, false)
	var flip_h:
		get: return _o.IconFlipH
		set(value): _o.IconFlipH = value; _o.queue_refresh(false, false, false)
	var flip_v:
		get: return _o.IconFlipV
		set(value): _o.IconFlipV = value; _o.queue_refresh(false, false, false)
	var modulate:
		get: return _o.IconModulate
		set(value): _o.IconModulate = value; _o.queue_refresh(false, false, false)

class OmniBackgroundAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var mode:
		get: return _o.BackgroundType
		set(value): _o.BackgroundType = value; _o.queue_refresh(true, true, true)
	var tex:
		get: return _o.BackgroundTexture
		set(value): _o.BackgroundTexture = value; _o.queue_refresh(false, false, false)
	var expand_mode:
		get: return _o.BackgroundExpandMode
		set(value): _o.BackgroundExpandMode = value; _o.queue_refresh(false, false, false)
	var stretch_mode:
		get: return _o.BackgroundStretchMode
		set(value): _o.BackgroundStretchMode = value; _o.queue_refresh(false, false, false)
	var flip_h:
		get: return _o.BackgroundFlipH
		set(value): _o.BackgroundFlipH = value; _o.queue_refresh(false, false, false)
	var flip_v:
		get: return _o.BackgroundFlipV
		set(value): _o.BackgroundFlipV = value; _o.queue_refresh(false, false, false)
	var modulate:
		get: return _o.BackgroundModulate
		set(value): _o.BackgroundModulate = value; _o.queue_refresh(false, false, false)

class OmniPanelAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var modulate:
		get: return _o.PanelModulate
		set(value): _o.PanelModulate = value; _o.queue_refresh(false, false, false)
	var theme_variation:
		get: return _o.PanelThemeVariation
		set(value): _o.PanelThemeVariation = value; _o.queue_refresh(false, true, false)
	var style_box:
		get: return _o.PanelStyleBox
		set(value): _o.PanelStyleBox = value; _o.queue_refresh(false, true, false)

class OmniCooldownAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.EnableCooldown
		set(value): _o.EnableCooldown = value; _o._invalidate_visual_state()
	var start_delay:
		get: return _o.CooldownStartDelay
		set(value): _o.CooldownStartDelay = value
	var duration:
		get: return _o.CooldownDuration
		set(value): _o.CooldownDuration = value
	var trigger:
		get: return _o.CooldownTrigger
		set(value): _o.CooldownTrigger = value
	var start_filled:
		get: return _o.CooldownStartFilled
		set(value): _o.CooldownStartFilled = value
	var color:
		get: return _o.CooldownColor
		set(value): _o.CooldownColor = value; _o._invalidate_visual_state()
	var direction:
		get: return _o.CooldownFillDirection
		set(value): _o.CooldownFillDirection = value
	var invert_on_cooldown:
		get: return _o.InvertOnCooldown
		set(value): _o.InvertOnCooldown = value; _o._invalidate_visual_state()
	var invert_duration:
		get: return _o.CooldownInvertDuration
		set(value): _o.CooldownInvertDuration = value; _o._invalidate_visual_state()
	var suspend_hover_scale:
		get: return _o.SuspendHoverScaleDuringCooldown
		set(value): _o.SuspendHoverScaleDuringCooldown = value
	var allow_hold_during:
		get: return _o.AllowHoldDuringCooldown
		set(value): _o.AllowHoldDuringCooldown = value
	var hide_during_charge_up:
		get: return _o.HideCooldownDuringHoldBuildUp
		set(value): _o.HideCooldownDuringHoldBuildUp = value

class OmniChargeUpAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.EnableHoldBuildUp
		set(value): _o.EnableHoldBuildUp = value; _o._invalidate_visual_state()
	var duration:
		get: return _o.HoldDuration
		set(value): _o.HoldDuration = value
	var color:
		get: return _o.HoldFillColor
		set(value): _o.HoldFillColor = value; _o._invalidate_visual_state()
	var direction:
		get: return _o.HoldFillDirection
		set(value): _o.HoldFillDirection = value

class OmniOverlayAccessor:
	var _o: Omni_Button
	func _init(o): _o = o
	var enabled:
		get: return _o.Selected
		set(value): _o.Selected = value; _o.queue_refresh(false, false, false)
	var color:
		get: return _o.SelectedColor
		set(value): _o.SelectedColor = value; _o.queue_refresh(false, false, false)
