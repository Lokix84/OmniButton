using Godot;
using System;
using System.Collections.Generic;

public partial class CSharpTest : Control
{
    private bool _moveActive = false;
    private bool _lookActive = false;
    private int? _activeTouchIndex = null;
    private int? _activeLookTouchIndex = null;

    private Control _gamepad;
    private OmniButton _center;
    private OmniButton _moveArea;
    private Control _lookjoystick;
    private OmniButton _lookcenter;
    private OmniButton _lookArea;

    private OmniButton _up, _down, _left, _right;
    private OmniButton _lastHover;

    // Selected item list support
    private Node _selectedContainer;
    private readonly List<OmniButton> _selectedButtons = new();

    // Logger
    private OmniButton _output;

    public override void _Ready()
    {
        _moveArea = GetNode<OmniButton>("TouchArea/Move");
        _lookArea = GetNode<OmniButton>("TouchArea/Look");
        _gamepad = GetNode<Control>("Gamepad");
        _center = GetNode<OmniButton>("Gamepad/Center");
        _center.BoundsSource = _gamepad; // confine joystick to gamepad area
        _lookjoystick = GetNode<Control>("LookJoystick");
        _lookcenter = GetNode<OmniButton>("LookJoystick/Center");
        _lookcenter.BoundsSource = _lookjoystick;

        _up = GetNodeOrNull<OmniButton>("Gamepad/Up");
        _down = GetNodeOrNull<OmniButton>("Gamepad/Down");
        _left = GetNodeOrNull<OmniButton>("Gamepad/Left");
        _right = GetNodeOrNull<OmniButton>("Gamepad/Right");

        // Start joystick only when Move area itself receives the press (selected items above it will consume input)
        _moveArea.Connect(Control.SignalName.GuiInput, new Callable(this, nameof(OnMoveGuiInput)));
        _lookArea.Connect(Control.SignalName.GuiInput, new Callable(this, nameof(OnLookGuiInput)));

        // Discover selected item container (adjust path if yours differs)
        _selectedContainer = GetNodeOrNull<Node>("UI/HotbarHUD/SingleSelectList")
                             ?? GetNodeOrNull<Node>("SelectedItems");
        if (_selectedContainer != null)
            WireSelectedItems(_selectedContainer);

        // Find the ButtonOutput logger
        _output = GetNodeOrNull<OmniButton>("%ButtonOutput")
                  ?? GetNodeOrNull<OmniButton>("ButtonOutput")
                  ?? (GetTree().GetFirstNodeInGroup("Output") as OmniButton);

        if (_output != null)
        {
            _output.LabelText = "Logger ready";
            ConnectAllButtonsToOutput(_output);
        }
    }

