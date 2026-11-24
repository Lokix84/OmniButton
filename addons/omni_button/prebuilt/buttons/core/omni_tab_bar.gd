@tool
class_name OmniTabBar
extends HBoxContainer
## A row of [Omni_Button] tabs where exactly one is on at a time, for tabs, category filters and
## "pick one" choices.
##
## Every [Omni_Button] child is a tab, in order (add one by duplicating a tab). The tab that is on
## uses the button's pressed style. Set [member pages] to a container and only the child with the
## current tab's index is shown, so a tab bar and its pages need no code.

## The current tab changed (by a click, a key press or [member current_tab]).
signal tab_changed(index: int)

## Index of the tab that is on.
@export var current_tab := 0:
	set(value):
		current_tab = value
		if is_node_ready():
			_apply(true)
## Optional: a container whose children are the pages. Only the child at [member current_tab] is visible.
@export var pages: Control

func _ready() -> void:
	refresh()
	if not child_order_changed.is_connected(_on_children_changed):
		child_order_changed.connect(_on_children_changed)

## The tabs, in order.
func get_tabs() -> Array[Omni_Button]:
	var tabs: Array[Omni_Button] = []
	for child in get_children():
		if child is Omni_Button:
			tabs.append(child)
	return tabs

## Re-reads the tabs after you add or remove some from code. Called automatically when the children change.
func refresh() -> void:
	var tabs := get_tabs()
	for i in tabs.size():
		var tab := tabs[i]
		tab.InteractionMode = Omni_Button.InteractionModeEnum.ToggleOnPress
		tab.EnableToggleActions = true
		for c in tab.toggled.get_connections():
			if c["callable"].get_object() == self:
				tab.toggled.disconnect(c["callable"])
		tab.toggled.connect(_on_tab_toggled.bind(i))
	_apply(false)

func _on_children_changed() -> void:
	if is_inside_tree():
		refresh.call_deferred()

func _on_tab_toggled(on: bool, index: int) -> void:
	if on and index != current_tab:
		current_tab = index
	else:
		# Pressing the tab that is already on keeps it on.
		_apply(false)

func _apply(notify: bool) -> void:
	var tabs := get_tabs()
	if tabs.is_empty():
		return
	var index := clampi(current_tab, 0, tabs.size() - 1)
	for i in tabs.size():
		if tabs[i].IsToggled != (i == index):
			tabs[i].IsToggled = i == index
	if pages != null:
		var page_index := 0
		for child in pages.get_children():
			if child is CanvasItem:
				child.visible = page_index == index
				page_index += 1
	if notify and not Engine.is_editor_hint():
		tab_changed.emit(index)
