using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;

/// <summary>
/// Advanced button control with theming, scaling, selection states, and extensive customization options
/// </summary>
[Tool]
public partial class OmniButton : Control
{
    #region Signals
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool button_pressed);
    [Signal] public delegate void ReleasedEventHandler();
    [Signal] public delegate void HoverInEventHandler();
    [Signal] public delegate void HoverOutEventHandler();
    [Signal] public delegate void LogEventHandler(string type, string message);
    #endregion

    #region Constants & Static Data
    private const string T_TEXT_NORMAL = "text_color";
    private const string T_TEXT_HOVER = "text_color_hover";
    private const string T_TEXT_PRESSED = "text_color_pressed";
    private const string T_TEXT_DISABLED = "text_color_disabled";
    private const string T_ICON_TINT_NORMAL = "icon_tint";
    private const string T_ICON_TINT_HOVER = "icon_tint_hover";
    private const string T_ICON_TINT_PRESSED = "icon_tint_pressed";
    private const string T_ICON_TINT_DISABLED = "icon_tint_disabled";
    private const string T_BG = "panel";
    private const string T_FONT = "font";
    private const string T_FONT_SIZE = "font_size";

    private static readonly Godot.Collections.Dictionary<string, Color> PresetSelectedColors = new()
    {
        ["red"] = new(1.0f, 0.3f, 0.3f, 0.7f),
        ["green"] = new(0.3f, 1.0f, 0.3f, 0.7f),
        ["blue"] = new(0.3f, 0.3f, 1.0f, 0.7f),
        ["yellow"] = new(1.0f, 1.0f, 0.3f, 0.7f),
        ["purple"] = new(0.8f, 0.3f, 1.0f, 0.7f),
        ["orange"] = new(1.0f, 0.6f, 0.2f, 0.7f),
        ["cyan"] = new(0.3f, 1.0f, 1.0f, 0.7f)
    };

    private static readonly Godot.Collections.Dictionary<string, Color> PresetUnselectedColors = new Godot.Collections.Dictionary<string, Color>
    {
        ["dark"] = new(0.0f, 0.0f, 0.0f, 0.4f),
        ["gray"] = new(0.3f, 0.3f, 0.3f, 0.3f),
        ["red"] = new(0.3f, 0.0f, 0.0f, 0.3f),
        ["blue"] = new(0.0f, 0.0f, 0.3f, 0.3f)
    };

    private static readonly string[] OwnSignals = { "pressed", "toggled", "released", "log", "hover_in", "hover_out" };

    private static ShaderMaterial? _sharedInvertMat;
    #endregion

    #region Exported Properties
    // General
    [ExportGroup("General Settings")]
    private bool _buttonDisabled = false;
    [Export] public bool ButtonDisabled { get => _buttonDisabled; set => SetButtonDisabled(value); }

    // Input
    [ExportGroup("Input & Hit Detection")]
    [Export] public string ActionName { get; set; } = "ui_accept";
    [Export] public bool RequireFocusForAction { get; set; } = true;
    [Export] public Control? BoundsSource { get; set; }
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;

    // Actions
    [ExportGroup("Interaction & Actions")]
    [Export] public bool EnablePressActions { get; set; } = true;
    [Export] public Callable PressedAction { get; set; }
    [Export] public bool InvertOnPressIfNoPressedTexture { get; set; } = true;
    [Export] public bool EnableReleaseActions { get; set; } = false;
    [Export] public Callable ReleasedAction { get; set; }

    private bool _enableToggleActions;
    [Export] public bool EnableToggleActions { get => _enableToggleActions; set => SetToggleEnabled(value); }
    [Export] public Callable ToggledAction { get; set; }

    private bool _togglePressed = false;
    [Export] public bool TogglePressed { get => _togglePressed; set => SetTogglePressed(value); }

    // Selection States
    private bool _selected = false;
    [Export] public bool Selected { get => _selected; set => SetSelectionState(value, _unSelected); }
    [Export] public Color SelectedColor = new(1.0f, 1.0f, 1.0f, 0.3f);

    private bool _unSelected = false;
    [Export] public bool UnSelected { get => _unSelected; set => SetSelectionState(_selected, value); }
    [Export] public Color UnSelectedColor = new(0.0f, 0.0f, 0.0f, 0.2f);

    // Hover
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

    private HorizontalAlignment _horizontalAlignment;
    [Export] public HorizontalAlignment HorizontalAlignment { get => _horizontalAlignment; set => SetAlignment(value, _verticalAlignment); }

    private VerticalAlignment _verticalAlignment;
    [Export] public VerticalAlignment VerticalAlignment { get => _verticalAlignment; set => SetAlignment(_horizontalAlignment, value); }

    private TextServer.AutowrapMode _autowrapMode;
    [Export] public TextServer.AutowrapMode AutowrapMode { get => _autowrapMode; set => SetAutowrapMode(value); }

    private bool _invertTextIfNoIcon;
    [Export] public bool InvertTextIfNoIcon { get => _invertTextIfNoIcon; set => SetInvertTextIfNoIcon(value); }

    private string _text = "";
    [Export] public string Text { get => _text; set => SetText(value); }

    // Icon & Texture
    [ExportGroup("Icon")]
    [Export] public bool IconStretch { get; set; } = true;
    [Export] public bool IconKeepAspect { get; set; } = true;

    [ExportGroup("Texture")]
    private Texture2D? _normalTexture;
    [Export] public Texture2D? Texture { get => _normalTexture; set => SetTexture(value, true); }

    private Texture2D? _pressedTexture;
    [Export] public Texture2D? PressedTexture { get => _pressedTexture; set => SetTexture(value, false); }

    // Theme
    [ExportGroup("Theme & Visuals")]
    private string _themeTypeName = "OmniButton";
    [Export] public string ThemeTypeName { get => _themeTypeName; set => SetThemeTypeName(value); }
    [Export] public bool InheritThemeToChildren { get; set; } = true;

    [ExportSubgroup("Base Node Theme Variations")]
    [Export] public string BaseNormalThemeVariation { get; set; } = "normal";
    [Export] public string BaseHoverThemeVariation { get; set; } = "hover";
    [Export] public string BasePressedThemeVariation { get; set; } = "pressed";
    [Export] public string BaseToggledThemeVariation { get; set; } = "toggled";

    [ExportSubgroup("Label Theme Variations")]
    [Export] public string LabelNormalThemeVariation { get; set; } = "";
    [Export] public string LabelHoverThemeVariation { get; set; } = "";
    [Export] public string LabelPressedThemeVariation { get; set; } = "";
    [Export] public string LabelToggledThemeVariation { get; set; } = "";

    [ExportSubgroup("Icon Theme Variations")]
    [Export] public string IconNormalThemeVariation { get; set; } = "";
    [Export] public string IconHoverThemeVariation { get; set; } = "";
    [Export] public string IconPressedThemeVariation { get; set; } = "";
    [Export] public string IconToggledThemeVariation { get; set; } = "";

    // Logging
    [ExportGroup("Logging")]
    [Export] public Callable LogAction { get; set; }
    #endregion

    #region Private State & Caching
    private bool _isPointerDown = false;
    private float _hoverTargetScale = 1.0f;
    private Vector2 _originalScale = Vector2.One;
    private bool _hovering = false;
    private bool _themeApplying = false;
    private bool _fittingLabel = false;

    // Cached components
    private Label? _cachedLabel;
    private TextureRect? _cachedIcon;
    private ColorRect? _cachedOverlay;

    // Cached state for optimization
    private string? _lastVisualState;
    private Color _lastTextColor = Colors.Transparent;
    private Color _lastIconTint = Colors.Transparent;
    #endregion

    #region Godot Lifecycle
    public override void _EnterTree() => Initialize();
    public override void _ExitTree() => Cleanup();
    public override void _Ready() => Setup();
    public override void _Process(double delta) => ProcessHoverScaling(delta);
    public override void _Notification(int what) => HandleNotifications(what);
    public override Array<Dictionary> _GetPropertyList() => BuildPropertyList();
    public override void _UnhandledInput(InputEvent @event) => HandleUnhandledInput(@event);
    public override void _GuiInput(InputEvent @event) => HandleGuiInput(@event);
    #endregion

    #region Initialization & Cleanup
    private void Initialize()
    {
        InitializeCallables();
        if (!Engine.IsEditorHint()) ConnectSignals();
        ConnectMouseEvents();
    }

    private void Setup()
    {
        FocusMode = FocusModeEnum.All;
        BoundsSource ??= this;
        ThemeTypeVariation = ThemeTypeName;
        _originalScale = Scale;

        if (Engine.IsEditorHint()) NotifyPropertyListChanged();
        if (!string.IsNullOrEmpty(_text)) SetText(_text);

        ApplyVisualState();
        ApplyThemeNow();
        UpdateOverlay();

        ConnectIfNotConnected("minimum_size_changed", new Callable(this, nameof(OnMinimumSizeChanged)));
    }

    private void Cleanup()
    {
        DisconnectAllSignalHandlers();
        _cachedLabel = null;
        _cachedIcon = null;
        _cachedOverlay = null;
    }

    private void InitializeCallables()
    {
        var fallbacks = new (string name, Callable callable)[]
        {
            ("Pressed", new Callable(this, nameof(RunBuiltInPressed))),
            ("Released", new Callable(this, nameof(RunBuiltInReleased))),
            ("HoverIn", new Callable(this, nameof(RunBuiltInHoverIn))),
            ("HoverOut", new Callable(this, nameof(RunBuiltInHoverOut))),
            ("Toggled", new Callable(this, nameof(RunBuiltInToggled))),
            ("Log", new Callable(this, nameof(RunBuiltInLog)))
        };

        foreach (var (name, callable) in fallbacks)
        {
            SetCallableProperty(name, AdoptConnectedCallable(name, callable));
        }
    }

    private void SetCallableProperty(string name, Callable callable)
    {
        switch (name)
        {
            case "Pressed": PressedAction = callable; break;
            case "Released": ReleasedAction = callable; break;
            case "HoverIn": HoverInAction = callable; break;
            case "HoverOut": HoverOutAction = callable; break;
            case "Toggled": ToggledAction = callable; break;
            case "Log": LogAction = callable; break;
        }
    }

    private void ConnectSignals()
    {
        var signals = new (string name, Callable callable)[]
        {
            ("Pressed", PressedAction),
            ("Released", ReleasedAction),
            ("HoverIn", HoverInAction),
            ("HoverOut", HoverOutAction),
            ("Toggled", ToggledAction),
            ("Log", LogAction)
        };

        foreach (var (name, callable) in signals)
        {
            if (GetSignalConnectionList(name).Count == 0)
                Connect(name, callable);
        }
    }

    private void ConnectMouseEvents()
    {
        ConnectIfNotConnected("mouse_entered", new Callable(this, nameof(OnMouseEntered)));
        ConnectIfNotConnected("mouse_exited", new Callable(this, nameof(OnMouseExited)));
    }

    private void ConnectIfNotConnected(string signal, Callable callable)
    {
        if (!IsConnected(signal, callable))
            Connect(signal, callable);
    }
    #endregion

    #region Property Setters (Optimized)
    private void SetButtonDisabled(bool value)
    {
        if (_buttonDisabled == value) return;
        _buttonDisabled = value;
        if (value)
        {
            _isPointerDown = false;
            _hovering = false;
            InvalidateVisualState();
        }
    }

    private void SetToggleEnabled(bool value)
    {
        if (_enableToggleActions == value) return;
        _enableToggleActions = value;
        if (Engine.IsEditorHint()) NotifyPropertyListChanged();
    }

    private void SetTogglePressed(bool value)
    {
        if (_togglePressed == value) return;
        _togglePressed = value;
        InvalidateVisualState();
        if (EnableToggleActions && !Engine.IsEditorHint())
            EmitSignal(SignalName.Toggled, _togglePressed);
    }

    private void SetAlignment(HorizontalAlignment hAlign, VerticalAlignment vAlign)
    {
        bool changed = _horizontalAlignment != hAlign || _verticalAlignment != vAlign;
        if (!changed) return;

        _horizontalAlignment = hAlign;
        _verticalAlignment = vAlign;

        if (_cachedLabel != null && IsInstanceValid(_cachedLabel))
        {
            _cachedLabel.HorizontalAlignment = hAlign;
            _cachedLabel.VerticalAlignment = vAlign;
        }
        if (Engine.IsEditorHint()) NotifyPropertyListChanged();
    }

    private void SetAutowrapMode(TextServer.AutowrapMode mode)
    {
        if (_autowrapMode == mode) return;
        _autowrapMode = mode;

        if (_cachedLabel != null && IsInstanceValid(_cachedLabel))
        {
            _cachedLabel.AutowrapMode = mode;
            SafeCallDeferred(nameof(FitLabelText));
        }
        if (Engine.IsEditorHint()) NotifyPropertyListChanged();
    }

    private void SetInvertTextIfNoIcon(bool value)
    {
        if (_invertTextIfNoIcon == value) return;
        _invertTextIfNoIcon = value;
        InvalidateVisualState();
        if (Engine.IsEditorHint()) NotifyPropertyListChanged();
    }

    private void SetText(string? value)
    {
        value ??= "";
        if (value == _text) return;
        _text = value;

        var lbl = GetOrCreateLabel();
        lbl.Text = value;
        SafeCallDeferred(nameof(FitLabelText));
    }

    private void SetTexture(Texture2D? texture, bool isNormal)
    {
        if (isNormal)
        {
            if (_normalTexture == texture) return;
            _normalTexture = texture;
            EnsureIcon();
        }
        else
        {
            if (_pressedTexture == texture) return;
            _pressedTexture = texture;
        }
        InvalidateVisualState();
    }

    private void SetThemeTypeName(string value)
    {
        if (_themeTypeName == value) return;
        _themeTypeName = value;
        ThemeTypeVariation = value;
        SafeCallDeferred(nameof(ApplyThemeNow));
    }

    public void SetSelectionState(bool selected, bool unselected = false)
    {
        if (selected && unselected) unselected = false;

        bool changed = _selected != selected || _unSelected != unselected;
        if (!changed) return;

        _selected = selected;
        _unSelected = unselected;
        UpdateOverlay();
    }

    private void InvalidateVisualState()
    {
        _lastVisualState = null;
        ApplyVisualState();
        ApplyThemeNow();
    }
    #endregion

    #region Input Handling (Optimized)
    private void HandleUnhandledInput(InputEvent @event)
    {
        if (ButtonDisabled || string.IsNullOrEmpty(ActionName)) return;

        if (@event.IsActionPressed(ActionName) && ActionAllowed())
        {
            OnPressed();
            GetViewport().SetInputAsHandled();
        }
        else if (@event.IsActionReleased(ActionName))
        {
            _isPointerDown = false;
            InvalidateVisualState();
            if (ActionAllowed())
            {
                OnReleased();
                GetViewport().SetInputAsHandled();
            }
        }
    }

    private void HandleGuiInput(InputEvent @event)
    {
        if (ButtonDisabled) return;

        switch (@event)
        {
            case InputEventMouseButton { ButtonIndex: MouseButton.Left } mb:
                HandleMouseButton(mb);
                break;
            case InputEventScreenTouch touch:
                HandleScreenTouch(touch);
                break;
        }
    }

    private void HandleMouseButton(InputEventMouseButton mb)
    {
        bool inside = PointInside(mb.GlobalPosition);

        if (mb.Pressed && inside)
        {
            OnPressed();
            GetViewport().SetInputAsHandled();
        }
        else if (!mb.Pressed)
        {
            _isPointerDown = false;
            InvalidateVisualState();
            if (inside)
            {
                OnReleased();
                GetViewport().SetInputAsHandled();
            }
        }
    }

    private void HandleScreenTouch(InputEventScreenTouch touch)
    {
        var globalPos = GlobalPosition + touch.Position;
        bool inside = PointInside(globalPos);

        if (touch.Pressed && inside)
        {
            OnPressed();
            GetViewport().SetInputAsHandled();
        }
        else if (!touch.Pressed)
        {
            _isPointerDown = false;
            InvalidateVisualState();
            if (inside)
            {
                OnReleased();
                GetViewport().SetInputAsHandled();
            }
        }
    }
    #endregion

    #region Event Handlers
    private void OnPressed()
    {
        if (ButtonDisabled) return;

        _isPointerDown = true;
        InvalidateVisualState();
        GrabFocus();

        if (EnablePressActions) EmitSignal(SignalName.Pressed);
        if (EnableToggleActions) TogglePressed = !TogglePressed;
    }

    private void OnReleased()
    {
        if (ButtonDisabled) return;
        if (EnableReleaseActions) EmitSignal(SignalName.Released);
    }

    private void OnLog(string type, string message) => EmitSignal(SignalName.Log, type, message);

    private void OnMouseEntered()
    {
        if (ButtonDisabled) return;
        _hovering = true;

        if (EnableHoverActions)
        {
            EmitSignal(SignalName.HoverIn);
            PivotOffset = Size / 2.0f;
            _hoverTargetScale = HoverTargetForViewport();
            SetProcess(true);
        }
        InvalidateVisualState();
    }

    private void OnMouseExited()
    {
        if (ButtonDisabled) return;
        _hovering = false;

        if (EnableHoverActions)
        {
            EmitSignal(SignalName.HoverOut);
            PivotOffset = Size / 2.0f;
            _hoverTargetScale = 1.0f;
            SetProcess(true);
        }
        InvalidateVisualState();
    }

    private void OnMinimumSizeChanged() => SafeCallDeferred(nameof(FitLabelText));
    #endregion

    #region Processing & Notifications
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
        switch (what)
        {
            case (int)NotificationResized:
                FitLabelText();
                if (_hovering && EnableHoverActions)
                {
                    PivotOffset = Size / 2.0f;
                    _hoverTargetScale = HoverTargetForViewport();
                    SetProcess(true);
                }
                break;

            case (int)NotificationThemeChanged:
                if (InheritThemeToChildren && Theme != null)
                    ApplyThemeToChildren();

                _lastVisualState = null; // Force theme refresh
                SafeCallDeferred(nameof(ApplyThemeNow));
                SafeCallDeferred(nameof(FitLabelText));

                if (_hovering && EnableHoverActions)
                {
                    _hoverTargetScale = HoverTargetForViewport();
                    SetProcess(true);
                }
                break;

            case (int)NotificationVisibilityChanged:
                if (!IsVisibleInTree())
                {
                    _isPointerDown = false;
                    _hovering = false;
                    InvalidateVisualState();
                }
                break;

            case (int)NotificationPredelete:
                Cleanup();
                break;
        }
    }

    private void ApplyThemeToChildren()
    {
        if (_cachedLabel != null && IsInstanceValid(_cachedLabel))
            _cachedLabel.Theme = Theme;
        if (_cachedIcon != null && IsInstanceValid(_cachedIcon))
            _cachedIcon.Theme = Theme;
    }
    #endregion

    #region UI Components (Cached)
    private Label GetOrCreateLabel()
    {
        if (_cachedLabel == null || !IsInstanceValid(_cachedLabel))
        {
            _cachedLabel = GetNodeOrNull<Label>("Label");
            if (_cachedLabel == null)
            {
                _cachedLabel = CreateChildNode<Label>("Label");
            }
        }
        ConfigureLabel(_cachedLabel);
        return _cachedLabel;
    }

    private TextureRect EnsureIcon()
    {
        if (_cachedIcon == null || !IsInstanceValid(_cachedIcon))
        {
            _cachedIcon = GetNodeOrNull<TextureRect>("Icon");
            if (_cachedIcon == null)
            {
                _cachedIcon = CreateChildNode<TextureRect>("Icon");
            }
        }
        ConfigureIcon(_cachedIcon);
        return _cachedIcon;
    }

    private T CreateChildNode<T>(string name) where T : Control, new()
    {
        var node = new T
        {
            Name = name,
            MouseFilter = MouseFilterEnum.Ignore
        };
        node.SetAnchorsPreset(LayoutPreset.FullRect);
        AddChild(node);
        return node;
    }

    private void ConfigureLabel(Label lbl)
    {
        lbl.HorizontalAlignment = HorizontalAlignment;
        lbl.VerticalAlignment = VerticalAlignment;
        lbl.AutowrapMode = AutowrapMode;
        if (InheritThemeToChildren && Theme != null)
            lbl.Theme = Theme;
    }

    private void ConfigureIcon(TextureRect tr)
    {
        tr.StretchMode = IconStretch ? TextureRect.StretchModeEnum.Scale : TextureRect.StretchModeEnum.KeepAspectCentered;
        tr.ExpandMode = IconStretch ? TextureRect.ExpandModeEnum.IgnoreSize : TextureRect.ExpandModeEnum.KeepSize;

        if (InheritThemeToChildren && Theme != null)
            tr.Theme = Theme;
    }
    #endregion

    #region Text Fitting (Optimized)
    private void FitLabelText()
    {
        if (_fittingLabel || _cachedLabel == null || !IsInstanceValid(_cachedLabel) || string.IsNullOrEmpty(_cachedLabel.Text))
            return;

        _fittingLabel = true;
        try
        {
            var avail = CalculateAvailableArea();
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                SafeCallDeferred(nameof(FitLabelText));
                return;
            }

            var fnt = GetRobustFont(_cachedLabel);
            if (fnt == null) return;

            int bestSize = FindBestFontSize(fnt, _cachedLabel.Text, avail);
            ApplyFontSettings(_cachedLabel, fnt, bestSize);
        }
        finally
        {
            _fittingLabel = false;
        }
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

    private static Font? GetRobustFont(Label lbl) =>
        lbl.GetThemeFont("font") ?? lbl.GetThemeDefaultFont() ?? ThemeDB.FallbackFont;

    private int FindBestFontSize(Font fnt, string text, Vector2 avail)
    {
        for (int fs = MaxFontSize; fs >= MinFontSize; fs--)
        {
            var sz = fnt.GetMultilineStringSize(text, HorizontalAlignment.Left, avail.X, fs, -1, TextServer.LineBreakFlag.WordBound);
            if (sz.X <= avail.X + 0.1f && sz.Y <= avail.Y + 0.1f)
                return fs;
        }
        return MinFontSize;
    }

    private void ApplyFontSettings(Label lbl, Font fnt, int bestSize)
    {
        var ls = lbl.LabelSettings ??= new LabelSettings();

        bool changed = false;
        if (ls.Font != fnt) { ls.Font = fnt; changed = true; }
        if (ls.FontSize != bestSize) { ls.FontSize = bestSize; changed = true; }

        if (changed)
        {
            ConfigureLabel(lbl);
            lbl.QueueRedraw();
        }
    }
    #endregion

    #region Visual State & Theme Management (Optimized)
    private void ApplyVisualState()
    {
        string currentState = CurrentVisualState();
        if (currentState == _lastVisualState) return; // Skip if state hasn't changed

        _lastVisualState = currentState;

        var tr = EnsureIcon();
        bool usePressed = EnableToggleActions ? TogglePressed : _isPointerDown;
        var desiredTex = (usePressed && _pressedTexture != null) ? _pressedTexture : _normalTexture;
        Material? desiredMat = null;

        if (usePressed && _pressedTexture == null && _normalTexture != null && InvertOnPressIfNoPressedTexture)
            desiredMat = GetInvertMaterial();

        if (tr.Texture != desiredTex) tr.Texture = desiredTex;
        if (tr.Material != desiredMat) tr.Material = desiredMat;

        ApplyTextInvertIfNeeded(usePressed, desiredTex);
        ApplyThemeNow();
    }

    private void ApplyTextInvertIfNeeded(bool usePressed, Texture2D? iconTexture)
    {
        if (!InvertTextIfNoIcon || _cachedLabel == null || !IsInstanceValid(_cachedLabel)) return;

        var desiredMat = (iconTexture == null && usePressed) ? GetInvertMaterial() : null;
        if (_cachedLabel.Material != desiredMat)
            _cachedLabel.Material = desiredMat;
    }

    private string CurrentVisualState()
    {
        if (ButtonDisabled) return "disabled";
        if (EnableToggleActions && TogglePressed) return "toggled";
        if (_isPointerDown) return "pressed";
        if (_hovering) return "hover";
        return "normal";
    }

    private void ApplyThemeNow()
    {
        if (_themeApplying) return;
        _themeApplying = true;

        try
        {
            string state = CurrentVisualState();

            var baseVariation = GetThemeVariation(state, "base");
            if (ThemeTypeVariation != baseVariation)
                ThemeTypeVariation = baseVariation;

            ApplyChildThemeVariations(state);
            ApplyStyleBox();
            ApplyStateColors(state);
            ApplyFonts();
        }
        finally
        {
            _themeApplying = false;
        }
    }

    private void ApplyChildThemeVariations(string state)
    {
        if (_cachedLabel != null && IsInstanceValid(_cachedLabel))
        {
            var labelVariation = GetThemeVariation(state, "label");
            _cachedLabel.ThemeTypeVariation = string.IsNullOrEmpty(labelVariation) ? "" : labelVariation;
        }

        if (_cachedIcon != null && IsInstanceValid(_cachedIcon))
        {
            var iconVariation = GetThemeVariation(state, "icon");
            _cachedIcon.ThemeTypeVariation = iconVariation;
            if (InheritThemeToChildren && Theme != null)
                _cachedIcon.Theme = Theme;
        }
    }

    private void ApplyStyleBox()
    {
        var sb = GetThemeStylebox(T_BG, ThemeTypeVariation);
        if (sb != null)
        {
            var cur = HasThemeStyleboxOverride("panel") ? GetThemeStylebox("panel") : null;
            if (cur != sb) AddThemeStyleboxOverride("panel", sb);
        }
        else if (HasThemeStyleboxOverride("panel"))
        {
            RemoveThemeStyleboxOverride("panel");
        }
    }

    private void ApplyStateColors(string state)
    {
        var textCol = GetStateColor(state, T_TEXT_NORMAL, T_TEXT_HOVER, T_TEXT_PRESSED, T_TEXT_DISABLED, Colors.White);
        var iconTint = GetStateColor(state, T_ICON_TINT_NORMAL, T_ICON_TINT_HOVER, T_ICON_TINT_PRESSED, T_ICON_TINT_DISABLED, Colors.White);

        if (Modulate != Colors.White) Modulate = Colors.White;

        // Only update colors if they've changed
        if (_cachedLabel != null && IsInstanceValid(_cachedLabel))
        {
            var desiredTextColor = (_cachedLabel.Material == null) ? textCol : Colors.White;
            if (_lastTextColor != desiredTextColor)
            {
                _cachedLabel.Modulate = desiredTextColor;
                _lastTextColor = desiredTextColor;
            }
        }

        if (_cachedIcon != null && IsInstanceValid(_cachedIcon) && _lastIconTint != iconTint)
        {
            _cachedIcon.Modulate = iconTint;
            _lastIconTint = iconTint;
        }
    }

    private void ApplyFonts()
    {
        if (_cachedLabel == null || !IsInstanceValid(_cachedLabel)) return;

        var fnt = GetThemeFont(T_FONT, ThemeTypeVariation);
        if (fnt != null && _cachedLabel.GetThemeFont("font") != fnt)
            _cachedLabel.AddThemeFontOverride("font", fnt);

        var fsz = GetThemeFontSize(T_FONT_SIZE, ThemeTypeVariation);
        if (fsz > 0 && _cachedLabel.GetThemeFontSize("font_size") != fsz)
            _cachedLabel.AddThemeFontSizeOverride("font_size", fsz);

        SafeCallDeferred(nameof(FitLabelText));
    }

    private Color GetStateColor(string state, string nKey, string hKey, string pKey, string dKey, Color fallback)
    {
        var key = state switch
        {
            "hover" => HasThemeColor(hKey, ThemeTypeVariation) ? hKey : nKey,
            "pressed" => HasThemeColor(pKey, ThemeTypeVariation) ? pKey : nKey,
            "disabled" => HasThemeColor(dKey, ThemeTypeVariation) ? dKey : nKey,
            _ => nKey
        };
        return HasThemeColor(key, ThemeTypeVariation) ? GetThemeColor(key, ThemeTypeVariation) : fallback;
    }

    private string GetThemeVariation(string state, string type)
    {
        var variation = (type, state) switch
        {
            ("base", "hover") => BaseHoverThemeVariation,
            ("base", "pressed") => BasePressedThemeVariation,
            ("base", "toggled") => BaseToggledThemeVariation,
            ("base", _) => BaseNormalThemeVariation,
            ("label", "hover") => LabelHoverThemeVariation,
            ("label", "pressed") => LabelPressedThemeVariation,
            ("label", "toggled") => LabelToggledThemeVariation,
            ("label", _) => LabelNormalThemeVariation,
            ("icon", "hover") => IconHoverThemeVariation,
            ("icon", "pressed") => IconPressedThemeVariation,
            ("icon", "toggled") => IconToggledThemeVariation,
            ("icon", _) => IconNormalThemeVariation,
            _ => ""
        };

        return string.IsNullOrEmpty(variation)
            ? (type == "base" ? ThemeTypeName : GetThemeVariation(state, "base"))
            : variation;
    }
    #endregion

    #region Material & Effects (Optimized)
    private static ShaderMaterial GetInvertMaterial()
    {
        return _sharedInvertMat ??= new ShaderMaterial
        {
            Shader = new Shader
            {
                Code = @"
shader_type canvas_item;
void fragment() {
    vec4 c = texture(TEXTURE, UV);
    COLOR = vec4(1.0 - c.rgb, c.a);
}"
            }
        };
    }

    private void UpdateOverlay()
    {
        bool needsOverlay = _selected || _unSelected;

        if (needsOverlay)
        {
            if (_cachedOverlay == null || !IsInstanceValid(_cachedOverlay))
            {
                _cachedOverlay = GetNodeOrNull<ColorRect>("Overlay");
                if (_cachedOverlay == null)
                {
                    _cachedOverlay = CreateChildNode<ColorRect>("Overlay");
                    MoveChild(_cachedOverlay, GetChildCount() - 1);
                }
            }

            Color overlayColor = _selected ? SelectedColor : UnSelectedColor;
            if (_cachedOverlay.Color != overlayColor)
                _cachedOverlay.Color = overlayColor;
        }
        else if (_cachedOverlay != null && IsInstanceValid(_cachedOverlay))
        {
            _cachedOverlay.QueueFree();
            _cachedOverlay = null;
        }
    }
    #endregion

    #region Hover Calculations (Optimized)
    private float HoverTargetForViewport()
    {
        var desired = HoverScale;
        if (desired <= Scale.X) return desired;

        var rect = GetGlobalRect();
        if (rect.Size.X <= 0.0f || rect.Size.Y <= 0.0f) return 1.0f;

        var vp = GetViewportRect().Size;
        var center = rect.Position + rect.Size * 0.5f;
        var sc = Math.Max(Scale.X, 0.0001f);

        var maxScaleX = (2.0f * Math.Min(center.X, vp.X - center.X) * sc) / Math.Max(rect.Size.X, 0.0001f);
        var maxScaleY = (2.0f * Math.Min(center.Y, vp.Y - center.Y) * sc) / Math.Max(rect.Size.Y, 0.0001f);

        return Math.Min(desired, Math.Max(0.0001f, Math.Min(maxScaleX, maxScaleY)));
    }
    #endregion

    #region Utilities (Optimized)
    private void SafeCallDeferred(string method, params Variant[] args)
    {
        if (IsInsideTree() && !IsQueuedForDeletion())
        {
            if (args.Length == 0) CallDeferred(method);
            else CallDeferred(method, args);
        }
    }

    private bool PointInside(Vector2 globalPoint)
    {
        var src = BoundsSource ?? this;
        var rect = src.GetGlobalRect();
        if (HitSlop != Vector2.Zero)
            rect = rect.GrowIndividual(HitSlop.X, HitSlop.Y, HitSlop.X, HitSlop.Y);
        return rect.HasPoint(globalPoint);
    }

    private bool ActionAllowed() =>
        RequireFocusForAction ? HasFocus() : (HasFocus() || PointInside(GetViewport().GetMousePosition()));

    private Callable AdoptConnectedCallable(string sigName, Callable fallback)
    {
        var conns = GetSignalConnectionList(sigName);
        foreach (Dictionary d in conns)
        {
            var c = (Callable)d["callable"];
            if (c.Target != this) return c;
        }
        return conns.Count > 0 ? (Callable)((Dictionary)conns[0])["callable"] : fallback;
    }
    #endregion

    #region Public API Methods (Optimized)
    public void SetSelected(bool isSelected, Color color = default)
    {
        if (color != default && color != new Color(0, 0, 0, 0))
            SelectedColor = color;
        SetSelectionState(isSelected, false);
    }

    public void SetUnSelected(bool isUnSelected, Color color = default)
    {
        if (color != default && color != new Color(0, 0, 0, 0))
            UnSelectedColor = color;
        SetSelectionState(false, isUnSelected);
    }

    public bool IsSelected() => _selected;
    public bool IsUnSelected() => _unSelected;
    public void ClearSelectionStates() => SetSelectionState(false, false);
    public void RefreshOverlay() => UpdateOverlay();

    public void SetSelectedWithPreset(bool isSelected, string preset)
    {
        var color = PresetSelectedColors.GetValueOrDefault(preset.ToLowerInvariant(), new Color(0.4f, 0.7f, 1.0f, 0.7f));
        SetSelected(isSelected, color);
    }

    public void SetUnSelectedWithPreset(bool isUnSelected, string preset)
    {
        var color = PresetUnselectedColors.GetValueOrDefault(preset.ToLowerInvariant(), new Color(0.0f, 0.0f, 0.0f, 0.2f));
        SetUnSelected(isUnSelected, color);
    }

    public void SetTextAlignment(HorizontalAlignment hAlign, VerticalAlignment vAlign) => SetAlignment(hAlign, vAlign);

    public void SetThemeInheritance(bool enabled)
    {
        InheritThemeToChildren = enabled;
        if (enabled && Theme != null)
            ApplyThemeToChildren();
        else
        {
            if (_cachedLabel != null && IsInstanceValid(_cachedLabel)) _cachedLabel.Theme = null;
            if (_cachedIcon != null && IsInstanceValid(_cachedIcon)) _cachedIcon.Theme = null;
        }
    }
    #endregion

    #region Built-in Fallback Behaviors
    private void RunBuiltInPressed() => RunBuiltInLog("info", $"PressedAction not set; running built-in logic for {Name}.");
    private void RunBuiltInToggled(bool _) => RunBuiltInLog("info", $"ToggledAction not set; running built-in logic for {Name}.");
    private void RunBuiltInReleased() => RunBuiltInLog("info", $"ReleasedAction not set; running built-in logic for {Name}.");

    private void RunBuiltInHoverIn()
    {
        PivotOffset = Size / 2.0f;
        Scale = Scale.Lerp(Vector2.One * HoverScale, HoverLerpSpeed * (float)GetProcessDeltaTime());
    }

    private void RunBuiltInHoverOut()
    {
        PivotOffset = Size / 2.0f;
        Scale = Scale.Lerp(Vector2.One, HoverLerpSpeed * (float)GetProcessDeltaTime());
    }

    private static void RunBuiltInLog(string type, string message)
    {
        switch (type.ToLowerInvariant())
        {
            case "error": GD.PushError(message); break;
            case "warning": GD.PushWarning(message); break;
            default: GD.Print(message); break;
        }
    }
    #endregion

    #region Property List & Signal Management (Optimized)
    private static readonly (string name, Variant.Type type, int usage, PropertyHint hint, string? hintString)[] PropertyDefinitions = new[]
    {
        ("Interaction & Actions/EnableToggleActions", Variant.Type.Bool, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Text & Font/HorizontalAlignment", Variant.Type.Int, (int)PropertyUsageFlags.Default, PropertyHint.Enum, "Left,Center,Right,Fill"),
        ("Text & Font/VerticalAlignment", Variant.Type.Int, (int)PropertyUsageFlags.Default, PropertyHint.Enum, "Top,Center,Bottom,Fill"),
        ("Text & Font/AutowrapMode", Variant.Type.Int, (int)PropertyUsageFlags.Default, PropertyHint.Enum, "Off,Arbitrary,Word,WordSmart"),
        ("Text & Font/InvertTextIfNoIcon", Variant.Type.Bool, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Interaction & Actions/Selected", Variant.Type.Bool, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Interaction & Actions/SelectedColor", Variant.Type.Vector4, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Interaction & Actions/UnSelected", Variant.Type.Bool, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Interaction & Actions/UnSelectedColor", Variant.Type.Vector4, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/BaseNormalThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/BaseHoverThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/BasePressedThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/LabelNormalThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/LabelHoverThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/LabelPressedThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/IconNormalThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/IconHoverThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null),
        ("Theme & Visuals/IconPressedThemeVariation", Variant.Type.String, (int)PropertyUsageFlags.Default, PropertyHint.None, null)
    };

    private static readonly (string name, Variant.Type type)[] ToggleDependentProperties = new[]
    {
        ("Interaction & Actions/TogglePressed", Variant.Type.Bool),
        ("Interaction & Actions/ToggledAction", Variant.Type.Callable),
        ("Theme & Visuals/BaseToggledThemeVariation", Variant.Type.String),
        ("Theme & Visuals/LabelToggledThemeVariation", Variant.Type.String),
        ("Theme & Visuals/IconToggledThemeVariation", Variant.Type.String)
    };

    private Array<Dictionary> BuildPropertyList()
    {
        var list = new Array<Dictionary>();
        var usage = (int)PropertyUsageFlags.Default;
        var usageHidden = (int)PropertyUsageFlags.Storage;

        // Add base properties
        foreach (var (name, type, propUsage, hint, hintString) in PropertyDefinitions)
        {
            var dict = new Dictionary
            {
                ["name"] = name,
                ["type"] = (int)type,
                ["usage"] = propUsage
            };

            if (hint != PropertyHint.None)
            {
                dict["hint"] = (int)hint;
                dict["hint_string"] = hintString ?? "";
            }

            list.Add(dict);
        }

        // Add toggle-dependent properties
        foreach (var (name, type) in ToggleDependentProperties)
        {
            list.Add(new Dictionary
            {
                ["name"] = name,
                ["type"] = (int)type,
                ["usage"] = EnableToggleActions ? usage : usageHidden
            });
        }

        return list;
    }

    private void DisconnectAllSignalHandlers()
    {
        if (Engine.IsEditorHint()) return;

        // Disconnect own signals
        foreach (var sig in OwnSignals)
        {
            var connections = GetSignalConnectionList(sig);
            foreach (Dictionary conn in connections)
            {
                if (conn.TryGetValue("callable", out var callableVar))
                {
                    var callable = (Callable)callableVar;
                    if (callable.Target == this && IsConnected(sig, callable))
                        Disconnect(sig, callable);
                }
            }
        }

        // Disconnect incoming connections
        foreach (var inc in GetIncomingConnections())
        {
            if (inc is Dictionary dict &&
                dict.TryGetValue("source", out var sourceVar) &&
                dict.TryGetValue("signal", out var signalVar) &&
                dict.TryGetValue("callable", out var callableVar))
            {
                var src = sourceVar.AsGodotObject();
                var sigName = signalVar.AsString();
                var call = callableVar.As<Callable>();

                if (IsInstanceValid(src) && call.Target != null && src.IsConnected(sigName, call))
                    src.Disconnect(sigName, call);
            }
        }
    }
    #endregion
}
