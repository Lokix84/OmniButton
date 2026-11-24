@tool
@icon("res://addons/omni_button/prebuilt/dialog/core/icons/toast.svg")
extends OmniOverlay
class_name OmniToast
## Short messages near the top of the screen that disappear on their own.
##
## Toasts never take focus or react to cancel, so a popup open at the same time keeps working. Several can show at once, newest at the bottom. Each toast is an [code]Omni_Button[/code] made from [member item_scene]: its panel comes from the look's [code]OmniDialogToast[/code] style, long text wraps and shrinks to fit, and clicking it dismisses it.
## [codeblock]
## $Toast.toast("Game saved")
## $Toast.toast("Achievement unlocked", 4.0)
## [/codeblock]

@export_group("Toasts")
## Seconds a toast stays up when no duration is given.
@export_range(0.1, 30.0, 0.1, "suffix:s") var default_duration: float = 2.0
## Oldest toasts are removed when more than this many are showing.
@export_range(1, 20) var max_visible: int = 4
## Seconds each toast takes to fade in and out.
@export_range(0.0, 2.0, 0.01, "suffix:s") var fade_time: float = 0.2
## Clicking or tapping a toast dismisses it. Off: toasts let clicks through to the game.
@export var dismiss_on_click: bool = true
## Scene each toast is made from ([code]parts/omni_toast_item.tscn[/code]). Edit it, or point this at your own, to restyle or resize toasts.
@export var item_scene: PackedScene = preload("res://addons/omni_button/prebuilt/dialog/parts/omni_toast_item.tscn")

## [VBoxContainer] the toasts are added to.
@onready var toast_list: VBoxContainer = %Toasts

var _items: Array[Control] = []

## Same as [method toast].
func show_toast(text: String, duration: float = -1.0) -> void:
	if Engine.is_editor_hint():
		return
	var item: Control = item_scene.instantiate()
	item.set("Text", text)
	var t := get_dialog_theme()
	if t != null:
		t.style_text(item)
	toast_list.add_child(item)
	if dismiss_on_click and item.has_signal("pressed"):
		item.connect("pressed", _on_item_pressed.bind(item))
	else:
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_items.append(item)
	while _items.size() > max_visible:
		_remove(_items[0], false)
	if not is_open():
		open()
	if fade_time > 0.0:
		item.modulate.a = 0.0
		create_tween().tween_property(item, "modulate:a", 1.0, fade_time)
	var wait := default_duration if duration < 0.0 else duration
	await get_tree().create_timer(wait, true, false, true).timeout
	if is_instance_valid(item) and _items.has(item):
		await _remove(item, true)

## Shows [param text] for [param duration] seconds ([member default_duration] when negative). Await it only to wait until it's gone. Not affected by pausing or [member Engine.time_scale].
func toast(text: String, duration: float = -1.0) -> void:
	await show_toast(text, duration)

## Returns how many toasts are showing.
func count() -> int:
	return _items.size()

## Removes every toast at once.
func clear() -> void:
	for item in _items.duplicate():
		_remove(item, false)

func _on_dialog_theme(t: OmniDialogTheme) -> void:
	for item in _items:
		if is_instance_valid(item):
			t.style_text(item)

func _on_item_pressed(item: Control) -> void:
	if _items.has(item):
		_remove(item, true)

func _remove(item: Control, fade: bool) -> void:
	_items.erase(item)
	if fade and fade_time > 0.0 and is_instance_valid(item):
		item.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var tw := create_tween()
		tw.tween_property(item, "modulate:a", 0.0, fade_time)
		await tw.finished
	if is_instance_valid(item):
		item.queue_free()
	if _items.is_empty() and is_open():
		close()
