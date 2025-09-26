using System;
using Godot;

[Tool]
public partial class OmniButton : Control
{
    // ---------- Signals ----------
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool button_pressed);
    [Signal] public delegate void ReleasedEventHandler();
    [Signal] public delegate void HoverInEventHandler();
    [Signal] public delegate void HoverOutEventHandler();
    [Signal] public delegate void LogEventHandler(string type, string message);

    // ---------- Enums ----------
    public enum ButtonType
    {
        Button,
        Toggle
    }

    // ---------- Export Groups ----------

    // General Settings
    [ExportGroup("General Settings")]
    [Export] public ButtonType Type { get; set; } = ButtonType.Button;
    [Export] public bool ButtonDisabled { get; private set; } = false;

    // Input Settings
    [ExportGroup("Input Settings")]
    [Export] public string ActionName { get; set; } = "ui_accept";
    [Export] public bool RequireFocusForAction { get; set; } = true;

    // Bounds and Hit Detection
    [ExportGroup("Bounds and Hit Detection")]
    [Export] public Control BoundsSource { get; set; }
    [Export] public Godot.Vector2 HitSlop { get; set; } = Godot.Vector2.Zero;

    [ExportGroup("Press Actions")]
    [Export] public bool EnablePressActions { get; set; } = true;
    [Export] public Callable PressedAction { get; set; }
    [Export] public bool EnableReleaseActions { get; set; } = false;
    [Export] public Callable ReleasedAction { get; set; }

    [ExportGroup("Toggle Actions")]
    [Export] public bool EnableToggleActions { get; set; } = false;
    [Export] public Callable ToggledAction { get; set; }

    // Hover and Scaling
    [ExportGroup("Hover and Scaling")]
    [Export] public bool EnableHoverActions { get; set; } = false;
    [Export] public Callable HoverInAction { get; set; }
    [Export] public Callable HoverOutAction { get; set; }
    [Export] public float HoverScale { get; set; } = 1.25f;
    [Export] public float HoverLerpSpeed { get; set; } = 25.0f;

    // Font Size Settings
    [ExportGroup("Font Size Settings")]
    [Export] public int MinFontSize { get; set; } = 12; // Minimum font size
    [Export] public int MaxFontSize { get; set; } = 100; // Maximum font size

    // Logging
    [ExportGroup("Logging")]
    [Export] public Callable LogAction { get; set; }

    // ---------- Private Variables ----------
    // Signal locks
    private bool _pressedLock = false;
    private bool _releasedLock = false;
    private bool _toggledLock = false;
    private bool _logLock = false;
    private Godot.Vector2 originalScale = Godot.Vector2.One;

    // ---------- Lifecycle Methods ----------
    public override void _EnterTree()
    {
        // Initialize default actions to their built-in methods
        PressedAction = new Callable(this, nameof(RunBuiltInPressed));
        ReleasedAction = new Callable(this, nameof(RunBuiltInReleased));
        HoverInAction = new Callable(this, nameof(RunBuiltInHoverIn));
        HoverOutAction = new Callable(this, nameof(RunBuiltInHoverOut));
        ToggledAction = new Callable(this, nameof(RunBuiltInToggled));
        LogAction = new Callable(this, nameof(RunBuiltInLog));

        // Use ConnectSignal to manage signal connections
        ConnectSignal(nameof(SignalName.Pressed), PressedAction);
        ConnectSignal(nameof(SignalName.Released), ReleasedAction);
        ConnectSignal(nameof(SignalName.Toggled), ToggledAction);
        ConnectSignal(nameof(SignalName.Log), LogAction);
        ConnectSignal(nameof(SignalName.HoverIn), HoverInAction);
        ConnectSignal(nameof(SignalName.HoverOut), HoverOutAction);

        Connect("mouse_entered", new Callable(this, nameof(OnMouseEntered)));
        Connect("mouse_exited", new Callable(this, nameof(OnMouseExited)));
    }

    public override void _ExitTree()
    {
        DisconnectAllLocalSignalHandlers();
    }

    public override void _Ready()
    {
        base._Ready();
        BoundsSource ??= this;

        if (Engine.IsEditorHint())
        {
            NotifyPropertyListChanged();
        }
    }

    // ---------- Input Handling ----------
    public override void _UnhandledInput(InputEvent @event)
    {
        if (ButtonDisabled)
        {
            OnLog("Warning", $"CustomButton: {Name} Button is disabled. Ignoring unhandled input.");
            return;
        }

        if (!string.IsNullOrEmpty(ActionName) && @event.IsActionPressed(ActionName) && ActionAllowed())
        {
            OnPressed();
            GetViewport().SetInputAsHandled();
        }
    }

    public override void _GuiInput(InputEvent @event)
    {
        if (ButtonDisabled)
        {
            OnLog("Warning", $"CustomButton: {Name} Button is disabled. Ignoring input.");
            return;
        }

        if (@event is InputEventMouseButton mb)
        {
            if (mb.Pressed && mb.ButtonIndex == MouseButton.Left)
            {
                // Handle button press
                if (PointInside(mb.GlobalPosition) && !_pressedLock)
                {
                    OnPressed();
                    GetViewport().SetInputAsHandled();
                    return;
                }
            }
            else if (!mb.Pressed && mb.ButtonIndex == MouseButton.Left)
            {
                // Handle button release
                if (PointInside(mb.GlobalPosition))
                {
                    OnReleased();
                    GetViewport().SetInputAsHandled();
                }
            }
        }
        else if (@event is InputEventScreenTouch touch)
        {
            if (touch.Pressed)
            {
                var globalPosition = Position + touch.Position;
                if (PointInside(globalPosition) && !_pressedLock)
                {
                    OnPressed();
                    GetViewport().SetInputAsHandled();
                    return;
                }
            }
            else
            {
                // Handle touch release
                var globalPosition = Position + touch.Position;
                if (PointInside(globalPosition))
                {
                    OnReleased();
                    GetViewport().SetInputAsHandled();
                }
            }
        }
    }

    // ---------- Hover and Scaling ----------
    private void OnMouseEntered()
    {
        if (!EnableHoverActions || ButtonDisabled) return;

        EmitSignal(SignalName.HoverIn);
    }

    private void OnMouseExited()
    {
        if (!EnableHoverActions || ButtonDisabled) return;

        EmitSignal(SignalName.HoverOut);
    }

    private void RunBuiltInHoverIn()
    {
        PivotOffset = Size / 2;
        Scale = Scale.Lerp(Godot.Vector2.One * HoverScale, (float)(HoverLerpSpeed * GetProcessDeltaTime()));
    }

    private void RunBuiltInHoverOut()
    {
        PivotOffset = Size / 2;
        Scale = Scale.Lerp(Godot.Vector2.One / HoverScale, (float)(HoverLerpSpeed * GetProcessDeltaTime()));
    }

    // ---------- Utility Methods ----------
    public void DisplayLabel(string text) => DisplayLabel(text, null);
    public void DisplayLabel(string text, Theme theme = null)
    {
        OnLog("Debug", $"CustomButton: {Name} Setting label text to '{text}'...");
        Label lbl = GetNodeOrNull<Label>("Label");
        if (lbl == null || !GodotObject.IsInstanceValid(lbl))
        {
            OnLog("Warning", $"CustomButton: {Name} Label is null or invalid. Creating a new label...");
            lbl = new Label
            {
                Name = "Label",
                MouseFilter = MouseFilterEnum.Ignore,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                AutowrapMode = Godot.TextServer.AutowrapMode.Word
            };
            lbl.SetAnchorsPreset(LayoutPreset.FullRect);
            AddChild(lbl);
        }

        lbl.Text = text;

        // Apply the provided theme or use the control's existing theme
        if (theme != null)
        {
            lbl.Theme = theme;
        }
        else
        {
            lbl.Theme = Theme; // Use the control's existing theme
        }

        // Dynamically adjust font size
        DynamicFontAdjust(lbl, text);
    }

    public void DisplayTexture(string texturepath, bool stretch = true)
    {
        DisplayTexture(GD.Load<Texture2D>(texturepath), stretch);
    }

    public void DisplayTexture(Texture2D texture, bool stretch = true)
    {
        OnLog("Debug", $"CustomButton: {Name} Setting texture...");
        TextureRect tr = GetNodeOrNull<TextureRect>("Icon");
        if (tr == null || !GodotObject.IsInstanceValid(tr))
        {
            OnLog("Warning", $"CustomButton: {Name} Icon is null or invalid. Creating a new texture rect...");
            tr = new TextureRect
            {
                Name = "Icon",
                MouseFilter = MouseFilterEnum.Ignore
            };
            tr.SetAnchorsPreset(LayoutPreset.FullRect);
            AddChild(tr);
        }

        tr.StretchMode = stretch ? TextureRect.StretchModeEnum.Scale
                                   : TextureRect.StretchModeEnum.KeepAspectCentered;
        tr.ExpandMode = stretch ? TextureRect.ExpandModeEnum.IgnoreSize
                                 : TextureRect.ExpandModeEnum.KeepSize;
        tr.Texture = texture;
    }

    private void DynamicFontAdjust(Label lbl, string text)
    {
        // Get the label's available size
        var availableSize = lbl.Size;

        // Start with the minimum font size
        int fontSize = MinFontSize;
        int maxFontSize = MaxFontSize; // Set an upper limit for the font size

        // Get the label's theme font
        var themeFont = lbl.GetThemeFont("font");
        if (themeFont == null)
        {
            OnLog("Warning", $"CustomButton: {Name} Label does not have a theme font. Using default font.");
            return;
        }

        // Find the largest font size that fits within the available space
        while (fontSize <= maxFontSize)
        {
            // Measure the text size with the current font size
            var textSize = themeFont.GetStringSize(text, HorizontalAlignment.Center, -1, fontSize);

            // Check if the text fits within the available size
            if (textSize.X > availableSize.X || textSize.Y > availableSize.Y)
            {
                // If it doesn't fit, reduce the font size and break
                fontSize--;
                break;
            }

            fontSize++;
        }

        // Apply the largest fitting font size using theme override
        lbl.AddThemeFontSizeOverride("font_size", fontSize);
        lbl.AddThemeFontOverride("font", themeFont);
    }

    // ---------- Private Helpers ----------
    private bool PointInside(Godot.Vector2 globalPoint)
    {
        var src = BoundsSource ?? this;
        var rect = src.GetGlobalRect()
            .GrowIndividual(HitSlop.X, HitSlop.Y, HitSlop.X, HitSlop.Y);
        return rect.HasPoint(globalPoint);
    }

    private bool ActionAllowed()
    {
        if (RequireFocusForAction)
            return HasFocus();

        return HasFocus() || PointInside(GetViewport().GetMousePosition());
    }

    private void UnlockPress()
    {
        _pressedLock = false;
    }

    public void ConnectSignal(string signalName, Callable newCallable)
    {
        // Validate the signal name
        if (string.IsNullOrEmpty(signalName))
        {
            GD.PushError($"CustomButton: {Name} Signal name cannot be null or empty.");
            return;
        }

        // Get the current callable for the signal
        Callable currentCallable = signalName switch
        {
            nameof(SignalName.Pressed) => PressedAction,
            nameof(SignalName.Released) => ReleasedAction,
            nameof(SignalName.Toggled) => ToggledAction,
            nameof(SignalName.HoverIn) => HoverInAction,
            nameof(SignalName.HoverOut) => HoverOutAction,
            nameof(SignalName.Log) => LogAction,
            _ => default
        };

        if (currentCallable.Target == null)
        {
            GD.PushError($"CustomButton: {Name} Invalid signal name '{signalName}'.");
            return;
        }

        // Disconnect the old callable if it exists
        if (IsConnected(signalName, currentCallable))
        {
            Disconnect(signalName, currentCallable);
        }

        // Connect the new callable
        if (newCallable.Target != null)
        {
            Connect(signalName, newCallable);

            // Update the corresponding action property
            switch (signalName)
            {
                case nameof(SignalName.Pressed):
                    PressedAction = newCallable;
                    break;
                case nameof(SignalName.Released):
                    ReleasedAction = newCallable;
                    break;
                case nameof(SignalName.Toggled):
                    ToggledAction = newCallable;
                    break;
                case nameof(SignalName.Log):
                    LogAction = newCallable;
                    break;
                case nameof(SignalName.HoverIn):
                    HoverInAction = newCallable;
                    break;
                case nameof(SignalName.HoverOut):
                    HoverOutAction = newCallable;
                    break;
            }
        }
        else
        {
            GD.PushWarning($"CustomButton: {Name} New callable for signal '{signalName}' is null or invalid. Signal will be disconnected.");
        }
    }

    private void DisconnectAllLocalSignalHandlers()
    {
        var signals = new[]
        {
            SignalName.Pressed,
            SignalName.Toggled,
            SignalName.Released,
            SignalName.Log,
            SignalName.HoverIn,
            SignalName.HoverOut
        };

        foreach (var sig in signals)
        {
            var connections = GetSignalConnectionList(sig);
            foreach (Godot.Collections.Dictionary dict in connections)
            {
                var callable = (Callable)dict["callable"];
                // Only disconnect handlers whose target object is this node
                if (callable.Target == this && IsConnected(sig, callable))
                {
                    Disconnect(sig, callable);
                }
            }
        }
    }

    // Default (now dispatcher) handlers
    private void OnPressed()
    {
        if (_pressedLock || !EnablePressActions || ButtonDisabled) return;

        _pressedLock = true; // Lock the button to prevent multiple presses
        EmitSignal(SignalName.Pressed);
        CallDeferred(nameof(UnlockPress)); // Unlock the button after the current frame
    }

    private void OnToggled(bool button_pressed)
    {
        if (_toggledLock || !EnableToggleActions || ButtonDisabled) return;

        _toggledLock = true; // Lock the button to prevent multiple toggles
        EmitSignal(SignalName.Toggled, button_pressed);
        CallDeferred(nameof(UnlockToggle)); // Unlock the button after the current frame
    }

    private void OnReleased()
    {
        if (_releasedLock || !EnableReleaseActions || ButtonDisabled) return;

        _releasedLock = true; // Lock the button to prevent multiple releases
        EmitSignal(SignalName.Released);
        CallDeferred(nameof(UnlockRelease)); // Unlock the button after the current frame
    }

    private void UnlockRelease()
    {
        _releasedLock = false;
    }

    private void UnlockToggle()
    {
        _toggledLock = false;
    }

    private void OnLog(string type, string message)
    {
        if (_logLock) return;

        _logLock = true; // Lock the log to prevent multiple log calls
        EmitSignal(SignalName.Log, type, message);
        CallDeferred(nameof(UnlockLog)); // Unlock the log after the current frame
    }

    private void UnlockLog()
    {
        _logLock = false;
    }

    // Built‑in fallback behaviors
    private void RunBuiltInPressed()
    {
        RunBuiltInLog("info", $"PressedAction not set; running built-in logic for {Name}.");
    }

    private void RunBuiltInToggled(bool button_pressed)
    {
        RunBuiltInLog("info", $"ToggledAction not set; running built-in logic for {Name}.");
    }

    private void RunBuiltInReleased()
    {
        RunBuiltInLog("info", $"ReleasedAction not set; running built-in logic for {Name}.");
    }

    private void RunBuiltInLog(string type, string message)
    {
        if (type.ToLower() == "error")
            GD.PushError(message);
        else if (type.ToLower() == "warning")
            GD.PushWarning(message);
        else
            GD.Print(message);
    }

    public override void _Notification(int what)
    {
        // Check if the notification is a resize event
        if (what == NotificationResized)
        {
            // Adjust the font size dynamically when the button is resized
            Label lbl = GetNodeOrNull<Label>("Label");
            if (lbl != null && GodotObject.IsInstanceValid(lbl))
            {
                DynamicFontAdjust(lbl, lbl.Text);
            }
        }
    }
}


