@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/dialogue_box.svg")
extends OmniTextWindow
class_name OmniDialogueBox
## rpg style dialogue box: speaker name, a portrait on either side, typing text and answers.
##
## a wide panel along the bottom of the screen that stays the same size the whole time. every line sets its own name and portrait so the speaker can change line to line, and an empty name or no portrait hides that part. on a line with answers the question types out on the left and the answers show up in a column on the right. long answers wrap, share one font size, and scroll if there's a lot of them.
## use it through the autoload ([method OmniDialogAutoload.say]) or drop [code]omni_dialogue_box.tscn[/code] into a scene and call the same methods on it:
## [codeblock]
## await $DialogueBox.say("Guard", "Halt! Who goes there?", "res://portraits/guard.png")
## var pick := await $DialogueBox.ask("Guard", "State your business.", ["Trade", "Leave"])
## [/codeblock]

## the [Label] with the speaker's name (type variation [code]OmniDialogName[/code]).
@onready var name_label: Label = %Name
## portrait for speakers on the left.
@onready var portrait_left: TextureRect = %PortraitLeft
## portrait for speakers on the right.
@onready var portrait_right: TextureRect = %PortraitRight
## the column on the right for answers. it shows for the whole line if the line has answers, so nothing moves when they pop in, and it scrolls if there's more than fit.
@onready var options_column: Control = %OptionsColumn

## shows one line, then closes unless another line comes right after (so a bunch of [method say] calls in a row reads as one conversation). [param portrait] is a [Texture2D] or a resource path, [param side] is [code]"left"[/code] or [code]"right"[/code].
func say(speaker: String, text: String, portrait: Variant = null, side: String = "left") -> void:
	await show_line(speaker, text, portrait, side)
	close_if_idle()

## shows a line with [param options] as answers and returns the index picked.
func ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") -> int:
	var pick := await show_line(speaker, text, portrait, side, options)
	close_if_idle()
	return pick

## shows one line and leaves the box open, call [method OmniTextWindow.close_if_idle] after the last one. returns the answer picked, or [code]-1[/code] if the line has no [param options]. [param speed] overrides [member OmniTextWindow.characters_per_second] for just this line.
func show_line(speaker: String, text: String, portrait: Variant = null, side: String = "left", options: PackedStringArray = PackedStringArray(), speed: float = 0.0) -> int:
	return await _show_text(text, options, speed, _set_speaker.bind(speaker, portrait, side))

func _layout_for_line(has_options: bool) -> void:
	options_column.visible = has_options

func _set_speaker(speaker: String, portrait: Variant, side: String) -> void:
	name_label.text = speaker
	name_label.visible = speaker != ""
	var tex := to_texture(portrait)
	var right := side.to_lower() == "right"
	portrait_left.texture = tex if not right else null
	portrait_right.texture = tex if right else null
	portrait_left.visible = tex != null and not right
	portrait_right.visible = tex != null and right
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right else HORIZONTAL_ALIGNMENT_LEFT
