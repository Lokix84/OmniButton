@tool
extends EditorPlugin
## Editor plugin: registers the Omni_Button type and its Inspector plugin, and re-syncs buttons
## when the editor's undo/redo history changes.

const OmniButtonInspector = preload("res://addons/omni_button/omni_button_inspector.gd")
const EDITOR_POLL_GROUP := &"_omni_button_editor_poll"
var _omni_button_inspector: EditorInspectorPlugin
var _sync_queued := false

## Editor sync is event-driven: every Inspector edit, undo/redo and signal (dis)connection goes
## through the editor's undo/redo history, so we re-check buttons only when that history changes
## (or the edited scene switches) instead of rebuilding a property signature for every button
## five times a second. Each button still compares its signature and only refreshes on change.

func _enter_tree() -> void:
	add_custom_type("Omni_Button", "Control", preload("res://addons/omni_button/omni_button.gd"), preload("res://addons/omni_button/OmniButtonGDV1.png"))
	_omni_button_inspector = OmniButtonInspector.new()
	add_inspector_plugin(_omni_button_inspector)
	var undo_redo := get_undo_redo()
	if undo_redo != null and not undo_redo.version_changed.is_connected(_queue_sync):
		undo_redo.version_changed.connect(_queue_sync)
	if not scene_changed.is_connected(_on_scene_changed):
		scene_changed.connect(_on_scene_changed)

func _on_scene_changed(_root: Node) -> void:
	_queue_sync()

## Coalesce bursts (e.g. dragging a slider emits many versions) into one pass per frame.
func _queue_sync() -> void:
	if _sync_queued:
		return
	_sync_queued = true
	call_deferred("_sync_buttons")

func _sync_buttons() -> void:
	_sync_queued = false
	var edited_scene_root := EditorInterface.get_edited_scene_root()
	if edited_scene_root == null:
		return
	var scene_tree := edited_scene_root.get_tree()
	if scene_tree == null:
		return
	for node in scene_tree.get_nodes_in_group(EDITOR_POLL_GROUP):
		if is_instance_valid(node) and node.is_inside_tree():
			node.call("_editor_poll")

func _exit_tree() -> void:
	var undo_redo := get_undo_redo()
	if undo_redo != null and undo_redo.version_changed.is_connected(_queue_sync):
		undo_redo.version_changed.disconnect(_queue_sync)
	if scene_changed.is_connected(_on_scene_changed):
		scene_changed.disconnect(_on_scene_changed)
	remove_inspector_plugin(_omni_button_inspector)
	_omni_button_inspector = null
	remove_custom_type("Omni_Button")
