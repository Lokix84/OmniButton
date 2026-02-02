using Godot;
using Godot.Collections;

internal sealed class OmniButtonEditorHelper
{
    private readonly OmniButton _o;
    private string _editorLastSig = string.Empty;
    private double _editorPollAccum = 0.0;
    private const double EditorPollInterval = 0.2;
    private bool _pendingInspectorRefresh = false;

    public OmniButtonEditorHelper(OmniButton owner)
    {
        _o = owner;
    }

    public Array<Dictionary> BuildPropertyList()
    {
        // Do not hide or rewrite any properties dynamically; return an empty list
        // so the Inspector shows all exported properties as-is.
        return new Array<Dictionary>();
    }

    public void SafeNotifyPropertyListChanged()
    {
        if (!Engine.IsEditorHint()) return;
        if (_pendingInspectorRefresh) return;
        _pendingInspectorRefresh = true;
        _o.CallDeferred(nameof(DoNotifyPropertyListChangedInternal));
    }

    public void DoNotifyPropertyListChangedInternal()
    {
        _pendingInspectorRefresh = false;
        _o.NotifyPropertyListChanged();
    }

    public void EditorPollTick(double delta)
    {
        _editorPollAccum += delta;
        if (_editorPollAccum < EditorPollInterval)
            return;
        _editorPollAccum = 0;
        var sig = BuildEditorSignature();
        if (sig != _editorLastSig)
        {
            _editorLastSig = sig;
            _o.EditorAutoEnableActionsFromConnectionsOnce();
            _o.SetupChildren();
            _o.ApplyPanelStyling();
            _o.ApplyVisualState();
            _o.FitLabelText();
        }
    }

    private string BuildEditorSignature()
    {
        var sb = new System.Text.StringBuilder(1024);
        // Query Godot's property list so we include exported + dynamic properties
        var props = _o.GetPropertyList();
        foreach (Godot.Collections.Dictionary p in props)
        {
            if (!p.ContainsKey("usage")) continue;
            var usage = (long)p["usage"]; // PropertyUsageFlags
            const long EditorUsage = (long)Godot.PropertyUsageFlags.Editor;
            if ((usage & EditorUsage) == 0) continue;
            string name = (string)p["name"];
            var val = _o.Get(name);
            sb.Append(name).Append('=').Append(val.ToString()).Append('|');
        }
        return sb.ToString();
    }
}
