extends RefCounted
class_name OmniButtonVisuals
## builds, styles and lays out the visuals the button draws.
## static, every function takes the button as the first argument (_o).
##
## only the text label is a node. the panel, background, icon, selected overlay, cooldown fill,
## hold fill and joystick thumb are OmniDrawItem canvas items under the _Managed root, so hover
## scaling and managed_draw_on_top work on them the same as they did on child nodes.
## draw order is the same z_index ladder the nodes had:
##   panel 0, background 1, icon/thumb 2, label 3, overlay 4, cooldown 5, hold fill 6.

## node names older versions made. scenes saved with them get cleaned up on rebuild.
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

const Z_PANEL := 0
const Z_BACKGROUND := 1
const Z_ICON := 2
const Z_LABEL := 3
const Z_OVERLAY := 4
const Z_COOLDOWN := 5
const Z_HOLD_FILL := 6


static func ensure_managed_root(_o: OmniButton) -> void:
	if _o._managed_root != null and is_instance_valid(_o._managed_root):
		return
	_o._managed_root = Control.new()
	_o._managed_root.name = "_Managed"
	_o.add_child(_o._managed_root)
	ensure_full_rect(_o, _o._managed_root)
	# the visuals are just decoration. input goes by the button's own rect, which is what its hit
	# test checks, so big icons, labels or hover scaled stuff can't steal clicks.
	_o._managed_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	position_managed_root(_o)

static func position_managed_root(_o: OmniButton) -> void:
	if _o._managed_root == null or not is_instance_valid(_o._managed_root):
		return
	var parent := _o
	if _o._managed_draw_on_top:
		parent.move_child(_o._managed_root, parent.get_child_count() - 1)
	else:
		parent.move_child(_o._managed_root, 0)

static func managed_add_child(_o: OmniButton, node: Node) -> void:
	ensure_managed_root(_o)
	_o._managed_root.add_child(node)

static func ensure_full_rect(_o: OmniButton, node: Control) -> void:
	if node == null or not is_instance_valid(node):
		return
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node.size_flags_vertical = Control.SIZE_EXPAND_FILL

## a new canvas item under the _Managed root. full rect items get the button's size.
static func new_item(_o: OmniButton, kind: int, item_name: String, z: int, full_rect := true) -> OmniDrawItem:
	ensure_managed_root(_o)
	var item := OmniDrawItem.new(kind, _o._managed_root.get_canvas_item(), item_name, z)
	if full_rect:
		item.size = _o.size
	return item

static func _alive(_o: OmniButton, item: OmniDrawItem) -> bool:
	return item != null and item.is_alive()

static func _free_item(_o: OmniButton, item: OmniDrawItem) -> void:
	if item != null:
		item.queue_free()

static func setup_children(_o: OmniButton) -> void:
	# scenes saved by older versions (or duplicated in the editor) can have saved copies of the
	# managed child nodes. clear them out by name so there's only ever one set.
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

	# only free our own visuals, children you added are left alone.
	for item in [_o._panel, _o._background_tex, _o._icon, _o._overlay, _o._cooldown, _o._hold_fill, _o._default_thumb]:
		_free_item(_o, item)
	for n in [_o._label, _o._rich_label, _o._vj_area_panel]:
		if n != null and is_instance_valid(n):
			var p = n.get_parent()
			if p != null:
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

	if _o._background_mode == OmniButton.BackgroundMode.USE_PANEL:
		_o._panel = new_item(_o, OmniDrawItem.Kind.STYLE, "Panel", Z_PANEL)
		apply_panel_styling(_o)

	if _o._background_mode == OmniButton.BackgroundMode.USE_TEXTURE and _o.texture != null:
		var bg := new_item(_o, OmniDrawItem.Kind.TEXTURE, "Background", Z_BACKGROUND)
		bg.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		_o._background_tex = bg
		_sync_background(_o)

	if _o._icon_texture != null:
		_create_icon(_o)

	_o._set_label_text()

	# default thumb for the virtual joystick when there's no icon
	var want_vj := _o._follow_mode == OmniButton.FollowMode.VIRTUAL_JOYSTICK
	var need_default_thumb := want_vj and _o._enable_default_thumb and _o._icon_texture == null
	if need_default_thumb:
		_o._ensure_joystick().ensure_default_thumb()
		_o._ensure_joystick().update_default_thumb_visual()

	update_overlay(_o)

	if _o._cooldown_trigger != _o.CooldownTrigger.NONE and (_o._cooldown_active or Engine.is_editor_hint()):
		ensure_cooldown(_o)
		OmniButtonTiming.update_cooldown_visual(_o)

