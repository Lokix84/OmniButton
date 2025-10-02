@tool
class_name OmniButton
extends Control

# ---------- Signals ----------
signal pressed
signal toggled(button_pressed: bool)
signal released
signal hover_in
signal hover_out
signal log(type: String, message: String)

# ---------- Constants & Static Data ----------
const T_TEXT_NORMAL := "text_color"
const T_TEXT_HOVER := "text_color_hover"
const T_TEXT_PRESSED := "text_color_pressed"
const T_TEXT_DISABLED := "text_color_disabled"

const T_ICON_TINT_NORMAL := "icon_tint"
const T_ICON_TINT_HOVER := "icon_tint_hover"
const T_ICON_TINT_PRESSED := "icon_tint_pressed"
const T_ICON_TINT_DISABLED := "icon_tint_disabled"

const T_BG := "panel"
const T_FONT := "font"
const T_FONT_SIZE := "font_size"

static var _preset_selected_colors := {
	"red": Color(1.0, 0.3, 0.3, 0.7),
	"green": Color(0.3, 1.0, 0.3, 0.7),
	"blue": Color(0.3, 0.3, 1.0, 0.7),
	"yellow": Color(1.0, 1.0, 0.3, 0.7),
	"purple": Color(0.8, 0.3, 1.0, 0.7),
	"orange": Color(1.0, 0.6, 0.2, 0.7),
	"cyan": Color(0.3, 1.0, 1.0, 0.7)
}

static var _preset_unselected_colors := {
	"dark": Color(0.0, 0.0, 0.0, 0.4),
	"gray": Color(0.3, 0.3, 0.3, 0.3),
	"red": Color(0.3, 0.0, 0.0, 0.3),
	"blue": Color(0.0, 0.0, 0.3, 0.3)
}

static var _own_signals := ["pressed", "toggled", "released", "log", "hover_in", "hover_out"]
static var _shared_invert_mat: ShaderMaterial

# ---------- Exported Properties ----------
# General
@export_group("General Settings")
var _button_disabled := false
@export var button_disabled: bool:
	get: return _button_disabled
	set(v): _set_button_disabled(v)

# Input
@export_group("Input & Hit Detection")
@export var action_name: String = "ui_accept"
@export var require_focus_for_action: bool = true
@export var bounds_source: Control
@export var hit_slop: Vector2 = Vector2.ZERO

# Actions
@export_group("Interaction & Actions")
@export var enable_press_actions: bool = true
@export var pressed_action: Callable
@export var invert_on_press_if_no_pressed_texture := true
@export var enable_release_actions: bool = false
@export var released_action: Callable

var _enable_toggle_actions: bool = false
@export var enable_toggle_actions: bool:
	get: return _enable_toggle_actions
	set(value): _set_toggle_enabled(value)

var _toggle_pressed: bool = false
@export var toggle_pressed: bool:
	get: return _toggle_pressed
	set(value): _set_toggle_pressed(value)

@export var toggled_action: Callable

# Selection States
var _selected: bool = false
@export var selected: bool:
	get: return _selected
	set(value): set_selection_state(value, _un_selected)

@export var selected_color: Color = Color(1.0, 1.0, 1.0, 0.3)

var _un_selected: bool = false
@export var un_selected: bool:
	get: return _un_selected
	set(value): set_selection_state(_selected, value)

@export var un_selected_color: Color = Color(0.0, 0.0, 0.0, 0.2)

# Hover
@export_group("Hover and Scaling")
@export var enable_hover_actions: bool = false
@export var hover_in_action: Callable
@export var hover_out_action: Callable
@export var hover_scale: float = 1.25
@export var hover_lerp_speed: float = 25.0

# Text & Font
@export_group("Text & Font")
@export var min_font_size: int = 12
@export var max_font_size: int = 100

var _horizontal_alignment: HorizontalAlignment = HORIZONTAL_ALIGNMENT_CENTER
@export var horizontal_alignment: HorizontalAlignment:
	get: return _horizontal_alignment
	set(value): _set_alignment(value, _vertical_alignment)

var _vertical_alignment: VerticalAlignment = VERTICAL_ALIGNMENT_CENTER
@export var vertical_alignment: VerticalAlignment:
	get: return _vertical_alignment
	set(value): _set_alignment(_horizontal_alignment, value)

var _autowrap_mode: TextServer.AutowrapMode = TextServer.AUTOWRAP_WORD
@export var autowrap_mode: TextServer.AutowrapMode:
	get: return _autowrap_mode
	set(value): _set_autowrap_mode(value)

