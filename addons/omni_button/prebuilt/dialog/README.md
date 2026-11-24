# OmniButton: dialog windows

Part of the OmniButton plugin, with nothing extra to install. Ready-made dialog windows built from OmniButtons: popups (alert, confirm, choice), toasts, an RPG dialogue box and full-screen narration. Every window is a scene you can open, see and edit. Show them from code through the `OmniDialog` autoload, or drop a window into your scene and set it up in the Inspector.

## Quick start

1. Enable the plugin in **Project Settings > Plugins**. It adds the `OmniDialog` autoload. If you enabled the plugin before the dialog system existed, turn it off and on once. Only want the buttons? Turn off **Project Settings > omni_button/dialog/enable_autoload** and the autoload is removed; nothing else changes.
2. Call it from any script:

   ```gdscript
   await OmniDialog.say("Guard", "Halt! Who goes there?", "res://portraits/guard.png")
   if await OmniDialog.confirm("Open the gate?"):
	   OmniDialog.toast("The gate creaks open.")
   ```

3. Run `demo/omni_dialog_demo.tscn` (F6). One screen with a button for everything: popups, toasts, dialogue, narration, the story file, the base overlay, the looks and text speed. The **Windows** button switches between the `OmniDialog` autoload and windows dropped into the scene, and a log shows each call and what it returned.

Every class (`OmniPopup`, `OmniDialogueBox`, `OmniDialogRunner`, the `OmniDialog` autoload as `OmniDialogAutoload`, ...) has a help page in the editor: press F1 and type its name. The same pages as Markdown are in [`docs/api/`](docs/api/README.md), and the design notes in [`docs/dialog_design_spec.md`](docs/dialog_design_spec.md).

## What's in this folder

```
dialog/
├── windows/        USE: the windows. Drop them into a scene, or let OmniDialog create them.
│   ├── popup/          omni_popup.tscn         alert, confirm, choice
│   ├── toast/          omni_toast.tscn         short messages that go away on their own
│   ├── dialogue_box/   omni_dialogue_box.tscn  speaker, portrait, typing text, answers
│   └── narration/      omni_narration.tscn     full screen text over an optional background
├── parts/          CUSTOMIZE SHAPE: the repeated pieces windows are built from
│   ├── omni_option_button.tscn   every popup button and dialogue answer
│   └── omni_toast_item.tscn      each toast
├── themes/         CUSTOMIZE LOOK: omni_dialog_modern.tres, omni_dialog_retro.tres, omni_dialog_bold.tres, README.md (how to make one)
├── docs/           READ: api/ (one page per class), dialog_design_spec.md (design notes)
├── demo/           TRY IT: omni_dialog_demo.tscn (every feature on one screen),
│                   story/gate_story.json (example dialog file)
├── dev/            ONLY FOR PLUGIN WORK: automated tests (left out of downloads)
└── core/           LEAVE ALONE: what the windows are made of
    ├── omni_dialog.gd           the OmniDialog autoload
    ├── omni_dialog_runner.gd    OmniDialogRunner: plays dialog JSON files on windows
    ├── omni_dialog_file.gd      OmniDialogFile: loads and caches dialog JSON files
    ├── omni_dialog_validator.gd OmniDialogValidator: finds mistakes in dialog files
    ├── omni_dialog_theme.gd     OmniDialogTheme: what a look contains
    ├── overlay/                 omni_overlay.tscn: the base every window inherits
    └── text_window/             shared typing and answers logic for dialogue box and narration
```

## Two ways to show a window

The method names are the same either way.

| | From code (autoload) | Dropped-in scene |
|---|---|---|
| Dialogue line | `await OmniDialog.say(name, text, portrait, side)` | `await $DialogueBox.say(name, text, portrait, side)` |
| Dialogue question | `var i := await OmniDialog.ask(name, text, answers, portrait, side)` | `var i := await $DialogueBox.ask(...)` |
| Narration | `await OmniDialog.narrate(text, background)` | `await $Narration.narrate(text, background)` |
| Acknowledge | `await OmniDialog.alert(text, title, ok)` | `await $Popup.alert(text, title, ok)` |
| Yes / No | `var yes := await OmniDialog.confirm(text, title, yes, no)` | `var yes := await $Popup.confirm(...)` |
| Choice | `var i := await OmniDialog.choose(text, answers, title)` | `var i := await $Popup.choose(...)` |
| Popup set up in the Inspector | — | `var i := await $Popup.show_configured()` |
| Toast | `OmniDialog.toast(text, duration)` | `$Toast.toast(text, duration)` |

