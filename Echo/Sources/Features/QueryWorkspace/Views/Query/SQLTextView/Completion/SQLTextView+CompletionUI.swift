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
        let selection = currentTextSelection()
        let descriptor = currentSelectionDescriptor()
        scheduleSymbolHighlights(for: descriptor)
        let range = selectedLineRange()
        if range.location != NSNotFound {
            lineNumberRuler?.highlightedLines = IndexSet(integersIn: range.location..<(range.location + range.length))
        } else {
            lineNumberRuler?.highlightedLines = IndexSet()
        }
        lineNumberRuler?.setNeedsDisplay(lineNumberRuler?.bounds ?? .zero)
        sqlDelegate?.sqlTextView(self, didChangeSelection: selection)
        // Only refresh completions if popup is already visible — never open
        // popup from selection changes alone. Opening is handled exclusively
        // by trigger logic (period, space-after-keyword, manual invoke).
        if !isApplyingCompletion && !suppressNextCompletionRefresh && isCompletionVisible {
            refreshCompletions(immediate: true)
        }
    }

    func notifySelectionPreview() {
        let selection = currentTextSelection()
        sqlDelegate?.sqlTextView(self, didPreviewSelection: selection)
    }

    func currentTextSelection() -> SQLEditorSelection {
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

        completionGeneration += 1

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
        }

        completionWorkItem = workItem
        let deadline: DispatchTime = immediate ? .now() : .now() + 0.015
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

}
#endif
