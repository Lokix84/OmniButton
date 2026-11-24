@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/overlay.svg")
extends CanvasLayer
class_name OmniOverlay
## the base of every dialog window. handles opening and closing, the backdrop, focus, cancel and pausing.
##
## [OmniPopup], [OmniToast], [OmniDialogueBox] and [OmniNarration] all inherit [code]omni_overlay.tscn[/code]. to make your own kind of window (a shop, an inventory, a pause screen), make a [b]New Inherited Scene[/b] from it and put your controls under [code]Root/Panel/Content[/code].
## it opens and closes with a quick animation ([method open] and [method close], you can await both), can dim the game and block clicks behind it, keeps keyboard and gamepad focus inside while it's open, closes on the cancel action, and can pause the game.
## more than one window can be open at once, like a popup over a dialogue box. the last one opened is on top. only that one reacts to cancel and keeps focus, and closing it hands focus back to the one under it.

## fires when [method open] starts, before the animation.
signal opening
## fires when the open animation is done.
signal opened
## fires when [method close] starts, before the animation.
signal closing
## fires when the window is hidden after the close animation.
signal closed
## fires from [method cancel]: the cancel action, a backdrop click (if that's on), or a call from code.
signal canceled

## how the window shows up and goes away. every animation fades too.
enum OverlayAnimation {NONE, FADE, SCALE, SLIDE_UP, SLIDE_DOWN}

@export_group("Window")
## opens as soon as the scene is ready.
@export var start_open: bool = false
## modal overlays go on the open overlay stack, so they take focus, react to cancel and can pause
## the game. non modal ones (toasts) just show and hide and never take input.
@export var modal: bool = true
## pauses the game (SceneTree.paused) while it's open. the overlay itself keeps running.
@export var pause_tree: bool = false
## scales the window to the game's resolution so it takes up the same amount of screen at any size
## (320x180, 640x360, 1920x1080...). the window is laid out for
## [b]Project Settings > omni_button/dialog/reference_size[/b] and scaled from there. turn it off to
## lay the window out in the game's own pixels.
@export var fit_to_screen: bool = true:
	set(value):
		fit_to_screen = value
		if is_node_ready():
			_fit_to_screen()
@export_group("Look")
## the look for this window. empty uses project settings > omni_button/dialog/theme.
@export var dialog_theme: OmniDialogTheme:
	set(value):
		dialog_theme = value
		if is_node_ready():
			apply_dialog_theme()
@export_group("Animation")
## animation [method open] plays.
@export var open_animation: OverlayAnimation = OverlayAnimation.FADE
## animation [method close] plays.
@export var close_animation: OverlayAnimation = OverlayAnimation.FADE
## how long the open and close animations take in seconds. [code]0[/code] shows and hides right away.
@export_range(0.0, 2.0, 0.01, "suffix:s") var animation_duration: float = 0.15
## how many pixels the panel moves for SLIDE_UP / SLIDE_DOWN.
@export var slide_distance: float = 48.0
@export_group("Backdrop")
## dims the game and blocks clicks to it while open.
@export var show_backdrop: bool = true:
	set(value):
		show_backdrop = value
		_apply_backdrop()
## color of the backdrop behind the panel.
@export var backdrop_color: Color = Color(0, 0, 0, 0.5):
	set(value):
		backdrop_color = value
		_apply_backdrop()
## clicking the backdrop (outside the panel) cancels.
@export var close_on_backdrop_click: bool = false
@export_group("Input")
## the cancel action closes the overlay (after sending canceled).
@export var close_on_cancel: bool = true
## input map action that cancels. empty turns it off.
@export var cancel_action: StringName = &"ui_cancel"
## keyboard/gamepad focus stays inside the overlay while it's the one on top.
@export var trap_focus: bool = true
@export_group("")

## open overlays, oldest first. the last one is on top.
static var _stack: Array[OmniOverlay] = []

## fires when an open/close animation ends or the next one cuts it off.
signal _animation_ended

