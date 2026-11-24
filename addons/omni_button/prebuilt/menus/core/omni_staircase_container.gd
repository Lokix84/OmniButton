@tool
class_name OmniStaircaseContainer
extends Container
## Stacks its children like a [VBoxContainer], shifting each one sideways by [member step], so a list
## follows a slant (the stylized menus line their items up with the angled bands).

## Space between items.
@export var separation := 6.0:
	set(value):
		separation = value
		queue_sort()
## Sideways shift per item: negative moves each lower item left, positive right.
@export var step := -18.0:
	set(value):
		step = value
		queue_sort()

func _notification(what: int) -> void:
	if what == NOTIFICATION_SORT_CHILDREN:
		var shown := _shown_children()
		var shift_total := absf(step) * maxf(0.0, shown.size() - 1)
		var y := 0.0
		for i in shown.size():
			var c: Control = shown[i]
			var ms := c.get_combined_minimum_size()
			var x := (i * step) if step >= 0.0 else (shift_total + i * step)
			fit_child_in_rect(c, Rect2(x, y, maxf(ms.x, size.x - shift_total), ms.y))
			y += ms.y + separation

func _get_minimum_size() -> Vector2:
	var shown := _shown_children()
	var w := 0.0
	var h := 0.0
	for c: Control in shown:
		var ms := c.get_combined_minimum_size()
		w = maxf(w, ms.x)
		h += ms.y
	h += separation * maxf(0.0, shown.size() - 1)
	return Vector2(w + absf(step) * maxf(0.0, shown.size() - 1), h)

func _shown_children() -> Array[Control]:
	var out: Array[Control] = []
	for c in get_children():
		if c is Control and c.visible and not c.top_level:
			out.append(c)
	return out
