@tool
class_name OmniMenu
extends OmniOverlay
## the base for the menu screens ([OmniTitleMenu], [OmniPauseMenu]). an [OmniOverlay] with a title
## and a column of buttons.
##
## every [OmniButton] under [code]%Items[/code] is a menu item, and its node name in snake case is its
## id ([code]QuitToTitle[/code] → [code]&"quit_to_title"[/code]). pressing it sends [signal item_pressed]
## with that id. to add one, duplicate an item in the scene, rename it and change its text, then
## connect [signal item_pressed] to do something with it. the look styles the items, same as dialog buttons.

## a menu item got pressed. [param item] is its node name in snake case.
signal item_pressed(item: StringName)

## styles the items like the look's option buttons. the stylized scenes turn this off and style
## them with their [OmniMenuStylizer] instead.
@export var style_items := true
## the options screen that Options opens. empty uses [b]Project Settings > omni_button/menus/options_scene[/b].
@export_file("*.tscn", "*.scn") var options_scene: String = ""

## text at the top of the menu. empty hides it.
@export var title: String = "":
	set(value):
		title = value
		if is_node_ready():
			_apply_title()

## the [Label] showing [member title] (type variation [code]OmniMenuTitle[/code]).
@onready var title_label: Label = get_node_or_null("%Title")
## the container whose [OmniButton] children are the items.
@onready var items_box: Container = %Items

func _ready() -> void:
	super()
	_apply_title()
	if Engine.is_editor_hint():
		return
	for b in get_items():
		var id := StringName(String(b.name).to_snake_case())
		if not b.pressed.is_connected(_on_item_pressed):
			b.pressed.connect(_on_item_pressed.bind(id))

## the items, in order (hidden ones too).
func get_items() -> Array[OmniButton]:
	var out: Array[OmniButton] = []
	if items_box != null:
		for c in items_box.get_children():
			if c is OmniButton:
				out.append(c)
	return out

## the item with id [param item] (node name in snake case), or [code]null[/code].
func get_item(item: StringName) -> OmniButton:
	for b in get_items():
		if StringName(String(b.name).to_snake_case()) == item:
			return b
	return null

## shows or hides an item.
func set_item_visible(item: StringName, on: bool) -> void:
	var b := get_item(item)
	if b != null:
		b.visible = on
		_restyle_items()

func _on_item_pressed(item: StringName) -> void:
	if not is_top():
		return # something's open on top of this menu (a popup, the options screen).
	item_pressed.emit(item)
	_handle_item(item)

## override this to give items built in behavior. runs after [signal item_pressed].
func _handle_item(_item: StringName) -> void:
	pass

func _apply_title() -> void:
	if title_label != null:
		title_label.text = title
		title_label.visible = title != ""

func _on_dialog_theme(t: OmniDialogTheme) -> void:
	if not style_items:
		return
	for b in get_items():
		t.style_option(b)
	_restyle_items()

## one font size for all the visible items, like a popup's buttons.
func _restyle_items() -> void:
	var t := get_dialog_theme()
	if t == null or not style_items or not is_inside_tree() or Engine.is_editor_hint():
		return
	var visible_items: Array[Control] = []
	for b in get_items():
		if b.visible:
			visible_items.append(b)
	if not visible_items.is_empty():
		t.fit_option_group(visible_items)

func _get_default_focus() -> Control:
	for b in get_items():
		if b.visible and not b.disabled:
			return b
	return super()

## opens [param menu] on top of this one, making it from [param scene_path] the first time
## (as a child of this menu, one layer up). gives back the menu.
func _open_child_menu(menu: OmniOverlay, scene_path: String) -> OmniOverlay:
	if options_scene != "":
		scene_path = options_scene
	if menu == null or not is_instance_valid(menu):
		var scene := load(scene_path) as PackedScene
		if scene == null:
			push_error("%s: could not load '%s'." % [name, scene_path])
			return null
		menu = scene.instantiate()
		menu.layer = layer + 1
		add_child(menu)
	if menu.layer <= layer:
		menu.layer = layer + 1
	# hide this menu's panel while the other one's up so they don't show through each other.
	panel.modulate.a = 0.0
	if not menu.closed.is_connected(_on_child_menu_closed):
		menu.closed.connect(_on_child_menu_closed, CONNECT_ONE_SHOT)
	menu.open()
	return menu

func _on_child_menu_closed() -> void:
	panel.modulate.a = 1.0