- `portrait` and `background` are a `Texture2D` or a resource path. `side` is `"left"` or `"right"`.
- `ask` / `choose` return the index picked. Canceling a choice returns `-1`, and canceling a confirm counts as No.
- A run of `say()` calls reads as one conversation: the box stays open between lines and closes after the last one.
- Every call can be awaited and returns when the window is done. A call made while a window is busy waits for its turn.
- **Autoload:** creates each window the first time it's needed and reuses it.
- **Dropped-in window:** uses its own Inspector settings, such as slower text or a different animation. Dropped-in windows are hidden until shown. Click the eye icon in the Scene dock to preview one while you edit.

### Text speed for players

`OmniDialog.text_speed_scale` is a player setting for every dialog window, including dropped-in ones: `1` normal, `2` twice as fast, `0.5` half as fast, `0` instant. Hook it to your options menu and save it with the player's settings:

```gdscript
OmniDialog.text_speed_scale = 0.0   # "Instant text" option
```

Without the autoload, set `OmniTextWindow.text_speed_scale`; it's the same shared value. Speeds written into the text with `[speed=...]` aren't scaled.

### In the text

- BBCode: `[b]bold[/b]`, `[color=gold]gold[/color]`, `[wave]...[/wave]`.
- Timing tags: `[pause=0.5]` waits half a second, `[speed=10]` changes the typing speed, and `[/speed]` goes back to normal.

### Signals

- **Every window:** `opening`, `opened`, `closing`, `closed`, `canceled`.
- **Popup:** `button_pressed(index, text)`.
- **Dialogue box and narration:** `line_started(text)`, `line_revealed`, `line_finished(result)`.

## Dialog from JSON files

Write conversations in a JSON file and play them by key. Lines are shown on the same windows, with answers stored by id so later lines can react to them. `demo/story/gate_story.json` uses every feature, and the demo's **Story file** buttons play it both ways.

```gdscript
const STORY := "res://story/chapter1.json"
var answers := await OmniDialog.play(STORY, "gate")   # answers given during this entry
if OmniDialog.get_answer("business") == "trade":
	await OmniDialog.play(STORY, "market")
```

**Without the autoload**, make a runner and give it your own windows:

```gdscript
var runner := OmniDialogRunner.new()
runner.dialogue_box = $DialogueBox
runner.narration = $Narration
runner.popup = $Popup
runner.toast = $Toast
await runner.play(STORY, "gate")
```

### File format

A file is a JSON object of **entries** by key. An entry is a list of **lines**, played in order:

```json
{
  "gate": [
	{ "type": "say", "name": "Gate Guard", "portrait": "res://portraits/guard.png", "text": "Halt!" },
	{ "type": "say", "name": "Mira", "portrait": "res://portraits/mira.png", "side": "right",
	  "text": "Easy...[pause=0.4] we're [b]friends[/b]." },
	{ "type": "say", "name": "Gate Guard", "text": "State your business.",
	  "choices": { "id": "business", "options": [
		{ "text": "I'm here to trade.", "value": "trade", "set": { "guard_trust": 1 } },
		{ "text": "Just passing through.", "value": "passing", "next": "gate_passing" },
		{ "text": "Slip him 10 gold.", "value": "bribe", "if": { "has_gold": true } }
	  ]}
	},
	{ "type": "confirm", "id": "follow_guard", "text": "Follow him?", "on_no": "gate_wait" },
	{ "type": "goto", "next": "market" }
  ],
  "gate_passing": [ { "type": "say", "name": "Gate Guard", "text": "Then keep moving." } ]
}
```

An entry can also be an object, `{ "skippable": false, "lines": [ ... ] }`, for entry-wide options. `skippable: false` turns skipping off for that entry, for example for a tutorial.

