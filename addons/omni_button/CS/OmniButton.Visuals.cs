using Godot;
using System;

public partial class OmniButton : Control
{
    #region Visual State & Theme
    internal void ApplyVisualState()
    {
        // Ensure required children exist based on current flags/state
        if (BackgroundType == BackgroundMode.UsePanel && _panel == null)
        {
            _panel = CreateManagedChildAtPosition<Panel>("Panel", 0);
            ConfigurePanel(_panel);
            ApplyPanelStyling();
        }
        EnsureOverlayUnderManagedRoot();
        bool overlayAlive = _overlay != null && IsInstanceValid(_overlay) && _overlay.GetParent() == _managedRoot;
        bool needOverlay = _isSelected;
        if (needOverlay && !overlayAlive)
        {
            EnsureManagedRoot();
            var append = _managedRoot!.GetChildCount();
            _overlay = CreateManagedChildAtPosition<ColorRect>("Overlay", append);
        }
        // Panel
        if (BackgroundType == BackgroundMode.UsePanel && _panel != null && IsInstanceValid(_panel))
        {
            _panel.Visible = true;
            _panel.Modulate = PanelModulate;
            if (PanelStyleBox != null)
                _panel.AddThemeStyleboxOverride("panel", PanelStyleBox);
            ApplyInvert(_panel);
            _panel.ZIndex = 0;
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
            _background.ZIndex = 1;
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
            _icon.ZIndex = 2;
        }
        // Label
        if (_label != null && IsInstanceValid(_label))
        {
            if (!_twActive)
                _label.Text = _text;
            _label.HorizontalAlignment = LabelHorizontalAlignment;
            _label.VerticalAlignment = LabelVerticalAlignment;
            _label.AutowrapMode = LabelAutowrap;
            if (LabelFont != null)
                _label.AddThemeFontOverride("font", LabelFont);
            _label.AddThemeColorOverride("font_color", _labelTextColor);
            _label.Modulate = TextModulate;
            ApplyLabelPaddingOffsets(_label);
            ApplyInvert(_label);
            _label.ZIndex = 3;
        }
        // Rich Label
        if (_richLabel != null && IsInstanceValid(_richLabel))
        {
            _richLabel.BbcodeEnabled = true;
            if (!_twActive)
                _richLabel.Text = _text;
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
            _richLabel.ZIndex = 3;
        }
        // Overlay
        if (_overlay != null && IsInstanceValid(_overlay))
        {
            _overlay.Visible = needOverlay;
            _overlay.Color = SelectedColor;
            ApplyInvert(_overlay);
            _overlay.ZIndex = 4;
        }
        // Cooldown live colors (z above label=3 and overlay=4 so the fill is actually visible)
        if (_cooldown != null && IsInstanceValid(_cooldown))
        {
            _cooldown.Color = CooldownColor;
            _cooldown.ZIndex = 5;
        }
        if (_holdFill != null && IsInstanceValid(_holdFill))
        {
            _holdFill.Color = HoldFillColor;
            _holdFill.ZIndex = 6;
        }

        // Maintain correct draw order after any add/remove during state application
        ReorderChildren();
    }
    private void ApplyInvert(Control node)
    {
        bool usePress = (InvertModes & InvertDisplayModes.Press) != 0;
        bool useToggle = (InvertModes & InvertDisplayModes.Toggle) != 0;
        bool useHover = (InvertModes & InvertDisplayModes.Hover) != 0;
        bool useHold = (InvertModes & InvertDisplayModes.Hold) != 0;
        bool holdActive = _isHolding || (EnableHoldBuildUp && _isPressed && _holdTimer >= HoldDuration);
        bool cooldownActive = _cooldownActive && InvertOnCooldown
            && (CooldownInvertDuration <= 0.0f || _cooldownElapsed <= CooldownInvertDuration);
        bool shouldInvert = (_isPressed && usePress)
                            || (_isToggled && useToggle)
                            || (_isHovering && useHover)
                            || (holdActive && useHold)
                            || cooldownActive;
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
        RequestRefresh(false, false, false);
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

    private void OnFocusOutlineRedraw()
    {
        if (_showKeyboardFocusOutline && FocusMode != FocusModeEnum.None)
            QueueRedraw();
    }

    public override void _Draw()
    {
        if (!_showKeyboardFocusOutline || FocusMode == FocusModeEnum.None || !HasFocus())
            return;
        float w = Mathf.Max(1f, _keyboardFocusOutlineWidth);
        DrawRect(new Rect2(Vector2.Zero, Size), _keyboardFocusOutlineColor, false, w);
    }
    #endregion
}
