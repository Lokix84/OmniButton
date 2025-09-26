-----------------------------------------------
OMNIBUTTON - Universal Button Control for Godot
-----------------------------------------------
A highly customizable and feature-rich button control for Godot that extends the base Control node with advanced input handling, hover effects, and flexible action management.

----------------
FEATURES
----------------
Multiple Button Types: Standard button and toggle button functionality

Advanced Input Handling: Support for mouse, touch, and keyboard input

Customizable Hover Effects: Built-in hover animations with configurable parameters

Flexible Bounds Detection: Custom hit detection areas with slop margins

Signal-Based Architecture: Comprehensive signal system for all button interactions

Focus Management: Optional focus requirements for keyboard actions

Extensible Design: Easy to extend with custom behaviors

----------------
INSTALLATION
----------------
Copy the omni_button addon folder to your project's addons directory

Enable the plugin in Project Settings > Plugins

The OmniButton class will be available in your project

----------------
BASIC USAGE
----------------
Adding an OmniButton to Your Scene

# In the editor, add a Control node and change its script to OmniButton# Or create programmatically:var omni_button = OmniButton.new()add_child(omni_button)
Connecting to Button Signals

func _ready():    var button = $OmniButton     

  # Connect to button press   
  
  button.pressed.connect(_on_button_pressed)     

  
  # Connect to toggle events (for toggle buttons)  
  
  button.toggled.connect(_on_button_toggled)   

  
  # Connect to hover events    
  
  button.hover_in.connect(_on_button_hover_in)    

  button.hover_out.connect(_on_button_hover_out)       

  
  # Connect to release events    
  
  button.released.connect(_on_button_released)
  

func _on_button_pressed():    

  print("Button was pressed!")
  

func _on_button_toggled(is_pressed: bool):   

  print("Button toggled: ", is_pressed)
  

func _on_button_hover_in():    

  print("Mouse entered button")
  

func _on_button_hover_out():    

  print("Mouse left button")
  

---------------------
CONFIGURATION OPTIONS
---------------------
General Settings

Type: Choose between BUTTON (standard) or TOGGLE button behavior

Button Disabled: Disable the button to prevent all interactions


Input Settings

Action Name: Input action name for keyboard/controller support (default: "ui_accept")

Require Focus for Action: Whether the button needs focus to respond to the assigned action


Bounds and Hit Detection

Bounds Source: Optional Control node to use for hit detection instead of self

Hit Slop: Extra margin around the button for easier touch/click detection

----------------
ACTION GROUPS
----------------
The button supports multiple action groups that can be enabled/disabled independently:

Press Actions: Control standard button press behavior

Toggle Actions: Control toggle button behavior (when type is TOGGLE)

Release Actions: Control button release behavior

Hover Actions: Control mouse enter/exit behavior

----------------
BUTTON TYPES
----------------
Standard Button (ButtonType.BUTTON)

Emits pressed signal when clicked

Can optionally emit released signal

Standard one-shot button behavior


Toggle Button (ButtonType.TOGGLE)

Maintains pressed/unpressed state

Emits toggled(bool) signal with current state

Visual feedback for current state


----------------
SIGNALS
----------------
Signal	Parameters	Description

pressed	None	Emitted when button is pressed

released	None	Emitted when button is released

toggled	button_pressed: bool	Emitted when toggle state changes

hover_in	None	Emitted when mouse enters button area

hover_out	None	Emitted when mouse exits button area

log	type: String, message: String	Internal logging signal

-----------------
ADVANCED FEATURES
-----------------

Custom Bounds Detection

Set a different Control node as the bounds source for hit detection:

# Use a larger invisible area for hit detectionbutton.bounds_source = $LargerHitArea


Hit Slop for Better Touch Support

Add extra margin around the button for easier touch interaction:

# Add 10 pixels of extra touch area on all sidesbutton.hit_slop = Vector2(10, 10)

----------------
FOCUS MANAGEMENT
----------------
Control whether the button responds to keyboard input:

# Button only responds to assigned action when focusedbutton.require_focus_for_action = true# Button always responds to assigned actionbutton.require_focus_for_action = false

Selective Action Enabling

Enable only the interactions you need:

# Only enable press actions, disable hover and releasebutton.enable_press_actions = truebutton.enable_hover_actions = falsebutton.enable_release_actions = false

----------------
BEST PRACTICES
----------------
Performance: Disable unused action groups to improve performance

Touch Support: Use hit slop for better mobile touch experience

Accessibility: Always provide keyboard support via action names

Visual Feedback: Connect to hover signals for visual state changes

State Management: Use toggle buttons for on/off states

----------------
TROUBLEASHOOTING
----------------
Button Not Responding

Check if button_disabled is set to false

Ensure the button has a valid size and is visible

Verify that MouseFilter is not set to IGNORE

Check if another control is intercepting input


Hover Effects Not Working

Ensure enable_hover_actions is true

Check that hover signals are properly connected

Verify the button is receiving mouse events


Keyboard Input Not Working

Ensure the assigned action_name exists in Input Map

Check require_focus_for_action setting

Verify the button can receive focus

----------------
LICENSE
----------------
This addon is provided under the MIT License. See LICENSE file for details.

----------------
CONTRIBUTING
----------------
Contributions are welcome! Please feel free to submit issues and pull requests to improve the OmniButton functionality.
