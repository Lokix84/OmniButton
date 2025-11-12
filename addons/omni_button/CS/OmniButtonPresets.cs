using Godot;

namespace OmniButtonKit
{
    public static class OmniButtonPresets
    {
        public static OmniButton ApplyBasic(this OmniButton b)
        {
            b.InteractionMode = OmniButton.InteractionModeEnum.Momentary;
            b.FollowMode = OmniButton.FollowModeEnum.None;
            b.EnableHoverScale = false;
            b.EnableCooldown = false;
            b.InvertModes = OmniButton.InvertDisplayModes.None;
            return b;
        }

        public static OmniButton ApplyToggle(this OmniButton b)
        {
            b.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress;
            b.FollowMode = OmniButton.FollowModeEnum.None;
            return b;
        }

        public static OmniButton ApplyHold(this OmniButton b, float seconds = 1.0f)
        {
            b.EnableHoldBuildUp = true;
            b.HoldDuration = Mathf.Max(0.1f, seconds);
            b.FollowMode = OmniButton.FollowModeEnum.None;
            return b;
        }

        public static OmniButton ApplySwipe(this OmniButton b, float threshold = 20f, bool mouseHoverInit = true)
        {
            b.SwipeThreshold = Mathf.Max(1f, threshold);
            b.MouseSwipeInit = mouseHoverInit ? OmniButton.SwipeInitMode.OnHoverIn : OmniButton.SwipeInitMode.OnPressed;
            b.MouseSwipeExit = OmniButton.SwipeExitMode.OnHoverOut;
            b.TouchSwipeInit = OmniButton.SwipeInitMode.OnPressed;
            b.TouchSwipeExit = OmniButton.SwipeExitMode.OnReleased;
            b.FollowMode = OmniButton.FollowModeEnum.None;
            return b;
        }

        public static OmniButton ApplyDraggable(this OmniButton b)
        {
            b.FollowMode = OmniButton.FollowModeEnum.FollowBoth;
            b.ClampToBounds = true;
            return b;
        }

        public static OmniButton ApplyVirtualJoystick(this OmniButton b)
        {
            b.FollowMode = OmniButton.FollowModeEnum.VirtualJoystick;
            b.ClampShape = OmniButton.JoystickClampShape.Circle;
            b.JoystickDeadzone = 0.15f;
            b.JoystickSnapToInput = true;
            b.JoystickHideWhenInactive = false;
            b.JoystickResetOnRelease = true;
            // Enable default area ring
            b.EnableJoystickArea = true;
            b.JoystickAreaPersistent = false;
            b.JoystickAreaColor = new Color(1, 1, 1, 0.25f);
            b.JoystickAreaThickness = 2;
            b.JoystickAreaUseRectForClamp = false;
            b.JoystickAreaExternalPath = new NodePath("");
            return b;
        }
    }
}
