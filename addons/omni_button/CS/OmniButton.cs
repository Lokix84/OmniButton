using Godot;
using Godot.Collections;
using System;
[Tool]
[GlobalClass, GodotClassName("OmniButton")]
/// <summary>
/// OmniButton is a flexible UI Control that provides press/release/hover/toggle/hold/swipe
/// interactions, optional selection overlays, a cooldown fill, hover scaling, and an optional
/// virtual joystick mode. It is editor-friendly and primarily driven by exported properties
/// and signals, so it drops into many UI patterns with minimal code.
/// </summary>
public partial class OmniButton : Control
{
    #region Signals
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ReleasedEventHandler();
    [Signal] public delegate void HoverInEventHandler();
    [Signal] public delegate void HoverOutEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool pressed);
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
    #region State(Exported Properties)
    [ExportGroup("State")]
    [Export] public bool Disabled { get; set; } = false;
    [Export]
    public bool Selected
    {
        get => _isSelected;
        set
        {
            _isSelected = value;
            UpdateOverlay();
            ApplyVisualState();
        }
    }
    [Export]
    public bool IsToggled
    {
        get => _isToggled;
        set
        {
            _isToggled = value;
            UpdateOverlay();
            ApplyVisualState();
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
                ApplyVisualState();
                return;
            }
            bool wasPressed = _isPressed;
            _isPressed = value;
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
            ApplyVisualState();
        }
    }
    [Export]
    public bool IsHovering
    {
        get => _isHovering;
        set
        {
            _isHovering = value;
            ApplyVisualState();
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
            ApplyVisualState();
        }
    }
    #endregion
    #region Preset(Exported Properties)
    public enum Preset { None = 0, Basic = 1, Toggle = 2, Hold = 3, Swipe = 4, Draggable = 5, VirtualJoystick = 6, Custom = 99 }
    private bool _suppressPresetApply = false;
    private Preset _preset = Preset.None;
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
    #region Display Properties(Exported Properties)
    [ExportGroup("Content Display")]
    [Export]
    public BackgroundMode BackgroundType
    {
        get => _backgroundMode;
        set { _backgroundMode = value; RefreshEditorVisual(children: true, panelStyling: true); }
    }
    public enum BackgroundMode { None = 0, UsePanel = 1, UseTexture = 2 }
    private BackgroundMode _backgroundMode = BackgroundMode.None;

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
            ApplyVisualState();
            FitLabelText();
        }
    }
    private Texture2D? _iconTexture;

    // Label type + unified Text
    public enum LabelTypeEnum { Label = 0, RichTextLabel = 1 }
    private LabelTypeEnum _labelType = LabelTypeEnum.Label;
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
            SetupChildren();
            ApplyVisualState();
            FitLabelText();
        }
    }
    private string _text = string.Empty;
    [Export(PropertyHint.MultilineText)]
    public string Text
    {
        get => _text;
        set
        {
            _text = value ?? string.Empty;
            if (_labelType == LabelTypeEnum.Label) { _labelText = _text; _richLabelText = string.Empty; }
            else { _richLabelText = _text; _labelText = string.Empty; }
            SetupChildren();
            ApplyVisualState();
            FitLabelText();
        }
    }
    // Back-compat exports
    /// <summary>Deprecated: use Text + LabelType</summary>
    [Export]
    public string LabelText
    {
        get => _labelType == LabelTypeEnum.Label ? _text : string.Empty;
        set { _labelText = value ?? string.Empty; _text = _labelText; _labelType = LabelTypeEnum.Label; SetupChildren(); ApplyVisualState(); FitLabelText(); }
    }
    private string _labelText = string.Empty;
    /// <summary>Deprecated: use Text + LabelType</summary>
    [Export]
    public string RichLabelText
    {
        get => _labelType == LabelTypeEnum.RichTextLabel ? _text : string.Empty;
        set { _richLabelText = value ?? string.Empty; _text = _richLabelText; _labelType = LabelTypeEnum.RichTextLabel; SetupChildren(); ApplyVisualState(); FitLabelText(); }
    }
    private string _richLabelText = string.Empty;
    // Interpret RichLabelText/Text as BBCode when using RichTextLabel
    [Export] public bool RichLabelUseBBCode { get; set; } = true;
    /// <summary>
    /// When true, shows a full-rect ColorRect overlay whenever either Selected or IsToggled is true.
    /// The overlay color is always <see cref="SelectedColor"/>.
    /// </summary>
    [Export]
    public bool EnableSelectedOverlay
    {
        get => _enableSelectedOverlay;
        set
        {
            _enableSelectedOverlay = value;
            UpdateOverlay();
            RefreshEditorVisual();
        }
    }
    private bool _enableSelectedOverlay = false;
    /// <summary>
    /// Overlay color used whenever the overlay is visible (Selected or IsToggled true).
    /// </summary>
    [Export]
    public Color SelectedColor
    {
        get => _selectedColor;
        set { _selectedColor = value; RefreshEditorVisual(); }
    }
    private Color _selectedColor = new Color(1, 1, 1, 0.3f);
    #region Panel(Exported Properties)
    [ExportSubgroup("Background Settings")]
    [Export] public string PanelThemeType { get => _panelThemeType; set { _panelThemeType = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private string _panelThemeType = "Panel";
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
    [ExportSubgroup("Icon Settings")]
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
    #region Label(Exported Properties)
    [ExportSubgroup("Label Settings")]
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
    [Export] public Vector2 TextFitPadding { get; set; } = new Vector2(12, 4);
    /// <summary>
    /// Minimum font size used by autosize
    /// </summary>
    [Export(PropertyHint.Range, "6,300,1")]
    public int MinFontSize { get => _minFontSize; set { _minFontSize = value; FitLabelText(); } }
    private int _minFontSize = 6;
    /// <summary>
    /// Maximum font size used by autosize
    /// </summary>
    [Export(PropertyHint.Range, "6,300,1")]
    public int MaxFontSize { get => _maxFontSize; set { _maxFontSize = value; FitLabelText(); } }
    private int _maxFontSize = 100;
    /// <summary>
    /// When > 0 forces this fixed size and bypasses autosize
    /// </summary>
    [Export(PropertyHint.Range, "0,300,1")] public int FixedFontSize { get; set; } = 0;
    /// <summary>
    /// Enable dynamic auto-sizing of Label/RichText within control bounds
    /// </summary>
    [Export] public bool EnableTextAutoSize { get; set; } = true;
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
    /// <summary>
    /// Autowrap mode for Label/RichText; affects autosize
    /// </summary>
    [Export] public TextServer.AutowrapMode LabelAutowrap { get => _labelAutowrap; set { _labelAutowrap = value; RefreshEditorVisual(); } }
    private TextServer.AutowrapMode _labelAutowrap = TextServer.AutowrapMode.Off;

    // Modulate properties relocated into relevant subgroups below
    #endregion
    #region Invert Display(Exported Properties)
    /// <summary>
    /// Flags for when to apply a simple invert shader to child visuals.
    /// Combine to invert on press, toggle, hover, or while holding.
    /// </summary>
    [Flags] public enum InvertDisplayModes { None = 0, Press = 1, Toggle = 2, Hover = 4, Hold = 8 }
    [ExportSubgroup("Invert Display")]
    private InvertDisplayModes _invertModes = InvertDisplayModes.None;
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
    #region Input(Exported Properties)
    [ExportGroup("Input")]
    /// <summary>
    /// Optional external Control whose rect defines input bounds
    /// </summary>
    [Export] public Control? BoundsSource { get; set; }
    /// <summary>
    /// Extra inset/outset for hit detection (pixels)
    /// </summary>
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;
    /// <summary>
    /// Determines how the button reacts to pointer drags while pressed.
    /// None keeps the control stationary; FollowBoth uses legacy rectangular follow;
    /// VirtualJoystick emits axes and optionally snaps the visual to input.
    /// </summary>
    public enum FollowModeEnum
    {
        None = 0,
        FollowBoth = 3,
        VirtualJoystick = 4
    }
    #endregion
    #region Follow(Exported Properties)
    [ExportGroup("Follow Input")]
    private FollowModeEnum _followMode = FollowModeEnum.None;
    /// <summary>
    /// Follow pointer while pressed or act as a virtual joystick
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
                CooldownDuration = 1.0f;
                CooldownStartFilled = false;
                CooldownColor = new Color(0, 0, 0, 0.4f);
                CooldownFillDirection = CooldownDirection.BottomToTop;
                SuspendHoverScaleDuringCooldown = false;
                AllowHoldDuringCooldown = false;
                HideCooldownDuringHoldBuildUp = true;
                _cooldownActive = false;
                _cooldownTimeLeft = 0.0;
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
    #region Theme Variations(Exported Properties)
    [ExportGroup("Theme Variations")]
    /// <summary>
    /// Theme type name used for style lookups
    /// </summary>
    [Export] public string ThemeTypeName { get; set; } = "OmniButton";
    /// <summary>
    /// Theme variation for normal state
    /// </summary>
    [Export] public string VariantNormal { get; set; } = "normal";
    /// <summary>
    /// Theme variation for pressed state
    /// </summary>
    [Export] public string VariantPressed { get; set; } = "pressed";
    /// <summary>
    /// Theme variation for hover state
    /// </summary>
    [Export] public string VariantHover { get; set; } = "hover";
    /// <summary>
    /// Theme variation for toggled state
    /// </summary>
    [Export] public string VariantToggled { get; set; } = "toggled";
    /// <summary>
    /// Theme variation for selected state
    /// </summary>
    [Export] public string VariantSelected { get; set; } = "selected";
    /// <summary>
    /// Theme variation for disabled state
    /// </summary>
    [Export] public string VariantDisabled { get; set; } = "disabled";
    #endregion
    #region Private State
    private Panel _panel;
    private TextureRect _background;
    private TextureRect _icon;
    private Label _label;
    private RichTextLabel _richLabel;
    private ColorRect _overlay;
    private ColorRect _cooldown;
    private ColorRect _holdFill;
    // Default visual for joystick thumb when no IconTexture is provided
    private Panel _defaultThumb;
    private ShaderMaterial _invertMaterial;
    private string? _lastVisualState;
    private float _hoverTargetScale = 1.0f;
    private Vector2 _originalScale = Vector2.One;
    private static readonly string[] OwnSignals = { "Pressed", "Toggled", "Released", "Log", "Warning", "Error", "Hold", "Swipe", "SwipeEnded", "HoverIn", "HoverOut" };
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
    private Panel _vjAreaPanel;

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
                EnableSelectedOverlay = true;
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
            EmitSignal(SignalName.SwipeEnded);
    }
    private void EndSwiping()
    {
        SetSwiping(false);
        _swipeStart = Vector2.Zero;
    }
    private double _holdTimer = 0;
    private bool _cooldownActive = false;
    private double _cooldownTimeLeft = 0.0;
    private bool _vjActive = false;
    private Vector2 _vjHomeGlobal; // center of the button at press time (global)
    private MouseFilterEnum _vjSavedMouseFilter = MouseFilterEnum.Stop;
    #endregion
    #region Accessor helpers for ergonomic usage
    public LabelAccessor LabelNode { get; private set; }
    public IconAccessor IconNode { get; private set; }
    public BackgroundAccessor BackgroundNode { get; private set; }
    public PanelAccessor PanelNode { get; private set; }
    public OverlayAccessor OverlayNode { get; private set; }
    public CooldownAccessor CooldownNode { get; private set; }
    public ChargeUpAccessor ChargeUpNode { get; private set; }

    public sealed class LabelAccessor
    {
        private readonly OmniButton _o;
        internal LabelAccessor(OmniButton o) { _o = o; }
        public string Text { get => _o.Text; set => _o.Text = value; }
        public LabelTypeEnum Type { get => _o.LabelType; set => _o.LabelType = value; }
        public Color Modulate { get => _o.TextModulate; set { _o.TextModulate = value; _o.ApplyVisualState(); } }
        public Font Font { get => _o.LabelFont; set { _o.LabelFont = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public Color Color { get => _o.LabelTextColor; set { _o.LabelTextColor = value; _o.ApplyVisualState(); } }
        public Vector2 FitPadding { get => _o.TextFitPadding; set { _o.TextFitPadding = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public int MinFontSize { get => _o.MinFontSize; set { _o.MinFontSize = value; _o.FitLabelText(); } }
        public int MaxFontSize { get => _o.MaxFontSize; set { _o.MaxFontSize = value; _o.FitLabelText(); } }
        public int FixedFontSize { get => _o.FixedFontSize; set { _o.FixedFontSize = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public bool AutoSize { get => _o.EnableTextAutoSize; set { _o.EnableTextAutoSize = value; _o.FitLabelText(); } }
        public HorizontalAlignment HAlign { get => _o.LabelHorizontalAlignment; set { _o.LabelHorizontalAlignment = value; _o.ApplyVisualState(); } }
        public VerticalAlignment VAlign { get => _o.LabelVerticalAlignment; set { _o.LabelVerticalAlignment = value; _o.ApplyVisualState(); } }
        public Vector2 Padding { get => _o.LabelPadding; set { _o.LabelPadding = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public float PadLeft { get => _o.LabelAdditionalPaddingLeft; set { _o.LabelAdditionalPaddingLeft = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public float PadTop { get => _o.LabelAdditionalPaddingTop; set { _o.LabelAdditionalPaddingTop = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public float PadRight { get => _o.LabelAdditionalPaddingRight; set { _o.LabelAdditionalPaddingRight = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public float PadBottom { get => _o.LabelAdditionalPaddingBottom; set { _o.LabelAdditionalPaddingBottom = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public TextServer.AutowrapMode Autowrap { get => _o.LabelAutowrap; set { _o.LabelAutowrap = value; _o.ApplyVisualState(); _o.FitLabelText(); } }
        public bool BBCode { get => _o.RichLabelUseBBCode; set { _o.RichLabelUseBBCode = value; _o.ApplyVisualState(); } }
    }
    public sealed class IconAccessor
    {
        private readonly OmniButton _o;
        internal IconAccessor(OmniButton o) { _o = o; }
        public Texture2D Texture { get => _o.IconTexture; set { _o.IconTexture = value; _o.ApplyVisualState(); } }
        public TextureRect.ExpandModeEnum ExpandMode { get => _o.IconExpandMode; set { _o.IconExpandMode = value; _o.ApplyVisualState(); } }
        public TextureRect.StretchModeEnum StretchMode { get => _o.IconStretchMode; set { _o.IconStretchMode = value; _o.ApplyVisualState(); } }
        public bool FlipH { get => _o.IconFlipH; set { _o.IconFlipH = value; _o.ApplyVisualState(); } }
        public bool FlipV { get => _o.IconFlipV; set { _o.IconFlipV = value; _o.ApplyVisualState(); } }
        public Color Modulate { get => _o.IconModulate; set { _o.IconModulate = value; _o.ApplyVisualState(); } }
    }
    public sealed class BackgroundAccessor
    {
        private readonly OmniButton _o;
        internal BackgroundAccessor(OmniButton o) { _o = o; }
        public BackgroundMode Mode { get => _o.BackgroundType; set { _o.BackgroundType = value; _o.ApplyVisualState(); } }
        public Texture2D Texture { get => _o.BackgroundTexture; set { _o.BackgroundTexture = value; _o.ApplyVisualState(); } }
        public TextureRect.ExpandModeEnum ExpandMode { get => _o.BackgroundExpandMode; set { _o.BackgroundExpandMode = value; _o.ApplyVisualState(); } }
        public TextureRect.StretchModeEnum StretchMode { get => _o.BackgroundStretchMode; set { _o.BackgroundStretchMode = value; _o.ApplyVisualState(); } }
        public bool FlipH { get => _o.BackgroundFlipH; set { _o.BackgroundFlipH = value; _o.ApplyVisualState(); } }
        public bool FlipV { get => _o.BackgroundFlipV; set { _o.BackgroundFlipV = value; _o.ApplyVisualState(); } }
        public Color Modulate { get => _o.BackgroundModulate; set { _o.BackgroundModulate = value; _o.ApplyVisualState(); } }
    }
    public sealed class OverlayAccessor
    {
        private readonly OmniButton _o;
        internal OverlayAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.EnableSelectedOverlay; set { _o.EnableSelectedOverlay = value; _o.ApplyVisualState(); } }
        public Color Color { get => _o.SelectedColor; set { _o.SelectedColor = value; _o.ApplyVisualState(); } }
    }
    public sealed class PanelAccessor
    {
        private readonly OmniButton _o;
        internal PanelAccessor(OmniButton o) { _o = o; }
        public Color Modulate { get => _o.PanelModulate; set { _o.PanelModulate = value; _o.ApplyVisualState(); } }
        public string ThemeType { get => _o.PanelThemeType; set { _o.PanelThemeType = value; _o.ApplyPanelStyling(); _o.ApplyVisualState(); } }
        public string ThemeVariation { get => _o.PanelThemeVariation; set { _o.PanelThemeVariation = value; _o.ApplyPanelStyling(); _o.ApplyVisualState(); } }
        public StyleBox PanelStyle { get => _o.PanelStyleBox; set { _o.PanelStyleBox = value; _o.ApplyPanelStyling(); _o.ApplyVisualState(); } }
    }
    public sealed class CooldownAccessor
    {
        private readonly OmniButton _o;
        internal CooldownAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.EnableCooldown; set { _o.EnableCooldown = value; _o.ApplyVisualState(); } }
        public float Duration { get => _o.CooldownDuration; set { _o.CooldownDuration = value; } }
        public CooldownTriggerEnum Trigger { get => _o.CooldownTrigger; set { _o.CooldownTrigger = value; } }
        public bool StartFilled { get => _o.CooldownStartFilled; set { _o.CooldownStartFilled = value; } }
        public Color Color { get => _o.CooldownColor; set { _o.CooldownColor = value; _o.ApplyVisualState(); } }
        public CooldownDirection Direction { get => _o.CooldownFillDirection; set { _o.CooldownFillDirection = value; } }
        public bool SuspendHoverScale { get => _o.SuspendHoverScaleDuringCooldown; set { _o.SuspendHoverScaleDuringCooldown = value; } }
        public bool AllowHoldDuring { get => _o.AllowHoldDuringCooldown; set { _o.AllowHoldDuringCooldown = value; } }
        public bool HideDuringChargeUp { get => _o.HideCooldownDuringHoldBuildUp; set { _o.HideCooldownDuringHoldBuildUp = value; } }
    }
    public sealed class ChargeUpAccessor
    {
        private readonly OmniButton _o;
        internal ChargeUpAccessor(OmniButton o) { _o = o; }
        public bool Enabled { get => _o.EnableHoldBuildUp; set { _o.EnableHoldBuildUp = value; _o.ApplyVisualState(); } }
        public float Duration { get => _o.HoldDuration; set { _o.HoldDuration = value; } }
        public Color Color { get => _o.HoldFillColor; set { _o.HoldFillColor = value; _o.ApplyVisualState(); } }
        public CooldownDirection Direction { get => _o.HoldFillDirection; set { _o.HoldFillDirection = value; } }
    }
    #endregion
    // Auto-enable actions once when user attaches external signal handlers
    private ActionMaskFlags _autoActionOnce = ActionMaskFlags.None;
    private void AutoEnableActionsFromConnectionsOnce()
    {
        var map = new (string signal, ActionMaskFlags flag)[]
        {
            (SignalName.Pressed, ActionMaskFlags.Pressed),
            (SignalName.Released, ActionMaskFlags.Released),
            (SignalName.HoverIn, ActionMaskFlags.Hover),
            (SignalName.HoverOut, ActionMaskFlags.Hover),
            (SignalName.Toggled, ActionMaskFlags.Toggle),
            (SignalName.Hold, ActionMaskFlags.Hold),
            (SignalName.Swipe, ActionMaskFlags.Swipe),
            (SignalName.Log, ActionMaskFlags.Log),
            (SignalName.Warning, ActionMaskFlags.Warning),
            (SignalName.Error, ActionMaskFlags.Error),
        };
        foreach (var (signal, flag) in map)
        {
            if ((_autoActionOnce & flag) != 0) continue;
            var conns = GetSignalConnectionList(signal);
            bool hasExternal = false;
            foreach (Godot.Collections.Dictionary dict in conns)
            {
                if (!dict.TryGetValue("callable", out var callable)) continue;
                var cb = (Callable)callable;
                var target = cb.Target;
                if (target != null && !ReferenceEquals(target, this))
                {
                    hasExternal = true; break;
                }
            }
            if (hasExternal)
            {
                ActionMask |= flag;
                _autoActionOnce |= flag;
            }
        }
    }
    private string _editorLastSig = string.Empty;
    private string BuildEditorSignature()
    {
        var sb = new System.Text.StringBuilder(1024);
        // Query Godot's property list so we include exported + dynamic properties
        var props = GetPropertyList();
        foreach (Godot.Collections.Dictionary p in props)
        {
            if (!p.ContainsKey("usage")) continue;
            var usage = (long)p["usage"]; // PropertyUsageFlags
            const long EditorUsage = (long)Godot.PropertyUsageFlags.Editor;
            if ((usage & EditorUsage) == 0) continue;
            string name = (string)p["name"];
            var val = Get(name);
            sb.Append(name).Append('=').Append(val.ToString()).Append('|');
        }
        return sb.ToString();
    }
    #region Godot Lifecycle
    public override void _EnterTree() => Initialize();
    public override void _ExitTree() => Cleanup();
    public override void _Ready() => Setup();
    public override void _Process(double delta)
    {
        // Editor: poll for export changes and refresh visuals immediately
        if (Engine.IsEditorHint())
        {
            var sig = BuildEditorSignature();
            if (sig != _editorLastSig)
            {
                _editorLastSig = sig;
                SetupChildren();
                ApplyPanelStyling();
                ApplyVisualState();
                FitLabelText();
            }
        }
        ProcessHoverScaling(delta);
    }
    public override Array<Dictionary> _GetPropertyList() => BuildPropertyList();

    // Ensure we observe mouse releases even if they occur off-bounds
    public override void _UnhandledInput(InputEvent @event)
    {
        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left && !mb.Pressed)
        {
            // If we had an active press/drag/joystick, cleanly end it even if release happened off this control
            if (_isPressed || _vjActive || _isSwiping)
            {
                _isPressed = false;
                _isHolding = false;
                EndSwiping();

                if (_holdFill != null && IsInstanceValid(_holdFill))
                    RemoveHoldFill();

                if (_vjActive)
                {
                    EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
                    EmitSignal(SignalName.JoystickEnded);
                    if (JoystickResetOnRelease)
                        GlobalPosition = _vjHomeGlobal - Size / 2f;
                    if (JoystickHideWhenInactive)
                        Visible = false;
                    _vjActive = false;
                }

                EnableHoverTopLevel(false);
                ApplyVisualState();
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
                _isPressed = true;
                _holdTimer = 0;
                _isHolding = false;
                EndSwiping();
                _swipeOrigin = mb.Position;
                if (wantJoystick)
                {
                    _vjActive = true;
                    _vjHomeGlobal = GlobalPosition + Size / 2f;
                    EnableHoverTopLevel(true);
                    if (JoystickSnapToInput)
                        MoveToGlobal(mb.GlobalPosition);
                    if (JoystickHideWhenInactive)
                        Visible = true;
                    EmitSignal(SignalName.JoystickStarted);
                    EmitJoystickAxisFor(mb.GlobalPosition);
                }
                if (FollowMode != FollowModeEnum.None)
                {
                    EnableHoverTopLevel(true);
                    MoveToGlobal(mb.GlobalPosition);
                }
                if (ActionMask.HasFlag(ActionMaskFlags.Swipe))
                    _swipeStart = mb.Position;
                if (ActionMask.HasFlag(ActionMaskFlags.Pressed))
                    EmitSignal(SignalName.Pressed);
                bool toggleOnPress = (InteractionMode == InteractionModeEnum.ToggleOnPress) ||
                                      (InteractionMode == InteractionModeEnum.Momentary && (ActionMask.HasFlag(ActionMaskFlags.Toggle)));
                if (toggleOnPress)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                }
                bool cooldownOnPress = (CooldownTrigger == CooldownTriggerEnum.OnPress || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && cooldownOnPress)
                    CallDeferred(MethodName.StartCooldown);
                if (EnableHoldBuildUp && !_isHolding)
                {
                    _holdTimer = 0; EnsureHoldFill(); UpdateHoldFillVisual(); SetProcess(true);
                }
                ApplyVisualState();
            }
            else
            {
                _isPressed = false;
                _isHolding = false;
                EndSwiping();
                _swipeStart = Vector2.Zero;
                if ((ActionMask.HasFlag(ActionMaskFlags.Released)) && inside)
                    EmitSignal(SignalName.Released);
                bool cooldownOnRelease = (CooldownTrigger == CooldownTriggerEnum.OnRelease || CooldownTrigger == CooldownTriggerEnum.OnPressAndRelease);
                if (EnableCooldown && cooldownOnRelease)
                    StartCooldown();
                if (_holdFill != null && IsInstanceValid(_holdFill))
                    RemoveHoldFill();
                if (InteractionMode == InteractionModeEnum.ToggleOnRelease)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                }
                if (_vjActive)
                {
                    EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
                    EmitSignal(SignalName.JoystickEnded);
                    if (JoystickResetOnRelease)
                    {
                        GlobalPosition = _vjHomeGlobal - Size / 2f;
                    }
                    if (JoystickHideWhenInactive)
                        Visible = false;
                    _vjActive = false;
                }
                EnableHoverTopLevel(false);
                ApplyVisualState();
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
            if (ActionMask.HasFlag(ActionMaskFlags.Swipe))
            {
                if (_swipeStart == Vector2.Zero)
                    _swipeStart = mm.Position;
                else
                {
                    var direction = mm.Position - _swipeStart;
                    if (direction.Length() > SwipeThreshold)
                    {
                        EmitSignal(SignalName.Swipe, direction.Normalized());
                        _swipeStart = Vector2.Zero;
                    }
                }
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
            if (ActionMask.HasFlag(ActionMaskFlags.Swipe))
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
                    if (_swipeStart == Vector2.Zero)
                        _swipeStart = sd.Position;
                    else
                    {
                        var direction = sd.Position - _swipeStart;
                        if (direction.Length() > SwipeThreshold)
                        {
                            EmitSignal(SignalName.Swipe, direction.Normalized());
                            _swipeStart = Vector2.Zero;
                        }
                    }
                }
            }
            // Update swiping state relative to origin regardless of action mask
            SetSwiping(IsInputInside(sd) && (sd.Position - _swipeOrigin).Length() > SwipeThreshold);
        }
        else if ((ActionMask.HasFlag(ActionMaskFlags.Swipe)) && @event is InputEventScreenDrag drag)
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
                if (_swipeStart == Vector2.Zero)
                    _swipeStart = drag.Position;
                else
                {
                    var direction = drag.Position - _swipeStart;
                    if (direction.Length() > SwipeThreshold)
                    {
                        EmitSignal(SignalName.Swipe, direction.Normalized());
                        _swipeStart = Vector2.Zero;
                    }
                }
            }
        }
        else if ((ActionMask.HasFlag(ActionMaskFlags.Swipe)) && _isPressed && @event is InputEventMouseMotion motion)
        {
            if (_swipeStart == Vector2.Zero)
                _swipeStart = motion.Position;
            else
            {
                var direction = motion.Position - _swipeStart;
                if (direction.Length() > SwipeThreshold)
                {
                    EmitSignal(SignalName.Swipe, direction.Normalized());
                    _swipeStart = Vector2.Zero;
                }
            }
        }
        else if ((ActionMask.HasFlag(ActionMaskFlags.Swipe)) && MouseSwipeInit == SwipeInitMode.OnHoverIn && @event is InputEventMouseMotion hoverMotion)
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
                    var direction = hoverMotion.GlobalPosition - _swipeStart;
                    if (direction.Length() > SwipeThreshold)
                    {
                        EmitSignal(SignalName.Swipe, direction.Normalized());
                        // For hover-init, keep the swipe session alive: advance anchor instead of clearing.
                        _swipeStart = hoverMotion.GlobalPosition;
                    }
                }
                // For hover-init, remain in swiping state while inside; exit is controlled by MouseSwipeExit
                SetSwiping(true);
            }
        }
    }
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
                    _isPressed = false;
                    _isHovering = false;
                    _isHolding = false;
                    EndSwiping();
                    InvalidateVisualState();
                }
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
        if (EnableSelectedOverlay && Selected && BackgroundType == BackgroundMode.None)
            BackgroundType = BackgroundMode.UsePanel;
        var shaderPath = "res://addons/omni_button/Shader/InvertColor.tres";
        if (ResourceLoader.Exists(shaderPath))
            _invertMaterial = GD.Load<ShaderMaterial>(shaderPath);
        SetupChildren();
        ApplyPanelStyling();
        ApplyVisualState();
        FitLabelText();
        // Optionally hide the control until a virtual joystick session starts (runtime only)
        if (!Engine.IsEditorHint() && EnableVirtualJoystick && JoystickHideWhenInactive)
            Visible = false;

        // Initialize ergonomic accessors
        LabelNode = new LabelAccessor(this);
        IconNode = new IconAccessor(this);
        BackgroundNode = new BackgroundAccessor(this);
        PanelNode = new PanelAccessor(this);
        OverlayNode = new OverlayAccessor(this);
        CooldownNode = new CooldownAccessor(this);
        ChargeUpNode = new ChargeUpAccessor(this);
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
        if (_panel != null && IsInstanceValid(_panel)) { RemoveChild(_panel); _panel.QueueFree(); }
        _panel = null;
        if (_defaultThumb != null && IsInstanceValid(_defaultThumb)) { RemoveChild(_defaultThumb); _defaultThumb.QueueFree(); }
        _defaultThumb = null;
        if (_vjAreaPanel != null && IsInstanceValid(_vjAreaPanel)) { RemoveChild(_vjAreaPanel); _vjAreaPanel.QueueFree(); }
        _vjAreaPanel = null;
    }
    #endregion
    #region Processing
    /// <summary>
    /// Drives hover scaling animation and hold build-up visuals over time.
    /// Also advances cooldown fill and hides/shows transient overlays as needed.
    /// </summary>
    private void ProcessHoverScaling(double delta)
    {
        Selected = _isSelected;
        IsToggled = _isToggled;
        IsPressed = _isPressed;
        IsHovering = _isHovering;
        IsHolding = _isHolding;
        Disabled = Disabled;
        // Hold timer progresses when pressed and either not in cooldown or allowed during cooldown
        if (_isPressed && (!EnableCooldown || !_cooldownActive || AllowHoldDuringCooldown || EnableHoldBuildUp))
        {
            _holdTimer += delta;
            if (!_isHolding && _holdTimer >= HoldDuration)
            {
                _isHolding = true;
                if (ActionMask.HasFlag(ActionMaskFlags.Hold))
                    EmitSignal(SignalName.Hold);
                RemoveHoldFill();
            }
            if (EnableHoldBuildUp) { if (!_isHolding) UpdateHoldFillVisual(); else RemoveHoldFill(); }
        }
        else if (EnableHoldBuildUp)
        {
            RemoveHoldFill();
        }
        // Hover scaling â€” independent of hover actions
        if (EnableHoverScale)
        {
            // Keep pivots centered so scaling stays symmetric even during swipe/hover
            if (_isHovering)
                UpdateHoverPivotOffsets();
            if (EnableCooldown && _cooldownActive && SuspendHoverScaleDuringCooldown)
            {
                var tReset = (float)Math.Min(1.0, delta * HoverLerpSpeed);
                if (_panel != null && IsInstanceValid(_panel)) LerpScaleTo(_panel, Vector2.One, tReset);
                if (_icon != null && IsInstanceValid(_icon)) LerpScaleTo(_icon, Vector2.One, tReset);
                if (_label != null && IsInstanceValid(_label)) LerpScaleTo(_label, Vector2.One, tReset);
                if (_overlay != null && IsInstanceValid(_overlay)) LerpScaleTo(_overlay, Vector2.One, tReset);
                EnableHoverTopLevel(false);
            }
            else
            {
                var target = new Vector2(_hoverTargetScale, _hoverTargetScale);
                var t = (float)Math.Min(1.0, delta * HoverLerpSpeed);
                bool anyAnimating = false;
                // Scale sub-nodes, not the container itself (avoids layout side-effects)
                if (_panel != null && IsInstanceValid(_panel)) anyAnimating |= LerpScaleTo(_panel, target, t);
                if (_icon != null && IsInstanceValid(_icon)) anyAnimating |= LerpScaleTo(_icon, target, t);
                if (_label != null && IsInstanceValid(_label)) anyAnimating |= LerpScaleTo(_label, target, t);
                if (_overlay != null && IsInstanceValid(_overlay)) anyAnimating |= LerpScaleTo(_overlay, target, t);
                // Keep processing if a hold build-up is in progress
                bool holdBuildActive = EnableHoldBuildUp && _isPressed && !_isHolding;
                if (!anyAnimating && !_isHovering && !(_cooldownActive && EnableCooldown) && !holdBuildActive)
                {
                    SetProcess(false);
                    EnableHoverTopLevel(false);
                }
            }
        }
        else
        {
            // Ensure we reset to default scale if hover actions are disabled
            var t = (float)Math.Min(1.0, delta * HoverLerpSpeed);
            bool anyAnimating = false;
            if (_panel != null && IsInstanceValid(_panel)) anyAnimating |= LerpScaleTo(_panel, Vector2.One, t);
            if (_icon != null && IsInstanceValid(_icon)) anyAnimating |= LerpScaleTo(_icon, Vector2.One, t);
            if (_label != null && IsInstanceValid(_label)) anyAnimating |= LerpScaleTo(_label, Vector2.One, t);
            if (_overlay != null && IsInstanceValid(_overlay)) anyAnimating |= LerpScaleTo(_overlay, Vector2.One, t);
            // Keep processing if a hold build-up is in progress
            bool holdBuildActive = EnableHoldBuildUp && _isPressed && !_isHolding;
            if (!anyAnimating && !(_cooldownActive && EnableCooldown) && !holdBuildActive)
            {
                SetProcess(false);
                EnableHoverTopLevel(false);
            }
        }
        // Optionally hide cooldown overlay while hold build-up is animating
        if (HideCooldownDuringHoldBuildUp && _cooldown != null && IsInstanceValid(_cooldown))
        {
            bool holdActive = EnableHoldBuildUp && _isPressed && !_isHolding;
            if (holdActive)
                _cooldown.Visible = false;
            else if (_cooldownActive)
                _cooldown.Visible = true;
        }
        // Cooldown handling
        if (_cooldownActive)
        {
            _cooldownTimeLeft = Math.Max(0.0, _cooldownTimeLeft - delta);
            UpdateCooldownVisual();
            if (_cooldownTimeLeft <= 0.0)
            {
                _cooldownActive = false;
                if (_cooldown != null && IsInstanceValid(_cooldown))
                    _cooldown.Visible = false;
                _cooldown.Size = Vector2.Zero;
                _cooldown.Position = Vector2.Zero;
            }
        }
    }
    private bool LerpScaleTo(Control node, Vector2 target, float t)
    {
        if (node == null || !IsInstanceValid(node)) return false;
        var newScale = node.Scale.Lerp(target, t);
        bool changed = (newScale - target).Length() >= 0.001f;
        node.Scale = newScale;
        if (!changed) node.Scale = target;
        return changed;
    }
    #endregion
    #region Signal & Event Management
    private void InitializeCallables()
    {
        var fallbacks = new (string name, Callable callable)[]
        {
            ("Pressed", new Callable(this, nameof(RunBuiltInPressed))),
            ("Released", new Callable(this, nameof(RunBuiltInReleased))),
            ("HoverIn", new Callable(this, nameof(RunBuiltInHoverIn))),
            ("HoverOut", new Callable(this, nameof(RunBuiltInHoverOut))),
            ("Toggled", new Callable(this, nameof(RunBuiltInToggled))),
            ("Log", new Callable(this, nameof(RunBuiltInLog))),
            ("Hold", new Callable(this, nameof(RunBuiltInHold))),
            ("Swipe", new Callable(this, nameof(RunBuiltInSwipe))),
            ("Warning", new Callable(this, nameof(RunBuiltInWarning))),
            ("Error", new Callable(this, nameof(RunBuiltInError)))
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
            case "Hold": HoldAction = callable; break;
            case "Swipe": SwipeAction = callable; break;
            case "Warning": WarningAction = callable; break;
            case "Error": ErrorAction = callable; break;
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
            ("Log", LogAction),
            ("Hold", HoldAction),
            ("Swipe", SwipeAction),
            ("Warning", WarningAction),
            ("Error", ErrorAction)
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
    private void DisconnectAllSignalHandlers()
    {
        foreach (var signal in OwnSignals)
        {
            if (HasSignal(signal))
            {
                var connections = GetSignalConnectionList(signal);
                foreach (var connection in connections)
                {
                    var dict = connection;
                    if (dict.TryGetValue("callable", out var callable))
                    {
                        var cb = (Callable)callable;
                        if (IsConnected(signal, cb))
                            Disconnect(signal, cb);
                    }
                }
            }
        }
    }
    private Callable AdoptConnectedCallable(string signalName, Callable fallback)
    {
        var connections = GetSignalConnectionList(signalName);
        return connections.Count > 0 ? ((Callable)connections[0]["callable"]) : fallback;
    }
    #endregion
    #region Mouse Events
    private void OnPressed()
    {
        if (Disabled) return;
        _isPressed = true;
        InvalidateVisualState();
        GrabFocus();
        if (ActionMask.HasFlag(ActionMaskFlags.Pressed)) EmitSignal(SignalName.Pressed);
    }
    private void OnReleased()
    {
        if (Disabled) return;
        if (ActionMask.HasFlag(ActionMaskFlags.Released)) EmitSignal(SignalName.Released);
    }
    private void OnLog(string type, string message) => EmitSignal(SignalName.Log, type, message);
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
        if (ActionMask.HasFlag(ActionMaskFlags.Hover))
            EmitSignal(SignalName.HoverIn);
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
        if (ActionMask.HasFlag(ActionMaskFlags.Hover))
            EmitSignal(SignalName.HoverOut);
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
    private void SetupChildren()
    {
        // Free existing managed children instead of only detaching them
        foreach (Node child in GetChildren())
        {
            RemoveChild(child);
            child.QueueFree();
        }
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
            AddChild(_panel);
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
            AddChild(_background);
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
            AddChild(_icon);
            EnsureFullRect(_icon);
        }
        // 2 - Label (prefer RichTextLabel if provided)
        if (!string.IsNullOrEmpty(_richLabelText))
        {
            _richLabel = new RichTextLabel { Name = "RichLabel" };
            _richLabel.ScrollActive = false;
            _richLabel.BbcodeEnabled = RichLabelUseBBCode;
            _richLabel.MouseFilter = MouseFilterEnum.Pass;
            AddChild(_richLabel);
            _richLabel.SetAnchorsAndOffsetsPreset(Control.LayoutPreset.FullRect);
            ApplyLabelPaddingOffsets(_richLabel);
        }
        else if (!string.IsNullOrEmpty(_labelText))
        {
            _label = new Label { Name = "Label", Text = _labelText };
            AddChild(_label);
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
        // 4 - Selected/Toggled Overlay (depends on EnableSelectedOverlay)
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
        bool needOverlay = EnableSelectedOverlay && (_isSelected || _isToggled);
        // Recreate if missing, invalid, or not parented to this control
        bool overlayAlive = _overlay != null && IsInstanceValid(_overlay) && _overlay.GetParent() == this;
        if (needOverlay && !overlayAlive)
        {
            _overlay = new ColorRect { Name = "Overlay", Color = SelectedColor };
            AddChild(_overlay);
            EnsureFullRect(_overlay);
        }
        else if (!needOverlay && overlayAlive)
        {
            RemoveChild(_overlay);
            _overlay.QueueFree();
            _overlay = null;
        }
    }
    private void EnsureHoldFill()
    {
        if (_holdFill == null || !IsInstanceValid(_holdFill))
        {
            _holdFill = new ColorRect { Name = "HoldFill", Color = HoldFillColor };
            _holdFill.MouseFilter = MouseFilterEnum.Pass;
            AddChild(_holdFill);
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
        int idx = 0;
        bool Alive(Control n) => n != null && IsInstanceValid(n) && n.GetParent() == this;
        if (Alive(_panel)) MoveChild(_panel, idx++);
        else if (Alive(_background)) MoveChild(_background, idx++);
        if (Alive(_icon)) MoveChild(_icon, idx++);
        else if (Alive(_defaultThumb)) MoveChild(_defaultThumb, idx++);
        if (Alive(_label)) MoveChild(_label, idx++);
        else if (Alive(_richLabel)) MoveChild(_richLabel, idx++);
        if (Alive(_overlay)) MoveChild(_overlay, idx++);
        if (Alive(_cooldown)) MoveChild(_cooldown, idx++);
        if (Alive(_holdFill)) MoveChild(_holdFill, idx++);
    }
    #endregion
    #region Label Font Sizing
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
    private void FitLabelText()
    {
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
            return;
        }
        if (!EnableTextAutoSize) return;
        if (_fittingLabel) return;
        if (_richLabel != null && IsInstanceValid(_richLabel) && !string.IsNullOrEmpty(_richLabelText))
        {
            FitRichTextLabel();
            return;
        }
        if (_label != null && IsInstanceValid(_label) && !string.IsNullOrEmpty(_label.Text))
        {
            FitPlainLabel();
        }
    }

    // Keep Label and RichTextLabel sizing separate so Label remains stable while we iterate on RichText
    private void FitPlainLabel()
    {
        _fittingLabel = true;
        try
        {
            var avail = CalculateAvailableArea();
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                CallDeferred(nameof(FitPlainLabel));
                return;
            }
            var fnt = GetRobustFont(_label);
            if (fnt == null) return;
            float wrap = (LabelAutowrap != TextServer.AutowrapMode.Off) ? avail.X : -1f;
            string text = _label.Text ?? string.Empty;
            int bestSize = FindBestFontSize(fnt, text, avail, wrap);
            ApplyFontSettings(_label, fnt, bestSize);
            _label.UpdateMinimumSize();
            _label.QueueRedraw();
            int guard2 = 0;
            while (bestSize > MinFontSize && guard2 < 64)
            {
                var sz = MeasureParagraph(fnt, text, wrap, bestSize);
                if (sz.X <= avail.X && sz.Y <= avail.Y) break;
                bestSize--;
                ApplyFontSettings(_label, fnt, bestSize);
                _label.UpdateMinimumSize();
                _label.QueueRedraw();
                guard2++;
            }
        }
        finally { _fittingLabel = false; }
    }

    private int _richCurrentFontSize = -1;
    private int _richVerifyPasses = 0;
    private void FitRichTextLabel()
    {
        _fittingLabel = true;
        try
        {
            var avail = CalculateAvailableArea();
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                CallDeferred(nameof(FitRichTextLabel));
                return;
            }
            var fnt = LabelFont ?? ThemeDB.FallbackFont;
            if (fnt == null) return;
            string plain = StripKnownBBCode(_richLabelText);
            float wrap = (LabelAutowrap != TextServer.AutowrapMode.Off) ? avail.X : -1f;
            int best = FindBestFontSize(fnt, plain, avail, wrap);
            ApplyRichLabelFontOverrides(_richLabel, fnt, best);
            _richLabel.UpdateMinimumSize();
            _richLabel.QueueRedraw();
            _richCurrentFontSize = best;
            // Quick clamp pass
            int guard = 0;
            while (best > MinFontSize && guard < 32)
            {
                var overH = _richLabel.GetContentHeight() > avail.Y;
                var sz = MeasureParagraph(fnt, plain, wrap, best);
                var overW = sz.X > avail.X;
                if (!overH && !overW) break;
                best--;
                ApplyRichLabelFontOverrides(_richLabel, fnt, best);
                _richCurrentFontSize = best;
                guard++;
            }
            // Deferred verification to allow layout to settle
            _richVerifyPasses = 0;
            CallDeferred(nameof(VerifyRichTextFit));
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
        string plain = StripKnownBBCode(_richLabelText ?? string.Empty);
        float wrap = (LabelAutowrap != TextServer.AutowrapMode.Off) ? avail.X : -1f;
        int size = _richCurrentFontSize > 0 ? _richCurrentFontSize : MinFontSize;
        int guard = 0;
        // Ensure latest layout info
        _richLabel.UpdateMinimumSize();
        _richLabel.QueueRedraw();
        while (size > MinFontSize && guard < 64)
        {
            bool overH = _richLabel.GetContentHeight() > avail.Y;
            var wsize = MeasureParagraph(fnt, plain, wrap, size).X;
            bool overW = wsize > avail.X;
            if (!overH && !overW) break;
            size--;
            ApplyRichLabelFontOverrides(_richLabel, fnt, size);
            _richLabel.UpdateMinimumSize();
            _richLabel.QueueRedraw();
            _richCurrentFontSize = size;
            guard++;
        }
        // If still overflowing (layout not settled), retry next frame with a cap on passes
        bool stillOver = _richLabel.GetContentHeight() > avail.Y || MeasureParagraph(fnt, plain, wrap, size).X > avail.X;
        if (stillOver && _richVerifyPasses < 8)
        {
            _richVerifyPasses++;
            CallDeferred(nameof(VerifyRichTextFit));
        }
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
    private int FindBestFontSize(Font font, string text, Vector2 availableArea, float wrapWidth = -1f)
    {
        int lo = MinFontSize;
        int hi = MaxFontSize;
        int best = lo;
        while (lo <= hi)
        {
            int mid = (lo + hi) / 2;
            var textSize = MeasureParagraph(font, text, wrapWidth, mid);
            if (textSize.X <= availableArea.X && textSize.Y <= availableArea.Y)
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
        var para = new TextParagraph();
        para.Alignment = LabelHorizontalAlignment;
        if (wrapWidth > 0) para.Width = wrapWidth; // 0 = no wrap
        para.AddString(text ?? string.Empty, font, fontSize);
        return para.GetSize();
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
    #region Visual State & Theme
    private void ApplyVisualState()
    {
        // Ensure required children exist based on current flags/state
        if (BackgroundType == BackgroundMode.UsePanel && _panel == null)
        {
            _panel = CreateChildNodeAtPosition<Panel>("Panel", 0);
            ConfigurePanel(_panel);
            ApplyPanelStyling();
        }
        // Ensure overlay co-exists with panel and others
        bool overlayAlive = _overlay != null && IsInstanceValid(_overlay) && _overlay.GetParent() == this;
        if (EnableSelectedOverlay && (_isSelected || _isToggled) && !overlayAlive)
        {
            _overlay = CreateChildNodeAtPosition<ColorRect>("Overlay", GetChildCount());
        }
        // Panel
        if (BackgroundType == BackgroundMode.UsePanel && _panel != null && IsInstanceValid(_panel))
        {
            _panel.Visible = true;
            _panel.Modulate = PanelModulate;
            if (PanelStyleBox != null)
                _panel.AddThemeStyleboxOverride("panel", PanelStyleBox);
            ApplyInvert(_panel);
        }
        // Background
        if (_background != null && IsInstanceValid(_background))
        {
            _background.Texture = BackgroundTexture;
            _background.FlipH = BackgroundFlipH;
            _background.FlipV = BackgroundFlipV;
            _background.ExpandMode = BackgroundExpandMode;
            _background.StretchMode = BackgroundStretchMode;
            _background.Modulate = BackgroundModulate;
            ApplyInvert(_background);
        }
        // Icon
        if (_icon != null && IsInstanceValid(_icon))
        {
            _icon.Texture = IconTexture;
            _icon.FlipH = IconFlipH;
            _icon.FlipV = IconFlipV;
            _icon.ExpandMode = IconExpandMode;
            _icon.StretchMode = IconStretchMode;
            _icon.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
            _icon.Modulate = IconModulate;
            ApplyInvert(_icon);
        }
        // Label
        if (_label != null && IsInstanceValid(_label))
        {
            _label.Text = LabelText;
            _label.HorizontalAlignment = LabelHorizontalAlignment;
            _label.VerticalAlignment = LabelVerticalAlignment;
            _label.AutowrapMode = LabelAutowrap;
            if (LabelFont != null)
                _label.AddThemeFontOverride("font", LabelFont);
            _label.AddThemeColorOverride("font_color", _labelTextColor);
            _label.Modulate = TextModulate;
            ApplyLabelPaddingOffsets(_label);
            ApplyInvert(_label);
        }
        // Rich Label
        if (_richLabel != null && IsInstanceValid(_richLabel))
        {
            _richLabel.BbcodeEnabled = RichLabelUseBBCode;
            _richLabel.Text = _richLabelText;
            _richLabel.HorizontalAlignment = LabelHorizontalAlignment;
            _richLabel.AutowrapMode = LabelAutowrap;
            if (LabelFont != null)
            {
                foreach (var key in new[] { "normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font" })
                    _richLabel.AddThemeFontOverride(key, LabelFont);
            }
            _richLabel.AddThemeColorOverride("default_color", _labelTextColor);
            _richLabel.Modulate = TextModulate;
            ApplyLabelPaddingOffsets(_richLabel);
            ApplyInvert(_richLabel);
        }
        // Overlay
        if (EnableSelectedOverlay && _overlay != null && IsInstanceValid(_overlay))
        {
            _overlay.Visible = true;
            _overlay.Color = SelectedColor;
            ApplyInvert(_overlay);
        }
        // Cooldown live colors
        if (_cooldown != null && IsInstanceValid(_cooldown))
            _cooldown.Color = CooldownColor;
        if (_holdFill != null && IsInstanceValid(_holdFill))
            _holdFill.Color = HoldFillColor;

        // Maintain correct draw order after any add/remove during state application
        ReorderChildren();
    }
    private void ApplyInvert(Control node)
    {
        bool usePress = InvertModes.HasFlag(InvertDisplayModes.Press);
        bool useToggle = InvertModes.HasFlag(InvertDisplayModes.Toggle);
        bool useHover = InvertModes.HasFlag(InvertDisplayModes.Hover);
        bool useHold = InvertModes.HasFlag(InvertDisplayModes.Hold);
        bool shouldInvert = (_isPressed && usePress)
                            || (_isToggled && useToggle)
                            || (_isHovering && useHover)
                            || (_isHolding && useHold);
        if (_invertMaterial != null && shouldInvert)
            node.Material = _invertMaterial;
        else
            node.Material = null;
    }
    private void ApplyFontSettings(Label label, Font font, int fontSize)
    {
        label.AddThemeFontOverride("font", font);
        label.AddThemeFontSizeOverride("font_size", fontSize);
    }
    private void ApplyRichLabelFontOverrides(RichTextLabel rtl, Font font, int fontSize)
    {
        if (rtl == null || !IsInstanceValid(rtl)) return;
        foreach (var key in new[] { "normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font" })
            rtl.AddThemeFontOverride(key, font);
        foreach (var key in new[] { "normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size" })
            rtl.AddThemeFontSizeOverride(key, fontSize);
    }
    private void InvalidateVisualState()
    {
        _lastVisualState = null;
        ApplyVisualState();
        ApplyThemeNow();
    }
    private void ApplyThemeNow()
    {
        if (_themeApplying) return;
        _themeApplying = true;
        try
        {
            if (_label != null && IsInstanceValid(_label))
                _label.Theme = Theme;
            if (_richLabel != null && IsInstanceValid(_richLabel))
                _richLabel.Theme = Theme;
            if (_icon != null && IsInstanceValid(_icon))
                _icon.Theme = Theme;
        }
        finally
        {
            _themeApplying = false;
        }
    }
    private void ApplyThemeToChildren()
    {
        if (_label != null && IsInstanceValid(_label))
            _label.Theme = Theme;
        if (_richLabel != null && IsInstanceValid(_richLabel))
            _richLabel.Theme = Theme;
        if (_icon != null && IsInstanceValid(_icon))
            _icon.Theme = Theme;
    }
    #endregion
    #region Panel Styling
    private void ApplyPanelStyling()
    {
        if (BackgroundType != BackgroundMode.UsePanel)
        {
            var panel = GetNodeOrNull<Panel>("Panel");
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
        _cooldownActive = true;
        _cooldownTimeLeft = CooldownDuration;
        EnsureCooldown();
        UpdateCooldownVisual();
        SetProcess(true);
        CallDeferred(nameof(ResetPressedVisualsAfterCooldownStart));
    }
    private void ResetPressedVisualsAfterCooldownStart()
    {
        // Clear pressed so invert-on-press reverts, but keep hover state
        // so invert-on-hover can continue to work during cooldown.
        _isPressed = false;
        _isHolding = false;
        EndSwiping();
        EnableHoverTopLevel(false);
        ApplyVisualState();
    }

    private void EnsureDefaultThumb()
    {
        if (_defaultThumb == null || !IsInstanceValid(_defaultThumb))
        {
            _defaultThumb = new Panel { Name = "DefaultThumb" };
            _defaultThumb.MouseFilter = MouseFilterEnum.Pass;
            AddChild(_defaultThumb);
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
            _cooldown = new ColorRect { Name = "Cooldown", Color = CooldownColor };
            _cooldown.MouseFilter = MouseFilterEnum.Pass;
            AddChild(_cooldown);
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
    private Panel GetOrCreatePanel()
    {
        var panel = GetNodeOrNull<Panel>("Panel");
        if (panel == null)
        {
            // Panel always goes at position 0
            panel = CreateChildNodeAtPosition<Panel>("Panel", 0);
            ConfigurePanel(panel);
        }
        return panel;
    }
    private T CreateChildNodeAtPosition<T>(string name, int position) where T : Control, new()
    {
        var node = new T
        {
            Name = name,
            MouseFilter = MouseFilterEnum.Ignore
        };
        AddChild(node);
        MoveChild(node, position);
        node.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        node.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        node.SizeFlagsVertical = SizeFlags.ExpandFill;
        return node;
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
        if (_icon != null && IsInstanceValid(_icon)) _icon.PivotOffset = _icon.Size / 2.0f;
        if (_label != null && IsInstanceValid(_label)) _label.PivotOffset = _label.Size / 2.0f;
        if (_overlay != null && IsInstanceValid(_overlay)) _overlay.PivotOffset = _overlay.Size / 2.0f;
        if (_richLabel != null && IsInstanceValid(_richLabel)) _richLabel.PivotOffset = _richLabel.Size / 2.0f;
    }
    private Control GetExternalJoystickArea()
    {
        if (JoystickAreaExternalPath == null || JoystickAreaExternalPath.IsEmpty) return null;
        return GetNodeOrNull<Control>(JoystickAreaExternalPath);
    }
    private void EnsureAndRefreshJoystickArea(Vector2 homeCenterGlobal)
    {
        if (!EnableJoystickArea) return;
        var target = GetExternalJoystickArea();
        if (target == null)
        {
            if (_vjAreaPanel == null || !IsInstanceValid(_vjAreaPanel))
            {
                _vjAreaPanel = new Panel();
                _vjAreaPanel.Name = "JoystickArea";
                _vjAreaPanel.TopLevel = true;
                _vjAreaPanel.MouseFilter = MouseFilterEnum.Ignore;
                _vjAreaPanel.ZIndex = -1000;
                AddChild(_vjAreaPanel);
            }
            target = _vjAreaPanel;
            var sb = new StyleBoxFlat();
            sb.BgColor = new Color(0, 0, 0, 0);
            sb.BorderColor = JoystickAreaColor;
            sb.BorderWidthTop = sb.BorderWidthBottom = sb.BorderWidthLeft = sb.BorderWidthRight = JoystickAreaThickness;
            _vjAreaPanel.AddThemeStyleboxOverride("panel", sb);
        }
        var clampRect = GetFollowClampRect();
        bool useCircle = (ClampShape == JoystickClampShape.Circle) && !JoystickAreaUseRectForClamp;
        if (useCircle)
        {
            float radius = JoystickRadiusPx > 0 ? JoystickRadiusPx : ComputeAutoJoystickRadius(homeCenterGlobal, clampRect);
            var size = new Vector2(radius * 2f, radius * 2f);
            if (target is Panel p && p.GetThemeStylebox("panel") is StyleBoxFlat flat)
            {
                int r = (int)Mathf.Round(radius);
                flat.CornerRadiusTopLeft = flat.CornerRadiusTopRight = flat.CornerRadiusBottomLeft = flat.CornerRadiusBottomRight = r;
            }
            target.Size = size;
            target.GlobalPosition = homeCenterGlobal - size / 2f;
        }
        else
        {
            Vector2 halfExtents = JoystickRectSizePx != Vector2.Zero ? JoystickRectSizePx / 2f : ComputeAutoJoystickHalfExtents(homeCenterGlobal, clampRect);
            var size = halfExtents * 2f;
            if (target is Panel p && p.GetThemeStylebox("panel") is StyleBoxFlat flat)
            {
                flat.CornerRadiusTopLeft = flat.CornerRadiusTopRight = flat.CornerRadiusBottomLeft = flat.CornerRadiusBottomRight = 0;
            }
            target.Size = size;
            target.GlobalPosition = homeCenterGlobal - size / 2f;
        }
    }
    private void SetJoystickAreaVisible(bool vis)
    {
        var external = GetExternalJoystickArea();
        if (external != null)
            external.Visible = vis;
        else if (_vjAreaPanel != null && IsInstanceValid(_vjAreaPanel))
            _vjAreaPanel.Visible = vis;
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
        if (BoundsSource != null)
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
    private void EmitJoystickAxisFor(Vector2 pointerGlobal)
    {
        // Current stick center (global)
        var currentCenter = GlobalPosition + Size / 2f;
        // Clamp pointer to movement bounds to keep axis consistent with visible clamp
        var clamp = GetFollowClampRect(); // already respects BoundsSource or parent
        var clamped = new Vector2(
            Mathf.Clamp(pointerGlobal.X, clamp.Position.X, clamp.Position.X + clamp.Size.X),
            Mathf.Clamp(pointerGlobal.Y, clamp.Position.Y, clamp.Position.Y + clamp.Size.Y)
        );
        // Use clamped point to infer the target center (where we tried to move to)
        // Then compute axis from home -> target
        var delta = (clamped - _vjHomeGlobal);
        Vector2 axis;
        bool useCircle = (ClampShape == JoystickClampShape.Circle);
        if (useCircle)
        {
            float radius = JoystickRadiusPx > 0
                ? JoystickRadiusPx
                : ComputeAutoJoystickRadius(_vjHomeGlobal, clamp);
            float len = delta.Length();
            axis = (len < 1e-4f || radius < 1e-4f) ? Vector2.Zero : (delta / radius);
            if (axis.Length() > 1f) axis = axis.Normalized();
        }
        else
        {
            Vector2 halfExtents = JoystickRectSizePx != Vector2.Zero
                ? JoystickRectSizePx / 2f
                : ComputeAutoJoystickHalfExtents(_vjHomeGlobal, clamp);
            float hx = Math.Max(1e-4f, halfExtents.X);
            float hy = Math.Max(1e-4f, halfExtents.Y);
            axis = new Vector2(Mathf.Clamp(delta.X / hx, -1f, 1f), Mathf.Clamp(delta.Y / hy, -1f, 1f));
        }
        // Deadzone
        if (axis.Length() < JoystickDeadzone)
            axis = Vector2.Zero;
        EmitSignal(SignalName.JoystickAxis, axis);
    }
    private float ComputeAutoJoystickRadius(Vector2 homeCenterGlobal, Rect2 clamp)
    {
        // Max circle that fits inside the clamp rect around the home center
        float left = (float)(homeCenterGlobal.X - clamp.Position.X);
        float right = (float)((clamp.Position.X + clamp.Size.X) - homeCenterGlobal.X);
        float top = (float)(homeCenterGlobal.Y - clamp.Position.Y);
        float bottom = (float)((clamp.Position.Y + clamp.Size.Y) - homeCenterGlobal.Y);
        return Math.Max(1f, Math.Min(Math.Min(left, right), Math.Min(top, bottom)));
    }
    private Vector2 ComputeAutoJoystickHalfExtents(Vector2 homeCenterGlobal, Rect2 clamp)
    {
        float left = (float)(homeCenterGlobal.X - clamp.Position.X);
        float right = (float)((clamp.Position.X + clamp.Size.X) - homeCenterGlobal.X);
        float top = (float)(homeCenterGlobal.Y - clamp.Position.Y);
        float bottom = (float)((clamp.Position.Y + clamp.Size.Y) - homeCenterGlobal.Y);
        return new Vector2(Math.Max(1f, Math.Min(left, right)), Math.Max(1f, Math.Min(top, bottom)));
    }
    public void StartVirtualJoystickAt(Vector2 globalPoint)
    {
        // Allow programmatic start if either the explicit flag is on
        // or this button is configured to use VirtualJoystick follow mode.
        if (!EnableVirtualJoystick && FollowMode != FollowModeEnum.VirtualJoystick)
            return;
        _vjActive = true;
        _vjHomeGlobal = GlobalPosition + Size / 2f;
        // Keep visuals consistent with a press
        _isPressed = true;
        ApplyVisualState();
        // Allow input to pass through this button (so underlying controls can hover)
        _vjSavedMouseFilter = MouseFilter;
        MouseFilter = MouseFilterEnum.Ignore;
        // Move in screen space and clamp to bounds
        EnableHoverTopLevel(true);
        if (JoystickSnapToInput)
            MoveToGlobal(globalPoint);
        if (JoystickHideWhenInactive)
            Visible = true;
        EmitSignal(SignalName.JoystickStarted);
        EmitJoystickAxisFor(globalPoint);
        if (EnableJoystickArea)
        {
            EnsureAndRefreshJoystickArea(_vjHomeGlobal);
            SetJoystickAreaVisible(true);
        }
    }
    public void UpdateVirtualJoystick(Vector2 globalPoint)
    {
        if (!_vjActive) return;
        if (JoystickSnapToInput)
            MoveToGlobal(globalPoint);
        EmitJoystickAxisFor(globalPoint);
    }
    public void StopVirtualJoystick()
    {
        if (!_vjActive) return;
        EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
        EmitSignal(SignalName.JoystickEnded);
        if (JoystickResetOnRelease)
            GlobalPosition = _vjHomeGlobal - Size / 2f;
        _vjActive = false;
        _isPressed = false;
        _isHolding = false;
        EndSwiping(); // clear swiping when joystick session ends
        ApplyVisualState();
        // Restore original mouse filter and top-level state
        MouseFilter = _vjSavedMouseFilter;
        EnableHoverTopLevel(false);
        if (EnableJoystickArea && !JoystickAreaPersistent)
            SetJoystickAreaVisible(false);
        if (JoystickHideWhenInactive)
            Visible = false;
    }
    #endregion
    #region Property List Builder
    private Array<Dictionary> BuildPropertyList()
    {
        // Do not hide or rewrite any properties dynamically; return an empty list
        // so the Inspector shows all exported properties as-is.
        return new Array<Dictionary>();
    }
    // Debounced inspector refresh to avoid recursive updates
    private bool _pendingInspectorRefresh = false;
    private void SafeNotifyPropertyListChanged()
    {
        if (!Engine.IsEditorHint()) return;
        if (_pendingInspectorRefresh) return;
        _pendingInspectorRefresh = true;
        CallDeferred(nameof(DoNotifyPropertyListChanged));
    }
    private void DoNotifyPropertyListChanged()
    {
        _pendingInspectorRefresh = false;
        NotifyPropertyListChanged();
    }
    #endregion
    #region Logging
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
