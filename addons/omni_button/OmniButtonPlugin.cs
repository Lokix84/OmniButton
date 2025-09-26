#if TOOLS
using Godot;
using System;

[Tool]
public partial class OmniButtonPlugin : EditorPlugin
{
	public override void _EnterTree()
	{
		var customNodeScript = GD.Load<Script>("res://addons/omni_button/OmniButton.cs");
		var customNodeIcon = GD.Load<Texture2D>("res://addons/omni_button/OmniButton.png");

		AddCustomType("OmniButton", "Control", customNodeScript, customNodeIcon);

	}

	public override void _ExitTree()
	{
		RemoveCustomType("OmniButton");
	}
}
#endif
