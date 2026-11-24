# OmniButton API reference

Generated from the doc comments in the scripts by `addons/omni_button/dev/generate_api_docs.gd`. In the Godot editor, the same docs open with F1 (Search Help) or Ctrl+click on a class or method name.

Dialog windows built on OmniButton have their own reference: [dialog API reference](../../prebuilt/dialog/docs/api/README.md).

## Button

- [Omni_Button](Omni_Button.md): A Control that does everything a button needs: press, release, toggle, hover, hold, swipe, cooldowns, typewriter text and a virtual joystick, with mouse, touch, keyboard and gamepad.
- [OmniLabelAccessor](OmniLabelAccessor.md): Text settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.label`).
- [OmniIconAccessor](OmniIconAccessor.md): Icon settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.icon`).
- [OmniBackgroundAccessor](OmniBackgroundAccessor.md): Background texture settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.background`).
- [OmniPanelAccessor](OmniPanelAccessor.md): Panel style settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.panel`).
- [OmniOverlayAccessor](OmniOverlayAccessor.md): Selection overlay settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.overlay`).
- [OmniCooldownAccessor](OmniCooldownAccessor.md): Cooldown settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.cooldown`).
- [OmniChargeUpAccessor](OmniChargeUpAccessor.md): Hold build-up settings of an [Omni_Button](./Omni_Button.md) (`Omni_Button.charge_up`).

## Presets (prebuilt/buttons)

- [OmniJoystick](OmniJoystick.md): An on-screen joystick for touch and mouse, built from an [Omni_Button](./Omni_Button.md) in virtual-joystick mode.
- [OmniSwipePad](OmniSwipePad.md): An [Omni_Button](./Omni_Button.md) that reports one direction per swipe, for dashes, card swipes and menus.
- [OmniTypewriterButton](OmniTypewriterButton.md): An [Omni_Button](./Omni_Button.md) that types its `Omni_Button.Text` out when the scene starts, for title screens ("Press Start"), intros and prompts.
- [OmniTabBar](OmniTabBar.md): A row of [Omni_Button](./Omni_Button.md) tabs where exactly one is on at a time, for tabs, category filters and "pick one" choices.

## Companion (prebuilt/cursor)

- [OmniVirtualCursor](OmniVirtualCursor.md): A controller cursor for menus: a ring moved by a joystick that clicks whatever is under it, like the menus in Destiny or The First Descendant.
