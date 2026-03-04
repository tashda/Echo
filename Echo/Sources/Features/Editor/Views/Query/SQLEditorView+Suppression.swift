import AppKit
import Foundation
import EchoSense

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
            clause: query.clause,
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
            hasFollowUps: result.suppression.hasFollowUps,
            allowTrailingWhitespace: shouldAllowTrailingWhitespace(for: result.suppression)
        )

        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, newSuppression.tokenRange).length > 0 }
        suppressedCompletions.append(newSuppression)
        updateCompletionIndicator()
        return true
    }

    func suppressedCompletionEntry(containing selection: NSRange, caretLocation: Int) -> (Int, SuppressedCompletion)? {
        guard selection.location != NSNotFound else { return nil }
        let nsString = string as NSString
        for (index, entry) in suppressedCompletions.enumerated() {
            let tokenRange = entry.tokenRange
            guard sqlRangeIsValid(tokenRange, upperBound: nsString.length) else {
                continue
            }

            if selection.length > 0 {
                if NSIntersectionRange(selection, tokenRange).length > 0 {
                    return (index, entry)
                }
            } else {
                let lowerBound = tokenRange.location
                var upperBound = NSMaxRange(tokenRange)
                if entry.allowTrailingWhitespace {
                    let extraSpan = trailingWhitespaceSpan(after: upperBound, in: nsString)
                    upperBound = min(nsString.length, upperBound + extraSpan)
                }
                if caretLocation >= lowerBound && caretLocation <= upperBound {
                    return (index, entry)
                }
            }
        }
        return nil
    }

    private func shouldAllowTrailingWhitespace(for suppression: SQLAutocompleteRuleEngine.Suppression) -> Bool {
        suppression.hasFollowUps
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

        let parsedContext = SQLContextParser(text: string,
                                             caretLocation: caretLocation,
                                             dialect: currentSQLDialect(),
                                             catalog: SQLDatabaseCatalog(schemas: [])).parse()
        let query = SQLAutoCompletionQuery(
            token: token,
            prefix: String(prefix),
            pathComponents: pathComponents,
            replacementRange: tokenRange,
            precedingKeyword: nil,
            precedingCharacter: nil,
            focusTable: nil,
            tablesInScope: [],
            clause: parsedContext.clause
        )

        let request = SQLAutocompleteRuleEngine.SuppressionRequest(
            query: query,
            selection: NSRange(location: caretLocation, length: 0),
            caretLocation: caretLocation,
            suggestions: [],
            tokenRange: tokenRange,
            tokenText: token,
            clause: query.clause,
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
                                               hasFollowUps: result.suppression.hasFollowUps,
                                               allowTrailingWhitespace: shouldAllowTrailingWhitespace(for: result.suppression))
        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, suppression.tokenRange).length > 0 }
        suppressedCompletions.append(suppression)
        updateCompletionIndicator()
        return suppression
    }

    private func trailingWhitespaceSpan(after index: Int, in string: NSString) -> Int {
        guard index < string.length else { return 0 }
        let whitespace = CharacterSet.whitespacesAndNewlines
        var span = 0
        var cursor = index
        while cursor < string.length {
            let value = string.character(at: cursor)
            guard let scalar = UnicodeScalar(UInt32(value)) else { break }
            if whitespace.contains(scalar) {
                span += 1
                cursor += 1
            } else {
                break
            }
        }
        return span
    }

    func finalizeAppliedCompletion(for suggestion: SQLAutoCompletionSuggestion,
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

        let tokenRange = NSRange(location: appliedRange.location, length: canonicalLength)
        guard sqlRangeIsValid(tokenRange, upperBound: (string as NSString).length) else { return }

        suppressedCompletions.removeAll { existing in
            NSIntersectionRange(existing.tokenRange, tokenRange).length > 0
        }

        if suppressionForTrigger(at: tokenRange.location) != nil {
            return
        }

        let canonicalText = insertion.substring(with: NSRange(location: 0, length: canonicalLength))
        let suppression = SuppressedCompletion(tokenRange: tokenRange,
                                               canonicalText: canonicalText,
                                               hasFollowUps: false,
                                               allowTrailingWhitespace: true)
        suppressedCompletions.append(suppression)
        updateCompletionIndicator()
    }

    @MainActor
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

    @MainActor
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
