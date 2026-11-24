# OmniMenu

**Inherits:** [OmniOverlay](../../../dialog/docs/api/OmniOverlay.md)

Base of the menu screens ([OmniTitleMenu](./OmniTitleMenu.md), [OmniPauseMenu](./OmniPauseMenu.md)): an [OmniOverlay](../../../dialog/docs/api/OmniOverlay.md) with a title and a column of buttons.

## Description

Every [Omni_Button](../../../../docs/api/Omni_Button.md) under `%Items` is a menu item. Its node name is its id, in snake case (`QuitToTitle` → `&"quit_to_title"`): pressing it emits `item_pressed` with that id. To add an item, duplicate one in the scene, rename it and change its text; connect `item_pressed` to react to it. The items are styled by the look, like dialog buttons.

## Properties

| Type | Name | Default |
|---|---|---|
| `bool` | [`style_items`](#style_items) | `true` |
| `String` | [`options_scene`](#options_scene) | `""` |
| `String` | [`title`](#title) | `""` |
| `Label` | [`title_label`](#title_label) | `get_node_or_null(...)` |
| `Container` | [`items_box`](#items_box) |  |

## Methods

| Returns | Method |
|---|---|
| `Omni_Button[]` | [`get_items`](#get_items)() |
| [Omni_Button](../../../../docs/api/Omni_Button.md) | [`get_item`](#get_item)(item: StringName) |
| `void` | [`set_item_visible`](#set_item_visible)(item: StringName, on: bool) |

## Signals

### item_pressed(item: StringName)

A menu item was pressed. `item` is its node name in snake case.

## Property descriptions

### style_items

`bool` `style_items` = `true`

Style the items as the look's option buttons. The stylized scenes turn this off and style them through their [OmniMenuStylizer](./OmniMenuStylizer.md).

### options_scene

`String` `options_scene` = `""`

The options screen scene that Options opens. Empty: **Project Settings > omni_button/menus/options_scene**.

### title

`String` `title` = `""`

Text shown at the top of the menu. Empty hides it.

### title_label

`Label` `title_label` = `get_node_or_null(...)`

The `Label` showing `title` (type variation `OmniMenuTitle`).

### items_box

`Container` `items_box`

The container whose [Omni_Button](../../../../docs/api/Omni_Button.md) children are the items.

## Method descriptions

### get_items

`Omni_Button[]` `get_items()`

The items, in order (hidden ones included).

### get_item

[Omni_Button](../../../../docs/api/Omni_Button.md) `get_item(item: StringName)`

The item with id `item` (node name in snake case), or `null`.

### set_item_visible

`void` `set_item_visible(item: StringName, on: bool)`

Shows or hides an item.