static func _create_icon(_o: OmniButton) -> void:
	var icon := new_item(_o, OmniDrawItem.Kind.TEXTURE, "Icon", Z_ICON)
	icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_o._icon = icon
	_sync_icon(_o)

## extra tint for the text and icon. disabled_modulate while disabled, otherwise nothing.
static func content_modulate(_o: OmniButton) -> Color:
	return _o.disabled_modulate if _o._disabled else Color.WHITE

static func _sync_icon(_o: OmniButton) -> void:
	var icon := _o._icon
	icon.texture = _o._icon_texture
	icon.expand_mode = _o.icon_expand_mode
	icon.stretch_mode = _o.icon_stretch_mode
	icon.flip_h = _o.icon_flip_h
	icon.flip_v = _o.icon_flip_v
	icon.modulate = _o.icon_modulate * content_modulate(_o)

static func _sync_background(_o: OmniButton) -> void:
	var bg := _o._background_tex
	bg.texture = _o.texture
	bg.expand_mode = _o.expand_mode
	bg.stretch_mode = _o.stretch_mode
	bg.flip_h = _o.flip_h
	bg.flip_v = _o.flip_v
	bg.modulate = _o.background_modulate

static func _wants_default_thumb(_o: OmniButton) -> bool:
	var want_vj := _o._follow_mode == OmniButton.FollowMode.VIRTUAL_JOYSTICK
	return want_vj and _o._enable_default_thumb

## applies an icon_texture change without rebuilding everything.
## returns false when it still needs a full setup_children(_o) (not ready yet, or the joystick's
## default thumb has to be swapped in or out).
static func try_sync_icon_in_place(_o: OmniButton) -> bool:
	if not _o.is_node_ready():
		return false
	var tex := _o._icon_texture
	var icon_alive := _alive(_o, _o._icon)
	if _wants_default_thumb(_o):
		# the thumb exists exactly when there's no icon, so changing that needs a rebuild.
		if (tex == null) != _alive(_o, _o._default_thumb):
			return false
	if tex != null:
		if icon_alive:
			_o._icon.texture = tex
		else:
			_create_icon(_o)
		return true
	if icon_alive:
		_o._icon.queue_free()
		_o._icon = null
	return true

static func update_overlay(_o: OmniButton) -> void:
	var need := _o._selected
	var alive := _alive(_o, _o._overlay)
	if need and not alive:
		_o._overlay = new_item(_o, OmniDrawItem.Kind.RECT, "Overlay", Z_OVERLAY)
		_o._overlay.color = _o.selected_color
		_o._overlay.material = _invert_target(_o)
	elif not need and alive:
		_o._overlay.queue_free()
		_o._overlay = null

static func ensure_cooldown(_o: OmniButton) -> void:
	if not _alive(_o, _o._cooldown):
		# above the label (3) and selected overlay (4). the timing code positions and sizes it.
		_o._cooldown = new_item(_o, OmniDrawItem.Kind.RECT, "Cooldown", Z_COOLDOWN, false)
		_o._cooldown.color = _o.cooldown_color
		_o._cooldown.corner_radius = panel_corner_radius(_o)

static func ensure_hold_fill_rect(_o: OmniButton) -> void:
	if not _alive(_o, _o._hold_fill):
		_o._hold_fill = new_item(_o, OmniDrawItem.Kind.RECT, "HoldFill", Z_HOLD_FILL, false)
		_o._hold_fill.color = _o.hold_fill_color
		_o._hold_fill.corner_radius = panel_corner_radius(_o)

static func remove_hold_fill(_o: OmniButton) -> void:
	if _alive(_o, _o._hold_fill):
		_o._hold_fill.visible = false
		_o._hold_fill.size = Vector2.ZERO
		_o._hold_fill.position = Vector2.ZERO

static func configure_label(_o: OmniButton, lbl: Label) -> void:
	# fill the parent with zero offsets so it actually stretches
	lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ep := OmniButtonText.get_effective_label_padding(_o)
	lbl.offset_left = ep.x
	lbl.offset_top = ep.y
	lbl.offset_right = - ep.z
	lbl.offset_bottom = - ep.w
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	# use the alignment and wrap from the settings
	lbl.horizontal_alignment = _o.label_horizontal_alignment
	lbl.vertical_alignment = _o.label_vertical_alignment
	lbl.autowrap_mode = _o.label_autowrap
	lbl.uppercase = _o.label_uppercase
	lbl.clip_text = _o.label_clip_text
	lbl.text_overrun_behavior = _o.label_text_overrun
	# font override if there is one
	if _o.label_font != null:
		lbl.add_theme_font_override("font", _o.label_font)
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lbl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING

