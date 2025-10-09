import AppKit
import Foundation

extension SQLTextView {
    private var suppressionEnvironment: SQLAutocompleteRuleEngine.Environment { ruleEnvironment }

    func shouldSuppressCompletions(query: SQLAutoCompletionQuery,
                                           selection: NSRange,
                                           caretLocation: Int,
                                           suggestions: [SQLAutoCompletionSuggestion],
                                           bypassSuppression: Bool) -> Bool {
        guard !bypassSuppression else { return false }

        let nsString = string as NSString

        if let (index, suppression) = suppressedCompletionEntry(containing: selection, caretLocation: caretLocation) {
            guard suppression.isValid else {
                suppressedCompletions.remove(at: index)
                removeCompletionIndicator()
                return false
            }

            guard sqlRangeIsValid(suppression.tokenRange, upperBound: nsString.length) else {
                suppressedCompletions.remove(at: index)
                removeCompletionIndicator()
                return false
            }

            let currentText = nsString.substring(with: suppression.tokenRange)
            if currentText != suppression.canonicalText {
                suppressedCompletions.remove(at: index)
                removeCompletionIndicator()
                return false
            }

            return true
        }

        let tokenRange = tokenRange(at: caretLocation, in: nsString)
        let tokenText = tokenRange.length > 0 ? nsString.substring(with: tokenRange) : ""

        let request = SQLAutocompleteRuleEngine.SuppressionRequest(
            query: query,
            selection: selection,
            caretLocation: caretLocation,
            suggestions: suggestions,
            tokenRange: tokenRange,
            tokenText: tokenText,
            objectContextKeywords: SQLTextView.objectContextKeywords,
            columnContextKeywords: SQLTextView.columnContextKeywords
        )

        var trace: SQLAutocompleteTrace?
        if isRuleTracingEnabled {
            trace = SQLAutocompleteTrace.suppression(request: request)
        }

        guard let result = ruleEngine.buildSuppressionIfNeeded(
            request: request,
            environment: suppressionEnvironment,
            trace: &trace
        ) else {
            if let trace, isRuleTracingEnabled {
                onRuleTrace?(trace)
            }
            return false
        }

        if let trace, isRuleTracingEnabled {
            onRuleTrace?(trace)
        }

        let newSuppression = SuppressedCompletion(
            tokenRange: result.suppression.tokenRange,
            canonicalText: result.suppression.canonicalText,
            hasFollowUps: result.suppression.hasFollowUps
        )

        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, newSuppression.tokenRange).length > 0 }
        suppressedCompletions.append(newSuppression)
        updateCompletionIndicator()
        return true
    }

    func suppressedCompletionEntry(containing selection: NSRange, caretLocation: Int) -> (Int, SuppressedCompletion)? {
        guard selection.location != NSNotFound else { return nil }
        for (index, entry) in suppressedCompletions.enumerated() {
            let tokenRange = entry.tokenRange
            guard sqlRangeIsValid(tokenRange, upperBound: (string as NSString).length) else {
                continue
            }

            if selection.length > 0 {
                if NSIntersectionRange(selection, tokenRange).length > 0 {
                    return (index, entry)
                }
            } else {
                if caretLocation >= tokenRange.location && caretLocation <= NSMaxRange(tokenRange) {
                    return (index, entry)
                }
            }
        }
        return nil
    }

    private func suppressionForTrigger(at caretLocation: Int) -> SuppressedCompletion? {
        if let (_, suppression) = suppressedCompletionEntry(containing: NSRange(location: caretLocation, length: 0),
                                                            caretLocation: caretLocation) {
            return suppression
        }

        let nsString = string as NSString
        let tokenRange = tokenRange(at: caretLocation, in: nsString)
        guard tokenRange.length > 0 else { return nil }

        let token = nsString.substring(with: tokenRange)
        let rawComponents = token.split(separator: ".").map { SQLAutocompleteIdentifierTools.normalize(String($0)) }
        let components = rawComponents.map { $0.lowercased() }.filter { !$0.isEmpty }
        guard !components.isEmpty else { return nil }

        let prefix = rawComponents.last ?? ""
        let pathComponents = rawComponents.dropLast().map { String($0) }
        let query = SQLAutoCompletionQuery(
            token: token,
            prefix: String(prefix),
            pathComponents: pathComponents,
            replacementRange: tokenRange,
            precedingKeyword: nil,
            precedingCharacter: nil,
            focusTable: nil,
            tablesInScope: []
        )

        let request = SQLAutocompleteRuleEngine.SuppressionRequest(
            query: query,
            selection: NSRange(location: caretLocation, length: 0),
            caretLocation: caretLocation,
            suggestions: [],
            tokenRange: tokenRange,
            tokenText: token,
            objectContextKeywords: SQLTextView.objectContextKeywords,
            columnContextKeywords: SQLTextView.columnContextKeywords
        )

        var trace: SQLAutocompleteTrace?
        if isRuleTracingEnabled {
            trace = SQLAutocompleteTrace.suppression(request: request)
        }

        guard let result = ruleEngine.buildSuppressionIfNeeded(
            request: request,
            environment: suppressionEnvironment,
            trace: &trace
        ), result.suppression.hasFollowUps else {
            if let trace, isRuleTracingEnabled {
                onRuleTrace?(trace)
            }
            return nil
        }

        if let trace, isRuleTracingEnabled {
            onRuleTrace?(trace)
        }

        let suppression = SuppressedCompletion(tokenRange: result.suppression.tokenRange,
                                               canonicalText: result.suppression.canonicalText,
                                               hasFollowUps: result.suppression.hasFollowUps)
        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, suppression.tokenRange).length > 0 }
        suppressedCompletions.append(suppression)
        updateCompletionIndicator()
        return suppression
    }

    func registerSuppressedCompletion(for suggestion: SQLAutoCompletionSuggestion,
                                              appliedRange: NSRange,
                                              insertion: NSString) {
        let eligibleKinds: Set<SQLAutoCompletionKind> = [.table, .view, .materializedView]
        guard eligibleKinds.contains(suggestion.kind) else { return }
        guard appliedRange.location != NSNotFound, appliedRange.length > 0 else { return }
        let whitespaceSet = CharacterSet.whitespacesAndNewlines
        let fullLength = insertion.length
        var canonicalLength = fullLength
        let whitespaceRange = insertion.rangeOfCharacter(from: whitespaceSet, options: [], range: NSRange(location: 0, length: fullLength))
        if whitespaceRange.location != NSNotFound {
            canonicalLength = whitespaceRange.location
        }
        canonicalLength = max(0, min(canonicalLength, fullLength))
        guard canonicalLength > 0 else { return }

        let canonicalText = insertion.substring(with: NSRange(location: 0, length: canonicalLength))
        let tokenRange = NSRange(location: appliedRange.location, length: canonicalLength)
        guard sqlRangeIsValid(tokenRange, upperBound: (string as NSString).length) else { return }

        let hasFollowUps = ruleEngine.hasColumnFollowUps(for: suggestion,
                                                         in: [],
                                                         environment: suppressionEnvironment)

        let suppression = SuppressedCompletion(tokenRange: tokenRange,
                                               canonicalText: canonicalText,
                                               hasFollowUps: hasFollowUps)

        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, tokenRange).length > 0 }
        suppressedCompletions.append(suppression)
        updateCompletionIndicator()
    }

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
        if let query = makeCompletionQuery() {
            var suggestions = filteredSuggestions(from: completionEngine.suggestions(for: query), for: query)
            suggestions = filterSuggestionsForContext(suggestions, query: query)
            suggestions = limitSuggestions(suggestions)

            if suggestions.isEmpty,
               let suppression = suppressionForTrigger(at: query.replacementRange.location),
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
            controller.present(suggestions: suggestions, query: query)
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

            let query = SQLAutoCompletionQuery(
                token: canonical,
                prefix: prefix,
                pathComponents: pathComponents,
                replacementRange: suppression.tokenRange,
                precedingKeyword: nil,
                precedingCharacter: nil,
                focusTable: nil,
                tablesInScope: []
            )

            controller.present(suggestions: fallback, query: query)
            return true
        }

        return false
    }

    func handleCommandShortcut(_ event: NSEvent) -> Bool {
        guard isCommandPeriod(event) else { return false }
        return triggerSuppressedCompletionsIfAvailable()
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
