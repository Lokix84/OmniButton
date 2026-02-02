using Godot;
using System;

public partial class OmniButton : Control
{
private Control? GetExternalJoystickArea()
    {
        if (JoystickAreaExternalPath.IsEmpty) return null;
        return GetNodeOrNull<Control>(JoystickAreaExternalPath);
    }
private void EnsureAndRefreshJoystickArea(Vector2 homeCenterGlobal)
    {
        if (!EnableJoystickArea) return;
        var target = GetExternalJoystickArea();
        if (target == null)
        {
            if (_vjAreaPanel == null || !IsInstanceValid(_vjAreaPanel))
            {
                _vjAreaPanel = new Panel();
                _vjAreaPanel.Name = "JoystickArea";
                _vjAreaPanel.TopLevel = true;
                _vjAreaPanel.MouseFilter = MouseFilterEnum.Ignore;
                _vjAreaPanel.ZIndex = -1000;
                ManagedAddChild(_vjAreaPanel);
            }
            target = _vjAreaPanel;
            var sb = new StyleBoxFlat();
            sb.BgColor = new Color(0, 0, 0, 0);
            sb.BorderColor = JoystickAreaColor;
            sb.BorderWidthTop = sb.BorderWidthBottom = sb.BorderWidthLeft = sb.BorderWidthRight = JoystickAreaThickness;
            _vjAreaPanel.AddThemeStyleboxOverride("panel", sb);
        }
        var clampRect = GetFollowClampRect();
        bool useCircle = (ClampShape == JoystickClampShape.Circle) && !JoystickAreaUseRectForClamp;
        if (useCircle)
        {
            float radius = JoystickRadiusPx > 0 ? JoystickRadiusPx : ComputeAutoJoystickRadius(homeCenterGlobal, clampRect);
            var size = new Vector2(radius * 2f, radius * 2f);
            if (target is Panel p && p.GetThemeStylebox("panel") is StyleBoxFlat flat)
            {
                int r = (int)Mathf.Round(radius);
                flat.CornerRadiusTopLeft = flat.CornerRadiusTopRight = flat.CornerRadiusBottomLeft = flat.CornerRadiusBottomRight = r;
            }
            target.Size = size;
            target.GlobalPosition = homeCenterGlobal - size / 2f;
        }
        else
        {
            Vector2 halfExtents = JoystickRectSizePx != Vector2.Zero ? JoystickRectSizePx / 2f : ComputeAutoJoystickHalfExtents(homeCenterGlobal, clampRect);
            var size = halfExtents * 2f;
            if (target is Panel p && p.GetThemeStylebox("panel") is StyleBoxFlat flat)
            {
                flat.CornerRadiusTopLeft = flat.CornerRadiusTopRight = flat.CornerRadiusBottomLeft = flat.CornerRadiusBottomRight = 0;
            }
            target.Size = size;
            target.GlobalPosition = homeCenterGlobal - size / 2f;
        }
    }
private void SetJoystickAreaVisible(bool vis)
    {
        var external = GetExternalJoystickArea();
        if (external != null)
            external.Visible = vis;
        else if (_vjAreaPanel != null && IsInstanceValid(_vjAreaPanel))
            _vjAreaPanel.Visible = vis;
    }
private float ComputeAutoJoystickRadius(Vector2 homeCenterGlobal, Rect2 clamp)
    {
        // Max circle that fits inside the clamp rect around the home center
        float left = (float)(homeCenterGlobal.X - clamp.Position.X);
        float right = (float)((clamp.Position.X + clamp.Size.X) - homeCenterGlobal.X);
        float top = (float)(homeCenterGlobal.Y - clamp.Position.Y);
        float bottom = (float)((clamp.Position.Y + clamp.Size.Y) - homeCenterGlobal.Y);
        return Math.Max(1f, Math.Min(Math.Min(left, right), Math.Min(top, bottom)));
    }
private Vector2 ComputeAutoJoystickHalfExtents(Vector2 homeCenterGlobal, Rect2 clamp)
    {
        float left = (float)(homeCenterGlobal.X - clamp.Position.X);
        float right = (float)((clamp.Position.X + clamp.Size.X) - homeCenterGlobal.X);
        float top = (float)(homeCenterGlobal.Y - clamp.Position.Y);
        float bottom = (float)((clamp.Position.Y + clamp.Size.Y) - homeCenterGlobal.Y);
        return new Vector2(Math.Max(1f, Math.Min(left, right)), Math.Max(1f, Math.Min(top, bottom)));
    }
private void EmitJoystickAxisFor(Vector2 pointerGlobal)
    {
        // Current stick center (global)
        var currentCenter = GlobalPosition + Size / 2f;
        // Clamp pointer to movement bounds to keep axis consistent with visible clamp
        var clamp = GetFollowClampRect(); // already respects BoundsSource or parent
        var clamped = new Vector2(
            Mathf.Clamp(pointerGlobal.X, clamp.Position.X, clamp.Position.X + clamp.Size.X),
            Mathf.Clamp(pointerGlobal.Y, clamp.Position.Y, clamp.Position.Y + clamp.Size.Y)
        );
        // Use clamped point to infer the target center (where we tried to move to)
        // Then compute axis from home -> target
        var delta = (clamped - _vjHomeGlobal);
        Vector2 axis;
        bool useCircle = (ClampShape == JoystickClampShape.Circle);
        if (useCircle)
        {
            float radius = JoystickRadiusPx > 0
                ? JoystickRadiusPx
                : ComputeAutoJoystickRadius(_vjHomeGlobal, clamp);
            float len = delta.Length();
            axis = (len < 1e-4f || radius < 1e-4f) ? Vector2.Zero : (delta / radius);
            if (axis.Length() > 1f) axis = axis.Normalized();
        }
        else
        {
            Vector2 halfExtents = JoystickRectSizePx != Vector2.Zero
                ? JoystickRectSizePx / 2f
                : ComputeAutoJoystickHalfExtents(_vjHomeGlobal, clamp);
            float hx = Math.Max(1e-4f, halfExtents.X);
            float hy = Math.Max(1e-4f, halfExtents.Y);
            axis = new Vector2(Mathf.Clamp(delta.X / hx, -1f, 1f), Mathf.Clamp(delta.Y / hy, -1f, 1f));
        }
        // Deadzone
        if (axis.Length() < JoystickDeadzone)
            axis = Vector2.Zero;
    EmitSignal(SignalName.JoystickAxis, axis);
    }
private void BeginVirtualJoystickFromInput(Vector2 globalPoint, string debugTag)
    {
        if (!EnableVirtualJoystick && FollowMode != FollowModeEnum.VirtualJoystick)
            return;
        _vjActive = true;
        _vjHomeGlobal = GlobalPosition + Size / 2f;
        EnableHoverTopLevel(true);
        if (JoystickSnapToInput)
            MoveToGlobal(globalPoint);
        if (JoystickHideWhenInactive)
            Visible = true;
        EmitSignal(SignalName.JoystickStarted);
        if (!string.IsNullOrEmpty(debugTag))
            DebugLog($"JoystickStarted ({debugTag})");
        EmitJoystickAxisFor(globalPoint);
        if (EnableJoystickArea)
        {
            EnsureAndRefreshJoystickArea(_vjHomeGlobal);
            SetJoystickAreaVisible(true);
        }
    }
private void EndVirtualJoystickFromInput(string debugTag)
    {
        if (!_vjActive) return;
        EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
        if (!string.IsNullOrEmpty(debugTag))
            DebugLog($"JoystickAxis zero ({debugTag})");
        EmitSignal(SignalName.JoystickEnded);
        if (!string.IsNullOrEmpty(debugTag))
            DebugLog($"JoystickEnded ({debugTag})");
        if (JoystickResetOnRelease)
            GlobalPosition = _vjHomeGlobal - Size / 2f;
        if (JoystickHideWhenInactive)
            Visible = false;
        _vjActive = false;
        if (EnableJoystickArea && !JoystickAreaPersistent)
            SetJoystickAreaVisible(false);
    }
public void StartVirtualJoystickAt(Vector2 globalPoint)
    {
        // Allow programmatic start if either the explicit flag is on
        // or this button is configured to use VirtualJoystick follow mode.
        if (!EnableVirtualJoystick && FollowMode != FollowModeEnum.VirtualJoystick)
            return;
        DebugLog($"Virtual joystick started at {globalPoint}");
        _vjActive = true;
        _vjHomeGlobal = GlobalPosition + Size / 2f;
        // Keep visuals consistent with a press
        _isPressed = true;
        InvalidateVisualState();
        // Allow input to pass through this button (so underlying controls can hover)
        _vjSavedMouseFilter = MouseFilter;
        MouseFilter = MouseFilterEnum.Ignore;
        // Move in screen space and clamp to bounds
        EnableHoverTopLevel(true);
        if (JoystickSnapToInput)
            MoveToGlobal(globalPoint);
        if (JoystickHideWhenInactive)
            Visible = true;
        EmitSignal(SignalName.JoystickStarted);
        DebugLog("JoystickStarted emitted (programmatic)");
        EmitJoystickAxisFor(globalPoint);
        if (EnableJoystickArea)
        {
            EnsureAndRefreshJoystickArea(_vjHomeGlobal);
            SetJoystickAreaVisible(true);
        }
    }
public void UpdateVirtualJoystick(Vector2 globalPoint)
    {
        if (!_vjActive) return;
        if (JoystickSnapToInput)
            MoveToGlobal(globalPoint);
        EmitJoystickAxisFor(globalPoint);
    }
public void StopVirtualJoystick()
    {
        if (!_vjActive) return;
        EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
        EmitSignal(SignalName.JoystickEnded);
        DebugLog("Virtual joystick stopped");
        if (JoystickResetOnRelease)
            GlobalPosition = _vjHomeGlobal - Size / 2f;
        _vjActive = false;
        ResetPressState(emitSwipeEnded: true);
        InvalidateVisualState();
        // Restore original mouse filter and top-level state
        MouseFilter = _vjSavedMouseFilter;
        EnableHoverTopLevel(false);
        if (EnableJoystickArea && !JoystickAreaPersistent)
            SetJoystickAreaVisible(false);
        if (JoystickHideWhenInactive)
            Visible = false;
    }
}