var _is_open := false
var _tween: Tween
var _play_id := 0
## where the panel was before a slide started, so a slide that gets cut off can put it back.
var _slide_rest := Vector2.ZERO
var _sliding := false
var _focus_before_open: Control
var _last_focus_inside: Control
var _paused_tree := false
var _was_tree_paused := false

## full screen [Control] that holds the backdrop and the panel. the look's [Theme] goes on this.
@onready var root_control: Control = %Root
## full screen [ColorRect] that dims the game and blocks clicks to it.
@onready var backdrop: ColorRect = %Backdrop
## the window's panel ([PanelContainer] in the prebuilt scenes).
@onready var panel: Control = %Panel
## where a window's own controls go.
@onready var content: Control = %Content

func _ready() -> void:
	_apply_backdrop()
	apply_dialog_theme()
	if Engine.is_editor_hint():
		return
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	backdrop.gui_input.connect(_on_backdrop_gui_input)
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	if start_open:
		open.call_deferred()

## the look gets applied in the editor too so windows preview with it. take it off while the editor
## saves so the look's Theme doesn't get copied into the scene file, then put it back.
func _notification(what: int) -> void:
	if not Engine.is_editor_hint() or root_control == null:
		return
	if what == NOTIFICATION_EDITOR_PRE_SAVE:
		root_control.theme = null
	elif what == NOTIFICATION_EDITOR_POST_SAVE:
		apply_dialog_theme()

func _exit_tree() -> void:
	if Engine.is_editor_hint():
		return
	if _is_open:
		_finish_close_state()

#region Public API

## returns [code]true[/code] from [method open] until [method close] starts.
func is_open() -> bool:
	return _is_open

## returns the modal window on top (the one that reacts to cancel and keeps focus), or [code]null[/code] if none are open.
static func get_top() -> OmniOverlay:
	return null if _stack.is_empty() else _stack.back()

## returns [code]true[/code] while this is the last window opened, the one that reacts to cancel and keeps focus.
func is_top() -> bool:
	return _is_open and not _stack.is_empty() and _stack.back() == self

## shows the window and focuses its default control. you can await it, it returns once the animation's done.
func open() -> void:
	if _is_open:
		return
	_is_open = true
	if modal:
		_stack.append(self)
		var vp := get_viewport()
		_focus_before_open = vp.gui_get_focus_owner() if vp != null else null
		if vp != null and not vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
			vp.gui_focus_changed.connect(_on_gui_focus_changed)
		if pause_tree and is_inside_tree():
			_was_tree_paused = get_tree().paused
			get_tree().paused = true
			_paused_tree = true
	visible = true
	opening.emit()
	_on_open()
	if modal:
		_focus_default()
	await _play(open_animation, true)
	if _is_open:
		opened.emit()

## hides the window and gives focus back to whatever had it before. you can await it, it returns once the animation's done.
func close() -> void:
	if not _is_open:
		return
	_is_open = false
	closing.emit()
	_on_close()
	if modal:
		_release_focus_trap()
	await _play(close_animation, false)
	if _is_open:
		return # got reopened while closing
	visible = false
	_finish_close_state()
	closed.emit()

## sends [signal canceled], then closes if [member close_on_cancel] is on.
func cancel() -> void:
	if not _is_open:
		return
	canceled.emit()
	if close_on_cancel:
		close()

#endregion

## returns the look being used: [member dialog_theme], or the project default.
func get_dialog_theme() -> OmniDialogTheme:
	return dialog_theme if dialog_theme != null else OmniDialogTheme.get_default()

## applies the current look. its [Theme] goes on [member root_control], then the window's own [code]OmniButton[/code] parts get styled.
func apply_dialog_theme() -> void:
	var t := get_dialog_theme()
	if t == null or root_control == null:
		return
	root_control.theme = t.theme
	_on_dialog_theme(t)

## project setting with the screen size the windows are laid out for.
const REFERENCE_SIZE_SETTING := "omni_button/dialog/reference_size"
## the screen size the prebuilt windows are laid out for.
const DEFAULT_REFERENCE_SIZE := Vector2i(1152, 648)