var _invert_text_if_no_icon := false
@export var invert_text_if_no_icon: bool:
	get: return _invert_text_if_no_icon
	set(value): _set_invert_text_if_no_icon(value)

var _text: String = ""
@export var text: String:
	get: return _text
	set(value): _set_text(value)

# Icon & Texture
@export_group("Icon")
@export var icon_stretch := true
@export var icon_keep_aspect := true

@export_group("Texture")
var _normal_texture: Texture2D
@export var texture: Texture2D:
	get: return _normal_texture
	set(value): _set_texture(value, true)

var _pressed_texture: Texture2D
@export var pressed_texture: Texture2D:
	get: return _pressed_texture
	set(value): _set_texture(value, false)

# Theme
@export_group("Theme & Visuals")
var _theme_type_name: String = "OmniButton"
@export var theme_type_name: String:
	get: return _theme_type_name
	set(value): _set_theme_type_name(value)

@export var inherit_theme_to_children: bool = true

@export_subgroup("Base Node Theme Variations")
@export var base_normal_theme_variation: String = "normal"
@export var base_hover_theme_variation: String = "hover"
@export var base_pressed_theme_variation: String = "pressed"
@export var base_toggled_theme_variation: String = "toggled"

@export_subgroup("Label Theme Variations")
@export var label_normal_theme_variation: String = ""
@export var label_hover_theme_variation: String = ""
@export var label_pressed_theme_variation: String = ""
@export var label_toggled_theme_variation: String = ""

@export_subgroup("Icon Theme Variations")
@export var icon_normal_theme_variation: String = ""
@export var icon_hover_theme_variation: String = ""
@export var icon_pressed_theme_variation: String = ""
@export var icon_toggled_theme_variation: String = ""

# Logging
@export_group("Logging")
@export var log_action: Callable

# ---------- Private State & Caching ----------
var _is_pointer_down := false
var _hover_target_scale := 1.0
var _original_scale: Vector2 = Vector2.ONE
var _hovering := false
var _theme_applying := false
var _fitting_label := false

# Cached components
var _cached_label: Label
var _cached_icon: TextureRect
var _cached_overlay: ColorRect

# Cached state for optimization
var _last_visual_state: String
var _last_text_color: Color = Color.TRANSPARENT
var _last_icon_tint: Color = Color.TRANSPARENT

# ---------- Godot Lifecycle ----------
func _enter_tree() -> void:
	_initialize()

func _exit_tree() -> void:
	_cleanup()

func _ready() -> void:
	_setup()

func _process(delta: float) -> void:
	_process_hover_scaling(delta)

func _notification(what: int) -> void:
	_handle_notifications(what)

func _get_property_list() -> Array:
	return _build_property_list()

func _unhandled_input(event: InputEvent) -> void:
	_handle_unhandled_input(event)

func _gui_input(event: InputEvent) -> void:
	_handle_gui_input(event)

# ---------- Initialization & Cleanup ----------
func _initialize() -> void:
	_initialize_callables()
	if not Engine.is_editor_hint():
		_connect_signals()
	_connect_mouse_events()

func _setup() -> void:
	focus_mode = Control.FOCUS_ALL
	bounds_source = bounds_source if bounds_source != null else self
	theme_type_variation = theme_type_name
	_original_scale = scale

	if Engine.is_editor_hint():
		notify_property_list_changed()
	if _text != "":
		_set_text(_text)

	_apply_visual_state()
	_apply_theme_now()
	_update_overlay()

	_connect_if_not_connected("minimum_size_changed", Callable(self, "_on_minimum_size_changed"))

func _cleanup() -> void:
	_disconnect_all_signal_handlers()
	_cached_label = null
	_cached_icon = null
	_cached_overlay = null

func _initialize_callables() -> void:
	var fallbacks := [
		["pressed", Callable(self, "_run_built_in_pressed")],
		["released", Callable(self, "_run_built_in_released")],
		["hover_in", Callable(self, "_run_built_in_hover_in")],
		["hover_out", Callable(self, "_run_built_in_hover_out")],
		["toggled", Callable(self, "_run_built_in_toggled")],
		["log", Callable(self, "_run_built_in_log")]
	]

	for pair in fallbacks:
		_set_callable_property(pair[0], _adopt_connected_callable(pair[0], pair[1]))

