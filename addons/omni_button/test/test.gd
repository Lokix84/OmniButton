extends Control

func _ready() -> void:
	$IconButton.DisplayTexture(load("res://addons/omni_button/OmniButton.png"),true)
	$IconButton.PressedAction = func(): print("new pressed functionality")
	$IconButton.ReleasedAction = func(): print("new released functionality")
	$LabelButton.DisplayLabel("Testing")