## returns the screen size windows are laid out for: [b]Project Settings > omni_button/dialog/reference_size[/b]
## ([code](0, 0)[/code] turns scaling off for every window).
static func get_reference_size() -> Vector2:
	return Vector2(ProjectSettings.get_setting(REFERENCE_SIZE_SETTING, DEFAULT_REFERENCE_SIZE))

## returns how much the window is scaled to fit the game's resolution (1 if it isn't).
func get_screen_scale() -> float:
	return scale.x

## scales the layer so a window laid out for the reference size takes up the same amount of screen,
## and sizes [member root_control] to cover the whole screen at that scale.
func _fit_to_screen() -> void:
	if Engine.is_editor_hint() or root_control == null or not is_inside_tree():
		return
	var screen := get_viewport().get_visible_rect().size
	var reference := get_reference_size()
	var s := 1.0
	if fit_to_screen and reference.x > 0.0 and reference.y > 0.0 and screen.x > 0.0 and screen.y > 0.0:
		s = minf(screen.x / reference.x, screen.y / reference.y)
	scale = Vector2(s, s)
	if is_equal_approx(s, 1.0):
		root_control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		return
	root_control.set_anchors_preset(Control.PRESET_TOP_LEFT)
	root_control.position = Vector2.ZERO
	root_control.size = screen / s

#region Hooks for window scenes

## runs when a look gets applied. style the window's OmniButton parts here.
func _on_dialog_theme(_t: OmniDialogTheme) -> void:
	pass

## runs when opening, before the animation. fill in the content here.
func _on_open() -> void:
	pass

## runs when closing, before the animation.
func _on_close() -> void:
	pass

## the control that gets focus on open. by default it's the first focusable control inside %Content.
func _get_default_focus() -> Control:
	var chain := _get_focus_chain()
	return chain[0] if not chain.is_empty() else null

## focusable controls inside the overlay, in tab order. by default it's the visible controls under
## %Content whose focus_mode isn't FOCUS_NONE, in tree order.
func _get_focus_chain() -> Array[Control]:
	var out: Array[Control] = []
	_collect_focusable(content, out)
	return out

#endregion

#region Focus

func _collect_focusable(node: Node, out: Array[Control]) -> void:
	for child in node.get_children():
		var c := child as Control
		if c == null:
			continue
		if not c.visible:
			continue
		if c.focus_mode != Control.FOCUS_NONE:
			out.append(c)
		_collect_focusable(c, out)

## focuses the default control and loops Tab / Shift+Tab around the focus chain.
## arrow key navigation is left up to godot, and if focus leaves the overlay it gets pulled back.
func _focus_default() -> void:
	var chain := _get_focus_chain()
	for i in chain.size():
		var c := chain[i]
		c.focus_next = c.get_path_to(chain[(i + 1) % chain.size()])
		c.focus_previous = c.get_path_to(chain[(i - 1 + chain.size()) % chain.size()])
	var target := _get_default_focus()
	if target != null and target.is_inside_tree():
		target.grab_focus()
		_last_focus_inside = target

## focuses the default control again, for windows that change what's in them while open.
func refresh_focus() -> void:
	if not _is_open or not modal:
		return
	_focus_default()

func _is_inside(c: Control) -> bool:
	return c != null and (c == root_control or root_control.is_ancestor_of(c))

func _on_gui_focus_changed(c: Control) -> void:
	if not _is_open or not trap_focus or not is_top():
		return
	if _is_inside(c):
		_last_focus_inside = c
		return
	# focus left the overlay, pull it back.
	var back := _last_focus_inside if is_instance_valid(_last_focus_inside) and _last_focus_inside.is_visible_in_tree() else _get_default_focus()
	if back != null and back.is_inside_tree():
		back.grab_focus.call_deferred()

