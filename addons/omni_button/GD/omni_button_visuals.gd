extends RefCounted
class_name OmniButtonVisuals

const _MANAGED_CHILD_NAMES := {
	"Panel": true,
	"Background": true,
	"Icon": true,
	"Label": true,
	"RichLabel": true,
	"Overlay": true,
	"HoldFill": true,
	"Cooldown": true,
	"DefaultThumb": true,
	"JoystickArea": true
}

var _o: Omni_Button

func _init(o: Omni_Button) -> void:
	_o = o

func setup_children() -> void:
	# In editor, duplicated nodes may carry serialized managed children (Icon/Label/etc.)
	# which causes stacked visuals when properties change. Proactively purge any
	# pre-existing managed children by name so we rebuild a single correct set.
	var purge_children := func(parent: Node) -> void:
		if parent == null or not is_instance_valid(parent):
			return
		for child in parent.get_children():
			if child is Node and _MANAGED_CHILD_NAMES.has(child.name):
				parent.remove_child(child)
				child.queue_free()
	purge_children.call(_o)
	if _o._managed_root != null and is_instance_valid(_o._managed_root):
		purge_children.call(_o._managed_root)

	# Free only managed nodes; leave user-added children intact
	for n in [_o._panel, _o._background_tex, _o._icon, _o._label, _o._rich_label, _o._overlay, _o._cooldown, _o._hold_fill, _o._default_thumb, _o._vj_area_panel]:
		if n != null and is_instance_valid(n):
			var p = n.get_parent()
			if p == _o or (p != null and is_instance_valid(p) and p == _o._managed_root):
				p.remove_child(n)
			n.queue_free()
	_o._panel = null
	_o._background_tex = null
	_o._icon = null
	_o._label = null
	_o._rich_label = null
	_o._overlay = null
	_o._cooldown = null
	_o._hold_fill = null
	_o._default_thumb = null
	_o._vj_area_panel = null

	if _o.BackgroundType == Omni_Button.BackgroundMode.UsePanel:
		_o._panel = Panel.new()
		_o._panel.name = "Panel"
		_o._managed_add_child(_o._panel)
		_o._ensure_full_rect(_o._panel)
		apply_panel_styling()

	if _o.BackgroundType == Omni_Button.BackgroundMode.UseTexture and _o.BackgroundTexture != null:
		_o._background_tex = TextureRect.new()
		_o._background_tex.name = "Background"
		_o._background_tex.texture = _o.BackgroundTexture
		_o._background_tex.expand_mode = _o.BackgroundExpandMode
		_o._background_tex.stretch_mode = _o.BackgroundStretchMode
		_o._background_tex.flip_h = _o.BackgroundFlipH
		_o._background_tex.flip_v = _o.BackgroundFlipV
		_o._background_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_o._managed_add_child(_o._background_tex)
		_o._ensure_full_rect(_o._background_tex)
		_o._background_tex.mouse_filter = Control.MOUSE_FILTER_PASS

	if _o._icon_texture != null:
		_o._icon = TextureRect.new()
		_o._icon.name = "Icon"
		_o._icon.texture = _o._icon_texture
		_o._icon.expand_mode = _o.IconExpandMode
		_o._icon.stretch_mode = _o.IconStretchMode
		_o._icon.flip_h = _o.IconFlipH
		_o._icon.flip_v = _o.IconFlipV
		_o._icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_o._managed_add_child(_o._icon)
		_o._ensure_full_rect(_o._icon)
		_o._icon.mouse_filter = Control.MOUSE_FILTER_PASS

	_o._set_label_text()

	# Default thumb for virtual joystick when no icon is provided
	var want_vj := (_o.FollowMode == Omni_Button.FollowModeEnum.VirtualJoystick) or _o.EnableVirtualJoystick
	var need_default_thumb := want_vj and _o.EnableDefaultThumb and _o._icon_texture == null
	if need_default_thumb:
		_o._ensure_default_thumb()
		_o._update_default_thumb_visual()

	update_overlay()

	if _o.EnableCooldown and (_o._cooldown_active or Engine.is_editor_hint()):
		ensure_cooldown()
		_o._update_cooldown_visual()

	reorder_children()

