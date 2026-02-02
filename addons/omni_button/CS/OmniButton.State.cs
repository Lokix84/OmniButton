using Godot;

public partial class OmniButton : Control
{
    private void ResetPressState(bool emitSwipeEnded)
    {
        _isPressed = false;
        _isHolding = false;
        if (emitSwipeEnded)
            EndSwiping();
        else
        {
            _isSwiping = false;
            _swipeStart = Vector2.Zero;
        }
        if (_holdFill != null && IsInstanceValid(_holdFill))
            RemoveHoldFill();
    }
}
