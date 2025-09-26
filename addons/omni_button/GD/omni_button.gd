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

# ---------- Enums ----------
enum ButtonType {
	BUTTON,
	TOGGLE
}

# ---------- Export Groups ----------
# General Settings
@export_group("General Settings")
@export var type: ButtonType = ButtonType.BUTTON
@export var button_disabled: bool = false

# Input Settings
@export_group("Input Settings")
@export var action_name: String = "ui_accept"
@export var require_focus_for_action: bool = true

# Bounds and Hit Detection
@export_group("Bounds and Hit Detection")
@export var bounds_source: Control
@export var hit_slop: Vector2 = Vector2.ZERO

# Press Actions
@export_group("Press Actions")
@export var enable_press_actions: bool = true
@export var pressed_action: Callable
@export var enable_release_actions: bool = false
@export var released_action: Callable

# Toggle Actions
@export_group("Toggle Actions")
@export var enable_toggle_actions: bool = false
@export var toggled_action: Callable

# Hover and Scaling
@export_group("Hover and Scaling")
@export var enable_hover_actions: bool = false
@export var hover_in_action: Callable
@export var hover_out_action: Callable
@export var hover_scale: float = 1.25
@export var hover_lerp_speed: float = 25.0

# Font Size Settings
@export_group("Font Size Settings")
@export var min_font_size: int = 12
@export var max_font_size: int = 100

# Logging
@export_group("Logging")
@export var log_action: Callable

# ---------- Private Variables ----------
var _pressed_lock := false
var _released_lock := false
var _toggled_lock := false
var _log_lock := false
var _original_scale: Vector2 = Vector2.ONE

# ---------- Lifecycle Methods ----------
func _enter_tree() -> void:
	# Initialize default actions to built-ins
	pressed_action = Callable(self, "_run_built_in_pressed")
	released_action = Callable(self, "_run_built_in_released")
	hover_in_action = Callable(self, "_run_built_in_hover_in")
	hover_out_action = Callable(self, "_run_built_in_hover_out")
	toggled_action = Callable(self, "_run_built_in_toggled")
	log_action = Callable(self, "_run_built_in_log")

	# Manage signal connections via helper
	connect_signal("pressed", pressed_action)
	connect_signal("released", released_action)
	connect_signal("toggled", toggled_action)
	connect_signal("log", log_action)
	connect_signal("hover_in", hover_in_action)
	connect_signal("hover_out", hover_out_action)

	# Mouse hover signals
	connect("mouse_entered", Callable(self, "_on_mouse_entered"))
	connect("mouse_exited", Callable(self, "_on_mouse_exited"))

func _exit_tree() -> void:
	_disconnect_all_local_signal_handlers()

func _ready() -> void:
	bounds_source = bounds_source if bounds_source != null else self
	_original_scale = scale
	if Engine.is_editor_hint():
		notify_property_list_changed()

# ---------- Input Handling ----------
func _unhandled_input(event: InputEvent) -> void:
	if button_disabled:
		_on_log("Warning", "CustomButton: %s Button is disabled. Ignoring unhandled input." % name)
		return

	if action_name != "" and event.is_action_pressed(action_name) and _action_allowed():
		_on_pressed()
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
				if _point_inside(mb.global_position):
					_on_released()
					get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var global_pos: Vector2 = self.get_global_position() + touch.position
		if touch.pressed:
			if _point_inside(global_pos) and not _pressed_lock:
				_on_pressed()
				get_viewport().set_input_as_handled()
				return
		else:
			if _point_inside(global_pos):
				_on_released()
				get_viewport().set_input_as_handled()

# ---------- Hover and Scaling ----------
func _on_mouse_entered() -> void:
	if not enable_hover_actions or button_disabled:
		return
	emit_signal("hover_in")

func _on_mouse_exited() -> void:
	if not enable_hover_actions or button_disabled:
		return
	emit_signal("hover_out")

func _run_built_in_hover_in() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE * hover_scale, hover_lerp_speed * get_process_delta_time())

