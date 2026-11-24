extends Control
# The OmniButton dialog demo: every window, the story file, the base overlay and the looks, from one
# screen. Run with F6. Each button opens a window on demand; the log on the right shows the call
# that ran and what it returned.
#
# Two ways to use the windows, switched with the "Windows" button at the top:
#   - OmniDialog (code): calls go to the OmniDialog autoload, which makes its windows when first
#     needed. Example: var yes: bool = await OmniDialog.confirm("Quit?")
#   - This scene's nodes: the same calls go to ScenePopup, SceneToast, SceneBox and SceneNarration,
#     the prebuilt window scenes dropped into this scene and set up in the Inspector (select one to
#     see its settings). Example: var yes: bool = await $ScenePopup.confirm("Quit?")
# ShopPopup (its question is written in the Inspector) and the two overlays are always this scene's.
#
# Making a look: duplicate a .tres in themes/, drag it into this scene root's "Your Look", run the
# scene and pick it with the Look button. Edit the .tres in the editor and save; when you click back
# into the running game it reloads the look, so the next window you open shows the change.

const DialogScript := preload("res://addons/omni_button/prebuilt/dialog/core/omni_dialog.gd")
const STORY := "res://addons/omni_button/prebuilt/dialog/demo/story/gate_story.json"
const GUARD := "res://addons/omni_button/prebuilt/dialog/demo/icons/Icon-Sword1.png"
const MIRA := "res://addons/omni_button/prebuilt/dialog/demo/icons/Icon-Potion6.png"
const BACKGROUND := "res://addons/omni_button/OmniButtonGDV1.png"
const OPTION_SCENE := "res://addons/omni_button/prebuilt/dialog/parts/omni_option_button.tscn"
const LOOKS := {
	"Modern": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_modern.tres",
	"Retro": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_retro.tres",
	"Bold": "res://addons/omni_button/prebuilt/dialog/themes/omni_dialog_bold.tres",
}
const SPEEDS := [["Normal", 1.0], ["Fast", 2.0], ["Instant", 0.0], ["Slow", 0.5]]
const ANIMATIONS := ["None", "Fade", "Scale", "SlideUp", "SlideDown"]

## Your own look (an OmniDialogTheme .tres) to try out. The Look button adds it after Modern and
## Retro, and the running game reloads it from disk whenever its window gets focus back.
@export var your_look: OmniDialogTheme

@onready var scene_popup: OmniPopup = $ScenePopup
@onready var scene_toast: OmniToast = $SceneToast
@onready var scene_box: OmniDialogueBox = $SceneBox
@onready var scene_narration: OmniNarration = $SceneNarration
@onready var shop_popup: OmniPopup = $ShopPopup
@onready var overlay_a: OmniOverlay = $OverlayA
@onready var overlay_b: OmniOverlay = $OverlayB

## The OmniDialog autoload (or a local copy when the plugin hasn't registered it).
var dialog: Node
## Plays the story file on this scene's windows, with its own answers.
var scene_runner := OmniDialogRunner.new()
var use_scene := false
var _look_names: Array = []
var _look := ""
var _speed := 0
var _toast_count := 0
var _log: PackedStringArray = []

func _ready() -> void:
	dialog = get_node_or_null("/root/OmniDialog")
	if dialog == null:
		dialog = DialogScript.new()
		add_child(dialog)
		_add_log("The OmniDialog autoload isn't registered (turn the plugin off and on in Project Settings > Plugins, or check omni_button/dialog/enable_autoload). Using a local copy.")
	scene_runner.dialogue_box = scene_box
	scene_runner.narration = scene_narration
	scene_runner.popup = scene_popup
	scene_runner.toast = scene_toast
	# Both runners get the same story events. (Don't bind a runner into its own handler: it keeps its
	# handlers, so that would be a reference loop and the runner would never be freed.)
	for r: OmniDialogRunner in [dialog.runner, scene_runner]:
		r.register_event("flash", _flash)
		r.register_event("shake", _shake)
		r.register_event("give_item", _give_item)
	# The End key also skips (hold the button above the text, or keep End held).
	for w in [dialog.get_dialogue(), dialog.get_narration(), scene_box, scene_narration]:
		w.skip_action = &"ui_end"
	for o: OmniOverlay in [overlay_a, overlay_b]:
		var tag := "OverlayA" if o == overlay_a else "OverlayB"
		for sig in ["opened", "closed", "canceled"]:
			o.connect(sig, _add_log.bind("%s %s" % [tag, sig]))
	_connect_buttons()
	get_viewport().size_changed.connect(_fit_to_screen)
	_fit_to_screen()
	_look_names = LOOKS.keys()
	if your_look != null:
		_look_names.append("Yours")
	_set_look("Yours" if your_look != null else _shipped_name(OmniDialogTheme.get_default()))
	_set_speed(0)
	_set_mode(false)
	_refresh_overlay_labels()
	%ToastButton.grab_focus()

