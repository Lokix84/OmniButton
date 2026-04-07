using Godot;
using Godot.Collections;
using System;
#nullable enable
[Tool]
[GlobalClass, GodotClassName("OmniButton")]
/// <summary>
/// OmniButton is a flexible UI Control that provides press/release/hover/toggle/hold/swipe
/// interactions, optional selection overlays, a cooldown fill, hover scaling, and an optional
/// virtual joystick mode. It is editor-friendly and primarily driven by exported properties
/// and signals, so it drops into many UI patterns with minimal code.
/// </summary>
/// <remarks>
/// <b>Child nodes</b> (e.g. Font Awesome, extra icons): add as <b>direct children of OmniButton</b> (siblings of internal <c>_Managed</c>), not inside <c>_Managed</c>.
/// Do <b>not</b> use these reserved names (they are removed/rebuilt on refresh):
/// <c>Panel</c>, <c>Background</c>, <c>Icon</c>, <c>Label</c>, <c>RichLabel</c>, <c>Overlay</c>, <c>HoldFill</c>, <c>Cooldown</c>, <c>DefaultThumb</c>, <c>JoystickArea</c>.
/// Use <see cref="ManagedDrawOnTop"/> to control whether built-in visuals draw above or below your nodes.
/// For decorative overlays, set <c>MouseFilter = Ignore</c> (or <c>Pass</c>) so the button still receives <c>_GuiInput</c> unless you intentionally want the child to steal input.
/// </remarks>
public partial class OmniButton : Control
{
    #region Signals
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ReleasedEventHandler();
    [Signal] public delegate void HoverInEventHandler();
    [Signal] public delegate void HoverOutEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool pressed);
    [Signal] public delegate void TypewriterCompletedEventHandler();
    [Signal] public delegate void HoldEventHandler();
    [Signal] public delegate void SwipeEventHandler(Vector2 direction);
    [Signal] public delegate void SwipeEndedEventHandler();
    [Signal] public delegate void LogEventHandler(string message);
    [Signal] public delegate void WarningEventHandler(string message);
    [Signal] public delegate void ErrorEventHandler(string message);
    [Signal] public delegate void JoystickStartedEventHandler();
    [Signal] public delegate void JoystickAxisEventHandler(Vector2 axis);
    [Signal] public delegate void JoystickEndedEventHandler();
    #endregion
    #region Debugging
    public enum DebuggerLogMode { Off = 0, Basic = 1 }
    #endregion
    #region Preset(Exported Properties)
    public enum Preset { None = 0, Basic = 1, Toggle = 2, Hold = 3, Swipe = 4, Draggable = 5, VirtualJoystick = 6, Custom = 99 }
    private bool _suppressPresetApply = false;
    private Preset _preset = Preset.None;
    [ExportCategory("Essentials")]
    [ExportGroup("Presets")]
    [Export]
    public Preset PresetSelection
    {
        get => _preset;
        set
        {
            if (_preset == value) return;
            _preset = value;
            if (_preset == Preset.Custom || _preset == Preset.None) return;
            ApplyPreset(_preset);
        }
    }
    #endregion
    #region State(Exported Properties)
    [ExportGroup("State")]
    [Export] public bool Disabled { get; set; } = false;
    [Export]
    public bool Selected
    {
        get => _isSelected;
        set
        {
            if (_isSelected == value) return;
            _isSelected = value;
            DebugLog($"Selected={(value ? "true" : "false")}");
            UpdateOverlay();
            InvalidateVisualState();
        }
    }
    [Export]
    public bool IsToggled
    {
        get => _isToggled;
        set
        {
            if (_isToggled == value) return;
            _isToggled = value;
            DebugLog($"IsToggled={(value ? "true" : "false")}");
            UpdateOverlay();
            InvalidateVisualState();
        }
    }
    [Export]
    public bool IsPressed
    {
        get => _isPressed;
        set
        {
            if (_isPressed == value)
            {
                DebugLog($"IsPressed unchanged={value}");
                InvalidateVisualState();
                return;
            }
            bool wasPressed = _isPressed;
            _isPressed = value;
            DebugLog($"IsPressed={(value ? "true" : "false")}");
            // Only on transition into pressed
            if (!wasPressed && _isPressed && EnableHoldBuildUp && !_isHolding)
            {
                _holdTimer = 0;
                EnsureHoldFill();
                UpdateHoldFillVisual();
                if (_holdFill != null && IsInstanceValid(_holdFill)) _holdFill.Visible = true;
                SetProcess(true);
            }
            // Only on transition out of pressed
            else if (wasPressed && !_isPressed)
            {
                RemoveHoldFill();
            }
            InvalidateVisualState();
        }
    }
    [Export]
    public bool IsHovering
    {
        get => _isHovering;
        set
        {
            if (_isHovering == value) return;
            _isHovering = value;
            DebugLog($"IsHovering={(value ? "true" : "false")}");
            InvalidateVisualState();
        }
    }
    [Export]
    public bool IsHolding
    {
        get => _isHolding;
        set
        {
            bool wasHolding = _isHolding;
            _isHolding = value;
            // When holding flips on, remove the hold build-up overlay immediately
            if (!wasHolding && _isHolding)
                RemoveHoldFill();
            if (wasHolding != value)
                DebugLog($"IsHolding={(value ? "true" : "false")}");
            InvalidateVisualState();
        }
    }
    #endregion
    #region Accessibility (Exported Properties)
    [ExportCategory("Accessibility")]
    [ExportGroup("Keyboard focus")]
    [Export]
    public bool ShowKeyboardFocusOutline
    {
        get => _showKeyboardFocusOutline;
        set
        {
            if (_showKeyboardFocusOutline == value) return;
            _showKeyboardFocusOutline = value;
            QueueRedraw();
        }
    }
    private bool _showKeyboardFocusOutline;
    [Export]
    public Color KeyboardFocusOutlineColor
    {
        get => _keyboardFocusOutlineColor;
        set
        {
            _keyboardFocusOutlineColor = value;
            QueueRedraw();
        }
    }
    private Color _keyboardFocusOutlineColor = new Color(0.6f, 0.85f, 1f, 0.95f);
    [Export(PropertyHint.Range, "1,8,1")]
    public int KeyboardFocusOutlineWidth
    {
        get => _keyboardFocusOutlineWidth;
        set
        {
            _keyboardFocusOutlineWidth = Mathf.Clamp(value, 1, 8);
            QueueRedraw();
        }
    }
    private int _keyboardFocusOutlineWidth = 2;
    #endregion
    #region Display Properties(Exported Properties)
    [ExportCategory("Appearance")]
    [ExportGroup("Background")]
    [Export]
    public BackgroundMode BackgroundType
    {
        get => _backgroundMode;
        set { _backgroundMode = value; RefreshEditorVisual(children: true, panelStyling: true); }
    }
    public enum BackgroundMode { None = 0, UsePanel = 1, UseTexture = 2 }
    private BackgroundMode _backgroundMode = BackgroundMode.None;
    private Texture2D? _iconTexture;
    private void InvalidateAutosizeState()
    {
        _fitCacheSig = string.Empty;
        _lastFitFontSize = -1;
        _richCurrentFontSize = -1;
    }

    private void DebugLog(string message)
    {
        if (!Engine.IsEditorHint() && DebuggerLog != DebuggerLogMode.Off)
            GD.Print($"[OmniButton:{Name}] {message}");
    }

    // Label type + unified Text (backing fields; text exports follow Background and Icon groups for correct inspector nesting)
    public enum LabelTypeEnum { Label = 0, RichTextLabel = 1 }
    private LabelTypeEnum _labelType = LabelTypeEnum.Label;
    private string _text = string.Empty;
    private string _labelText = string.Empty;
    private string _richLabelText = string.Empty;
    #region Panel(Exported Properties)
    [ExportSubgroup("Panel & Texture")]
    [Export] public string PanelThemeVariation { get => _panelThemeVariation; set { _panelThemeVariation = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private string _panelThemeVariation = "";
    [Export] public StyleBox? PanelStyleBox { get => _panelStyleBox; set { _panelStyleBox = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private StyleBox? _panelStyleBox;
    /// <summary>
    /// Optional background texture when Background = UseTexture
    /// </summary>
    [Export] public Texture2D? BackgroundTexture { get; set; }
    /// <summary>
    /// Expand mode for background texture
    /// </summary>
    [Export] public TextureRect.ExpandModeEnum BackgroundExpandMode { get; set; } = TextureRect.ExpandModeEnum.FitWidthProportional;
    /// <summary>
    /// Stretch mode for background texture
    /// </summary>
    [Export] public TextureRect.StretchModeEnum BackgroundStretchMode { get; set; } = TextureRect.StretchModeEnum.Scale;
    /// <summary>
    /// Flip background texture horizontally
    /// </summary>
    [Export] public bool BackgroundFlipH { get; set; } = false;
    /// <summary>
    /// Flip background texture vertically
    /// </summary>
    [Export] public bool BackgroundFlipV { get; set; } = false;
    /// <summary>
    /// Modulate colors for panel and background
    /// </summary>
    [Export] public Color PanelModulate { get; set; } = Colors.White;
    [Export] public Color BackgroundModulate { get; set; } = Colors.White;
    #endregion
    #region Icon(Exported Properties)
    [ExportGroup("Icon")]
    /// <summary>
    /// Optional icon texture displayed inside the button
    /// </summary>
    [Export]
    public Texture2D? IconTexture
    {
        get => _iconTexture;
        set
        {
            _iconTexture = value;
            SetupChildren();
            InvalidateVisualState();
            FitLabelText();
        }
    }
    [Export] public TextureRect.ExpandModeEnum IconExpandMode { get => _iconExpand; set { _iconExpand = value; RefreshEditorVisual(); } }
    private TextureRect.ExpandModeEnum _iconExpand = TextureRect.ExpandModeEnum.FitWidthProportional;
    [Export] public TextureRect.StretchModeEnum IconStretchMode { get => _iconStretch; set { _iconStretch = value; RefreshEditorVisual(); } }
    private TextureRect.StretchModeEnum _iconStretch = TextureRect.StretchModeEnum.Scale;
    [Export] public bool IconFlipH { get => _iconFlipH; set { _iconFlipH = value; RefreshEditorVisual(); } }
    private bool _iconFlipH = false;
    [Export] public bool IconFlipV { get => _iconFlipV; set { _iconFlipV = value; RefreshEditorVisual(); } }
    private bool _iconFlipV = false;
    /// <summary>
    /// Modulate color for icon
    /// </summary>
    [Export] public Color IconModulate { get; set; } = Colors.White;
    #endregion
    [ExportGroup("Text")]
    [Export]
    public LabelTypeEnum LabelType
    {
        get => _labelType;
        set
        {
            _labelType = value;
            // Mirror into legacy fields for internal use
            if (_labelType == LabelTypeEnum.Label) { _labelText = _text; _richLabelText = string.Empty; }
            else { _richLabelText = _text; _labelText = string.Empty; }
            if (_twActive)
            {
                RequestRefresh(false, false, false);
                return;
            }
            SetupChildren();
            InvalidateVisualState();
            ScheduleFitLabel();
        }
    }
    [Export(PropertyHint.MultilineText)]
    public string Text
    {
        get => _text;
        set
        {
            _text = value ?? string.Empty;
            if (_labelType == LabelTypeEnum.Label) { _labelText = _text; _richLabelText = string.Empty; }
            else { _richLabelText = _text; _labelText = string.Empty; }
            if (_twActive)
            {
                RequestRefresh(false, false, false);
                return;
            }
            SetupChildren();
            InvalidateVisualState();
            ScheduleFitLabel();
        }
    }
    [ExportSubgroup("Legacy Scenes")]
    [Export(PropertyHint.MultilineText)]
    public string LabelText
    {
        get => _labelType == LabelTypeEnum.Label ? _text : string.Empty;
        set
        {
            _labelType = LabelTypeEnum.Label;
            Text = value ?? string.Empty;
        }
    }
    [Export(PropertyHint.MultilineText)]
    public string RichLabelText
    {
        get => _labelType == LabelTypeEnum.RichTextLabel ? _text : string.Empty;
        set
        {
            _labelType = LabelTypeEnum.RichTextLabel;
            Text = value ?? string.Empty;
        }
    }
    [Export(PropertyHint.MultilineText)]
    public string TextToType { get; set; } = string.Empty;

    #region Label(Exported Properties)
    [ExportGroup("Label")]
    [ExportSubgroup("Typography")]
    /// <summary>
    /// Optional font resource applied to Label/RichText
    /// </summary>
    [Export] public Font? LabelFont { get => _labelFont; set { _labelFont = value; RefreshEditorVisual(); } }
    private Font? _labelFont;
    /// <summary>
    /// Text color for Label/RichText (default_color)
    /// </summary>
    [Export] public Color LabelTextColor { get => _labelTextColor; set { _labelTextColor = value; RefreshEditorVisual(); } }
    private Color _labelTextColor = Colors.White;
    /// <summary>
    /// Modulate color for Label/RichText
    /// </summary>
    [Export] public Color TextModulate { get; set; } = Colors.White;
    /// <summary>
    /// Horizontal alignment for Label/RichText text
    /// </summary>
    [Export] public HorizontalAlignment LabelHorizontalAlignment { get => _labelHAlign; set { _labelHAlign = value; RefreshEditorVisual(); } }
    private HorizontalAlignment _labelHAlign = HorizontalAlignment.Center;
    /// <summary>
    /// Vertical alignment for Label text
    /// </summary>
    [Export] public VerticalAlignment LabelVerticalAlignment { get => _labelVAlign; set { _labelVAlign = value; RefreshEditorVisual(); } }
    private VerticalAlignment _labelVAlign = VerticalAlignment.Center;
    /// <summary>
    /// Autowrap mode for Label/RichText; affects autosize
    /// </summary>
    [Export] public TextServer.AutowrapMode LabelAutowrap { get => _labelAutowrap; set { _labelAutowrap = value; InvalidateAutosizeState(); RefreshEditorVisual(); } }
    private TextServer.AutowrapMode _labelAutowrap = TextServer.AutowrapMode.Off;
    [ExportSubgroup("Sizing & Fit")]
    [Export] public Vector2 TextFitPadding { get; set; } = new Vector2(12, 4);
    /// <summary>
    /// Minimum font size used by autosize
    /// </summary>
    [Export(PropertyHint.Range, "6,300,1")]
    public int MinFontSize { get => _minFontSize; set { _minFontSize = value; ScheduleFitLabel(); } }
    private int _minFontSize = 6;
    /// <summary>
    /// Maximum font size used by autosize (autosize binary search cost scales with log2(Max−Min); keep range tight for UI perf)
    /// </summary>
    [Export(PropertyHint.Range, "6,300,1")]
    public int MaxFontSize { get => _maxFontSize; set { _maxFontSize = value; ScheduleFitLabel(); } }
    private int _maxFontSize = 100;
    /// <summary>
    /// When > 0 forces this fixed size and bypasses autosize
    /// </summary>
    [Export(PropertyHint.Range, "0,300,1")] public int FixedFontSize { get; set; } = 0;
    /// <summary>
    /// Enable dynamic auto-sizing of Label/RichText within control bounds
    /// </summary>
    [Export] public bool EnableTextAutoSize { get => _enableTextAutoSize; set { _enableTextAutoSize = value; ScheduleFitLabel(); } }
    private bool _enableTextAutoSize = true;
    /// <summary>
    /// Universal text padding (pixels). X applies to left and right, Y to top and bottom.
    /// This is a base inset applied to both Label and RichTextLabel.
    /// </summary>
    [Export] public Vector2 LabelPadding { get => _labelPadding; set { _labelPadding = value; RefreshEditorVisual(); } }
    private Vector2 _labelPadding = Vector2.Zero;
    /// <summary>
    /// Additional per-side text padding (pixels). These values are added on top of the universal LabelPadding.
    /// Use to nudge a specific side (e.g., only bottom/right for corner-aligned counts).
    /// </summary>
    [Export(PropertyHint.Range, "0,4096,1")] public float LabelAdditionalPaddingLeft { get => _labelPadLeft; set { _labelPadLeft = value; RefreshEditorVisual(); } }
    [Export(PropertyHint.Range, "0,4096,1")] public float LabelAdditionalPaddingTop { get => _labelPadTop; set { _labelPadTop = value; RefreshEditorVisual(); } }
    [Export(PropertyHint.Range, "0,4096,1")] public float LabelAdditionalPaddingRight { get => _labelPadRight; set { _labelPadRight = value; RefreshEditorVisual(); } }
    [Export(PropertyHint.Range, "0,4096,1")] public float LabelAdditionalPaddingBottom { get => _labelPadBottom; set { _labelPadBottom = value; RefreshEditorVisual(); } }
    private float _labelPadLeft = 0f, _labelPadTop = 0f, _labelPadRight = 0f, _labelPadBottom = 0f;

    // ===== BBCode-aware typing support =====
    private struct BBToken { public bool IsTag; public string Content; public BBToken(bool t, string c) { IsTag = t; Content = c; } }
    private bool _twBBCodeAware = false;
    [ExportGroup("Typewriter")]
    [Export] public bool SuspendHoverDuringTypewriter { get; set; } = true;
    [Export] public bool DelayEffectTagsDuringTypewriter { get; set; } = true;
    private bool _twDelayEffects => DelayEffectTagsDuringTypewriter;
    [Export] public bool FinishTypewriterOnPress { get; set; } = true;
    private System.Collections.Generic.List<BBToken>? _twBBTokens;
    private int _twVisiblePlainChars = 0;
    private int _twTotalPlainChars = 0;

    // Modulate properties relocated into relevant subgroups below
    #endregion
    #region Invert Display(Exported Properties)
    /// <summary>
    /// Flags for when to apply a simple invert shader to child visuals.
    /// Combine to invert on press, toggle, hover, or while holding.
    /// </summary>
    [Flags] public enum InvertDisplayModes { None = 0, Press = 1, Toggle = 2, Hover = 4, Hold = 8 }
    private InvertDisplayModes _invertModes = InvertDisplayModes.None;
    [ExportGroup("Visual Effects")]
    [ExportSubgroup("Invert Display")]
    [Export]
    public InvertDisplayModes InvertModes
    {
        get => _invertModes;
        set { _invertModes = value; MarkPresetCustom(); }
    }
    #endregion
    #region Hover Scaling(Exported Properties)
    [ExportSubgroup("Hover Scaling")]
    [Export]
    public bool EnableHoverScale
    {
        get => _enableHoverScale;
        set
        {
            _enableHoverScale = value;
            MarkPresetCustom();
            if (!_enableHoverScale)
            {
                HoverScale = 1.25f;
                HoverLerpSpeed = 25.0f;
                if (_panel != null && IsInstanceValid(_panel)) _panel.Scale = Vector2.One;
                if (_icon != null && IsInstanceValid(_icon)) _icon.Scale = Vector2.One;
                if (_label != null && IsInstanceValid(_label)) _label.Scale = Vector2.One;
                if (_overlay != null && IsInstanceValid(_overlay)) _overlay.Scale = Vector2.One;
            }
            RefreshEditorVisual();
        }
    }
    private bool _enableHoverScale = false;
    [Export(PropertyHint.Range, "1.0,3.0,0.01")]
    public float HoverScale
    {
        get => _hoverScale;
        set { _hoverScale = value; RefreshEditorVisual(); }
    }
    private float _hoverScale = 1.25f;
    [Export(PropertyHint.Range, "0.0,100.0,0.1")]
    public float HoverLerpSpeed
    {
        get => _hoverLerpSpeed;
        set { _hoverLerpSpeed = value; }
    }
    private float _hoverLerpSpeed = 25.0f;
    #endregion
    private Color _selectedColor = new Color(1, 1, 1, 0.3f);
    /// <summary>
    /// Overlay color used when the selection overlay is visible (Selected == true).
    /// </summary>
    [ExportGroup("Selection")]
    [Export]
    public Color SelectedColor
    {
        get => _selectedColor;
        set { _selectedColor = value; RefreshEditorVisual(); }
    }
    #endregion
    #region Actions(Exported Properties)
    // Behavior
    [Flags]
    public enum ActionMaskFlags
    {
        None = 0,
        Pressed = 1 << 0,
        Released = 1 << 1,
        Hover = 1 << 2,
        Toggle = 1 << 3,
        Hold = 1 << 4,
        Swipe = 1 << 5,
        Log = 1 << 6,
        Warning = 1 << 7,
        Error = 1 << 8
    }
    /// <summary>
    /// Action enable mask. Note: the first time an external handler is connected to a signal
    /// (Pressed/Released/Hover/Toggle/Hold/Swipe/Log/Warning/Error), the corresponding bit is
    /// auto-enabled for convenience. If you later disable a bit manually, it will remain off.
    /// </summary>
    [ExportCategory("Behavior")]
    [ExportGroup("Actions")]
    // Export as bits to avoid editor issues with [Flags] enums
    [Export(PropertyHint.Flags, "Pressed,Released,Hover,Toggle,Hold,Swipe,Log,Warning,Error")] public int ActionMaskBits { get; set; } = 0;
    public ActionMaskFlags ActionMask
    {
        get => (ActionMaskFlags)ActionMaskBits;
        set => ActionMaskBits = (int)value;
    }
    public Callable PressedAction { get; set; }
    public Callable ReleasedAction { get; set; }
    public Callable HoverInAction { get; set; }
    public Callable HoverOutAction { get; set; }
    public Callable ToggledAction { get; set; }
    [ExportSubgroup("Hold Build-Up")]
    public Callable HoldAction { get; set; }
    [Export(PropertyHint.Range, "0.05,5.0,0.05")] public float HoldDuration { get; set; } = 0.5f;
    [Export] public bool EnableHoldBuildUp { get; set; } = false;
    [Export] public Color HoldFillColor { get; set; } = new Color(1, 1, 1, 0.25f);
    [Export] public CooldownDirection HoldFillDirection { get; set; } = CooldownDirection.BottomToTop;
    [ExportSubgroup("Swipe")]
    public Callable SwipeAction { get; set; }
    [Export(PropertyHint.Range, "0.0,1000.0,1.0")] public float SwipeThreshold { get; set; } = 20f;

    public enum SwipeInitMode { OnHoverIn = 0, OnPressed = 1 }
    public enum SwipeExitMode { OnHoverOut = 0, OnReleased = 1 }

    private SwipeInitMode _touchSwipeInit = SwipeInitMode.OnHoverIn;
    private SwipeExitMode _touchSwipeExit = SwipeExitMode.OnHoverOut;
    private SwipeInitMode _mouseSwipeInit = SwipeInitMode.OnPressed;
    private SwipeExitMode _mouseSwipeExit = SwipeExitMode.OnReleased;

    [Export]
    public SwipeInitMode TouchSwipeInit { get => _touchSwipeInit; set { _touchSwipeInit = value; MarkPresetCustom(); } }
    [Export]
    public SwipeExitMode TouchSwipeExit { get => _touchSwipeExit; set { _touchSwipeExit = value; MarkPresetCustom(); } }
    [Export]
    public SwipeInitMode MouseSwipeInit { get => _mouseSwipeInit; set { _mouseSwipeInit = value; MarkPresetCustom(); } }
    [Export]
    public SwipeExitMode MouseSwipeExit { get => _mouseSwipeExit; set { _mouseSwipeExit = value; MarkPresetCustom(); } }
    public Callable LogAction { get; set; }
    public Callable WarningAction { get; set; }
    public Callable ErrorAction { get; set; }
    // Toggling semantics
    public enum InteractionModeEnum { Momentary = 0, ToggleOnPress = 1, ToggleOnRelease = 2 }
    private InteractionModeEnum _interactionMode = InteractionModeEnum.Momentary;
    [ExportSubgroup("Toggle Behavior")]
    [Export]
    public InteractionModeEnum InteractionMode { get => _interactionMode; set { _interactionMode = value; MarkPresetCustom(); } }
    #endregion
    #region Cooldown(Exported Properties)
    public enum CooldownDirection
    {
        BottomToTop = 0,
        TopToBottom = 1,
        LeftToRight = 2,
        RightToLeft = 3
    }
    [ExportGroup("Cooldown")]
    private bool _enableCooldown = false;
    /// <summary>
    /// Enable cooldown fill overlay and timing
    /// </summary>
    [Export]
    public bool EnableCooldown
    {
        get => _enableCooldown;
        set
        {
            _enableCooldown = value;
            MarkPresetCustom();
            if (!_enableCooldown)
            {
                CooldownTrigger = CooldownTriggerEnum.None;
                CooldownStartDelay = 0.0f;
                CooldownDuration = 1.0f;
                CooldownStartFilled = false;
                CooldownColor = new Color(0, 0, 0, 0.4f);
                CooldownFillDirection = CooldownDirection.BottomToTop;
                InvertOnCooldown = false;
                CooldownInvertDuration = 0.0f;
                SuspendHoverScaleDuringCooldown = false;
                AllowHoldDuringCooldown = false;
                HideCooldownDuringHoldBuildUp = true;
                _cooldownActive = false;
                _cooldownTimeLeft = 0.0;
                _cooldownDelayPending = false;
                _cooldownDelayLeft = 0.0;
                _cooldownElapsed = 0.0;
                if (_cooldown != null && IsInstanceValid(_cooldown))
                {
                    _cooldown.Visible = false;
                    _cooldown.Size = Vector2.Zero;
                    _cooldown.Position = Vector2.Zero;
                }
            }
        }
    }
    public enum CooldownTriggerEnum { None = 0, OnPress = 1, OnRelease = 2, OnPressAndRelease = 3 }
    private CooldownTriggerEnum _cooldownTrigger = CooldownTriggerEnum.None;
    [Export]
    public CooldownTriggerEnum CooldownTrigger
    {
        get => _cooldownTrigger;
        set { _cooldownTrigger = value; SafeNotifyPropertyListChanged(); }
    }
    /// <summary>
    /// Optional delay before cooldown begins, allowing pressed visuals to show.
    /// </summary>
    [Export(PropertyHint.Range, "0.0,10.0,0.01")] public float CooldownStartDelay { get; set; } = 0.0f;
    /// <summary>
    /// Duration of cooldown in seconds
    /// </summary>
    [Export(PropertyHint.Range, "0.05,60.0,0.05")] public float CooldownDuration { get; set; } = 1.0f;
    /// <summary>
    /// Start with overlay fully filled and empty over time
    /// </summary>
    [Export] public bool CooldownStartFilled { get; set; } = false;
    /// <summary>
    /// Color used for cooldown overlay
    /// </summary>
    [Export] public Color CooldownColor { get; set; } = new Color(0, 0, 0, 0.4f);
    /// <summary>
    /// Direction the cooldown overlay fills/empties
    /// </summary>
    [Export] public CooldownDirection CooldownFillDirection { get; set; } = CooldownDirection.BottomToTop;
    /// <summary>
    /// Invert visuals while cooldown is active.
    /// </summary>
    [Export] public bool InvertOnCooldown { get; set; } = false;
    /// <summary>
    /// How long to keep cooldown invert active. 0 = infinite.
    /// </summary>
    [Export(PropertyHint.Range, "0.0,10.0,0.01")] public float CooldownInvertDuration { get; set; } = 0.0f;
    /// <summary>
    /// Temporarily disable hover scaling during active cooldown
    /// </summary>
    [Export] public bool SuspendHoverScaleDuringCooldown { get; set; } = false;
    /// <summary>
    /// Allow hold actions while cooldown is active
    /// </summary>
    [Export] public bool AllowHoldDuringCooldown { get; set; } = false;
    /// <summary>
    /// Hide cooldown overlay while hold build-up is visible
    /// </summary>
    [Export] public bool HideCooldownDuringHoldBuildUp { get; set; } = true;
    #endregion
    #region Input(Exported Properties)
    /// <summary>
    /// If set, hit tests (press, hover-inside, swipe bounds) use this control’s global rect instead of this OmniButton’s.
    /// Use for a larger invisible hit target, matching a parent panel, or aligning with another widget’s shape.
    /// </summary>
    [ExportCategory("Input & Motion")]
    [ExportGroup("Input bounds")]
    [Export] public Control? BoundsSource { get; set; }
    /// <summary>
    /// Expands the hit rectangle in pixels on each side (X = left/right, Y = top/bottom) after resolving bounds from this control or <see cref="BoundsSource"/>.
    /// </summary>
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;
    /// <summary>
    /// While the pointer is held: None = control stays put; FollowBoth = moves with the pointer (draggable);
    /// VirtualJoystick = axis signals and optional thumb follow (see virtual joystick settings).
    /// </summary>
    public enum FollowModeEnum
    {
        None = 0,
        FollowBoth = 3,
        VirtualJoystick = 4
    }
    #endregion
    #region Follow(Exported Properties)
    [ExportGroup("Drag & virtual joystick")]
    private FollowModeEnum _followMode = FollowModeEnum.None;
    /// <summary>
    /// How the control behaves while pressed: stationary, draggable with the pointer, or virtual joystick mode.
    /// </summary>
    [Export]
    public FollowModeEnum FollowMode
    {
        get => _followMode;
        set
        {
            _followMode = value;
            MarkPresetCustom();
            if (_followMode == FollowModeEnum.None)
            {
                ClampToBounds = true;
            }
            if (_followMode != FollowModeEnum.VirtualJoystick && !EnableVirtualJoystick)
            {
                ClampShape = JoystickClampShape.Circle;
                JoystickRadiusPx = 0;
                JoystickRectSizePx = Vector2.Zero;
                JoystickDeadzone = 0.1f;
                JoystickSnapToInput = true;
                JoystickHideWhenInactive = false;
                JoystickResetOnRelease = true;
            }
            SafeNotifyPropertyListChanged();
        }
    }
    #endregion
    #region Virtual Joystick(Exported Properties)
    [ExportSubgroup("Virtual Joystick")]
    private bool _enableVirtualJoystick = false;
    /// <summary>
    /// Enable virtual joystick behavior and signals
    /// </summary>
    [Export]
    public bool EnableVirtualJoystick
    {
        get => _enableVirtualJoystick;
        set
        {
            _enableVirtualJoystick = value;
            if (!_enableVirtualJoystick && FollowMode != FollowModeEnum.VirtualJoystick)
            {
                ClampShape = JoystickClampShape.Circle;
                JoystickRadiusPx = 0;
                JoystickRectSizePx = Vector2.Zero;
                JoystickDeadzone = 0.1f;
                JoystickSnapToInput = true;
                JoystickHideWhenInactive = false;
                JoystickResetOnRelease = true;
            }
            SafeNotifyPropertyListChanged();
        }
    }
    public enum JoystickClampShape { Circle = 0, Rectangle = 1 }
    private JoystickClampShape _clampShape = JoystickClampShape.Circle;
    /// <summary>
    /// Clamp shape used for virtual joystick movement
    /// </summary>
    [Export]
    public JoystickClampShape ClampShape
    {
        get => _clampShape;
        set { _clampShape = value; SafeNotifyPropertyListChanged(); }
    }
    /// <summary>
    /// Circle clamp radius in pixels (0 = auto)
    /// </summary>
    [Export(PropertyHint.Range, "0,4096,1")] public int JoystickRadiusPx { get; set; } = 0;
    /// <summary>
    /// Rectangle clamp size in pixels (0 = auto)
    /// </summary>
    [Export] public Vector2 JoystickRectSizePx { get; set; } = Vector2.Zero;
    /// <summary>
    /// Deadzone for joystick axis output
    /// </summary>
    [Export(PropertyHint.Range, "0.0,1.0,0.01")] public float JoystickDeadzone { get; set; } = 0.1f;
    /// <summary>
    /// Snap the visual to pointer while active
    /// </summary>
    [Export] public bool JoystickSnapToInput { get; set; } = true;
    /// <summary>
    /// Hide control when joystick is inactive (runtime)
    /// </summary>
    [Export] public bool JoystickHideWhenInactive { get; set; } = false;
    /// <summary>
    /// Return visual to home on release
    /// </summary>
    [Export] public bool JoystickResetOnRelease { get; set; } = true;

    // Virtual joystick area ring (optional static background)
    [ExportSubgroup("Virtual Joystick Area")]
    /// <summary>
    /// Draw an area ring for the joystick clamp zone
    /// </summary>
    [Export] public bool EnableJoystickArea { get; set; } = false;
    /// <summary>
    /// Keep area ring visible when inactive
    /// </summary>
    [Export] public bool JoystickAreaPersistent { get; set; } = false;
    /// <summary>
    /// Color of the joystick area ring
    /// </summary>  
    [Export] public Color JoystickAreaColor { get; set; } = new Color(1, 1, 1, 0.25f);
    /// <summary>
    /// Ring thickness in pixels
    /// </summary>
    [Export(PropertyHint.Range, "0,64,1")] public int JoystickAreaThickness { get; set; } = 2;
    /// <summary>
    /// Force rectangle clamp for area ring
    /// </summary>
    [Export] public bool JoystickAreaUseRectForClamp { get; set; } = false;
    /// <summary>
    /// External Control to host the area ring (optional)
    /// </summary>
    [Export] public NodePath JoystickAreaExternalPath { get; set; } = new NodePath("");

    // Virtual joystick default thumb (shown when no IconTexture is provided)
    [ExportSubgroup("Virtual Joystick Thumb")]
    /// <summary>
    /// Show default circular thumb when no icon is provided
    /// </summary>
    [Export] public bool EnableDefaultThumb { get; set; } = true;
    /// <summary>
    /// Size of default thumb relative to control
    /// </summary>
    [Export(PropertyHint.Range, "0.1,1.0,0.01")] public float DefaultThumbSizeRatio { get; set; } = 0.6f;
    /// <summary>
    /// Color of default thumb
    /// </summary>
    [Export] public Color DefaultThumbColor { get; set; } = new Color(1, 1, 1, 0.9f);
    #endregion
    [ExportSubgroup("Legacy Flags (Compat)")]
    [Export] public bool ClampToBounds { get; set; } = true;
    #region Private State
    private Panel? _panel;
    private TextureRect? _background;
    private TextureRect? _icon;
    private Label? _label;
    private RichTextLabel? _richLabel;
    private ColorRect? _overlay;
    private ColorRect? _cooldown;
    private ColorRect? _holdFill;
    private Control? _managedRoot;
    // Default visual for joystick thumb when no IconTexture is provided
    private Panel? _defaultThumb;
    private ShaderMaterial? _invertMaterial;
    private string? _lastVisualState;
    private float _hoverTargetScale = 1.0f;
    private Vector2 _originalScale = Vector2.One;
    private static readonly string[] OwnSignals = { "Pressed", "Toggled", "Released", "Log", "Warning", "Error", "Hold", "Swipe", "SwipeEnded", "HoverIn", "HoverOut" };
    private static readonly System.Collections.Generic.HashSet<string> ManagedChildNamesForPurge = new(System.StringComparer.Ordinal)
    {
        "Panel", "Background", "Icon", "Label", "RichLabel",
        "Overlay", "HoldFill", "Cooldown", "DefaultThumb", "JoystickArea"
    };
    private readonly System.Collections.Generic.List<Node> _setupChildrenPurgeScratch = new(16);
    private bool _isPressed = false;
    private bool _isHovering = false;
    private bool _isToggled = false;
    private bool _isSelected = false;
    private bool _isHolding = false;
    private bool _isSwiping = false;
    private bool _fittingLabel = false;
    private bool _themeApplying = false;
    private Vector2 _swipeStart = Vector2.Zero;
    private Vector2 _swipeOrigin = Vector2.Zero;
    private bool _touchSwipeEligible = false;
    /// <summary>Which modality owns the current press so emulated mouse + native touch do not both fire.</summary>
    private enum PointerGestureSource { None, Mouse, NativeTouch }
    private PointerGestureSource _pointerGestureSource;
    /// <summary>-1 = mouse session; &gt;= 0 = finger index that started the current native touch press on this control.</summary>
    private int _activePointerTouchIndex = -1;
    private Panel? _vjAreaPanel;
    private ActionMaskFlags _autoActionOnce = ActionMaskFlags.None;
    private void MarkPresetCustom()
    {
        if (_suppressPresetApply) return;
        if (_preset != Preset.Custom) _preset = Preset.Custom;
    }

    private void ApplyPreset(Preset p)
    {
        _suppressPresetApply = true;
        switch (p)
        {
            case Preset.Basic:
                InteractionMode = InteractionModeEnum.Momentary;
                FollowMode = FollowModeEnum.None;
                EnableHoverScale = false;
                EnableCooldown = false;
                InvertModes = InvertDisplayModes.None;
                break;
            case Preset.Toggle:
                InteractionMode = InteractionModeEnum.ToggleOnPress;
                // Overlay visibility now follows Selected only
                FollowMode = FollowModeEnum.None;
                break;
            case Preset.Hold:
                EnableHoldBuildUp = true;
                HoldDuration = Math.Max(0.1f, HoldDuration);
                FollowMode = FollowModeEnum.None;
                break;
            case Preset.Swipe:
                SwipeThreshold = Math.Max(1f, SwipeThreshold);
                MouseSwipeInit = SwipeInitMode.OnHoverIn;
                MouseSwipeExit = SwipeExitMode.OnHoverOut;
                TouchSwipeInit = SwipeInitMode.OnPressed;
                TouchSwipeExit = SwipeExitMode.OnReleased;
                FollowMode = FollowModeEnum.None;
                break;
            case Preset.Draggable:
                FollowMode = FollowModeEnum.FollowBoth;
                ClampToBounds = true;
                break;
            case Preset.VirtualJoystick:
                FollowMode = FollowModeEnum.VirtualJoystick;
                ClampShape = JoystickClampShape.Circle;
                JoystickDeadzone = 0.15f;
                JoystickSnapToInput = true;
                JoystickHideWhenInactive = false;
                JoystickResetOnRelease = true;
                // Enable default area ring
                EnableJoystickArea = true;
                JoystickAreaPersistent = false;
                JoystickAreaColor = new Color(1, 1, 1, 0.25f);
                JoystickAreaThickness = 2;
                JoystickAreaUseRectForClamp = false;
                JoystickAreaExternalPath = new NodePath("");
                break;
        }
        _suppressPresetApply = false;
    }

    private void SetSwiping(bool value)
    {
        bool was = _isSwiping;
        _isSwiping = value;
        if (was && !_isSwiping)
        {
            EmitSignal(SignalName.SwipeEnded);
            DebugLog("SwipeEnded emitted");
        }
    }
    private void EndSwiping()
    {
        SetSwiping(false);
        _swipeStart = Vector2.Zero;
    }
    private double _holdTimer = 0;
    private bool _cooldownActive = false;
    private double _cooldownTimeLeft = 0.0;
    private bool _cooldownDelayPending = false;
    private double _cooldownDelayLeft = 0.0;
    private double _cooldownElapsed = 0.0;
    private bool _vjActive = false;
    private Vector2 _vjHomeGlobal; // center of the button at press time (global)
    private MouseFilterEnum _vjSavedMouseFilter = MouseFilterEnum.Stop;
    #endregion
    #region Accessor helpers for ergonomic usage
    public LabelAccessor? Label { get; private set; }
    public IconAccessor? Icon { get; private set; }
    public BackgroundAccessor? Background { get; private set; }
    public PanelAccessor? Panel { get; private set; }
    public OverlayAccessor? Overlay { get; private set; }
    public CooldownAccessor? Cooldown { get; private set; }
    public ChargeUpAccessor? ChargeUp { get; private set; }

    public sealed class LabelAccessor
    {
        private readonly OmniButton _o;
        internal LabelAccessor(OmniButton o) { _o = o; }
        public string Text { get => _o.Text; set => _o.Text = value; }
        public LabelTypeEnum Type { get => _o.LabelType; set => _o.LabelType = value; }
        public Color Modulate { get => _o.TextModulate; set { _o.TextModulate = value; _o.RequestRefresh(false, false, false); } }
        public Font? Font { get => _o.LabelFont; set { _o.LabelFont = value; _o.RequestRefresh(false, false, true); } }
        public Color Color { get => _o.LabelTextColor; set { _o.LabelTextColor = value; _o.RequestRefresh(false, false, false); } }
        public Vector2 FitPadding { get => _o.TextFitPadding; set { _o.TextFitPadding = value; _o.RequestRefresh(false, false, true); } }
        public int MinFontSize { get => _o.MinFontSize; set { _o.MinFontSize = value; _o.FitLabelText(); } }
        public int MaxFontSize { get => _o.MaxFontSize; set { _o.MaxFontSize = value; _o.FitLabelText(); } }
        public int FixedFontSize { get => _o.FixedFontSize; set { _o.FixedFontSize = value; _o.RequestRefresh(false, false, true); } }
        public bool AutoSize { get => _o.EnableTextAutoSize; set { _o.EnableTextAutoSize = value; } }
        public HorizontalAlignment HAlign { get => _o.LabelHorizontalAlignment; set { _o.LabelHorizontalAlignment = value; _o.RequestRefresh(false, false, false); } }
        public VerticalAlignment VAlign { get => _o.LabelVerticalAlignment; set { _o.LabelVerticalAlignment = value; _o.RequestRefresh(false, false, false); } }
        public Vector2 Padding { get => _o.LabelPadding; set { _o.LabelPadding = value; _o.RequestRefresh(false, false, true); } }
        public float PadLeft { get => _o.LabelAdditionalPaddingLeft; set { _o.LabelAdditionalPaddingLeft = value; _o.RequestRefresh(false, false, true); } }
        public float PadTop { get => _o.LabelAdditionalPaddingTop; set { _o.LabelAdditionalPaddingTop = value; _o.RequestRefresh(false, false, true); } }
        public float PadRight { get => _o.LabelAdditionalPaddingRight; set { _o.LabelAdditionalPaddingRight = value; _o.RequestRefresh(false, false, true); } }
        public float PadBottom { get => _o.LabelAdditionalPaddingBottom; set { _o.LabelAdditionalPaddingBottom = value; _o.RequestRefresh(false, false, true); } }
        public TextServer.AutowrapMode Autowrap { get => _o.LabelAutowrap; set { _o.LabelAutowrap = value; _o.RequestRefresh(false, false, true); } }
        public bool BBCode
        {
            get => _o.LabelType == LabelTypeEnum.RichTextLabel;
            set { _o.LabelType = value ? LabelTypeEnum.RichTextLabel : LabelTypeEnum.Label; _o.RequestRefresh(false, false, false); }
        }
    }
    public sealed class IconAccessor
    {
        private readonly OmniButton _o;
        internal IconAccessor(OmniButton o) { _o = o; }
        public Texture2D? Texture { get => _o.IconTexture; set { _o.IconTexture = value; _o.RequestRefresh(false, false, false); } }
        public TextureRect.ExpandModeEnum ExpandMode { get => _o.IconExpandMode; set { _o.IconExpandMode = value; _o.RequestRefresh(false, false, false); } }
        public TextureRect.StretchModeEnum StretchMode { get => _o.IconStretchMode; set { _o.IconStretchMode = value; _o.RequestRefresh(false, false, false); } }
        public bool FlipH { get => _o.IconFlipH; set { _o.IconFlipH = value; _o.RequestRefresh(false, false, false); } }
        public bool FlipV { get => _o.IconFlipV; set { _o.IconFlipV = value; _o.RequestRefresh(false, false, false); } }
        public Color Modulate { get => _o.IconModulate; set { _o.IconModulate = value; _o.RequestRefresh(false, false, false); } }
    }
    public sealed class BackgroundAccessor
    {
        private readonly OmniButton _o;
        internal BackgroundAccessor(OmniButton o) { _o = o; }
        public BackgroundMode Mode { get => _o.BackgroundType; set { _o.BackgroundType = value; _o.RequestRefresh(false, false, false); } }
        public Texture2D? Texture { get => _o.BackgroundTexture; set { _o.BackgroundTexture = value; _o.RequestRefresh(false, false, false); } }
        public TextureRect.ExpandModeEnum ExpandMode { get => _o.BackgroundExpandMode; set { _o.BackgroundExpandMode = value; _o.RequestRefresh(false, false, false); } }
        public TextureRect.StretchModeEnum StretchMode { get => _o.BackgroundStretchMode; set { _o.BackgroundStretchMode = value; _o.RequestRefresh(false, false, false); } }
        public bool FlipH { get => _o.BackgroundFlipH; set { _o.BackgroundFlipH = value; _o.RequestRefresh(false, false, false); } }
        public bool FlipV { get => _o.BackgroundFlipV; set { _o.BackgroundFlipV = value; _o.RequestRefresh(false, false, false); } }
        public Color Modulate { get => _o.BackgroundModulate; set { _o.BackgroundModulate = value; _o.RequestRefresh(false, false, false); } }
    }
    public sealed class OverlayAccessor
    {
        private readonly OmniButton _o;
        internal OverlayAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.Selected; set { _o.Selected = value; _o.RequestRefresh(false, false, false); } }
        public Color Color { get => _o.SelectedColor; set { _o.SelectedColor = value; _o.RequestRefresh(false, false, false); } }
    }
    public sealed class PanelAccessor
    {
        private readonly OmniButton _o;
        internal PanelAccessor(OmniButton o) { _o = o; }
        public Color Modulate { get => _o.PanelModulate; set { _o.PanelModulate = value; _o.RequestRefresh(false, false, false); } }
        public string ThemeVariation { get => _o.PanelThemeVariation; set { _o.PanelThemeVariation = value; _o.ApplyPanelStyling(); _o.RequestRefresh(false, false, false); } }
        public StyleBox? PanelStyle { get => _o.PanelStyleBox; set { _o.PanelStyleBox = value; _o.ApplyPanelStyling(); _o.RequestRefresh(false, false, false); } }
    }
    public sealed class CooldownAccessor
    {
        private readonly OmniButton _o;
        internal CooldownAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.EnableCooldown; set { _o.EnableCooldown = value; _o.RequestRefresh(false, false, false); } }
        public float Duration { get => _o.CooldownDuration; set { _o.CooldownDuration = value; } }
        public CooldownTriggerEnum Trigger { get => _o.CooldownTrigger; set { _o.CooldownTrigger = value; } }
        public bool StartFilled { get => _o.CooldownStartFilled; set { _o.CooldownStartFilled = value; } }
        public Color Color { get => _o.CooldownColor; set { _o.CooldownColor = value; _o.RequestRefresh(false, false, false); } }
        public CooldownDirection Direction { get => _o.CooldownFillDirection; set { _o.CooldownFillDirection = value; } }
        public bool SuspendHoverScale { get => _o.SuspendHoverScaleDuringCooldown; set { _o.SuspendHoverScaleDuringCooldown = value; } }
        public bool AllowHoldDuring { get => _o.AllowHoldDuringCooldown; set { _o.AllowHoldDuringCooldown = value; } }
        public bool HideDuringChargeUp { get => _o.HideCooldownDuringHoldBuildUp; set { _o.HideCooldownDuringHoldBuildUp = value; } }
    }
    public sealed class ChargeUpAccessor
    {
        private readonly OmniButton _o;
        internal ChargeUpAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.EnableHoldBuildUp; set { _o.EnableHoldBuildUp = value; _o.RequestRefresh(false, false, false); } }
        public float Duration { get => _o.HoldDuration; set { _o.HoldDuration = value; } }
        public Color Color { get => _o.HoldFillColor; set { _o.HoldFillColor = value; _o.RequestRefresh(false, false, false); } }
        public CooldownDirection Direction { get => _o.HoldFillDirection; set { _o.HoldFillDirection = value; } }
    }
    #endregion
    private bool _pendingChildrenRefresh = false;
    private bool _pendingPanelStyling = false;
    private bool _pendingVisualRefresh = false;
    private bool _pendingFitLabel = false;
    private int _runtimeRefitFrames = 0;
    private void RequestRefresh(bool children, bool panelStyling, bool fitLabel)
    {
        if (children) _pendingChildrenRefresh = true;
        if (panelStyling) _pendingPanelStyling = true;
        _pendingVisualRefresh = true; // always re-apply visuals
        if (fitLabel) _pendingFitLabel = true;

        if (Engine.IsEditorHint())
        {
            // Apply immediately for editor responsiveness
            if (children) SetupChildren();
            if (panelStyling) ApplyPanelStyling();
            ApplyVisualState();
            if (fitLabel) FitLabelText();
            QueueRedraw();
        }
        else
        {
            // Runtime: ensure _Process runs to coalesce deferred updates
            SetProcess(true);
        }
    }
    [ExportCategory("Composition")]
    [Export]
    public bool ManagedDrawOnTop
    {
        get => _managedDrawOnTop;
        set { _managedDrawOnTop = value; PositionManagedRoot(); }
    }
    private bool _managedDrawOnTop = true;
    [ExportCategory("Debug")]
    [Export(PropertyHint.Enum, "Off,Basic")] public DebuggerLogMode DebuggerLog { get; set; } = DebuggerLogMode.Off;
    private void EnsureManagedRoot()
    {
        if (_managedRoot != null && IsInstanceValid(_managedRoot)) return;
        _managedRoot = new Control { Name = "_Managed" };
        AddChild(_managedRoot);
        EnsureFullRect(_managedRoot);
        _managedRoot.MouseFilter = MouseFilterEnum.Pass;
        PositionManagedRoot();
    }
    private void PositionManagedRoot()
    {
        if (_managedRoot == null || !IsInstanceValid(_managedRoot)) return;
        var count = GetChildCount();
        int idx = _managedDrawOnTop ? Math.Max(0, count - 1) : 0;
        MoveChild(_managedRoot, idx);
    }
    private void ManagedAddChild(Control node)
    {
        EnsureManagedRoot();
        _managedRoot!.AddChild(node);
    }

    /// <summary>Reparents a legacy <c>Overlay</c> that was a direct child of OmniButton onto <c>_Managed</c> (one-time migration).</summary>
    private void EnsureOverlayUnderManagedRoot()
    {
        if (_overlay == null || !IsInstanceValid(_overlay)) return;
        if (_overlay.GetParent() == _managedRoot) return;
        if (_overlay.GetParent() != this) return;
        EnsureManagedRoot();
        RemoveChild(_overlay);
        _managedRoot!.AddChild(_overlay);
        EnsureFullRect(_overlay);
        _overlay.MouseFilter = MouseFilterEnum.Pass;
    }

    /// <summary>Creates a control under <c>_Managed</c> (same layer as Panel/Icon/Label). Do not use for user decorations.</summary>
    private T CreateManagedChildAtPosition<T>(string name, int position) where T : Control, new()
    {
        EnsureManagedRoot();
        var node = new T
        {
            Name = name,
            MouseFilter = MouseFilterEnum.Ignore
        };
        _managedRoot!.AddChild(node);
        var count = _managedRoot.GetChildCount();
        var dest = Mathf.Clamp(position, 0, Mathf.Max(0, count - 1));
        _managedRoot.MoveChild(node, dest);
        node.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        node.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        node.SizeFlagsVertical = SizeFlags.ExpandFill;
        return node;
    }

    #region Godot Lifecycle
    public override void _EnterTree() => Initialize();
    public override void _ExitTree() => Cleanup();
    public override void _Ready() => Setup();
    public override void _Process(double delta)
    {
        if (Engine.IsEditorHint())
            EditorPollTick(delta);

        if (_pendingChildrenRefresh || _pendingPanelStyling || _pendingVisualRefresh || _pendingFitLabel)
        {
            if (_pendingChildrenRefresh)
            {
                SetupChildren();
                _pendingChildrenRefresh = false;
            }
            if (_pendingPanelStyling)
            {
                ApplyPanelStyling();
                _pendingPanelStyling = false;
            }
            if (_pendingVisualRefresh)
            {
                ApplyVisualState();
                _pendingVisualRefresh = false;
            }
            if (_pendingFitLabel)
            {
                FitLabelText();
                _pendingFitLabel = false;
            }
        }

        if (!Engine.IsEditorHint() && _runtimeRefitFrames > 0)
        {
            _runtimeRefitFrames--;
            _fitCacheSig = string.Empty;
            FitLabelText();
        }

        ProcessHoverScaling(delta);

        if (_twActive)
            ProcessTypewriter(delta);

        TryStopProcessWhenFullyIdle();
    }

    /// <summary>Runtime only: stop <see cref="_Process"/> when no subsystem still needs per-frame ticks.</summary>
    private void TryStopProcessWhenFullyIdle()
    {
        if (Engine.IsEditorHint()) return;
        if (_pendingChildrenRefresh || _pendingPanelStyling || _pendingVisualRefresh || _pendingFitLabel) return;
        if (_runtimeRefitFrames > 0) return;
        if (_twActive || _cooldownDelayPending) return;
        if (EnableCooldown && _cooldownActive) return;
        if (_isPressed && (!EnableCooldown || !_cooldownActive || AllowHoldDuringCooldown || EnableHoldBuildUp)) return;
        if (HoverScaleAnimationPending()) return;
        SetProcess(false);
    }
    public override Array<Dictionary> _GetPropertyList() => BuildPropertyList();

    // Ensure we observe mouse releases even if they occur off-bounds


    public override void _Notification(int what)
    {
        switch (what)
        {
            case (int)NotificationResized:
                FitLabelText();
                if (BackgroundType == BackgroundMode.UsePanel) QueueRedraw();
                if (_defaultThumb != null && IsInstanceValid(_defaultThumb))
                    UpdateDefaultThumbVisual();
                if (_isHovering && EnableHoverScale)
                {
                    UpdateHoverPivotOffsets();
                    _hoverTargetScale = HoverTargetForViewport();
                    SetProcess(true);
                }
                break;
            case (int)NotificationThemeChanged:
                if (Theme != null)
                    ApplyThemeToChildren();
                _lastVisualState = null;
                ApplyThemeNow();
                ApplyPanelStyling();
                FitLabelText();
                if (_defaultThumb != null && IsInstanceValid(_defaultThumb))
                    UpdateDefaultThumbVisual();
                if (_isHovering && EnableHoverScale)
                {
                    _hoverTargetScale = HoverTargetForViewport();
                    SetProcess(true);
                }
                break;
            case (int)NotificationVisibilityChanged:
                if (!IsVisibleInTree())
                {
                    ResetPressState(emitSwipeEnded: true);
                    _isHovering = false;
                    InvalidateVisualState();
                }
                break;
            case (int)NotificationTransformChanged:
                if (_isHovering && EnableHoverScale)
                {
                    UpdateHoverPivotOffsets();
                    _hoverTargetScale = HoverTargetForViewport();
                    SetProcess(true);
                }
                FitLabelText();
                break;
            case (int)NotificationPredelete:
                Cleanup();
                break;
        }
        if (Engine.IsEditorHint())
        {
            // EditorSettingsChanged = 1001, PostEnterTree = 13, ThemeChanged = 1008, Resized = 40
            if (what == 1001 || what == 13 || what == 1008 || what == 40)
            {
                SetupChildren();
                ApplyVisualState();
                FitLabelText();
                if (_defaultThumb != null && IsInstanceValid(_defaultThumb))
                    UpdateDefaultThumbVisual();
                if (EnableHoverScale)
                    UpdateHoverPivotOffsets();
            }
        }
        // Also handle runtime resizing
        if (what == 40) // NotificationResized
        {
            FitLabelText();
            if (EnableHoverScale)
                UpdateHoverPivotOffsets();
        }
    }
    #endregion
    #region "Initialization & Cleanup"
    private void Initialize()
    {
        InitializeCallables();
        if (!Engine.IsEditorHint()) ConnectSignals();
        ConnectMouseEvents();
    }
    private void Setup()
    {
        MouseFilter = MouseFilterEnum.Stop;
        _isSelected = Selected;
        _isToggled = IsToggled;
        _isPressed = IsPressed;
        _isHovering = IsHovering;
        _isHolding = IsHolding;
        // Seed action mask once at runtime to reflect any early external connections
        AutoEnableActionsFromConnectionsOnce();
        if (Selected && BackgroundType == BackgroundMode.None)
            BackgroundType = BackgroundMode.UsePanel;
        var shaderPath = "res://addons/omni_button/Shader/InvertColor.tres";
        if (ResourceLoader.Exists(shaderPath))
            _invertMaterial = GD.Load<ShaderMaterial>(shaderPath);
        SetupChildren();
        ApplyPanelStyling();
        ApplyVisualState();
        FitLabelText();
        // Runtime layout settles one frame after Ready; ensure we refit once anchors/size finalize.
        CallDeferred(nameof(FitLabelText));
        if (!Engine.IsEditorHint())
            _runtimeRefitFrames = 4;
        // Optionally hide the control until a virtual joystick session starts (runtime only)
        if (!Engine.IsEditorHint() && EnableVirtualJoystick && JoystickHideWhenInactive)
            Visible = false;

        // Initialize ergonomic accessors
        Label = new LabelAccessor(this);
        Icon = new IconAccessor(this);
        Background = new BackgroundAccessor(this);
        Panel = new PanelAccessor(this);
        Overlay = new OverlayAccessor(this);
        Cooldown = new CooldownAccessor(this);
        ChargeUp = new ChargeUpAccessor(this);
    }
    private void Cleanup()
    {
        DisconnectAllSignalHandlers();
        _label = null;
        _richLabel = null;
        _icon = null;
        _overlay = null;
        _cooldown = null;
        _holdFill = null;
        if (_panel != null && IsInstanceValid(_panel))
        {
            var pp = _panel.GetParent();
            if (pp == this || pp == _managedRoot)
            {
                pp.RemoveChild(_panel);
                _panel.QueueFree();
            }
        }
        _panel = null;
        if (_defaultThumb != null && IsInstanceValid(_defaultThumb) && _defaultThumb.GetParent() == this)
        {
            RemoveChild(_defaultThumb);
            _defaultThumb.QueueFree();
        }
        _defaultThumb = null;
        if (_vjAreaPanel != null && IsInstanceValid(_vjAreaPanel) && _vjAreaPanel.GetParent() == this)
        {
            RemoveChild(_vjAreaPanel);
            _vjAreaPanel.QueueFree();
        }
        _vjAreaPanel = null;
    }
    #endregion

    #region Mouse Events
    private void OnPressed()
    {
        if (Disabled) return;
        _isPressed = true;
        InvalidateVisualState();
        GrabFocus();
        if ((ActionMask & ActionMaskFlags.Pressed) != 0)
        {
            EmitSignal(SignalName.Pressed);
            DebugLog("Pressed signal emitted (OnPressed)");
        }
        else DebugLog("Pressed skipped (OnPressed ActionMask)");
    }
    private void OnReleased()
    {
        if (Disabled) return;
        if ((ActionMask & ActionMaskFlags.Released) != 0)
        {
            EmitSignal(SignalName.Released);
            DebugLog("Released signal emitted (OnReleased)");
        }
        else DebugLog("Released skipped (OnReleased ActionMask)");
    }
    private void OnLog(string type, string message)
    {
        EmitSignal(SignalName.Log, type, message);
        DebugLog($"Log emitted type={type} message='{message}'");
    }
    private void OnMouseEntered()
    {
        if (Disabled) return;
        _isHovering = true;
        // Initialize hover-based swipe origin if enabled
        if (MouseSwipeInit == SwipeInitMode.OnHoverIn)
        {
            var gp = GetGlobalMousePosition();
            _swipeOrigin = gp;
            // Do not mark swiping yet; wait for movement over threshold
            if (_swipeStart == Vector2.Zero)
                _swipeStart = gp;
        }
        if ((ActionMask & ActionMaskFlags.Hover) != 0)
        {
            EmitSignal(SignalName.HoverIn);
            DebugLog("HoverIn emitted");
        }
        if (EnableHoverScale)
        {
            if (!(EnableCooldown && _cooldownActive && SuspendHoverScaleDuringCooldown))
            {
                UpdateHoverPivotOffsets();
                _hoverTargetScale = HoverTargetForViewport();
                EnableHoverTopLevel(true);
            }
            SetProcess(true);
        }
        InvalidateVisualState();
    }
    private void OnMouseExited()
    {
        if (Disabled) return;
        _isHovering = false;
        if ((ActionMask & ActionMaskFlags.Hover) != 0)
        {
            EmitSignal(SignalName.HoverOut);
            DebugLog("HoverOut emitted");
        }
        if (MouseSwipeExit == SwipeExitMode.OnHoverOut)
        {
            EndSwiping();
        }
        if (EnableHoverScale)
        {
            if (!(EnableCooldown && _cooldownActive && SuspendHoverScaleDuringCooldown))
            {
                UpdateHoverPivotOffsets();
                _hoverTargetScale = 1.0f;
            }
            SetProcess(true);
        }
        InvalidateVisualState();
    }
    #endregion
    #region Child Node Management
    internal void SetupChildren()
    {
        // In editor, duplicated nodes may carry serialized managed children (Icon/Label/etc.)
        // which causes stacked visuals when properties change. Proactively clean any
        // pre-existing managed children by name so we rebuild a single correct set.
        try
        {
            EnsureManagedRoot();
            void PurgeChildren(Node parent)
            {
                if (parent == null || !IsInstanceValid(parent)) return;
                _setupChildrenPurgeScratch.Clear();
                foreach (var child in parent.GetChildren())
                {
                    if (child is Node n && n.Name != null && ManagedChildNamesForPurge.Contains(n.Name))
                        _setupChildrenPurgeScratch.Add(n);
                }
                foreach (var n in _setupChildrenPurgeScratch)
                {
                    var p = n.GetParent();
                    p?.RemoveChild(n);
                    n.QueueFree();
                }
            }
            PurgeChildren(this);
            if (_managedRoot != null && IsInstanceValid(_managedRoot))
                PurgeChildren(_managedRoot);
        }
        catch (System.Exception ex)
        {
            if (Engine.IsEditorHint())
                GD.PushError($"OmniButton '{Name}': SetupChildren purge failed: {ex.Message}");
            if (DebuggerLog != DebuggerLogMode.Off)
                GD.PrintErr($"[OmniButton:{Name}] SetupChildren purge: {ex}");
        }
        // Free only managed children; leave user-added nodes intact
        void FreeNode(Node? n)
        {
            if (n == null || !IsInstanceValid(n)) return;
            var parent = n.GetParent();
            if (parent == null) { n.QueueFree(); return; }
            // Only remove if parent is this control or the managed root container
            if (ReferenceEquals(parent, this) || (ReferenceEquals(parent, _managedRoot)))
            {
                parent.RemoveChild(n);
                n.QueueFree();
            }
        }
        FreeNode(_panel);
        FreeNode(_background);
        FreeNode(_icon);
        FreeNode(_label);
        FreeNode(_richLabel);
        FreeNode(_overlay);
        FreeNode(_cooldown);
        FreeNode(_holdFill);
        FreeNode(_defaultThumb);
        FreeNode(_vjAreaPanel);
        // Clear cached references so they are recreated correctly
        _panel = null;
        _icon = null;
        _label = null;
        _richLabel = null;
        _overlay = null;
        _cooldown = null;
        _holdFill = null;
        _background = null;
        _defaultThumb = null;
        _vjAreaPanel = null;
        // 0 - Panel (background)
        if (BackgroundType == BackgroundMode.UsePanel)
        {
            _panel = new Panel { Name = "Panel" };
            ManagedAddChild(_panel);
            ConfigurePanel(_panel);
            EnsureFullRect(_panel);
        }

        // 0b - Background Texture (full-rect)
        if (BackgroundType == BackgroundMode.UseTexture && BackgroundTexture != null)
        {
            _background = new TextureRect
            {
                Name = "Background",
                Texture = BackgroundTexture,
                ExpandMode = BackgroundExpandMode,
                StretchMode = BackgroundStretchMode,
                FlipH = BackgroundFlipH,
                FlipV = BackgroundFlipV
            };
            _background.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
            ManagedAddChild(_background);
            EnsureFullRect(_background);
        }
        // 1 - Icon
        if (IconTexture != null)
        {
            _icon = new TextureRect
            {
                Name = "Icon",
                Texture = IconTexture,
                ExpandMode = IconExpandMode,
                StretchMode = IconStretchMode,
                FlipH = IconFlipH,
                FlipV = IconFlipV
            };
            _icon.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
            ManagedAddChild(_icon);
            EnsureFullRect(_icon);
        }
        // 2 - Label (prefer RichTextLabel based on LabelType or active typewriter)
        bool wantRichChild = (_labelType == LabelTypeEnum.RichTextLabel) || _twBBCodeAware || !string.IsNullOrEmpty(_richLabelText);
        bool wantPlainChild = (_labelType == LabelTypeEnum.Label) || !string.IsNullOrEmpty(_labelText);
        if (wantRichChild)
        {
            _richLabel = new RichTextLabel { Name = "RichLabel" };
            _richLabel.ScrollActive = false;
            _richLabel.BbcodeEnabled = true;
            _richLabel.MouseFilter = MouseFilterEnum.Pass;
            ManagedAddChild(_richLabel);
            _richLabel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            ApplyLabelPaddingOffsets(_richLabel);
        }
        else if (wantPlainChild)
        {
            _label = new Label { Name = "Label", Text = _labelText };
            ManagedAddChild(_label);
            ConfigureLabel();
        }
        // 3 - Default thumb for virtual joystick if no icon is provided
        bool wantVJ = (FollowMode == FollowModeEnum.VirtualJoystick) || EnableVirtualJoystick;
        bool needDefaultThumb = wantVJ && EnableDefaultThumb && IconTexture == null;
        if (needDefaultThumb)
        {
            EnsureDefaultThumb();
            UpdateDefaultThumbVisual();
        }
        // 4 - Selected Overlay
        UpdateOverlay();
        // 5 - Cooldown (create if enabled in editor or active at runtime)
        if (EnableCooldown && (_cooldownActive || Engine.IsEditorHint()))
        {
            EnsureCooldown();
            UpdateCooldownVisual();
        }
        ReorderChildren();
        if (_panel != null) _panel.MouseFilter = MouseFilterEnum.Pass;
        if (_background != null) _background.MouseFilter = MouseFilterEnum.Pass;
        if (_icon != null) _icon.MouseFilter = MouseFilterEnum.Pass;
        if (_label != null) _label.MouseFilter = MouseFilterEnum.Pass;
        if (_richLabel != null) _richLabel.MouseFilter = MouseFilterEnum.Pass;
        if (_overlay != null) _overlay.MouseFilter = MouseFilterEnum.Pass;
        if (_cooldown != null) _cooldown.MouseFilter = MouseFilterEnum.Pass;
        if (_holdFill != null) _holdFill.MouseFilter = MouseFilterEnum.Pass;
        ApplyPanelStyling();
    }
    private void UpdateOverlay()
    {
        EnsureOverlayUnderManagedRoot();
        bool needOverlay = _isSelected;
        bool overlayAlive = _overlay != null && IsInstanceValid(_overlay) && _overlay.GetParent() == _managedRoot;
        if (needOverlay && !overlayAlive)
        {
            _overlay = new ColorRect { Name = "Overlay", Color = SelectedColor };
            ManagedAddChild(_overlay);
            EnsureFullRect(_overlay);
        }
        else if (!needOverlay && overlayAlive)
        {
            var overlay = _overlay;
            if (overlay != null && IsInstanceValid(overlay))
            {
                var parent = overlay.GetParent(); parent?.RemoveChild(overlay); overlay.QueueFree();
            }
            _overlay = null;
        }
    }
    private void EnsureHoldFill()
    {
        if (_holdFill == null || !IsInstanceValid(_holdFill))
        {
            _holdFill = new ColorRect { Name = "HoldFill", Color = HoldFillColor, ZIndex = 6 };
            _holdFill.MouseFilter = MouseFilterEnum.Pass;
            ManagedAddChild(_holdFill);
            // Use manual sizing/positioning; do NOT anchor full-rect
            _holdFill.SetAnchorsAndOffsetsPreset(LayoutPreset.TopLeft);
        }
    }
    private void RemoveHoldFill()
    {
        if (_holdFill != null && IsInstanceValid(_holdFill))
        {
            // Reset to initial hidden state for reuse later
            _holdFill.Visible = false;
            _holdFill.Size = Vector2.Zero;
            _holdFill.Position = Vector2.Zero;
        }
    }
    private void EnsureFullRect(Control node)
    {
        if (node == null || !IsInstanceValid(node)) return;
        node.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        node.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        node.SizeFlagsVertical = SizeFlags.ExpandFill;
    }
    private void ReorderChildren()
    {
        var parent = (_managedRoot != null && IsInstanceValid(_managedRoot)) ? _managedRoot! : this;
        int idx = 0;
        bool Alive(Control? n) => n != null && IsInstanceValid(n) && n.GetParent() == parent;
        if (Alive(_panel)) parent.MoveChild(_panel!, idx++);
        if (Alive(_background)) parent.MoveChild(_background!, idx++);
        if (Alive(_icon)) parent.MoveChild(_icon!, idx++);
        else if (Alive(_defaultThumb)) parent.MoveChild(_defaultThumb!, idx++);
        if (Alive(_label)) parent.MoveChild(_label!, idx++);
        else if (Alive(_richLabel)) parent.MoveChild(_richLabel!, idx++);
        if (Alive(_overlay)) parent.MoveChild(_overlay!, idx++);
        if (Alive(_cooldown)) parent.MoveChild(_cooldown!, idx++);
        if (Alive(_holdFill)) parent.MoveChild(_holdFill!, idx++);
    }
    #endregion
    #region Label Font Sizing
    private string _fitCacheSig = string.Empty;

    /// <summary>Cache key must follow the string actually drawn (typewriter updates the label, not <see cref="_text"/>).</summary>
    private string TextForFitSignature()
    {
        if (_richLabel != null && IsInstanceValid(_richLabel))
            return _richLabel.Text ?? string.Empty;
        if (_label != null && IsInstanceValid(_label))
            return _label.Text ?? string.Empty;
        return _text ?? string.Empty;
    }

    private void ConfigureLabel()
    {
        if (_label == null) return;
        _label.HorizontalAlignment = LabelHorizontalAlignment;
        _label.VerticalAlignment = LabelVerticalAlignment;
        _label.AutowrapMode = LabelAutowrap;
        _label.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
        ApplyLabelPaddingOffsets(_label);
        if (LabelFont != null)
            _label.AddThemeFontOverride("font", LabelFont);
    }
    /// <summary>Runtime: queue autosize for the next frame (coalesces with ApplyVisualState). Editor: fit immediately.</summary>
    private void ScheduleFitLabel()
    {
        if (Engine.IsEditorHint())
            FitLabelText();
        else
        {
            _pendingFitLabel = true;
            SetProcess(true);
        }
    }

    internal void FitLabelText()
    {
        var sigText = TextForFitSignature();
        var __sig = $"{sigText}|{Size}|{_labelPadding}|{_labelPadLeft},{_labelPadTop},{_labelPadRight},{_labelPadBottom}|{_labelAutowrap}|{FixedFontSize}|{_labelType}";
        if (_fitCacheSig == __sig) return;
        DebugLog($"Autosize begin size={Size} type={LabelType} wrap={LabelAutowrap} text='{sigText}'");
        // Fixed font size takes precedence regardless of auto-size
        if (FixedFontSize > 0)
        {
            if (_label != null && IsInstanceValid(_label))
            {
                _label.AddThemeFontSizeOverride("font_size", FixedFontSize);
                _label.UpdateMinimumSize();
            }
            if (_richLabel != null && IsInstanceValid(_richLabel))
            {
                ApplyRichLabelFontSizeOnly(FixedFontSize);
            }
            _fitCacheSig = __sig;
            return;
        }
        if (!EnableTextAutoSize) return;
        if (_fittingLabel) return;
        bool didFit = false;
        if (_richLabel != null && IsInstanceValid(_richLabel) && !string.IsNullOrEmpty(_richLabel.Text))
        {
            didFit = FitRichTextLabel();
        }
        else if (_label != null && IsInstanceValid(_label) && !string.IsNullOrEmpty(_label.Text))
        {
            didFit = FitPlainLabel();
        }

        if (didFit)
            _fitCacheSig = __sig;
        else
            _fitCacheSig = string.Empty;
    }

    // Keep Label and RichTextLabel sizing separate so Label remains stable while we iterate on RichText
    private bool FitPlainLabel()
    {
        _fittingLabel = true;
        try
        {
            bool wrapEnabled = LabelAutowrap != TextServer.AutowrapMode.Off;
            var avail = CalculateAvailableArea();
            if (DebuggerLog != DebuggerLogMode.Off)
            {
                string dbgText = (_label != null && IsInstanceValid(_label)) ? (_label.Text ?? string.Empty) : (_text ?? string.Empty);
                DebugLog($"Autosize plain start avail={avail} wrapEnabled={wrapEnabled} autowrap={LabelAutowrap} text='{dbgText.Replace("\n", "\\n")}' size={Size}");
            }
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                CallDeferred(nameof(FitPlainLabel));
                return false;
            }
            if (_label is not Label label || !IsInstanceValid(label))
            {
                return false;
            }
            var fnt = GetRobustFont(label);
            if (fnt == null) return false;
            float wrap = (LabelAutowrap != TextServer.AutowrapMode.Off) ? avail.X : -1f;
            string text = label.Text ?? string.Empty;
            // Fast-path: try last font size first; if overflow, decrement a few steps, else full search
            if (_lastFitFontSize > 0)
            {
                var sz0 = MeasureParagraph(fnt, text, wrap, _lastFitFontSize);
                if (FitsWithin(sz0, avail, wrapEnabled))
                {
                    int grown = GrowFontSize(fnt, text, avail, wrap, wrapEnabled, _lastFitFontSize);
                    ApplyFontSettings(label, fnt, grown);
                    label.UpdateMinimumSize();
                    label.QueueRedraw();
                    _lastFitFontSize = grown;
                    return true;
                }
                int s = _lastFitFontSize;
                int guard0 = 0;
                while (s > MinFontSize && guard0 < 16)
                {
                    s--;
                    var sz1 = MeasureParagraph(fnt, text, wrap, s);
                    if (FitsWithin(sz1, avail, wrapEnabled))
                    {
                        ApplyFontSettings(label, fnt, s);
                        label.UpdateMinimumSize();
                        label.QueueRedraw();
                        _lastFitFontSize = s;
                        return true;
                    }
                    guard0++;
                }
            }
            int bestSize = FindBestFontSize(fnt, text, avail, wrap, wrapEnabled);
            bestSize = GrowFontSize(fnt, text, avail, wrap, wrapEnabled, bestSize);
            ApplyFontSettings(label, fnt, bestSize);
            label.UpdateMinimumSize();
            label.QueueRedraw();
            int guard2 = 0;
            while (bestSize > MinFontSize && guard2 < 64)
            {
                var sz = MeasureParagraph(fnt, text, wrap, bestSize);
                if (FitsWithin(sz, avail, wrapEnabled)) break;
                bestSize--;
                ApplyFontSettings(label, fnt, bestSize);
                label.UpdateMinimumSize();
                label.QueueRedraw();
                guard2++;
            }
            _lastFitFontSize = bestSize;
            DebugLog($"Autosize plain fitted size={bestSize} wrap={wrap} avail={avail}");
            return true;
        }
        finally { _fittingLabel = false; }
    }

    private int _richCurrentFontSize = -1;
    private int _richVerifyPasses = 0;
    // Cache of last chosen font size to accelerate incremental append cases
    private int _lastFitFontSize = -1;
    // Typewriter support
    private bool _twActive = false;
    private bool _twByWord = false;
    private float _twCps = 30f;
    private double _twAccum = 0.0;
    private string _twFinalText = string.Empty;
    private int _twIndex = 0;
    private System.Collections.Generic.List<string>? _twTokens = null;
    private System.Text.StringBuilder? _twBuilder = null;
    private bool FitRichTextLabel()
    {
        _fittingLabel = true;
        try
        {
            bool wrapEnabled = LabelAutowrap != TextServer.AutowrapMode.Off;
            var avail = CalculateAvailableArea();
            DebugLog($"Autosize rich start avail={avail} wrapEnabled={wrapEnabled} text='{(_richLabel!.Text ?? string.Empty).Replace("\n", "\\n")}'");
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                CallDeferred(nameof(FitRichTextLabel));
                return false;
            }
            var fnt = LabelFont ?? ThemeDB.FallbackFont;
            if (fnt == null) return false;
            var rtl = _richLabel;
            if (rtl == null || !IsInstanceValid(rtl)) return false;
            string plain = StripKnownBBCode(rtl.Text ?? string.Empty);
            float wrap = (LabelAutowrap != TextServer.AutowrapMode.Off) ? avail.X : -1f;
            // Fast-path: try current cached size first; if overflow, decrement a few steps
            int seed = _richCurrentFontSize > 0 ? _richCurrentFontSize : _lastFitFontSize;
            if (seed > 0)
            {
                var sz0 = MeasureParagraph(fnt, plain, wrap, seed);
                if (FitsWithin(sz0, avail, wrapEnabled))
                {
                    int grown = GrowFontSize(fnt, plain, avail, wrap, wrapEnabled, seed);
                    ApplyRichLabelFontOverrides(rtl, fnt, grown);
                    rtl.UpdateMinimumSize();
                    rtl.QueueRedraw();
                    _richCurrentFontSize = grown;
                    _lastFitFontSize = grown;
                    return true;
                }
                int s = seed;
                int guard0 = 0;
                while (s > MinFontSize && guard0 < 16)
                {
                    s--;
                    var sz1 = MeasureParagraph(fnt, plain, wrap, s);
                    if (FitsWithin(sz1, avail, wrapEnabled))
                    {
                        ApplyRichLabelFontOverrides(rtl, fnt, s);
                        rtl.UpdateMinimumSize();
                        rtl.QueueRedraw();
                        _richCurrentFontSize = s;
                        _lastFitFontSize = s;
                        return true;
                    }
                    guard0++;
                }
            }
            int best = FindBestFontSize(fnt, plain, avail, wrap, wrapEnabled);
            best = GrowFontSize(fnt, plain, avail, wrap, wrapEnabled, best);
            ApplyRichLabelFontOverrides(rtl, fnt, best);
            rtl.UpdateMinimumSize();
            rtl.QueueRedraw();
            _richCurrentFontSize = best;
            // Quick clamp pass
            int guard = 0;
            while (best > MinFontSize && guard < 32)
            {
                var overH = RichHeightExceedsAvail(avail.Y, fnt, plain, wrap, best);
                var sz = MeasureParagraph(fnt, plain, wrap, best);
                var overW = !FitsWithin(sz, avail, wrapEnabled) && sz.X > avail.X;
                if (!overH && !overW) break;
                best--;
                ApplyRichLabelFontOverrides(rtl, fnt, best);
                rtl.UpdateMinimumSize();
                rtl.QueueRedraw();
                _richCurrentFontSize = best;
                guard++;
            }
            _lastFitFontSize = _richCurrentFontSize;
            DebugLog($"Autosize rich fitted size={_richCurrentFontSize} wrap={wrap} avail={avail}");
            // Deferred verification to allow layout to settle
            _richVerifyPasses = 0;
            CallDeferred(nameof(VerifyRichTextFit));
            return true;
        }
        finally { _fittingLabel = false; }
    }

    private void VerifyRichTextFit()
    {
        if (_richLabel == null || !IsInstanceValid(_richLabel)) return;
        var avail = CalculateAvailableArea();
        // Small safety margin for padding/layout differences
        avail = new Vector2(Mathf.Max(1, avail.X - 2), Mathf.Max(1, avail.Y - 2));
        if (avail.X <= 1.0f || avail.Y <= 1.0f) return;
        var fnt = LabelFont ?? ThemeDB.FallbackFont;
        if (fnt == null) return;
        string plain = StripKnownBBCode(_richLabel.Text ?? string.Empty);
        bool wrapEnabled = LabelAutowrap != TextServer.AutowrapMode.Off;
        float wrap = wrapEnabled ? avail.X : -1f;
        int size = _richCurrentFontSize > 0 ? _richCurrentFontSize : MinFontSize;
        int guard = 0;
        // Ensure latest layout info
        _richLabel.UpdateMinimumSize();
        _richLabel.QueueRedraw();
        while (size > MinFontSize && guard < 64)
        {
            bool overH = RichHeightExceedsAvail(avail.Y, fnt, plain, wrap, size);
            var measured = MeasureParagraph(fnt, plain, wrap, size);
            bool overW = !FitsWithin(measured, avail, wrapEnabled);
            if (!overH && !overW) break;
            size--;
            ApplyRichLabelFontOverrides(_richLabel, fnt, size);
            _richLabel.UpdateMinimumSize();
            _richLabel.QueueRedraw();
            _richCurrentFontSize = size;
            guard++;
        }
        // If still overflowing (layout not settled), retry next frame with a cap on passes
        bool stillOver = RichHeightExceedsAvail(avail.Y, fnt, plain, wrap, size) || !FitsWithin(MeasureParagraph(fnt, plain, wrap, size), avail, wrapEnabled);
        if (stillOver && _richVerifyPasses < 8)
        {
            _richVerifyPasses++;
            CallDeferred(nameof(VerifyRichTextFit));
        }
        else
        {
            _lastFitFontSize = _richCurrentFontSize;
        }
    }

    /// <summary>Prefer RichTextLabel layout height when ready; otherwise TextParagraph (same frame as fit).</summary>
    private bool RichHeightExceedsAvail(float availY, Font font, string plain, float wrapWidth, int sizePx)
    {
        if (_richLabel == null || !IsInstanceValid(_richLabel)) return false;
        float gh = _richLabel.GetContentHeight();
        if (gh > 0.5f) return gh > availY;
        return MeasureParagraph(font, plain, wrapWidth, sizePx).Y > availY;
    }

    private void ApplyRichLabelFontSizeOnly(int fontSize)
    {
        if (_richLabel == null || !IsInstanceValid(_richLabel)) return;
        foreach (var key in new[] { "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size" })
            _richLabel.AddThemeFontSizeOverride(key, fontSize);
        _richLabel.UpdateMinimumSize();
    }
    private Vector2 CalculateAvailableArea()
    {
        var pad = TextFitPadding;
        GetEffectiveLabelPadding(out float l, out float t, out float r, out float b);
        float horiz = Mathf.Max(0, pad.X) + Mathf.Max(0, l) + Mathf.Max(0, r);
        float vert = Mathf.Max(0, pad.Y) + Mathf.Max(0, t) + Mathf.Max(0, b);
        return new Vector2(Mathf.Max(1, Size.X - horiz), Mathf.Max(1, Size.Y - vert));
    }
    private Font? GetRobustFont(Label label)
    {
        return label.GetThemeFont("font") ?? ThemeDB.FallbackFont;
    }
    private int FindBestFontSize(Font font, string text, Vector2 availableArea, float wrapWidth, bool wrapEnabled)
    {
        int lo = MinFontSize;
        int hi = MaxFontSize;
        int best = lo;
        while (lo <= hi)
        {
            int mid = (lo + hi) / 2;
            var textSize = MeasureParagraph(font, text, wrapWidth, mid);
            if (FitsWithin(textSize, availableArea, wrapEnabled))
            {
                best = mid;
                lo = mid + 1; // try larger
            }
            else
            {
                hi = mid - 1; // too big
            }
        }
        return best;
    }

    private Vector2 MeasureParagraph(Font font, string text, float wrapWidth, int fontSize)
    {
        if (font == null) return Vector2.Zero;
        using var paragraph = new TextParagraph();
        paragraph.Alignment = LabelHorizontalAlignment;
        paragraph.Direction = TextServer.Direction.Auto;
        paragraph.Orientation = TextServer.Orientation.Horizontal;
        paragraph.JustificationFlags = TextServer.JustificationFlag.None;
        paragraph.BreakFlags = GetLineBreakFlagsForCurrentWrapMode();
        paragraph.Width = wrapWidth > 0f ? wrapWidth : 0f;
        paragraph.AddString(text ?? string.Empty, font, fontSize, default, default);
        var size = paragraph.GetSize();
        // Hot path: do not build the debug string unless Basic logging is on (matches DebugLog gate).
        if (!Engine.IsEditorHint() && DebuggerLog != DebuggerLogMode.Off)
            DebugLog($"Autosize measure wrapWidth={wrapWidth} fontSize={fontSize} size={size} text='{text?.Replace("\n", "\\n")}'");
        return size;
    }

    private int GrowFontSize(Font font, string text, Vector2 availableArea, float wrapWidth, bool wrapEnabled, int currentSize)
    {
        int lo = currentSize + 1;
        int hi = MaxFontSize;
        int best = currentSize;
        while (lo <= hi)
        {
            int mid = (lo + hi) / 2;
            var sz = MeasureParagraph(font, text, wrapWidth, mid);
            if (FitsWithin(sz, availableArea, wrapEnabled))
            {
                best = mid;
                lo = mid + 1;
            }
            else
            {
                hi = mid - 1;
            }
        }
        return best;
    }

    private TextServer.LineBreakFlag GetLineBreakFlagsForCurrentWrapMode()
    {
        // Removed TextServer.AutowrapMode.Char and Trim/TrimWord because they do not exist in this Godot version;
        // Arbitrary is used for grapheme (character) wrapping.
        return LabelAutowrap switch
        {
            TextServer.AutowrapMode.Word => TextServer.LineBreakFlag.WordBound,
            TextServer.AutowrapMode.WordSmart => TextServer.LineBreakFlag.WordBound | TextServer.LineBreakFlag.Adaptive,
            TextServer.AutowrapMode.Arbitrary => TextServer.LineBreakFlag.GraphemeBound,
            _ => TextServer.LineBreakFlag.None
        };
    }

    private bool FitsWithin(Vector2 measured, Vector2 available, bool wrapEnabled)
    {
        bool widthOk;
        if (wrapEnabled)
        {
            // When wrapping, allow a small epsilon to account for font metrics;
            // overflow beyond that means a truly unbreakable chunk.
            widthOk = measured.X <= available.X + 0.5f;
        }
        else
        {
            widthOk = measured.X <= available.X;
        }
        return widthOk && measured.Y <= available.Y;
    }

    // Remove only known BBCode tags; preserve bracketed literals like "[PressButton]"
    private static readonly System.Text.RegularExpressions.Regex BbcodeTagRegex =
        new(System.Text.RegularExpressions.Regex.Escape("[") + @"/?(b|i|u|s|code|url|color|center|left|right|p|br|wave|rainbow|tornado|pulse|shake|fade|font|img|table|cell|ol|ul|li|indent|quote)(=[^\]]+)?\]",
            System.Text.RegularExpressions.RegexOptions.IgnoreCase);

    private string StripKnownBBCode(string src)
    {
        if (string.IsNullOrEmpty(src)) return string.Empty;
        return BbcodeTagRegex.Replace(src, m =>
        {
            var v = m.Value.ToLower();
            // convert line/paragraph breaks to spaces for measurement
            if (v.StartsWith("[br") || v == "[br]" || v.StartsWith("[p") || v == "[p]")
                return " ";
            return string.Empty;
        });
    }
    #endregion
    #region Panel Styling
    internal void ApplyPanelStyling()
    {
        if (BackgroundType != BackgroundMode.UsePanel)
        {
            var panel = FindManagedPanelOrLegacy();
            if (panel != null)
            {
                panel.RemoveThemeStyleboxOverride("panel");
                panel.QueueRedraw();
            }
            return;
        }
        var panelNode = GetOrCreatePanel();
        // Inherit Theme from parent so project/scene theme also applies
        panelNode.Theme = null;
        // Use variation defined in your Theme under class "Panel"
        panelNode.ThemeTypeVariation = PanelThemeVariation ?? string.Empty;
        // Let the Theme define the style by default
        panelNode.RemoveThemeStyleboxOverride("panel");
        // Only hard-override if explicitly provided
        if (PanelStyleBox != null)
            panelNode.AddThemeStyleboxOverride("panel", PanelStyleBox);
        panelNode.QueueRedraw();
        if (Engine.IsEditorHint())
            QueueRedraw();
    }
    #region Cooldown
    public void StartCooldown()
    {
        if (!EnableCooldown) return;
        _cooldownActive = false;
        _cooldownElapsed = 0.0;
        _cooldownTimeLeft = 0.0;
        _cooldownDelayPending = CooldownStartDelay > 0.0f;
        _cooldownDelayLeft = CooldownStartDelay;
        DebugLog($"Cooldown scheduled delay={CooldownStartDelay} duration={CooldownDuration} trigger={CooldownTrigger}");
        if (_cooldown != null && IsInstanceValid(_cooldown))
        {
            _cooldown.Visible = false;
            _cooldown.Size = Vector2.Zero;
            _cooldown.Position = Vector2.Zero;
        }
        SetProcess(true);
        if (!_cooldownDelayPending)
            BeginCooldownNow();
    }
    private void BeginCooldownNow()
    {
        _cooldownActive = true;
        _cooldownElapsed = 0.0;
        _cooldownTimeLeft = CooldownDuration;
        DebugLog($"Cooldown started duration={CooldownDuration} trigger={CooldownTrigger}");
        EnsureCooldown();
        UpdateCooldownVisual();
        CallDeferred(nameof(ResetPressedVisualsAfterCooldownStart));
    }
    private void ResetPressedVisualsAfterCooldownStart()
    {
        // Clear pressed so invert-on-press reverts, but keep hover state
        // so invert-on-hover can continue to work during cooldown.
        ResetPressState(emitSwipeEnded: true);
        EnableHoverTopLevel(false);
        ApplyVisualState();
    }

    private void EnsureDefaultThumb()
    {
        if (_defaultThumb == null || !IsInstanceValid(_defaultThumb))
        {
            _defaultThumb = new Panel { Name = "DefaultThumb" };
            _defaultThumb.MouseFilter = MouseFilterEnum.Pass;
            _defaultThumb.ZIndex = 2;
            ManagedAddChild(_defaultThumb);
            var sb = new StyleBoxFlat();
            sb.BgColor = DefaultThumbColor;
            _defaultThumb.AddThemeStyleboxOverride("panel", sb);
        }
    }

    private void UpdateDefaultThumbVisual()
    {
        if (_defaultThumb == null || !IsInstanceValid(_defaultThumb)) return;
        float side = Math.Max(1f, Math.Min(Size.X, Size.Y) * DefaultThumbSizeRatio);
        _defaultThumb.SetAnchorsAndOffsetsPreset(LayoutPreset.TopLeft);
        _defaultThumb.Size = new Vector2(side, side);
        _defaultThumb.Position = (Size - _defaultThumb.Size) / 2f;
        _defaultThumb.ZIndex = 2;
        if (_defaultThumb.GetThemeStylebox("panel") is StyleBoxFlat flat)
        {
            int r = (int)Mathf.Round(side / 2f);
            flat.BgColor = DefaultThumbColor;
            flat.CornerRadiusTopLeft = flat.CornerRadiusTopRight = flat.CornerRadiusBottomLeft = flat.CornerRadiusBottomRight = r;
        }
    }

    private void ApplyLabelPaddingOffsets(Control node)
    {
        if (node == null || !IsInstanceValid(node)) return;
        GetEffectiveLabelPadding(out float l, out float t, out float r, out float b);
        node.AnchorLeft = 0f; node.AnchorTop = 0f; node.AnchorRight = 1f; node.AnchorBottom = 1f;
        node.OffsetLeft = Mathf.Max(0, l);
        node.OffsetTop = Mathf.Max(0, t);
        node.OffsetRight = -Mathf.Max(0, r);
        node.OffsetBottom = -Mathf.Max(0, b);
        if (Engine.IsEditorHint())
        {
            node.UpdateMinimumSize();
            node.QueueRedraw();
            QueueRedraw();
        }
    }

    private void GetEffectiveLabelPadding(out float left, out float top, out float right, out float bottom)
    {
        // Universal base padding (symmetric)
        float lr = _labelPadding.X;
        float tb = _labelPadding.Y;
        // Add per-side additional padding
        left = lr + _labelPadLeft;
        right = lr + _labelPadRight;
        top = tb + _labelPadTop;
        bottom = tb + _labelPadBottom;
    }

    /// <summary>
    /// True while pressed and the pointer has moved beyond SwipeThreshold from the press origin.
    /// Read-only runtime state for visual or logic cues; cleared on release/visibility change.
    /// </summary>
    public bool IsSwiping => _isSwiping;
    private void EnsureCooldown()
    {
        if (_cooldown == null || !IsInstanceValid(_cooldown))
        {
            _cooldown = new ColorRect { Name = "Cooldown", Color = CooldownColor, ZIndex = 5 };
            _cooldown.MouseFilter = MouseFilterEnum.Pass;
            ManagedAddChild(_cooldown);
        }
    }
    private void UpdateCooldownVisual()
    {
        if (!EnableCooldown) return;
        EnsureCooldown();
        if (_cooldown == null || !IsInstanceValid(_cooldown)) return;
        var total = Math.Max(0.0001f, CooldownDuration);
        float remaining = (float)Math.Max(0.0, _cooldownTimeLeft);
        float progress = (float)(1.0 - (remaining / total)); // 0 -> 1 over time
        var size = Size;
        switch (CooldownFillDirection)
        {
            case CooldownDirection.BottomToTop:
                {
                    if (CooldownStartFilled)
                    {
                        float h = size.Y * (1.0f - progress);
                        _cooldown.Size = new Vector2(size.X, h);
                        _cooldown.Position = new Vector2(0, 0);
                        _cooldown.Visible = h > 0.0f;
                    }
                    else
                    {
                        float h = size.Y * progress;
                        _cooldown.Size = new Vector2(size.X, h);
                        _cooldown.Position = new Vector2(0, size.Y - h);
                        _cooldown.Visible = h > 0.0f;
                    }
                    break;
                }
            case CooldownDirection.TopToBottom:
                {
                    if (CooldownStartFilled)
                    {
                        float h = size.Y * (1.0f - progress);
                        _cooldown.Size = new Vector2(size.X, h);
                        _cooldown.Position = new Vector2(0, size.Y - h);
                        _cooldown.Visible = h > 0.0f;
                    }
                    else
                    {
                        float h = size.Y * progress;
                        _cooldown.Size = new Vector2(size.X, h);
                        _cooldown.Position = new Vector2(0, 0);
                        _cooldown.Visible = h > 0.0f;
                    }
                    break;
                }
            case CooldownDirection.LeftToRight:
                {
                    if (CooldownStartFilled)
                    {
                        float w = size.X * (1.0f - progress);
                        _cooldown.Size = new Vector2(w, size.Y);
                        _cooldown.Position = new Vector2(size.X - w, 0);
                        _cooldown.Visible = w > 0.0f;
                    }
                    else
                    {
                        float w = size.X * progress;
                        _cooldown.Size = new Vector2(w, size.Y);
                        _cooldown.Position = new Vector2(0, 0);
                        _cooldown.Visible = w > 0.0f;
                    }
                    break;
                }
            case CooldownDirection.RightToLeft:
                {
                    if (CooldownStartFilled)
                    {
                        float w = size.X * (1.0f - progress);
                        _cooldown.Size = new Vector2(w, size.Y);
                        _cooldown.Position = new Vector2(0, 0);
                        _cooldown.Visible = w > 0.0f;
                    }
                    else
                    {
                        float w = size.X * progress;
                        _cooldown.Size = new Vector2(w, size.Y);
                        _cooldown.Position = new Vector2(size.X - w, 0);
                        _cooldown.Visible = w > 0.0f;
                    }
                    break;
                }
        }
    }
    private void UpdateHoldFillVisual()
    {
        if (!EnableHoldBuildUp || !_isPressed) return;
        EnsureHoldFill();
        if (_holdFill == null || !IsInstanceValid(_holdFill)) return;
        float total = Math.Max(0.0001f, HoldDuration);
        float progress = Mathf.Clamp((float)(_holdTimer / total), 0f, 1f);
        // Make sure it becomes visible immediately even at 0 progress
        _holdFill.Visible = true;
        var size = Size;
        switch (HoldFillDirection)
        {
            case CooldownDirection.BottomToTop:
                {
                    float h = Math.Max(1f, size.Y * progress);
                    _holdFill.Size = new Vector2(size.X, h);
                    _holdFill.Position = new Vector2(0, size.Y - h);
                    break;
                }
            case CooldownDirection.TopToBottom:
                {
                    float h = Math.Max(1f, size.Y * progress);
                    _holdFill.Size = new Vector2(size.X, h);
                    _holdFill.Position = new Vector2(0, 0);
                    break;
                }
            case CooldownDirection.LeftToRight:
                {
                    float w = Math.Max(1f, size.X * progress);
                    _holdFill.Size = new Vector2(w, size.Y);
                    _holdFill.Position = new Vector2(0, 0);
                    break;
                }
            case CooldownDirection.RightToLeft:
                {
                    float w = Math.Max(1f, size.X * progress);
                    _holdFill.Size = new Vector2(w, size.Y);
                    _holdFill.Position = new Vector2(size.X - w, 0);
                    break;
                }
        }
    }
    #endregion
    /// <summary>Resolves Panel for styling whether it lives under <c>_Managed</c> or legacy direct child.</summary>
    private Panel? FindManagedPanelOrLegacy()
    {
        if (_managedRoot != null && IsInstanceValid(_managedRoot))
        {
            var p = _managedRoot.GetNodeOrNull<Panel>("Panel");
            if (p != null) return p;
        }
        var legacy = GetNodeOrNull<Panel>("Panel");
        if (legacy != null) return legacy;
        if (_panel != null && IsInstanceValid(_panel)) return _panel;
        return null;
    }

    private Panel GetOrCreatePanel()
    {
        EnsureManagedRoot();

        if (_panel != null && IsInstanceValid(_panel))
        {
            if (_panel.GetParent() == _managedRoot)
                return _panel;
            if (_panel.GetParent() == this)
            {
                RemoveChild(_panel);
                _managedRoot!.AddChild(_panel);
                _managedRoot.MoveChild(_panel, 0);
                ConfigurePanel(_panel);
                return _panel;
            }
        }

        var onManaged = _managedRoot!.GetNodeOrNull<Panel>("Panel");
        if (onManaged != null)
        {
            _panel = onManaged;
            return _panel;
        }

        var onSelf = GetNodeOrNull<Panel>("Panel");
        if (onSelf != null)
        {
            onSelf.GetParent()?.RemoveChild(onSelf);
            _managedRoot.AddChild(onSelf);
            _managedRoot.MoveChild(onSelf, 0);
            _panel = onSelf;
            ConfigurePanel(_panel);
            return _panel;
        }

        _panel = CreateManagedChildAtPosition<Panel>("Panel", 0);
        ConfigurePanel(_panel);
        return _panel;
    }
    private void ConfigurePanel(Panel panel)
    {
        if (panel == null) return;
        panel.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        panel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        panel.SizeFlagsVertical = SizeFlags.ExpandFill;
        panel.MouseFilter = MouseFilterEnum.Ignore;
        panel.ThemeTypeVariation = PanelThemeVariation ?? string.Empty;
    }
    #endregion
    #region Input Helpers

    private float HoverTargetForViewport()
    {
        // Limit hover scale so the visual stays within the viewport bounds
        var desired = HoverScale;
        var viewport = GetViewportRect();
        var rect = GetGlobalRect();
        var center = rect.Position + rect.Size / 2.0f;
        float halfW = Math.Max(1e-3f, rect.Size.X / 2.0f);
        float halfH = Math.Max(1e-3f, rect.Size.Y / 2.0f);
        float leftSpace = (float)(center.X - viewport.Position.X);
        float rightSpace = (float)((viewport.Position.X + viewport.Size.X) - center.X);
        float topSpace = (float)(center.Y - viewport.Position.Y);
        float bottomSpace = (float)((viewport.Position.Y + viewport.Size.Y) - center.Y);
        float maxScaleX = Math.Min(leftSpace / halfW, rightSpace / halfW);
        float maxScaleY = Math.Min(topSpace / halfH, bottomSpace / halfH);
        float maxScale = Math.Max(1.0f, Math.Min(maxScaleX, maxScaleY));
        return Math.Min(desired, maxScale);
    }
    private void UpdateHoverPivotOffsets()
    {
        PivotOffset = Size / 2.0f;
        if (_panel != null && IsInstanceValid(_panel)) _panel.PivotOffset = _panel.Size / 2.0f;
        if (_background != null && IsInstanceValid(_background)) _background.PivotOffset = _background.Size / 2.0f;
        if (_icon != null && IsInstanceValid(_icon)) _icon.PivotOffset = _icon.Size / 2.0f;
        if (_label != null && IsInstanceValid(_label)) _label.PivotOffset = _label.Size / 2.0f;
        if (_overlay != null && IsInstanceValid(_overlay)) _overlay.PivotOffset = _overlay.Size / 2.0f;
        if (_richLabel != null && IsInstanceValid(_richLabel)) _richLabel.PivotOffset = _richLabel.Size / 2.0f;
    }



    private bool _hoverTopLevelActive = false;
    private Vector2 _savedGlobalPos;
    private void EnableHoverTopLevel(bool enable)
    {
        if (enable && !_hoverTopLevelActive)
        {
            _savedGlobalPos = GlobalPosition;
            TopLevel = true;
            GlobalPosition = _savedGlobalPos; // keep the control where it was
            _hoverTopLevelActive = true;
        }
        else if (!enable && _hoverTopLevelActive)
        {
            var gp = GlobalPosition;
            TopLevel = false;
            GlobalPosition = gp; // preserve screen-space location when reattaching
            _hoverTopLevelActive = false;
        }
    }
    private void RefreshEditorVisual(bool children = false, bool panelStyling = false)
    {
        if (children)
            SetupChildren();
        if (panelStyling)
            ApplyPanelStyling();
        ApplyVisualState();
        FitLabelText();
        UpdateHoverPivotOffsets();
        if (Engine.IsEditorHint())
            QueueRedraw();
    }
    private Rect2 GetFollowClampRect()
    {
        if (BoundsSource != null && IsInstanceValid(BoundsSource))
            return BoundsSource.GetGlobalRect();
        if (GetParent() is Control p)
            return p.GetGlobalRect();
        // Fallback to whole viewport
        return GetViewportRect();
    }
    /// <summary>
    /// Moves the control so its center tracks the given global screen point.
    /// Honors current follow constraints (bounds clamp or virtual joystick clamp).
    /// </summary>
    private void MoveToGlobal(Vector2 globalPoint)
    {
        var half = Size / 2f;
        // When virtual joystick is active, clamp movement to a circle centered at the home point
        bool useCircle = (ClampShape == JoystickClampShape.Circle);
        if (_vjActive && useCircle)
        {
            var clampRect = GetFollowClampRect();
            var pointer = globalPoint;
            // Compute circular clamp radius (pixels from center)
            float radius = JoystickRadiusPx > 0
                ? JoystickRadiusPx
                : ComputeAutoJoystickRadius(_vjHomeGlobal, clampRect);
            // Clamp pointer to a circle around the home center
            var delta = pointer - _vjHomeGlobal;
            var len = delta.Length();
            if (len > radius && len > 1e-4f)
                pointer = _vjHomeGlobal + delta / len * radius;
            // Also respect rectangular bounds to avoid leaving the allowed area
            pointer.X = Mathf.Clamp(pointer.X, clampRect.Position.X, clampRect.Position.X + clampRect.Size.X);
            pointer.Y = Mathf.Clamp(pointer.Y, clampRect.Position.Y, clampRect.Position.Y + clampRect.Size.Y);
            GlobalPosition = pointer - half;
            return;
        }
        // When virtual joystick is active with rectangular clamp, restrict to a rectangle centered at home
        if (_vjActive && !useCircle)
        {
            var clampRect = GetFollowClampRect();
            var pointer = globalPoint;
            Vector2 halfExtents = JoystickRectSizePx != Vector2.Zero
                ? JoystickRectSizePx / 2f
                : ComputeAutoJoystickHalfExtents(_vjHomeGlobal, clampRect);
            // Clamp pointer to rect centered at home, then to overall clamp rect
            pointer.X = Mathf.Clamp(pointer.X, _vjHomeGlobal.X - halfExtents.X, _vjHomeGlobal.X + halfExtents.X);
            pointer.Y = Mathf.Clamp(pointer.Y, _vjHomeGlobal.Y - halfExtents.Y, _vjHomeGlobal.Y + halfExtents.Y);
            pointer.X = Mathf.Clamp(pointer.X, clampRect.Position.X, clampRect.Position.X + clampRect.Size.X);
            pointer.Y = Mathf.Clamp(pointer.Y, clampRect.Position.Y, clampRect.Position.Y + clampRect.Size.Y);
            GlobalPosition = pointer - half;
            return;
        }
        // Default follow behavior uses rectangular clamp (full space of the clamp rect)
        var desired = globalPoint - half;
        if (ClampToBounds)
        {
            var clamp = GetFollowClampRect();
            desired.X = Mathf.Clamp(desired.X, clamp.Position.X, clamp.Position.X + clamp.Size.X - Size.X);
            desired.Y = Mathf.Clamp(desired.Y, clamp.Position.Y, clamp.Position.Y + clamp.Size.Y - Size.Y);
        }
        GlobalPosition = desired;
    }
    /// <summary>
    /// Computes and emits the joystick axis vector in the range [-1,1] based on the
    /// current virtual joystick home position and a clamped pointer location.
    /// Applies circular or rectangular normalization and a deadzone.
    /// </summary>






    #region Property List Builder



    #endregion

    public void PrintLog(string message)
    {
        if (HasSignal(SignalName.Log))
            EmitSignal(SignalName.Log, message);
        else
            DefaultLog(message);
    }
    public void DefaultLog(string message)
    {
        GD.Print("[OmniButton] " + message);
    }
    public void PrintWarn(string message)
    {
        if (HasSignal(SignalName.Warning))
            EmitSignal(SignalName.Warning, message);
        else
            DefaultWarn(message);
    }
    private void DefaultWarn(string message)
    {
        GD.PushWarning("[OmniButton] " + message);
    }
    private void PrintError(string message)
    {
        if (HasSignal(SignalName.Error))
            EmitSignal(SignalName.Error, message);
        else
            DefaultError(message);
    }
    private void DefaultError(string message)
    {
        GD.PushError("[OmniButton] " + message);
    }
    #endregion
    #region Built-in Signal Handlers
    private void RunBuiltInPressed() { /* Default pressed behavior */ }
    private void RunBuiltInReleased() { /* Default released behavior */ }
    private void RunBuiltInHoverIn() { /* Default hover in behavior */ }
    private void RunBuiltInHoverOut() { /* Default hover out behavior */ }
    private void RunBuiltInToggled(bool pressed) { /* Default toggle behavior */ }
    private void RunBuiltInLog(string type, string message)
    {
        GD.Print($"[{type}] {message}");
    }
    private void RunBuiltInHold() { /* Default hold behavior */ }
    private void RunBuiltInSwipe(Vector2 direction) { /* Default swipe behavior */ }
    private void RunBuiltInWarning(string message)
    {
        GD.PushWarning(message);
    }
    private void RunBuiltInError(string message)
    {
        GD.PushError(message);
    }
    #endregion
}