func _run_built_in_hover_out() -> void:
	pivot_offset = size / 2.0
	scale = scale.lerp(Vector2.ONE / hover_scale, hover_lerp_speed * get_process_delta_time())

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

	# Use provided theme or this control's theme
	if theme != null:
		lbl.theme = theme
	else:
		lbl.theme = self.theme

	_dynamic_font_adjust(lbl, text)

func display_texture(texture_path: String, stretch: bool = true) -> void:
	var tex: Texture2D = load(texture_path)
	display_texture_tex(tex, stretch)

func display_texture_tex(texture: Texture2D, stretch: bool = true) -> void:
	_on_log("Debug", "CustomButton: %s Setting texture..." % name)
	var tr: TextureRect = get_node_or_null("Icon")
	if tr == null or not is_instance_valid(tr):
		_on_log("Warning", "CustomButton: %s Icon is null or invalid. Creating a new texture rect..." % name)
		tr = TextureRect.new()
		tr.name = "Icon"
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tr.set_anchors_preset(Control.PRESET_FULL_RECT)
		add_child(tr)

	tr.stretch_mode = (TextureRect.STRETCH_SCALE if stretch else TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	tr.expand_mode = (TextureRect.EXPAND_IGNORE_SIZE if stretch else TextureRect.EXPAND_KEEP_SIZE)
	tr.texture = texture

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
	var src: Control = bounds_source if bounds_source != null else self
	var rect: Rect2 = Rect2(src.get_global_rect()) # ensure Rect2 (not Rect2i)
	rect = rect.grow_individual(hit_slop.x, hit_slop.y, hit_slop.x, hit_slop.y)
	return rect.has_point(global_point)

func _action_allowed() -> bool:
	if require_focus_for_action:
		return has_focus()
	return has_focus() or _point_inside(get_viewport().get_mouse_position())

func _unlock_press() -> void:
	_pressed_lock = false

func connect_signal(signal_name: String, new_callable: Callable) -> void:
	if signal_name == "":
		push_error("CustomButton: %s Signal name cannot be null or empty." % name)
		return

	var current_callable: Callable = Callable()

	match signal_name:
		"pressed":
			current_callable = pressed_action
		"released":
			current_callable = released_action
		"toggled":
			current_callable = toggled_action
		"hover_in":
			current_callable = hover_in_action
		"hover_out":
			current_callable = hover_out_action
		"log":
			current_callable = log_action
		_:
			push_error("CustomButton: %s Invalid signal name '%s'." % [name, signal_name])
			return

	# Disconnect old callable if present
	if is_connected(signal_name, current_callable):
		disconnect(signal_name, current_callable)

	# Connect new callable if valid
	if new_callable.is_valid():
		connect(signal_name, new_callable)

		match signal_name:
			"pressed":
				pressed_action = new_callable
			"released":
				released_action = new_callable
			"toggled":
				toggled_action = new_callable
			"log":
				log_action = new_callable
			"hover_in":
				hover_in_action = new_callable
			"hover_out":
				hover_out_action = new_callable
	else:
		push_warning("CustomButton: %s New callable for signal '%s' is null or invalid. Signal will be disconnected." % [name, signal_name])

func _disconnect_all_local_signal_handlers() -> void:
	for sig in ["pressed", "toggled", "released", "log", "hover_in", "hover_out"]:
		for conn in get_signal_connection_list(sig):
			var callable: Callable = conn["callable"]
			if callable.get_object() == self and is_connected(sig, callable):
				disconnect(sig, callable)

# Default (dispatcher) handlers
func _on_pressed() -> void:
	if _pressed_lock or not enable_press_actions or button_disabled:
		return
	_pressed_lock = true
	emit_signal("pressed")
	call_deferred("_unlock_press")

func _on_toggled(button_pressed: bool) -> void:
	if _toggled_lock or not enable_toggle_actions or button_disabled:
		return
	_toggled_lock = true
	emit_signal("toggled", button_pressed)
	call_deferred("_unlock_toggle")

func _on_released() -> void:
	if _released_lock or not enable_release_actions or button_disabled:
		return
	_released_lock = true
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		var lbl: Label = get_node_or_null("Label")
		if lbl != null and is_instance_valid(lbl):
			_dynamic_font_adjust(lbl, lbl.text)
