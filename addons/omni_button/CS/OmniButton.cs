using Godot;
using Godot.Collections;
using System;
using System.Collections.Generic;


[Tool]
[GlobalClass, GodotClassName("OmniButton")]
public partial class OmniButton : Control
{
    public enum CooldownDirection
    {
        BottomToTop = 0,
        TopToBottom = 1,
        LeftToRight = 2,
        RightToLeft = 3
    }
    #region Signals
    [Signal] public delegate void PressedEventHandler();
    [Signal] public delegate void ReleasedEventHandler();
    [Signal] public delegate void HoverInEventHandler();
    [Signal] public delegate void HoverOutEventHandler();
    [Signal] public delegate void ToggledEventHandler(bool pressed);
    [Signal] public delegate void HoldEventHandler();
    [Signal] public delegate void SwipeEventHandler(Vector2 direction);
    [Signal] public delegate void LogEventHandler(string message);
    [Signal] public delegate void WarningEventHandler(string message);
    [Signal] public delegate void ErrorEventHandler(string message);
    // New: joystick lifecycle + axis (normalized -1..1 in a circle)
    [Signal] public delegate void JoystickStartedEventHandler();
    [Signal] public delegate void JoystickAxisEventHandler(Vector2 axis);
    [Signal] public delegate void JoystickEndedEventHandler();
    #endregion

    #region Exported Properties
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

    // Display: shown before behavior for quicker setup
    [ExportGroup("Content Display")]
    [Export]
    public bool EnablePanel
    {
        get => _enablePanel;
        set
        {
            _enablePanel = value;
            RefreshEditorVisual(children: true, panelStyling: true);
        }
    }
    private bool _enablePanel = false;
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

    [Export]
    public string LabelText
    {
        get => _labelText;
        set
        {
            _labelText = value;
            SetupChildren();
            ApplyVisualState();
            FitLabelText();
        }
    }
    private string _labelText = "";
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

    [Export]
    public Color SelectedColor
    {
        get => _selectedColor;
        set { _selectedColor = value; RefreshEditorVisual(); }
    }
    private Color _selectedColor = new Color(1, 1, 1, 0.3f);
    [Export]
    public Color UnselectedColor
    {
        get => _unselectedColor;
        set { _unselectedColor = value; RefreshEditorVisual(); }
    }
    private Color _unselectedColor = new Color(0, 0, 0, 0.2f);

    // Behavior
    [ExportGroup("Actions")]
    [ExportSubgroup("Pressed")]
    [Export] public bool EnablePressedActions { get; set; } = false;
    [Export] public Callable PressedAction { get; set; }
    [ExportSubgroup("Released")]
    [Export] public bool EnableReleasedActions { get; set; } = false;
    [Export] public Callable ReleasedAction { get; set; }
    [ExportSubgroup("Hover")]
    [Export]
    public bool EnableHoverActions
    {
        get => _enableHoverActions;
        set { _enableHoverActions = value; RefreshEditorVisual(); }
    }
    private bool _enableHoverActions = false;
    [Export] public Callable HoverInAction { get; set; }
    [Export] public Callable HoverOutAction { get; set; }
    [ExportSubgroup("Toggle")]
    [Export] public bool EnableToggleActions { get; set; } = false;
    [Export] public Callable ToggledAction { get; set; }
    [ExportSubgroup("Hold")]
    [Export] public bool EnableHoldActions { get; set; } = false;
    [Export] public Callable HoldAction { get; set; }
    [ExportSubgroup("Swipe")]
    [Export] public bool EnableSwipeActions { get; set; } = false;
    [Export] public Callable SwipeAction { get; set; }
    [ExportSubgroup("Logging")]
    [Export] public bool EnableLogActions { get; set; } = false;
    [Export] public Callable LogAction { get; set; }
    [Export] public bool EnableWarningActions { get; set; } = false;
    [Export] public Callable WarningAction { get; set; }
    [Export] public bool EnableErrorActions { get; set; } = false;
    [Export] public Callable ErrorAction { get; set; }

    [ExportGroup("Input")]
    [Export] public Control? BoundsSource { get; set; }
    [Export] public Vector2 HitSlop { get; set; } = Vector2.Zero;

