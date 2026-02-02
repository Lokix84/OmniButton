using Godot;

public partial class OmniButton : Control
{
    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && !mb.Pressed)
        {
            // If we had an active press/drag/joystick, cleanly end it even if release happened off this control
            if (_isPressed || _vjActive || _isSwiping)
            {
                ResetPressState(emitSwipeEnded: true);

                if (_vjActive)
                {
                    EndVirtualJoystickFromInput(string.Empty);
                    DebugLog("JoystickEnded emitted (_UnhandledInput)");
                }

                FinishReleaseVisuals();
            }
        }
    }
    /// <summary>
    /// Central input handler. Routes press/release, hover-in-bounds checks,
    /// drag follow (respecting FollowMode), swipe detection, and virtual
    /// joystick lifecycle + axis emission.
    /// </summary>
    public override void _GuiInput(InputEvent @event)
    {
        if (FinishTypewriterOnPress && _twActive && IsPressInput(@event))
            SkipTypewriter();

        if (Disabled) return;
        bool inside = IsInputInside(@event);
        if (EnableCooldown && _cooldownActive) return; // disable actions during cooldown
        bool wantJoystick = (FollowMode == FollowModeEnum.VirtualJoystick) || EnableVirtualJoystick;
        if (@event is InputEventScreenTouch st)
        {
            if (st.Pressed)
            {
                // Touch press: mark eligibility if started inside
                _touchSwipeEligible = IsInputInside(st);
                if (_touchSwipeEligible && TouchSwipeInit == SwipeInitMode.OnPressed)
                {
                    _swipeOrigin = st.Position;
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
            }
            else
            {
                // Touch release: optionally end swipe and clear eligibility
                if (TouchSwipeExit == SwipeExitMode.OnReleased)
                {
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
                _touchSwipeEligible = false;
            }
        }
        else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed)
            {
                if (!inside) return; // only react to press when inside
                BeginPressState(mb.Position);
                if (wantJoystick)
                    BeginVirtualJoystickFromInput(mb.GlobalPosition, "mouse press");
                if (FollowMode != FollowModeEnum.None)
                {
                    EnableHoverTopLevel(true);
                    MoveToGlobal(mb.GlobalPosition);
                }
                if ((ActionMask & ActionMaskFlags.Swipe) != 0)
                    _swipeStart = mb.Position;
                EmitPressedAction("mouse");
                bool toggleOnPress = (InteractionMode == InteractionModeEnum.ToggleOnPress) ||
                                      (InteractionMode == InteractionModeEnum.Momentary && ((ActionMask & ActionMaskFlags.Toggle) != 0));
                if (toggleOnPress)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                    DebugLog($"Toggled -> {_isToggled} (mouse press)");
                }
                bool cooldownOnPress = (CooldownTrigger == CooldownTriggerEnum.OnPress || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && cooldownOnPress)
                    CallDeferred(MethodName.StartCooldown);
                if (EnableHoldBuildUp && !_isHolding)
                {
                    _holdTimer = 0; EnsureHoldFill(); UpdateHoldFillVisual(); SetProcess(true);
                }
                FinishPressVisuals();
            }
            else
            {
                ResetPressState(emitSwipeEnded: false);
                EmitReleasedAction("mouse", inside);
                bool cooldownOnRelease = (CooldownTrigger == CooldownTriggerEnum.OnRelease || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && cooldownOnRelease)
                    StartCooldown();
                if (InteractionMode == InteractionModeEnum.ToggleOnRelease)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                    DebugLog($"Toggled -> {_isToggled} (mouse release)");
                }
                if (_vjActive)
                    EndVirtualJoystickFromInput("mouse release");
                FinishReleaseVisuals();
            }
        }
        else if (_isPressed && @event is InputEventMouseMotion mm)
        {
            if (wantJoystick && _vjActive)
            {
                if (JoystickSnapToInput)
                    MoveToGlobal(mm.GlobalPosition);
                EmitJoystickAxisFor(mm.GlobalPosition);
            }
            if (FollowMode != FollowModeEnum.None)
            {
                MoveToGlobal(mm.GlobalPosition);
            }
            // Swipe detection while pressed (mouse motion)
            if ((ActionMask & ActionMaskFlags.Swipe) != 0)
            {
                SwipeStep(mm.Position, "MouseMotion");
            }
            // Update swiping state relative to origin regardless of action mask
            SetSwiping((mm.Position - _swipeOrigin).Length() > SwipeThreshold);
        }
        else if (_isPressed && @event is InputEventScreenDrag sd)
        {
            if (wantJoystick && _vjActive)
            {
                if (JoystickSnapToInput)
                    MoveToGlobal(sd.Position);
                EmitJoystickAxisFor(sd.Position);
            }
            if (FollowMode != FollowModeEnum.None)
            {
                MoveToGlobal(sd.Position);
            }
            // Swipe detection while pressed (touch drag)
            if ((ActionMask & ActionMaskFlags.Swipe) != 0)
            {
                bool insideDrag = IsInputInside(sd);
                bool allowSwipe = (TouchSwipeInit == SwipeInitMode.OnPressed) ? _touchSwipeEligible : insideDrag;
                bool endOnHoverOut = (TouchSwipeExit == SwipeExitMode.OnHoverOut);
                if ((!allowSwipe) || (endOnHoverOut && !insideDrag))
                {
                    // Stop swipe when touch leaves the button bounds
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
                else
                {
                    SwipeStep(sd.Position, "TouchDragPressed");
                }
            }
            // Update swiping state relative to origin regardless of action mask
            SetSwiping(IsInputInside(sd) && (sd.Position - _swipeOrigin).Length() > SwipeThreshold);
        }
        else if (((ActionMask & ActionMaskFlags.Swipe) != 0) && @event is InputEventScreenDrag drag)
        {
            // Only allow swipe while touch remains within button bounds (or started from press inside if required)
            bool insideDrag = IsInputInside(drag);
            bool allowSwipe = (TouchSwipeInit == SwipeInitMode.OnPressed) ? _touchSwipeEligible : insideDrag;
            bool endOnHoverOut = (TouchSwipeExit == SwipeExitMode.OnHoverOut);
            if ((!allowSwipe) || (endOnHoverOut && !insideDrag))
            {
                EndSwiping();
                _swipeStart = Vector2.Zero;
            }
            else
            {
                SwipeStep(drag.Position, "TouchDrag");
            }
        }
        else if (((ActionMask & ActionMaskFlags.Swipe) != 0) && _isPressed && @event is InputEventMouseMotion motion)
        {
            SwipeStep(motion.Position, "MouseMotionHover");
        }
        else if (((ActionMask & ActionMaskFlags.Swipe) != 0) && MouseSwipeInit == SwipeInitMode.OnHoverIn && @event is InputEventMouseMotion hoverMotion)
        {
            bool insideMove = IsInputInside(hoverMotion);
            if (!insideMove)
            {
                if (MouseSwipeExit == SwipeExitMode.OnHoverOut)
                {
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
            }
            else
            {
                if (_swipeStart == Vector2.Zero)
                {
                    _swipeStart = hoverMotion.GlobalPosition;
                    _swipeOrigin = hoverMotion.GlobalPosition;
                }
                else
                {
                    // For hover-init, keep the swipe session alive: advance anchor instead of clearing.
                    SwipeStep(hoverMotion.GlobalPosition, "MouseHover", resetToZero: false);
                }
                // For hover-init, remain in swiping state while inside; exit is controlled by MouseSwipeExit
                SetSwiping(true);
            }
        }
    }
    private bool IsInputInside(InputEvent @event)
    {
        Vector2 position = Vector2.Zero;
        if (@event is InputEventMouseButton mouseButton)
            position = mouseButton.GlobalPosition;
        else if (@event is InputEventMouseMotion mouseMotion)
            position = mouseMotion.GlobalPosition;
        else if (@event is InputEventScreenTouch screenTouch)
            position = screenTouch.Position; // ScreenTouch uses global screen coordinates
        else if (@event is InputEventScreenDrag screenDrag)
            position = screenDrag.Position; // ScreenDrag uses global screen coordinates
        else
            return false;
        Rect2 bounds = BoundsSource != null
            ? new Rect2(BoundsSource.GetGlobalRect().Position, BoundsSource.GetGlobalRect().Size)
            : GetGlobalRect();
        if (HitSlop != Vector2.Zero)
            bounds = bounds.GrowIndividual(HitSlop.X, HitSlop.Y, HitSlop.X, HitSlop.Y);
        return bounds.HasPoint(position);
    }
    private static bool IsPressInput(InputEvent ev)
    {
        if (ev is InputEventScreenTouch st)
            return st.Pressed;
        if (ev is InputEventMouseButton mb)
            return mb.Pressed && mb.ButtonIndex == MouseButton.Left;
        return false;
    }
    private void BeginPressState(Vector2 swipeOrigin)
    {
        _isPressed = true;
        _holdTimer = 0;
        _isHolding = false;
        EndSwiping();
        _swipeOrigin = swipeOrigin;
    }
    private void EmitPressedAction(string sourceTag)
    {
        if ((ActionMask & ActionMaskFlags.Pressed) != 0)
        {
            EmitSignal(SignalName.Pressed);
            DebugLog($"Pressed signal emitted ({sourceTag})");
        }
        else
        {
            DebugLog("Pressed signal skipped (ActionMask)");
        }
    }
    private void EmitReleasedAction(string sourceTag, bool inside)
    {
        if (((ActionMask & ActionMaskFlags.Released) != 0) && inside)
        {
            EmitSignal(SignalName.Released);
            DebugLog($"Released signal emitted ({sourceTag})");
        }
        else if ((ActionMask & ActionMaskFlags.Released) == 0)
        {
            DebugLog("Released signal skipped (ActionMask)");
        }
    }
    private void FinishReleaseVisuals()
    {
        EnableHoverTopLevel(false);
        InvalidateVisualState();
    }
    private void FinishPressVisuals()
    {
        InvalidateVisualState();
    }
    private void SwipeStep(Vector2 position, string source, bool resetToZero = true)
    {
        if (_swipeStart == Vector2.Zero)
        {
            _swipeStart = position;
            return;
        }
        var direction = position - _swipeStart;
        if (direction.Length() > SwipeThreshold)
        {
            var norm = direction.Normalized();
            EmitSignal(SignalName.Swipe, norm);
            DebugLog($"Swipe emitted dir={norm} source={source}");
            _swipeStart = resetToZero ? Vector2.Zero : position;
        }
    }
}
