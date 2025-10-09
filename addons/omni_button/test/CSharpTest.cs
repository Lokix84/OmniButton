using Godot;
using System;

public partial class CSharpTest : Control
{
    private bool _moveActive = false;
    private bool _activeIsMouse = false;
    private int? _activeTouchIndex = null;

    private Control _gamepad;
    private OmniButton _center;
    private OmniButton _moveArea;
    private OmniButton _up, _down, _left, _right;
    private OmniButton _lastHover;

    // Origin center of the joystick when it was spawned (in global coords)
    private Vector2 _originCenterGlobal;

    public override void _Ready()
    {
        _moveArea = GetNode<OmniButton>("TouchArea/Move");
        _moveArea.Connect(OmniButton.SignalName.Pressed, Callable.From(OnMovePressed));
        _moveArea.Connect(OmniButton.SignalName.Released, Callable.From(OnMoveReleased));

        _gamepad = GetNode<Control>("Gamepad");
        _center = GetNode<OmniButton>("Gamepad/Center");
        _center.BoundsSource = _gamepad; // confine center when following

        _up = GetNodeOrNull<OmniButton>("Gamepad/Up");
        _down = GetNodeOrNull<OmniButton>("Gamepad/Down");
        _left = GetNodeOrNull<OmniButton>("Gamepad/Left");
        _right = GetNodeOrNull<OmniButton>("Gamepad/Right");
    }

    public override void _Input(InputEvent @event)
    {
        // START: touch press inside Move area
        if (!_moveActive)
        {
            if (@event is InputEventScreenTouch st && st.Pressed)
            {
                if (IsPointInNode(_moveArea, st.Position))
                {
                    _activeIsMouse = false;
                    _activeTouchIndex = st.Index;
                    BeginMoveAt(st.Position);
                }
            }
            else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && mb.Pressed)
            {
                if (IsPointInNode(_moveArea, mb.Position))
                {
                    _activeIsMouse = true;
                    _activeTouchIndex = null;
                    BeginMoveAt(mb.Position);
                }
            }
            return;
        }

        // UPDATE: follow active pointer
        if (_moveActive)
        {
            if (_activeIsMouse)
            {
                if (@event is InputEventMouseMotion mm)
                    UpdateCenterFollow(mm.Position);
                else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && !mb.Pressed)
                    EndMove();
            }
            else
            {
                if (@event is InputEventScreenDrag sd && _activeTouchIndex.HasValue && sd.Index == _activeTouchIndex.Value)
                    UpdateCenterFollow(sd.Position);
                else if (@event is InputEventScreenTouch st && !st.Pressed && _activeTouchIndex.HasValue && st.Index == _activeTouchIndex.Value)
                    EndMove();
            }
        }
    }

    public void OnMovePressed()
    {
        if (_moveActive) return;
        _activeIsMouse = true;
        _activeTouchIndex = null;
        BeginMoveAt(GetViewport().GetMousePosition());
    }

    public void OnMoveReleased()
    {
        if (_activeIsMouse && _moveActive)
            EndMove();
    }

    private void BeginMoveAt(Vector2 globalPoint)
    {
        _moveActive = true;
        _gamepad.Visible = true;

        // Place gamepad so its center aligns with the input, clamped inside parent/container.
        var parent = _gamepad.GetParent() as Control;
        Rect2 clamp = parent != null ? parent.GetGlobalRect() : GetViewportRect();

        Vector2 half = _gamepad.Size / 2f;
        Vector2 desiredTopLeft = globalPoint - half;
        Vector2 clampedTopLeft = new Vector2(
            Mathf.Clamp(desiredTopLeft.X, clamp.Position.X, clamp.Position.X + clamp.Size.X - _gamepad.Size.X),
            Mathf.Clamp(desiredTopLeft.Y, clamp.Position.Y, clamp.Position.Y + clamp.Size.Y - _gamepad.Size.Y)
        );
        _gamepad.GlobalPosition = clampedTopLeft;

        // Center the center button
        _center.Position = (_gamepad.Size - _center.Size) / 2f;

        // Start OmniButton's built-in virtual joystick under the user's input
        _center.StartVirtualJoystickAt(globalPoint);
    }

    private void UpdateCenterFollow(Vector2 globalPoint)
    {
        if (!_moveActive || !_gamepad.Visible) return;

        // Drive OmniButton’s joystick update (it clamps to BoundsSource)
        _center.UpdateVirtualJoystick(globalPoint);

        // Keep directional hover behavior
        // Clamp input to gamepad rect so hover sticks to edges when outside
        Rect2 gamepadRect = _gamepad.GetGlobalRect();
        Vector2 clampedGlobal = new Vector2(
            Mathf.Clamp(globalPoint.X, gamepadRect.Position.X, gamepadRect.End.X),
            Mathf.Clamp(globalPoint.Y, gamepadRect.Position.Y, gamepadRect.End.Y)
        );
        UpdateDirectionalHover(clampedGlobal);
    }

    private void EndMove()
    {
        if (!_moveActive) return;

        _moveActive = false;
        _activeIsMouse = false;
        _activeTouchIndex = null;

        if (_lastHover != null) { _lastHover.IsHovering = false; _lastHover = null; }

        // Stop OmniButton’s joystick and hide gamepad
        _center.StopVirtualJoystick();
        _gamepad.Visible = false;
    }

    private void UpdateDirectionalHover(Vector2 globalPoint)
    {
        OmniButton hit = null;

        if (_up != null && IsPointInNode(_up, globalPoint)) hit = _up;
        else if (_down != null && IsPointInNode(_down, globalPoint)) hit = _down;
        else if (_left != null && IsPointInNode(_left, globalPoint)) hit = _left;
        else if (_right != null && IsPointInNode(_right, globalPoint)) hit = _right;

        if (hit == _lastHover) return;

        if (_lastHover != null)
            _lastHover.IsHovering = false;

        if (hit != null)
            hit.IsHovering = true;

        _lastHover = hit;
    }

    private static bool IsPointInNode(Control node, Vector2 globalPoint)
        => node.GetGlobalRect().HasPoint(globalPoint);

    public void ToggleHotBar(int index)
    {
        var hotbar = GetNode<HBoxContainer>("UI/HotbarHUD/SingleSelectList");
        foreach (var child in hotbar.GetChildren())
        {
            if (child is OmniButton button)
            {
                button.Selected = button.GetIndex() == index;
                button.ThemeTypeName = button.GetIndex() == index ? "Selected" : "Unselected";
            }
        }
    }

    public void OnCenterPressed() { /* optional: no-op, handled by joystick flow */ }
    public void OnCenterSwiped() { /* optional: no-op, handled by joystick flow */ }
}