| `type` | Shows | Fields |
|---|---|---|
| `say` (default) | dialogue box | `name`, `text`, `portrait`, `side`, `choices`, `speed` |
| `narrate` | narration | `text`, `background`, `choices`, `speed` |
| `toast` | toast | `text`, `duration` |
| `alert` | popup | `text`, `title`, `button` |
| `confirm` | popup (Yes / No) | `id`, `text`, `title`, `yes`, `no`, `on_yes`, `on_no` |
| `choice` | popup | `text`, `title`, `choices` |
| `event` | nothing | `name`, `args`, `wait` (default `true`) |
| `wait` | nothing | `seconds` |
| `goto` | nothing | `next`: the entry to continue at |
| `end` | nothing | stops the entry |

**On any line or option:**
- `if` shows it only when every listed answer matches. `if_not` hides it when any listed answer matches. A list matches any of its values, and `null` means "not answered yet".
- `set` stores values, such as `{ "has_gold": true }`.
- `event` fires a cue before the line shows, for example `{ "name": "shake" }`.

**`choices` group:**
- `id` names the answer.
- `options` is a list. An option is a plain string, or an object with `text`, `value` (default: its position), `next`, `set`, `if`, `if_not` and `event`.

**Text:** `name`, `title`, option text, and `yes` / `no` / `button` labels go through Godot's translations (`tr()`), so they can be translation keys.

### Answers

- Answers are stored by id: `OmniDialog.get_answer(id)` and `set_answer(id, value)`. A confirm stores `true` / `false`, and a canceled choice stores `-1`.
- To save: store `OmniDialog.get_answers()` with your save game, and pass it to `set_answers(...)` when loading.
- JSON numbers load as floats: an answer of `1` comes back as `1.0`. Conditions treat `1` and `1.0` as the same.
- Signals: `choice_made(id, value)`, `started(file, key)`, `finished(file, key, answers)`, `event_triggered(name, args)`.

### Events

An `event` line, or a line's or option's `event`, calls the handler you register for its name, with its `args`:

```gdscript
OmniDialog.register_event("shake", _shake_camera)
OmniDialog.register_event("give_item", func(item): inventory.add(item))

func _shake_camera() -> void:
    var tween := create_tween()
    ...
    await tween.finished   # the dialog waits until this finishes (unless the event says "wait": false)
```

Don't bind a runner into one of its own handlers, as in `register_event("x", _f.bind(runner))`. The runner keeps its handlers, so that's a reference loop and the runner never frees.

### Skipping

While a story entry plays, the dialogue box and narration show a **Hold to skip ▶▶** button. It's an `Omni_Button` using its hold build-up: holding it until the fill completes fast-forwards the rest of the entry.
- **Lines still count:** skipped lines aren't shown, but their `set` values, conditions and jumps still apply, so the game ends up where it would have.
- **Dropped:** `wait` lines and toasts.
- **Questions stop the skip:** skipping ends at the next question, which shows normally. A question is never skipped: skipping on one only shows the rest of it.
- **Events still run:** handlers can check `OmniDialog.is_skipping()` to jump straight to their end state instead of animating.
- **Other ways to skip:** a key or button (set **Skipping > Skip Action** on the window to an InputMap action), or code: `OmniDialog.skip_entry()`, or `runner.skip()` on your own runner.
- **Settings and signals:** **Skipping > Show Skip Button** and **Skip Hold Time** are in each window's Inspector. Signals: `skip_started(file, key)` and `skip_stopped(file, key)`.
- **Code-driven conversations** (`say()` / `ask()` calls) have no skip button, because there's no entry to fast-forward.

### Checking files for mistakes

A typo in a dialog file doesn't stop the game; the line just behaves wrongly. To find mistakes before playing:

- **In the editor:** **Project > Tools > Check OmniButton dialog files** checks every dialog file in the project and prints a report to the Output panel.
- **From code:** `OmniDialog.check_file("res://story/chapter1.json")` prints the report and returns the problems. `OmniDialogValidator.check_file(path)` does the same without the autoload.

It reports:
- **Errors:**
  - unknown line types;
  - `next` / `on_yes` / `on_no` / `goto` pointing to an entry that doesn't exist;
  - missing text;
  - options without text;
  - portraits or backgrounds that don't exist;
  - a `side` other than left / right;
  - malformed `choices`, `if`, `set`, `event` and `wait`.
