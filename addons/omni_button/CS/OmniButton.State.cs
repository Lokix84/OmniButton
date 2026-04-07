using Godot;

public partial class OmniButton : Control
{
    private void ResetPressState(bool emitSwipeEnded)
    {
        _activePointerTouchIndex = -1;
        _pointerGestureSource = PointerGestureSource.None;
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
