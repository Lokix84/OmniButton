OmniButton for Godot 4
Universal, highly configurable button control available in both C# and GDScript. OmniButton unifies press/release/toggle actions, hover scaling, swipe, hold, dynamic label sizing, and panel/overlay visuals into a single, editorâ€‘friendly node.

Why use OmniButton
- Single node, many behaviors: momentary or toggle, hover zoom, swipe, hold.
- Works in editor: most properties update live when changed in the Inspector.
- Two implementations, same features: C# and GDScript stay in parity.
- Dropâ€‘in: fullâ€‘rect children, crisp icon filtering, smart theme/variant support.

Repository layout
- addons/omni_button/CS/README.md â€” C# usage and details
- addons/omni_button/GD/README.md â€” GDScript usage and details
- addons/omni_button/CS/OmniButton.cs â€” C# implementation
- addons/omni_button/GD/omni_button.gd â€” GDScript implementation

Features (high level)
- Press/Release/Toggle with enable flags and signals
- Hover scaling independent of hover signals; centered, smooth, viewportâ€‘clamped
- Inversion effects: invert on press, toggle, and hover
- Dynamic label sizing with min/max font bounds and configurable label text color
- Icon support with nearest filtering for crisp pixel art
- Optional panel and overlay visuals (fullâ€‘rect children)
- Swipe (mouse and touch) and Hold timing
- Custom hit detection via `bounds_source` and `hit_slop`

Install
- Copy `addons/omni_button` into your projectâ€™s `addons/` folder.
- Enable the plugin if using an EditorPlugin (not required to use the nodes).
- Keep either or both versions (C# and/or GDScript). You can delete the one you wonâ€™t use.

Quick start
- C#
  - Add a node with script `OmniButton.cs` or create via code, then:
  
  ```csharp
  public override void _Ready()
  {
      var btn = GetNode<OmniButton>("OmniButton");
      btn.Connect(OmniButton.SignalName.Pressed, Callable.From(() => GD.Print("Pressed")));
      btn.EnableHoverScale = true;
      btn.InvertDisplayOnHover = true;
      btn.LabelText = "Play";
  }
  ```

- GDScript
  - Add `OmniButton.gd` (class_name) or create via code, then:

  ```gdscript
  func _ready() -> void:
      var btn: OmniButton = $OmniButton
      btn.pressed.connect(func(): print("Pressed"))
      btn.enable_hover_scale = true
      btn.invert_on_hover = true
      btn.text = "Play"
  ```

Core concepts
- Signals: pressed, released, toggled(bool), hover_in, hover_out, swipe(Vector2), hold, log/warning/error
- Editor friendliness: changing display and visual properties updates preview live
- Safety: hover zoom is clamped to stay within the viewport while able to overflow parent containers

Going deeper
- C# specific API, examples, and property groups: see `addons/omni_button/CS/README.md`
- GDScript specific API, examples, and property groups: see `addons/omni_button/GD/README.md`

Compatibility
- Godot 4.x (GDScript and C#)
- C#: targets Godotâ€™s .NET/Mono build; ensure the Godot C# export templates are installed

Contributing
- PRs and issues welcome. Aim to keep both implementations in feature parity and the subâ€‘READMEs as the source of truth for versionâ€‘specific details.

License
- MIT. See LICENSE.

