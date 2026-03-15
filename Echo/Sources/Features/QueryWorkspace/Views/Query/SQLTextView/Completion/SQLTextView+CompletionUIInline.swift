#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func showInlineKeywordSuggestions(_ suggestions: [SQLAutoCompletionSuggestion], query: SQLAutoCompletionQuery) {
        guard displayOptions.autoCompletionEnabled,
              displayOptions.inlineKeywordSuggestionsEnabled else {
            hideInlineKeywordSuggestion()
            return
        }
        guard !suggestions.isEmpty else {
            hideInlineKeywordSuggestion()
            return
        }
        inlineKeywordSuggestions = suggestions
        inlineSuggestionQuery = query
        inlineSuggestionNextIndex = 0
        inlineInsertedRange = nil
        inlineInsertedIndex = nil
        let view = ensureInlineSuggestionView()
        applyInlineSuggestionAppearance(to: view)
        view.isHidden = false
        updateInlineSuggestionText()
        updateInlineSuggestionPosition()
    }

    func hideInlineKeywordSuggestion(preserveState: Bool = false) {
        inlineSuggestionView?.removeFromSuperview()
        inlineSuggestionView = nil
        if !preserveState && !inlineAcceptanceInProgress {
            clearInlineSuggestionState()
        }
    }

    private func ensureInlineSuggestionView() -> InlineSuggestionLabel {
        if let view = inlineSuggestionView {
            return view
        }
        let view = InlineSuggestionLabel()
        view.alphaValue = 1.0
        addSubview(view)
        inlineSuggestionView = view
        return view
    }

    func applyInlineSuggestionAppearance(to view: InlineSuggestionLabel? = nil) {
        guard let target = view ?? inlineSuggestionView else { return }
        target.font = theme.nsFont
        let keywordColor = theme.tokenColors.keyword.nsColor
        let surfaceColor = (backgroundOverride ?? theme.surfaces.background.nsColor)
        let blendFraction: CGFloat = theme.tone == .dark ? 0.2 : 0.35
        let blended = keywordColor.blended(withFraction: blendFraction, of: surfaceColor) ?? keywordColor
        let alpha: CGFloat = theme.tone == .dark ? 0.75 : 0.65
        target.textColor = blended.withAlphaComponent(alpha)
    }

    func updateInlineSuggestionText() {
        guard let view = inlineSuggestionView,
              !inlineKeywordSuggestions.isEmpty else { return }
        let index = min(max(inlineSuggestionNextIndex, 0), inlineKeywordSuggestions.count - 1)
        let suggestion = inlineKeywordSuggestions[index]
        let suggestionText = suggestion.insertText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let query = inlineSuggestionQuery {
            let typedToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
            let typedLower = typedToken.lowercased()
            let suggestionLower = suggestionText.lowercased()
            if !typedLower.isEmpty, suggestionLower.hasPrefix(typedLower) {
                let dropIndex = suggestionText.index(suggestionText.startIndex,
                                                     offsetBy: typedToken.count)
                let remainder = suggestionText[dropIndex...]
                view.stringValue = String(remainder)
            } else {
                view.stringValue = suggestionText
            }
        } else {
            view.stringValue = suggestionText
        }
        view.invalidateIntrinsicContentSize()
    }

    func updateInlineSuggestionPosition() {
        guard let view = inlineSuggestionView,
              inlineInsertedRange == nil,
              !inlineKeywordSuggestions.isEmpty else { return }
        let caretLocation = selectedRange().location
        guard caretLocation != NSNotFound else { return }
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        layoutManager.ensureLayout(for: textContainer)

        let characterCount = (string as NSString).length
        let clampedCaret = min(max(caretLocation, 0), characterCount)
        let glyphCount = layoutManager.numberOfGlyphs

        if glyphCount == 0 {
            let origin = textContainerOrigin
            let lineHeight = theme.nsFont.ascender - theme.nsFont.descender + theme.nsFont.leading
            let xPosition = origin.x + textContainer.lineFragmentPadding
            let yPosition = origin.y + lineHeight - theme.nsFont.ascender
            let intrinsicWidth = max(view.intrinsicContentSize.width, 24)
            view.frame = NSRect(x: xPosition,
                                y: yPosition,
                                width: intrinsicWidth,
                                height: lineHeight)
            return
        }

        let referenceCharIndex = max(min(clampedCaret - 1, characterCount - 1), 0)
        let referenceGlyphIndex = layoutManager.glyphIndexForCharacter(at: referenceCharIndex)

        var lineGlyphRange = NSRange(location: 0, length: 0)
        let lineRect = layoutManager.lineFragmentUsedRect(forGlyphAt: referenceGlyphIndex,
                                                          effectiveRange: &lineGlyphRange,
                                                          withoutAdditionalLayout: true)

        let lineCharRange = layoutManager.characterRange(forGlyphRange: lineGlyphRange, actualGlyphRange: nil)
        let caretRelativeCharLength = max(0, clampedCaret - lineCharRange.location)
        let caretCharRange = NSRange(location: lineCharRange.location, length: caretRelativeCharLength)
        let caretGlyphRange = layoutManager.glyphRange(forCharacterRange: caretCharRange, actualCharacterRange: nil)

        let precedingRect = caretGlyphRange.length > 0
            ? layoutManager.boundingRect(forGlyphRange: caretGlyphRange, in: textContainer)
            : CGRect(origin: lineRect.origin, size: .zero)

        let origin = textContainerOrigin
        let xPosition = origin.x + (caretGlyphRange.length > 0 ? precedingRect.maxX : lineRect.minX)
        let lineHeight = max(lineRect.height, theme.nsFont.ascender - theme.nsFont.descender + theme.nsFont.leading)
        let baseline = origin.y + lineRect.minY + theme.nsFont.ascender
        let yPosition = baseline - theme.nsFont.ascender
        let intrinsicWidth = max(view.intrinsicContentSize.width, 24)

        view.frame = NSRect(x: xPosition,
                            y: yPosition,
                            width: intrinsicWidth,
                            height: lineHeight)
    }

}
#endif
