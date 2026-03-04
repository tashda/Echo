#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    override func menu(for event: NSEvent) -> NSMenu? {
        let baseMenu = super.menu(for: event) ?? NSMenu(title: "Context")
        let item = NSMenuItem(title: "Add to Bookmarks", action: #selector(addSelectionToBookmarks(_:)), keyEquivalent: "")
        item.target = self
        item.isEnabled = hasBookmarkableSelection

        if let existingIndex = baseMenu.items.firstIndex(where: { $0.action == #selector(addSelectionToBookmarks(_:)) }) {
            baseMenu.removeItem(at: existingIndex)
        }

        if let firstItem = baseMenu.items.first, firstItem.isSeparatorItem == false {
            baseMenu.insertItem(NSMenuItem.separator(), at: 0)
        }
        baseMenu.insertItem(item, at: 0)
        return baseMenu
    }

    private var hasBookmarkableSelection: Bool {
        let range = selectedRange()
        guard range.length > 0 else { return false }
        let selection = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        return !selection.isEmpty
    }

    @objc private func addSelectionToBookmarks(_ sender: Any?) {
        guard hasBookmarkableSelection else { return }
        let range = selectedRange()
        let content = (string as NSString).substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        sqlDelegate?.sqlTextView(self, didRequestBookmarkWithContent: content)
    }

    func notifySelectionChanged() {
        let selection = currentSelectionDescriptor()
        scheduleSymbolHighlights(for: selection)
        let range = selectedLineRange()
        if range.location != NSNotFound {
            lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length))
        } else {
            lineNumberRuler?.highlightedLines = IndexSet()
        }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        sqlDelegate?.sqlTextView(self, didChangeSelection: selection)
        handleInlineSelectionChange()
        if !isApplyingCompletion && !suppressNextCompletionRefresh {
            refreshCompletions(immediate: true)
        }
    }

    func notifySelectionPreview() {
        let selection = currentSelectionDescriptor()
        sqlDelegate?.sqlTextView(self, didPreviewSelection: selection)
    }

    func currentSelectionDescriptor() -> SQLEditorSelection {
        let range = selectedRange()
        let nsString = string as NSString
        let selected = (range.length > 0 && range.location != NSNotFound) ? nsString.substring(with: range) : ""
        let lines = selectedLines(for: range)
        return SQLEditorSelection(selectedText: selected, range: range, lineRange: lines)
    }

    // MARK: - Autocompletion

    func refreshCompletions(immediate: Bool = false) {
        if suppressNextCompletionPopover {
            suppressNextCompletionPopover = false
            return
        }
        if isAliasTypingContext() {
            hideCompletions()
            return
        }
        guard !isApplyingCompletion else { return }
        guard displayOptions.autoCompletionEnabled else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        guard completionContext != nil else {
            completionTask?.cancel()
            hideCompletions()
            return
        }

        if manualCompletionSuppression {
            hideCompletions()
            return
        }

        completionWorkItem?.cancel()
        completionTask?.cancel()

        let generation: Int = {
            completionGeneration += 1
            return completionGeneration
        }()

        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            defer { self.completionWorkItem = nil }
            guard !self.isApplyingCompletion else { return }
            if self.manualCompletionSuppression {
                self.hideCompletions()
                return
            }
            guard let controller = self.ensureCompletionController() else { return }
            guard let query = self.makeCompletionQuery() else {
                self.hideCompletions()
                return
            }

            let selectionRange = self.selectedRange()
            let caretLocation = selectionRange.location
            let fullText = self.string

            let engineResult = self.completionEngine.suggestions(for: query,
                                                                 text: fullText,
                                                                 caretLocation: caretLocation)
            let activeQuery = self.enrichedQuery(query, with: engineResult.metadata)

            var baseSuggestions = self.filteredSuggestions(from: engineResult.sections, for: activeQuery)
            baseSuggestions = self.filterSuggestionsForContext(baseSuggestions, query: activeQuery)
            baseSuggestions = self.limitSuggestions(baseSuggestions)

            if baseSuggestions.isEmpty,
               let (_, suppression) = self.suppressedCompletionEntry(containing: selectionRange, caretLocation: caretLocation),
               suppression.hasFollowUps,
               let fallback = self.ruleEngine.fallbackSuggestions(for: suppression.asRuleSuppression,
                                                                  environment: self.ruleEnvironment),
               !fallback.isEmpty {
                baseSuggestions = fallback
            }

            if self.shouldSuppressCompletions(query: activeQuery,
                                              selection: selectionRange,
                                              caretLocation: caretLocation,
                                              suggestions: baseSuggestions,
                                              bypassSuppression: false) {
                self.hideCompletions()
                return
            }

            if baseSuggestions.isEmpty {
                self.hideCompletions()
            } else {
                self.removeCompletionIndicator()
                controller.present(suggestions: baseSuggestions, query: activeQuery)
            }

            let currentContext = self.completionContext
            let baseForAsync = baseSuggestions
            let asyncQuery = activeQuery

            self.completionTask = Task { [weak self] in
                guard let self else { return }
                if Task.isCancelled { return }
                guard generation == self.completionGeneration else { return }
                if self.manualCompletionSuppression {
                    await MainActor.run {
                        self.hideCompletions()
                    }
                    return
                }
                defer {
                    if generation == self.completionGeneration {
                        self.completionTask = nil
                    }
                }
                guard let context = currentContext else { return }

                let updatedCaretLocation = self.currentSelectionDescriptor().range.location

                let external = await self.fetchSqruffSuggestions(for: asyncQuery,
                                                                  text: fullText,
                                                                  caretLocation: updatedCaretLocation,
                                                                  context: context)
                guard !external.isEmpty, !Task.isCancelled else { return }

                var combined = self.mergeSuggestions(primary: baseForAsync, secondary: external, query: asyncQuery)
                combined = self.filterSuggestionsForContext(combined, query: asyncQuery)
                combined = self.limitSuggestions(combined)

                guard !combined.isEmpty, !Task.isCancelled, generation == self.completionGeneration else { return }

                await MainActor.run {
                    guard !Task.isCancelled, generation == self.completionGeneration else { return }
                    if self.shouldSuppressCompletions(query: asyncQuery,
                                                      selection: self.selectedRange(),
                                                      caretLocation: updatedCaretLocation,
                                                      suggestions: combined,
                                                      bypassSuppression: false) {
                        self.hideCompletions()
                        return
                    }
                    self.removeCompletionIndicator()
                    controller.present(suggestions: combined, query: asyncQuery)
                }
            }
        }

        completionWorkItem = workItem
        let deadline: DispatchTime = immediate ? .now() : .now() + 0.015
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

    @MainActor
    func hideCompletions() {
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
        completionController?.hide()
        updateCompletionIndicator()
    }

    func activateManualCompletionSuppression() {
        manualCompletionSuppression = true
        completionGeneration += 1
        completionWorkItem?.cancel()
        completionWorkItem = nil
        completionTask?.cancel()
        completionTask = nil
    }

    func deactivateManualCompletionSuppression() {
        guard manualCompletionSuppression else { return }
        manualCompletionSuppression = false
    }

    func cancelPendingCompletions() {
        hideCompletions()
    }

    @discardableResult
    @MainActor
    func ensureCompletionController() -> SQLAutoCompletionController? {
        if completionController == nil {
            completionController = SQLAutoCompletionController(textView: self)
        }
        return completionController
    }

    func consumePopoverSuppressionFlag() -> Bool {
        let value = suppressNextCompletionPopover
        suppressNextCompletionPopover = false
        return value
    }

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

    func handleInlineSelectionChange() {
        if let range = inlineInsertedRange {
            let selection = selectedRange()
            if selection.length == 0, selection.location == NSMaxRange(range) {
                return
            }
            if selection.location != range.location || selection.length != range.length {
                hideInlineKeywordSuggestion()
            }
        } else if inlineSuggestionView != nil {
            updateInlineSuggestionPosition()
        }
    }

    func clearInlineSuggestionState() {
        inlineKeywordSuggestions.removeAll()
        inlineSuggestionQuery = nil
        inlineSuggestionNextIndex = 0
        inlineInsertedRange = nil
        inlineInsertedIndex = nil
    }

    func handleInlineSuggestionKey(_ event: NSEvent) -> Bool {
        guard let view = inlineSuggestionView,
              !view.isHidden,
              !inlineKeywordSuggestions.isEmpty else { return false }

        let index = min(max(inlineSuggestionNextIndex, 0), inlineKeywordSuggestions.count - 1)
        let suggestion = inlineKeywordSuggestions[index]

        if event.keyCode == 48 { // Tab
            acceptInlineSuggestion(suggestion)
            return true
        }

        if event.keyCode == 124 { // Right Arrow
            acceptInlineSuggestion(suggestion)
            return true
        }

        if event.keyCode == 125 || event.keyCode == 126 { // Down / Up
            inlineSuggestionNextIndex = (inlineSuggestionNextIndex + 1) % inlineKeywordSuggestions.count
            updateInlineSuggestionText()
            updateInlineSuggestionPosition()
            return true
        }

        if event.keyCode == 53 { // Escape
            hideInlineKeywordSuggestion()
            return true
        }

        return false
    }

    private func acceptInlineSuggestion(_ suggestion: SQLAutoCompletionSuggestion) {
        guard let query = inlineSuggestionQuery else { return }
        inlineAcceptanceInProgress = true
        applyCompletion(suggestion, query: query)
        inlineAcceptanceInProgress = false
        hideInlineKeywordSuggestion()
    }
}
#endif
