using Godot;

public partial class OmniButton : Control
{
    private OmniButtonSignalHelper? _signalHelper;
    private OmniButtonSignalHelper SignalHelper => _signalHelper ??= new OmniButtonSignalHelper(this);

    private void InitializeCallables()
        => SignalHelper.InitializeCallables();

    private void SetCallableProperty(string name, Callable callable)
        => SignalHelper.SetCallableProperty(name, callable);

    private void ConnectSignals()
        => SignalHelper.ConnectSignals();

    private void ConnectMouseEvents()
        => SignalHelper.ConnectMouseEvents();

    private void ConnectIfNotConnected(string signal, Callable callable)
        => SignalHelper.ConnectIfNotConnected(signal, callable);

    private void DisconnectAllSignalHandlers()
        => SignalHelper.DisconnectAllSignalHandlers();

    private Callable AdoptConnectedCallable(string signalName, Callable fallback)
        => SignalHelper.AdoptConnectedCallable(signalName, fallback);

    private void AutoEnableActionsFromConnectionsOnce()
        => SignalHelper.AutoEnableActionsFromConnectionsOnce();

    internal void EditorAutoEnableActionsFromConnectionsOnce()
        => SignalHelper.AutoEnableActionsFromConnectionsOnce();

    private sealed class OmniButtonSignalHelper
    {
        private readonly OmniButton _o;

        public OmniButtonSignalHelper(OmniButton owner)
        {
            _o = owner;
        }

        public void InitializeCallables()
        {
            var fallbacks = new (string name, Callable callable)[]
            {
                ("Pressed", new Callable(_o, nameof(RunBuiltInPressed))),
                ("Released", new Callable(_o, nameof(RunBuiltInReleased))),
                ("HoverIn", new Callable(_o, nameof(RunBuiltInHoverIn))),
                ("HoverOut", new Callable(_o, nameof(RunBuiltInHoverOut))),
                ("Toggled", new Callable(_o, nameof(RunBuiltInToggled))),
                ("Log", new Callable(_o, nameof(RunBuiltInLog))),
                ("Hold", new Callable(_o, nameof(RunBuiltInHold))),
                ("Swipe", new Callable(_o, nameof(RunBuiltInSwipe))),
                ("Warning", new Callable(_o, nameof(RunBuiltInWarning))),
                ("Error", new Callable(_o, nameof(RunBuiltInError)))
            };
            foreach (var (name, callable) in fallbacks)
            {
                SetCallableProperty(name, AdoptConnectedCallable(name, callable));
            }
        }

        public void SetCallableProperty(string name, Callable callable)
        {
            switch (name)
            {
                case "Pressed": _o.PressedAction = callable; break;
                case "Released": _o.ReleasedAction = callable; break;
                case "HoverIn": _o.HoverInAction = callable; break;
                case "HoverOut": _o.HoverOutAction = callable; break;
                case "Toggled": _o.ToggledAction = callable; break;
                case "Log": _o.LogAction = callable; break;
                case "Hold": _o.HoldAction = callable; break;
                case "Swipe": _o.SwipeAction = callable; break;
                case "Warning": _o.WarningAction = callable; break;
                case "Error": _o.ErrorAction = callable; break;
            }
        }

        public void ConnectSignals()
        {
            var signals = new (string name, Callable callable)[]
            {
                ("Pressed", _o.PressedAction),
                ("Released", _o.ReleasedAction),
                ("HoverIn", _o.HoverInAction),
                ("HoverOut", _o.HoverOutAction),
                ("Toggled", _o.ToggledAction),
                ("Log", _o.LogAction),
                ("Hold", _o.HoldAction),
                ("Swipe", _o.SwipeAction),
                ("Warning", _o.WarningAction),
                ("Error", _o.ErrorAction)
            };
            foreach (var (name, callable) in signals)
            {
                if ((callable.Target == null && string.IsNullOrEmpty(callable.Method)) || !_o.HasSignal(name))
                    continue;
                if (!_o.IsConnected(name, callable))
                    _o.Connect(name, callable);
            }
        }

        public void ConnectMouseEvents()
        {
            ConnectIfNotConnected("mouse_entered", new Callable(_o, nameof(OnMouseEntered)));
            ConnectIfNotConnected("mouse_exited", new Callable(_o, nameof(OnMouseExited)));
            ConnectIfNotConnected(Control.SignalName.FocusEntered, new Callable(_o, nameof(OnFocusOutlineRedraw)));
            ConnectIfNotConnected(Control.SignalName.FocusExited, new Callable(_o, nameof(OnFocusOutlineRedraw)));
        }

        public void ConnectIfNotConnected(string signal, Callable callable)
        {
            if (!_o.IsConnected(signal, callable))
                _o.Connect(signal, callable);
        }

        public void DisconnectAllSignalHandlers()
        {
            foreach (var signal in OwnSignals)
            {
                if (_o.HasSignal(signal))
                {
                    var connections = _o.GetSignalConnectionList(signal);
                    foreach (var connection in connections)
                    {
                        var dict = connection;
                        if (dict.TryGetValue("callable", out var callable))
                        {
                            var cb = (Callable)callable;
                            if (cb.Target == null && string.IsNullOrEmpty(cb.Method))
                                continue;
                            if (_o.IsConnected(signal, cb))
                                _o.Disconnect(signal, cb);
                        }
                    }
                }
            }
        }

        public Callable AdoptConnectedCallable(string signalName, Callable fallback)
        {
            var connections = _o.GetSignalConnectionList(signalName);
            return connections.Count > 0 ? ((Callable)connections[0]["callable"]) : fallback;
        }

        public void AutoEnableActionsFromConnectionsOnce()
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
                if ((_o._autoActionOnce & flag) != 0) continue;
                var conns = _o.GetSignalConnectionList(signal);
                bool hasExternal = false;
                foreach (Godot.Collections.Dictionary dict in conns)
                {
                    if (!dict.TryGetValue("callable", out var callable)) continue;
                    var cb = (Callable)callable;
                    var target = cb.Target;
                    if (target != null && !ReferenceEquals(target, _o))
                    {
                        hasExternal = true; break;
                    }
                }
                if (hasExternal)
                {
                    _o.ActionMask |= flag;
                    _o._autoActionOnce |= flag;
                }
            }
        }
    }
}
