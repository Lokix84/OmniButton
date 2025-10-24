using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class CSharpFullTest : Control
{
    private ScrollContainer _leftScroll;
    private VBoxContainer _leftList;
    private Control _arena; // right-side area for placing test buttons

    private class TestRow
    {
        public string Name;
        public Func<Task<bool>> RunAsync;
        public HBoxContainer Row;
        public CheckBox Check;
        public Label Label;
    }

    private readonly List<TestRow> _tests = new();
    private int _passed = 0;
    private int _failed = 0;

    public override void _Ready()
    {
        Name = "CSharpFullTest";
        BuildUi();
        // Replace existing right-side content with test-driven content
        ClearArena();

        BuildTests();
        CallDeferred(nameof(BeginRun));
    }

    private async void BeginRun()
    {
        await RunAllAsync();
    }

    private void BuildUi()
    {
        // If the scene provides a RootHBox with ResultsPanel/Results/List and Arena, use that
        var rootHBox = GetNodeOrNull<HBoxContainer>("RootHBox");
        if (rootHBox != null)
        {
            var leftPanel = GetNodeOrNull<PanelContainer>("RootHBox/ResultsPanel");
            _leftScroll = GetNodeOrNull<ScrollContainer>("RootHBox/ResultsPanel/Results") ?? new ScrollContainer();
            _leftList = GetNodeOrNull<VBoxContainer>("RootHBox/ResultsPanel/Results/List") ?? new VBoxContainer();
            _arena = GetNodeOrNull<Control>("RootHBox/Arena") ?? new Control();

            if (_leftScroll.GetParent() == null && leftPanel != null) leftPanel.AddChild(_leftScroll);
            if (_leftList.GetParent() == null) _leftScroll.AddChild(_leftList);
            if (_arena.GetParent() == null) rootHBox.AddChild(_arena);
            return;
        }

        // Fallback: build programmatically using a 50/50 split
        var split = new HSplitContainer { Name = "Split" };
        split.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        split.DraggerVisibility = SplitContainer.DraggerVisibilityEnum.Hidden;
        AddChild(split);

        var left = new PanelContainer { Name = "ResultsPanel" };
        left.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        left.SizeFlagsVertical = SizeFlags.ExpandFill;
        split.AddChild(left);

        _leftScroll = new ScrollContainer { Name = "Results" };
        _leftScroll.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _leftScroll.SizeFlagsVertical = SizeFlags.ExpandFill;
        left.AddChild(_leftScroll);

        _leftList = new VBoxContainer { Name = "List" };
        _leftList.SizeFlagsHorizontal = SizeFlags.Fill;
        _leftList.SizeFlagsVertical = SizeFlags.ExpandFill;
        _leftScroll.AddChild(_leftList);

        _arena = new Control { Name = "Arena" };
        _arena.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _arena.SizeFlagsVertical = SizeFlags.ExpandFill;
        split.AddChild(_arena);

        CallDeferred(nameof(SetHalfSplit), split);
    }

    private void SetHalfSplit(HSplitContainer split)
    {
        if (split == null) return;
        split.SplitOffset = (int)Mathf.Round(split.Size.X * 0.5f);
    }

    private void AddTest(string name, Func<Task<bool>> runAsync)
    {
        var row = new HBoxContainer();
        var label = new Label { Text = name, HorizontalAlignment = HorizontalAlignment.Left };
        label.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        var check = new CheckBox { Text = "pending" };
        check.MouseFilter = MouseFilterEnum.Ignore;
        row.AddChild(label);
        row.AddChild(check);
        _leftList.AddChild(row);

        _tests.Add(new TestRow
        {
            Name = name,
            RunAsync = runAsync,
            Row = row,
            Check = check,
            Label = label
        });
    }

    private async Task RunAllAsync()
    {
        foreach (var t in _tests)
        {
            bool ok = false;
            try
            {
                t.Check.Text = "running";
                t.Check.ButtonPressed = false;
                await Delay(0.2);
                ok = await t.RunAsync();
            }
            catch (Exception ex)
            {
                ok = false;
                GD.PushError($"[TestError] {t.Name}: {ex.Message}\n{ex.StackTrace}");
            }
            t.Check.ButtonPressed = ok;
            t.Check.Text = ok ? "pass" : "fail";
            if (ok) _passed++; else _failed++;
            await Delay(0.35);
        }
        GD.Print($"[Tests] Finished: Passed={_passed}, Failed={_failed}");
    }

    // Utilities
    private OmniButton MakeButton(Vector2 pos, Vector2 size, Action<OmniButton> configure = null)
    {
        ClearArena();
        var b = new OmniButton
        {
            Name = $"TestBtn_{Guid.NewGuid().ToString().Substring(0, 8)}",
            Position = pos,
            Size = size
        };
        _arena.AddChild(b);
        configure?.Invoke(b);
        // Ensure internal setup paths run at least once for child creation and visuals
        b._Ready();
        // Center the test control in the right pane
        CenterInArena(b);
        return b;
    }

    private void CenterInArena(Control ctrl)
    {
        if (ctrl == null || _arena == null) return;
        var ar = _arena.GetGlobalRect();
        ctrl.GlobalPosition = ar.Position + (ar.Size - ctrl.Size) / 2f;
    }

    private void ClearArena()
    {
        if (_arena == null) return;
        foreach (var child in _arena.GetChildren())
        {
            if (child is Node n)
            {
                _arena.RemoveChild(n);
                n.QueueFree();
            }
        }
    }

    private static InputEventMouseButton MousePressAt(Vector2 global, bool pressed)
    {
        var e = new InputEventMouseButton
        {
            ButtonIndex = MouseButton.Left,
            Pressed = pressed,
            GlobalPosition = global,
            Position = global // safe for local-inside checks on some paths
        };
        return e;
    }

    private static InputEventMouseMotion MouseMoveAt(Vector2 global)
    {
        var e = new InputEventMouseMotion
        {
            GlobalPosition = global,
            Position = global
        };
        return e;
    }

    private Vector2 Center(Control c) => c.GetGlobalRect().Position + c.GetGlobalRect().Size / 2f;

    private void SimProcess(OmniButton b, double duration, double step = 0.016)
    {
        double t = 0;
        while (t < duration)
        {
            b._Process(step);
            t += step;
        }
    }

    // Assertions
    private static void Assert(bool cond, string msg)
    {
        if (!cond) throw new Exception(msg);
    }

    private static bool Nearly(Vector2 a, Vector2 b, float tol = 0.02f)
        => Mathf.Abs(a.X - b.X) <= tol && Mathf.Abs(a.Y - b.Y) <= tol;

    private async Task Delay(double seconds)
    {
        var timer = GetTree().CreateTimer(seconds);
        await ToSignal(timer, SceneTreeTimer.SignalName.Timeout);
    }

    // Build the full test suite
    private void BuildTests()
    {
        // 1) Press / Release
        AddTest("Pressed/Released signals", async () =>
        {
            var b = MakeButton(new Vector2(50, 50), new Vector2(100, 60), ob =>
            {
                ob.ActionMaskBits = (int)(OmniButton.ActionMaskFlags.Pressed | OmniButton.ActionMaskFlags.Released);
            });
            await Delay(0.25);
            int pressed = 0, released = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => pressed++));
            b.Connect(OmniButton.SignalName.Released, Callable.From(() => released++));

            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            await Delay(0.1);
            b._GuiInput(MousePressAt(p, false));
            bool ok = pressed == 1 && released == 1;
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, $"Expected 1 press and 1 release, got {pressed}/{released}");
            return true;
        });

        // 2) Toggle
        AddTest("Toggle signal and state", async () =>
        {
            var b = MakeButton(new Vector2(60, 140), new Vector2(100, 60), ob => ob.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress);
            await Delay(0.2);
            bool toggledValue = false; int toggledCount = 0;
            b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(v => { toggledValue = v; toggledCount++; }));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true)); // press triggers toggle
            await Delay(0.1);
            Assert(toggledCount == 1 && toggledValue == true, "Toggle expected true once on press");
            b._GuiInput(MousePressAt(p, false));
            await Delay(0.1);
            b.QueueFree();
            return true;
        });

        // 3) Hold
        AddTest("Hold after duration", async () =>
        {
            var b = MakeButton(new Vector2(60, 220), new Vector2(100, 60), ob =>
            {
                ob.ActionMaskBits = (int)OmniButton.ActionMaskFlags.Hold;
                ob.HoldDuration = 0.1f;
            });
            await Delay(0.2);
            int hold = 0;
            b.Connect(OmniButton.SignalName.Hold, Callable.From(() => hold++));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            SimProcess(b, 0.15);
            bool ok = hold == 1;
            b._GuiInput(MousePressAt(p, false));
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, $"Hold expected 1, got {hold}");
            return true;
        });

        // 4) Swipe
        AddTest("Swipe emits direction", async () =>
        {
            var b = MakeButton(new Vector2(60, 300), new Vector2(120, 60), ob =>
            {
                ob.ActionMaskBits = (int)OmniButton.ActionMaskFlags.Swipe;
                ob.SwipeThreshold = 10f;
            });
            Vector2 dir = Vector2.Zero; int count = 0;
            b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(d => { dir = d; count++; }));
            var p = Center(b);
            // Use ScreenDrag path (global coords) – send two drags to set start and trigger
            var drag1 = new InputEventScreenDrag { Position = p };
            var drag2 = new InputEventScreenDrag { Position = p + new Vector2(20, 0) };
            b._GuiInput(drag1);
            b._GuiInput(drag2);
            bool ok = count == 1 && dir.X > 0.9f && Mathf.Abs(dir.Y) < 0.1f;
            b.QueueFree();
            Assert(ok, "Expected one swipe to the right");
            return true;
        });

        // 5) Cooldown blocks input
        AddTest("Cooldown blocks repeat press", async () =>
        {
            var b = MakeButton(new Vector2(60, 380), new Vector2(120, 60), ob =>
            {
                ob.ActionMaskBits = (int)OmniButton.ActionMaskFlags.Pressed;
                ob.EnableCooldown = true;
                ob.CooldownTrigger = OmniButton.CooldownTriggerEnum.OnPress;
                ob.CooldownDuration = 0.2f;
            });
            await Delay(0.2);
            int pressed = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => pressed++));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            // During cooldown, press ignored
            await Delay(0.05);
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            // Advance time to finish cooldown
            SimProcess(b, 0.25);
            // Now it should accept again
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            bool ok = pressed == 2;
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, $"Pressed count should be 2, got {pressed}");
            return true;
        });

        // 6) Selected overlay
        AddTest("Selected overlay color", async () =>
        {
            var b = MakeButton(new Vector2(60, 460), new Vector2(120, 60), ob =>
            {
                ob.Background = OmniButton.BackgroundMode.UsePanel;
                ob.EnableSelectedOverlay = true;
                ob.Selected = true;
                ob.SelectedColor = new Color(1, 0, 0, 0.5f);
            });
            await Delay(0.15);
            // Find overlay by name
            ColorRect overlay = b.GetNodeOrNull<ColorRect>("Overlay");
            Assert(overlay != null, "Overlay not found");
            Assert(overlay.Color.R > 0.99f && overlay.Color.A > 0.49f, "Overlay color mismatch");
            await Delay(0.15);
            b.QueueFree();
            return true;
        });

        // 7) Invert display on press
        AddTest("Invert on press sets material", async () =>
        {
            var b = MakeButton(new Vector2(60, 540), new Vector2(120, 60), ob =>
            {
                ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
                ob.InvertModes |= OmniButton.InvertDisplayModes.Press;
            });
            await Delay(0.15);
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            // any child (Icon or Overlay) should have material set
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            bool ok = icon != null && icon.Material != null;
            b._GuiInput(MousePressAt(p, false));
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, "Icon material not set on press");
            return true;
        });

        // 7b) Invert display on hover via property
        AddTest("Invert on hover via property", async () =>
        {
            var b = MakeButton(new Vector2(60, 620), new Vector2(120, 60), ob =>
            {
                ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
                ob.InvertModes |= OmniButton.InvertDisplayModes.Hover;
            });
            await Delay(0.15);
            b.EmitSignal("mouse_entered"); // triggers ApplyVisualState in setter
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            bool ok = icon != null && icon.Material != null;
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, "Icon material not set on hover");
            return true;
        });

        // 8) Label auto-fit bounds
        AddTest("Label auto-fit within range", async () =>
        {
            var b = MakeButton(new Vector2(220, 50), new Vector2(140, 40), ob =>
            {
                ob.LabelText = "A very very long label";
                ob.MinFontSize = 8;
                ob.MaxFontSize = 20;
                ob.Background = OmniButton.BackgroundMode.UsePanel;
            });
            await Delay(0.15);
            // Grab label and read font size override
            var label = b.GetNodeOrNull<Label>("Label");
            Assert(label != null, "Label missing");
            int fs = label.GetThemeFontSize("font_size");
            Assert(fs >= 8 && fs <= 20, $"Font size {fs} out of range");
            await Delay(0.15);
            b.QueueFree();
            return true;
        });

        // 9a) Pressing inside should not move control when follow is not enabled
        AddTest("Press does not move control", async () =>
        {
            var b = MakeButton(new Vector2(210, 130), new Vector2(100, 60), ob => { /* no follow properties */ });
            await Delay(0.1);
            var rect = b.GetGlobalRect();
            var target = rect.Position + new Vector2(rect.Size.X * 0.8f, rect.Size.Y * 0.2f);
            var before = b.GlobalPosition + b.Size / 2f;
            b._GuiInput(MousePressAt(target, true));
            await Delay(0.05);
            var after = b.GlobalPosition + b.Size / 2f;
            bool ok = (after - before).Length() < 0.5f;
            b._GuiInput(MousePressAt(target, false));
            b.QueueFree();
            Assert(ok, "Control should not relocate on press without follow feature");
            return true;
        });

        // 10) HitSlop expands hit area
        AddTest("HitSlop expands hit", async () =>
        {
            var b = MakeButton(new Vector2(220, 320), new Vector2(60, 40), ob =>
            {
                ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed;
                ob.HitSlop = new Vector2(20, 20);
            });
            await Delay(0.15);
            int pressed = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => pressed++));
            var rect = b.GetGlobalRect();
            // Point just outside original rect but within slop
            var justOutside = rect.Position + new Vector2(rect.Size.X + 10, rect.Size.Y / 2f);
            b._GuiInput(MousePressAt(justOutside, true));
            b._GuiInput(MousePressAt(justOutside, false));
            bool ok = pressed == 1;
            await Delay(0.15);
            b.QueueFree();
            Assert(ok, "Press not registered within HitSlop");
            return true;
        });

        // 11) Virtual joystick circle axis
        AddTest("VJ circle axis normalize", async () =>
        {
            var b = MakeButton(new Vector2(220, 400), new Vector2(60, 60), ob =>
            {
                ob.EnableVirtualJoystick = true;
                ob.ClampShape = OmniButton.JoystickClampShape.Circle;
                ob.JoystickRadiusPx = 50;
                ob.JoystickDeadzone = 0f;
                ob.JoystickSnapToInput = false;
            });
            await Delay(0.15);
            Vector2 axis = Vector2.Zero;
            b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => axis = a));
            var home = b.GlobalPosition + b.Size / 2f;
            b.StartVirtualJoystickAt(home);
            await Delay(0.1);
            b.UpdateVirtualJoystick(home + new Vector2(50, 0));
            bool ok = Nearly(axis, new Vector2(1, 0));
            b.StopVirtualJoystick();
            await Delay(0.1);
            b.QueueFree();
            Assert(ok, $"Axis expected (1,0), got {axis}");
            return true;
        });

        // 12) Virtual joystick rectangle axis
        AddTest("VJ rect axis normalize", async () =>
        {
            var b = MakeButton(new Vector2(220, 480), new Vector2(60, 60), ob =>
            {
                ob.EnableVirtualJoystick = true;
                ob.ClampShape = OmniButton.JoystickClampShape.Rectangle;
                ob.JoystickRectSizePx = new Vector2(100, 60); // half 50 x 30
                ob.JoystickDeadzone = 0f;
                ob.JoystickSnapToInput = false;
            });
            await Delay(0.15);
            Vector2 axis = Vector2.Zero;
            b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => axis = a));
            var home = b.GlobalPosition + b.Size / 2f;
            b.StartVirtualJoystickAt(home);
            await Delay(0.1);
            b.UpdateVirtualJoystick(home + new Vector2(50, 30));
            bool ok = Nearly(axis, new Vector2(1, 1));
            b.StopVirtualJoystick();
            await Delay(0.1);
            b.QueueFree();
            Assert(ok, $"Axis expected (1,1), got {axis}");
            return true;
        });

        // 13) VJ visibility + snap
        AddTest("VJ hide inactive + snap", async () =>
        {
            var b = MakeButton(new Vector2(380, 60), new Vector2(60, 60), ob =>
            {
                ob.EnableVirtualJoystick = true;
                ob.JoystickHideWhenInactive = true;
                ob.JoystickSnapToInput = true;
                ob.ClampShape = OmniButton.JoystickClampShape.Circle;
                ob.JoystickRadiusPx = 40;
            });
            // After ready, should be hidden
            Assert(!b.Visible, "Button should be hidden when inactive");
            var home = b.GlobalPosition + b.Size / 2f;
            var startPoint = home + new Vector2(10, 0);
            b.StartVirtualJoystickAt(startPoint);
            await Delay(0.1);
            Assert(b.Visible, "Button should be visible during joystick session");
            // With snap, center should move towards pointer
            bool moved = (b.GlobalPosition + b.Size / 2f - startPoint).Length() < 1.0f;
            b.StopVirtualJoystick();
            await Delay(0.1);
            Assert(!b.Visible, "Button should hide again after joystick stop");
            b.QueueFree();
            Assert(moved, "Button did not snap under input");
            return true;
        });

        // 1) Disabled button cannot be interacted with
        AddTest("Disabled blocks interaction", async () =>
        {
            var b = MakeButton(new Vector2(420, 140), new Vector2(100, 60), ob =>
            {
                ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed;
                ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Released;
                ob.Disabled = true;
            });
            await Delay(0.1);
            int pressed = 0, released = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => pressed++));
            b.Connect(OmniButton.SignalName.Released, Callable.From(() => released++));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            await Delay(0.1);
            bool ok = pressed == 0 && released == 0;
            b.QueueFree();
            Assert(ok, $"Disabled should block signals, got {pressed}/{released}");
            return true;
        });

        // 2) Button can be given a texture (+ size options, hover scale, invert on hover)
        AddTest("Icon: texture + size + hover", async () =>
        {
            var b = MakeButton(new Vector2(420, 220), new Vector2(120, 80), ob =>
            {
                ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
                ob.IconExpandMode = TextureRect.ExpandModeEnum.FitWidthProportional;
                ob.IconStretchMode = TextureRect.StretchModeEnum.Scale;
                ob.EnableHoverScale = true;
                ob.HoverScale = 1.4f;
                ob.InvertModes |= OmniButton.InvertDisplayModes.Hover;
            });
            await Delay(0.15);
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            Assert(icon != null && icon.Texture != null, "Icon/texture missing");
            Assert(icon.ExpandMode == TextureRect.ExpandModeEnum.FitWidthProportional, "ExpandMode not applied");
            Assert(icon.StretchMode == TextureRect.StretchModeEnum.Scale, "StretchMode not applied");
            b.EmitSignal("mouse_entered");
            SimProcess(b, 0.2);
            bool scaled = icon.Scale.X > 1.2f;
            bool inverted = icon.Material != null;
            b.QueueFree();
            Assert(scaled && inverted, "Hover scale or invert failed");
            return true;
        });

        // 4) Button can be given text (+ label tests)
        AddTest("Text label present", async () =>
        {
            var b = MakeButton(new Vector2(420, 320), new Vector2(160, 60), ob =>
            {
                ob.LabelText = "Sample Text";
            });
            await Delay(0.1);
            var label = b.GetNodeOrNull<Label>("Label");
            Assert(label != null && label.Text == "Sample Text", "Label missing or wrong");
            b.QueueFree();
            return true;
        });

        // 5) Text: fit, alignment, wrap, hover
        AddTest("Text fit, align, wrap, hover", async () =>
        {
            var b = MakeButton(new Vector2(420, 400), new Vector2(180, 70), ob =>
            {
                ob.LabelText = "This is a long label that should fit";
                ob.MinFontSize = 8; ob.MaxFontSize = 24;
                ob.LabelHorizontalAlignment = HorizontalAlignment.Left;
                ob.LabelVerticalAlignment = VerticalAlignment.Top;
                ob.LabelAutowrap = TextServer.AutowrapMode.Word;
                ob.EnableHoverScale = true; ob.HoverScale = 1.3f; ob.InvertModes |= OmniButton.InvertDisplayModes.Hover;
            });
            await Delay(0.1);
            var label = b.GetNodeOrNull<Label>("Label");
            Assert(label != null, "Label missing");
            int fs = label.GetThemeFontSize("font_size");
            Assert(fs >= 8 && fs <= 24, "Font size not within bounds");
            Assert(label.HorizontalAlignment == HorizontalAlignment.Left && label.VerticalAlignment == VerticalAlignment.Top, "Alignment not set");
            Assert(label.AutowrapMode == TextServer.AutowrapMode.Word, "Wrap not set");
            b.EmitSignal("mouse_entered"); SimProcess(b, 0.2);
            bool scaled = label.Scale.X > 1.1f; bool inverted = label.Material != null;
            b.QueueFree();
            Assert(scaled && inverted, "Text hover scale/invert failed");
            return true;
        });

        // 6) Button with both icon and text
        AddTest("Icon + Text", async () =>
        {
            var b = MakeButton(new Vector2(420, 500), new Vector2(160, 80), ob =>
            {
                ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
                ob.LabelText = "Play";
            });
            await Delay(0.1);
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            var label = b.GetNodeOrNull<Label>("Label");
            Assert(icon != null && label != null, "Icon and Label should exist");
            b.QueueFree();
            return true;
        });

        // 7/8/9/10) Panel with icon/text, hover scale, invert
        AddTest("Panel + Icon center, hover/invert", async () =>
        {
            var b = MakeButton(new Vector2(620, 120), new Vector2(140, 80), ob =>
            {
                ob.Background = OmniButton.BackgroundMode.UsePanel;
                ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png");
                ob.EnableHoverScale = true; ob.HoverScale = 1.25f; ob.InvertModes |= OmniButton.InvertDisplayModes.Hover;
            });
            await Delay(0.15);
            var panel = b.GetNodeOrNull<Panel>("Panel"); var icon = b.GetNodeOrNull<TextureRect>("Icon");
            Assert(panel != null && icon != null, "Panel or Icon missing");
            b.EmitSignal("mouse_entered"); SimProcess(b, 0.2);
            Assert(icon.Scale.X > 1.1f && icon.Material != null, "Hover effects not applied with panel");
            b.QueueFree();
            return true;
        });

        AddTest("Panel + Text center", async () =>
        {
            var b = MakeButton(new Vector2(620, 220), new Vector2(140, 60), ob =>
            {
                ob.Background = OmniButton.BackgroundMode.UsePanel;
                ob.LabelText = "Panel Text";
            });
            await Delay(0.1);
            Assert(b.GetNodeOrNull<Panel>("Panel") != null && b.GetNodeOrNull<Label>("Label") != null, "Panel+Text missing");
            b.QueueFree();
            return true;
        });

        // 11/12) Selected/unselected overlay via toggle + Selected flag
        AddTest("Selected overlay on", async () =>
        {
            var b = MakeButton(new Vector2(620, 300), new Vector2(140, 60), ob =>
            {
                ob.EnableSelectedOverlay = true; ob.Selected = true; ob.SelectedColor = new Color(0, 1, 0, 0.5f);
            });
            await Delay(0.1);
            var overlay = b.GetNodeOrNull<ColorRect>("Overlay");
            Assert(overlay != null && overlay.Color.G > 0.9f, "Selected overlay not visible");
            b.QueueFree();
            return true;
        });

        AddTest("Overlay via toggle uses SelectedColor", async () =>
        {
            var b = MakeButton(new Vector2(620, 380), new Vector2(140, 60), ob =>
            {
                ob.EnableSelectedOverlay = true; ob.IsToggled = true; // overlay shown via toggle
                ob.SelectedColor = new Color(0, 0, 1, 0.5f);
            });
            await Delay(0.1);
            var overlay = b.GetNodeOrNull<ColorRect>("Overlay");
            Assert(overlay != null && overlay.Color.B > 0.9f, "Overlay did not use SelectedColor for toggle");
            b.QueueFree();
            return true;
        });

        // 13a) Signal: Pressed
        AddTest("Signal: Pressed", async () =>
        {
            var b = MakeButton(new Vector2(620, 440), new Vector2(140, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed; });
            int count = 0; b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => count++));
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); b._GuiInput(MousePressAt(p, false));
            b.QueueFree(); Assert(count == 1, "Pressed not emitted once"); return true;
        });

        // 13b) Signal: Released
        AddTest("Signal: Released", async () =>
        {
            var b = MakeButton(new Vector2(620, 500), new Vector2(140, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Released; });
            int count = 0; b.Connect(OmniButton.SignalName.Released, Callable.From(() => count++));
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); b._GuiInput(MousePressAt(p, false));
            b.QueueFree(); Assert(count == 1, "Released not emitted once"); return true;
        });

        // 13c) Signal: HoverIn
        AddTest("Signal: HoverIn", async () =>
        {
            var b = MakeButton(new Vector2(620, 560), new Vector2(140, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hover; });
            int count = 0; b.Connect(OmniButton.SignalName.HoverIn, Callable.From(() => count++));
            b.EmitSignal("mouse_entered");
            b.QueueFree(); Assert(count == 1, "HoverIn not emitted"); return true;
        });

        // 13d) Signal: HoverOut
        AddTest("Signal: HoverOut", async () =>
        {
            var b = MakeButton(new Vector2(620, 620), new Vector2(140, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hover; });
            int count = 0; b.Connect(OmniButton.SignalName.HoverOut, Callable.From(() => count++));
            b.EmitSignal("mouse_entered"); b.EmitSignal("mouse_exited");
            b.QueueFree(); Assert(count == 1, "HoverOut not emitted"); return true;
        });

        // 13e) Signal: Toggled
        AddTest("Signal: Toggled", async () =>
        {
            var b = MakeButton(new Vector2(780, 440), new Vector2(140, 60), ob => { ob.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress; });
            int count = 0; bool last = false; b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(v => { count++; last = v; }));
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); b._GuiInput(MousePressAt(p, false));
            b.QueueFree(); Assert(count == 1 && last == true, "Toggled not emitted true once"); return true;
        });

        // 13f) Signal: Hold
        AddTest("Signal: Hold", async () =>
        {
            var b = MakeButton(new Vector2(780, 500), new Vector2(140, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hold; ob.HoldDuration = 0.05f; });
            int count = 0; b.Connect(OmniButton.SignalName.Hold, Callable.From(() => count++));
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); SimProcess(b, 0.06); b._GuiInput(MousePressAt(p, false));
            b.QueueFree(); Assert(count == 1, "Hold not emitted once"); return true;
        });

        // 13g) Signal: Swipe
        AddTest("Signal: Swipe", async () =>
        {
            var b = MakeButton(new Vector2(780, 560), new Vector2(160, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Swipe; ob.SwipeThreshold = 12f; });
            int count = 0; b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(_ => count++));
            var p = Center(b); b._GuiInput(new InputEventScreenDrag { Position = p }); b._GuiInput(new InputEventScreenDrag { Position = p + new Vector2(20, 0) });
            b.QueueFree(); Assert(count == 1, "Swipe not emitted once"); return true;
        });

        // 13h) Signal: Log
        AddTest("Signal: Log", async () =>
        {
            var b = MakeButton(new Vector2(940, 440), new Vector2(140, 60));
            int count = 0; b.Connect(OmniButton.SignalName.Log, Callable.From<string>(_ => count++));
            b.PrintLog("x"); b.QueueFree(); Assert(count == 1, "Log not emitted"); return true;
        });

        // 13i) Signal: Warning
        AddTest("Signal: Warning", async () =>
        {
            var b = MakeButton(new Vector2(940, 500), new Vector2(140, 60));
            int count = 0; b.Connect(OmniButton.SignalName.Warning, Callable.From<string>(_ => count++));
            b.PrintWarn("y"); b.QueueFree(); Assert(count == 1, "Warning not emitted"); return true;
        });

        // 13j) Signal: Error
        AddTest("Signal: Error", async () =>
        {
            var b = MakeButton(new Vector2(940, 560), new Vector2(140, 60));
            int count = 0; b.Connect(OmniButton.SignalName.Error, Callable.From<string>(_ => count++));
            b.EmitSignal(OmniButton.SignalName.Error, "z"); b.QueueFree(); Assert(count == 1, "Error not emitted"); return true;
        });

        // 13k) Signal: JoystickStarted
        AddTest("Signal: JoystickStarted", async () =>
        {
            var b = MakeButton(new Vector2(1100, 440), new Vector2(80, 80), ob => { ob.EnableVirtualJoystick = true; ob.JoystickRadiusPx = 30; });
            int count = 0; b.Connect(OmniButton.SignalName.JoystickStarted, Callable.From(() => count++));
            var home = b.GlobalPosition + b.Size / 2f; b.StartVirtualJoystickAt(home);
            b.StopVirtualJoystick(); b.QueueFree(); Assert(count == 1, "JoystickStarted not emitted"); return true;
        });

        // 13l) Signal: JoystickAxis
        AddTest("Signal: JoystickAxis", async () =>
        {
            var b = MakeButton(new Vector2(1100, 540), new Vector2(80, 80), ob => { ob.EnableVirtualJoystick = true; ob.JoystickRadiusPx = 30; ob.JoystickDeadzone = 0f; ob.JoystickSnapToInput = false; ob.BoundsSource = _arena; });
            Vector2 observed = new Vector2(-999, -999);
            b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a =>
            {
                // capture first non-zero axis so StopVirtualJoystick's zero does not overwrite it
                if (observed.X == -999 && observed.Y == -999 && a.Length() > 0.05f)
                    observed = a;
            }));
            var home = b.GlobalPosition + b.Size / 2f;
            b.StartVirtualJoystickAt(home);
            b.UpdateVirtualJoystick(home + new Vector2(30, 0));
            await Delay(0.05);
            bool ok = observed.X > 0.9f && Mathf.Abs(observed.Y) < 0.1f;
            b.StopVirtualJoystick();
            b.QueueFree();
            Assert(ok, $"JoystickAxis unexpected: {observed}");
            return true;
        });

        // 13m) Signal: JoystickEnded
        AddTest("Signal: JoystickEnded", async () =>
        {
            var b = MakeButton(new Vector2(1100, 640), new Vector2(80, 80), ob => { ob.EnableVirtualJoystick = true; });
            int count = 0; b.Connect(OmniButton.SignalName.JoystickEnded, Callable.From(() => count++));
            var home = b.GlobalPosition + b.Size / 2f; b.StartVirtualJoystickAt(home); b.StopVirtualJoystick();
            b.QueueFree(); Assert(count == 1, "JoystickEnded not emitted"); return true;
        });

        // 14/15) Pressed+Released; Toggle with Selected visual
        AddTest("Toggle + Selected visual", async () =>
        {
            var b = MakeButton(new Vector2(820, 120), new Vector2(140, 60), ob =>
            {
                ob.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress; ob.EnableSelectedOverlay = true; ob.SelectedColor = new Color(1, 1, 0, 0.5f);
            });
            b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(v => b.Selected = v));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true)); await Delay(0.05); b._GuiInput(MousePressAt(p, false));
            await Delay(0.1);
            var overlay = b.GetNodeOrNull<ColorRect>("Overlay");
            Assert(overlay != null && overlay.Color.R > 0.9f && overlay.Color.G > 0.9f && overlay.Color.B < 0.1f && overlay.Color.A >= 0.49f, "Selected overlay not reflecting toggle");
            b.QueueFree();
            return true;
        });

        // (replaced by 16a/16b above)

        // 17) Swipe threshold
        AddTest("Swipe threshold", async () =>
        {
            var b = MakeButton(new Vector2(820, 360), new Vector2(120, 60), ob => { ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Swipe; ob.SwipeThreshold = 30; });
            int count = 0; b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(_ => count++));
            var p = Center(b);
            b._GuiInput(new InputEventScreenDrag { Position = p });
            b._GuiInput(new InputEventScreenDrag { Position = p + new Vector2(20, 0) }); // below threshold
            b._GuiInput(new InputEventScreenDrag { Position = p });
            b._GuiInput(new InputEventScreenDrag { Position = p + new Vector2(40, 0) }); // above
            await Delay(0.1);
            b.QueueFree();
            Assert(count == 1, "Swipe threshold not enforced");
            return true;
        });

        // 19) Without follow enabled, pressing and moving should not relocate control
        AddTest("No follow: press/move does not relocate", async () =>
        {
            var bounds = new Control { Position = new Vector2(780, 500), Size = new Vector2(260, 180) }; _arena.AddChild(bounds);
            var b = MakeButton(new Vector2(800, 520), new Vector2(60, 40), ob => { ob.BoundsSource = bounds; ob.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed; });
            var startCenter = b.GlobalPosition + b.Size / 2f;
            var target = bounds.GetGlobalRect().Position + new Vector2(200, 120);
            b._GuiInput(MousePressAt(target, true));
            b._GuiInput(new InputEventMouseMotion { GlobalPosition = target - new Vector2(500, 500) });
            var endCenter = b.GlobalPosition + b.Size / 2f;
            b._GuiInput(MousePressAt(target, false));
            bounds.QueueFree(); b.QueueFree();
            Assert((endCenter - startCenter).Length() < 0.5f, "Control should not relocate without follow features");
            return true;
        });

        // 20a) Cooldown on press shows/hides
        AddTest("Cooldown on press shows/hides", async () =>
        {
            var b = MakeButton(new Vector2(1060, 120), new Vector2(120, 60), ob => { ob.EnableCooldown = true; ob.CooldownTrigger = OmniButton.CooldownTriggerEnum.OnPress; ob.CooldownDuration = 0.2f; ob.CooldownFillDirection = OmniButton.CooldownDirection.LeftToRight; });
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); b._GuiInput(MousePressAt(p, false));
            await Delay(0.02); SimProcess(b, 0.02);
            var cd = b.GetNodeOrNull<ColorRect>("Cooldown"); bool visible = cd != null;
            SimProcess(b, 0.25); bool gone = cd == null || !cd.Visible;
            b.QueueFree(); Assert(visible && gone, "Cooldown on press visibility incorrect"); return true;
        });
        // 20b) Cooldown on release shows
        AddTest("Cooldown on release shows", async () =>
        {
            var b = MakeButton(new Vector2(1060, 160), new Vector2(120, 60), ob => { ob.EnableCooldown = true; ob.CooldownTrigger = OmniButton.CooldownTriggerEnum.OnRelease; ob.CooldownDuration = 0.15f; ob.CooldownFillDirection = OmniButton.CooldownDirection.BottomToTop; });
            var p = Center(b); b._GuiInput(MousePressAt(p, true)); await Delay(0.02); b._GuiInput(MousePressAt(p, false));
            await Delay(0.02); SimProcess(b, 0.02); var cd = b.GetNodeOrNull<ColorRect>("Cooldown"); bool visible = cd != null && cd.Visible; b.QueueFree(); Assert(visible, "Cooldown on release not visible"); return true;
        });

        // 22) Different hover scaling values
        AddTest("Hover scaling values", async () =>
        {
            var b = MakeButton(new Vector2(1060, 220), new Vector2(120, 60), ob => { ob.LabelText = "Scale"; ob.EnableHoverScale = true; ob.HoverScale = 1.8f; });
            b.EmitSignal("mouse_entered"); SimProcess(b, 0.3); bool s1 = b.GetNodeOrNull<Label>("Label").Scale.X > 1.5f;
            b.QueueFree();
            var c = MakeButton(new Vector2(1060, 220), new Vector2(120, 60), ob => { ob.LabelText = "Scale"; ob.EnableHoverScale = true; ob.HoverScale = 1.2f; });
            c.EmitSignal("mouse_entered"); SimProcess(c, 0.3); bool s2 = c.GetNodeOrNull<Label>("Label").Scale.X > 1.1f && c.GetNodeOrNull<Label>("Label").Scale.X < 1.5f;
            c.QueueFree();
            Assert(s1 && s2, "Hover scaling values not applied");
            return true;
        });

        // 23) Invert display using different functions
        AddTest("Invert on press/toggle/hover", async () =>
        {
            var b = MakeButton(new Vector2(1060, 300), new Vector2(120, 60), ob => { ob.IconTexture = GD.Load<Texture2D>("res://addons/omni_button/test/icons/Icon-Circle1.png"); ob.InvertModes = OmniButton.InvertDisplayModes.Press | OmniButton.InvertDisplayModes.Toggle | OmniButton.InvertDisplayModes.Hover; ob.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress; });
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            var p = Center(b);
            // press
            b._GuiInput(MousePressAt(p, true)); bool onPress = icon.Material != null; b._GuiInput(MousePressAt(p, false));
            // toggle (on press already toggled to true)
            bool onToggle = icon.Material != null;
            // hover
            b.EmitSignal("mouse_entered"); bool onHover = icon.Material != null;
            b.QueueFree();
            Assert(onPress && onToggle && onHover, "Invert modes failed");
            return true;
        });

        // 24/25) Virtual joystick full suite
        AddTest("VJ: circle/rect/deadzone/reset/snap/hide", async () =>
        {
            var circle = MakeButton(new Vector2(1060, 380), new Vector2(60, 60), ob => { ob.EnableVirtualJoystick = true; ob.ClampShape = OmniButton.JoystickClampShape.Circle; ob.JoystickRadiusPx = 40; ob.JoystickDeadzone = 0.2f; ob.JoystickSnapToInput = false; ob.JoystickResetOnRelease = true; });
            Vector2 axis = Vector2.One; circle.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => axis = a));
            var hc = circle.GlobalPosition + circle.Size / 2f; circle.StartVirtualJoystickAt(hc); circle.UpdateVirtualJoystick(hc + new Vector2(5, 0)); // within deadzone
            bool dz = axis == Vector2.Zero;
            circle.UpdateVirtualJoystick(hc + new Vector2(40, 0)); bool circ = axis.X > 0.9f && Mathf.Abs(axis.Y) < 0.1f; circle.StopVirtualJoystick();
            // snap/hide
            var snap = MakeButton(new Vector2(1140, 380), new Vector2(60, 60), ob => { ob.EnableVirtualJoystick = true; ob.JoystickHideWhenInactive = true; ob.JoystickSnapToInput = true; ob.ClampShape = OmniButton.JoystickClampShape.Circle; ob.JoystickRadiusPx = 30; });
            Assert(!snap.Visible, "Should start hidden"); var hs = snap.GlobalPosition + snap.Size / 2f; var start = hs + new Vector2(10, 0); snap.StartVirtualJoystickAt(start); bool visible = snap.Visible; bool snapped = (snap.GlobalPosition + snap.Size / 2f - start).Length() < 1.0f; snap.StopVirtualJoystick(); bool hidden = !snap.Visible;
            // rectangle
            var rect = MakeButton(new Vector2(1220, 380), new Vector2(60, 60), ob => { ob.EnableVirtualJoystick = true; ob.ClampShape = OmniButton.JoystickClampShape.Rectangle; ob.JoystickRectSizePx = new Vector2(80, 40); ob.JoystickDeadzone = 0f; });
            Vector2 ax2 = Vector2.Zero; rect.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => ax2 = a)); var hr = rect.GlobalPosition + rect.Size / 2f; rect.StartVirtualJoystickAt(hr); rect.UpdateVirtualJoystick(hr + new Vector2(40, 20)); bool rectOk = Nearly(ax2, new Vector2(1, 1)); rect.StopVirtualJoystick();
            circle.QueueFree(); snap.QueueFree(); rect.QueueFree();
            Assert(dz && circ && visible && snapped && hidden && rectOk, "Virtual joystick features failed");
            return true;
        });
    }
}














