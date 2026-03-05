import AppKit
import Foundation
import EchoSense

extension SQLTextView {
    func suppressionForTrigger(at caretLocation: Int) -> SuppressedCompletion? {
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

        let request = SQLAutocompleteRuleModels.SuppressionRequest(
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
            environment: ruleEnvironment,
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
                                               allowTrailingWhitespace: result.suppression.hasFollowUps)
        suppressedCompletions.removeAll { NSIntersectionRange($0.tokenRange, suppression.tokenRange).length > 0 }
        suppressedCompletions.append(suppression)
        updateCompletionIndicator()
        return suppression
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
}
