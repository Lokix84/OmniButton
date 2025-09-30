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

# ---------- Export Groups ----------
# General Settings
@export_group("General Settings")
var _button_disabled := false
@export var button_disabled: bool:
	get: return _button_disabled
	set(v):
		_button_disabled = v
		if v:
			_is_pointer_down = false
			_hovering = false
			_apply_visual_state()
			_apply_theme_now()

# ---------- Input & Hit Detection ----------
@export_group("Input & Hit Detection")
@export var action_name: String = "ui_accept"
@export var require_focus_for_action: bool = true
@export var bounds_source: Control
@export var hit_slop: Vector2 = Vector2.ZERO

# ---------- Interaction & Actions ----------
@export_group("Interaction & Actions")
# Press/Release
@export var enable_press_actions: bool = true
@export var pressed_action: Callable
@export var invert_on_press_if_no_pressed_texture := true
@export var enable_release_actions: bool = false
@export var released_action: Callable
# Toggle
@export var enable_toggle_actions: bool = false
@export var toggle_pressed: bool = false:
	set(value):
		if toggle_pressed == value:
			return
		toggle_pressed = value
		_apply_visual_state()   # live swap in editor because @tool
		if enable_toggle_actions and not Engine.is_editor_hint():
			emit_signal("toggled", toggle_pressed)
@export var toggled_action: Callable

# Hover and Scaling
@export_group("Hover and Scaling")
@export var enable_hover_actions: bool = false
@export var hover_in_action: Callable
@export var hover_out_action: Callable
@export var hover_scale: float = 1.25
@export var hover_lerp_speed: float = 25.0

# ---------- Text & Font ----------
@export_group("Text & Font")
@export var min_font_size: int = 12
@export var max_font_size: int = 100
var _text: String = ""
@export var text: String:
	get:
		return _text
	set(value):
		if typeof(value) == TYPE_NIL:
			value = ""
		var s := String(value)
		if s == _text:
			return
		_text = s
		display_label(_text)

@export_group("Icon")
@export var icon_stretch := true
@export var icon_keep_aspect := true

# ---------- Texture ----------
@export_group("Texture")
@export var texture: Texture2D:
	get:
		return normal_texture
	set(value):
		# IMPORTANT: avoid recursion here (don't write `texture = value`)
		normal_texture = value
		_ensure_icon()
		_apply_visual_state()

@export var pressed_texture: Texture2D:
	get:
		return _pressed_texture
	set(value):
		_pressed_texture = value
		_apply_visual_state()


# Colors
const T_TEXT_NORMAL      := "text_color"
const T_TEXT_HOVER       := "text_color_hover"
const T_TEXT_PRESSED     := "text_color_pressed"
const T_TEXT_DISABLED    := "text_color_disabled"

const T_ICON_TINT_NORMAL := "icon_tint"
const T_ICON_TINT_HOVER  := "icon_tint_hover"
const T_ICON_TINT_PRESSED:= "icon_tint_pressed"
const T_ICON_TINT_DISABLED:= "icon_tint_disabled"

const T_BG               := "panel" # StyleBox (optional)

# Fonts (optional—fallback to label’s theme)
const T_FONT             := "font"
const T_FONT_SIZE        := "font_size"

# Backing fields
var normal_texture: Texture2D
var _pressed_texture: Texture2D
var _is_pointer_down := false  # tracks mouse/touch down for non-toggle mode
var _invert_mat: ShaderMaterial
var _hover_target_scale := 1.0

@export_group("Theme & Visuals")
@export var theme_type_name: String = "OmniButton":
	set(v):
		theme_type_name = v
		theme_type_variation = v
		call_deferred("_apply_theme_now")

# ---------- Logging ----------
@export_group("Logging")
@export var log_action: Callable

# ---------- Private Variables ----------
var _pressed_lock := false
var _released_lock := false
var _toggled_lock := false
var _log_lock := false
var _original_scale: Vector2 = Vector2.ONE
var _hovering := false
var _theme_applying := false
var _fitting_label := false
var _msize_conn_bound := false

