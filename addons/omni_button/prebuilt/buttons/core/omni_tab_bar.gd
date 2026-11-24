@tool
class_name OmniTabBar
extends HBoxContainer
## a row of [OmniButton] tabs where only one is on at a time. for tabs, category filters and
## "pick one" choices.
##
## every [OmniButton] child is a tab, in order (duplicate a tab to add one). the tab that's on uses
## the button's pressed style. point [member pages] at a container and only the child matching the
## current tab's index shows, so a tab bar and its pages don't need any code.

## the current tab changed (a click, a key press, or setting [member current_tab]).
signal tab_changed(index: int)

## index of the tab that's on.
@export var current_tab := 0:
	set(value):
		current_tab = value
		if is_node_ready():
			_apply(true)
## optional. a container whose children are the pages, only the one at [member current_tab] shows.
@export var pages: Control

func _ready() -> void:
	refresh()
	if not child_order_changed.is_connected(_on_children_changed):
		child_order_changed.connect(_on_children_changed)

## the tabs, in order.
func get_tabs() -> Array[OmniButton]:
	var tabs: Array[OmniButton] = []
	for child in get_children():
		if child is OmniButton:
			tabs.append(child)
	return tabs

## rereads the tabs if you added or removed some from code. it already does this when the children change.
func refresh() -> void:
	var tabs := get_tabs()
	for i in tabs.size():
		var tab := tabs[i]
		tab.interaction_mode = OmniButton.InteractionMode.TOGGLE_ON_PRESS
		tab.enable_toggle_actions = true
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
		# pressing the tab that's already on keeps it on.
		_apply(false)

func _apply(notify: bool) -> void:
	var tabs := get_tabs()
	if tabs.is_empty():
		return
	var index := clampi(current_tab, 0, tabs.size() - 1)
	for i in tabs.size():
		if tabs[i].is_toggled != (i == index):
			tabs[i].is_toggled = i == index
	if pages != null:
		var page_index := 0
		for child in pages.get_children():
			if child is CanvasItem:
				child.visible = page_index == index
				page_index += 1
	if notify and not Engine.is_editor_hint():
		tab_changed.emit(index)
