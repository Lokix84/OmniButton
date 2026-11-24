# OmniTabBar

**Inherits:** `HBoxContainer`

A row of [Omni_Button](./Omni_Button.md) tabs where exactly one is on at a time, for tabs, category filters and "pick one" choices.

## Description

Every [Omni_Button](./Omni_Button.md) child is a tab, in order (add one by duplicating a tab). The tab that is on uses the button's pressed style. Set `pages` to a container and only the child with the current tab's index is shown, so a tab bar and its pages need no code.

## Properties

| Type | Name | Default |
|---|---|---|
| `int` | [`current_tab`](#current_tab) | `0` |
| `Control` | [`pages`](#pages) |  |

## Methods

| Returns | Method |
|---|---|
| `Omni_Button[]` | [`get_tabs`](#get_tabs)() |
| `void` | [`refresh`](#refresh)() |

## Signals

### tab_changed(index: int)

The current tab changed (by a click, a key press or `current_tab`).

## Property descriptions

### current_tab

`int` `current_tab` = `0`

Index of the tab that is on.

### pages

`Control` `pages`

Optional: a container whose children are the pages. Only the child at `current_tab` is visible.

## Method descriptions

### get_tabs

`Omni_Button[]` `get_tabs()`

The tabs, in order.

### refresh

`void` `refresh()`

Re-reads the tabs after you add or remove some from code. Called automatically when the children change.
