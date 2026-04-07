using Godot;

public partial class OmniButton : Control
{
    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && !mb.Pressed)
        {
            if (_pointerGestureSource == PointerGestureSource.NativeTouch) return;
            // Native touch session uses ScreenTouch release in unhandled; ignore emulated/off-path mouse ups
            if (_activePointerTouchIndex >= 0) return;
            if (_isPressed || _vjActive || _isSwiping)
            {
                ResetPressState(emitSwipeEnded: true);

                if (_vjActive)
                {
                    EndVirtualJoystickFromInput(string.Empty);
                    DebugLog("JoystickEnded emitted (_UnhandledInput)");
                }

                FinishReleaseVisuals();
                GetViewport().SetInputAsHandled();
            }
        }
        else if (@event is InputEventScreenTouch st && !st.Pressed)
        {
            if (_pointerGestureSource != PointerGestureSource.NativeTouch) return;
            if (_activePointerTouchIndex < 0 || st.Index != _activePointerTouchIndex) return;
            if (_isPressed || _vjActive || _isSwiping)
            {
                ResetPressState(emitSwipeEnded: true);
                if (_vjActive)
                {
                    EndVirtualJoystickFromInput("_UnhandledInput touch");
                    DebugLog("JoystickEnded emitted (_UnhandledInput touch)");
                }
                FinishReleaseVisuals();
                GetViewport().SetInputAsHandled();
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
        // Block *new* interactions during cooldown, but still process drags/releases for an in-flight press.
        if (EnableCooldown && _cooldownActive && !_isPressed) return;
        bool inside = IsInputInside(@event);
        bool wantJoystick = (FollowMode == FollowModeEnum.VirtualJoystick) || EnableVirtualJoystick;
        if (@event is InputEventScreenTouch st)
        {
            if (st.Pressed)
            {
                _touchSwipeEligible = IsInputInside(st);
                if (_touchSwipeEligible && TouchSwipeInit == SwipeInitMode.OnPressed)
                {
                    _swipeOrigin = st.Position;
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
                if (!inside) return;
                if (_pointerGestureSource == PointerGestureSource.Mouse) return;
                _pointerGestureSource = PointerGestureSource.NativeTouch;
                _activePointerTouchIndex = st.Index;
                BeginPressState(st.Position);
                if (wantJoystick)
                    BeginVirtualJoystickFromInput(st.Position, "touch press");
                if (FollowMode != FollowModeEnum.None)
                {
                    EnableHoverTopLevel(true);
                    MoveToGlobal(st.Position);
                }
                if ((ActionMask & ActionMaskFlags.Swipe) != 0)
                    _swipeStart = st.Position;
                EmitPressedAction("touch");
                bool touchToggleOnPress = (InteractionMode == InteractionModeEnum.ToggleOnPress) ||
                    (InteractionMode == InteractionModeEnum.Momentary && ((ActionMask & ActionMaskFlags.Toggle) != 0));
                if (touchToggleOnPress)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                    DebugLog($"Toggled -> {_isToggled} (touch press)");
                }
                bool touchCooldownOnPress = (CooldownTrigger == CooldownTriggerEnum.OnPress || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && touchCooldownOnPress)
                    CallDeferred(MethodName.StartCooldown);
                if (EnableHoldBuildUp && !_isHolding)
                {
                    _holdTimer = 0; EnsureHoldFill(); UpdateHoldFillVisual(); SetProcess(true);
                }
                FinishPressVisuals();
            }
            else if (_activePointerTouchIndex >= 0 && st.Index == _activePointerTouchIndex)
            {
                if (_pointerGestureSource != PointerGestureSource.NativeTouch) return;
                if (TouchSwipeExit == SwipeExitMode.OnReleased)
                {
                    EndSwiping();
                    _swipeStart = Vector2.Zero;
                }
                _touchSwipeEligible = false;
                ResetPressState(emitSwipeEnded: false);
                EmitReleasedAction("touch", inside);
                bool touchCooldownOnRelease = (CooldownTrigger == CooldownTriggerEnum.OnRelease || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && touchCooldownOnRelease)
                    StartCooldown();
                if (InteractionMode == InteractionModeEnum.ToggleOnRelease)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                    DebugLog($"Toggled -> {_isToggled} (touch release)");
                }
                if (_vjActive)
                    EndVirtualJoystickFromInput("touch release");
                FinishReleaseVisuals();
            }
        }
        else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed)
            {
                if (!inside) return; // only react to press when inside
                if (_pointerGestureSource == PointerGestureSource.NativeTouch) return;
                _pointerGestureSource = PointerGestureSource.Mouse;
                _activePointerTouchIndex = -1;
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
                if (_pointerGestureSource == PointerGestureSource.NativeTouch) return;
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
        else if (_isPressed && @event is InputEventScreenDrag sd && ScreenDragMatchesActiveTouch(sd))
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
        else if (((ActionMask & ActionMaskFlags.Swipe) != 0) && @event is InputEventScreenDrag drag && ScreenDragMatchesActiveTouch(drag))
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
        else if (TryProcessKeyboardUiAccept(@event)) { }
    }

    private bool ScreenDragMatchesActiveTouch(InputEventScreenDrag d) =>
        _activePointerTouchIndex < 0 || d.Index == _activePointerTouchIndex;

    /// <summary>Space/Enter (ui_accept) when focused: skip typewriter if configured, else one-shot click. Skips joystick/follow modes.</summary>
    private bool TryProcessKeyboardUiAccept(InputEvent @event)
    {
        if (FocusMode == FocusModeEnum.None || !HasFocus()) return false;
        if (@event is not InputEventKey ik || !ik.Pressed || ik.Echo) return false;
        if (!InputMap.EventIsAction(@event, "ui_accept", true)) return false;
        if (FinishTypewriterOnPress && _twActive)
        {
            SkipTypewriter();
            AcceptEvent();
            return true;
        }
        if (Disabled) return false;
        bool wantVj = (FollowMode == FollowModeEnum.VirtualJoystick) || EnableVirtualJoystick;
        if (wantVj || FollowMode != FollowModeEnum.None) return false;
        if (EnableCooldown && _cooldownActive && !_isPressed) return false;
        if (_isPressed) return false;
        AcceptEvent();
        _pointerGestureSource = PointerGestureSource.Mouse;
        _activePointerTouchIndex = -1;
        BeginPressState(Size / 2f);
        EmitPressedAction("keyboard");
        bool toggleOnPress = (InteractionMode == InteractionModeEnum.ToggleOnPress) ||
                             (InteractionMode == InteractionModeEnum.Momentary && ((ActionMask & ActionMaskFlags.Toggle) != 0));
        if (toggleOnPress)
        {
            _isToggled = !_isToggled;
            UpdateOverlay();
            EmitSignal(SignalName.Toggled, _isToggled);
            DebugLog($"Toggled -> {_isToggled} (keyboard press)");
        }
        bool cooldownOnPress = (CooldownTrigger == CooldownTriggerEnum.OnPress || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
        if (EnableCooldown && cooldownOnPress)
            CallDeferred(MethodName.StartCooldown);
        if (EnableHoldBuildUp && !_isHolding)
        {
            _holdTimer = 0; EnsureHoldFill(); UpdateHoldFillVisual(); SetProcess(true);
        }
        FinishPressVisuals();

        ResetPressState(emitSwipeEnded: false);
        EmitReleasedAction("keyboard", true);
        bool cooldownOnRelease = (CooldownTrigger == CooldownTriggerEnum.OnRelease || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
        if (EnableCooldown && cooldownOnRelease)
            StartCooldown();
        if (InteractionMode == InteractionModeEnum.ToggleOnRelease)
        {
            _isToggled = !_isToggled;
            UpdateOverlay();
            EmitSignal(SignalName.Toggled, _isToggled);
            DebugLog($"Toggled -> {_isToggled} (keyboard release)");
        }
        FinishReleaseVisuals();
        return true;
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
        Rect2 bounds = (BoundsSource != null && IsInstanceValid(BoundsSource))
            ? BoundsSource.GetGlobalRect()
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