# ---------- Lifecycle Methods ----------
func _enter_tree() -> void:
	# Build fallbacks
	var fb_pressed   := Callable(self, "_run_built_in_pressed")
	var fb_released  := Callable(self, "_run_built_in_released")
	var fb_hover_in  := Callable(self, "_run_built_in_hover_in")
	var fb_hover_out := Callable(self, "_run_built_in_hover_out")
	var fb_toggled   := Callable(self, "_run_built_in_toggled")
	var fb_log       := Callable(self, "_run_built_in_log")

	# Adopt existing editor connections where present, otherwise use fallbacks
	pressed_action   = _adopt_connected_callable("pressed",   fb_pressed)
	released_action  = _adopt_connected_callable("released",  fb_released)
	hover_in_action  = _adopt_connected_callable("hover_in",  fb_hover_in)
	hover_out_action = _adopt_connected_callable("hover_out", fb_hover_out)
	toggled_action   = _adopt_connected_callable("toggled",   fb_toggled)
	log_action       = _adopt_connected_callable("log",       fb_log)

	if Engine.is_editor_hint():
		return

	# Only connect our fallback if the signal has no connections yet
	if get_signal_connection_list("pressed").is_empty() and pressed_action == Callable(self, "_run_built_in_pressed"):
		connect("pressed", pressed_action)
	if get_signal_connection_list("released").is_empty() and released_action == Callable(self, "_run_built_in_released"):
		connect("released", released_action)
	if get_signal_connection_list("hover_in").is_empty() and hover_in_action == Callable(self, "_run_built_in_hover_in"):
		connect("hover_in", hover_in_action)
	if get_signal_connection_list("hover_out").is_empty() and hover_out_action == Callable(self, "_run_built_in_hover_out"):
		connect("hover_out", hover_out_action)
	if get_signal_connection_list("toggled").is_empty() and toggled_action == Callable(self, "_run_built_in_toggled"):
		connect("toggled", toggled_action)
	if get_signal_connection_list("log").is_empty() and log_action == Callable(self, "_run_built_in_log"):
		connect("log",  log_action)

	# Mouse hover signals (guard duplicates)
	if not is_connected("mouse_entered", Callable(self, "_on_mouse_entered")):
		connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	if not is_connected("mouse_exited", Callable(self, "_on_mouse_exited")):
		connect("mouse_exited",  Callable(self, "_on_mouse_exited"))

func _exit_tree() -> void:
	_disconnect_all_signal_handlers()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_fit_label_text()
		if _hovering and enable_hover_actions:
			pivot_offset = size / 2.0
			_hover_target_scale = _hover_target_for_viewport()
			set_process(true)
	elif what == NOTIFICATION_THEME_CHANGED:
		call_deferred("_apply_theme_now")
		call_deferred("_fit_label_text")
		# if hovering, re-clamp target (theme/metrics might have changed)
		if _hovering and enable_hover_actions:
			_hover_target_scale = _hover_target_for_viewport()
			set_process(true)
	elif what == NOTIFICATION_VISIBILITY_CHANGED:
		if not is_visible_in_tree():
			_is_pointer_down = false
			_hovering = false
			_apply_visual_state()
	elif what == NOTIFICATION_PREDELETE:
		_disconnect_all_signal_handlers()
		return

func _ready() -> void:
	focus_mode = Control.FOCUS_ALL
	bounds_source = bounds_source if bounds_source != null else self
	theme_type_variation = theme_type_name
	_original_scale = scale
	if Engine.is_editor_hint():
		notify_property_list_changed()
	if _text != "":
		text = _text
	_apply_visual_state()
	_apply_theme_now()
	if not is_connected("minimum_size_changed", Callable(self, "_on_minimum_size_changed")):
		connect("minimum_size_changed", Callable(self, "_on_minimum_size_changed"))

func _on_minimum_size_changed() -> void:
	call_deferred("_fit_label_text")

func _process(delta: float) -> void:
	if not enable_hover_actions:
		set_process(false); return
	pivot_offset = size / 2.0
	var target := Vector2.ONE * _hover_target_scale
	scale = scale.lerp(target, hover_lerp_speed * delta)
	if scale.distance_to(target) < 0.001:
		set_process(false)