func _connect_buttons() -> void:
	var actions := {
		"WindowsButton": func(): _set_mode(not use_scene),
		"LookButton": func(): _set_look(_look_names[(_look_names.find(_look) + 1) % _look_names.size()]),
		"SpeedButton": func(): _set_speed((_speed + 1) % SPEEDS.size()),
		"ToastButton": _on_toast, "AlertButton": _on_alert, "ConfirmButton": _on_confirm,
		"ChooseButton": _on_choose, "ChainButton": _on_chain, "ShopButton": _on_shop,
		"ConversationButton": _on_conversation, "AskButton": _on_ask, "LongAskButton": _on_long_ask,
		"NarrationButton": _on_narration, "MixedButton": _on_mixed,
		"OpeningButton": _play.bind("opening"), "GateButton": _play.bind("gate"),
		"MarketButton": _play.bind("market"), "CheckFileButton": _on_check_file,
		"ResetButton": _on_reset_answers,
		"OpenOverlayButton": func(): overlay_a.open(), "AnimationButton": _cycle_animation,
		"PauseButton": _toggle_pause, "BackdropButton": _toggle_backdrop_click,
		# Buttons inside the overlays' content.
		"StackButton": func(): overlay_b.open(), "CloseAButton": func(): overlay_a.close(),
		"CloseBButton": func(): overlay_b.close(),
	}
	for button_name in actions:
		get_node("%" + button_name).pressed.connect(actions[button_name])

## Scales the demo's own screen like the dialog windows scale themselves (see OmniOverlay.fit_to_screen),
## so it works at any game resolution, from 320x180 up.
func _fit_to_screen() -> void:
	var margin: Control = $Margin
	var screen := get_viewport().get_visible_rect().size
	var reference := OmniOverlay.get_reference_size()
	var s := 1.0
	if reference.x > 0.0 and reference.y > 0.0:
		s = minf(screen.x / reference.x, screen.y / reference.y)
	margin.set_anchors_preset(Control.PRESET_TOP_LEFT)
	margin.scale = Vector2(s, s)
	margin.position = Vector2.ZERO
	margin.size = screen / s

func _process(delta: float) -> void:
	# Keeps turning unless an overlay pauses the game.
	%Spinner.rotation += delta * 2.0

## Where a call goes: the autoload, or this scene's window of that kind.
func _target(kind: String) -> Object:
	if not use_scene:
		return dialog
	return {"popup": scene_popup, "toast": scene_toast, "box": scene_box, "narration": scene_narration}[kind]

## How the log writes the target of a call.
func _who(kind: String) -> String:
	if not use_scene:
		return "OmniDialog"
	return {"popup": "$ScenePopup", "toast": "$SceneToast", "box": "$SceneBox", "narration": "$SceneNarration"}[kind]

#region Popups and toasts

func _on_toast() -> void:
	_toast_count += 1
	_target("toast").toast("Toast number %d" % _toast_count)
	_add_log("%s.toast(\"Toast number %d\")" % [_who("toast"), _toast_count])

func _on_alert() -> void:
	await _target("popup").alert("You found a [b]rusty key[/b].", "Item found")
	_add_log("await %s.alert(...)  closed" % _who("popup"))

func _on_confirm() -> void:
	var yes: bool = await _target("popup").confirm("Quit to the title screen?", "Quit")
	_add_log("await %s.confirm(...)  ->  %s" % [_who("popup"), yes])

func _on_choose() -> void:
	var pick: int = await _target("popup").choose("Pick a class.", PackedStringArray(["Warrior", "Mage", "Rogue"]), "New game")
	_add_log("await %s.choose(...)  ->  %d%s" % [_who("popup"), pick, "  (canceled)" if pick < 0 else ""])

