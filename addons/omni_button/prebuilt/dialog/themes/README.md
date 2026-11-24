# Looks

A **look** is one file that styles every dialog window at once (popups, toasts, the dialogue box and narration) and the [menus](../../menus/README.md). This folder holds the three that ship:

- `omni_dialog_modern.tres`: the default look.
- `omni_dialog_retro.tres`: a pixel-font, blue-and-gold RPG look.
- `omni_dialog_bold.tres`: a high-contrast red, black and white look with slanted buttons, made for the [stylized menus](../../menus/README.md).

## Making a new look

1. **Copy a shipped look.** In the FileSystem dock, right-click `omni_dialog_modern.tres` (or `omni_dialog_retro.tres`), choose **Duplicate**, and give it a new name, such as `my_look.tres`. Starting from a copy means every required part is already filled in. You can keep it in this folder or anywhere in your project.
2. **Try it in the demo.** Open `../demo/omni_dialog_demo.tscn` and drag your file into the root node's **Your Look** slot in the Inspector. Run the scene (F6). It starts on your look, and the **Look** button shows "Yours". Open popups, a conversation and a toast to see every window.
3. **Edit and watch.** Double-click your file to edit it in the Inspector, and save. Click back into the running demo and it reloads your look, so you don't need to restart.
4. **Use it in your game.** Pick one of the options in **Making it take hold** below.

## What's in a look

| Part | What it styles |
|---|---|
| `theme` | A normal Godot `Theme`, applied to every window. It sets panels, labels, fonts and spacing (see below). |
| **Option Buttons** group | Every popup button and dialogue answer: five background styles, text color, font, height, font-size range, wrapping and padding. |
| **Text Body** group | The main text of the dialogue box, narration, popup message and toasts: color and font. |
| **Stylized Menus** group | The full-screen stylized menus ([menus](../../menus/README.md)): accent color and its text color, background, band and text colors, and an optional font. |

Inside `theme`, these entries are used:

| Theme entry | Styles |
|---|---|
| `PanelContainer` > styles > `panel` | The background of every window (popup, dialogue box, narration). |
| `Label`, `RichTextLabel` > colors, fonts | Ordinary text. |
| `default_font`, `default_font_size` | The font everything uses unless something else sets one. |
| `VBoxContainer` / `HBoxContainer` > constants > `separation` | Spacing between rows and buttons. |
| Type variation `OmniDialogTitle` (base `Label`) | Popup titles. |
| Type variation `OmniDialogName` (base `Label`) | The speaker name in the dialogue box. |
| Type variation `OmniDialogIndicator` (base `Label`) | The blinking "continue" marker. |
| Type variation `OmniDialogToast` (base `PanelContainer`) > styles > `panel` | The background of each toast. |
| Type variation `OmniMenuTitle` (base `Label`) | The big title on the title screen and pause menu ([menus](../../menus/README.md)). |
| `HSlider` > styles > `slider`, `grabber_area`, `grabber_area_highlight` | The options screen's sliders. |

## What is 100% required

A look takes hold only when all of these are true. Without them, nothing breaks, but the windows show Godot's plain grey default style instead of yours.

1. **The file is an `OmniDialogTheme` resource.** Its script must be `core/omni_dialog_theme.gd`. A plain Godot `Theme` (`.tres`) doesn't work on its own: it goes *inside* the look, in the `theme` slot. If the Project Setting points at a file that isn't an `OmniDialogTheme`, an error is printed and the modern look is used instead. Duplicating a shipped look takes care of this.
2. **`theme` is set.** It styles the window panels and all text. Without it, every window gets Godot's default theme.
3. **`option_normal` is set.** This is the idle background of every option button. The other four (`option_hover`, `option_pressed`, `option_focus`, `option_disabled`) fall back to it when empty. If `option_normal` is also empty, buttons fall back to the theme's `Panel` style.
4. **Something points at the look.** See the next section.

**Strongly recommended:**

- `option_focus`, because without it players on keyboard or gamepad can't see which button is selected.
- `option_hover` and `option_pressed`, for mouse feedback.
- A `PanelContainer` panel style and an `OmniDialogToast` panel style in the theme, so windows and toasts have your backgrounds. An empty `OmniDialogToast` falls back to the theme's `Panel` style.

**Optional:** everything else has a sensible default. Empty fonts use the theme's `default_font`, the title, name and indicator variations fall back to the normal `Label` style, and colors and sizes have built-in values.

## Making it take hold

A window uses the first of these it finds:

1. **That window's own look:** **Look > Dialog Theme** in the Inspector of a window you dropped into a scene. It changes only that window.
2. **The autoload's look, set from code:** `OmniDialog.set_dialog_theme(load("res://my_look.tres"))` switches every window the `OmniDialog` autoload shows, while the game runs. Pass `null` to go back to the project's look.
3. **The project's look:** **Project Settings > omni_button/dialog/theme**. Point it at your file and every window in the game uses it. This is the usual choice.

If the Project Setting points at a file that was moved or deleted, the plugin resets it to the modern look the next time the editor starts.

## Tips

- **Fonts:** a pixel font looks best when the game uses whole-number scaling. The retro look uses a `SystemFont` with fallbacks. To ship a font with your game, use a `FontFile` (drag a `.ttf` or `.otf` into the slot) instead.
- **Small screens:** windows are laid out at **Project Settings > omni_button/dialog/reference_size** (1152x648) and scaled to the game's resolution. Pick font sizes that are still readable when scaled down; 16 px and up is a safe floor for 640x360.
- **Don't edit the shipped files.** Updating the plugin replaces them. Copy them instead.
- The look always wins over styles set in the `parts/` scenes, so change option buttons here, not in `parts/omni_option_button.tscn`.