func _get_property_list() -> Array:
	var list := []
	var usage := PROPERTY_USAGE_DEFAULT
	var usage_hidden := PROPERTY_USAGE_STORAGE  # stored but not editable/visible

	list.append({
		"name": "Interaction & Actions/enable_toggle_actions",
		"type": TYPE_BOOL,
		"usage": PROPERTY_USAGE_DEFAULT
	})
	list.append({
		"name": "Interaction & Actions/toggle_pressed",
		"type": TYPE_BOOL,
		"usage": (usage if enable_toggle_actions else usage_hidden)
	})
	list.append({
		"name": "Interaction & Actions/toggled_action",
		"type": TYPE_CALLABLE,
		"usage": (usage if enable_toggle_actions else usage_hidden)
	})

	return list

# ---------- Input Handling ----------
func _unhandled_input(event: InputEvent) -> void:
	if button_disabled:
		_on_log("Warning", "CustomButton: %s Button is disabled. Ignoring unhandled input." % name)
		return

	if action_name == "":
		return

	# Press
	if event.is_action_pressed(action_name) and _action_allowed():
		_on_pressed()
		get_viewport().set_input_as_handled()
		return

	# Release
	if event.is_action_released(action_name):
		_is_pointer_down = false
		_apply_visual_state()
		if _action_allowed():
			_on_released()
			get_viewport().set_input_as_handled()

func _gui_input(event: InputEvent) -> void:
	if button_disabled:
		_on_log("Warning", "CustomButton: %s Button is disabled. Ignoring input." % name)
		return

	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				if _point_inside(mb.global_position) and not _pressed_lock:
					_on_pressed()
					get_viewport().set_input_as_handled()
					return
			else:
				# Always clear visuals on release, regardless of position
				_is_pointer_down = false
				_apply_visual_state()

				if _point_inside(mb.global_position):
					_on_released()
					get_viewport().set_input_as_handled()
				return
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var global_pos: Vector2 = self.global_position + touch.position
		if touch.pressed:
			if _point_inside(global_pos) and not _pressed_lock:
				_on_pressed()
				get_viewport().set_input_as_handled()
				return
		else:
			_is_pointer_down = false
			_apply_visual_state()

			if _point_inside(global_pos):
				_on_released()
				get_viewport().set_input_as_handled()
			return

# ---------- Hover and Scaling ----------
func _on_mouse_entered() -> void:
	if button_disabled: return
	_hovering = true
	if enable_hover_actions:
		emit_signal("hover_in")
		pivot_offset = size / 2.0
		_hover_target_scale = _hover_target_for_viewport()
		set_process(true)
	_apply_theme_now()

func _on_mouse_exited() -> void:
	if button_disabled: return
	_hovering = false
	if enable_hover_actions:
		emit_signal("hover_out")
		pivot_offset = size / 2.0
		_hover_target_scale = 1.0
		set_process(true)
	_apply_theme_now()

func _run_built_in_hover_in() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE * hover_scale, hover_lerp_speed * get_process_delta_time())

func _run_built_in_hover_out() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE / hover_scale, hover_lerp_speed * get_process_delta_time())

func _max_safe_scale_in_viewport() -> float:
	var rect := get_global_rect()                 # current (already scaled) rect
	if rect.size.x <= 0.0 or rect.size.y <= 0.0:
		return 1.0

	var vp := get_viewport_rect().size
	var center := rect.position + rect.size * 0.5

	# distances from center to viewport borders
	var left   := center.x
	var right  := vp.x - center.x
	var top    := center.y
	var bottom := vp.y - center.y

	# current uniform scale (assumes x==y; if not, use x)
	var sc := max(scale.x, 0.0001)

	# If we scale by factor f, the half-size scales linearly by (f / sc).
	# Ensure half-size <= distance to nearest border on each axis.
	var smax_x : float = (2.0 * min(left, right)  * sc) / max(rect.size.x, 0.0001)
	var smax_y : float = (2.0 * min(top,  bottom) * sc) / max(rect.size.y, 0.0001)

	return max(0.0001, min(smax_x, smax_y))

