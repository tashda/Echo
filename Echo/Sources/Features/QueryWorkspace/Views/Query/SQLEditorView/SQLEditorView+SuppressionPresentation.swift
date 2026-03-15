#if os(macOS)
import AppKit
import Foundation
import EchoSense

extension SQLTextView {
    func updateCompletionIndicator() {
        guard !isCompletionVisible else {
            removeCompletionIndicator()
            return
        }

        let selection = selectedRange()
        guard selection.location != NSNotFound else {
            removeCompletionIndicator()
            return
        }

        guard let (_, suppression) = suppressedCompletionEntry(containing: selection, caretLocation: selection.location) else {
            removeCompletionIndicator()
            return
        }

        guard suppression.hasFollowUps else {
            removeCompletionIndicator()
            return
        }

        guard let textContainer = textContainer,
              let layoutManager = layoutManager else {
            removeCompletionIndicator()
            return
        }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: suppression.tokenRange, actualCharacterRange: nil)
        guard glyphRange.length > 0 else {
            removeCompletionIndicator()
            return
        }

        var boundingRect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        boundingRect.origin.x += textContainerInset.width
        boundingRect.origin.y += textContainerInset.height

        if completionIndicatorView == nil {
            let indicator = CompletionAccessoryView()
            indicator.translatesAutoresizingMaskIntoConstraints = false
            indicator.onActivate = { [weak self] in
                _ = self?.triggerSuppressedCompletionsIfAvailable()
            }
            addSubview(indicator)
            completionIndicatorView = indicator
        }

        completionIndicatorView?.update(for: boundingRect)
    }

    func removeCompletionIndicator() {
        completionIndicatorView?.removeFromSuperview()
        completionIndicatorView = nil
    }

    @discardableResult
    func triggerSuppressedCompletionsIfAvailable() -> Bool {
        let selection = selectedRange()
        guard selection.location != NSNotFound else { return false }
        let caretLocation = selection.location
        let indicatorVisible = completionIndicatorView?.isVisible == true

        guard indicatorVisible || suppressedCompletionEntry(containing: selection, caretLocation: caretLocation) != nil else {
            return false
        }

        return forcePresentImmediateCompletions()
    }

    func forcePresentImmediateCompletions() -> Bool {
        deactivateManualCompletionSuppression()
        clearSnippetPlaceholders()
        completionEngine.clearPostCommitSuppression()
        suppressNextCompletionPopover = false

        if var query = makeCompletionQuery() {
            // Special-case identifiers that end with a dot (e.g. "public.")
            // so that we treat the preceding components as a completed
            // database/schema path and start suggesting objects immediately
            // after the dot, even if no table/view prefix has been typed yet.
            let selection = selectedRange()
            let caretIndex = selection.location
            if caretIndex != NSNotFound,
               let textStorage,
               caretIndex <= textStorage.length,
               caretIndex > 0 {
                let nsString = string as NSString
                let previousChar = nsString.character(at: caretIndex - 1)
                if previousChar == 46 { // "."
                    let rawToken = query.token.trimmingCharacters(in: .whitespacesAndNewlines)
                    if rawToken.hasSuffix(".") {
                        let trimmed = String(rawToken.dropLast())
                        let parts = trimmed.split(separator: ".", omittingEmptySubsequences: true).map { String($0) }
                        query = SQLAutoCompletionQuery(
                            token: "",
                            prefix: "",
                            pathComponents: parts,
                            replacementRange: NSRange(location: caretIndex, length: 0),
                            precedingKeyword: query.precedingKeyword,
                            precedingCharacter: query.precedingCharacter,
                            focusTable: query.focusTable,
                            tablesInScope: query.tablesInScope,
                            clause: query.clause
                        )
                    }
                }
            }

            let caretLocation = query.replacementRange.location
            completionEngine.beginManualTrigger()
            defer { completionEngine.endManualTrigger() }
            let engineResult = completionEngine.suggestions(for: query,
                                                            text: string,
                                                            caretLocation: caretLocation)
            let activeQuery = enrichedQuery(query, with: engineResult.metadata)
            var suggestions = filteredSuggestions(from: engineResult.sections, for: activeQuery)
            suggestions = filterSuggestionsForContext(suggestions, query: activeQuery)
            suggestions = limitSuggestions(suggestions)

            if suggestions.isEmpty,
               let suppression = suppressionForTrigger(at: activeQuery.replacementRange.location),
               suppression.hasFollowUps,
               let fallback = ruleEngine.fallbackSuggestions(for: suppression.asRuleSuppression,
                                                             environment: ruleEnvironment),
               !fallback.isEmpty {
                suggestions = fallback
            }

            guard !suggestions.isEmpty else { return false }
            guard let controller = ensureCompletionController() else { return false }

            completionGeneration += 1
            completionWorkItem?.cancel()
            completionWorkItem = nil
            completionTask?.cancel()
            completionTask = nil

            removeCompletionIndicator()
            controller.present(suggestions: suggestions, query: activeQuery)
            return true
        } else if let suppression = suppressionForTrigger(at: selectedRange().location),
                  suppression.hasFollowUps,
                  let fallback = ruleEngine.fallbackSuggestions(for: suppression.asRuleSuppression,
                                                                environment: ruleEnvironment),
                  !fallback.isEmpty,
                  let controller = ensureCompletionController() {
            completionGeneration += 1
            completionWorkItem?.cancel()
            completionWorkItem = nil
            completionTask?.cancel()
            completionTask = nil

            removeCompletionIndicator()

            let canonical = suppression.canonicalText.trimmingCharacters(in: .whitespacesAndNewlines)
            let rawComponents = canonical.split(separator: ".").map { String($0) }
            let pathComponents = rawComponents.dropLast().map { String($0) }
            let prefix = rawComponents.last ?? canonical

            let parsedContext = SQLContextParser(text: string,
                                                 caretLocation: suppression.tokenRange.location,
                                                 dialect: currentSQLDialect(),
                                                 catalog: SQLDatabaseCatalog(schemas: [])).parse()

            let query = SQLAutoCompletionQuery(
                token: canonical,
                prefix: prefix,
                pathComponents: pathComponents,
                replacementRange: suppression.tokenRange,
                precedingKeyword: nil,
                precedingCharacter: nil,
                focusTable: nil,
                tablesInScope: [],
                clause: parsedContext.clause
            )

            controller.present(suggestions: fallback, query: query)
            return true
        }

        return false
    }

    func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard isCommandPeriod(event) else { return false }
        if triggerSuppressedCompletionsIfAvailable() {
            return true
        }
        return forcePresentImmediateCompletions()
    }

    func isCommandPeriod(_ event: NSEvent) -> Bool {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard modifiers.contains(.command) else { return false }
        let periodKeyCode: UInt16 = 47
        if event.keyCode == periodKeyCode { return true }
        if let characters = event.charactersIgnoringModifiers, characters == "." {
            return true
        }
        return false
    }
}
#endif
