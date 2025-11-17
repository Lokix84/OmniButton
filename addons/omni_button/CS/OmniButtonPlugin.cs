#if TOOLS
using Godot;
using System;

[Tool]
public partial class OmniButtonPlugin : EditorPlugin
{
    public override void _EnterTree()
    {
        AddCustomType("OmniButton", "Control", GD.Load<Script>("res://addons/omni_button/CS/OmniButton.cs"), GD.Load<Texture2D>("res://addons/omni_button/OmniButtonCSV1.png"));
    }

    public override void _ExitTree()
    {
        RemoveCustomType("OmniButton");
    }
}
#endif