func _hover_target_for_viewport() -> float:
	var desired := hover_scale
	var safe_max := _max_safe_scale_in_viewport()

	# Allow shrinking freely; clamp only when growing.
	if desired >= scale.x:
		return min(desired, safe_max)
	return desired

# ---------- Utility Methods ----------
func display_label(text: String, theme: Theme = null) -> void:
	_on_log("Debug", "CustomButton: %s Setting label text to '%s'..." % [name, text])
	var lbl: Label = get_node_or_null("Label")
	if lbl == null or not is_instance_valid(lbl):
		_on_log("Warning", "CustomButton: %s Label is null or invalid. Creating a new label..." % name)
		lbl = Label.new()
		lbl.name = "Label"
		lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(lbl)

	lbl.text = text
	lbl.theme = theme if theme != null else self.theme
	call_deferred("_fit_label_text")

func _ensure_label_settings(lbl: Label) -> LabelSettings:
	var ls := lbl.label_settings
	if ls == null:
		ls = LabelSettings.new()
		lbl.label_settings = ls
	return ls

func _fit_label_text() -> void:
	if _fitting_label:
		return
	_fitting_label = true

	var lbl: Label = get_node_or_null("Label")
	if lbl == null or not is_instance_valid(lbl):
		_fitting_label = false
		return

	# Available content area = control size minus panel stylebox margins
	var avail := size
	var sb: StyleBox = get_theme_stylebox("panel", theme_type_variation)
	if sb:
		avail.x -= (sb.get_content_margin(SIDE_LEFT) + sb.get_content_margin(SIDE_RIGHT))
		avail.y -= (sb.get_content_margin(SIDE_TOP)  + sb.get_content_margin(SIDE_BOTTOM))

	if avail.x <= 1.0 or avail.y <= 1.0:
		call_deferred("_fit_label_text")
		_fitting_label = false
		return

	# Robust font fallback (works in editor too)
	var fnt: Font = lbl.get_theme_font("font")
	if fnt == null:
		fnt = lbl.get_theme_default_font()
	if fnt == null:
		fnt = ThemeDB.fallback_font
	if fnt == null:
		_fitting_label = false
		return

	var text := lbl.text
	if text == "":
		_fitting_label = false
		return

	# Try largest -> smallest; use MULTILINE measurement with word-bound wrapping
	var best_size := -1
	for fs in range(max_font_size, min_font_size - 1, -1):
		var sz: Vector2 = fnt.get_multiline_string_size(
			text,
			HORIZONTAL_ALIGNMENT_LEFT,   # alignment
			avail.x,                     # wrap width
			fs,                          # font size to test
			-1,                          # max lines (no limit)
			TextServer.BREAK_WORD_BOUND  # wrap on word boundaries
		)
		if sz.x <= avail.x + 0.1 and sz.y <= avail.y + 0.1:
			best_size = fs
			break

	if best_size == -1:
		best_size = min_font_size

	# Apply into LabelSettings (authoritative over theme overrides)
	var ls := _ensure_label_settings(lbl)
	if ls.font != fnt:
		ls.font = fnt
	if ls.font_size != best_size:
		ls.font_size = best_size

	# Keep the Label in wrap mode so what we measured is what is rendered
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD

	# Redraw and allow future fits
	lbl.queue_redraw()
	_fitting_label = false