## One answer leads to the next question.
func _on_chain() -> void:
	var popup := _target("popup")
	var pick: int = await popup.choose("Which door?", PackedStringArray(["Left", "Right"]))
	if pick < 0:
		_add_log("door chain canceled")
		return
	var door: String = ["left", "right"][pick]
	var sure: bool = await popup.confirm("Open the %s door?" % door)
	if sure:
		_target("toast").toast("The %s door creaks open." % door)
	_add_log("door chain: choose -> %d, confirm -> %s" % [pick, sure])

## ShopPopup's title, message and buttons are set in the Inspector; code only shows it.
func _on_shop() -> void:
	var pick: int = await shop_popup.show_configured()
	_add_log("await $ShopPopup.show_configured()  ->  %d" % pick)
	if pick == 0:
		_target("toast").toast("Bought a potion")

#endregion

#region Dialogue and narration

func _on_conversation() -> void:
	var box := _target("box")
	await box.say("Gate Guard", "Halt! Who goes there?", GUARD)
	await box.say("Mira", "Easy...[pause=0.6] we're [b]friends[/b].", MIRA, "right")
	await box.say("Gate Guard", "[speed=8]Friends.[/speed][pause=0.4] Sure you are.", GUARD)
	await box.say("", "(The guard squints at you for a long moment.)")
	_add_log("await %s.say(...) x4  finished" % _who("box"))

func _on_ask() -> void:
	var box := _target("box")
	var pick: int = await box.ask("Gate Guard", "State your business.", PackedStringArray(["I'm here to trade.", "Just passing through.", "None of yours."]), GUARD)
	_add_log("await %s.ask(...)  ->  %d" % [_who("box"), pick])
	var replies := ["Merchants use the east gate.", "Then keep moving.", "[shake]Watch your tongue.[/shake]"]
	await box.say("Gate Guard", replies[pick] if pick >= 0 else "...", GUARD)

## Answers of very different lengths: they wrap and share one font size; the box keeps its size.
func _on_long_ask() -> void:
	var box := _target("box")
	var pick: int = await box.ask("Gate Guard", "State your business, and be quick about it.", PackedStringArray([
		"I'm a travelling merchant with silk and spices to sell in the market, and a cart of fine cloth from the southern ports.",
		"Just passing through on my way to the coast.",
		"No.",
		"I'm looking for my brother. He came through this gate three days ago and never wrote home.",
	]), GUARD)
	_add_log("await %s.ask(...)  ->  %d" % [_who("box"), pick])
	var replies := ["Merchants use the east gate.", "Then keep moving.", "[shake]Watch your tongue.[/shake]", "Ask at the barracks. They keep a ledger."]
	await box.say("Gate Guard", replies[pick] if pick >= 0 else "...", GUARD)

func _on_narration() -> void:
	var n := _target("narration")
	await n.narrate("The city of Vell.", BACKGROUND)
	await n.narrate("Three days after the fire,[pause=0.5] the gates opened again.")
	_add_log("await %s.narrate(...) x2  finished" % _who("narration"))

## Narration, dialogue, a popup and a toast in one short scene.
func _on_mixed() -> void:
	await _target("narration").narrate("Night falls over the market.")
	var box := _target("box")
	await box.say("Mira", "We should rest. The inn is just ahead.", MIRA, "right")
	var rest: bool = await _target("popup").confirm("Rest at the inn for 10 gold?", "Inn")
	if rest:
		_target("toast").toast("You feel rested")
	await box.say("Mira", "Much better." if rest else "Suit yourself.", MIRA, "right")
	_add_log("mixed scene finished (rest = %s)" % rest)

#endregion

#region Story file

## Plays an entry of demo/story/gate_story.json (open it to see the lines).
func _play(key: String) -> void:
	var who := "OmniDialog" if not use_scene else "scene_runner"
	_add_log("await %s.play(\"gate_story.json\", \"%s\")  started" % [who, key])
	var entry_answers: Dictionary
	if use_scene:
		entry_answers = await scene_runner.play(STORY, key)
	else:
		entry_answers = await dialog.play(STORY, key)
	_add_log("  finished, answers given: %s" % _format(entry_answers))
	_add_log("  all stored answers: %s" % _format(_runner().get_answers()))

func _runner() -> OmniDialogRunner:
	return scene_runner if use_scene else dialog.runner

func _on_reset_answers() -> void:
	_runner().set_answers({})
	_add_log("answers cleared (the story starts fresh)")

