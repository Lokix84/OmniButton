extends RefCounted
class_name OmniButtonPresets

static func apply_basic(button: Omni_Button) -> Omni_Button:
	button.InteractionMode = Omni_Button.InteractionModeEnum.Momentary
	button.FollowMode = Omni_Button.FollowModeEnum.None
	button.EnableHoverScale = false
	button.EnableCooldown = false
	button.InvertModes = 0
	return button

static func apply_toggle(button: Omni_Button) -> Omni_Button:
	button.InteractionMode = Omni_Button.InteractionModeEnum.ToggleOnPress
	button.FollowMode = Omni_Button.FollowModeEnum.None
	return button

static func apply_hold(button: Omni_Button, seconds: float = 1.0) -> Omni_Button:
	button.EnableHoldBuildUp = true
	button.HoldDuration = max(0.1, seconds)
	button.FollowMode = Omni_Button.FollowModeEnum.None
	return button

static func apply_swipe(button: Omni_Button, threshold: float = 20.0, mouse_hover_init := true) -> Omni_Button:
	button.SwipeThreshold = max(1.0, threshold)
	button.MouseSwipeInit = Omni_Button.SwipeInitMode.OnHoverIn if mouse_hover_init else Omni_Button.SwipeInitMode.OnPressed
	button.MouseSwipeExit = Omni_Button.SwipeExitMode.OnHoverOut
	button.TouchSwipeInit = Omni_Button.SwipeInitMode.OnPressed
	button.TouchSwipeExit = Omni_Button.SwipeExitMode.OnReleased
	button.FollowMode = Omni_Button.FollowModeEnum.None
	return button

static func apply_draggable(button: Omni_Button) -> Omni_Button:
	button.FollowMode = Omni_Button.FollowModeEnum.FollowBoth
	button.ClampToBounds = true
	return button

static func apply_virtual_joystick(button: Omni_Button) -> Omni_Button:
	button.FollowMode = Omni_Button.FollowModeEnum.VirtualJoystick
	button.ClampShape = Omni_Button.JoystickClampShape.Circle
	button.JoystickDeadzone = 0.15
	button.JoystickSnapToInput = true
	button.JoystickHideWhenInactive = false
	button.JoystickResetOnRelease = true
	button.EnableJoystickArea = true
	button.JoystickAreaPersistent = false
	button.JoystickAreaColor = Color(1, 1, 1, 0.25)
	button.JoystickAreaThickness = 2
	button.JoystickAreaUseRectForClamp = false
	button.JoystickAreaExternalPath = NodePath("")
	return button
