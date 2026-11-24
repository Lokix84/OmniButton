@tool
class_name OmniMenuStylizer
extends Node
## makes a menu into the full screen stylized version. put it as a child of an [OmniMenu] or
## [OmniOptionsMenu] scene. it colors [member bands] with the look's [b]Stylized Menus[/b] colors, sets
## the title and items in a bold slanted font, puts a slanted [member OmniDialogTheme.accent_color]
## shape behind the selected item, and plays the entrance where the bands sweep in and the items pop
## in one after another. the menu itself (items, signals, input, pausing) works exactly the same.

## the angled background.
@export var bands: OmniMenuBands
## the menu title to put in the big slanted font. optional.
@export var title_label: Label
## the panel to draw as a dark slanted plate (the options screen). optional.
@export var plate_panel: PanelContainer

@export_group("Type")
## size of the title text.
@export_range(12, 200, 1) var title_size := 84
## size of the item text.
@export_range(8, 120, 1) var item_size := 38
## how far the text and the highlight lean (0 is straight up).
@export_range(0.0, 0.6, 0.01) var slant := 0.2
## how bold the default font gets (does nothing if the look has its own menu_font).
@export_range(0.0, 2.0, 0.05) var embolden := 0.9
## width and height of each item.
@export var item_size_px := Vector2(380, 58)

@export_group("Motion")
## seconds for the bands to sweep in. the menu's animation_duration at 0 skips all the motion.
@export_range(0.0, 2.0, 0.01) var sweep_time := 0.4
## delay between each item showing up.
@export_range(0.0, 0.5, 0.01) var stagger := 0.05
## how much the selected item grows when it gets selected.
@export_range(1.0, 1.5, 0.01) var select_pop := 1.08

var _overlay: OmniOverlay
var _font: Font
var _tween: Tween

func _ready() -> void:
	_overlay = get_parent() as OmniOverlay
	if _overlay == null:
		push_warning("OmniMenuStylizer must be a child of a menu (an OmniOverlay).")
		return
	# children are ready before their parent, so wait for the menu to know its items.
	if not _overlay.is_node_ready():
		await _overlay.ready
	apply_look()
	if Engine.is_editor_hint():
		return
	_overlay.opening.connect(_on_opening)
	_overlay.closing.connect(_on_closing)
	for b in _items():
		b.focus_entered.connect(_on_item_selected.bind(b))
		b.mouse_entered.connect(_on_item_selected.bind(b))
		b.focus_exited.connect(func(): _set_item_text(b, b.is_hovering))
		b.mouse_exited.connect(func(): _set_item_text(b, b.has_focus()))

## puts the look's colors and fonts on again (runs when the menu opens).
func apply_look() -> void:
	if _overlay == null or not is_instance_valid(_overlay):
		return
	var t := _overlay.get_dialog_theme()
	if t == null:
		return
	_font = t.menu_font if t.menu_font != null else _slanted_font(t)
	if bands != null:
		bands.background_color = t.menu_background_color
		bands.band_color = t.menu_band_color
		bands.accent_color = t.accent_color
	if title_label != null:
		title_label.add_theme_font_override("font", _font)
		title_label.add_theme_font_size_override("font_size", title_size)
		title_label.add_theme_color_override("font_color", t.menu_text_color)
		title_label.add_theme_color_override("font_shadow_color", Color(t.accent_color, 0.9))
		title_label.add_theme_constant_override("shadow_offset_x", 5)
		title_label.add_theme_constant_override("shadow_offset_y", 5)
	if plate_panel != null:
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(t.menu_background_color, 0.94)
		plate.border_width_left = 8
		plate.border_color = t.accent_color
		plate.skew = Vector2(slant * 0.25, 0)
		plate.set_content_margin_all(26)
		plate.content_margin_left = 40
		plate_panel.add_theme_stylebox_override("panel", plate)
	for b in _items():
		_style_item(b, t)

## a bold slanted copy of the look's default font.
func _slanted_font(t: OmniDialogTheme) -> Font:
	var base: Font = null
	if t.theme != null and t.theme.default_font != null:
		base = t.theme.default_font
	if base == null:
		base = ThemeDB.fallback_font
	var f := FontVariation.new()
	f.base_font = base
	f.variation_embolden = embolden
	f.variation_transform = Transform2D(Vector2(1, 0), Vector2(-slant, 1), Vector2.ZERO)
	return f

func _style_item(b: OmniButton, t: OmniDialogTheme) -> void:
	b.custom_minimum_size = item_size_px
	b.label_font = _font
	b.fixed_font_size = item_size
	b.label_horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.label_padding = Vector2(28, 0)
	b.panel_style_box = StyleBoxEmpty.new()
	var highlight := StyleBoxFlat.new()
	highlight.bg_color = t.accent_color
	highlight.skew = Vector2(slant * 1.5, 0)
	highlight.shadow_color = Color(0, 0, 0, 0.5)
	highlight.shadow_size = 1
	highlight.shadow_offset = Vector2(6, 6)
	var pressed := highlight.duplicate() as StyleBoxFlat
	pressed.bg_color = t.accent_color.lightened(0.25)
	b.panel_hover_style_box = highlight
	b.panel_focus_style_box = highlight
	b.panel_pressed_style_box = pressed
	b.set_meta(&"_omni_text", t.menu_text_color)
	b.set_meta(&"_omni_text_selected", t.accent_text_color)
	_set_item_text(b, b.has_focus())

func _on_item_selected(b: OmniButton) -> void:
	_set_item_text(b, true)
	if select_pop > 1.0 and _motion() > 0.0:
		b.pivot_offset = Vector2(0, b.size.y * 0.5)
		b.scale = Vector2.ONE * select_pop
		create_tween().tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## text color for a selected (focused or hovered) item, or a normal one.
func _set_item_text(b: OmniButton, selected: bool) -> void:
	var color: Color = b.get_meta(&"_omni_text_selected" if selected else &"_omni_text", Color.WHITE)
	if b.label_text_color != color:
		b.label_text_color = color

func _on_opening() -> void:
	apply_look()
	var m := _motion()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if m <= 0.0:
		if bands != null:
			bands.progress = 1.0
		return
	_tween = create_tween().set_parallel(true)
	if bands != null:
		bands.progress = 0.0
		_tween.tween_property(bands, "progress", 1.0, sweep_time * m)
	if title_label != null:
		title_label.modulate.a = 0.0
		_tween.tween_property(title_label, "modulate:a", 1.0, 0.2 * m).set_delay(0.12 * m)
	var i := 0
	for b in _items():
		if not b.visible:
			continue
		b.modulate.a = 0.0
		_tween.tween_property(b, "modulate:a", 1.0, 0.18 * m).set_delay((0.15 + i * stagger) * m)
		i += 1

func _on_closing() -> void:
	var m := _motion()
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if m <= 0.0 or bands == null:
		return
	_tween = create_tween()
	_tween.tween_property(bands, "progress", 0.0, _overlay.animation_duration)

## motion scale. 0 when the menu's animation_duration is 0 (no motion), otherwise 1.
func _motion() -> float:
	return 0.0 if _overlay == null or _overlay.animation_duration <= 0.0 else 1.0

func _items() -> Array[OmniButton]:
	if _overlay is OmniMenu and not (_overlay as OmniMenu).style_items:
		return (_overlay as OmniMenu).get_items()
	return []