func _set_callable_property(name: String, callable: Callable) -> void:
	match name:
		"pressed": pressed_action = callable
		"released": released_action = callable
		"hover_in": hover_in_action = callable
		"hover_out": hover_out_action = callable
		"toggled": toggled_action = callable
		"log": log_action = callable

func _connect_signals() -> void:
	var signals_array := [
		["pressed", pressed_action],
		["released", released_action],
		["hover_in", hover_in_action],
		["hover_out", hover_out_action],
		["toggled", toggled_action],
		["log", log_action]
	]

	for pair in signals_array:
		if get_signal_connection_list(pair[0]).is_empty():
			connect(pair[0], pair[1])

func _connect_mouse_events() -> void:
	_connect_if_not_connected("mouse_entered", Callable(self, "_on_mouse_entered"))
	_connect_if_not_connected("mouse_exited", Callable(self, "_on_mouse_exited"))

func _connect_if_not_connected(signal_name: String, callable: Callable) -> void:
	if not is_connected(signal_name, callable):
		connect(signal_name, callable)

# ---------- Property Setters (Optimized) ----------
func _set_button_disabled(value: bool) -> void:
	if _button_disabled == value:
		return
	_button_disabled = value
	if value:
		_is_pointer_down = false
		_hovering = false
		_invalidate_visual_state()

func _set_toggle_enabled(value: bool) -> void:
	if _enable_toggle_actions == value:
		return
	_enable_toggle_actions = value
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _set_toggle_pressed(value: bool) -> void:
	if _toggle_pressed == value:
		return
	_toggle_pressed = value
	_invalidate_visual_state()
	if enable_toggle_actions and not Engine.is_editor_hint():
		emit_signal("toggled", _toggle_pressed)

func _set_alignment(h_align: HorizontalAlignment, v_align: VerticalAlignment) -> void:
	var changed := _horizontal_alignment != h_align or _vertical_alignment != v_align
	if not changed:
		return

	_horizontal_alignment = h_align
	_vertical_alignment = v_align

	if _cached_label != null and is_instance_valid(_cached_label):
		_cached_label.horizontal_alignment = h_align
		_cached_label.vertical_alignment = v_align
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _set_autowrap_mode(mode: TextServer.AutowrapMode) -> void:
	if _autowrap_mode == mode:
		return
	_autowrap_mode = mode

	if _cached_label != null and is_instance_valid(_cached_label):
		_cached_label.autowrap_mode = mode
		_safe_call_deferred("_fit_label_text")
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _set_invert_text_if_no_icon(value: bool) -> void:
	if _invert_text_if_no_icon == value:
		return
	_invert_text_if_no_icon = value
	_invalidate_visual_state()
	if Engine.is_editor_hint():
		notify_property_list_changed()

func _set_text(value) -> void:
	if typeof(value) == TYPE_NIL:
		value = ""
	var s := String(value)
	if s == _text:
		return
	_text = s

	var lbl := _get_or_create_label()
	lbl.text = s
	_safe_call_deferred("_fit_label_text")

func _set_texture(tex: Texture2D, is_normal: bool) -> void:
	if is_normal:
		if _normal_texture == tex:
			return
		_normal_texture = tex
		_ensure_icon()
	else:
		if _pressed_texture == tex:
			return
		_pressed_texture = tex
	_invalidate_visual_state()

func _set_theme_type_name(value: String) -> void:
	if _theme_type_name == value:
		return
	_theme_type_name = value
	theme_type_variation = value
	_safe_call_deferred("_apply_theme_now")

func set_selection_state(selected: bool, unselected: bool = false) -> void:
	if selected and unselected:
		unselected = false

	var changed := _selected != selected or _un_selected != unselected
	if not changed:
		return

	_selected = selected
	_un_selected = unselected
	_update_overlay()

func _invalidate_visual_state() -> void:
	_last_visual_state = ""
	_apply_visual_state()
	_apply_theme_now()

# ---------- Input Handling (Optimized) ----------
func _handle_unhandled_input(event: InputEvent) -> void:
	if button_disabled or action_name == "":
		return

	if event.is_action_pressed(action_name) and _action_allowed():
		_on_pressed()
		get_viewport().set_input_as_handled()
	elif event.is_action_released(action_name):
		_is_pointer_down = false
		_invalidate_visual_state()
		if _action_allowed():
			_on_released()
			get_viewport().set_input_as_handled()

func _handle_gui_input(event: InputEvent) -> void:
	if button_disabled:
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_handle_mouse_button(mb)
	elif event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)