func _ensure_icon(stretch := true) -> TextureRect:
	var tr: TextureRect = get_node_or_null("Icon")
	if tr == null or not is_instance_valid(tr):
		tr = TextureRect.new()
		tr.name = "Icon"
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tr)
	tr.stretch_mode = (TextureRect.STRETCH_SCALE if (stretch and icon_stretch) else TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	tr.expand_mode  = (TextureRect.EXPAND_IGNORE_SIZE if (stretch and icon_stretch) else TextureRect.EXPAND_KEEP_SIZE)
	return tr

func _apply_visual_state() -> void:
	var tr := _ensure_icon()
	if tr == null or not is_instance_valid(tr): return

	var use_pressed := toggle_pressed if enable_toggle_actions else _is_pointer_down
	var desired_tex: Texture2D = _pressed_texture if use_pressed and _pressed_texture != null else normal_texture
	var desired_mat: Material = null
	if use_pressed and _pressed_texture == null and normal_texture != null and invert_on_press_if_no_pressed_texture:
		desired_mat = _get_invert_material()

	if tr.texture != desired_tex:
		tr.texture = desired_tex
	if tr.material != desired_mat:
		tr.material = desired_mat

	_apply_theme_now()

func _current_visual_state() -> String:
	if button_disabled: return "disabled"
	if enable_toggle_actions and toggle_pressed: return "pressed"
	if _is_pointer_down: return "pressed"
	if _hovering: return "hover"
	return "normal"

func _get_state_color(state: String, n_key: String, h_key: String, p_key: String, d_key: String, fallback: Color) -> Color:
	match state:
		"hover":
			return get_theme_color(h_key, theme_type_variation) if has_theme_color(h_key, theme_type_variation) else \
				   get_theme_color(n_key, theme_type_variation) if has_theme_color(n_key, theme_type_variation) else fallback
		"pressed":
			return get_theme_color(p_key, theme_type_variation) if has_theme_color(p_key, theme_type_variation) else \
				   get_theme_color(n_key, theme_type_variation) if has_theme_color(n_key, theme_type_variation) else fallback
		"disabled":
			return get_theme_color(d_key, theme_type_variation) if has_theme_color(d_key, theme_type_variation) else \
				   get_theme_color(n_key, theme_type_variation) if has_theme_color(n_key, theme_type_variation) else fallback
		_:
			return get_theme_color(n_key, theme_type_variation) if has_theme_color(n_key, theme_type_variation) else fallback

func _apply_theme_now() -> void:
	if _theme_applying:
		return
	_theme_applying = true

	var state := _current_visual_state()
	var lbl: Label = get_node_or_null("Label")
	var tr: TextureRect = _ensure_icon(false)

	# STYLEBOX background (optional)
	var sb: StyleBox = get_theme_stylebox(T_BG, theme_type_variation)
	if sb:
		var has_override := has_theme_stylebox_override("panel")
		var cur := get_theme_stylebox("panel") if has_override else null
		if cur != sb:
			add_theme_stylebox_override("panel", sb)
	else:
		if has_theme_stylebox_override("panel"):
			remove_theme_stylebox_override("panel")

	# Colors
	var text_col  := _get_state_color(state, T_TEXT_NORMAL, T_TEXT_HOVER, T_TEXT_PRESSED, T_TEXT_DISABLED, Color.WHITE)
	var icon_tint := _get_state_color(state, T_ICON_TINT_NORMAL, T_ICON_TINT_HOVER, T_ICON_TINT_PRESSED, T_ICON_TINT_DISABLED, Color.WHITE)

	if is_instance_valid(lbl) and lbl.modulate != text_col:
		lbl.modulate = text_col
	if is_instance_valid(tr) and tr.modulate != icon_tint:
		tr.modulate = icon_tint

	# Fonts (optional)
	if is_instance_valid(lbl):
		var fnt: Font = get_theme_font(T_FONT, theme_type_variation)
		if fnt and lbl.get_theme_font("font") != fnt:
			lbl.add_theme_font_override("font", fnt)

		var fsz: int = get_theme_font_size(T_FONT_SIZE, theme_type_variation)
		if fsz > 0 and lbl.get_theme_font_size("font_size") != fsz:
			lbl.add_theme_font_size_override("font_size", fsz)

		# Refit after potential font/size change
		call_deferred("_fit_label_text")

	_theme_applying = false

func _get_invert_material() -> ShaderMaterial:
	if _invert_mat:
		return _invert_mat
	var shader := Shader.new()
	shader.code = """
		shader_type canvas_item;
		void fragment() {
			vec4 c = texture(TEXTURE, UV);
			COLOR = vec4(1.0 - c.rgb, c.a);
		}
	"""
	_invert_mat = ShaderMaterial.new()
	_invert_mat.shader = shader
	return _invert_mat

func _dynamic_font_adjust(lbl: Label, text: String) -> void:
	var available_size: Vector2 = lbl.size
	var font_size := min_font_size
	var max_size := max_font_size

	var theme_font: Font = lbl.get_theme_font("font")
	if theme_font == null:
		_on_log("Warning", "CustomButton: %s Label does not have a theme font. Using default font." % name)
		return

	while font_size <= max_size:
		var text_size: Vector2 = theme_font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1.0, font_size)
		if text_size.x > available_size.x or text_size.y > available_size.y:
			font_size -= 1
			break
		font_size += 1

	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_font_override("font", theme_font)

