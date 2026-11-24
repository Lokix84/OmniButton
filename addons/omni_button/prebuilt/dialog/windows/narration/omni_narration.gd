@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/narration.svg")
extends OmniTextWindow
class_name OmniNarration
## Full-screen narration: centered typing text over an opaque backdrop, with an optional background image.
##
## Clicking anywhere moves on. A line without a background keeps the one already showing; the background is cleared when narration closes.
## [codeblock]
## await $Narration.narrate("The city of Vell.", "res://backgrounds/vell.png")
## await $Narration.narrate("Three days after the fire...")
## [/codeblock]

## [TextureRect] for the background image (cover-scaled).
@onready var background: TextureRect = %Background
## Dark layer over the background so the text stays readable.
@onready var shade: Control = %Shade

## Shows one narration line, then closes unless another line follows straight away. [param background_image] is a [Texture2D] or a resource path; [code]null[/code] keeps the current one.
func narrate(text: String, background_image: Variant = null) -> void:
	await show_text(text, background_image)
	close_if_idle()

## Shows one narration line and leaves narration open; call [method OmniTextWindow.close_if_idle] after the last one. Returns the answer picked, or [code]-1[/code] when there are no [param options].
func show_text(text: String, background_image: Variant = null, options: PackedStringArray = PackedStringArray(), speed: float = 0.0) -> int:
	return await _show_text(text, options, speed, _set_background.bind(background_image))

func _set_background(image: Variant) -> void:
	var tex := to_texture(image)
	if tex != null:
		background.texture = tex
	background.visible = background.texture != null
	shade.visible = background.visible

func _on_close() -> void:
	super()
	background.texture = null

## Anywhere on the screen counts as the body.
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not is_top():
		return
	var mb := event as InputEventMouseButton
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		backdrop.accept_event()
		advance()
