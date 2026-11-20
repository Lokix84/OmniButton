# OmniButton Dialog System — Design Spec

Status: planning. Target: Godot 4.7, GDScript.

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

`play()` returns every answer given during that entry, keyed by the asking line's `id`. All answers are also kept in `OmniDialog.answers` so they can be saved and checked later (see **Answers**).

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
- `OmniDialog.answers` holds every answer given so far (later answers to the same `id` replace earlier ones). `get_answer(id, default)` reads one. Saving and loading the game just saves and restores this Dictionary (`get_answers()` / `set_answers(dict)`).

Ids should be unique across the whole game, so the validator warns when two lines in different files use the same `id`.

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
- The validator reports keys that have no entry in the project's translation files.

### Validator

An editor tool (and a test in `addons/omni_button/test/`) that loads every dialog file and reports:

- unknown step types or missing required fields,
- `next` / `on_yes` / `on_no` keys that don't exist,
- missing resource paths (portraits, backgrounds),
- translation keys with no entry in the project's translation files,
- ids used in `if` / `if_not` that no line, option or `set` in any file ever stores (they may still be set from code, so this is a warning),
- `confirm` lines or `choices` groups without an `id`, and the same `id` used in more than one place.

## OmniDialog autoload

Added by the plugin when it's enabled (`add_autoload_singleton`) and removed when it's disabled.

### Responsibilities

- Load and cache dialog files (`play()` parses each file once).
- Run entries step by step, and follow `next` / `goto` / `on_yes` / `on_no` jumps.
- Instance each window scene on first use and keep it for reuse.
- Run registered event handlers and await them when `wait` is true.
- Make sure only one entry runs at a time. A second `play()` call waits for the first, unless `interrupt` is passed.

### Skipping

Players can skip the rest of a running entry (a cutscene or a conversation).

- **How:** the `skip_action` input (Project Settings, default none), an optional hold-to-skip button in the dialogue box (an `Omni_Button` using its Hold build-up, so the player holds it until the fill completes), or `OmniDialog.skip_entry()` from code.
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

All except `toast` and `register_event` can be awaited.

| Function | Returns |
|---|---|
| `play(file: String, key: String, interrupt := false)` | `Dictionary` of answers given during the entry |
| `toast(text: String, duration := 2.0)` | — |
| `alert(text: String, title := "", button := "OK")` | — |
| `confirm(text: String, title := "", yes := "Yes", no := "No", id := "")` | `bool` (also stored under `id` when given) |
| `choose(text: String, options: PackedStringArray, title := "", id := "")` | `int` (-1 if canceled; also stored under `id` when given) |
| `say(name: String, text: String, portrait: Texture2D = null, side := "left")` | — |
| `narrate(text: String, background: Texture2D = null)` | — |
| `register_event(name: String, handler: Callable)` / `unregister_event(name: String)` | — |
| `skip()` | — advance or skip the current line |
| `skip_entry()` | — fast-forward the rest of the running entry (see **Skipping**) |
| `is_skipping() -> bool` | — for event handlers |
| `stop()` | — end the running entry immediately |
| `is_running() -> bool` | — |
| `get_answer(id: String, default = null)` | the stored answer |
| `set_answer(id: String, value)` | — store a value conditions can check |
| `get_answers()` / `set_answers(answers: Dictionary)` | for saving and loading |

### Signals

`started(file, key)`, `step_started(step: Dictionary)`, `event_triggered(name, args)`, `choice_made(id, value)`, `skip_started(file, key)`, `skip_stopped(file, key)`, `finished(file, key, answers)`.

### Project Settings

Under `omni_button/dialog/`:

- One scene path per window type (`toast_scene`, `popup_scene`, `dialogue_scene`, `narration_scene`), defaulting to the shipped scenes. To restyle a window, make an inherited scene from the shipped one and point the setting at it.
- `default_text_speed` (characters per second), `advance_action`, `cancel_action`, `skip_action`.
- `show_skip_button` (default false) and `skip_hold_duration` (default 1.0 s) for the dialogue box's hold-to-skip button.
- `pause_tree_during_dialog` (default false).

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

Shared behavior: open/close with built-in animations (fade, scale, slide), optional backdrop, focus trapped inside while open (and restored on close), cancel action, optional tree pausing (the overlay itself keeps processing). Signals `opened`, `closed`, `canceled`.

### OmniToast

Small panel near the top of the screen, no backdrop, ignores input. Several toasts stack and each fades out after its `duration`.

### OmniPopup (alert / confirm / choice)

Centered panel with backdrop: `%Title`, `%Message`, `%Buttons` (one `Omni_Button` per option). Choices with many options stack vertically instead of in a row.

### OmniDialogueBox

Bottom-anchored panel: `%PortraitLeft`, `%PortraitRight`, `%Name`, `%Body` (an `Omni_Button` running the typewriter), `%Options`, `%ContinueIndicator`.

- Press `%Body` or the advance action while text is revealing: skip to the end.
- Press again once it's fully shown: continue.
- Each line shows its own name and portrait, so speakers can change from line to line. The portrait goes on the line's `side`.
- When the line has choices, they appear in `%Options` and take focus.
- Optional typing blip (`typing_sound`, played every N characters).
- Optional `%SkipButton`: hold to skip the rest of the entry. Hidden when the entry isn't skippable.

### OmniNarration

Full-screen panel with an opaque backdrop, optional `%Background` image, and centered `%Body` text using the typewriter. Advances the same way as the dialogue box. Fades in and out.

## Folder layout

```
addons/omni_button/dialog/
├── omni_dialog.gd                  autoload (OmniDialog)
├── omni_dialog_runner.gd           steps through an entry
├── omni_dialog_file.gd             loading, caching, parsing
├── omni_dialog_validator.gd        editor tool + test helper
├── scenes/
│   ├── omni_overlay.tscn / .gd     base
│   ├── omni_toast.tscn / .gd
│   ├── omni_popup.tscn / .gd
│   ├── omni_dialogue_box.tscn / .gd
│   ├── omni_narration.tscn / .gd
│   ├── omni_option_button.tscn     pre-styled Omni_Button for options
│   └── omni_dialog_theme.tres
└── examples/
    └── example_episode.json
```

## Prerequisites in OmniButton core

Done:

1. `typewriter_char_revealed(index: int, character: String)` signal, for typing sounds.
2. Inline `[pause=s]`, `[speed=cps]` and `[/speed]` tags, handled by the typewriter and removed before the text reaches the label.

Checked, and what the scenes must do about it:

3. **Containers:** `Omni_Button` has no minimum size of its own (its text shrinks to fit whatever size it gets), so it collapses to zero height in a VBox/HBox. The option button scene sets `custom_minimum_size` (height) and expands horizontally. Verified: with a minimum height it fills the container width and lays out its label.
4. **Focus:** `focus_mode` defaults to `FOCUS_NONE`, so the option button scene sets `FOCUS_ALL`. Verified: a focused button uses `PanelFocusStyleBox` and activates on `ui_accept`.

## Build order

1. ~~Core typewriter additions and checks.~~ Done.
2. Base overlay scene, option button, theme.
3. OmniPopup and OmniToast, opened directly from the autoload (no data files yet).
4. OmniDialogueBox and OmniNarration.
5. Data files: loading, the runner, jumps, answers, `set`, conditions.
6. Events: `register_event`, awaiting handlers, the per-step `event` field.
7. Skipping: fast-forward, stopping at questions, `is_skipping()`, the hold-to-skip button.
8. Validator, tests, README section, example episode.
9. Menus (separate scene set, later).

## Open questions

None right now. New questions go here as building starts.
