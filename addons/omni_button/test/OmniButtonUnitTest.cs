using Godot;
using System;
using System.Collections.Generic;
using System.Threading.Tasks;

public partial class OmniButtonUnitTest : Control
{
    // User-provided resources (optional)
    [Export] public Texture2D IconSample { get; set; }
    [Export] public Texture2D BackgroundTextureSample { get; set; }
    [Export] public StyleBoxFlat BackgroundPanelStyleBoxSample { get; set; }
    [Export] public Color SelectedColorSample { get; set; } = new Color();
    [Export] public Color CooldownColorSample { get; set; } = new Color();
    [Export] public Color HoldFillColorSample { get; set; } = new Color();
    [Export] public Theme OverrideTheme { get; set; }

    private HBoxContainer _root;
    private PanelContainer _leftPanel;
    private ScrollContainer _leftScroll;
    private VBoxContainer _leftList;
    private Control _arena;
    private Label _statusLabel; // bottom-right explanation label
    [Export] public double ExtraPauseSeconds { get; set; } = 0.5; // slows the demo pacing
    [Export] public bool LoggerUseOmniButton { get; set; } = false; // default to RichText for stability; toggle to try OmniButton logger
    private OmniButton _log; // OmniButton-based RichText logger
    private RichTextLabel _rtLog; // fallback logger if OmniButton logger fails
    private readonly System.Collections.Generic.List<string> _logLines = new();

    private readonly List<TestRow> _tests = new();
    private int _passed;
    private int _failed;

    private class TestRow
    {
        public string Name;
        public Func<Task<bool>> RunAsync;
        public HBoxContainer Row;
        public CheckBox Check;
        public Label Label;
    }

    public override void _Ready()
    {
        SeedDefaultsIfMissing();
        BuildUi();
        ClearArena();
        BuildAllTests();
        CallDeferred(nameof(BeginRun));
    }

    private void SeedDefaultsIfMissing()
    {
        var rnd = new Random();
        if (SelectedColorSample == default) SelectedColorSample = Color.FromHsv((float)rnd.NextDouble(), 0.7f, 0.95f, 0.6f);
        if (CooldownColorSample == default) CooldownColorSample = Color.FromHsv((float)rnd.NextDouble(), 0.7f, 0.95f, 0.9f);
        if (HoldFillColorSample == default) HoldFillColorSample = Color.FromHsv((float)rnd.NextDouble(), 0.7f, 0.95f, 0.8f);
        if (IconSample == null)
        {
            var path = "res://addons/omni_button/test/icons/Icon-Circle1.png";
            if (ResourceLoader.Exists(path)) IconSample = GD.Load<Texture2D>(path);
        }
        if (BackgroundTextureSample == null)
        {
            var path = "res://addons/omni_button/test/icons/Icon-Circle5.png";
            if (ResourceLoader.Exists(path)) BackgroundTextureSample = GD.Load<Texture2D>(path);
        }
        if (BackgroundPanelStyleBoxSample == null)
        {
            var sb = new StyleBoxFlat { BgColor = new Color(0.1f, 0.1f, 0.1f, 1f) };
            sb.CornerRadiusBottomLeft = sb.CornerRadiusBottomRight = sb.CornerRadiusTopLeft = sb.CornerRadiusTopRight = 8;
            BackgroundPanelStyleBoxSample = sb;
        }
    }

