@tool
extends EditorPlugin


func _enter_tree() -> void:
	add_custom_type("Omni_Button", "Control", preload("res://addons/omni_button/GD/omni_button.gd"), preload("res://addons/omni_button/OmniButton.png"))

func _exit_tree() -> void:
	remove_custom_type("Omni_Button")
