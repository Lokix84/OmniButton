using Godot;
using System;

public partial class Test : Control
{
    public override void _Ready()
    {
        OmniButton IconBtn = GetNode<OmniButton>("Directional/IconButton");
        IconBtn.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-UpArrow1.png"));

        OmniButton IconBtn2 = GetNode<OmniButton>("Directional/IconButton2");
        IconBtn2.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn2.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn2.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-LeftArrow1.png"));

        OmniButton IconBtn3 = GetNode<OmniButton>("Directional/IconButton3");
        IconBtn3.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn3.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn3.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-RightArrow1.png"));

        OmniButton IconBtn4 = GetNode<OmniButton>("Directional/IconButton4");
        IconBtn4.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn4.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn4.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-DownArrow1.png"));

        OmniButton IconBtn5 = GetNode<OmniButton>("Directional/IconButton5");
        IconBtn5.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn5.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn5.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png"));

        OmniButton IconBtn6 = GetNode<OmniButton>("Actions/Attack");
        IconBtn6.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn6.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn6.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Sword1.png"));
        
        OmniButton IconBtn7 = GetNode<OmniButton>("Actions/Defend");
        IconBtn7.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));
        IconBtn7.ConnectSignal(nameof(OmniButton.Released), new Callable(this, nameof(OnButtonReleased)));
        IconBtn7.DisplayTexture(GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Shield5.png"));

        OmniButton LabelBtn = GetNode<OmniButton>("LabelButton");
        LabelBtn.DisplayLabel("Click Me");
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
}