    [ExportGroup("Swipe & Hold")]
    [ExportSubgroup("Swipe")]
    [Export(PropertyHint.Range, "0.0,1000.0,1.0")] public float SwipeThreshold { get; set; } = 20f;
    [ExportSubgroup("Hold")]
    [Export(PropertyHint.Range, "0.05,5.0,0.05")] public float HoldDuration { get; set; } = 0.5f;
    [Export] public bool EnableHoldBuildUp { get; set; } = false;
    [Export] public Color HoldFillColor { get; set; } = new Color(1, 1, 1, 0.25f);
    [Export] public CooldownDirection HoldFillDirection { get; set; } = CooldownDirection.BottomToTop;

    [ExportSubgroup("Follow Input")]
    [Export] public bool FollowOnPress { get; set; } = false;
    [Export] public bool FollowWhileHeld { get; set; } = false;
    [Export] public bool ClampToBounds { get; set; } = true;

    [ExportGroup("Cooldown")]
    [Export] public bool EnableCooldown { get; set; } = false;
    [Export(PropertyHint.Range, "0.05,60.0,0.05")] public float CooldownDuration { get; set; } = 1.0f;
    [Export] public bool CooldownOnPress { get; set; } = false;
    [Export] public bool CooldownOnRelease { get; set; } = false;
    [Export] public bool CooldownStartFilled { get; set; } = false;
    [Export] public Color CooldownColor { get; set; } = new Color(0, 0, 0, 0.4f);
    [Export] public CooldownDirection CooldownFillDirection { get; set; } = CooldownDirection.BottomToTop;
    [Export] public bool SuspendHoverScaleDuringCooldown { get; set; } = false;
    [Export] public bool AllowHoldDuringCooldown { get; set; } = false;
    [Export] public bool HideCooldownDuringHoldBuildUp { get; set; } = true;



