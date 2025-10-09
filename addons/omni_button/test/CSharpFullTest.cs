using Godot;
using System;

public partial class CSharpFullTest : Control
{
    public override void _Ready()
    {
        OmniButton log = GetTree().GetFirstNodeInGroup("Output") as OmniButton;
        if (log != null)
        {
            log.LabelText = "CSharpFullTest ready";
        }
        // Connect all OmniButton nodes under this scene to log their signals
        foreach (var node in GetTree().GetNodesInGroup("Button"))
        {
            if (node is OmniButton b)
            {
                ConnectButton(b, log);
            }

        }
    }
    void ConnectButton(OmniButton b, OmniButton log = null)
    {
        b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => log.LabelText = $"[{b.Name}] Pressed"));
        b.Connect(OmniButton.SignalName.Released, Callable.From(() => log.LabelText = $"[{b.Name}] Released"));
        b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(v => log.LabelText = $"[{b.Name}] Toggled: {v}"));
        b.Connect(OmniButton.SignalName.HoverIn, Callable.From(() => log.LabelText = $"[{b.Name}] HoverIn"));
        b.Connect(OmniButton.SignalName.HoverOut, Callable.From(() => log.LabelText = $"[{b.Name}] HoverOut"));
        b.Connect(OmniButton.SignalName.Hold, Callable.From(() => log.LabelText = $"[{b.Name}] Hold"));
        b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(dir => log.LabelText = $"[{b.Name}] Swipe: {dir}"));
        // Optional logging signals if enabled
        b.Connect(OmniButton.SignalName.Log, Callable.From<string>(msg => log.LabelText = $"[{b.Name}] Log: {msg}"));
        b.Connect(OmniButton.SignalName.Warning, Callable.From<string>(msg => log.LabelText = $"[{b.Name}] {msg}"));
        b.Connect(OmniButton.SignalName.Error, Callable.From<string>(msg => log.LabelText = $"[{b.Name}] {msg}"));
    }
}