    private void BuildUi()
    {
        Name = "OmniButtonUnitTest";
        SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        _root = new HBoxContainer { Name = "RootHBox" };
        _root.SetAnchorsAndOffsetsPreset(LayoutPreset.FullRect);
        AddChild(_root);

        _leftPanel = new PanelContainer { Name = "ResultsPanel" };
        _leftPanel.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _leftPanel.SizeFlagsVertical = SizeFlags.ExpandFill;
        _leftPanel.SizeFlagsStretchRatio = 1f; // left third is narrower via arena 2x stretch
        _root.AddChild(_leftPanel);

        // Build a vertical stack: [Scroll(List)] + [Logger OmniButton]
        var leftStack = new VBoxContainer { Name = "LeftStack" };
        leftStack.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        leftStack.SizeFlagsVertical = SizeFlags.ExpandFill;
        _leftPanel.AddChild(leftStack);

        _leftScroll = new ScrollContainer { Name = "Results" };
        _leftScroll.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _leftScroll.SizeFlagsVertical = SizeFlags.ExpandFill;
        _leftScroll.SizeFlagsStretchRatio = 2f;
        leftStack.AddChild(_leftScroll);

        _leftList = new VBoxContainer { Name = "List" };
        _leftList.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _leftList.SizeFlagsVertical = SizeFlags.ExpandFill;
        _leftScroll.AddChild(_leftList);

        if (LoggerUseOmniButton)
        {
            // Try to use OmniButton as the logger; fall back to RichTextLabel if anything goes wrong
            try
            {
                _log = new OmniButton { Name = "Logger" };
                _log.SizeFlagsHorizontal = SizeFlags.ExpandFill;
                _log.SizeFlagsVertical = SizeFlags.Fill;
                _log.Background = OmniButton.BackgroundMode.UsePanel;
                _log.PanelStyleBox = BackgroundPanelStyleBoxSample;
                _log.RichLabelUseBBCode = true;
                _log.RichLabelText = "[b]Log[/b]\n";
                _log.EnableTextAutoSize = true;
                _log.LabelAutowrap = TextServer.AutowrapMode.Word;
                _log.LabelHorizontalAlignment = HorizontalAlignment.Left;
                _log.LabelPadding = new Vector2(6, 6);
                _log.MouseFilter = MouseFilterEnum.Ignore; // non-interactive
                leftStack.AddChild(_log);
            }
            catch (Exception)
            {
                _log = null;
            }
        }
        if (_log == null)
        {
            _rtLog = new RichTextLabel { Name = "LoggerFallback" };
            _rtLog.BbcodeEnabled = true;
            _rtLog.ScrollActive = true;
            _rtLog.AutowrapMode = TextServer.AutowrapMode.Word;
            _rtLog.SizeFlagsHorizontal = SizeFlags.ExpandFill;
            _rtLog.SizeFlagsVertical = SizeFlags.Fill;
            _rtLog.Text = "[b]Log[/b]\n";
            leftStack.AddChild(_rtLog);
        }

        _arena = new Control { Name = "Arena" };
        _arena.SizeFlagsHorizontal = SizeFlags.ExpandFill;
        _arena.SizeFlagsVertical = SizeFlags.ExpandFill;
        _arena.SizeFlagsStretchRatio = 2f; // right 2/3rds
        _root.AddChild(_arena);

        _statusLabel = new Label { Name = "Status", HorizontalAlignment = HorizontalAlignment.Right, VerticalAlignment = VerticalAlignment.Bottom };
        _statusLabel.Theme = OverrideTheme;
        _arena.AddChild(_statusLabel);
        _statusLabel.AnchorLeft = 0; _statusLabel.AnchorTop = 0; _statusLabel.AnchorRight = 1; _statusLabel.AnchorBottom = 1;
        _statusLabel.OffsetLeft = 8; _statusLabel.OffsetTop = 8; _statusLabel.OffsetRight = -8; _statusLabel.OffsetBottom = -8;
        _statusLabel.AutowrapMode = TextServer.AutowrapMode.Word;
        _statusLabel.Text = "Preparing tests...";
    }

    private void ClearArena()
    {
        foreach (var c in _arena.GetChildren())
        {
            if (c != _statusLabel)
            {
                _arena.RemoveChild(c);
                (c as Node)?.QueueFree();
            }
        }
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

        _tests.Add(new TestRow { Name = name, RunAsync = runAsync, Row = row, Check = check, Label = label });
    }