func overlay_parent_matches(node: Node) -> bool:
	if node == null or not is_instance_valid(node):
		return false
	var parent := node.get_parent()
	if parent == _o:
		return true
	return _o._managed_root != null and is_instance_valid(_o._managed_root) and parent == _o._managed_root

func ensure_overlay_under_managed_root() -> void:
	if _o._overlay == null or not is_instance_valid(_o._overlay):
		return
	var p := _o._overlay.get_parent()
	if _o._managed_root != null and is_instance_valid(_o._managed_root) and p == _o._managed_root:
		return
	if p != _o:
		return
	_o._ensure_managed_root()
	_o.remove_child(_o._overlay)
	_o._managed_root.add_child(_o._overlay)
	_o._ensure_full_rect(_o._overlay)
	_o._overlay.mouse_filter = Control.MOUSE_FILTER_PASS

func _find_managed_panel_for_styling() -> Panel:
	if _o._managed_root != null and is_instance_valid(_o._managed_root):
		var n = _o._managed_root.get_node_or_null("Panel")
		if n is Panel:
			return n
	var leg = _o.get_node_or_null("Panel")
	if leg is Panel:
		return leg
	if _o._panel != null and is_instance_valid(_o._panel):
		return _o._panel
	return null

func ensure_panel_under_managed_root() -> void:
	if _o._panel == null or not is_instance_valid(_o._panel):
		return
	var p := _o._panel.get_parent()
	if _o._managed_root != null and is_instance_valid(_o._managed_root) and p == _o._managed_root:
		return
	if p != _o:
		return
	_o._ensure_managed_root()
	_o.remove_child(_o._panel)
	_o._managed_root.add_child(_o._panel)
	_o._managed_root.move_child(_o._panel, 0)
	_o._ensure_full_rect(_o._panel)

func cleanup_extra_overlays() -> void:
	var parents := [_o, _o._managed_root]
	for parent in parents:
		if parent == null or not is_instance_valid(parent):
			continue
		for child in parent.get_children():
			if child == _o._overlay:
				continue
			if child is ColorRect and child.name == "Overlay":
				parent.remove_child(child)
				child.queue_free()

func update_overlay() -> void:
	ensure_overlay_under_managed_root()
	var need := _o._selected
	var alive := _o._overlay != null and is_instance_valid(_o._overlay) and _o._managed_root != null and is_instance_valid(_o._managed_root) and _o._overlay.get_parent() == _o._managed_root
	if need and not alive:
		_o._overlay = ColorRect.new()
		_o._overlay.name = "Overlay"
		_o._overlay.color = _o.SelectedColor
		_o._overlay.mouse_filter = Control.MOUSE_FILTER_PASS
		_o._managed_add_child(_o._overlay)
		_o._ensure_full_rect(_o._overlay)
	elif not need and alive:
		var ov := _o._overlay
		if ov != null and is_instance_valid(ov):
			var p := ov.get_parent()
			if p != null:
				p.remove_child(ov)
			ov.queue_free()
		_o._overlay = null

func ensure_cooldown() -> void:
	if _o._cooldown == null or not is_instance_valid(_o._cooldown):
		_o._cooldown = ColorRect.new()
		_o._cooldown.name = "Cooldown"
		_o._cooldown.color = _o.CooldownColor
		_o._cooldown.mouse_filter = Control.MOUSE_FILTER_PASS
		_o._managed_add_child(_o._cooldown)
		_o._cooldown.set_anchors_preset(Control.PRESET_TOP_LEFT)
		# Above label (3) and selection overlay (4); otherwise fill is drawn underneath and looks "missing" until other state changes.
		_o._cooldown.z_index = 5

func ensure_hold_fill_rect() -> void:
	if _o._hold_fill == null or not is_instance_valid(_o._hold_fill):
		_o._hold_fill = ColorRect.new()
		_o._hold_fill.name = "HoldFill"
		_o._hold_fill.color = _o.HoldFillColor
		_o._hold_fill.mouse_filter = Control.MOUSE_FILTER_PASS
		_o._managed_add_child(_o._hold_fill)
		_o._hold_fill.set_anchors_preset(Control.PRESET_TOP_LEFT)
		_o._hold_fill.z_index = 6

