# OmniButton Dialog System — Design Spec

Status: built (see **Build order**; menus are their own system in `prebuilt/menus/`). Target: Godot 4.7, GDScript.

These are the design notes: what each piece does and why. The user guide is [`../README.md`](../README.md) and the class reference is [`api/`](api/README.md).

## Goal

A data-driven dialog system that ships with the OmniButton plugin:

- Text and flow live in **data files**. Game code plays an entry by file and key, and awaits the result:
  `await OmniDialog.play("res://story/ep1.json", "guard_intro")`.
- An **autoload** (`OmniDialog`) loads the window scenes when they're first needed, runs the entry step by step, and emits a signal when it ends.
- Entries can trigger **events** (camera moves, animations, sound, anything in the game) for cutscenes. The dialog waits for an event to finish when the event handler is awaitable.
- Six window types, all built from `Omni_Button`s, so mouse, touch, keyboard and gamepad behave as they do for a plain button.

Story "episode" scenes stay short: they call entries in order and await each one.

## Window types

| Window | What it shows | Blocks the game | Result |
|---|---|---|---|
| **Toast** | Short message that disappears on its own | No | none |
| **Alert** | Message + one acknowledge button (covers "popup" and "alert") | Yes | none |
| **Confirm** | Message + Yes / No | Yes | `bool` |
| **Choice** | Message + several options | Yes | option index / value |
| **Dialogue** | RPG box: speaker, portrait, typewriter text, optional replies | Configurable | chosen reply, if any |
| **Narration** | Full-screen panel: centered text, optional background image | Yes | none |

Alert, Confirm and Choice are one scene (**OmniPopup**) that differs only in how many buttons it shows.

## How it's used

### From an episode scene

```gdscript
const EP1 := "res://story/ep1.json"

func _ready() -> void:
	await OmniDialog.play(EP1, "opening_narration")
	var answers: Dictionary = await OmniDialog.play(EP1, "guard_intro")
	if answers.get("guard_business") == "trade":
		await OmniDialog.play(EP1, "market")
```

`play()` returns every answer given during that entry, keyed by the asking line's `id`. All answers are also kept by the autoload (`get_answers()`) so they can be saved and checked later (see **Answers**).

### Without a data file

Every window can also be opened directly for one-off UI:

```gdscript
OmniDialog.toast("Game saved")
await OmniDialog.alert("You found a key.")
if await OmniDialog.confirm("Quit to the title screen?"):
    get_tree().change_scene_to_file("res://title.tscn")
var pick := await OmniDialog.choose("Pick a class", ["Warrior", "Mage", "Rogue"])
await OmniDialog.say("Guard", "Halt!")
await OmniDialog.narrate("Three days later...")
```

### Cutscene events

Game code registers a handler for each event name. If the handler is a coroutine, the dialog waits for it before continuing:

```gdscript
func _ready() -> void:
    OmniDialog.register_event("camera_pan", _camera_pan)
    OmniDialog.register_event("play_anim", func(node_path, anim): get_node(node_path).play(anim))

func _camera_pan(target: String) -> void:
    var tween := create_tween()
    tween.tween_property($Camera2D, "global_position", get_node(target).global_position, 1.0)
    await tween.finished
```

Events without a registered handler are still emitted as `OmniDialog.event_triggered(name, args)`, so a scene can listen instead of registering.

## Data format

**JSON**, one file per episode or area, holding many entries by key. JSON is easy to write by hand, diff in git and generate from external tools. Godot can't check it in the editor, so the plugin includes a validator (see below).

An entry is a list of **lines**, played in order. Each line says which window shows it and who is speaking, so any number of people can talk in one entry. An entry can also be an object, `{ "skippable": false, "lines": [ ... ] }`, to set options for the whole entry (see **Skipping**).