    private void OnMoveGuiInput(InputEvent ev)
    {
        if (_moveActive) return;

        if (ev is InputEventScreenTouch st && st.Pressed)
        {
            _activeTouchIndex = st.Index;
            BeginMoveAt(st.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (ev is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && mb.Pressed)
        {
            _activeTouchIndex = null; // mouse
            BeginMoveAt(mb.GlobalPosition);
            GetViewport().SetInputAsHandled();
        }
    }

    private void OnLookGuiInput(InputEvent ev)
    {
        if (_lookActive) return;

        if (ev is InputEventScreenTouch st && st.Pressed)
        {
            _activeLookTouchIndex = st.Index;
            BeginLookAt(st.Position);
            GetViewport().SetInputAsHandled();
        }
        else if (ev is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && mb.Pressed)
        {
            _activeLookTouchIndex = null; // mouse
            BeginLookAt(mb.GlobalPosition);
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _Input(InputEvent @event)
    {
        if (!_moveActive && !_lookActive) return;

        if (@event is InputEventScreenDrag sd)
        {
            if (_moveActive && _activeTouchIndex.HasValue && sd.Index == _activeTouchIndex.Value)
                UpdateCenterFollow(sd.Position);
            if (_lookActive && _activeLookTouchIndex.HasValue && sd.Index == _activeLookTouchIndex.Value)
                UpdateLookFollow(sd.Position);
        }
        else if (@event is InputEventMouseMotion mm)
        {
            if (_moveActive && !_activeTouchIndex.HasValue)
                UpdateCenterFollow(mm.GlobalPosition);
            if (_lookActive && !_activeLookTouchIndex.HasValue)
                UpdateLookFollow(mm.GlobalPosition);
        }

        else if (@event is InputEventScreenTouch st && !st.Pressed)
        {
            if (_moveActive && _activeTouchIndex.HasValue && st.Index == _activeTouchIndex.Value)
                EndMove();
            if (_lookActive && _activeLookTouchIndex.HasValue && st.Index == _activeLookTouchIndex.Value)
                EndLook();
        }
        else if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && !mb.Pressed)
        {
            if (_moveActive && !_activeTouchIndex.HasValue)
                EndMove();
            if (_lookActive && !_activeLookTouchIndex.HasValue)
                EndLook();
        }
    }

    private void BeginMoveAt(Vector2 globalPoint)
    {
        _moveActive = true;
        _gamepad.Visible = true;

        // Place gamepad centered on input, clamped to its parent/container.
        var parent = _gamepad.GetParent() as Control;
        Rect2 clamp = parent != null ? parent.GetGlobalRect() : GetViewportRect();
        Vector2 half = _gamepad.Size / 2f;
        Vector2 desiredTL = globalPoint - half;
        _gamepad.GlobalPosition = new Vector2(
            Mathf.Clamp(desiredTL.X, clamp.Position.X, clamp.End.X - _gamepad.Size.X),
            Mathf.Clamp(desiredTL.Y, clamp.Position.Y, clamp.End.Y - _gamepad.Size.Y)
        );

        // Center the stick and start OmniButton's built-in virtual joystick
        _center.Position = (_gamepad.Size - _center.Size) / 2f;
        _center.StartVirtualJoystickAt(globalPoint);
    }

    private void BeginLookAt(Vector2 globalPoint)
    {

        _lookActive = true;
        _lookjoystick.Visible = true;
        // Place look joystick centered on input, clamped to its parent/container.
        var parent = _lookjoystick.GetParent() as Control;
        Rect2 clamp = parent != null ? parent.GetGlobalRect() : GetViewportRect();
        Vector2 half = _lookjoystick.Size / 2f;
        Vector2 desiredTL = globalPoint - half;
        _lookjoystick.GlobalPosition = new Vector2(
            Mathf.Clamp(desiredTL.X, clamp.Position.X, clamp.End.X - _lookjoystick.Size.X),
            Mathf.Clamp(desiredTL.Y, clamp.Position.Y, clamp.End.Y - _lookjoystick.Size.Y)
        );

        // Center the stick and start OmniButton's built-in virtual joystick
        _lookcenter.Position = (_lookjoystick.Size - _lookcenter.Size) / 2f;
        _lookcenter.StartVirtualJoystickAt(globalPoint);
    }

    private void UpdateLookFollow(Vector2 globalPoint)
    {
        if (!_lookActive || !_lookjoystick.Visible) return;
        _lookcenter.UpdateVirtualJoystick(globalPoint);
    }

    private void UpdateCenterFollow(Vector2 globalPoint)
    {
        if (!_moveActive || !_gamepad.Visible) return;

        // Drive OmniButton’s joystick update (handles clamping and axis)
        _center.UpdateVirtualJoystick(globalPoint);

        // Synthesize arrow hover; clamp probe to gamepad rect so it sticks to edges
        Rect2 gp = _gamepad.GetGlobalRect();
        Vector2 probe = new(
            Mathf.Clamp(globalPoint.X, gp.Position.X, gp.End.X),
            Mathf.Clamp(globalPoint.Y, gp.Position.Y, gp.End.Y)
        );
        UpdateDirectionalHover(probe);
    }

    private void EndMove()
    {
        if (!_moveActive) return;

        _moveActive = false;
        _activeTouchIndex = null;

        if (_lastHover != null) { _lastHover.IsHovering = false; _lastHover = null; }

        _center.StopVirtualJoystick();
        _gamepad.Visible = false;
    }

    private void EndLook()
    {
        if (!_lookActive) return;

        _lookActive = false;
        _activeLookTouchIndex = null;

        _lookcenter.StopVirtualJoystick();
        _lookjoystick.Visible = false;
    }

    private void UpdateDirectionalHover(Vector2 globalPoint)
    {
        OmniButton hit = null;
        if (_up != null && IsPointInNode(_up, globalPoint)) hit = _up;
        else if (_down != null && IsPointInNode(_down, globalPoint)) hit = _down;
        else if (_left != null && IsPointInNode(_left, globalPoint)) hit = _left;
        else if (_right != null && IsPointInNode(_right, globalPoint)) hit = _right;

        if (hit == _lastHover) return;

        if (_lastHover != null) _lastHover.IsHovering = false;
        if (hit != null) hit.IsHovering = true;

        _lastHover = hit;
    }

    // Selected item helpers
    private void WireSelectedItems(Node container)
    {
        _selectedButtons.Clear();
        foreach (var child in container.GetChildren())
        {
            if (child is OmniButton ob)
            {
                _selectedButtons.Add(ob);
                ob.Connect(OmniButton.SignalName.Pressed, Callable.From(() => OnSelectedItemPressed(ob)));
            }
        }
    }

    private void OnSelectedItemPressed(OmniButton clicked)
    {
        for (int i = 0; i < _selectedButtons.Count; i++)
        {
            var b = _selectedButtons[i];
            b.Selected = b == clicked;
        }
    }

    private static bool IsPointInNode(Control node, Vector2 globalPoint)
        => node.GetGlobalRect().HasPoint(globalPoint);

    // ===== Logging wiring =====
    private void ConnectAllButtonsToOutput(OmniButton output)
    {
        // Prefer group "Button" if present; else scan the tree.
        var list = new List<OmniButton>();
        var grouped = GetTree().GetNodesInGroup("Button");
        if (grouped.Count > 0)
        {
            foreach (var n in grouped)
                if (n is OmniButton g && g != output)
                    list.Add(g);
        }
        else
        {
            CollectOmniButtons(this, output, list);
        }

        foreach (var b in list)
            ConnectButtonForLog(b, output);
    }

    private void CollectOmniButtons(Node root, OmniButton skip, List<OmniButton> dst)
    {
        foreach (var child in root.GetChildren())
        {
            if (child is OmniButton ob && ob != skip)
                dst.Add(ob);
            if (child is Node n)
                CollectOmniButtons(n, skip, dst);
        }
    }

    private void ConnectButtonForLog(OmniButton b, OmniButton output)
    {
        // Capture b per-iteration
        var btn = b;

        void SetOut(string msg)
        {
            if (GodotObject.IsInstanceValid(output))
                output.LabelText = msg;
        }

        SafeConnect(btn, OmniButton.SignalName.Pressed, Callable.From(() => SetOut($"[{btn.Name}] Pressed")));
        SafeConnect(btn, OmniButton.SignalName.Released, Callable.From(() => SetOut($"[{btn.Name}] Released")));
        SafeConnect(btn, OmniButton.SignalName.Toggled, Callable.From<bool>(v => SetOut($"[{btn.Name}] Toggled: {v}")));
        SafeConnect(btn, OmniButton.SignalName.HoverIn, Callable.From(() => SetOut($"[{btn.Name}] HoverIn")));
        SafeConnect(btn, OmniButton.SignalName.HoverOut, Callable.From(() => SetOut($"[{btn.Name}] HoverOut")));
        SafeConnect(btn, OmniButton.SignalName.Hold, Callable.From(() => SetOut($"[{btn.Name}] Hold")));
        SafeConnect(btn, OmniButton.SignalName.Swipe, Callable.From<Vector2>(dir => SetOut($"[{btn.Name}] Swipe: {dir}")));

        // If using virtual joystick on any button, log those too
        SafeConnect(btn, OmniButton.SignalName.JoystickStarted, Callable.From(() => SetOut($"[{btn.Name}] JoystickStarted")));
        SafeConnect(btn, OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(axis => SetOut($"[{btn.Name}] JoystickAxis: {axis}")));
        SafeConnect(btn, OmniButton.SignalName.JoystickEnded, Callable.From(() => SetOut($"[{btn.Name}] JoystickEnded")));

        // Optional: log custom messages
        SafeConnect(btn, OmniButton.SignalName.Log, Callable.From<string>(m => SetOut($"[{btn.Name}] Log: {m}")));
        SafeConnect(btn, OmniButton.SignalName.Warning, Callable.From<string>(m => SetOut($"[{btn.Name}] Warn: {m}")));
        SafeConnect(btn, OmniButton.SignalName.Error, Callable.From<string>(m => SetOut($"[{btn.Name}] Error: {m}")));
    }

    private void SafeConnect(GodotObject obj, StringName signal, Callable callable)
    {
        if (!obj.IsConnected(signal, callable))
            obj.Connect(signal, callable);
    }
}