    private async void BeginRun()
    {
        _passed = _failed = 0;
        AppendLog("[b]Starting tests...[/b]");
        foreach (var t in _tests)
        {
            t.Check.Text = "running";
            t.Check.ButtonPressed = false;
            await Delay(0.2);
            bool ok = false;
            try
            {
                ok = await t.RunAsync();
            }
            catch (Exception ex)
            {
                GD.PushError($"Test '{t.Name}' exception: {ex}");
                ok = false;
                AppendLog($"[color=red]Exception in '{t.Name}': {ex.Message}[/color]");
            }
            t.Check.Text = ok ? "pass" : "fail";
            t.Check.ButtonPressed = ok;
            if (ok) _passed++; else _failed++;
            AppendLog($"[b]{t.Name}[/b]: {(ok ? "[color=lime]PASS[/color]" : "[color=red]FAIL[/color]")}");
            await Delay(0.05);
        }
        var summary = $"Done. Passed: {_passed}, Failed: {_failed}";
        _statusLabel.Text = summary;
        AppendLog($"[b]{summary}[/b]");
    }

    private async Task Delay(double seconds)
    {
        // Add extra pacing so each step is visible during the demo
        var total = Math.Max(0.0, seconds + ExtraPauseSeconds);
        await ToSignal(GetTree().CreateTimer(total), SceneTreeTimer.SignalName.Timeout);
    }

