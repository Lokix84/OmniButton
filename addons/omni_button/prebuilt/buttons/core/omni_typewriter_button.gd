@tool
class_name OmniTypewriterButton
extends Omni_Button
## An [Omni_Button] that types its [member Omni_Button.Text] out when the scene starts, for title
## screens ("Press Start"), intros and prompts.
##
## The first press while it is still typing only finishes the text; presses after that emit
## [signal Omni_Button.pressed] as usual. With [member blink_when_done] on, the text pulses once it
## has finished typing, so it reads as "waiting for you".

## Start typing as soon as the scene starts. Off: call [method play] yourself.
@export var autoplay := true
## Typing speed.
@export_range(1.0, 200.0, 1.0, "or_greater") var characters_per_second := 24.0
## Reveal whole words instead of letters.
@export var by_word := false
## Wait this long before typing starts.
@export_range(0.0, 10.0, 0.05, "suffix:s") var start_delay := 0.3
## Pulse the button once the text is fully shown.
@export var blink_when_done := true
## Seconds for one full pulse (fade out and back in).
@export_range(0.2, 5.0, 0.05, "suffix:s") var blink_period := 1.4
## How faint the text gets at the bottom of each pulse (0 = invisible, 1 = no pulse).
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

## Types [member Omni_Button.Text] from the start (also restarts it).
func play() -> void:
	_stop_blink()
	start_typewriter_from_text_to_type(characters_per_second, by_word)

## Whether the text is still being typed.
func is_typing() -> bool:
	return _tw_active

func _gui_input(event: InputEvent) -> void:
	# While typing, a press only finishes the text; it doesn't count as a press.
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
