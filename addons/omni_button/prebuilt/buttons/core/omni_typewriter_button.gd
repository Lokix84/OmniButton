@tool
class_name OmniTypewriterButton
extends OmniButton
## an [OmniButton] that types its [member text] out when the scene starts. good for title
## screens ("Press Start"), intros and prompts.
##
## the first press while it's still typing just finishes the text, presses after that send
## [signal OmniButton.pressed] like normal. with [member blink_when_done] on the text pulses once
## it's done typing so it reads as "waiting for you".

## start typing as soon as the scene starts. off means you call [method play] yourself.
@export var autoplay := true
## how fast it types.
@export_range(1.0, 200.0, 1.0, "or_greater") var characters_per_second := 24.0
## shows whole words at a time instead of letters.
@export var by_word := false
## wait this long before it starts typing.
@export_range(0.0, 10.0, 0.05, "suffix:s") var start_delay := 0.3
## pulses the button once all the text is showing.
@export var blink_when_done := true
## seconds for one whole pulse (fade out and back in).
@export_range(0.2, 5.0, 0.05, "suffix:s") var blink_period := 1.4
## how faint the text gets at the bottom of each pulse (0 is invisible, 1 is no pulse).
@export_range(0.0, 1.0, 0.05) var blink_min_alpha := 0.3

var _blink: Tween

func _ready() -> void:
	super()
	if Engine.is_editor_hint():
		return
	typewriter_completed.connect(_on_typed)
	if autoplay:
		if start_delay > 0.0:
			modulate.a = 0.0
			await get_tree().create_timer(start_delay).timeout
			modulate.a = 1.0
		play()

## types [member text] from the start (restarts it too).
func play() -> void:
	_stop_blink()
	start_typewriter_from_text_to_type(characters_per_second, by_word)

## true while it's still typing.
func is_typing() -> bool:
	return _tw_active

func _gui_input(event: InputEvent) -> void:
	# while it's typing a press just finishes the text, it doesn't count as a press.
	if _tw_active and OmniButtonInput.is_press_input(self, event):
		skip_typewriter()
		accept_event()
		return
	super(event)

func _on_typed() -> void:
	if not blink_when_done or not is_inside_tree():
		return
	_stop_blink()
	_blink = create_tween().set_loops().set_trans(Tween.TRANS_SINE)
	_blink.tween_property(self, "modulate:a", blink_min_alpha, blink_period * 0.5)
	_blink.tween_property(self, "modulate:a", 1.0, blink_period * 0.5)

func _stop_blink() -> void:
	if _blink != null and _blink.is_valid():
		_blink.kill()
	_blink = null
	modulate.a = 1.0