    [ExportGroup("Hover Scaling")]
    [Export]
    public bool EnableHoverScale
    {
        get => _enableHoverScale;
        set { _enableHoverScale = value; RefreshEditorVisual(); }
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

    [ExportGroup("Label Settings")]
    [Export]
    public Font? LabelFont { get => _labelFont; set { _labelFont = value; RefreshEditorVisual(); } }
    private Font? _labelFont;
    [Export]
    public Color LabelTextColor { get => _labelTextColor; set { _labelTextColor = value; RefreshEditorVisual(); } }
    private Color _labelTextColor = Colors.White;
    [Export(PropertyHint.Range, "6,300,1")]
    public int MinFontSize { get => _minFontSize; set { _minFontSize = value; FitLabelText(); } }
    private int _minFontSize = 12;
    [Export(PropertyHint.Range, "6,300,1")]
    public int MaxFontSize { get => _maxFontSize; set { _maxFontSize = value; FitLabelText(); } }
    private int _maxFontSize = 100;
    [Export]
    public HorizontalAlignment LabelHorizontalAlignment { get => _labelHAlign; set { _labelHAlign = value; RefreshEditorVisual(); } }
    private HorizontalAlignment _labelHAlign = HorizontalAlignment.Center;
    [Export]
    public VerticalAlignment LabelVerticalAlignment { get => _labelVAlign; set { _labelVAlign = value; RefreshEditorVisual(); } }
    private VerticalAlignment _labelVAlign = VerticalAlignment.Center;
    [Export]
    public TextServer.AutowrapMode LabelAutowrap { get => _labelAutowrap; set { _labelAutowrap = value; RefreshEditorVisual(); } }
    private TextServer.AutowrapMode _labelAutowrap = TextServer.AutowrapMode.Word;

    [ExportGroup("Panel Settings")]
    [Export]
    public string PanelThemeType { get => _panelThemeType; set { _panelThemeType = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private string _panelThemeType = "Panel";
    [Export]
    public string PanelThemeVariation { get => _panelThemeVariation; set { _panelThemeVariation = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private string _panelThemeVariation = "";
    [Export]
    public StyleBox? PanelStyleBox { get => _panelStyleBox; set { _panelStyleBox = value; ApplyPanelStyling(); RefreshEditorVisual(); } }
    private StyleBox? _panelStyleBox;

    [ExportGroup("Icon Settings")]
    [Export]
    public TextureRect.ExpandModeEnum IconExpandMode { get => _iconExpand; set { _iconExpand = value; RefreshEditorVisual(); } }
    private TextureRect.ExpandModeEnum _iconExpand = TextureRect.ExpandModeEnum.FitWidthProportional;
    [Export]
    public TextureRect.StretchModeEnum IconStretchMode { get => _iconStretch; set { _iconStretch = value; RefreshEditorVisual(); } }
    private TextureRect.StretchModeEnum _iconStretch = TextureRect.StretchModeEnum.Scale;
    [Export]
    public bool IconFlipH { get => _iconFlipH; set { _iconFlipH = value; RefreshEditorVisual(); } }
    private bool _iconFlipH = false;
    [Export]
    public bool IconFlipV { get => _iconFlipV; set { _iconFlipV = value; RefreshEditorVisual(); } }
    private bool _iconFlipV = false;

    [ExportGroup("Invert Display")]
    [Export]
    public bool InvertDisplayOnPress { get => _invertOnPress; set { _invertOnPress = value; RefreshEditorVisual(); } }
    private bool _invertOnPress = false;
    [Export]
    public bool InvertDisplayOnToggle { get => _invertOnToggle; set { _invertOnToggle = value; RefreshEditorVisual(); } }
    private bool _invertOnToggle = false;
    [Export]
    public bool InvertDisplayOnHover { get => _invertOnHover; set { _invertOnHover = value; RefreshEditorVisual(); } }
    private bool _invertOnHover = false;

    [ExportGroup("Virtual Joystick")]
    [Export] public bool EnableVirtualJoystick { get; set; } = false;
    // Radius used to normalize axis (pixels). 0 means auto: max circle inside clamp rect from the home center.
    [Export(PropertyHint.Range, "0,2048,1")] public int JoystickRadiusPx { get; set; } = 0;
    [Export(PropertyHint.Range, "0.0,1.0,0.01")] public float JoystickDeadzone { get; set; } = 0.1f;
    [Export] public bool JoystickResetOnRelease { get; set; } = true;

    [ExportGroup("Theme Variations")]
    [Export] public string ThemeTypeName { get; set; } = "OmniButton";
    [Export] public string VariantNormal { get; set; } = "normal";
    [Export] public string VariantPressed { get; set; } = "pressed";
    [Export] public string VariantHover { get; set; } = "hover";
    [Export] public string VariantToggled { get; set; } = "toggled";
    [Export] public string VariantSelected { get; set; } = "selected";
    [Export] public string VariantDisabled { get; set; } = "disabled";
    #endregion

    #region Private State
    private Panel _panel;
    private TextureRect _icon;
    private Label _label;
    private ColorRect _overlay;
    private ColorRect _cooldown;
    private ColorRect _holdFill;
    private ShaderMaterial _invertMaterial;
    private string? _lastVisualState;
    private float _hoverTargetScale = 1.0f;
    private Vector2 _originalScale = Vector2.One;
    private static readonly string[] OwnSignals = { "Pressed", "Toggled", "Released", "Log", "Warning", "Error", "Hold", "Swipe", "HoverIn", "HoverOut" };
    private bool _isPressed = false;
    private bool _isHovering = false;
    private bool _isToggled = false;
    private bool _isSelected = false;
    private bool _isHolding = false;
    private bool _fittingLabel = false;
    private bool _themeApplying = false;
    private Vector2 _swipeStart = Vector2.Zero;
    private double _holdTimer = 0;
    private bool _cooldownActive = false;
    private double _cooldownTimeLeft = 0.0;

    // Virtual joystick session state
    private bool _vjActive = false;
    private Vector2 _vjHomeGlobal; // center of the button at press time (global)
    private MouseFilterEnum _vjSavedMouseFilter = MouseFilterEnum.Stop;
    #endregion

    #region Godot Lifecycle
    public override void _EnterTree() => Initialize();
    public override void _ExitTree() => Cleanup();

    public override void _Ready() => Setup();

    public override void _Process(double delta) => ProcessHoverScaling(delta);

    public override Array<Dictionary> _GetPropertyList() => BuildPropertyList();

    public override void _GuiInput(InputEvent @event)
    {
        bool inside = IsInputInside(@event);
        if (EnableCooldown && _cooldownActive) return; // disable actions during cooldown

        if (@event is InputEventMouseButton mb && mb.ButtonIndex == MouseButton.Left)
        {
            if (mb.Pressed)
            {
                if (!inside) return; // only react to press when inside
                _isPressed = true;
                _holdTimer = 0;
                _isHolding = false;

                // Virtual joystick start
                if (EnableVirtualJoystick)
                {
                    // Remember the original center as the joystick origin, then move under the pointer.
                    _vjActive = true;
                    _vjHomeGlobal = GlobalPosition + Size / 2f;
                    EnableHoverTopLevel(true);
                    MoveToGlobal(mb.GlobalPosition);
                    EmitSignal(SignalName.JoystickStarted);
                    // Emit first axis immediately
                    EmitJoystickAxisFor(mb.GlobalPosition);
                }
                else if (FollowOnPress)
                {
                    EnableHoverTopLevel(true);
                    MoveToGlobal(mb.GlobalPosition);
                }

                if (EnableSwipeActions)
                    _swipeStart = mb.Position;
                if (EnablePressedActions)
                    EmitSignal(SignalName.Pressed);
                if (EnableToggleActions)
                {
                    _isToggled = !_isToggled;
                    UpdateOverlay();
                    EmitSignal(SignalName.Toggled, _isToggled);
                }
                if (EnableCooldown && CooldownOnPress)
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
                _swipeStart = Vector2.Zero;
                if (EnableReleasedActions && inside)
                    EmitSignal(SignalName.Released);
                if (EnableCooldown && CooldownOnRelease)
                    StartCooldown();
                if (_holdFill != null && IsInstanceValid(_holdFill))
                    RemoveHoldFill();

                // Virtual joystick end
                if (_vjActive)
                {
                    EmitSignal(SignalName.JoystickAxis, Vector2.Zero);
                    EmitSignal(SignalName.JoystickEnded);
                    if (JoystickResetOnRelease)
                    {
                        // Snap back to the original home center
                        GlobalPosition = _vjHomeGlobal - Size / 2f;
                    }
                    _vjActive = false;
                }

                // Stop following when released
                EnableHoverTopLevel(false);

                ApplyVisualState();
            }
        }
        else if (_isPressed && @event is InputEventMouseMotion mm)
        {
            if (EnableVirtualJoystick && _vjActive)
            {
                MoveToGlobal(mm.GlobalPosition);
                EmitJoystickAxisFor(mm.GlobalPosition);
            }
            else if (FollowWhileHeld)
            {
                MoveToGlobal(mm.GlobalPosition);
            }
        }
        else if (_isPressed && @event is InputEventScreenDrag sd)
        {
            if (EnableVirtualJoystick && _vjActive)
            {
                MoveToGlobal(sd.Position);
                EmitJoystickAxisFor(sd.Position);
            }
            else if (FollowWhileHeld)
            {
                MoveToGlobal(sd.Position);
            }
        }
        else if (EnableSwipeActions && @event is InputEventScreenDrag drag)
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
        else if (EnableSwipeActions && _isPressed && @event is InputEventMouseMotion motion)
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
    }

    public override void _Notification(int what)
    {
        switch (what)
        {
            case (int)NotificationResized:
                FitLabelText();
                if (EnablePanel) QueueRedraw();
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

        if (EnableSelectedOverlay && Selected && !EnablePanel)
            EnablePanel = true;

        var shaderPath = "res://addons/omni_button/Shader/InvertColor.tres";
        if (ResourceLoader.Exists(shaderPath))
            _invertMaterial = GD.Load<ShaderMaterial>(shaderPath);

        SetupChildren();
        ApplyPanelStyling();
        ApplyVisualState();
        FitLabelText();
    }

    private void Cleanup()
    {
        DisconnectAllSignalHandlers();
        _label = null;
        _icon = null;
        _overlay = null;
        _cooldown = null;
        _holdFill = null;
    }
    #endregion

    #region Processing
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
                if (EnableHoldActions) EmitSignal(SignalName.Hold);
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
                        Disconnect(signal, ((Callable)callable));
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

        if (EnablePressedActions) EmitSignal(SignalName.Pressed);
        if (EnableToggleActions) _isToggled = !_isToggled;
    }

    private void OnReleased()
    {
        if (Disabled) return;
        if (EnableReleasedActions) EmitSignal(SignalName.Released);
    }

    private void OnLog(string type, string message) => EmitSignal(SignalName.Log, type, message);

    private void OnMouseEntered()
    {
        if (Disabled) return;
        _isHovering = true;

        if (EnableHoverActions && !(EnableCooldown && _cooldownActive))
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

        if (EnableHoverActions && !(EnableCooldown && _cooldownActive))
            EmitSignal(SignalName.HoverOut);

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
        _overlay = null;
        _cooldown = null;
        _holdFill = null;

        // 0 - Panel
        if (EnablePanel)
        {
            _panel = new Panel { Name = "Panel" };
            AddChild(_panel);
            ConfigurePanel(_panel);
            EnsureFullRect(_panel);
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

        // 2 - Label
        if (!string.IsNullOrEmpty(LabelText))
        {
            _label = new Label { Name = "Label", Text = LabelText };
            AddChild(_label);
            ConfigureLabel();
        }

        // 3 - Selected/Toggled Overlay (depends on EnableSelectedOverlay)
        UpdateOverlay();

        // 4 - Cooldown (create if enabled in editor or active at runtime)
        if (EnableCooldown && (_cooldownActive || Engine.IsEditorHint()))
        {
            EnsureCooldown();
            UpdateCooldownVisual();
        }

        ReorderChildren();

        if (_panel != null) _panel.MouseFilter = MouseFilterEnum.Pass;
        if (_icon != null) _icon.MouseFilter = MouseFilterEnum.Pass;
        if (_label != null) _label.MouseFilter = MouseFilterEnum.Pass;
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
            _overlay = new ColorRect { Name = "Overlay", Color = _isSelected ? SelectedColor : UnselectedColor };
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

    private void ReorderChildren()
    {
        int idx = 0;
        if (_panel != null) MoveChild(_panel, idx++);
        if (_icon != null) MoveChild(_icon, idx++);
        if (_label != null) MoveChild(_label, idx++);
        if (_overlay != null) MoveChild(_overlay, idx++);
        if (_cooldown != null) MoveChild(_cooldown, idx++);
        if (_holdFill != null) MoveChild(_holdFill, idx++);
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
        if (LabelFont != null)
            _label.AddThemeFontOverride("font", LabelFont);
    }

    private void FitLabelText()
    {
        if (_fittingLabel || _label == null || !IsInstanceValid(_label) || string.IsNullOrEmpty(_label.Text))
            return;

        _fittingLabel = true;
        try
        {
            var avail = CalculateAvailableArea();
            if (avail.X <= 1.0f || avail.Y <= 1.0f)
            {
                return;
            }

            var fnt = GetRobustFont(_label);
            if (fnt == null) return;

            int bestSize = FindBestFontSize(fnt, _label.Text, avail);
            ApplyFontSettings(_label, fnt, bestSize);
        }
        finally
        {
            _fittingLabel = false;
        }
    }
    private Vector2 CalculateAvailableArea()
    {
        return Size - new Vector2(8, 8);
    }

    private Font? GetRobustFont(Label label)
    {
        return label.GetThemeFont("font") ?? ThemeDB.FallbackFont;
    }

    private int FindBestFontSize(Font font, string text, Vector2 availableArea)
    {
        int bestSize = MinFontSize;

        for (int size = MinFontSize; size <= MaxFontSize; size++)
        {
            var textSize = font.GetStringSize(text, HorizontalAlignment.Left, -1, size);
            if (textSize.X <= availableArea.X && textSize.Y <= availableArea.Y)
            {
                bestSize = size;
            }
            else
            {
                break;
            }
        }

        return bestSize;
    }
    #endregion

    #region Visual State & Theme
    private void ApplyVisualState()
    {
        // Ensure required children exist based on current flags/state
        if (EnablePanel && _panel == null)
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
        if (EnablePanel && _panel != null)
        {
            _panel.Visible = true;
            _panel.Modulate = Colors.White;
            if (PanelStyleBox != null)
                _panel.AddThemeStyleboxOverride("panel", PanelStyleBox);
            ApplyInvert(_panel, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover);

        }

        // Icon
        if (_icon != null)
        {
            _icon.Texture = IconTexture;
            _icon.FlipH = IconFlipH;
            _icon.FlipV = IconFlipV;
            _icon.ExpandMode = IconExpandMode;
            _icon.StretchMode = IconStretchMode;
            _icon.TextureFilter = CanvasItem.TextureFilterEnum.Nearest;
            ApplyInvert(_icon, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover);
        }

        // Label
        if (_label != null)
        {
            _label.Text = LabelText;
            _label.HorizontalAlignment = LabelHorizontalAlignment;
            _label.VerticalAlignment = LabelVerticalAlignment;
            _label.AutowrapMode = LabelAutowrap;
            if (LabelFont != null)
                _label.AddThemeFontOverride("font", LabelFont);
            _label.AddThemeColorOverride("font_color", _labelTextColor);
            ApplyInvert(_label, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover);
        }

        // Overlay
        if (EnableSelectedOverlay && _overlay != null && IsInstanceValid(_overlay))
        {
            _overlay.Visible = true;
            _overlay.Color = Selected ? SelectedColor : UnselectedColor;
            ApplyInvert(_overlay, InvertDisplayOnPress, InvertDisplayOnToggle, InvertDisplayOnHover);
        }

        // Cooldown live colors
        if (_cooldown != null && IsInstanceValid(_cooldown))
            _cooldown.Color = CooldownColor;
        if (_holdFill != null && IsInstanceValid(_holdFill))
            _holdFill.Color = HoldFillColor;
    }

    private void ApplyInvert(Control node, bool invertOnPress, bool invertOnToggle, bool invertOnHover)
    {
        bool shouldInvert = (_isPressed && invertOnPress) || (_isToggled && invertOnToggle) || (_isHovering && invertOnHover);
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
        if (_icon != null && IsInstanceValid(_icon))
            _icon.Theme = Theme;
    }

    #endregion

    #region Panel Styling
    private void ApplyPanelStyling()
    {
        if (!EnablePanel)
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
        EnableHoverTopLevel(false);
        ApplyVisualState();
    }

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

    private void EnsureFullRect(Control node)
    {
        if (node == null || !IsInstanceValid(node)) return;
        node.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        node.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        node.SizeFlagsVertical = SizeFlags.ExpandFill;
    }

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
        if (EnableHoverActions)
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

    private void MoveToGlobal(Vector2 globalPoint)
    {
        var half = Size / 2f;
        var desired = globalPoint - half;

        if (ClampToBounds)
        {
            var clamp = GetFollowClampRect();
            desired.X = Mathf.Clamp(desired.X, clamp.Position.X, clamp.Position.X + clamp.Size.X - Size.X);
            desired.Y = Mathf.Clamp(desired.Y, clamp.Position.Y, clamp.Position.Y + clamp.Size.Y - Size.Y);
        }

        GlobalPosition = desired;
    }

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

        float radius = JoystickRadiusPx > 0
            ? JoystickRadiusPx
            : ComputeAutoJoystickRadius(_vjHomeGlobal, clamp);

        float len = delta.Length();
        Vector2 axis = len < 1e-4f || radius < 1e-4f ? Vector2.Zero : (delta / radius);

        // Clamp to unit circle
        if (axis.Length() > 1f)
            axis = axis.Normalized();

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

    public void StartVirtualJoystickAt(Vector2 globalPoint)
    {
        if (!EnableVirtualJoystick) return;

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
        MoveToGlobal(globalPoint);

        EmitSignal(SignalName.JoystickStarted);
        EmitJoystickAxisFor(globalPoint);
    }

    public void UpdateVirtualJoystick(Vector2 globalPoint)
    {
        if (!_vjActive) return;

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
        ApplyVisualState();

        // Restore original mouse filter and top-level state
        MouseFilter = _vjSavedMouseFilter;
        EnableHoverTopLevel(false);
    }
    #endregion

    #region Property List Builder
    private Array<Dictionary> BuildPropertyList()
    {
        var properties = new Array<Dictionary>();

        if (EnableToggleActions)
        {
            properties.Add(new Dictionary
            {
                ["name"] = "toggle_pressed",
                ["type"] = (int)Variant.Type.Bool,
                ["usage"] = (int)PropertyUsageFlags.Default
            });
        }

        return properties;
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
















