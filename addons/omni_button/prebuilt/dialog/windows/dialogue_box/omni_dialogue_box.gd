@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/dialogue_box.svg")
extends OmniTextWindow
class_name OmniDialogueBox
## RPG-style dialogue box: speaker name, portrait on either side, typing text and answers.
##
## A wide panel along the bottom of the screen that keeps the same size the whole time. Every line sets its own name and portrait, so the speaker can change from line to line; an empty name or no portrait hides that part. On a line with answers, the question types out on the left and the answers appear in a column on the right; long answers wrap, share one font size, and scroll if there are many.
## Use it through the autoload ([method OmniDialogAutoload.say]) or drop [code]omni_dialogue_box.tscn[/code] into a scene and call the same methods on it:
## [codeblock]
## await $DialogueBox.say("Guard", "Halt! Who goes there?", "res://portraits/guard.png")
## var pick := await $DialogueBox.ask("Guard", "State your business.", ["Trade", "Leave"])
## [/codeblock]

## [Label] showing the speaker's name (type variation [code]OmniDialogName[/code]).
@onready var name_label: Label = %Name
## Portrait shown for speakers on the left.
@onready var portrait_left: TextureRect = %PortraitLeft
## Portrait shown for speakers on the right.
@onready var portrait_right: TextureRect = %PortraitRight
## Right-hand column for answers. It is shown for the whole of a line that has answers, so nothing moves when they appear, and scrolls if there are more than fit.
@onready var options_column: Control = %OptionsColumn

## Shows one line, then closes unless another line follows straight away (so a run of [method say] calls reads as one conversation). [param portrait] is a [Texture2D] or a resource path; [param side] is [code]"left"[/code] or [code]"right"[/code].
func say(speaker: String, text: String, portrait: Variant = null, side: String = "left") -> void:
	await show_line(speaker, text, portrait, side)
	close_if_idle()

## Shows a line with [param options] as answers and returns the index picked.
func ask(speaker: String, text: String, options: PackedStringArray, portrait: Variant = null, side: String = "left") -> int:
	var pick := await show_line(speaker, text, portrait, side, options)
	close_if_idle()
	return pick

## Shows one line and leaves the box open; call [method OmniTextWindow.close_if_idle] after the last one. Returns the answer picked, or [code]-1[/code] when the line has no [param options]. [param speed] overrides [member OmniTextWindow.characters_per_second] for this line.
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