# ---------- Private Helpers ----------
func _point_inside(global_point: Vector2) -> bool:
	var src: Control = bounds_source if (is_instance_valid(bounds_source) and bounds_source != null) else self
	var rect: Rect2 = Rect2(src.get_global_rect())
	rect = rect.grow_individual(hit_slop.x, hit_slop.y, hit_slop.x, hit_slop.y)
	return rect.has_point(global_point)

func _action_allowed() -> bool:
	if require_focus_for_action:
		return has_focus()
	return has_focus() or _point_inside(get_viewport().get_mouse_position())

func _unlock_press() -> void:
	_pressed_lock = false

func _adopt_connected_callable(sig_name: String, fallback: Callable) -> Callable:
	var conns := get_signal_connection_list(sig_name)
	for conn in conns:
		var c: Callable = conn["callable"]
		if c.get_object() != self:
			return c
	if conns.size() > 0:
		return conns[0]["callable"]
	return fallback

func _disconnect_all_signal_handlers() -> void:
	#This is to prevent the connections from being disconnected
	#when you switch between scenes in the editor
	if Engine.is_editor_hint():
		return

	for sig in ["pressed", "toggled", "released", "log", "hover_in", "hover_out"]:
		for conn in get_signal_connection_list(sig):
			var c: Callable = conn["callable"]
			# keep editor connections to other nodes intact
			if c.get_object() == self and is_connected(sig, c):
				disconnect(sig, c)

	# Incoming (others -> you), using Signal + Callable (Godot 4)
	for inc in get_incoming_connections():
		var src    : Object = inc.get("source")
		var sig_o  : Signal = inc.get("signal")
		var sig_n  : StringName = sig_o.get_name()
		var call   : Callable =  inc.get("callable") if inc.has("callable") else Callable()

		if is_instance_valid(src) and call.is_valid():
			if src.is_connected(sig_n, call):
				src.disconnect(sig_n, call)

# Default (dispatcher) handlers
func _on_pressed() -> void:
	if _pressed_lock or button_disabled:
		return
	_pressed_lock = true

	_is_pointer_down = true
	_apply_visual_state()
	grab_focus() # optional: helps keyboard interactions

	if enable_press_actions:
		emit_signal("pressed")

	if enable_toggle_actions:
		toggle_pressed = not toggle_pressed  # setter emits `toggled`

	call_deferred("_unlock_press")

func _on_toggled(button_pressed: bool) -> void:
	if _toggled_lock or not enable_toggle_actions or button_disabled:
		return
	_toggled_lock = true
	emit_signal("toggled", button_pressed)
	call_deferred("_unlock_toggle")

func _on_released() -> void:
	if _released_lock or button_disabled:
		return
	_released_lock = true

	_is_pointer_down = false
	_apply_visual_state()

	if enable_release_actions:
		emit_signal("released")

	call_deferred("_unlock_release")

func _unlock_release() -> void:
	_released_lock = false

func _unlock_toggle() -> void:
	_toggled_lock = false

func _on_log(type: String, message: String) -> void:
	if _log_lock:
		return
	_log_lock = true
	emit_signal("log", type, message)
	call_deferred("_unlock_log")

func _unlock_log() -> void:
	_log_lock = false

# Built-in fallback behaviors
func _run_built_in_pressed() -> void:
	_run_built_in_log("info", "PressedAction not set; running built-in logic for %s." % name)

func _run_built_in_toggled(button_pressed: bool) -> void:
	_run_built_in_log("info", "ToggledAction not set; running built-in logic for %s." % name)

func _run_built_in_released() -> void:
	_run_built_in_log("info", "ReleasedAction not set; running built-in logic for %s." % name)

func _run_built_in_log(type: String, message: String) -> void:
	match type.to_lower():
		"error":
			push_error(message)
		"warning":
			push_warning(message)
		_:
			print(message)