func _handle_mouse_button(mb: InputEventMouseButton) -> void:
	var inside := _point_inside(mb.global_position)

	if mb.pressed and inside:
		_on_pressed()
		get_viewport().set_input_as_handled()
	elif not mb.pressed:
		_is_pointer_down = false
		_invalidate_visual_state()
		if inside:
			_on_released()
			get_viewport().set_input_as_handled()

func _handle_screen_touch(touch: InputEventScreenTouch) -> void:
	var global_pos := global_position + touch.position
	var inside := _point_inside(global_pos)

	if touch.pressed and inside:
		_on_pressed()
		get_viewport().set_input_as_handled()
	elif not touch.pressed:
		_is_pointer_down = false
		_invalidate_visual_state()
		if inside:
			_on_released()
			get_viewport().set_input_as_handled()

# ---------- Event Handlers ----------
func _on_pressed() -> void:
	if button_disabled:
		return

	_is_pointer_down = true
	_invalidate_visual_state()
	grab_focus()

	if enable_press_actions:
		emit_signal("pressed")
	if enable_toggle_actions:
		toggle_pressed = not toggle_pressed

func _on_released() -> void:
	if button_disabled:
		return
	if enable_release_actions:
		emit_signal("released")

func _on_log(type: String, message: String) -> void:
	emit_signal("log", type, message)

func _on_mouse_entered() -> void:
	if button_disabled:
		return
	_hovering = true

	if enable_hover_actions:
		emit_signal("hover_in")
		pivot_offset = size / 2.0
		_hover_target_scale = _hover_target_for_viewport()
		set_process(true)
	_invalidate_visual_state()

func _on_mouse_exited() -> void:
	if button_disabled:
		return
	_hovering = false

	if enable_hover_actions:
		emit_signal("hover_out")
		pivot_offset = size / 2.0
		_hover_target_scale = 1.0
		set_process(true)
	_invalidate_visual_state()

func _on_minimum_size_changed() -> void:
	_safe_call_deferred("_fit_label_text")

# ---------- Processing & Notifications ----------
func _process_hover_scaling(delta: float) -> void:
	if not enable_hover_actions:
		set_process(false)
		return

	pivot_offset = size / 2.0
	var target := Vector2.ONE * _hover_target_scale
	scale = scale.lerp(target, hover_lerp_speed * delta)

	if scale.distance_to(target) < 0.001:
		set_process(false)

func _handle_notifications(what: int) -> void:
	match what:
		NOTIFICATION_RESIZED:
			_fit_label_text()
			if _hovering and enable_hover_actions:
				pivot_offset = size / 2.0
				_hover_target_scale = _hover_target_for_viewport()
				set_process(true)

		NOTIFICATION_THEME_CHANGED:
			if inherit_theme_to_children and theme != null:
				_apply_theme_to_children()

			_last_visual_state = "" # Force theme refresh
			_safe_call_deferred("_apply_theme_now")
			_safe_call_deferred("_fit_label_text")

			if _hovering and enable_hover_actions:
				_hover_target_scale = _hover_target_for_viewport()
				set_process(true)

		NOTIFICATION_VISIBILITY_CHANGED:
			if not is_visible_in_tree():
				_is_pointer_down = false
				_hovering = false
				_invalidate_visual_state()

		NOTIFICATION_PREDELETE:
			_cleanup()

func _apply_theme_to_children() -> void:
	if _cached_label != null and is_instance_valid(_cached_label):
		_cached_label.theme = theme
	if _cached_icon != null and is_instance_valid(_cached_icon):
		_cached_icon.theme = theme

# ---------- UI Components (Cached) ----------
func _get_or_create_label() -> Label:
	if _cached_label == null or not is_instance_valid(_cached_label):
		_cached_label = get_node_or_null("Label")
		if _cached_label == null:
			_cached_label = _create_child_node("Label", Label)
	_configure_label(_cached_label)
	return _cached_label

func _ensure_icon() -> TextureRect:
	if _cached_icon == null or not is_instance_valid(_cached_icon):
		_cached_icon = get_node_or_null("Icon")
		if _cached_icon == null:
			_cached_icon = _create_child_node("Icon", TextureRect)
	_configure_icon(_cached_icon)
	return _cached_icon

func _create_child_node(node_name: String, node_class) -> Control:
	var node = node_class.new()
	node.name = node_name
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(node)
	return node