func remove_hold_fill() -> void:
	if is_instance_valid(_o._hold_fill):
		_o._hold_fill.visible = false
		_o._hold_fill.size = Vector2.ZERO
		_o._hold_fill.position = Vector2.ZERO

func reorder_children() -> void:
	var parent := _o._managed_root if (_o._managed_root != null and is_instance_valid(_o._managed_root)) else _o
	var idx := 0
	if child_alive(parent, _o._panel): parent.move_child(_o._panel, idx); idx += 1
	if child_alive(parent, _o._background_tex): parent.move_child(_o._background_tex, idx); idx += 1
	if child_alive(parent, _o._icon): parent.move_child(_o._icon, idx); idx += 1
	elif child_alive(parent, _o._default_thumb): parent.move_child(_o._default_thumb, idx); idx += 1
	if child_alive(parent, _o._label): parent.move_child(_o._label, idx); idx += 1
	elif child_alive(parent, _o._rich_label): parent.move_child(_o._rich_label, idx); idx += 1
	if child_alive(parent, _o._overlay): parent.move_child(_o._overlay, idx); idx += 1
	if child_alive(parent, _o._cooldown): parent.move_child(_o._cooldown, idx); idx += 1
	if child_alive(parent, _o._hold_fill): parent.move_child(_o._hold_fill, idx); idx += 1

func child_alive(parent: Node, node: Node) -> bool:
	return node != null and is_instance_valid(node) and node.get_parent() == parent

func configure_label(lbl: Label) -> void:
	# Fill parent and zero offsets so it truly stretches
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ep := _o._get_effective_label_padding()
	lbl.offset_left = ep.x
	lbl.offset_top = ep.y
	lbl.offset_right = - ep.z
	lbl.offset_bottom = - ep.w
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# Respect configured alignment and wrap
	lbl.horizontal_alignment = _o.LabelHorizontalAlignment
	lbl.vertical_alignment = _o.LabelVerticalAlignment
	lbl.autowrap_mode = _o.LabelAutowrap
	# Apply optional font override
	if _o.LabelFont != null:
		lbl.add_theme_font_override("font", _o.LabelFont)
	lbl.mouse_filter = Control.MOUSE_FILTER_PASS

func configure_rich_label(rtl: RichTextLabel) -> void:
	rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ep := _o._get_effective_label_padding()
	rtl.offset_left = ep.x
	rtl.offset_top = ep.y
	rtl.offset_right = - ep.z
	rtl.offset_bottom = - ep.w
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.bbcode_enabled = true
	rtl.scroll_active = false
	# Match C#: do not shrink the control to content; fill rect and let autosize scale fonts.
	rtl.fit_content = false
	rtl.autowrap_mode = _o.LabelAutowrap
	rtl.horizontal_alignment = _o.LabelHorizontalAlignment
	rtl.vertical_alignment = _o.LabelVerticalAlignment
	if _o.LabelFont != null:
		rtl.add_theme_font_override("normal_font", _o.LabelFont)
	rtl.add_theme_color_override("default_color", _o.LabelTextColor)
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS

