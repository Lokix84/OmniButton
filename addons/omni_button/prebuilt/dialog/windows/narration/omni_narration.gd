@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/narration.svg")
extends OmniTextWindow
class_name OmniNarration
## full screen narration: centered typing text over a solid backdrop, with a background image if you want one.
##
## clicking anywhere moves on. a line without a background keeps whatever one is already showing, and the background gets cleared when narration closes.
## [codeblock]
## await $Narration.narrate("The city of Vell.", "res://backgrounds/vell.png")
## await $Narration.narrate("Three days after the fire...")
## [/codeblock]

## the [TextureRect] for the background image (scaled to cover).
@onready var background: TextureRect = %Background
## dark layer over the background so the text stays readable.
@onready var shade: Control = %Shade

## shows one narration line, then closes unless another line comes right after. [param background_image] is a [Texture2D] or a resource path, [code]null[/code] keeps the current one.
func narrate(text: String, background_image: Variant = null) -> void:
	await show_text(text, background_image)
	close_if_idle()

## shows one narration line and leaves narration open, call [method OmniTextWindow.close_if_idle] after the last one. returns the answer picked, or [code]-1[/code] if there are no [param options].
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

## anywhere on the screen counts as the body.
func _on_backdrop_gui_input(event: InputEvent) -> void:
	if not is_top():
		return
	var mb := event as InputEventMouseButton
	if (mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT) or (event is InputEventScreenTouch and event.pressed):
		backdrop.accept_event()
		advance()