func _configure_label(lbl: Label) -> void:
	lbl.horizontal_alignment = horizontal_alignment
	lbl.vertical_alignment = vertical_alignment
	lbl.autowrap_mode = autowrap_mode
	if inherit_theme_to_children and theme != null:
		lbl.theme = theme

func _configure_icon(tr: TextureRect) -> void:
	tr.stretch_mode = TextureRect.STRETCH_SCALE if icon_stretch else TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE if icon_stretch else TextureRect.EXPAND_KEEP_SIZE

	if inherit_theme_to_children and theme != null:
		tr.theme = theme

# ---------- Text Fitting (Optimized) ----------
func _fit_label_text() -> void:
	if _fitting_label or _cached_label == null or not is_instance_valid(_cached_label) or _cached_label.text == "":
		return

	_fitting_label = true

	var avail := _calculate_available_area()
	if avail.x <= 1.0 or avail.y <= 1.0:
		_safe_call_deferred("_fit_label_text")
		_fitting_label = false
		return

	var fnt := _get_robust_font(_cached_label)
	if fnt == null:
		_fitting_label = false
		return

	var best_size := _find_best_font_size(fnt, _cached_label.text, avail)
	_apply_font_settings(_cached_label, fnt, best_size)

	_fitting_label = false

func _calculate_available_area() -> Vector2:
	var avail := size
	var sb: StyleBox = get_theme_stylebox("panel", theme_type_variation)
	if sb:
		avail.x -= (sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT))
		avail.y -= (sb.get_content_margin(SIDE_TOP) + sb.get_content_margin(SIDE_BOTTOM))
	return avail

static func _get_robust_font(lbl: Label) -> Font:
	var fnt: Font = lbl.get_theme_font("font")
	if fnt == null:
		fnt = lbl.get_theme_default_font()
	if fnt == null:
		fnt = ThemeDB.fallback_font
	return fnt

func _find_best_font_size(fnt: Font, text: String, avail: Vector2) -> int:
	for fs in range(max_font_size, min_font_size - 1, -1):
		var sz: Vector2 = fnt.get_multiline_string_size(
			text, HORIZONTAL_ALIGNMENT_LEFT, avail.x, fs, -1, TextServer.BREAK_WORD_BOUND
		)
		if sz.x <= avail.x + 0.1 and sz.y <= avail.y + 0.1:
			return fs
	return min_font_size

func _apply_font_settings(lbl: Label, fnt: Font, best_size: int) -> void:
	var ls := _ensure_label_settings(lbl)

	var changed := false
	if ls.font != fnt:
		ls.font = fnt
		changed = true
	if ls.font_size != best_size:
		ls.font_size = best_size
		changed = true

	if changed:
		_configure_label(lbl)
		lbl.queue_redraw()

# ---------- Visual State & Theme Management (Optimized) ----------
func _apply_visual_state() -> void:
	var current_state := _current_visual_state()
	if current_state == _last_visual_state:
		return # Skip if state hasn't changed

	_last_visual_state = current_state

	var tr := _ensure_icon()
	var use_pressed := toggle_pressed if enable_toggle_actions else _is_pointer_down
	var desired_tex: Texture2D = _pressed_texture if use_pressed and _pressed_texture != null else _normal_texture
	var desired_mat: Material = null

	if use_pressed and _pressed_texture == null and _normal_texture != null and invert_on_press_if_no_pressed_texture:
		desired_mat = _get_invert_material()

	if tr.texture != desired_tex:
		tr.texture = desired_tex
	if tr.material != desired_mat:
		tr.material = desired_mat

	_apply_text_invert_if_needed(use_pressed, desired_tex)
	_apply_theme_now()

func _apply_text_invert_if_needed(use_pressed: bool, icon_texture: Texture2D) -> void:
	if not invert_text_if_no_icon or _cached_label == null or not is_instance_valid(_cached_label):
		return

	var desired_mat = _get_invert_material() if (icon_texture == null and use_pressed) else null
	if _cached_label.material != desired_mat:
		_cached_label.material = desired_mat

func _current_visual_state() -> String:
	if button_disabled:
		return "disabled"
	if enable_toggle_actions and toggle_pressed:
		return "toggled"
	if _is_pointer_down:
		return "pressed"
	if _hovering:
		return "hover"
	return "normal"

func _apply_theme_now() -> void:
	if _theme_applying:
		return
	_theme_applying = true

	var state := _current_visual_state()

	var base_variation := _get_theme_variation(state, "base")
	if theme_type_variation != base_variation:
		theme_type_variation = base_variation

	_apply_child_theme_variations(state)
	_apply_style_box()
	_apply_state_colors(state)
	_apply_fonts()

	_theme_applying = false

