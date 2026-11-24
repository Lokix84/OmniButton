@tool
class_name OmniSwipePad
extends OmniButton
## an [OmniButton] that gives you one direction per swipe, for dashes, card swipes and menus.
##
## [signal OmniButton.swipe] keeps firing over and over while the finger moves. [signal swiped]
## fires once per gesture, as soon as the finger has gone [member swipe_threshold] pixels, with the
## direction snapped to left / right / up / down (or the exact direction if [member four_way] is off).

## a swipe happened. with [member four_way] on, [param direction] is [code]Vector2.LEFT[/code],
## [code]RIGHT[/code], [code]UP[/code] or [code]DOWN[/code], otherwise it's the exact unit direction.
signal swiped(direction: Vector2)

## snaps each swipe to whichever of left / right / up / down is closest.
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

## whichever of left / right / up / down is closest to [param direction].
static func snap(direction: Vector2) -> Vector2:
	if absf(direction.x) >= absf(direction.y):
		return Vector2.RIGHT if direction.x >= 0.0 else Vector2.LEFT
	return Vector2.DOWN if direction.y >= 0.0 else Vector2.UP