static func configure_rich_label(_o: OmniButton, rtl: RichTextLabel) -> void:
	rtl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ep := OmniButtonText.get_effective_label_padding(_o)
	rtl.offset_left = ep.x
	rtl.offset_top = ep.y
	rtl.offset_right = - ep.z
	rtl.offset_bottom = - ep.w
	rtl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rtl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rtl.bbcode_enabled = _o.rich_label_use_bbcode
	rtl.scroll_active = _o.rich_text_scroll_active
	rtl.scroll_following = _o.rich_text_scroll_following
	rtl.selection_enabled = _o.rich_text_selection_enabled
	rtl.context_menu_enabled = _o.rich_text_context_menu_enabled
	rtl.fit_content = _o.rich_text_fit_content
	rtl.autowrap_mode = _o.label_autowrap
	rtl.horizontal_alignment = _o.label_horizontal_alignment
	rtl.vertical_alignment = _o.label_vertical_alignment
	if _o.label_font != null:
		rtl.add_theme_font_override("normal_font", _o.label_font)
	rtl.add_theme_color_override("default_color", _o.label_text_color)
	# rich text only needs the mouse for its own selecting and scrolling, otherwise it's just decoration.
	rtl.mouse_filter = Control.MOUSE_FILTER_PASS if (_o.rich_text_selection_enabled or _o.rich_text_scroll_active) else Control.MOUSE_FILTER_IGNORE
	rtl.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING

## full rect visuals follow the button's size (the nodes used to do this with anchors).
static func layout_content(_o: OmniButton) -> void:
	var s := _o.size
	for item in [_o._panel, _o._background_tex, _o._icon, _o._overlay]:
		if _alive(_o, item):
			item.size = s

static func apply_visual_state(_o: OmniButton) -> void:
	if _o._background_mode == OmniButton.BackgroundMode.USE_PANEL and not _alive(_o, _o._panel):
		_o._panel = new_item(_o, OmniDrawItem.Kind.STYLE, "Panel", Z_PANEL)
	update_overlay(_o)
	layout_content(_o)
	var mat := _invert_target(_o)

	if _o._background_mode == OmniButton.BackgroundMode.USE_PANEL and _alive(_o, _o._panel):
		_o._panel.visible = true
		_o._panel.modulate = _o.panel_modulate
		_o._panel.material = mat

	if _o._background_mode == OmniButton.BackgroundMode.USE_TEXTURE and _alive(_o, _o._background_tex):
		_sync_background(_o)
		_o._background_tex.material = mat

	if _alive(_o, _o._icon):
		_sync_icon(_o)
		_o._icon.material = mat

	if _o._label != null:
		if not _o._tw_active:
			_o._label.text = _o._text
		configure_label(_o, _o._label)
		_o._label.add_theme_color_override("font_color", _o.label_text_color)
		_o._label.modulate = _o.text_modulate * content_modulate(_o)
		_set_node_material(_o, _o._label, mat)
		_o._label.z_index = Z_LABEL
	if _o._rich_label != null:
		if not _o._tw_active:
			_o._rich_label.text = _o._text
		configure_rich_label(_o, _o._rich_label)
		_o._rich_label.add_theme_color_override("default_color", _o.label_text_color)
		_o._rich_label.modulate = _o.text_modulate * content_modulate(_o)
		_set_node_material(_o, _o._rich_label, mat)
		_o._rich_label.z_index = Z_LABEL

	if _alive(_o, _o._overlay):
		_o._overlay.visible = _o._selected
		_o._overlay.color = _o.selected_color
		_o._overlay.material = mat

	if _alive(_o, _o._cooldown):
		_o._cooldown.color = _o.cooldown_color
	if _alive(_o, _o._hold_fill):
		_o._hold_fill.color = _o.hold_fill_color
	apply_panel_styling(_o)

## the material every visual should have right now: the invert shader or null.
static func _invert_target(_o: OmniButton) -> Material:
	if _o._invert_material == null:
		return null
	var modes := _o.invert_modes
	var hold_duration := _o._hold_duration
	var hold_active := _o._is_holding or (hold_duration > 0.0 and _o._is_pressed and _o._hold_timer >= hold_duration)
	var cooldown_active := _o._cooldown_active and _o.invert_on_cooldown and (_o.cooldown_invert_duration <= 0.0 or _o._cooldown_elapsed <= _o.cooldown_invert_duration)
	var should := (_o._is_pressed and (modes & _o.INVERT_PRESS) != 0) \
		or (_o._is_toggled and (modes & _o.INVERT_TOGGLE) != 0) \
		or (_o._is_hovering and (modes & _o.INVERT_HOVER) != 0) \
		or (hold_active and (modes & _o.INVERT_HOLD) != 0) \
		or cooldown_active
	return _o._invert_material if should else null

## CanvasItem.set_material() doesn't skip when the value's the same, so compare first.
## (OmniDrawItem.material already does that itself.)
static func _set_node_material(_o: OmniButton, node: CanvasItem, mat: Material) -> void:
	if node != null and is_instance_valid(node) and node.material != mat:
		node.material = mat

## the cheap pass for state changes: material, overlay visibility and panel style only.
static func apply_state_visuals(_o: OmniButton) -> void:
	var mat := _invert_target(_o)
	if _o._panel != null: _o._panel.material = mat
	if _o._background_tex != null: _o._background_tex.material = mat
	if _o._icon != null: _o._icon.material = mat
	_set_node_material(_o, _o._label, mat)
	_set_node_material(_o, _o._rich_label, mat)
	if _alive(_o, _o._overlay):
		_o._overlay.visible = _o._selected
		_o._overlay.material = mat
	refresh_panel_style(_o)

## points the panel at the style for the current state. it only redraws if that changed.
static func refresh_panel_style(_o: OmniButton) -> void:
	if _o._background_mode != OmniButton.BackgroundMode.USE_PANEL or not _alive(_o, _o._panel):
		return
	_o._panel.style = _resolved_panel_style(_o)
	var corners := panel_corner_radius(_o)
	if _alive(_o, _o._cooldown):
		_o._cooldown.corner_radius = corners
	if _alive(_o, _o._hold_fill):
		_o._hold_fill.corner_radius = corners

## corner radii of the panel's idle style if it's a StyleBoxFlat, so the cooldown and hold fills stay
## inside rounded corners. zero for square panels, textures and other StyleBox types.
static func panel_corner_radius(_o: OmniButton) -> Vector4i:
	if _o._background_mode != OmniButton.BackgroundMode.USE_PANEL:
		return Vector4i.ZERO
	var flat := _o.panel_style_box as StyleBoxFlat
	if flat == null and _alive(_o, _o._panel):
		flat = _o._panel.style as StyleBoxFlat
	if flat == null:
		return Vector4i.ZERO
	return Vector4i(flat.corner_radius_top_left, flat.corner_radius_top_right,
		flat.corner_radius_bottom_right, flat.corner_radius_bottom_left)

## what a Panel node would draw: the state override, otherwise the theme's "panel" stylebox for
## panel_theme_variation (falling back to the Panel type like a node would).
static func _resolved_panel_style(_o: OmniButton) -> StyleBox:
	var style := _active_panel_style(_o)
	if style != null:
		return style
	var variation := StringName(_o.panel_theme_variation)
	if variation != &"" and _o.has_theme_stylebox(&"panel", variation):
		return _o.get_theme_stylebox(&"panel", variation)
	return _o.get_theme_stylebox(&"panel", &"Panel")

static func apply_panel_styling(_o: OmniButton) -> void:
	if _o._background_mode != OmniButton.BackgroundMode.USE_PANEL:
		return
	if not _alive(_o, _o._panel):
		return
	refresh_panel_style(_o)
	if Engine.is_editor_hint():
		_o.queue_redraw()

static func _active_panel_style(_o: OmniButton) -> StyleBox:
	if _o._disabled and _o.panel_disabled_style_box != null:
		return _o.panel_disabled_style_box
	if (_o._is_pressed or _o._is_toggled) and _o.panel_pressed_style_box != null:
		return _o.panel_pressed_style_box
	if _o._is_hovering and _o.panel_hover_style_box != null:
		return _o.panel_hover_style_box
	if _o.has_focus() and _o.panel_focus_style_box != null:
		return _o.panel_focus_style_box
	return _o.panel_style_box
