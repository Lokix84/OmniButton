OmniButton (C#) - Universal Button Control for Godot
A highly customizable and feature-rich button control for Godot written in C#. This extends the base Control node with advanced input handling, hover effects, dynamic font sizing, and flexible action management through a callable-based architecture.

Features
Multiple Button Types: Standard button and toggle button functionality
Advanced Input Handling: Support for mouse, touch, and keyboard input with custom bounds detection
Callable-Based Actions: Flexible action system allowing custom behaviors through Godot's Callable system
Dynamic Font Sizing: Automatic font size adjustment to fit available space
Built-in Hover Effects: Configurable scaling animations with customizable parameters
Signal Locking: Prevention of infinite loops and stack overflow with built-in signal locks
Texture and Label Support: Easy methods for displaying textures and text with automatic child node management
Focus Management: Optional focus requirements for keyboard actions
Comprehensive Logging: Built-in logging system with customizable log actions
Installation
Copy the omni_button addon folder to your project's addons directory
Enable the plugin in Project Settings > Plugins
The OmniButton class will be available in your C# scripts
Basic Usage
Creating an OmniButton

// Create programmaticallyvar omniButton = new OmniButton();AddChild(omniButton);// Set basic propertiesomniButton.Type = OmniButton.ButtonType.Button;omniButton.EnablePressActions = true;
Connecting to Button Signals

public override void _Ready(){    var button = GetNode<OmniButton>("OmniButton");        // Connect using Godot's Connect method    button.Connect(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));    button.Connect(nameof(OmniButton.Toggled), new Callable(this, nameof(OnButtonToggled)));    button.Connect(nameof(OmniButton.HoverIn), new Callable(this, nameof(OnButtonHoverIn)));    button.Connect(nameof(OmniButton.HoverOut), new Callable(this, nameof(OnButtonHoverOut)));        // Or use the custom ConnectSignal method    button.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(OnButtonPressed)));}private void OnButtonPressed(){    GD.Print("Button was pressed!");}private void OnButtonToggled(bool isPressed){    GD.Print($"Button toggled: {isPressed}");}private void OnButtonHoverIn(){    GD.Print("Mouse entered button");}private void OnButtonHoverOut(){    GD.Print("Mouse left button");}
Adding Content to the Button

// Display text labelbutton.DisplayLabel("Click Me!");// Display text with custom themevar customTheme = GD.Load<Theme>("res://themes/button_theme.tres");button.DisplayLabel("Styled Button", customTheme);// Display texturebutton.DisplayTexture("res://icons/button_icon.png");// Or with loaded texturevar texture = GD.Load<Texture2D>("res://icons/button_icon.png");button.DisplayTexture(texture, stretch: false);
Configuration Options
General Settings
Type: ButtonType.Button or ButtonType.Toggle
ButtonDisabled: Disable the button to prevent all interactions
Input Settings
ActionName: Input action name for keyboard/controller support (default: "ui_accept")
RequireFocusForAction: Whether the button needs focus to respond to the assigned action
Bounds and Hit Detection
BoundsSource: Optional Control node to use for hit detection instead of self
HitSlop: Extra margin around the button for easier touch/click detection (Vector2)
Press Actions
EnablePressActions: Enable/disable press functionality
PressedAction: Custom callable for press behavior
EnableReleaseActions: Enable/disable release functionality
ReleasedAction: Custom callable for release behavior
Toggle Actions
EnableToggleActions: Enable/disable toggle functionality (for toggle buttons)
ToggledAction: Custom callable for toggle behavior
Hover and Scaling
EnableHoverActions: Enable/disable hover effects
HoverInAction: Custom callable for hover enter behavior
HoverOutAction: Custom callable for hover exit behavior
HoverScale: Scale multiplier for hover effect (default: 1.25)
HoverLerpSpeed: Speed of hover animation (default: 25.0)
Font Size Settings
MinFontSize: Minimum font size for dynamic sizing (default: 12)
MaxFontSize: Maximum font size for dynamic sizing (default: 100)
Logging
LogAction: Custom callable for log handling
Advanced Features
Custom Action Callables
You can assign custom behaviors to any button action:


// Custom press actionbutton.PressedAction = new Callable(this, nameof(CustomPressAction));// Custom hover actionsbutton.HoverInAction = new Callable(this, nameof(CustomHoverIn));button.HoverOutAction = new Callable(this, nameof(CustomHoverOut));private void CustomPressAction(){    // Your custom press logic    GD.Print("Custom press behavior!");}private void CustomHoverIn(){    // Custom hover enter logic    Modulate = Colors.Yellow;}private void CustomHoverOut(){    // Custom hover exit logic    Modulate = Colors.White;}
Dynamic Signal Connection
Use the ConnectSignal method to safely connect and disconnect signals:


// This method automatically disconnects old connections before connecting new onesbutton.ConnectSignal(nameof(OmniButton.Pressed), new Callable(this, nameof(NewPressHandler)));
Custom Bounds Detection
Set a different Control node as the bounds source for hit detection:


var largerArea = GetNode<Control>("LargerHitArea");button.BoundsSource = largerArea;// Add extra touch areabutton.HitSlop = new Vector2(15, 15);
Dynamic Font Sizing
The button automatically adjusts font size to fit the available space:


// Configure font size limitsbutton.MinFontSize = 8;button.MaxFontSize = 48;// Font will automatically resize when button size changesbutton.Size = new Vector2(200, 100);
Button Types
Standard Button (ButtonType.Button)

button.Type = OmniButton.ButtonType.Button;button.EnablePressActions = true;button.EnableReleaseActions = true; // Optional
Toggle Button (ButtonType.Toggle)

button.Type = OmniButton.ButtonType.Toggle;button.EnableToggleActions = true;
Signals
Signal	Parameters	Description
Pressed	None	Emitted when button is pressed
Released	None	Emitted when button is released
Toggled	bool button_pressed	Emitted when toggle state changes
HoverIn	None	Emitted when mouse enters button area
HoverOut	None	Emitted when mouse exits button area
Log	string type, string message	Internal logging signal
Built-in Behaviors
Each action has a built-in fallback behavior that executes if no custom callable is assigned:

Press: Logs that no custom action was set
Release: Logs that no custom action was set
Toggle: Logs that no custom action was set
Hover In: Scales the button up by HoverScale
Hover Out: Scales the button back to normal size
Log: Outputs to Godot's console using GD.Print, GD.PushWarning, or GD.PushError
Signal Lock System
The OmniButton includes a built-in signal lock system to prevent stack overflow and infinite loops:

Each signal type has its own lock
Locks are automatically managed and released after one frame
Prevents rapid-fire signal emissions that could cause performance issues
Best Practices
Performance: Disable unused action groups to improve performance
Touch Support: Use HitSlop for better mobile touch experience
Accessibility: Always provide keyboard support via ActionName
Visual Feedback: Use hover actions for visual state changes
Memory Management: The button automatically manages child Label and TextureRect nodes
Custom Actions: Use callables for complex custom behaviors instead of connecting multiple signals
Troubleshooting
Button Not Responding
Check if ButtonDisabled is set to false
Ensure the button has a valid size and is visible
Verify that MouseFilter is not set to Ignore
Check if another control is intercepting input
Hover Effects Not Working
Ensure EnableHoverActions is true
Check that the mouse_entered and mouse_exited signals are connected (handled automatically in _EnterTree)
Verify the button can receive mouse events
Font Not Resizing
Check that MinFontSize and MaxFontSize are set correctly
Ensure the Label node exists (created automatically by DisplayLabel)
Verify the button size is changing (font adjusts on resize notification)
Stack Overflow Issues
The built-in signal lock system should prevent this
If it still occurs, check for recursive callable chains
Ensure custom callables don't emit the same signal they're handling
License
This addon is provided under the MIT License. See LICENSE file for details.

Contributing
Contributions are welcome! Please feel free to submit issues and pull requests to improve the OmniButton functionality.
