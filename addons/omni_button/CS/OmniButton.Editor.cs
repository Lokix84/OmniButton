using Godot;
using Godot.Collections;

public partial class OmniButton : Control
{
    private OmniButtonEditorHelper? _editorHelper;
    private OmniButtonEditorHelper EditorHelper => _editorHelper ??= new OmniButtonEditorHelper(this);

    private Array<Dictionary> BuildPropertyList()
        => EditorHelper.BuildPropertyList();

    private void SafeNotifyPropertyListChanged()
        => EditorHelper.SafeNotifyPropertyListChanged();

    private void DoNotifyPropertyListChangedInternal()
        => EditorHelper.DoNotifyPropertyListChangedInternal();

    private void EditorPollTick(double delta)
        => EditorHelper.EditorPollTick(delta);
}