- **Warnings:**
  - misspelled or unused fields (`"nmae"`);
  - questions without an `id` (the answer isn't stored);
  - conditions on ids that nothing in the file stores.

Each problem says which entry and line it's on, for example `gate, line 4`.

### Notes

- Files under `res://` are loaded as Godot JSON resources, so they work in exported games. `user://` files (for example downloaded or modded dialog) are read directly.
- Entries play one at a time. A `play()` call made while another is playing waits for its turn.
- `OmniDialog.stop()` ends the playing entry.
- A `goto` loop is stopped after 10,000 lines, with an error printed.

## Customizing, from least to most work

1. **Inspector on a window.** Select a dropped-in window, or open its scene. Each window has the same groups:
   - **Window:** start open, pause the game while open.
   - **Look:** this window's look.
   - **Animation:** open and close animation and timing.
   - **Backdrop:** dim the game, click outside to cancel.
   - **Input:** cancel action, keep focus inside.

   Plus the window's own settings:
   - **Popup:** title, message, buttons, typing the message.
   - **Toast:** duration, how many show at once, click to dismiss.
   - **Dialogue box and narration:** text speed, auto-advance, typing sound.

2. **A look** (`themes/*.tres`, an `OmniDialogTheme`). Colors, fonts, panel and button styles for every window at once. A look holds:
   - a Godot **Theme** for panels and labels, with the type variations `OmniDialogTitle`, `OmniDialogName`, `OmniDialogIndicator` and `OmniDialogToast`;
   - **option button** styles, text color, font, wrap, minimum font size and padding;
   - **body text** color and font, for dialogue, narration, popup messages and toasts.

   Inside the windows, the look always wins over styles set in the `parts/` scenes.

   **To make a look** (full guide, including what a look must have: [`themes/README.md`](themes/README.md)):
   1. Duplicate a file in `themes/`.
   2. Open `demo/omni_dialog_demo.tscn` and drag your file into its root's **Your Look**.
   3. Run the demo (F6) and press **Look** until it shows "Yours". Open any window to see it.
   4. Edit the `.tres` in the editor and save. Click back into the running demo: it reloads your look, so the next window you open shows the change.
   5. Use it: point **Project Settings > omni_button/dialog/theme** at it, set one window's **Look**, or call `OmniDialog.set_dialog_theme(load("res://my_look.tres"))` at runtime.

3. **Shape.**
   - Edit a scene in `parts/` to change every button or toast, such as size or padding.
   - To rearrange one window, make a **New Inherited Scene** from it, then point **Project Settings > omni_button/dialog/popup_scene** (or `toast_scene`, `dialogue_scene`, `narration_scene`) at your scene so the autoload uses it.
   - To make a new kind of window (shop, inventory, pause screen), inherit `core/overlay/omni_overlay.tscn` and put your controls under `Root/Panel/Content`. `OverlayA` and `OverlayB` in the demo scene show how.

## How the windows behave

- **Focus:** keyboard and gamepad work everywhere, Enter / A presses and Esc / B cancels. Focus stays inside the top window and goes back to where it was when the window closes.
- **Stacking:** a popup opened over a dialogue box is on top. Only the top window reacts to cancel.
- **Toasts:** never take focus. A popup open at the same time keeps working.
- **Dialogue box:** keeps the same size the whole time. On a line with answers, the question types on the left and the answers appear on the right once it's done. Long answers wrap and share one font size. An answer that still doesn't fit gets taller, and the answer list scrolls.
- **Pausing:** windows keep working while the game is paused, and can pause it themselves (**Window > Pause Tree**).
- **Any game resolution:** the windows are laid out for a 1152x648 screen and scale to your game's resolution, so they take the same share of the screen at 320x180, 640x360 or 1920x1080. This works best with **Project Settings > Display > Window > Stretch > Mode** set to `canvas_items`, which keeps text sharp. If you lay your windows out for a different size, set **Project Settings > omni_button/dialog/reference_size** to it; `(0, 0)` turns scaling off for every window, and **Window > Fit To Screen** turns it off for one.
