extends Control

func _ready() -> void:
	var sprint_toggle : OmniButton = $Directional/SprintToggle
	sprint_toggle.texture = preload("res://addons/omni_button/test/icons/Icon-Circle1.png")

func on_button_pressed() -> void:
	print("Icon Button Pressed!")

func on_button_released() -> void:
	print("Icon Button Released!")

func on_label_button_pressed() -> void:
	print("Label Button Pressed!")

func on_label_button_released() -> void:
	print("Label Button Released!")

func _on_sprint_toggle_toggled(button_pressed: bool) -> void:
	print("Sprint Toggle: " + str(button_pressed))

func _on_defend_toggled(button_pressed: bool) -> void:
	print("Defend Toggle: " + str(button_pressed))
