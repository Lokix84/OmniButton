using Godot;
using System;
using System.Collections.Generic;
using System.Text;

public partial class OmniButton : Control
{
    // ===== Typewriter API =====
    // Primary entrypoint: explicit text
    public void StartTypewriter(string finalText, float cps = 30f, bool byWord = false)
        => StartTypewriterInternal(finalText, cps, byWord, preserveBBCodeTags: false);

    // Overload: use TextToType and optionally preserve BBCode tags
    public void StartTypewriter(float cps = 30f, bool byWord = false, bool preserveBBCodeTags = false)
        => StartTypewriterInternal(TextToType, cps, byWord, preserveBBCodeTags);

    private void StartTypewriterInternal(string finalText, float cps, bool byWord, bool preserveBBCodeTags)
    {
        if (string.IsNullOrEmpty(finalText))
        {
            SkipTypewriter();
            return;
        }
        DebugLog($"Typewriter start len={finalText.Length} cps={cps} byWord={byWord} bbcode={preserveBBCodeTags}");
        // Decide BBCode behavior based on current label type
        bool wantBB = preserveBBCodeTags && (_labelType == LabelTypeEnum.RichTextLabel);
        string content = wantBB ? finalText : StripKnownBBCode(finalText);
        _twBBCodeAware = wantBB;
        _twByWord = byWord;
        _twCps = Math.Max(1f, cps);
        _twAccum = 0.0;
        _twIndex = 0;
        _twVisiblePlainChars = 0;
        _twFinalText = content;
        _twBuilder = _twBBCodeAware ? null : new System.Text.StringBuilder(content.Length);

        // Ensure visuals exist
        SetupChildren();
        // Pre-fit for final text so we don't re-fit during reveal
        PrefitForText(content);

        if (_twBBCodeAware)
        {
            (_twBBTokens, _twTotalPlainChars) = TokenizeBBCode(content);
            // Start with tags-only skeleton
            SetTypewriterVisibleText(BuildVisibleFromTokens(_twBBTokens, 0));
        }
        else
        {
            // Prepare tokens for per-word mode
            if (_twByWord)
                _twTokens = TokenizeWords(content);
            else
                _twTokens = null;
            // Clear current visible text
            SetTypewriterVisibleText(string.Empty);
        }

        _twActive = true;
        SetProcess(true);
    }

    public void SkipTypewriter()
    {
        if (string.IsNullOrEmpty(_twFinalText)) { StopTypewriter(); return; }
        SetTypewriterVisibleText(_twFinalText);
        StopTypewriter();
        DebugLog("Typewriter skipped to end");
    }

    public void StopTypewriter()
    {
        bool wasActive = _twActive;
        string current = string.Empty;
        if (_richLabel != null && IsInstanceValid(_richLabel))
            current = _richLabel.Text;
        else if (_label != null && IsInstanceValid(_label))
            current = _label.Text;

        _twActive = false;
        if (!string.IsNullOrEmpty(current))
            _text = current;

        _twBuilder = null;
        _twTokens = null;
        _twBBTokens = null;

        if (wasActive)
        {
            EmitSignal(SignalName.TypewriterCompleted);
            DebugLog("Typewriter completed");
        }
    }


    private void ProcessTypewriter(double delta)
    {
        if (!_twActive) return;
        double step = 1.0 / Math.Max(1.0f, _twCps);
        _twAccum += delta;
        bool changed = false;
        if (_twBBCodeAware && _twBBTokens != null)
        {
            while (_twAccum >= step && _twVisiblePlainChars < _twTotalPlainChars)
            {
                _twAccum -= step;
                _twVisiblePlainChars++;
                changed = true;
            }
            if (changed)
                SetTypewriterVisibleText(BuildVisibleFromTokens(_twBBTokens, _twVisiblePlainChars));
            if (_twVisiblePlainChars >= _twTotalPlainChars)
                StopTypewriter();
        }
        else if (_twByWord && _twTokens != null)
        {
            while (_twAccum >= step && _twIndex < _twTokens.Count)
            {
                _twAccum -= step;
                _twBuilder!.Append(_twTokens[_twIndex]);
                _twIndex++;
                changed = true;
            }
            if (changed)
                SetTypewriterVisibleText(_twBuilder!.ToString());
            if (_twIndex >= _twTokens.Count)
                StopTypewriter();
        }
        else
        {
            while (_twAccum >= step && _twIndex < _twFinalText.Length)
            {
                _twAccum -= step;
                _twBuilder!.Append(_twFinalText[_twIndex]);
                _twIndex++;
                changed = true;
            }
            if (changed)
                SetTypewriterVisibleText(_twBuilder!.ToString());
            if (_twIndex >= _twFinalText.Length)
                StopTypewriter();
        }
    }

