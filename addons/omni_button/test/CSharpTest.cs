using Godot;
using System;

public partial class CSharpTest : Control
{
    public override void _Ready()
    {
        OmniButton SprintBtn = GetNode<OmniButton>("Directional/SprintToggle");
        SprintBtn.Toggled += OnSprintToggled;
        SprintBtn.Texture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");

        OmniButton AttackBtn = GetNode<OmniButton>("Actions/Attack");
        AttackBtn.Pressed += OnButtonPressed;
        AttackBtn.Released += OnButtonReleased;

        OmniButton DefendBtn = GetNode<OmniButton>("Actions/Defend");
        DefendBtn.Toggled += OnDefendToggled;
        DefendBtn.Texture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Shield5.png");

        OmniButton LabelBtn = GetNode<OmniButton>("LabelButton");
        LabelBtn.Text = "Click Me this is a huge amount of text that will probably make an overflow and not cleanly fit";
    }

    public void OnButtonPressed()
    {
        GD.Print("Icon Button Pressed!");
    }
    public void OnButtonReleased()
    {
        GD.Print("Icon Button Released!");
    }

    public void OnLabelButtonPressed()
    {
        GD.Print("Label Button Pressed!");
    }
    public void OnLabelButtonReleased()
    {
        GD.Print("Label Button Released!");
    }

    public void OnSprintToggled(bool toggled)
    {
        GD.Print("Sprint Toggled: " + toggled);
    }

    public void OnDefendToggled(bool toggled)
    {
        GD.Print("Defend Toggled: " + toggled);
    }

}