func _release_focus_trap() -> void:
	var vp := get_viewport()
	if vp != null:
		var focused := vp.gui_get_focus_owner()
		if _is_inside(focused):
			focused.release_focus()
	# give focus back to whatever had it before, unless another overlay opened on top since then.
	var restore := _focus_before_open
	_focus_before_open = null
	_last_focus_inside = null
	_stack.erase(self)
	if not _stack.is_empty():
		var top: OmniOverlay = _stack.back()
		if is_instance_valid(restore) and top._is_inside(restore) and restore.is_visible_in_tree():
			restore.grab_focus()
		else:
			top.refresh_focus()
	elif is_instance_valid(restore) and restore.is_visible_in_tree():
		restore.grab_focus()

func _finish_close_state() -> void:
	_stack.erase(self)
	var vp := get_viewport()
	if vp != null and vp.gui_focus_changed.is_connected(_on_gui_focus_changed):
		vp.gui_focus_changed.disconnect(_on_gui_focus_changed)
	if _paused_tree and is_inside_tree():
		get_tree().paused = _was_tree_paused
	_paused_tree = false

#endregion

#region Input

func _unhandled_input(event: InputEvent) -> void:
	if not is_top():
		return
	if cancel_action != &"" and InputMap.has_action(cancel_action) and event.is_action_pressed(cancel_action):
		get_viewport().set_input_as_handled()
		cancel()

func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not close_on_backdrop_click or not is_top():
		return
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		backdrop.accept_event()
		cancel()
	elif event is InputEventScreenTouch and event.pressed:
		backdrop.accept_event()
		cancel()

#endregion

#region Visuals

func _apply_backdrop() -> void:
	if backdrop == null:
		backdrop = get_node_or_null("%Backdrop")
		if backdrop == null:
			return
	backdrop.visible = show_backdrop
	backdrop.color = backdrop_color
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP if show_backdrop else Control.MOUSE_FILTER_IGNORE

## runs the open/close animation and returns when it ends or another one cuts it off.
func _play(anim: OverlayAnimation, showing: bool) -> void:
	_play_id += 1
	var id := _play_id
	_stop_animation()
	if anim == OverlayAnimation.NONE or animation_duration <= 0.0:
		return
	var from_alpha := 0.0 if showing else 1.0
	root_control.modulate.a = from_alpha
	# containers might not have sized the panel yet on the first open.
	if panel.size == Vector2.ZERO:
		await get_tree().process_frame
		if id != _play_id:
			return
	panel.pivot_offset = panel.size * 0.5
	var d := animation_duration
	_tween = create_tween().set_parallel(true).set_ease(Tween.EASE_OUT if showing else Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# every animation fades, so the backdrop fades with the panel.
	_tween.tween_property(root_control, "modulate:a", 1.0 - from_alpha, d)
	match anim:
		OverlayAnimation.SCALE:
			var small := Vector2(0.9, 0.9)
			panel.scale = small if showing else Vector2.ONE
			_tween.tween_property(panel, "scale", Vector2.ONE if showing else small, d)
		OverlayAnimation.SLIDE_UP, OverlayAnimation.SLIDE_DOWN:
			var dir := 1.0 if anim == OverlayAnimation.SLIDE_UP else -1.0
			_slide_rest = panel.position
			_sliding = true
			var off := _slide_rest + Vector2(0, slide_distance * dir)
			panel.position = off if showing else _slide_rest
			_tween.tween_property(panel, "position", _slide_rest if showing else off, d)
	_tween.finished.connect(_animation_ended.emit)
	await _animation_ended
	if id != _play_id:
		return # a newer animation took over and it owns the visuals now
	_tween = null
	_end_slide()
	_reset_visuals()

func _stop_animation() -> void:
	var cut_short := _tween != null and _tween.is_valid()
	if cut_short:
		_tween.kill()
	_tween = null
	_end_slide()
	_reset_visuals()
	if cut_short:
		_animation_ended.emit() # lets the open()/close() that's waiting carry on

func _end_slide() -> void:
	if _sliding:
		panel.position = _slide_rest
		_sliding = false

func _reset_visuals() -> void:
	root_control.modulate.a = 1.0
	panel.scale = Vector2.ONE

#endregion