    private void SetTypewriterVisibleText(string current)
    {
        if (_label != null && IsInstanceValid(_label))
            _label.Text = current;
        if (_richLabel != null && IsInstanceValid(_richLabel))
            _richLabel.Text = current;
        if (!_twActive)
            _text = current;
    }

    private System.Collections.Generic.List<string> TokenizeWords(string s)
    {
        var list = new System.Collections.Generic.List<string>();
        int i = 0;
        while (i < s.Length)
        {
            int start = i;
            while (i < s.Length && !char.IsWhiteSpace(s[i])) i++;
            int wordEnd = i;
            while (i < s.Length && char.IsWhiteSpace(s[i])) i++;
            int end = i;
            if (end > start)
                list.Add(s.Substring(start, end - start));
        }
        return list;
    }

    private void PrefitForText(string content)
    {
        var avail = CalculateAvailableArea();
        if (avail.X <= 1.0f || avail.Y <= 1.0f) return;
        if (_richLabel != null && !string.IsNullOrEmpty(_richLabelText))
        {
            var rtl = _richLabel;
            if (rtl == null || !IsInstanceValid(rtl)) return;
            var fnt = LabelFont ?? ThemeDB.FallbackFont;
            if (fnt == null) return;
            string plain = StripKnownBBCode(content);
            bool wrapEnabled = LabelAutowrap != TextServer.AutowrapMode.Off;
            float wrap = wrapEnabled ? avail.X : -1f;
            int size = FindBestFontSize(fnt, plain, avail, wrap, wrapEnabled);
            ApplyRichLabelFontOverrides(rtl, fnt, size);
            _richCurrentFontSize = size;
            _lastFitFontSize = size;
        }
        else if (_label != null)
        {
            var label = _label;
            if (label == null || !IsInstanceValid(label)) return;
            var fnt = GetRobustFont(label);
            if (fnt == null) return;
            bool wrapEnabled = LabelAutowrap != TextServer.AutowrapMode.Off;
            float wrap = wrapEnabled ? avail.X : -1f;
            int size = FindBestFontSize(fnt, content, avail, wrap, wrapEnabled);
            ApplyFontSettings(label, fnt, size);
            _lastFitFontSize = size;
        }
    }

    private (System.Collections.Generic.List<BBToken>, int) TokenizeBBCode(string s)
    {
        var tokens = new System.Collections.Generic.List<BBToken>();
        int i = 0;
        int totalPlain = 0;
        while (i < s.Length)
        {
            if (s[i] == '[')
            {
                int j = s.IndexOf(']', i + 1);
                if (j > i)
                {
                    tokens.Add(new BBToken(true, s.Substring(i, j - i + 1)));
                    i = j + 1;
                    continue;
                }
                // Unmatched '[' â€” treat as plain text
                i++;
                totalPlain++;
                tokens.Add(new BBToken(false, "["));
                continue;
            }
            // accumulate plain text until next tag
            int start = i;
            while (i < s.Length && s[i] != '[')
                i++;
            string text = s.Substring(start, i - start);
            if (text.Length > 0)
            {
                tokens.Add(new BBToken(false, text));
                totalPlain += text.Length;
            }
        }
        return (tokens, totalPlain);
    }

    private string BuildVisibleFromTokens(System.Collections.Generic.List<BBToken> tokens, int visiblePlainChars)
    {
        var sb = new System.Text.StringBuilder(_twFinalText?.Length ?? 64);
        int remain = Math.Max(0, visiblePlainChars);
        foreach (var t in tokens)
        {
            if (t.IsTag)
            {
                // Optionally delay effect tags until typing completes
                if (_twDelayEffects && visiblePlainChars < _twTotalPlainChars && IsEffectTag(t.Content))
                {
                    continue;
                }
                sb.Append(t.Content);
                continue;
            }
            if (remain <= 0) continue;
            int take = Math.Min(remain, t.Content.Length);
            sb.Append(t.Content.AsSpan(0, take));
            remain -= take;
        }
        return sb.ToString();
    }
    // Effect tags that can be expensive or glitchy mid-typing; delay until complete
    private static readonly System.Collections.Generic.HashSet<string> EffectTags = new System.Collections.Generic.HashSet<string>(StringComparer.OrdinalIgnoreCase)
    { "wave", "rainbow", "tornado", "pulse", "shake", "fade" };
    private bool IsEffectTag(string tag)
    {
        if (string.IsNullOrEmpty(tag)) return false;
        int start = tag.IndexOf('[');
        int end = tag.IndexOf(']');
        if (start < 0 || end <= start) return false;
        var inner = tag.Substring(start + 1, end - start - 1).Trim();
        if (inner.StartsWith("/")) inner = inner.Substring(1).TrimStart();
        int sp = inner.IndexOf(' ');
        var name = sp >= 0 ? inner.Substring(0, sp) : inner;
        return EffectTags.Contains(name);
    }
}
