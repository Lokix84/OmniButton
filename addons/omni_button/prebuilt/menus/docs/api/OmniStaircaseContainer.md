# OmniStaircaseContainer

**Inherits:** `Container`

Stacks its children like a `VBoxContainer`, shifting each one sideways by `step`, so a list follows a slant (the stylized menus line their items up with the angled bands).

## Properties

| Type | Name | Default |
|---|---|---|
| `float` | [`separation`](#separation) | `6.0` |
| `float` | [`step`](#step) | `-18.0` |

## Property descriptions

### separation

`float` `separation` = `6.0`

Space between items.

### step

`float` `step` = `-18.0`

Sideways shift per item: negative moves each lower item left, positive right.
