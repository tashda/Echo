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

    func refreshCompletions(immediate: Bool = false, manual: Bool = false) {
        if suppressNextCompletionPopover {
            suppressNextCompletionPopover = false
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
        if !manual && manualCompletionSuppression {
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
            if !manual && self.manualCompletionSuppression {
                self.hideCompletions()
                return
            }
            guard let controller = self.ensureCompletionController() else { return }

            let caretLocation = self.selectedRange().location
            guard caretLocation != NSNotFound else {
                self.hideCompletions()
                return
            }
            let fullText = self.string

            // Trigger lazy schema load if needed
            self.notifySchemaLoadIfNeeded(text: fullText, caretLocation: caretLocation)

            // Ask EchoSense — it handles ALL intelligence
            let response: SQLCompletionResponse
            if manual {
                response = self.completionEngine.manualCompletions(in: fullText, at: caretLocation)
            } else {
                response = self.completionEngine.completions(in: fullText, at: caretLocation)
            }

            // Store the last response for use when accepting a suggestion
            self.lastCompletionResponse = response

            if response.shouldShow {
                self.removeCompletionIndicator()
                controller.present(suggestions: response.suggestions, response: response)
            } else {
                self.hideCompletions()
            }
        }

        completionWorkItem = workItem
        let deadline: DispatchTime = immediate ? .now() : .now() + 0.015
        DispatchQueue.main.asyncAfter(deadline: deadline, execute: workItem)
    }

}
#endif