func _apply_child_theme_variations(state: String) -> void:
	if _cached_label != null and is_instance_valid(_cached_label):
		var label_variation := _get_theme_variation(state, "label")
		_cached_label.theme_type_variation = label_variation if label_variation != "" else ""

	if _cached_icon != null and is_instance_valid(_cached_icon):
		var icon_variation := _get_theme_variation(state, "icon")
		_cached_icon.theme_type_variation = icon_variation
		if inherit_theme_to_children and theme != null:
			_cached_icon.theme = theme

func _apply_style_box() -> void:
	var sb: StyleBox = get_theme_stylebox(T_BG, theme_type_variation)
	if sb:
		var cur := get_theme_stylebox("panel") if has_theme_stylebox_override("panel") else null
		if cur != sb:
			add_theme_stylebox_override("panel", sb)
	else:
		if has_theme_stylebox_override("panel"):
			remove_theme_stylebox_override("panel")

func _apply_state_colors(state: String) -> void:
	var text_col := _get_state_color(state, T_TEXT_NORMAL, T_TEXT_HOVER, T_TEXT_PRESSED, T_TEXT_DISABLED, Color.WHITE)
	var icon_tint := _get_state_color(state, T_ICON_TINT_NORMAL, T_ICON_TINT_HOVER, T_ICON_TINT_PRESSED, T_ICON_TINT_DISABLED, Color.WHITE)

	if modulate != Color.WHITE:
		modulate = Color.WHITE
	# Only update colors if they've changed
	if _cached_label != null and is_instance_valid(_cached_label):
		var desired_text_color := text_col if _cached_label.material == null else Color.WHITE
		if _last_text_color != desired_text_color:
			_cached_label.modulate = desired_text_color
			_last_text_color = desired_text_color

	if _cached_icon != null and is_instance_valid(_cached_icon) and _last_icon_tint != icon_tint:
		_cached_icon.modulate = icon_tint
		_last_icon_tint = icon_tint

func _apply_fonts() -> void:
	if _cached_label == null or not is_instance_valid(_cached_label):
		return

	var fnt: Font = get_theme_font(T_FONT, theme_type_variation)
	if fnt and _cached_label.get_theme_font("font") != fnt:
		_cached_label.add_theme_font_override("font", fnt)

	var fsz: int = get_theme_font_size(T_FONT_SIZE, theme_type_variation)
	if fsz > 0 and _cached_label.get_theme_font_size("font_size") != fsz:
		_cached_label.add_theme_font_size_override("font_size", fsz)

	_safe_call_deferred("_fit_label_text")

func _get_state_color(state: String, n_key: String, h_key: String, p_key: String, d_key: String, fallback: Color) -> Color:
	var key: String
	match state:
		"hover":
			key = h_key if has_theme_color(h_key, theme_type_variation) else n_key
		"pressed":
			key = p_key if has_theme_color(p_key, theme_type_variation) else n_key
		"disabled":
			key = d_key if has_theme_color(d_key, theme_type_variation) else n_key
		_:
			key = n_key

	return get_theme_color(key, theme_type_variation) if has_theme_color(key, theme_type_variation) else fallback

func _get_theme_variation(state: String, type: String) -> String:
	var variation: String

	match [type, state]:
		["base", "hover"]: variation = base_hover_theme_variation
		["base", "pressed"]: variation = base_pressed_theme_variation
		["base", "toggled"]: variation = base_toggled_theme_variation
		["base", _]: variation = base_normal_theme_variation
		["label", "hover"]: variation = label_hover_theme_variation
		["label", "pressed"]: variation = label_pressed_theme_variation
		["label", "toggled"]: variation = label_toggled_theme_variation
		["label", _]: variation = label_normal_theme_variation
		["icon", "hover"]: variation = icon_hover_theme_variation
		["icon", "pressed"]: variation = icon_pressed_theme_variation
		["icon", "toggled"]: variation = icon_toggled_theme_variation
		["icon", _]: variation = icon_normal_theme_variation
		_: variation = ""

	return variation if variation != "" else (theme_type_name if type == "base" else _get_theme_variation(state, "base"))

# ---------- Material & Effects (Optimized) ----------
static func _get_invert_material() -> ShaderMaterial:
	if _shared_invert_mat == null:
		var shader := Shader.new()
		shader.code = """
shader_type canvas_item;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    COLOR = vec4(1.0 - c.rgb, c.a);
}"""
		_shared_invert_mat = ShaderMaterial.new()
		_shared_invert_mat.shader = shader
	return _shared_invert_mat

