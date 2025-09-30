using Godot;
using Godot.Collections;

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

    // ---------- Export Groups ----------

    // General Settings
    [ExportGroup("General Settings")]
    private bool _buttonDisabled = false;
    [Export]
    public bool ButtonDisabled
    {
        get => _buttonDisabled;
        set
        {
            _buttonDisabled = value;
            if (value)
            {
                _isPointerDown = false;
                ApplyVisualState();
            }
        }
    }

    // ---------- Input & Hit Detection ----------
    [ExportGroup("Input & Hit Detection")]
    [Export] public string ActionName { get; set; } = "ui_accept";
    [Export] public bool RequireFocusForAction { get; set; } = true;
    [Export] public Control BoundsSource { get; set; }
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;

    // ---------- Interaction & Actions ----------
    [ExportGroup("Interaction & Actions")]
    [Export] public bool EnablePressActions { get; set; } = true;
    [Export] public Callable PressedAction { get; set; }
    [Export] public bool EnableReleaseActions { get; set; } = false;
    [Export] public Callable ReleasedAction { get; set; }

    [Export] public bool EnableToggleActions { get; set; } = false;

    private bool _togglePressed = false;
    [Export]
    public bool TogglePressed
    {
        get => _togglePressed;
        set
        {
            if (_togglePressed == value) return;
            _togglePressed = value;
            ApplyVisualState(); // live swap (tool)
            if (EnableToggleActions && !Engine.IsEditorHint())
                EmitSignal(SignalName.Toggled, _togglePressed);
        }
    }

    [Export] public Callable ToggledAction { get; set; }

    // ---------- Hover and Scaling ----------
    [ExportGroup("Hover and Scaling")]
    [Export] public bool EnableHoverActions { get; set; } = false;
    [Export] public Callable HoverInAction { get; set; }
    [Export] public Callable HoverOutAction { get; set; }
    [Export] public float HoverScale { get; set; } = 1.25f;
    [Export] public float HoverLerpSpeed { get; set; } = 25.0f;

    // ---------- Text & Font ----------
    [ExportGroup("Text & Font")]
    [Export] public int MinFontSize { get; set; } = 12;
    [Export] public int MaxFontSize { get; set; } = 100;

    private string _text = "";
    [Export]
    public string Text
    {
        get => _text;
        set
        {
            if (value == null) value = "";
            var s = value.ToString();
            if (s == _text) return;
            _text = s;
            DisplayLabel(_text);
        }
    }

    // ---------- Icon ----------
    [ExportGroup("Icon")]
    [Export] public bool IconStretch { get; set; } = true;
    [Export] public bool IconKeepAspect { get; set; } = true;

    // ---------- Texture ----------
    [ExportGroup("Texture")]
    private Texture2D _normalTexture;
    [Export]
    public Texture2D Texture
    {
        get => _normalTexture;
        set
        {
            _normalTexture = value;
            EnsureIcon();
            ApplyVisualState();
        }
    }

    private Texture2D _pressedTexture;
    [Export]
    public Texture2D PressedTexture
    {
        get => _pressedTexture;
        set
        {
            _pressedTexture = value;
            ApplyVisualState();
        }
    }

    // ---------- Theme keys ----------
    private const string T_TEXT_NORMAL = "text_color";
    private const string T_TEXT_HOVER = "text_color_hover";
    private const string T_TEXT_PRESSED = "text_color_pressed";
    private const string T_TEXT_DISABLED = "text_color_disabled";

    private const string T_ICON_TINT_NORMAL = "icon_tint";
    private const string T_ICON_TINT_HOVER = "icon_tint_hover";
    private const string T_ICON_TINT_PRESSED = "icon_tint_pressed";
    private const string T_ICON_TINT_DISABLED = "icon_tint_disabled";

    private const string T_BG = "panel"; // StyleBox

    private const string T_FONT = "font";
    private const string T_FONT_SIZE = "font_size";

    // ---------- Backing fields ----------
    private bool _isPointerDown = false;
    private ShaderMaterial _invertMat;
    private float _hoverTargetScale = 1.0f;

    // ---------- Theme & Visuals ----------
    [ExportGroup("Theme & Visuals")]
    private string _themeTypeName = "OmniButton";
    [Export]
    public string ThemeTypeName
    {
        get => _themeTypeName;
        set
        {
            _themeTypeName = value;
            ThemeTypeVariation = value;
            CallDeferred(nameof(ApplyThemeNow));
        }
    }

    // ---------- Logging ----------
    [ExportGroup("Logging")]
    [Export] public Callable LogAction { get; set; }

    // ---------- Private Vars ----------
    private bool _pressedLock = false;
    private bool _releasedLock = false;
    private bool _toggledLock = false;
    private bool _logLock = false;
    private Vector2 _originalScale = Vector2.One;
    private bool _hovering = false;
    private bool _themeApplying = false;
    private bool _fittingLabel = false;

    // ---------- Lifecycle ----------
    public override void _EnterTree()
    {
        // Build fallbacks
        var fbPressed = new Callable(this, nameof(RunBuiltInPressed));
        var fbReleased = new Callable(this, nameof(RunBuiltInReleased));
        var fbHoverIn = new Callable(this, nameof(RunBuiltInHoverIn));
        var fbHoverOut = new Callable(this, nameof(RunBuiltInHoverOut));
        var fbToggled = new Callable(this, nameof(RunBuiltInToggled));
        var fbLog = new Callable(this, nameof(RunBuiltInLog));

        // Adopt existing editor connections if present, otherwise use fallbacks
        PressedAction = AdoptConnectedCallable(SignalName.Pressed, fbPressed);
        ReleasedAction = AdoptConnectedCallable(SignalName.Released, fbReleased);
        HoverInAction = AdoptConnectedCallable(SignalName.HoverIn, fbHoverIn);
        HoverOutAction = AdoptConnectedCallable(SignalName.HoverOut, fbHoverOut);
        ToggledAction = AdoptConnectedCallable(SignalName.Toggled, fbToggled);
        LogAction = AdoptConnectedCallable(SignalName.Log, fbLog);

        // Only connect our fallback if the signal has no connections yet
        if (GetSignalConnectionList(SignalName.Pressed).Count == 0 && PressedAction.Equals(fbPressed))
            Connect(SignalName.Pressed, PressedAction);
        if (GetSignalConnectionList(SignalName.Released).Count == 0 && ReleasedAction.Equals(fbReleased))
            Connect(SignalName.Released, ReleasedAction);
        if (GetSignalConnectionList(SignalName.HoverIn).Count == 0 && HoverInAction.Equals(fbHoverIn))
            Connect(SignalName.HoverIn, HoverInAction);
        if (GetSignalConnectionList(SignalName.HoverOut).Count == 0 && HoverOutAction.Equals(fbHoverOut))
            Connect(SignalName.HoverOut, HoverOutAction);
        if (GetSignalConnectionList(SignalName.Toggled).Count == 0 && ToggledAction.Equals(fbToggled))
            Connect(SignalName.Toggled, ToggledAction);
        if (GetSignalConnectionList(SignalName.Log).Count == 0 && LogAction.Equals(fbLog))
            Connect(SignalName.Log, LogAction);

        // Mouse hover signals (guard duplicates)
        if (!IsConnected("mouse_entered", new Callable(this, nameof(OnMouseEntered))))
            Connect("mouse_entered", new Callable(this, nameof(OnMouseEntered)));
        if (!IsConnected("mouse_exited", new Callable(this, nameof(OnMouseExited))))
            Connect("mouse_exited", new Callable(this, nameof(OnMouseExited)));
    }

    public override void _ExitTree() => DisconnectAllSignalHandlers();

    public override void _Ready()
    {
        FocusMode = FocusModeEnum.All;
        BoundsSource ??= this;
        ThemeTypeVariation = ThemeTypeName;
        _originalScale = Scale;

        if (Engine.IsEditorHint())
            NotifyPropertyListChanged();

        if (!string.IsNullOrEmpty(_text))
            Text = _text; // ensures label exists and fits

        ApplyVisualState();
        ApplyThemeNow();

        // NEW: re-fit when min size changes (e.g. theme/stylebox changes content size)
        if (!IsConnected("minimum_size_changed", new Callable(this, nameof(OnMinimumSizeChanged))))
            Connect("minimum_size_changed", new Callable(this, nameof(OnMinimumSizeChanged)));
    }

    public override void _Process(double delta)
    {
        if (!EnableHoverActions)
        {
            SetProcess(false);
            return;
        }
        PivotOffset = Size / 2.0f;
        var target = Vector2.One * _hoverTargetScale;
        Scale = Scale.Lerp(target, (float)(HoverLerpSpeed * delta));
        if (Scale.DistanceTo(target) < 0.001f)
            SetProcess(false);
    }

    public override void _Notification(int what)
    {
        if (what == NotificationResized)
        {
            FitLabelText();
        }
        else if (what == NotificationThemeChanged)
        {
            CallDeferred(nameof(ApplyThemeNow));
            CallDeferred(nameof(FitLabelText));
        }
        else if (what == NotificationVisibilityChanged)
        {
            if (!IsVisibleInTree())
            {
                _isPointerDown = false;
                ApplyVisualState();
            }
        }
        else if (what == NotificationPredelete)
        {
            DisconnectAllSignalHandlers();
        }
    }

    // ---------- Property List (to re-announce toggle props conditionally) ----------
    public override Array<Dictionary> _GetPropertyList()
    {
        var list = new Array<Dictionary>();

        list.Add(new Dictionary
        {
            { "name", "Interaction & Actions/EnableToggleActions" },
            { "type", (int)Variant.Type.Bool },
            { "usage", (int)PropertyUsageFlags.Default }
        });

        var usage = (int)PropertyUsageFlags.Default;
        var usageHidden = (int)PropertyUsageFlags.Storage; // stored but not editable/visible

        list.Add(new Dictionary
        {
            { "name", "Interaction & Actions/TogglePressed" },
            { "type", (int)Variant.Type.Bool },
            { "usage", EnableToggleActions ? usage : usageHidden }
        });

        list.Add(new Dictionary
        {
            { "name", "Interaction & Actions/ToggledAction" },
            { "type", (int)Variant.Type.Callable },
            { "usage", EnableToggleActions ? usage : usageHidden }
        });

        return list;
    }

    // ---------- Input Handling ----------
    public override void _UnhandledInput(InputEvent @event)
    {
        if (ButtonDisabled)
        {
            OnLog("Warning", $"CustomButton: {Name} Button is disabled. Ignoring unhandled input.");
            return;
        }
        if (string.IsNullOrEmpty(ActionName))
            return;

        // Press
        if (@event.IsActionPressed(ActionName) && ActionAllowed())
        {
            OnPressed();
            GetViewport().SetInputAsHandled();
            return;
        }

        // Release
        if (@event.IsActionReleased(ActionName))
        {
            _isPointerDown = false;
            ApplyVisualState();
            if (ActionAllowed())
            {
                OnReleased();
                GetViewport().SetInputAsHandled();
            }
        }
    }

    public override void _GuiInput(InputEvent @event)
    {
        if (ButtonDisabled)
        {
            OnLog("Warning", $"CustomButton: {Name} Button is disabled. Ignoring input.");
            return;
        }

        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed)
            {
                if (PointInside(mb.GlobalPosition) && !_pressedLock)
                {
                    OnPressed();
                    GetViewport().SetInputAsHandled();
                    return;
                }
            }
            else
            {
                _isPointerDown = false;
                ApplyVisualState();

                if (PointInside(mb.GlobalPosition))
                {
                    OnReleased();
                    GetViewport().SetInputAsHandled();
                }
                return;
            }
        }
        else if (@event is InputEventScreenTouch touch)
        {
            var globalPos = GlobalPosition + touch.Position;
            if (touch.Pressed)
            {
                if (PointInside(globalPos) && !_pressedLock)
                {
                    OnPressed();
                    GetViewport().SetInputAsHandled();
                    return;
                }
            }
            else
            {
                _isPointerDown = false;
                ApplyVisualState();

                if (PointInside(globalPos))
                {
                    OnReleased();
                    GetViewport().SetInputAsHandled();
                }
                return;
            }
        }
    }

    // ---------- Hover and Scaling ----------
    private void OnMouseEntered()
    {
        if (ButtonDisabled) return;
        _hovering = true;
        if (EnableHoverActions)
        {
            EmitSignal(SignalName.HoverIn);
            _hoverTargetScale = HoverScale;
            SetProcess(true);
        }
        ApplyThemeNow(); // hover tint/colors
    }

    private void OnMouseExited()
    {
        if (ButtonDisabled) return;
        _hovering = false;
        if (EnableHoverActions)
        {
            EmitSignal(SignalName.HoverOut);
            _hoverTargetScale = 1.0f;
            SetProcess(true);
        }
        ApplyThemeNow(); // revert hover tint/colors
    }

    private void RunBuiltInHoverIn()
    {
        PivotOffset = Size / 2.0f;
        Scale = Scale.Lerp(Vector2.One * HoverScale, HoverLerpSpeed * (float)GetProcessDeltaTime());
    }

    private void RunBuiltInHoverOut()
    {
        PivotOffset = Size / 2.0f;
        Scale = Scale.Lerp(Vector2.One / HoverScale, HoverLerpSpeed * (float)GetProcessDeltaTime());
    }

    // ---------- Utility ----------
    public void DisplayLabel(string text, Theme theme = null)
    {
        OnLog("Debug", $"CustomButton: {Name} Setting label text to '{text}'...");
        var lbl = GetNodeOrNull<Label>("Label");
        if (lbl == null || !GodotObject.IsInstanceValid(lbl))
        {
            OnLog("Warning", $"CustomButton: {Name} Label is null or invalid. Creating a new label...");
            lbl = new Label
            {
                Name = "Label",
                MouseFilter = MouseFilterEnum.Ignore,
                HorizontalAlignment = HorizontalAlignment.Center,
                VerticalAlignment = VerticalAlignment.Center,
                AutowrapMode = TextServer.AutowrapMode.Word
            };
            lbl.SetAnchorsPreset(LayoutPreset.FullRect);
            AddChild(lbl);
        }

        lbl.Text = text ?? "";
        lbl.Theme = theme ?? Theme;

        // Ensure we have LabelSettings so we can authoritatively set font + size
        EnsureLabelSettings(lbl);

        // Fit next frame after layout/theme is ready
        CallDeferred(nameof(FitLabelText));
    }

    private void OnMinimumSizeChanged()
    {
        CallDeferred(nameof(FitLabelText));
    }

    private void FitLabelText()
    {
        if (_fittingLabel) return;
        _fittingLabel = true;

        var lbl = GetNodeOrNull<Label>("Label");
        if (lbl == null || !GodotObject.IsInstanceValid(lbl))
        {
            _fittingLabel = false;
            return;
        }

        // Available area = control Size minus StyleBox content margins
        var avail = Size;
        var sb = GetThemeStylebox("panel", ThemeTypeVariation);
        if (sb != null)
        {
            avail.X -= (float)(sb.GetContentMargin(Side.Left) + sb.GetContentMargin(Side.Right));
            avail.Y -= (float)(sb.GetContentMargin(Side.Top) + sb.GetContentMargin(Side.Bottom));
        }

        if (avail.X <= 1.0f || avail.Y <= 1.0f)
        {
            CallDeferred(nameof(FitLabelText));
            _fittingLabel = false;
            return;
        }

        // Robust font fallback (works in editor too)
        Font fnt = lbl.GetThemeFont("font");
        if (fnt == null) fnt = lbl.GetThemeDefaultFont();
        if (fnt == null) fnt = ThemeDB.FallbackFont;
        if (fnt == null)
        {
            _fittingLabel = false;
            return;
        }

        var text = lbl.Text;
        if (string.IsNullOrEmpty(text))
        {
            _fittingLabel = false;
            return;
        }

        // Try largest -> smallest; measure WRAPPED MULTILINE text
        int bestSize = -1;
        for (int fs = MaxFontSize; fs >= MinFontSize; fs--)
        {
            // NOTE: this call matches the GDScript logic (word-bound wrapping)
            var sz = fnt.GetMultilineStringSize(
                text,
                HorizontalAlignment.Left,     // alignment for measurement
                avail.X,                      // wrap width
                fs,                           // font size
                -1,                           // no line limit
                TextServer.LineBreakFlag.WordBound
            );

            if (sz.X <= avail.X + 0.1f && sz.Y <= avail.Y + 0.1f)
            {
                bestSize = fs;
                break;
            }
        }

        if (bestSize == -1)
            bestSize = MinFontSize;

        // Apply through LabelSettings (authoritative over theme overrides)
        var ls = EnsureLabelSettings(lbl);
        if (ls.Font != fnt) ls.Font = fnt;
        if (ls.FontSize != bestSize) ls.FontSize = bestSize;

        // Make sure what we measured is how we render
        lbl.AutowrapMode = TextServer.AutowrapMode.Word;

        lbl.QueueRedraw();
        _fittingLabel = false;
    }


    private TextureRect EnsureIcon(bool stretch = true)
    {
        var tr = GetNodeOrNull<TextureRect>("Icon");
        if (tr == null || !GodotObject.IsInstanceValid(tr))
        {
            tr = new TextureRect
            {
                Name = "Icon",
                MouseFilter = MouseFilterEnum.Ignore
            };
            tr.SetAnchorsPreset(LayoutPreset.FullRect);
            AddChild(tr);
        }

        tr.StretchMode = (stretch && IconStretch)
            ? TextureRect.StretchModeEnum.Scale
            : TextureRect.StretchModeEnum.KeepAspectCentered;

        tr.ExpandMode = (stretch && IconStretch)
            ? TextureRect.ExpandModeEnum.IgnoreSize
            : TextureRect.ExpandModeEnum.KeepSize;

        return tr;
    }

    private void ApplyVisualState()
    {
        var tr = EnsureIcon();
        if (tr == null || !GodotObject.IsInstanceValid(tr)) return;

        bool usePressed = EnableToggleActions ? TogglePressed : _isPointerDown;

        if (usePressed && _pressedTexture != null)
        {
            tr.Material = null;
            tr.Texture = _pressedTexture;
        }
        else if (usePressed && _normalTexture != null)
        {
            tr.Texture = _normalTexture;
            tr.Material = GetInvertMaterial();
        }
        else
        {
            tr.Texture = _normalTexture;
            tr.Material = null;
        }

        ApplyThemeNow(); // update tints/fonts/bg for current state
    }

    private string CurrentVisualState()
    {
        if (ButtonDisabled) return "disabled";
        if (EnableToggleActions && TogglePressed) return "pressed";
        if (_isPointerDown) return "pressed";
        if (_hovering) return "hover";
        return "normal";
    }

    private Color GetStateColor(string state, string nKey, string hKey, string pKey, string dKey, Color fallback)
    {
        switch (state)
        {
            case "hover":
                if (HasThemeColor(hKey, ThemeTypeVariation)) return GetThemeColor(hKey, ThemeTypeVariation);
                if (HasThemeColor(nKey, ThemeTypeVariation)) return GetThemeColor(nKey, ThemeTypeVariation);
                return fallback;
            case "pressed":
                if (HasThemeColor(pKey, ThemeTypeVariation)) return GetThemeColor(pKey, ThemeTypeVariation);
                if (HasThemeColor(nKey, ThemeTypeVariation)) return GetThemeColor(nKey, ThemeTypeVariation);
                return fallback;
            case "disabled":
                if (HasThemeColor(dKey, ThemeTypeVariation)) return GetThemeColor(dKey, ThemeTypeVariation);
                if (HasThemeColor(nKey, ThemeTypeVariation)) return GetThemeColor(nKey, ThemeTypeVariation);
                return fallback;
            default:
                if (HasThemeColor(nKey, ThemeTypeVariation)) return GetThemeColor(nKey, ThemeTypeVariation);
                return fallback;
        }
    }

    private void ApplyThemeNow()
    {
        if (_themeApplying) return;
        _themeApplying = true;

        string state = CurrentVisualState();
        var lbl = GetNodeOrNull<Label>("Label");
        var tr = EnsureIcon(false);

        // StyleBox background (optional)
        var sb = GetThemeStylebox(T_BG, ThemeTypeVariation);
        if (sb != null)
        {
            var hasOverride = HasThemeStyleboxOverride("panel");
            var cur = hasOverride ? GetThemeStylebox("panel") : null;
            if (cur != sb) AddThemeStyleboxOverride("panel", sb);
        }
        else
        {
            if (HasThemeStyleboxOverride("panel"))
                RemoveThemeStyleboxOverride("panel");
        }

        // Colors
        var textCol = GetStateColor(state, T_TEXT_NORMAL, T_TEXT_HOVER, T_TEXT_PRESSED, T_TEXT_DISABLED, Colors.White);
        var iconTint = GetStateColor(state, T_ICON_TINT_NORMAL, T_ICON_TINT_HOVER, T_ICON_TINT_PRESSED, T_ICON_TINT_DISABLED, Colors.White);

        if (IsInstanceValid(lbl) && lbl.Modulate != textCol)
            lbl.Modulate = textCol;

        if (IsInstanceValid(tr) && tr.Modulate != iconTint)
            tr.Modulate = iconTint;

        // Fonts (optional)
        if (IsInstanceValid(lbl))
        {
            var fnt = GetThemeFont(T_FONT, ThemeTypeVariation);
            if (fnt != null && lbl.GetThemeFont("font") != fnt)
                lbl.AddThemeFontOverride("font", fnt);

            var fsz = GetThemeFontSize(T_FONT_SIZE, ThemeTypeVariation);
            if (fsz > 0 && lbl.GetThemeFontSize("font_size") != fsz)
                lbl.AddThemeFontSizeOverride("font_size", fsz);

            // Refit after potential font/size change
            CallDeferred(nameof(FitLabelText));
        }

        _themeApplying = false;
    }

    private ShaderMaterial GetInvertMaterial()
    {
        if (_invertMat != null)
            return _invertMat;

        var shader = new Shader();
        shader.Code = @"
shader_type canvas_item;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    COLOR = vec4(1.0 - c.rgb, c.a);
}";
        _invertMat = new ShaderMaterial { Shader = shader };
        return _invertMat;
    }

    // ---------- Private Helpers ----------
    private LabelSettings EnsureLabelSettings(Label lbl)
    {
        var ls = lbl.LabelSettings;
        if (ls == null)
        {
            ls = new LabelSettings();
            lbl.LabelSettings = ls;
        }
        return ls;
    }

    private bool PointInside(Vector2 globalPoint)
    {
        var src = (IsInstanceValid(BoundsSource) && BoundsSource != null) ? BoundsSource : this;
        var rect = src.GetGlobalRect();
        rect = rect.GrowIndividual(HitSlop.X, HitSlop.Y, HitSlop.X, HitSlop.Y);
        return rect.HasPoint(globalPoint);
    }

    private bool ActionAllowed()
    {
        if (RequireFocusForAction) return HasFocus();
        return HasFocus() || PointInside(GetViewport().GetMousePosition());
    }

    private void UnlockPress() => _pressedLock = false;
    private void UnlockRelease() => _releasedLock = false;
    private void UnlockToggle() => _toggledLock = false;
    private void UnlockLog() => _logLock = false;

    private Callable AdoptConnectedCallable(StringName sigName, Callable fallback)
    {
        var conns = GetSignalConnectionList(sigName);
        foreach (Dictionary d in conns)
        {
            var c = (Callable)d["callable"];
            if (c.Target != this)
                return c;
        }
        if (conns.Count > 0)
            return ((Callable)((Dictionary)conns[0])["callable"]);
        return fallback;
    }

    private void DisconnectAllSignalHandlers()
    {
        // --- Outgoing connections (this node's signals -> others) ---
        string[] ownSignals =
        {
            "pressed", "toggled", "released", "log", "hover_in", "hover_out"
        };

        foreach (var sig in ownSignals)
        {
            var list = GetSignalConnectionList(sig); // Array<Dictionary>
            foreach (Godot.Collections.Dictionary conn in list)
            {
                // Godot 4: "callable" is the stable shape
                if (conn.TryGetValue("callable", out var callableVar))
                {
                    var callable = (Callable)callableVar;
                    if (IsConnected(sig, callable))
                        Disconnect(sig, callable);
                }
            }
        }
    }

    // ---------- Default (dispatcher) handlers ----------
    private void OnPressed()
    {
        if (_pressedLock || ButtonDisabled) return;
        _pressedLock = true;

        _isPointerDown = true;
        ApplyVisualState();
        GrabFocus();

        if (EnablePressActions)
            EmitSignal(SignalName.Pressed);

        if (EnableToggleActions)
            TogglePressed = !TogglePressed; // setter emits toggled

        CallDeferred(nameof(UnlockPress));
    }

    private void OnReleased()
    {
        if (_releasedLock || ButtonDisabled) return;
        _releasedLock = true;

        _isPointerDown = false;
        ApplyVisualState();

        if (EnableReleaseActions)
            EmitSignal(SignalName.Released);

        CallDeferred(nameof(UnlockRelease));
    }

    private void OnToggled(bool button_pressed)
    {
        if (_toggledLock || !EnableToggleActions || ButtonDisabled) return;
        _toggledLock = true;
        EmitSignal(SignalName.Toggled, button_pressed);
        CallDeferred(nameof(UnlockToggle));
    }

    private void OnLog(string type, string message)
    {
        if (_logLock) return;
        _logLock = true;
        EmitSignal(SignalName.Log, type, message);
        CallDeferred(nameof(UnlockLog));
    }

    // ---------- Built-in fallback behaviors ----------
    private void RunBuiltInPressed() => RunBuiltInLog("info", $"PressedAction not set; running built-in logic for {Name}.");
    private void RunBuiltInToggled(bool _buttonPressed) => RunBuiltInLog("info", $"ToggledAction not set; running built-in logic for {Name}.");
    private void RunBuiltInReleased() => RunBuiltInLog("info", $"ReleasedAction not set; running built-in logic for {Name}.");

    private void RunBuiltInLog(string type, string message)
    {
        switch (type.ToLowerInvariant())
        {
            case "error": GD.PushError(message); break;
            case "warning": GD.PushWarning(message); break;
            default: GD.Print(message); break;
        }
    }
}