```json
{
  "opening_narration": [
	{ "type": "narrate", "text": "EP1_OPENING", "background": "res://story/bg/vell.png" }
  ],

  "guard_intro": [
	{ "type": "event", "name": "camera_pan", "args": ["Gate"] },
	{ "type": "say", "name": "Gate Guard", "portrait": "res://story/portraits/guard.png",
	  "text": "EP1_GUARD_HALT" },
	{ "type": "say", "name": "Mira", "portrait": "res://story/portraits/mira.png",
	  "text": "EP1_MIRA_EASY" },
	{ "type": "say", "name": "Gate Guard", "portrait": "res://story/portraits/guard.png",
	  "text": "EP1_GUARD_BUSINESS",
	  "choices": {
		"id": "guard_business",
		"options": [
		  { "text": "EP1_OPT_TRADE", "value": "trade" },
		  { "text": "EP1_OPT_PASSING", "value": "passing", "next": "guard_leave" }
		]
	  }
	},
	{ "type": "say", "name": "Gate Guard", "text": "EP1_GUARD_EAST_GATE" }
  ],

  "guard_leave": [
	{ "type": "say", "name": "Gate Guard", "text": "EP1_GUARD_KEEP_MOVING" },
	{ "type": "confirm", "id": "follow_guard", "text": "EP1_FOLLOW_PROMPT" }
  ]
}
```

### Line fields

| Field | Required | Meaning |
|---|---|---|
| `type` | yes | Which window shows the line (`say`, `narrate`, `toast`, `alert`, `confirm`, `choice`), or a non-window step (`event`, `wait`, `goto`, `end`). |
| `name` | no | Speaker name to display. No name → the name area is hidden. |
| `portrait` | no | Portrait image path. No portrait → the portrait area is hidden. |
| `side` | no | `left` or `right`: where the portrait sits in the dialogue box. Default `left`. |
| `text` | yes for windows | The line, or a translation key (see **Translations**). BBCode and `[pause=…]` / `[speed=…]` allowed in `say` and `narrate`. |
| `id` | yes when the line asks something | Name the answer is stored under. Required on `confirm`, and inside `choices`. |
| `choices` | no | Sub-group of options: `id` plus an `options` list. Shown in the dialogue box on `say`, or as a popup on `choice`. |
| `title` | no | Popup title (`alert`, `confirm`, `choice`). |
| `speed` | no | Typewriter characters per second for this line. |
| `duration` | no | Seconds a `toast` stays up. |
| `event` | no | `{ "name": ..., "args": [...] }` fired just before the line shows. |
| `if` / `if_not` | no | Show the line only when stored answers match (see **Conditions**). Works on non-window steps too. |
| `set` | no | `{ "id": value, ... }` stored as answers when the line shows. |

Non-window steps:

| `type` | Fields |
|---|---|
| `event` | `name`, optional `args`, `wait` (default true) |
| `wait` | `seconds` |
| `goto` | `next`: key of the entry to continue at |
| `end` | — stops the entry here |

### Options

Each item in `choices.options`:

- `text`: button label (or translation key).
- `value`: what gets stored as the answer. Defaults to the option's index.
- `next`: key of an entry to continue at. Without it, the current entry carries on with its next line.
- `event`: optional event fired when the option is picked.
- `if` / `if_not`: hide the option unless stored answers match.
- `set`: extra answers stored when the option is picked, e.g. `{ "guard_trusts_you": true }`.

A `confirm` line stores `true` or `false`. It can also take `yes` / `no` (button labels) and `on_yes` / `on_no` (keys to jump to).

### Answers

Every `confirm` and every `choices` group stores its answer under its `id`:

- `play()` returns a Dictionary of the answers given during that entry: `{ "guard_business": "trade" }`.
- `OmniDialog.choice_made(id, value)` is emitted the moment an answer is picked, for code that stores it immediately.
- The autoload keeps every answer given so far (later answers to the same `id` replace earlier ones). `get_answer(id, default)` reads one. Saving and loading the game just saves and restores this Dictionary (`get_answers()` / `set_answers(dict)`).

Ids should be unique across the whole game: two questions with the same `id` overwrite each other's answer.

