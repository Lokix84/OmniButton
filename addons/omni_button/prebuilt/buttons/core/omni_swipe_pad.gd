@tool
class_name OmniSwipePad
extends Omni_Button
## An [Omni_Button] that reports one direction per swipe, for dashes, card swipes and menus.
##
## [signal Omni_Button.swipe] fires again and again while the finger keeps moving; [signal swiped]
## fires once per gesture, as soon as the finger has travelled [member Omni_Button.SwipeThreshold]
## pixels, with the direction snapped to left / right / up / down (or exact, with [member four_way] off).

## One swipe happened. With [member four_way] on, [param direction] is [code]Vector2.LEFT[/code],
## [code]RIGHT[/code], [code]UP[/code] or [code]DOWN[/code]; otherwise it is the exact unit direction.
signal swiped(direction: Vector2)

## Snap each swipe to the nearest of left / right / up / down.
@export var four_way := true

var _fired := false

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	swipe.connect(_on_swipe)
	swipe_ended.connect(func(): _fired = false)

func _on_swipe(direction: Vector2) -> void:
	if _fired:
		return
	_fired = true
	swiped.emit(snap(direction) if four_way else direction)

## Nearest of left / right / up / down to [param direction].
static func snap(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP
