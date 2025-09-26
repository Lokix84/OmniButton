Customized Godot Button Control (Draft)

The idea was to make a control that could have text or an image that could have touch input capacity and started expanding it from there.


----------------
INSTALL
----------------
Add omni_button folder to addons folder.

----------------
GET STARED
----------------
create a new node
<img width="911" height="736" alt="image" src="https://github.com/user-attachments/assets/54be2664-ae30-4796-bdfd-4f0d89225bce" />

Size the control however you like.

In code you call DisplayTexture or DisplayLabel to add a texture or label respectively. The button when you run the code wil add a texture or label automatically.

For label functionality, you can set a min and max font size and the label will adjust the font to match the area you have available. This can be useful for when you want to create a button that has more dynamic text. 

You can enable, disable and customize the following actions:
Press
Release
Toggle
Hover Over
Hover Out

By Default, the control will be marked as a button with press and hover enabled. The default hover behavior is to make the button scale increase to 1.25.

The Press, Release and Toggle actions by default will output a log message stating that the button is running built-in logic.

PressAction, ReleaseAction, ToggleAction, HoverInAction and HoverOutAction are Callable properties. Setting those in code will change the functionality of the corresponding signal events.