**Saving.** Decided: the system doesn't save its position inside an entry. A save made while an entry is running loads back to the start of that entry, and the episode scene plays it again. Only the answers Dictionary needs saving. Answers given earlier in the interrupted entry are kept, and are replaced if the player answers differently the second time.

### Conditions

Lines, non-window steps and options can depend on stored answers.

```json
{ "type": "say", "name": "Gate Guard", "text": "EP1_GUARD_WELCOME_BACK",
  "if": { "guard_business": "trade" } },

{ "type": "goto", "next": "guard_suspicious",
  "if": { "follow_guard": true }, "if_not": { "guard_trusts_you": true } },

{ "text": "EP1_OPT_BRIBE", "value": "bribe",
  "if": { "has_gold": true } }
```

Rules:

- `if`: every listed id must match. `if_not`: none of the listed ids may match. Both can be used together.
- A plain value matches when the stored answer equals it.
- A list matches any of its values: `"if": { "guard_business": ["trade", "passing"] }`.
- `null` matches an id that hasn't been answered yet: `"if": { "met_mira": null }`.
- A line whose condition fails is skipped. An option whose condition fails is hidden. If every option in a group is hidden, the line shows without choices and nothing is stored.
- A `goto` with a condition is how an entry branches on earlier answers without game code.

Game code can store values too, so conditions can check things the dialog never asked about (items, quest state): `OmniDialog.set_answer("has_gold", true)`.

Anything more complex (comparisons, counting, combining with OR across different ids) stays in game code: check `get_answer()` and pick which key to `play()`.

### Translations

Decided: **one JSON file per episode, translation keys in the text fields, and Godot's built-in translation files for the languages.**

- `text`, `name`, `title`, option `text`, and `yes` / `no` labels hold translation keys such as `"EP1_GUARD_HALT"`.
- The sentences for each language go in Godot translation files (CSV with one column per language, or one PO file per language), added under Project Settings → Localization.
- The dialog system runs every one of those fields through `tr()`, so the current locale is used automatically, and changing locale mid-game affects the next line shown.
- A key with no translation is shown as written, so drafts can use plain sentences and be converted to keys later.
- Not built: the validator doesn't check translation keys against the translation files yet.

### Validator

`OmniDialogValidator` (`core/omni_dialog_validator.gd`) checks dialog files: **Project > Tools > Check OmniButton dialog files** checks every dialog file in the project and prints a report, `OmniDialog.check_file(path)` checks one from code, and the demo has a **Check the file** button. It reports:

- errors: unknown line types, missing required fields (`text`, `name` on events, `seconds` on waits, `next` on gotos, `choices` on choice lines), `next` / `on_yes` / `on_no` keys that aren't entries in the file, missing portrait and background files, and fields of the wrong kind (`side`, `args`, `if`, `set`, `event`, `skippable`);
- warnings: fields a line type doesn't use (likely typos), `confirm` lines or `choices` groups without an `id`, ids checked by `if` / `if_not` that nothing in the file stores (fine when game code sets them), and empty entries.

Not built: checking translation keys, and the same `id` used in more than one file.

## OmniDialog autoload

Added by the plugin when it's enabled (`add_autoload_singleton`) and removed when it's disabled.

### Responsibilities

- Load and cache dialog files (`play()` parses each file once).
- Run entries step by step, and follow `next` / `goto` / `on_yes` / `on_no` jumps.
- Instance each window scene on first use and keep it for reuse.
- Run registered event handlers and await them when `wait` is true.
- Make sure only one entry runs at a time. A second `play()` call waits for the first to finish; `stop()` ends the running one.

### Skipping

Players can skip the rest of a running entry (a cutscene or a conversation).

