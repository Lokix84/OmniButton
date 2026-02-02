using Godot;
using System;

public partial class OmniButton : Control
{
    private void ProcessHoverScaling(double delta)
    {
        // Optionally suspend hover animations while typewriter is active
        if (_twActive && SuspendHoverDuringTypewriter)
        {
            var tReset = (float)Math.Min(1.0, delta * HoverLerpSpeed);
            if (_panel != null && IsInstanceValid(_panel)) LerpScaleTo(_panel, Vector2.One, tReset);
            if (_icon != null && IsInstanceValid(_icon)) LerpScaleTo(_icon, Vector2.One, tReset);
            if (_label != null && IsInstanceValid(_label)) LerpScaleTo(_label, Vector2.One, tReset);
            if (_overlay != null && IsInstanceValid(_overlay)) LerpScaleTo(_overlay, Vector2.One, tReset);
            EnableHoverTopLevel(false);
            return;
        }
        // Avoid reassigning properties every frame; state fields already reflect truth
        // Hold timer progresses when pressed and either not in cooldown or allowed during cooldown
        if (_isPressed && (!EnableCooldown || !_cooldownActive || AllowHoldDuringCooldown || EnableHoldBuildUp))
        {
            _holdTimer += delta;
            if (!_isHolding && _holdTimer >= HoldDuration)
            {
                IsHolding = true;
                if ((ActionMask & ActionMaskFlags.Hold) != 0)
                {
                    EmitSignal(SignalName.Hold);
                    DebugLog("Hold signal emitted");
                }
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
                if (!anyAnimating && !_isHovering && !(_cooldownActive && EnableCooldown) && !holdBuildActive && !_twActive)
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
            if (!anyAnimating && !(_cooldownActive && EnableCooldown) && !holdBuildActive && !_twActive)
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
        // Cooldown delay countdown
        if (_cooldownDelayPending)
        {
            _cooldownDelayLeft = Math.Max(0.0, _cooldownDelayLeft - delta);
            if (_cooldownDelayLeft <= 0.0)
            {
                _cooldownDelayPending = false;
                BeginCooldownNow();
            }
        }
        // Cooldown handling
        if (_cooldownActive)
        {
            _cooldownElapsed += delta;
            _cooldownTimeLeft = Math.Max(0.0, _cooldownTimeLeft - delta);
            UpdateCooldownVisual();
            if (_cooldownTimeLeft <= 0.0)
            {
                _cooldownActive = false;
                _cooldownElapsed = 0.0;
                DebugLog("Cooldown completed");
                if (_cooldown != null && IsInstanceValid(_cooldown))
                {
                    _cooldown.Visible = false;
                    _cooldown.Size = Vector2.Zero;
                    _cooldown.Position = Vector2.Zero;
                }
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
}