func apply_visual_state() -> void:
	if _o.BackgroundType == Omni_Button.BackgroundMode.UsePanel and _o._panel == null:
		_o._panel = Panel.new()
		_o._panel.name = "Panel"
		_o._managed_add_child(_o._panel)
		_o._ensure_full_rect(_o._panel)
		apply_panel_styling()
	else:
		ensure_panel_under_managed_root()

	ensure_overlay_under_managed_root()
	var overlay_alive := _o._overlay != null and is_instance_valid(_o._overlay) and _o._managed_root != null and is_instance_valid(_o._managed_root) and _o._overlay.get_parent() == _o._managed_root
	if _o._selected and not overlay_alive:
		_o._overlay = ColorRect.new()
		_o._overlay.name = "Overlay"
		_o._managed_add_child(_o._overlay)

	if _o.BackgroundType == Omni_Button.BackgroundMode.UsePanel and _o._panel != null:
		_o._panel.visible = true
		_o._panel.modulate = _o.PanelModulate
		apply_invert(_o._panel)
		_o._panel.z_index = 0

	if _o.BackgroundType == Omni_Button.BackgroundMode.UseTexture and _o._background_tex != null:
		_o._background_tex.texture = _o.BackgroundTexture
		_o._background_tex.flip_h = _o.BackgroundFlipH
		_o._background_tex.flip_v = _o.BackgroundFlipV
		_o._background_tex.expand_mode = _o.BackgroundExpandMode
		_o._background_tex.stretch_mode = _o.BackgroundStretchMode
		_o._background_tex.modulate = _o.BackgroundModulate
		apply_invert(_o._background_tex)
		_o._background_tex.z_index = 1

	if _o._icon != null:
		_o._icon.texture = _o._icon_texture
		_o._icon.flip_h = _o.IconFlipH
		_o._icon.flip_v = _o.IconFlipV
		_o._icon.expand_mode = _o.IconExpandMode
		_o._icon.stretch_mode = _o.IconStretchMode
		_o._icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_o._icon.modulate = _o.IconModulate
		apply_invert(_o._icon)
		_o._icon.z_index = 2

	if _o._label != null:
		if not _o._tw_active:
			_o._label.text = _o._text
		configure_label(_o._label)
		_o._label.add_theme_color_override("font_color", _o.LabelTextColor)
		_o._label.modulate = _o.TextModulate
		apply_invert(_o._label)
		_o._label.z_index = 3
	if _o._rich_label != null:
		if not _o._tw_active:
			_o._rich_label.text = _o._text
		configure_rich_label(_o._rich_label)
		_o._rich_label.modulate = _o.TextModulate
		apply_invert(_o._rich_label)
		_o._rich_label.z_index = 3

	if _o._overlay != null and is_instance_valid(_o._overlay):
		_o._overlay.visible = _o._selected
		_o._overlay.color = _o.SelectedColor
		apply_invert(_o._overlay)
		_o._overlay.z_index = 4

	if _o._cooldown != null and is_instance_valid(_o._cooldown):
		_o._cooldown.color = _o.CooldownColor
		_o._cooldown.z_index = 5
	if _o._hold_fill != null and is_instance_valid(_o._hold_fill):
		_o._hold_fill.color = _o.HoldFillColor
		_o._hold_fill.z_index = 6

func apply_invert(node: CanvasItem) -> void:
	var on_pressf := (_o.InvertModes & _o.INVERT_PRESS) != 0
	var on_togglef := (_o.InvertModes & _o.INVERT_TOGGLE) != 0
	var on_hoverf := (_o.InvertModes & _o.INVERT_HOVER) != 0
	var on_holdf := (_o.InvertModes & _o.INVERT_HOLD) != 0
	var hold_active := _o._is_holding or (_o.EnableHoldBuildUp and _o._is_pressed and _o._hold_timer >= _o.HoldDuration)
	var cooldown_active := _o._cooldown_active and _o.InvertOnCooldown and (_o.CooldownInvertDuration <= 0.0 or _o._cooldown_elapsed <= _o.CooldownInvertDuration)
	var should := (_o._is_pressed and on_pressf) or (_o._is_toggled and on_togglef) or (_o._is_hovering and on_hoverf) or (hold_active and on_holdf) or cooldown_active
	if _o._invert_material != null and should:
		node.material = _o._invert_material
	else:
		node.material = null

func apply_panel_styling() -> void:
	if _o.BackgroundType != Omni_Button.BackgroundMode.UsePanel:
		var p_clear := _find_managed_panel_for_styling()
		if p_clear != null:
			if p_clear.has_theme_stylebox_override("panel"):
				p_clear.remove_theme_stylebox_override("panel")
			p_clear.queue_redraw()
		return
	if _o._panel == null or not is_instance_valid(_o._panel):
		var found := _find_managed_panel_for_styling()
		if found != null:
			_o._panel = found
			ensure_panel_under_managed_root()
	if _o._panel == null: return
	_o._panel.theme = null
	_o._panel.theme_type_variation = _o.PanelThemeVariation
	_o._panel.remove_theme_stylebox_override("panel")
	if _o.PanelStyleBox != null:
		_o._panel.add_theme_stylebox_override("panel", _o.PanelStyleBox)
	_o._panel.queue_redraw()
	if Engine.is_editor_hint():
		_o.queue_redraw()