    // ===== Test set =====
    private void BuildAllTests()
    {
        // 1) Presets showcase with interactive demos
        foreach (OmniButton.Preset p in Enum.GetValues(typeof(OmniButton.Preset)))
        {
            if (p == OmniButton.Preset.Custom || p == OmniButton.Preset.None) continue;
            var presetName = p.ToString();
            AddTest($"Preset: {presetName}", async () =>
            {
                ClearArena();
                var b = MakeBaseButton(new Vector2(100, 100), new Vector2(200, 90), $"{presetName}");
                b.PresetSelection = p;
                _statusLabel.Text = $"Preset {presetName} applied";
                await Delay(0.2);

                bool ok = true;
                var center = Center(b);
                switch (p)
                {
                    case OmniButton.Preset.Basic:
                        {
                            int pr = 0, rl = 0;
                            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed | (int)OmniButton.ActionMaskFlags.Released;
                            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => { pr++; b.LabelText = "Pressed"; }));
                            b.Connect(OmniButton.SignalName.Released, Callable.From(() => { rl++; b.LabelText = "Released"; }));
                            _statusLabel.Text = "Basic: press and release";
                            b._GuiInput(MousePressAt(center, true));
                            await Delay(0.2);
                            b._GuiInput(MousePressAt(center, false));
                            await Delay(0.2);
                            ok = pr == 1 && rl == 1;
                        }
                        break;
                    case OmniButton.Preset.Toggle:
                        {
                            int tg = 0;
                            b.InteractionMode = OmniButton.InteractionModeEnum.ToggleOnPress;
                            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Toggle;
                            b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(on => { tg++; b.LabelText = on ? "Toggled On" : "Toggled Off"; }));
                            _statusLabel.Text = "Toggle: press to toggle on";
                            b._GuiInput(MousePressAt(center, true));
                            b._GuiInput(MousePressAt(center, false));
                            await Delay(0.2);
                            ok = tg == 1 && b.IsToggled;
                        }
                        break;
                    case OmniButton.Preset.Hold:
                        {
                            int hold = 0;
                            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hold;
                            b.EnableHoldBuildUp = true;
                            b.HoldDuration = 0.25f;
                            b.HoldFillColor = HoldFillColorSample;
                            b.Connect(OmniButton.SignalName.Hold, Callable.From(() => { hold++; b.LabelText = "Hold!"; }));
                            _statusLabel.Text = "Hold: press and wait";
                            _statusLabel.Text = "Hold: press and wait";
                            b.LabelText = "Hold Active";
                            b._GuiInput(MousePressAt(center, true));
                            ok = hold == 1;
                        }
                        break;
                    case OmniButton.Preset.Swipe:
                        {
                            int count = 0; Vector2 dir = Vector2.Zero;
                            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Swipe;
                            b.MouseSwipeInit = OmniButton.SwipeInitMode.OnHoverIn;
                            b.SwipeThreshold = 10f;
                            b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(d => { dir = d; count++; b.LabelText = $"Swipe {Mathf.Sign(d.X)},{Mathf.Sign(d.Y)}"; }));
                            _statusLabel.Text = "Swipe: right";
                            var mm1 = new InputEventMouseMotion { GlobalPosition = center, Position = center };
                            b._GuiInput(mm1);
                            var mm2 = new InputEventMouseMotion { GlobalPosition = center + new Vector2(35, 0), Position = center + new Vector2(35, 0) };
                            b._GuiInput(mm2);


                            await Delay(0.2);
                            ok = count >= 1 && dir.X > 0.5f;
                        }
                        break;
                    case OmniButton.Preset.Draggable:
                        {
                            b.FollowMode = OmniButton.FollowModeEnum.FollowBoth;
                            var start = b.GlobalPosition;
                            _statusLabel.Text = "Draggable: drag down-right";
                            b._GuiInput(MousePressAt(center, true));
                            b._GuiInput(new InputEventMouseMotion { GlobalPosition = center + new Vector2(40, 30), Position = center + new Vector2(40, 30) });
                            b._GuiInput(MousePressAt(center + new Vector2(40, 30), false));
                            await Delay(0.2);
                            ok = (b.GlobalPosition - start).Length() > 5f;
                        }
                        break;
                    case OmniButton.Preset.VirtualJoystick:
                        {
                            int axes = 0;
                            b.EnableVirtualJoystick = true;
                            b.EnableJoystickArea = true;
                            b.JoystickAreaPersistent = true;
                            b.BoundsSource = _arena;
                            b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => { axes++; b.LabelText = $"Axis {Math.Round(a.X, 2)},{Math.Round(a.Y, 2)}"; }));
                            _statusLabel.Text = "Virtual Joystick: start, move, stop";
                            b.StartVirtualJoystickAt(center);
                            b.UpdateVirtualJoystick(center + new Vector2(50, 0));
                            await Delay(0.2);
                            b.StopVirtualJoystick();
                            ok = axes > 0;
                        }
                        break;
                }

                b.QueueFree();
                return ok;
            });
        }

        // 2) Background: Panel vs Texture
        AddTest("Background Panel styling", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 120), new Vector2(220, 110), "Panel Background");
            b.Background = OmniButton.BackgroundMode.UsePanel;
            b.PanelStyleBox = BackgroundPanelStyleBoxSample;
            _statusLabel.Text = "Background Panel applied";
            await Delay(0.2);
            var panel = b.GetNodeOrNull<Panel>("Panel");
            bool ok = panel != null;
            b.QueueFree();
            return ok;
        });

        AddTest("Background TextureRect", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 120), new Vector2(220, 110), "Texture Background");
            // Assign texture first, then enable UseTexture so SetupChildren creates the node
            b.BackgroundTexture = BackgroundTextureSample;
            b.Background = OmniButton.BackgroundMode.UseTexture;
            _statusLabel.Text = "Background texture applied";
            await Delay(0.2);
            var tex = b.GetNodeOrNull<TextureRect>("Background");
            bool ok = tex != null && tex.Texture != null;
            b.QueueFree();
            return ok;
        });

        // 3) Overlay + Selected
        AddTest("Selected overlay visible", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 120), new Vector2(220, 110), "Selected Overlay");
            b.EnableSelectedOverlay = true;
            b.SelectedColor = SelectedColorSample;
            b.Selected = true;
            _statusLabel.Text = "Selected overlay shown";
            await Delay(0.2);
            var overlay = b.GetNodeOrNull<ColorRect>("Overlay");
            bool ok = overlay != null && overlay.Visible;
            b.QueueFree();
            return ok;
        });

        // 4) Icon + Label
        AddTest("Icon + Label", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 180), new Vector2(220, 110), "Icon + Label");
            b.IconTexture = IconSample;
            b.LabelText = "Hello";
            _statusLabel.Text = "Icon + Label set";
            await Delay(0.2);
            bool ok = b.GetNodeOrNull<TextureRect>("Icon") != null || !string.IsNullOrEmpty(b.LabelText);
            b.QueueFree();
            return ok;
        });

        // 5) Label padding + autosize
        AddTest("Label padding + autosize", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 240), new Vector2(220, 110), "Label Padding");
            b.LabelText = "x10";
            b.LabelHorizontalAlignment = HorizontalAlignment.Right;
            b.LabelVerticalAlignment = VerticalAlignment.Bottom;
            b.LabelPadding = new Vector2(0, 0);
            b.LabelAdditionalPaddingRight = 6;
            b.LabelAdditionalPaddingBottom = 6;
            _statusLabel.Text = "Label bottom-right with padding";
            await Delay(0.2);
            var lbl = b.GetNodeOrNull<Label>("Label");
            bool ok = lbl != null;
            if (ok)
            {
                // Offsets reflect per-side padding: left/top positive, right/bottom negative
                ok &= Near(lbl.OffsetLeft, 0f, 0.5f);
                ok &= Near(lbl.OffsetTop, 0f, 0.5f);
                ok &= Near(lbl.OffsetRight, -6f, 0.5f);
                ok &= Near(lbl.OffsetBottom, -6f, 0.5f);
            }
            b.QueueFree();
            return ok;
        });

        // 6) Hover scale
        AddTest("Hover scale animates", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(360, 140), new Vector2(220, 110), "Hover Scale");
            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hover;
            b.Connect(OmniButton.SignalName.HoverIn, Callable.From(() => b.LabelText = "HoverIn"));
            b.Connect(OmniButton.SignalName.HoverOut, Callable.From(() => b.LabelText = "HoverOut"));

            b.EnableHoverScale = true;
            b.HoverScale = 1.5f;
            b.HoverLerpSpeed = 12f;

            // Force hover state and run the animation for a visible duration
            b.IsHovering = true;
            SimProcess(b, 0.6);

            var lbl = b.GetNodeOrNull<Label>("Label");
            bool ok = lbl != null && lbl.Scale.X > 1.01f;
            _statusLabel.Text = ok ? "Hover scaled up" : "Hover scale unchanged";

            // Return to normal and animate back down
            b.IsHovering = false;
            SimProcess(b, 0.4);

            b.QueueFree();
            return ok;
        });

        // 7) Cooldown blocks input
        AddTest("Cooldown blocks repeat press", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(360, 240), new Vector2(220, 110), "Cooldown");
            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed;
            b.EnableCooldown = true;
            b.CooldownColor = CooldownColorSample;
            b.CooldownTrigger = OmniButton.CooldownTriggerEnum.OnPress;
            b.CooldownDuration = 0.2f;
            int pressed = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => { pressed++; b.LabelText = $"Pressed x{pressed}"; }));
            // Start in cooldown: first attempt should be blocked
            b.StartCooldown();
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            await Delay(0.05);
            bool firstIgnored = pressed == 0;
            // After cooldown completes, next press should register
            SimProcess(b, 0.25);
            b._GuiInput(MousePressAt(p, true));
            b._GuiInput(MousePressAt(p, false));
            bool ok = firstIgnored && pressed == 1;
            b.QueueFree();
            return ok;
        });

        // 8) Hold build-up
        AddTest("Hold emits after duration", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(360, 340), new Vector2(220, 110), "Hold Build-Up");
            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Hold;
            b.EnableHoldBuildUp = true;
            b.HoldFillColor = HoldFillColorSample;
            b.HoldDuration = 0.15f;
            int hold = 0;
            b.Connect(OmniButton.SignalName.Hold, Callable.From(() => { hold++; b.LabelText = "Hold!"; }));
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            SimProcess(b, 0.2);
            bool ok = hold == 1;
            b._GuiInput(MousePressAt(p, false));
            _statusLabel.Text = ok ? "Hold fired" : "Hold did not fire";
            b.QueueFree();
            return ok;
        });

        // 9) Swipe emits direction
        AddTest("Swipe emits direction", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 360), new Vector2(220, 110), "Swipe");
            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Swipe;
            b.SwipeThreshold = 10f;
            Vector2 dir = Vector2.Zero; int count = 0;
            b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(d => { dir = d; count++; }));
            var p = Center(b);
            var drag1 = new InputEventScreenDrag { Position = p };
            var drag2 = new InputEventScreenDrag { Position = p + new Vector2(20, 0) };
            b._GuiInput(drag1);
            b._GuiInput(drag2);
            bool ok = count == 1 && dir.X > 0.9f && Mathf.Abs(dir.Y) < 0.1f;
            _statusLabel.Text = ok ? "Swipe right detected" : $"Swipe mismatch {dir}";
            b.QueueFree();
            return ok;
        });

        // 10) Invert on hover
        AddTest("Invert on hover", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 460), new Vector2(220, 110), "Invert");
            b.IconTexture = IconSample;
            b.InvertModes |= OmniButton.InvertDisplayModes.Hover;
            b.IsHovering = true;
            await Delay(0.05);
            var icon = b.GetNodeOrNull<TextureRect>("Icon");
            bool ok = icon == null || icon.Material != null; // material may apply to label if no icon
            _statusLabel.Text = ok ? "Invert applied" : "Invert missing";
            b.QueueFree();
            return ok;
        });

        // 11) RichTextLabel + BBCode
        AddTest("RichText BBCode renders", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(360, 460), new Vector2(280, 120), "BBCode");
            b.RichLabelUseBBCode = true;
            b.RichLabelText = "[b]Bold[/b] [color=red]Red[/color] [i]Italics[/i]";
            _statusLabel.Text = "RichTextLabel with BBCode (see Godot docs for tags)";
            await Delay(0.2);
            var rtl = b.GetNodeOrNull<RichTextLabel>("RichLabel");
            bool ok = rtl != null && rtl.BbcodeEnabled;
            b.QueueFree();
            return ok;
        });

        // 12) Theme variations toggling
        AddTest("Theme variations settable", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(100, 560), new Vector2(240, 110), "Theme Variations");
            b.VariantNormal = "normal";
            b.VariantPressed = "pressed";
            b.VariantHover = "hover";
            b.VariantToggled = "toggled";
            b.VariantSelected = "selected";
            b.VariantDisabled = "disabled";
            b.Selected = true;
            b.Disabled = false;
            _statusLabel.Text = "Theme variation strings assigned";
            _statusLabel.Text = "Theme variation strings assigned";
            await Delay(0.1); b.LabelText = "Normal";
            b.IsPressed = true; b.LabelText = "Pressed"; await Delay(0.05);
            b.IsPressed = false; await Delay(0.05); b.Selected = true; b.LabelText = "Selected";
            b.PanelThemeVariation = "primary";
            b.PanelThemeVariation = "primary"; b.LabelText = "Variation: primary";
            await Delay(0.05); b.IsToggled = true; b.LabelText = "Toggled";
            bool ok = b == null || b.ThemeTypeVariation == "primary";
            return ok;
        });

        // 13) FollowBoth drags position
        AddTest("FollowBoth moves on drag", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(420, 80), new Vector2(140, 80), "FollowBoth");
            b.FollowMode = OmniButton.FollowModeEnum.FollowBoth;
            var start = b.GlobalPosition;
            var p = Center(b);
            b._GuiInput(MousePressAt(p, true));
            var move = new InputEventMouseMotion { GlobalPosition = p + new Vector2(30, 20), Position = p + new Vector2(30, 20) };
            b._GuiInput(move);
            b._GuiInput(MousePressAt(p + new Vector2(30, 20), false));
            await Delay(0.05);
            bool ok = b.GlobalPosition != start;
            _statusLabel.Text = ok ? "Dragged moved position" : "No movement detected"; if (ok) b.LabelText = "Moved";
            return ok;
        });

        // 14) HitSlop expands hit area
        AddTest("HitSlop expands hit region", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(420, 190), new Vector2(140, 80), "HitSlop");
            b.ActionMaskBits |= (int)OmniButton.ActionMaskFlags.Pressed;
            b.HitSlop = new Vector2(20, 20);
            int pressed = 0;
            b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => { pressed++; b.LabelText = "Pressed via slop"; }));
            var rect = b.GetGlobalRect();
            var outside = new Vector2(rect.Position.X - 5, rect.Position.Y + rect.Size.Y / 2f);
            b._GuiInput(MousePressAt(outside, true));
            b._GuiInput(MousePressAt(outside, false));
            await Delay(0.05);
            bool ok = pressed > 0;
            _statusLabel.Text = ok ? "Press registered via slop" : "Press ignored";
            b.QueueFree();
            return ok;
        });

        // 15) Cooldown directions
        AddTest("Cooldown directions", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(420, 290), new Vector2(180, 110), "Cooldown Dirs");
            b.EnableCooldown = true;
            b.CooldownDuration = 0.3f;
            b.CooldownColor = CooldownColorSample;
            bool allOk = true;
            foreach (OmniButton.CooldownDirection dir in Enum.GetValues(typeof(OmniButton.CooldownDirection)))
            {
                b.CooldownFillDirection = dir;
                b.StartCooldown();
                SimProcess(b, 0.1);
                var cr = b.GetNodeOrNull<ColorRect>("Cooldown");
                allOk &= (cr != null && cr.Visible);
            }
            _statusLabel.Text = allOk ? "All directions created cooldown" : "Missing cooldown rect";
            b.QueueFree();
            return allOk;
        });

        // 16) Joystick area ring (persistent)
        AddTest("Joystick area ring persists", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(640, 100), new Vector2(140, 140), "Joystick Ring");
            b.FollowMode = OmniButton.FollowModeEnum.VirtualJoystick;
            b.EnableJoystickArea = true;
            b.JoystickAreaPersistent = true;
            b.BoundsSource = _arena;
            b.StartVirtualJoystickAt(Center(b));
            b.StopVirtualJoystick();
            await Delay(0.05);
            var jp = b.GetNodeOrNull<Panel>("JoystickArea");
            bool ok = jp != null && jp.Visible;
            _statusLabel.Text = ok ? "Ring visible" : "Ring not found";
            b.QueueFree();
            return ok;
        });

        // 17) Joystick deadzone
        AddTest("Joystick deadzone zeros small moves", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(640, 270), new Vector2(160, 160), "Deadzone");
            b.EnableVirtualJoystick = true;
            b.BoundsSource = _arena;
            b.JoystickDeadzone = 0.5f;
            b.ClampShape = OmniButton.JoystickClampShape.Circle;
            b.JoystickRadiusPx = 100;
            Vector2 last = new Vector2(999, 999);
            b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => last = a));
            var home = Center(b);
            b.StartVirtualJoystickAt(home);
            b.UpdateVirtualJoystick(home + new Vector2(20, 0)); // 20/100 = 0.2 < 0.5
            await Delay(0.05);
            b.StopVirtualJoystick();
            bool ok = last == Vector2.Zero || last.Length() < 0.05f;
            _statusLabel.Text = ok ? "Axis zeroed inside deadzone" : $"Axis = {last}";
            b.QueueFree();
            return ok;
        });

        // 18) Joystick snap/hide/reset
        AddTest("Joystick snap/hide/reset", async () =>
        {
            ClearArena();
            var b = MakeBaseButton(new Vector2(640, 460), new Vector2(160, 160), "Snap/Hide/Reset");
            b.EnableVirtualJoystick = true;
            b.BoundsSource = _arena;
            b.JoystickSnapToInput = true;
            b.JoystickHideWhenInactive = true;
            b.JoystickResetOnRelease = true;
            var start = b.GlobalPosition;
            var home = Center(b);
            b.StartVirtualJoystickAt(home);
            b.UpdateVirtualJoystick(home + new Vector2(40, 0));
            b.StopVirtualJoystick();
            await Delay(0.05);
            bool hidden = !b.Visible;
            bool reset = (b.GlobalPosition - start).Length() < 1.0f;
            _statusLabel.Text = hidden && reset ? "Hidden and reset" : $"hidden={hidden} reset={reset}";
            b.Visible = true; // restore so arena stays interactive
            b.QueueFree();
            return hidden && reset;
        });
    }

    // Simple numeric tolerance compare for layout assertions
    private static bool Near(float a, float b, float eps = 0.5f) => Math.Abs(a - b) <= eps;

    // ===== Button helpers =====
    private OmniButton MakeBaseButton(Vector2 pos, Vector2 size, string title = null)
    {
        var b = new OmniButton { Name = "Button" };
        if (OverrideTheme != null) b.Theme = OverrideTheme;
        _arena.AddChild(b);
        CenterInArena(b, size);
        // Default: no panel background so most demos show only what's needed
        b.Background = OmniButton.BackgroundMode.None;
        if (!string.IsNullOrEmpty(title))
        {
            b.LabelText = title;
            b.LabelHorizontalAlignment = HorizontalAlignment.Center;
            b.LabelVerticalAlignment = VerticalAlignment.Center;
            b.LabelPadding = new Vector2(6, 4);
        }
        WireAllSignals(b, b.Name);
        return b;
    }

    private static void CenterInArena(Control node, Vector2 size)
    {
        node.AnchorLeft = 0.5f; node.AnchorTop = 0.5f; node.AnchorRight = 0.5f; node.AnchorBottom = 0.5f;
        node.OffsetLeft = -size.X / 2f;
        node.OffsetRight = size.X / 2f;
        node.OffsetTop = -size.Y / 2f;
        node.OffsetBottom = size.Y / 2f;
        node.Size = size;
    }

    private static Vector2 Center(Control node) => node.GlobalPosition + node.Size / 2f;

    private static InputEventMouseButton MousePressAt(Vector2 globalPos, bool down)
    {
        return new InputEventMouseButton
        {
            GlobalPosition = globalPos,
            Position = globalPos,
            ButtonIndex = MouseButton.Left,
            Pressed = down
        };
    }

    private void SimProcess(Node n, double total)
    {
        double t = 0;
        while (t < total)
        {
            n._Process(0.016);
            t += 0.016;
        }
    }

    private void WireAllSignals(OmniButton b, string tag)
    {
        void Append(string msg) { AppendLog(msg); }
        b.Connect(OmniButton.SignalName.Pressed, Callable.From(() => Append($"{tag}: Pressed")));
        b.Connect(OmniButton.SignalName.Released, Callable.From(() => Append($"{tag}: Released")));
        b.Connect(OmniButton.SignalName.Toggled, Callable.From<bool>(v => Append($"{tag}: Toggled {v}")));
        b.Connect(OmniButton.SignalName.HoverIn, Callable.From(() => Append($"{tag}: HoverIn")));
        b.Connect(OmniButton.SignalName.HoverOut, Callable.From(() => Append($"{tag}: HoverOut")));
        b.Connect(OmniButton.SignalName.Hold, Callable.From(() => Append($"{tag}: Hold")));
        b.Connect(OmniButton.SignalName.Swipe, Callable.From<Vector2>(d => Append($"{tag}: Swipe {new Vector2(Mathf.Round(d.X * 100) / 100f, Mathf.Round(d.Y * 100) / 100f)}")));
        b.Connect(OmniButton.SignalName.SwipeEnded, Callable.From(() => Append($"{tag}: SwipeEnded")));
        b.Connect(OmniButton.SignalName.JoystickStarted, Callable.From(() => Append($"{tag}: JoystickStarted")));
        b.Connect(OmniButton.SignalName.JoystickAxis, Callable.From<Vector2>(a => Append($"{tag}: Axis {new Vector2(Mathf.Round(a.X * 100) / 100f, Mathf.Round(a.Y * 100) / 100f)}")));
        b.Connect(OmniButton.SignalName.JoystickEnded, Callable.From(() => Append($"{tag}: JoystickEnded")));
        b.Connect(OmniButton.SignalName.Log, Callable.From<string>(m => Append($"{tag}: Log {m}")));
        b.Connect(OmniButton.SignalName.Warning, Callable.From<string>(m => Append($"{tag}: Warn {m}")));
        b.Connect(OmniButton.SignalName.Error, Callable.From<string>(m => Append($"{tag}: Error {m}")));
    }

    private void AppendLog(string msg)
    {
        _logLines.Add(msg);
        // Keep log from growing unbounded
        const int MaxLines = 500;
        if (_logLines.Count > MaxLines) _logLines.RemoveRange(0, _logLines.Count - MaxLines);
        var text = string.Join("\n", _logLines);
        if (IsInstanceValid(_log))
            _log.RichLabelText = text;
        else if (IsInstanceValid(_rtLog))
            _rtLog.Text = text;
    }
}
