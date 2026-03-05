import AppKit
import Foundation
import EchoSense

extension SQLTextView {
    private var suppressionEnvironment: SQLAutocompleteRuleModels.Environment { ruleEnvironment }

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

        let request = SQLAutocompleteRuleModels.SuppressionRequest(
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

    private func shouldAllowTrailingWhitespace(for suppression: SQLAutocompleteRuleModels.Suppression) -> Bool {
        suppression.hasFollowUps
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

}