- **How:** a hold-to-skip button on the dialogue box and narration (`%SkipButton`, an `Omni_Button` using its Hold build-up, so the player holds it until the fill completes; `show_skip_button`, `skip_hold_time`), the window's `skip_action` input (default none), or `OmniDialog.skip_entry()` from code. The button only shows while a skippable entry is playing, and hides on question lines.
- **What it does:** it fast-forwards instead of cutting the entry off. The remaining lines run without being shown, so `set` values, conditions and `goto` / `next` jumps still apply and the player ends up in the same state as if they had watched it. `wait` steps and toasts are skipped.
- **Where it stops:** at the next `confirm`, `choice` or line with choices, because skipping can't answer for the player. The question is shown normally and the entry carries on unskipped after it. The player can skip again from there.
- **Events still run,** so the game reaches the right end state. Handlers check `OmniDialog.is_skipping()` and jump to their end result instead of animating:

  ```gdscript
  func _camera_pan(target: String) -> void:
	  var end_pos: Vector2 = get_node(target).global_position
	  if OmniDialog.is_skipping():
		  $Camera2D.global_position = end_pos
		  return
	  var tween := create_tween()
	  tween.tween_property($Camera2D, "global_position", end_pos, 1.0)
	  await tween.finished
  ```

- **Opting out:** an entry can be written as an object instead of a plain list to turn skipping off, for tutorials or key story moments:

  ```json
  "tutorial_intro": { "skippable": false, "lines": [ ... ] }
  ```

### Functions

The autoload's script is `core/omni_dialog.gd` (`class_name OmniDialogAutoload`). Everything that shows a window can be awaited; `toast` returns at once.

