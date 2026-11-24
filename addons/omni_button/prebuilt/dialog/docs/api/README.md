# OmniButton dialog API reference

Generated from the doc comments in the scripts by `addons/omni_button/dev/generate_api_docs.gd`. In the Godot editor, the same docs open with F1 (Search Help) or Ctrl+click on a class or method name.

The windows are built from [Omni_Button](../../../../docs/api/Omni_Button.md); see the [OmniButton API reference](../../../../docs/api/README.md). Usage guide: [dialog README](../../README.md).

## Dialog windows

- [OmniPopup](OmniPopup.md): A centered window with a title, a message and buttons: alert, confirm and choice in one scene.
- [OmniToast](OmniToast.md): Short messages near the top of the screen that disappear on their own.
- [OmniDialogueBox](OmniDialogueBox.md): RPG-style dialogue box: speaker name, portrait on either side, typing text and answers.
- [OmniNarration](OmniNarration.md): Full-screen narration: centered typing text over an opaque backdrop, with an optional background image.

## Dialog system

- [OmniDialogAutoload](OmniDialogAutoload.md): The `OmniDialog` autoload: shows OmniButton's dialog windows from any script.
- [OmniDialogRunner](OmniDialogRunner.md): Plays dialog entries from JSON files on dialog windows, one line at a time.
- [OmniDialogFile](OmniDialogFile.md): Loads dialog JSON files and caches them.
- [OmniDialogValidator](OmniDialogValidator.md): Checks dialog JSON files for mistakes before the game runs them.
- [OmniDialogTheme](OmniDialogTheme.md): One complete look for the dialog windows.
- [OmniOverlay](OmniOverlay.md): Base of every dialog window: opening and closing, backdrop, focus, cancel and pausing.
- [OmniTextWindow](OmniTextWindow.md): Shared base of [OmniDialogueBox](./OmniDialogueBox.md) and [OmniNarration](./OmniNarration.md): typing text, answers and moving on.
