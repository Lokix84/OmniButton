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

    // ---------- Constants ----------
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

    // ---------- Export Properties ----------

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

    // Input & Hit Detection
    [ExportGroup("Input & Hit Detection")]
    [Export] public string ActionName { get; set; } = "ui_accept";
    [Export] public bool RequireFocusForAction { get; set; } = true;
    [Export] public Control? BoundsSource { get; set; }
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;

    // Interaction & Actions
    [ExportGroup("Interaction & Actions")]
    [Export] public bool EnablePressActions { get; set; } = true;
    [Export] public Callable PressedAction { get; set; }
    [Export] public bool EnableReleaseActions { get; set; } = false;
    [Export] public Callable ReleasedAction { get; set; }
    [Export] public bool EnableToggleActions { get; set; } = false;
    [Export] public Callable ToggledAction { get; set; }

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

    // Hover and Scaling
    [ExportGroup("Hover and Scaling")]
    [Export] public bool EnableHoverActions { get; set; } = false;
    [Export] public Callable HoverInAction { get; set; }
    [Export] public Callable HoverOutAction { get; set; }
    [Export] public float HoverScale { get; set; } = 1.25f;
    [Export] public float HoverLerpSpeed { get; set; } = 25.0f;

    // Text & Font
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

    // Icon
    [ExportGroup("Icon")]
    [Export] public bool IconStretch { get; set; } = true;
    [Export] public bool IconKeepAspect { get; set; } = true;

    // Texture
    [ExportGroup("Texture")]
    private Texture2D? _normalTexture;
    [Export]
    public Texture2D? Texture
    {
        get => _normalTexture;
        set
        {
            _normalTexture = value;
            EnsureIcon();
            ApplyVisualState();
        }
    }

    private Texture2D? _pressedTexture;
    [Export]
    public Texture2D? PressedTexture
    {
        get => _pressedTexture;
        set
        {
            _pressedTexture = value;
            ApplyVisualState();
        }
    }

    // Theme & Visuals
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

    // Logging
    [ExportGroup("Logging")]
    [Export] public Callable LogAction { get; set; }

    // ---------- Private Fields ----------
    private bool _isPointerDown = false;
    private ShaderMaterial? _invertMat;
    private float _hoverTargetScale = 1.0f;
    private Vector2 _originalScale = Vector2.One;
    private bool _hovering = false;
    private bool _themeApplying = false;
    private bool _fittingLabel = false;

    // ---------- Godot Lifecycle Methods ----------
    public override void _EnterTree()
    {
        InitializeCallables();
        ConnectSignals();
        ConnectMouseEvents();
    }

    public override void _ExitTree()
    {
        DisconnectAllSignalHandlers();
    }

    public override void _Ready()
    {
        InitializeComponent();
        ApplyInitialState();
        ConnectMinimumSizeChanged();
    }

    public override void _Process(double delta)
    {
        ProcessHoverScaling(delta);
    }

    public override void _Notification(int what)
    {
        HandleNotifications(what);
    }

    public override Array<Dictionary> _GetPropertyList()
    {
        return BuildPropertyList();
    }

    // ---------- Input Handling ----------
    public override void _UnhandledInput(InputEvent @event)
    {
        HandleUnhandledInput(@event);
    }

    public override void _GuiInput(InputEvent @event)
    {
        HandleGuiInput(@event);
    }

    // ---------- Initialization Methods ----------
    private void InitializeCallables()
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
    }

    private void ConnectSignals()
    {
        // Only connect our fallback if the signal has no connections yet
        if (GetSignalConnectionList(SignalName.Pressed).Count == 0 && PressedAction.Equals(new Callable(this, nameof(RunBuiltInPressed))))
            Connect(SignalName.Pressed, PressedAction);
        if (GetSignalConnectionList(SignalName.Released).Count == 0 && ReleasedAction.Equals(new Callable(this, nameof(RunBuiltInReleased))))
            Connect(SignalName.Released, ReleasedAction);
        if (GetSignalConnectionList(SignalName.HoverIn).Count == 0 && HoverInAction.Equals(new Callable(this, nameof(RunBuiltInHoverIn))))
            Connect(SignalName.HoverIn, HoverInAction);
        if (GetSignalConnectionList(SignalName.HoverOut).Count == 0 && HoverOutAction.Equals(new Callable(this, nameof(RunBuiltInHoverOut))))
            Connect(SignalName.HoverOut, HoverOutAction);
        if (GetSignalConnectionList(SignalName.Toggled).Count == 0 && ToggledAction.Equals(new Callable(this, nameof(RunBuiltInToggled))))
            Connect(SignalName.Toggled, ToggledAction);
        if (GetSignalConnectionList(SignalName.Log).Count == 0 && LogAction.Equals(new Callable(this, nameof(RunBuiltInLog))))
            Connect(SignalName.Log, LogAction);
    }

    private void ConnectMouseEvents()
    {
        // Mouse hover signals (guard duplicates)
        if (!IsConnected("mouse_entered", new Callable(this, nameof(OnMouseEntered))))
            Connect("mouse_entered", new Callable(this, nameof(OnMouseEntered)));
        if (!IsConnected("mouse_exited", new Callable(this, nameof(OnMouseExited))))
            Connect("mouse_exited", new Callable(this, nameof(OnMouseExited)));
    }

    private void InitializeComponent()
    {
        FocusMode = FocusModeEnum.All;
        BoundsSource ??= this;
        ThemeTypeVariation = ThemeTypeName;
        _originalScale = Scale;

        if (Engine.IsEditorHint())
            NotifyPropertyListChanged();

        if (!string.IsNullOrEmpty(_text))
            Text = _text; // ensures label exists and fits
    }

    private void ApplyInitialState()
    {
        ApplyVisualState();
        ApplyThemeNow();
    }

    private void ConnectMinimumSizeChanged()
    {
        // NEW: re-fit when min size changes (e.g. theme/stylebox changes content size)
        if (!IsConnected("minimum_size_changed", new Callable(this, nameof(OnMinimumSizeChanged))))
            Connect("minimum_size_changed", new Callable(this, nameof(OnMinimumSizeChanged)));
    }

    // ---------- Input Processing ----------
    private void HandleUnhandledInput(InputEvent @event)
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

    private void HandleGuiInput(InputEvent @event)
    {
        if (ButtonDisabled)
        {
            OnLog("Warning", $"CustomButton: {Name} Button is disabled. Ignoring input.");
            return;
        }

        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            HandleMouseButton(mb);
        }
        else if (@event is InputEventScreenTouch touch)
        {
            HandleScreenTouch(touch);
        }
    }

    private void HandleMouseButton(InputEventMouseButton mb)
    {
        if (mb.Pressed)
        {
            if (PointInside(mb.GlobalPosition))
            {
                OnPressed();
                GetViewport().SetInputAsHandled();
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
        }
    }

    private void HandleScreenTouch(InputEventScreenTouch touch)
    {
        var globalPos = GlobalPosition + touch.Position;
        if (touch.Pressed)
        {
            if (PointInside(globalPos))
            {
                OnPressed();
                GetViewport().SetInputAsHandled();
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
        }
    }

    // ---------- Event Handlers ----------
    private void OnPressed()
    {
        if (ButtonDisabled) return;

        _isPointerDown = true;
        ApplyVisualState();
        GrabFocus();

        if (EnablePressActions)
            EmitSignal(SignalName.Pressed);

        if (EnableToggleActions)
            TogglePressed = !TogglePressed;
    }

    private void OnReleased()
    {
        if (ButtonDisabled) return;

        _isPointerDown = false;
        ApplyVisualState();

        if (EnableReleaseActions)
            EmitSignal(SignalName.Released);
    }

    private void OnToggled(bool button_pressed)
    {
        if (!EnableToggleActions || ButtonDisabled) return;
        EmitSignal(SignalName.Toggled, button_pressed);
    }

    private void OnLog(string type, string message)
    {
        EmitSignal(SignalName.Log, type, message);
    }

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

    private void OnMinimumSizeChanged()
    {
        if (IsInsideTree() && !IsQueuedForDeletion())
            CallDeferred(nameof(FitLabelText));
    }

    // ---------- Process Methods ----------
    private void ProcessHoverScaling(double delta)
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

    private void HandleNotifications(int what)
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

    // ---------- UI Component Management ----------
    public void DisplayLabel(string text, Theme theme = null)
    {
        OnLog("Debug", $"CustomButton: {Name} Setting label text to '{text}'...");
        var lbl = GetOrCreateLabel();

        lbl.Text = text ?? "";
        lbl.Theme = theme ?? Theme;

        // Ensure we have LabelSettings so we can authoritatively set font + size
        EnsureLabelSettings(lbl);

        // Fit next frame after layout/theme is ready
        if (IsInsideTree() && !IsQueuedForDeletion())
            CallDeferred(nameof(FitLabelText));
    }

    private Label GetOrCreateLabel()
    {
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
        return lbl;
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

    // ---------- Text Fitting ----------
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

        var avail = CalculateAvailableArea();
        if (!IsValidArea(avail))
        {
            _fittingLabel = false;
            return;
        }

        var fnt = GetRobustFont(lbl);
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

        int bestSize = FindBestFontSize(fnt, text, avail);
        ApplyFontSettings(lbl, fnt, bestSize);

        _fittingLabel = false;
    }

    private Vector2 CalculateAvailableArea()
    {
        var avail = Size;
        var sb = GetThemeStylebox("panel", ThemeTypeVariation);
        if (sb != null)
        {
            avail.X -= (float)(sb.GetContentMargin(Side.Left) + sb.GetContentMargin(Side.Right));
            avail.Y -= (float)(sb.GetContentMargin(Side.Top) + sb.GetContentMargin(Side.Bottom));
        }
        return avail;
    }

    private bool IsValidArea(Vector2 avail)
    {
        if ((avail.X <= 1.0f || avail.Y <= 1.0f) && (GodotObject.IsInstanceValid(this)))
        {
            if (IsInsideTree() && !IsQueuedForDeletion())
                CallDeferred(nameof(FitLabelText));
            return false;
        }
        return true;
    }

    private Font GetRobustFont(Label lbl)
    {
        Font fnt = lbl.GetThemeFont("font");
        if (fnt == null) fnt = lbl.GetThemeDefaultFont();
        if (fnt == null) fnt = ThemeDB.FallbackFont;
        return fnt;
    }

    private int FindBestFontSize(Font fnt, string text, Vector2 avail)
    {
        int bestSize = -1;
        for (int fs = MaxFontSize; fs >= MinFontSize; fs--)
        {
            var sz = fnt.GetMultilineStringSize(
                text,
                HorizontalAlignment.Left,
                avail.X,
                fs,
                -1,
                TextServer.LineBreakFlag.WordBound
            );

            if (sz.X <= avail.X + 0.1f && sz.Y <= avail.Y + 0.1f)
            {
                bestSize = fs;
                break;
            }
        }

        return bestSize == -1 ? MinFontSize : bestSize;
    }

    private void ApplyFontSettings(Label lbl, Font fnt, int bestSize)
    {
        var ls = EnsureLabelSettings(lbl);
        if (ls.Font != fnt) ls.Font = fnt;
        if (ls.FontSize != bestSize) ls.FontSize = bestSize;

        lbl.AutowrapMode = TextServer.AutowrapMode.Word;
        lbl.QueueRedraw();
    }

    // ---------- Visual State Management ----------
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

    // ---------- Theme Management ----------
    private void ApplyThemeNow()
    {
        if (_themeApplying) return;
        _themeApplying = true;

        string state = CurrentVisualState();
        var lbl = GetNodeOrNull<Label>("Label");
        var tr = EnsureIcon(false);

        ApplyStyleBox();
        ApplyStateColors(state, lbl, tr);
        ApplyFonts(lbl);

        _themeApplying = false;
    }

    private void ApplyStyleBox()
    {
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
    }

    private void ApplyStateColors(string state, Label lbl, TextureRect tr)
    {
        var textCol = GetStateColor(state, T_TEXT_NORMAL, T_TEXT_HOVER, T_TEXT_PRESSED, T_TEXT_DISABLED, Colors.White);
        var iconTint = GetStateColor(state, T_ICON_TINT_NORMAL, T_ICON_TINT_HOVER, T_ICON_TINT_PRESSED, T_ICON_TINT_DISABLED, Colors.White);

        if (IsInstanceValid(lbl) && lbl.Modulate != textCol)
            lbl.Modulate = textCol;

        if (IsInstanceValid(tr) && tr.Modulate != iconTint)
            tr.Modulate = iconTint;
    }

    private void ApplyFonts(Label lbl)
    {
        if (!IsInstanceValid(lbl)) return;

        var fnt = GetThemeFont(T_FONT, ThemeTypeVariation);
        if (fnt != null && lbl.GetThemeFont("font") != fnt)
            lbl.AddThemeFontOverride("font", fnt);

        var fsz = GetThemeFontSize(T_FONT_SIZE, ThemeTypeVariation);
        if (fsz > 0 && lbl.GetThemeFontSize("font_size") != fsz)
            lbl.AddThemeFontSizeOverride("font_size", fsz);

        // Refit after potential font/size change
        if (IsInsideTree() && !IsQueuedForDeletion())
            CallDeferred(nameof(FitLabelText));
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

    // ---------- Material Management ----------
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

    // ---------- Utility Methods ----------
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

    private Array<Dictionary> BuildPropertyList()
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

    // ---------- Signal Management ----------
    private void DisconnectAllSignalHandlers()
    {
        string[] ownSignals =
        {
            "pressed", "toggled", "released", "log", "hover_in", "hover_out"
        };

        foreach (var sig in ownSignals)
        {
            var list = GetSignalConnectionList(sig);
            foreach (Godot.Collections.Dictionary conn in list)
            {
                if (conn.TryGetValue("callable", out var callableVar))
                {
                    var callable = (Callable)callableVar;
                    if (IsConnected(sig, callable))
                        Disconnect(sig, callable);
                }
            }
        }
    }

    // ---------- Built-in Fallback Behaviors ----------
    private void RunBuiltInPressed() => RunBuiltInLog("info", $"PressedAction not set; running built-in logic for {Name}.");
    private void RunBuiltInToggled(bool _buttonPressed) => RunBuiltInLog("info", $"ToggledAction not set; running built-in logic for {Name}.");
    private void RunBuiltInReleased() => RunBuiltInLog("info", $"ReleasedAction not set; running built-in logic for {Name}.");

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