func _update_overlay() -> void:
	var needs_overlay := _selected or _un_selected

	if needs_overlay:
		if _cached_overlay == null or not is_instance_valid(_cached_overlay):
			_cached_overlay = get_node_or_null("Overlay")
			if _cached_overlay == null:
				_cached_overlay = _create_child_node("Overlay", ColorRect)
				move_child(_cached_overlay, get_child_count() - 1)

		var overlay_color := selected_color if _selected else un_selected_color
		if _cached_overlay.color != overlay_color:
			_cached_overlay.color = overlay_color
	elif _cached_overlay != null and is_instance_valid(_cached_overlay):
		_cached_overlay.queue_free()
		_cached_overlay = null

# ---------- Hover Calculations (Optimized) ----------
func _hover_target_for_viewport() -> float:
	var desired := hover_scale
	if desired <= scale.x:
		return desired

	var rect := get_global_rect()
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 1.0

	var vp := get_viewport_rect().size
	var center := rect.position + rect.size * 0.5
	var sc := max(scale.x, 0.0001)

	var max_scale_x: float = (2.0 * min(center.x, vp.x - center.x) * sc) / max(rect.size.x, 0.0001)
	var max_scale_y: float = (2.0 * min(center.y, vp.y - center.y) * sc) / max(rect.size.y, 0.0001)

	return min(desired, max(0.0001, min(max_scale_x, max_scale_y)))

# ---------- Utilities (Optimized) ----------
func _safe_call_deferred(method: String, args: Array = []) -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		if args.is_empty():
			call_deferred(method)
		else:
			call_deferred(method, args)

func _ensure_label_settings(lbl: Label) -> LabelSettings:
	var ls := lbl.label_settings
	if ls == null:
		ls = LabelSettings.new()
		lbl.label_settings = ls
	return ls

func _point_inside(global_point: Vector2) -> bool:
	var src := bounds_source if (is_instance_valid(bounds_source) and bounds_source != null) else self
	var rect := src.get_global_rect()
	if hit_slop != Vector2.ZERO:
		rect = rect.grow_individual(hit_slop.x, hit_slop.y, hit_slop.x, hit_slop.y)
	return rect.has_point(global_point)

func _action_allowed() -> bool:
	return has_focus() if require_focus_for_action else (has_focus() or _point_inside(get_viewport().get_mouse_position()))

func _adopt_connected_callable(sig_name: String, fallback: Callable) -> Callable:
	var conns := get_signal_connection_list(sig_name)
	for conn in conns:
		var c: Callable = conn["callable"]
		if c.get_object() != self:
			return c
	return conns[0]["callable"] if conns.size() > 0 else fallback

# ---------- Public API Methods (Optimized) ----------
func set_selected(is_selected: bool, color: Color = Color.TRANSPARENT) -> void:
	if color != Color.TRANSPARENT:
		selected_color = color
	set_selection_state(is_selected, false)

func set_un_selected(is_unselected: bool, color: Color = Color.TRANSPARENT) -> void:
	if color != Color.TRANSPARENT:
		un_selected_color = color
	set_selection_state(false, is_unselected)

func is_selected() -> bool:
	return _selected

func is_un_selected() -> bool:
	return _un_selected

func clear_selection_states() -> void:
	set_selection_state(false, false)

func refresh_overlay() -> void:
	_update_overlay()

func set_selected_with_preset(is_selected: bool, preset: String) -> void:
	var color := _preset_selected_colors.get(preset.to_lower(), Color(0.4, 0.7, 1.0, 0.7))
	set_selected(is_selected, color)

func set_un_selected_with_preset(is_unselected: bool, preset: String) -> void:
	var color := _preset_unselected_colors.get(preset.to_lower(), Color(0.0, 0.0, 0.0, 0.2))
	set_un_selected(is_unselected, color)

func set_text_alignment(h_align: HorizontalAlignment, v_align: VerticalAlignment) -> void:
	_set_alignment(h_align, v_align)

func set_theme_inheritance(enabled: bool) -> void:
	inherit_theme_to_children = enabled
	if enabled and theme != null:
		_apply_theme_to_children()
	else:
		if _cached_label != null and is_instance_valid(_cached_label):
			_cached_label.theme = null
		if _cached_icon != null and is_instance_valid(_cached_icon):
			_cached_icon.theme = null

