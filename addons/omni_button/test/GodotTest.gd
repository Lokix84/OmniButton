extends Control

func _ready() -> void:
	var icon_btn: OmniButton = get_node("Directional/IconButton")
	icon_btn.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn.display_texture("res://addons/omni_button/test/icons/Icon-UpArrow1.png")

	var icon_btn2: OmniButton = get_node("Directional/IconButton2")
	icon_btn2.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn2.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn2.display_texture("res://addons/omni_button/test/icons/Icon-LeftArrow1.png")

	var icon_btn3: OmniButton = get_node("Directional/IconButton3")
	icon_btn3.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn3.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn3.display_texture("res://addons/omni_button/test/icons/Icon-RightArrow1.png")

	var icon_btn4: OmniButton = get_node("Directional/IconButton4")
	icon_btn4.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn4.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn4.display_texture("res://addons/omni_button/test/icons/Icon-DownArrow1.png")

	var icon_btn5: OmniButton = get_node("Directional/IconButton5")
	icon_btn5.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn5.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn5.display_texture("res://addons/omni_button/test/icons/Icon-Circle1.png")

	var icon_btn6: OmniButton = get_node("Actions/Attack")
	icon_btn6.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn6.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn6.display_texture("res://addons/omni_button/test/icons/Icon-Sword1.png")

	var icon_btn7: OmniButton = get_node("Actions/Defend")
	icon_btn7.connect_signal("pressed", Callable(self, "on_button_pressed"))
	icon_btn7.connect_signal("released", Callable(self, "on_button_released"))
	icon_btn7.display_texture("res://addons/omni_button/test/icons/Icon-Shield5.png")

	var label_btn: OmniButton = get_node("LabelButton")
	label_btn.display_label("Click Me")
	# (Optional) If you want label button to use its own handlers:
	# label_btn.connect_signal("pressed", Callable(self, "on_label_button_pressed"))
	# label_btn.connect_signal("released", Callable(self, "on_label_button_released"))

func on_button_pressed() -> void:
	print("Icon Button Pressed!")

func on_button_released() -> void:
	print("Icon Button Released!")

func on_label_button_pressed() -> void:
	print("Label Button Pressed!")

func on_label_button_released() -> void:
	print("Label Button Released!")
