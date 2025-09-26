using System;
using Godot;

[Tool]
public partial class OmniButton : Control
{
    // ---------- Signals ----------
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool button_pressed);
    [Signal] public delegate void ReleasedEventHandler();
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

    // ---------- Private Variables ----------
    private bool _pressedLock = false;
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

        SafeConnect(SignalName.Pressed, nameof(OnPressed));
        SafeConnect(SignalName.Toggled, nameof(OnToggled));
        SafeConnect(SignalName.Released, nameof(OnReleased));
        SafeConnect(SignalName.Log, nameof(OnLog));
        SafeConnect(SignalName.MouseEntered, nameof(OnMouseEntered));
        SafeConnect(SignalName.MouseExited, nameof(OnMouseExited));
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
            if (FireOnce())
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

        if (@event is InputEventMouseButton mb && mb.Pressed && mb.ButtonIndex == MouseButton.Left)
        {
            if (PointInside(mb.GlobalPosition) && FireOnce())
                return;
        }
        else if (@event is InputEventScreenTouch touch && touch.Pressed)
        {
            var globalPosition = Position + touch.Position;
            if (PointInside(globalPosition) && FireOnce())
                return;
        }
    }

    // ---------- Hover and Scaling ----------
    private void OnMouseEntered()
    {
        if (EnableHoverActions)
        {
            RunBuiltInHoverIn();
        }
    }

    private void OnMouseExited()
    {
        if (EnableHoverActions)
        {
            RunBuiltInHoverOut();
        }
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
    public void DisplayLabel(string text, Theme theme = null)
    {
        OnLog("Debug", $"CustomButton: {Name} Setting label...");
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

    private bool FireOnce()
    {
        if (_pressedLock)
        {
            OnLog("Warning", $"CustomButton: {Name} Button press ignored because it is locked.");
            return false;
        }

        _pressedLock = true;
        OnLog("Info", $"CustomButton: {Name} Button pressed.");
        EmitSignal(SignalName.Pressed);
        CallDeferred(MethodName.UnlockPress);
        return true;
    }

    private bool ActionAllowed()
    {
        if (RequireFocusForAction)
            return HasFocus();

        return HasFocus() || PointInside(GetViewport().GetMousePosition());
    }

    private void UnlockPress()
    {
        OnLog("Info", $"CustomButton: {Name} Unlocking button press.");
        _pressedLock = false;
    }

    private void SafeConnect(StringName signal, string method)
    {
        var callable = new Callable(this, method);
        if (!IsConnected(signal, callable))
            Connect(signal, callable);
    }

    private void DisconnectAllLocalSignalHandlers()
    {
        var signals = new[]
        {
            SignalName.Pressed,
            SignalName.Toggled,
            SignalName.Released,
            SignalName.Log
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
        if (!EnablePressActions || ButtonDisabled) return;
        PressedAction.Call();
    }

    private void OnToggled(bool button_pressed)
    {
        if (!EnableToggleActions || ButtonDisabled) return;
        ToggledAction.Call(button_pressed);
    }

    private void OnReleased()
    {
        if (!EnableReleaseActions || ButtonDisabled) return;
        ReleasedAction.Call();
    }

    private void OnLog(string type, string message)
    {
        RunBuiltInLog(type, message);
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


