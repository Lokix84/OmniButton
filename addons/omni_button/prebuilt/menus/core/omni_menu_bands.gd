@tool
class_name OmniMenuBands
extends Control
## the angled background behind the stylized menus. bold slanted bands with a thin accent stripe,
## drawn in code so they stay sharp at any size. [member progress] sweeps them in (0 is off screen
## to the left, 1 is in place), and [OmniMenuStylizer] animates it when the menu opens and closes.

enum Shape {
	FULL, ## covers the whole screen: a solid background with slanted bands across it (title, options).
	SPLIT, ## a slanted plate over the left side of the screen, the rest stays see through (pause).
}

@export var shape: Shape = Shape.FULL:
	set(value):
		shape = value
		queue_redraw()
@export var background_color := Color(0.05, 0.06, 0.09):
	set(value):
		background_color = value
		queue_redraw()
@export var band_color := Color(0.11, 0.15, 0.25):
	set(value):
		band_color = value
		queue_redraw()
@export var accent_color := Color(0.36, 0.55, 0.9):
	set(value):
		accent_color = value
		queue_redraw()
## how far the bands have swept in. 0 is gone, 1 is in place.
@export_range(0.0, 1.0, 0.01) var progress := 1.0:
	set(value):
		progress = value
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	var t := ease(clampf(progress, 0.0, 1.0), 0.35)
	match shape:
		Shape.FULL:
			var bg := background_color
			bg.a *= t
			draw_rect(Rect2(Vector2.ZERO, size), bg)
			var off := -(1.0 - t) * w * 1.3
			# a darker band behind, a wide main band, and a thin accent stripe along its edge.
			_quad(off * 1.15, [0.30, 0.66, 0.74, 0.38], band_color.darkened(0.45), w, h)
			_quad(off, [-0.04, 0.34, 0.60, 0.22], band_color, w, h)
			_quad(off, [0.22, 0.60, 0.615, 0.235], accent_color, w, h)
			_quad(off * 0.85, [0.80, 1.06, 1.10, 0.84], band_color.darkened(0.2), w, h)
		Shape.SPLIT:
			var off := -(1.0 - t) * w * 0.75
			var plate := background_color
			plate.a = 0.94
			draw_colored_polygon(PackedVector2Array([Vector2(off, 0), Vector2(0.56 * w + off, 0),
				Vector2(0.44 * w + off, h), Vector2(off, h)]), plate)
			_quad(off, [0.44, 0.56, 0.60, 0.48], band_color, w, h)
			_quad(off, [0.48, 0.60, 0.61, 0.49], accent_color, w, h)

## one slanted band. [param x] has the bottom left, top left, top right and bottom right x positions
## as fractions of the width.
func _quad(off: float, x: Array, color: Color, w: float, h: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(x[0] * w + off, h), Vector2(x[1] * w + off, 0),
		Vector2(x[2] * w + off, 0), Vector2(x[3] * w + off, h)]), color)