## Runs the file checker on the story and shows its report.
func _on_check_file() -> void:
	var problems := OmniDialogValidator.check_file(STORY)
	var report := OmniDialogValidator.format_report(STORY.get_file(), problems)
	_add_log("OmniDialogValidator.check_file(...)  ->  %d problem(s)" % problems.size())
	await _target("popup").alert("[code]%s[/code]" % report, "Story file check")

## "flash" event: a white flash. The story waits for it, because the handler awaits the tween.
func _flash() -> void:
	var flash: ColorRect = %Flash
	flash.color.a = 0.8
	var t := create_tween()
	t.tween_property(flash, "color:a", 0.0, 0.5)
	await t.finished

## "shake" event: shakes the background.
func _shake() -> void:
	var bg: Control = $Background
	var t := create_tween()
	for i in 6:
		t.tween_property(bg, "position", Vector2(randf_range(-10, 10), randf_range(-6, 6)), 0.04)
	t.tween_property(bg, "position", Vector2.ZERO, 0.04)
	await t.finished

## "give_item" event: shows what changed hands as a toast.
func _give_item(what: String) -> void:
	_target("toast").toast(what)

static func _format(answers: Dictionary) -> String:
	if answers.is_empty():
		return "(none)"
	var parts := PackedStringArray()
	for id in answers:
		parts.append("%s = %s" % [id, answers[id]])
	return ", ".join(parts)

#endregion

#region Base overlay

func _cycle_animation() -> void:
	var a := (overlay_a.open_animation + 1) % ANIMATIONS.size()
	for o: OmniOverlay in [overlay_a, overlay_b]:
		o.open_animation = a
		o.close_animation = a
	_refresh_overlay_labels()

func _toggle_pause() -> void:
	overlay_a.pause_tree = not overlay_a.pause_tree
	_refresh_overlay_labels()

func _toggle_backdrop_click() -> void:
	overlay_a.close_on_backdrop_click = not overlay_a.close_on_backdrop_click
	_refresh_overlay_labels()

func _refresh_overlay_labels() -> void:
	%AnimationButton.Text = "Animation: %s" % ANIMATIONS[overlay_a.open_animation]
	%PauseButton.Text = "Pauses game: %s" % ("On" if overlay_a.pause_tree else "Off")
	%BackdropButton.Text = "Click outside closes: %s" % ("On" if overlay_a.close_on_backdrop_click else "Off")

#endregion

#region Settings

func _set_mode(scene: bool) -> void:
	use_scene = scene
	%WindowsButton.Text = "Windows: this scene's nodes" if scene else "Windows: OmniDialog (code)"
	%Info.text = ("Calls go to ScenePopup, SceneToast, SceneBox and SceneNarration: prebuilt windows dropped into this scene and set up in the Inspector (slower typing, longer toasts). Same method names, on the node: await $ScenePopup.confirm(...)"
		if scene else
		"Calls go to the OmniDialog autoload, which makes its windows when first needed. No scene setup: await OmniDialog.confirm(...), await OmniDialog.say(...), await OmniDialog.play(file, key)")

func _set_speed(index: int) -> void:
	_speed = index
	dialog.text_speed_scale = SPEEDS[index][1]
	%SpeedButton.Text = "Text speed: %s" % SPEEDS[index][0]

func _set_look(look_name: String) -> void:
	_look = look_name
	var t: OmniDialogTheme = your_look if look_name == "Yours" else load(LOOKS[look_name])
	dialog.set_dialog_theme(t)
	for w: OmniOverlay in [scene_popup, scene_toast, scene_box, scene_narration, shop_popup, overlay_a, overlay_b]:
		w.dialog_theme = t
	# The demo's own buttons and labels use the look too.
	theme = t.theme
	for node in find_children("*", "Control", true, false):
		if node.scene_file_path == OPTION_SCENE:
			t.style_option(node)
	%LookButton.Text = "Look: " + look_name

static func _shipped_name(t: OmniDialogTheme) -> String:
	for n in LOOKS:
		if t != null and t.resource_path == LOOKS[n]:
			return n
	return "Modern"

## Coming back from the editor: reload your look from disk so saved edits show up.
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and your_look != null and your_look.resource_path != "" and is_node_ready():
		your_look = ResourceLoader.load(your_look.resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if _look == "Yours":
			_set_look("Yours")

#endregion

func _add_log(line: String) -> void:
	_log.append(line)
	if _log.size() > 14:
		_log.remove_at(0)
	%Log.text = "\n".join(_log)
