#if TOOLS
using Godot;
using System;

[Tool]
public partial class OmniButtonPlugin : EditorPlugin
{
	public override void _EnterTree()
	{
		var customNodeScript = GD.Load<Script>("res://addons/omni_button/CS/OmniButton.cs");
		var customNodeIcon = GD.Load<Texture2D>("res://addons/omni_button/OmniButtonV4.png");

		AddCustomType("OmniButton", "Control", customNodeScript, customNodeIcon);

	}

	public override void _ExitTree()
	{
		RemoveCustomType("OmniButton");
	}
}
#endif
