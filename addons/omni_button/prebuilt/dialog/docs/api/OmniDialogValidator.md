# OmniDialogValidator

**Inherits:** `RefCounted`

Checks dialog JSON files for mistakes before the game runs them.

## Description

A typo in a dialog file (a `next` that points to a missing entry, a question without an `id`, a misspelled field) doesn't stop the game: the line just behaves wrongly. This finds those problems and says where they are.

```gdscript
var problems := OmniDialogValidator.check_file("res://story/chapter1.json")
print(OmniDialogValidator.format_report("res://story/chapter1.json", problems))
```

In the editor, **Project > Tools > Check OmniButton dialog files** checks every dialog file in the project and prints the report to the Output panel. Each problem is a Dictionary: [code]{ "severity": "error" or "warning", "entry": String,

"line": int (1-based, 0 for the entry itself), "message": String }[/code]. Errors break the dialog; warnings are probably mistakes but might be on purpose.

## Methods

| Returns | Method |
|---|---|
| `Dictionary[]` | [`check_file`](#check_file)(path: String) static |
| `Dictionary` | [`check_folder`](#check_folder)(folder: String = "res://") static |
| `String` | [`format_report`](#format_report)(path: String, problems: Dictionary[]) static |

## Constants and enums

- `LINE_FIELDS = {"alert": ["text", "title", "button"], "choice": ["text", "title", "choices"], "confirm": ["id", "text", "title", "yes", "no", "on_yes", "on_no"], "end": [], "event": ["name", "args", "wait"], "goto": ["next"], "narrate": ["text", "background", "choices", "speed"], "say": ["name", "text", "portrait", "side", "choices", "speed"], "toast": ["text", "duration"], "wait": ["seconds"]}`: Fields each line type uses (besides `COMMON_FIELDS`).
- `COMMON_FIELDS = ["type", "if", "if_not", "set", "event"]`: Fields any line can have.
- `OPTION_FIELDS = ["text", "value", "next", "set", "if", "if_not", "event"]`: Fields an option in a `choices` group can have.
- `ENTRY_FIELDS = ["lines", "skippable"]`: Fields an entry written as an object can have.

## Method descriptions

### check_file

`Dictionary[]` `check_file(path: String)` static

Checks the dialog file at `path` and returns its problems (empty when it's fine).

### check_folder

`Dictionary` `check_folder(folder: String = "res://")` static

Checks every `.json` file under `folder` that looks like a dialog file. Returns `{ path: problems }` for each file checked.

### format_report

`String` `format_report(path: String, problems: Dictionary[])` static

Turns `problems` into readable text, one problem per line.
