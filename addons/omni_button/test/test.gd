extends Control

func _ready() -> void:
	$IconTextButton.DisplayTexture(load("res://addons/omni_button/OmniButton.png"),true)
	$LabelButton.DisplayLabel("Testing")