# ---------- Built-in Fallback Behaviors ----------
func _run_built_in_pressed() -> void:
	_run_built_in_log("info", "PressedAction not set; running built-in logic for %s." % name)

func _run_built_in_toggled(button_pressed: bool) -> void:
	_run_built_in_log("info", "ToggledAction not set; running built-in logic for %s." % name)

func _run_built_in_released() -> void:
	_run_built_in_log("info", "ReleasedAction not set; running built-in logic for %s." % name)

func _run_built_in_hover_in() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE * hover_scale, hover_lerp_speed * get_process_delta_time())

func _run_built_in_hover_out() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE, hover_lerp_speed * get_process_delta_time())

static func _run_built_in_log(type: String, message: String) -> void:
	match type.to_lower():
		"error":
			push_error(message)
		"warning":
			push_warning(message)
		_:
			print(message)

# ---------- Property List & Signal Management (Optimized) ----------
static var _property_definitions := [
	["Interaction & Actions/enable_toggle_actions", TYPE_BOOL, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Text & Font/horizontal_alignment", TYPE_INT, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_ENUM, "Left,Center,Right,Fill"],
	["Text & Font/vertical_alignment", TYPE_INT, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_ENUM, "Top,Center,Bottom,Fill"],
	["Text & Font/autowrap_mode", TYPE_INT, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_ENUM, "Off,Arbitrary,Word,WordSmart"],
	["Text & Font/invert_text_if_no_icon", TYPE_BOOL, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Interaction & Actions/selected", TYPE_BOOL, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Interaction & Actions/selected_color", TYPE_VECTOR4, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Interaction & Actions/un_selected", TYPE_BOOL, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Interaction & Actions/un_selected_color", TYPE_VECTOR4, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/base_normal_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/base_hover_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/base_pressed_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/label_normal_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/label_hover_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/label_pressed_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/icon_normal_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/icon_hover_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""],
	["Theme & Visuals/icon_pressed_theme_variation", TYPE_STRING, PROPERTY_USAGE_DEFAULT, PROPERTY_HINT_NONE, ""]
]

static var _toggle_dependent_properties := [
	["Interaction & Actions/toggle_pressed", TYPE_BOOL],
	["Interaction & Actions/toggled_action", TYPE_CALLABLE],
	["Theme & Visuals/base_toggled_theme_variation", TYPE_STRING],
	["Theme & Visuals/label_toggled_theme_variation", TYPE_STRING],
	["Theme & Visuals/icon_toggled_theme_variation", TYPE_STRING]
]

func _build_property_list() -> Array:
	var list := []
	var usage := PROPERTY_USAGE_DEFAULT
	var usage_hidden := PROPERTY_USAGE_STORAGE

	# Add base properties
	for prop in _property_definitions:
		var dict := {
			"name": prop[0],
			"type": prop[1],
			"usage": prop[2]
		}
		if prop[3] != PROPERTY_HINT_NONE:
			dict["hint"] = prop[3]
			dict["hint_string"] = prop[4]
		list.append(dict)

	# Add toggle-dependent properties
	for prop in _toggle_dependent_properties:
		list.append({
			"name": prop[0],
			"type": prop[1],
			"usage": usage if enable_toggle_actions else usage_hidden
		})

	return list

func _disconnect_all_signal_handlers() -> void:
	if Engine.is_editor_hint():
		return

	# Disconnect own signals
	for sig in _own_signals:
		for conn in get_signal_connection_list(sig):
			var c: Callable = conn["callable"]
			if c.get_object() == self and is_connected(sig, c):
				disconnect(sig, c)

	# Disconnect incoming connections
	for inc in get_incoming_connections():
		var src: Object = inc.get("source")
		var sig_o: Signal = inc.get("signal")
		var sig_n: StringName = sig_o.get_name()
		var call: Callable = inc.get("callable", Callable())

		if is_instance_valid(src) and call.is_valid():
			if src.is_connected(sig_n, call):
				src.disconnect(sig_n, call)

# ---------- Deprecated/Legacy Methods for Compatibility ----------
func display_label(text: String, theme_resource: Theme = null) -> void:
	_on_log("Debug", "OmniButton: %s Setting label text to '%s'..." % [name, text])
	var lbl := _get_or_create_label()
	lbl.text = text
	lbl.theme = theme_resource if theme_resource != null else self.theme
	_safe_call_deferred("_fit_label_text")