| Function | Returns |
|---|---|
| `play(file: String, key: String)` | `Dictionary` of answers given during the entry |
| `toast(text: String, duration := -1.0)` | — (`-1` uses the toast window's default) |
| `alert(text: String, title := "", ok := "OK")` | — |
| `confirm(text: String, title := "", yes := "Yes", no := "No")` | `bool` (cancel = No) |
| `choose(text: String, options: PackedStringArray, title := "")` | `int` (-1 if canceled) |
| `say(speaker: String, text: String, portrait = null, side := "left")` | — (portrait: Texture2D or path) |
| `ask(speaker: String, text: String, options: PackedStringArray, portrait = null, side := "left")` | `int` option picked |
| `narrate(text: String, background = null)` | — (background: Texture2D or path) |
| `register_event(name, handler: Callable)` / `unregister_event(name)` | — |
| `skip_entry()` / `is_skipping()` | fast-forward the running entry (see **Skipping**) / for event handlers |
| `stop()` / `is_playing()` | end the running entry / whether one is playing |
| `check_file(file)` | the validator's problems for one file |
| `get_answer(id, default = null)` / `set_answer(id, value)` | read / store one answer |
| `get_answers()` / `set_answers(answers: Dictionary)` | for saving and loading |
| `set_dialog_theme(look)` | switch the look of the autoload's windows (`null` = project default) |
| `get_popup()` / `get_toast()` / `get_dialogue()` / `get_narration()` | the window, created on first use |

Properties: `text_speed_scale` (player text speed for every window: 1 normal, 0 instant), `runner` (the `OmniDialogRunner` that `play()` uses).

`OmniDialogRunner` can also be used without the autoload: give it windows (`dialogue_box`, `narration`, `popup`, `toast`, or a `window_provider`) and call `play()`; it has its own answers and event handlers.

### Signals

On the autoload (relayed from its runner): `started(file, key)`, `event_triggered(name, args)`, `choice_made(id, value)`, `skip_started(file, key)`, `skip_stopped(file, key)`, `finished(file, key, entry_answers)`. The runner also has `line_started(line: Dictionary)`.

### Project Settings

Under `omni_button/dialog/`, registered by the plugin:

- `enable_autoload` (default on): off removes the `OmniDialog` autoload; the windows still work dropped into scenes.
- `theme`: the look every window uses unless it sets its own (default `themes/omni_dialog_modern.tres`).
- One scene path per window type (`toast_scene`, `popup_scene`, `dialogue_scene`, `narration_scene`), defaulting to the shipped scenes. To restyle a window, make an inherited scene from the shipped one and point the setting at it.
- `reference_size` (default 1152x648): the screen size the windows are laid out for. Each window scales from it to the game's resolution; `(0, 0)` turns scaling off.

Text speed, input actions and skipping are set per window in the Inspector (see **OmniTextWindow**), and for players with `text_speed_scale`.

## Window scenes

All are `.tscn` files with a `class_name` root script, inheriting a shared base scene. Scripts find their parts by unique name (`%Body`, `%Options`, ...), so moving nodes around in an inherited scene doesn't break them.

### OmniOverlay (base)

```
OmniOverlay (CanvasLayer)            omni_overlay.gd
└── %Root (Control, full rect)
	├── %Backdrop (ColorRect)        dims the game, blocks clicks underneath
	└── %Panel (PanelContainer)
		└── %Content (MarginContainer)
```

Built: `addons/omni_button/prebuilt/dialog/core/overlay/omni_overlay.tscn` / `.gd` (`class_name OmniOverlay`).

- **Open/close:** `open()` and `close()` can be awaited and return when the animation ends, including when one cuts the other short. Animations (`OverlayAnimation`): None, Fade, Scale, SlideUp, SlideDown; every one also fades. Signals `opening`, `opened`, `closing`, `closed`, `canceled`.
- **Backdrop:** `show_backdrop`, `backdrop_color`, `close_on_backdrop_click`.
- **Cancel:** `cancel_action` (default `ui_cancel`) calls `cancel()`, which emits `canceled` and closes when `close_on_cancel` is on.
- **Focus:** on open, the first focusable control under `%Content` gets focus and Tab / Shift+Tab loop inside the overlay. Arrow-key and gamepad navigation are left to Godot; if focus lands outside the overlay it is pulled back. On close, focus returns to whatever had it before. `refresh_focus()` re-applies this after a window changes its content while open.
- **Stacking:** overlays opened later are on top (`is_top()`). Only the top one reacts to cancel and keeps focus; closing it hands focus back to the one underneath. Freeing an open overlay removes it cleanly.
- **Pausing:** `pause_tree` pauses the game while open and restores the previous pause state on close. Overlays always process, so they work while the game is paused.
- **Screen size:** with `fit_to_screen` on (the default), the layer is scaled by `min(screen / reference_size)` and `%Root` is sized to `screen / scale`, so a window laid out for 1152x648 takes the same share of a 320x180 or 640x360 screen. It rescales when the viewport size changes. Text stays sharp with stretch mode `canvas_items`; with stretch mode `viewport` (pixel-perfect), small base sizes make the text too small to read, so turn it off and lay windows out in the game's pixels.
- **Hooks for window scenes:** `_on_open()`, `_on_close()`, `_get_default_focus()`, `_get_focus_chain()`.
- **Defaults:** layer 10, panel centered with a 360 px minimum width, styled by the look (see **Looks**).

Also built: `parts/omni_option_button.tscn` (an `Omni_Button` with a 44 px minimum height, horizontal expand, `FOCUS_ALL`, pressed signal on). Every popup button and dialogue answer is an instance of it.

### OmniToast

Built: `prebuilt/dialog/windows/toast/omni_toast.tscn` / `.gd` (`class_name OmniToast`), inherited from the base overlay.

- `show_toast(text, duration := -1.0)`: shows a toast near the top of the screen. Awaiting it waits until that toast is gone.
- Each toast is an `Omni_Button` made from `item_scene` (`parts/omni_toast_item.tscn`, 360×52): its panel is the look's `OmniDialogToast` style (via `PanelThemeVariation`), text wraps and then shrinks to fit, and clicking it dismisses it (`dismiss_on_click`; off lets clicks through to the game). Restyle or resize toasts by editing that scene.
- Non-modal (`modal = false` on the base overlay): never takes focus, never reacts to cancel, no backdrop. A popup open at the same time keeps focus and cancel.
- `default_duration` (2 s), `max_visible` (4; the oldest are removed beyond that), `fade_time`, `count()`, `clear()`.
- Timers ignore pausing and `Engine.time_scale`. Layer 20.

### OmniPopup (alert / confirm / choice)

Built: `prebuilt/dialog/windows/popup/omni_popup.tscn` / `.gd` (`class_name OmniPopup`), inherited from the base overlay.

- `%Title` (hidden when empty), `%Message` (an `Omni_Button` with BBCode, fixed at 400×72: long messages wrap and then shrink to fit; `type_message` / `message_speed` type it out, and clicking it shows the rest), `%ButtonRow` / `%ButtonColumn`: buttons sit in a row up to `max_buttons_in_row` (2), and stack vertically beyond that.
- `ask(text, options, title, default_index, cancel_index) -> int`, plus `alert()`, `confirm() -> bool` (cancel = No), `choose() -> int` (cancel = -1). All can be awaited.
- One question at a time: a call made while the popup is busy waits for its turn. Closing it from code still answers (with `cancel_index`), so nothing waits forever.
- Inspector setup: `title`, `message`, `buttons`, `default_button`, `allow_cancel`, `cancel_index`, `option_button_scene`. A popup dropped into a scene and set up this way is shown with `await popup.show_configured()`. In the editor, the buttons from the Inspector are previewed (not saved into the scene).
- `button_pressed(index, text)` signal. Layer 12.

### OmniTextWindow (shared by the dialogue box and narration)

Built: `prebuilt/dialog/core/text_window/omni_text_window.gd` (`class_name OmniTextWindow`, no scene of its own).

- A line is revealed with the typewriter in `%Body` (an `Omni_Button`). Pressing the body, or `advance_action` (`ui_accept`), shows the rest of the line at once; pressing again moves on. `advance()` does the same from code.
- When a line has options, they appear in `%Options` once the text is fully shown, take focus, and end the line when picked. The body ignores presses while options show.
- `%ContinueIndicator` blinks once a line is fully shown and is waiting for input.
- Each line call can be awaited and returns the option index, or -1. Calls made while a line is showing wait their turn. The window stays open between lines; `close_if_idle()` closes it at the end of the frame unless another line has started, so back-to-back lines don't flicker.
- Closing from code (or cancel, if turned on) ends the current line with -1.
- Settings: `characters_per_second` (40; a line can override it), `auto_advance_delay` (0 = wait for input), `advance_action`, `typing_sound` / `typing_sound_every` / `typing_pitch_variation` / `typing_sound_bus`, `show_skip_button` / `skip_hold_time` / `skip_action`, `option_button_scene`.
- `OmniTextWindow.text_speed_scale` (static, shared by every window, also set through `OmniDialog.text_speed_scale`) scales typing speed for players: 2 twice as fast, 0 shows each line at once. `[speed=...]` tags in the text aren't scaled.
- Signals: `line_started(text)`, `line_revealed`, `line_finished(result)`. `state`: IDLE, REVEALING, WAITING, CHOOSING.

### OmniDialogueBox

Built: `prebuilt/dialog/windows/dialogue_box/omni_dialogue_box.tscn` / `.gd` (`class_name OmniDialogueBox`).

- Wide panel along the bottom, a fixed 190 px tall: `%PortraitLeft`, `%Name` and `%Body` (fixed 22 px, word wrap, BBCode and timing tags) in the text column, `%OptionsColumn` (a ScrollContainer holding `%Options`), `%PortraitRight`.
- Lines with options use a split layout so the box never changes size: `%OptionsColumn` is shown from the start of the line (the question types out on the left at its final width), and the options fill it in once the text is shown. Lines without options hide the column and use the full width. More options than fit scroll, following focus. The split is set by the columns' stretch ratios (text 1 : options 0.7) in the scene.
- `show_line(speaker, text, portrait = null, side = "left", options = [], speed = 0) -> int`. `portrait` is a Texture2D or a resource path. A right-side speaker shows the portrait on the right and right-aligns the name. An empty name or no portrait hides that part.
- Defaults: no backdrop, cancel does nothing, slides up.

### OmniNarration

Built: `prebuilt/dialog/windows/narration/omni_narration.tscn` / `.gd` (`class_name OmniNarration`).

- Full screen: opaque backdrop, optional `%Background` image (cover-scaled) with a `%Shade` over it for readability, centered `%Body` text (30 px).
- `show_text(text, background = null, options = [], speed = 0) -> int`. A line without a background keeps the current one; the background is cleared when narration closes.
- Clicking anywhere moves on. Defaults: 30 characters per second, fades over 0.4 s, layer 11.

## Looks (OmniDialogTheme)

Every window's styling comes from one look file, an `OmniDialogTheme` resource (`core/omni_dialog_theme.gd`). Two ship with the plugin in `themes/`:

- `omni_dialog_modern.tres`: dark rounded panels, soft shadows, blue accents (the original styling).
- `omni_dialog_retro.tres`: classic console-RPG windows: navy panels with square white borders, gold titles / names / focus, hard drop shadows, an unsmoothed monospace font (uses "Press Start 2P" or "PixelOperator" if installed, otherwise Consolas / Courier New).

A look holds:

- `theme`: a Godot Theme applied to each window's `%Root`. It styles PanelContainer panels, Label / RichTextLabel text and fonts, and four type variations used by the scenes: `OmniDialogTitle` (popup title), `OmniDialogName` (speaker name), `OmniDialogIndicator` (continue marker), `OmniDialogToast` (each toast). It can be opened and edited in Godot's theme editor.
- Option button settings (Omni_Button parts a Godot Theme can't reach): `option_normal / hover / pressed / focus / disabled` styles, `option_text_color`, `option_font`, `option_height`, `option_max_font_size`, `option_min_font_size` (modern 14, retro 12), `option_wrap` (on), `option_text_padding` (12, 2).
- Option groups (one question's answers, or one popup's buttons) share a single font size: the largest at which every option fits (wrapping first when `option_wrap` is on), never below `option_min_font_size`. An option whose text still doesn't fit at that size is made taller, measured from its laid-out label lines plus a small margin, and re-checked until stable because a scrollbar appearing narrows every option; the dialogue box's options column scrolls, so the box keeps its size. Options stay hidden for the two frames this takes, so sizes never visibly jump (`OmniDialogTheme.fit_option_group()`).
- Text body settings for the dialogue box and narration text, the popup message and toasts: `text_color`, `text_font`.

Which look a window uses:

1. its own `dialog_theme` property, if set (for windows dropped into a scene);
2. otherwise for windows the autoload manages, `OmniDialog.set_dialog_theme(look)` (switches open windows immediately; `null` goes back to the default);
3. otherwise Project Settings > `omni_button/dialog/theme` (modern by default; registered by the plugin).

Looks always win: inside the dialog windows, the look's values replace styles set in the option button and toast item scenes. Those sub-scenes set size and behavior.

To make a new look: duplicate one of the shipped `.tres` files, drag it into `demo/omni_dialog_demo.tscn`'s `your_look`, run the demo, pick it with the Look button and open windows on demand. Saving the `.tres` in the editor and clicking back into the running demo reloads it (`CACHE_MODE_IGNORE_DEEP` on focus-in). Then point the project setting (or a window's `dialog_theme`) at the new look. Layout (sizes, spacing, positions) stays in the window scenes; looks only change appearance.

The demo's **Look** button switches between the shipped looks (and yours) while it runs. Tests: `dev/OmniDialogThemeValidation.gd`.

## Folder layout

User-facing documentation: `addons/omni_button/prebuilt/dialog/README.md`. API reference: `addons/omni_button/prebuilt/dialog/docs/api/` (generated from the scripts' doc comments by `addons/omni_button/dev/generate_api_docs.gd`). Ready-made content lives under `addons/omni_button/prebuilt/` (menus have their own folder there: `prebuilt/menus/`). Automated tests are in each system's `dev/` folder (`addons/omni_button/dev/`, `prebuilt/dialog/dev/`), left out of downloads.

```
addons/omni_button/prebuilt/dialog/
├── README.md
├── docs/         api/ (generated reference), dialog_design_spec.md (this file)
├── windows/      popup/, toast/, dialogue_box/, narration/  (the windows people use)
├── parts/        omni_option_button.tscn, omni_toast_item.tscn  (repeated pieces)
├── themes/       omni_dialog_modern.tres, omni_dialog_retro.tres  (looks)
├── demo/         omni_dialog_demo.tscn (one screen for every feature), story/, icons/
├── dev/          automated tests (left out of downloads)
└── core/         omni_dialog.gd (autoload), omni_dialog_runner.gd, omni_dialog_file.gd,
                  omni_dialog_validator.gd, omni_dialog_theme.gd, overlay/, text_window/, icons/
```

Every window also has the autoload's method names (`say`, `ask`, `narrate`, `toast`, `alert`, `confirm`, `choose`), so code is the same whether it calls `OmniDialog` or a dropped-in window.

## Prerequisites in OmniButton core

Done:

1. `typewriter_char_revealed(index: int, character: String)` signal, for typing sounds.
2. Inline `[pause=s]`, `[speed=cps]` and `[/speed]` tags, handled by the typewriter and removed before the text reaches the label.

Checked, and what the scenes must do about it:

3. **Containers:** `Omni_Button` has no minimum size of its own (its text shrinks to fit whatever size it gets), so it collapses to zero height in a VBox/HBox. The option button scene sets `custom_minimum_size` (height) and expands horizontally. Verified: with a minimum height it fills the container width and lays out its label.
4. **Focus:** `focus_mode` defaults to `FOCUS_NONE`, so the option button scene sets `FOCUS_ALL`. Verified: a focused button uses `PanelFocusStyleBox` and activates on `ui_accept`.

## Build order

1. ~~Core typewriter additions and checks.~~ Done.
2. ~~Base overlay scene, option button, theme.~~ Done (tests: `dev/OmniOverlayValidation.gd`). Later: scaling to the game's resolution (`fit_to_screen`, `reference_size`).
3. ~~OmniPopup and OmniToast, opened directly from the autoload (no data files yet).~~ Done: `OmniDialog.toast / alert / confirm / choose`, the plugin registers the autoload and the `omni_button/dialog/popup_scene` / `toast_scene` settings (tests: `dev/OmniPopupValidation.gd`).
4. ~~OmniDialogueBox and OmniNarration.~~ Done: `OmniDialog.say / ask / narrate` (tests: `dev/OmniDialogueValidation.gd`). Also fixed the typewriter re-fitting text that has a `FixedFontSize`.
5. ~~Data files: loading, the runner, jumps, answers, `set`, conditions.~~ Done: `OmniDialogFile`, `OmniDialogRunner` (usable without the autoload), `OmniDialog.play()` (tests: `dev/OmniDialogDataValidation.gd`; example: `demo/story/gate_story.json`).
6. ~~Events: `register_event`, awaiting handlers, the per-step `event` field.~~ Done with step 5 (also on options).
7. ~~Skipping: fast-forward, stopping at questions, `is_skipping()`, the hold-to-skip button.~~ Done: `OmniDialogRunner.skip()`, `OmniDialog.skip_entry()`, `%SkipButton` (an Omni_Button using its hold build-up) on the dialogue box and narration, `skip_action`, `skippable: false`. A question is never skipped.
8. ~~Validator, tests, README section, example episode.~~ Done: `OmniDialogValidator`, **Project > Tools > Check OmniButton dialog files**, `OmniDialog.check_file()` (tests in `dev/OmniDialogDataValidation.gd`).
9. ~~Demo, player settings.~~ Done: one demo scene for every feature (`demo/omni_dialog_demo.tscn`, also the look test bed), `text_speed_scale`, the `enable_autoload` switch.
10. ~~Menus.~~ Built as their own system in `prebuilt/menus/` (title, pause, options, `OmniSettings`), on top of `OmniOverlay` and the looks; see `prebuilt/menus/docs/menus_design.md`.

## Open questions

None right now.
