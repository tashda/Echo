#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {

    func applyCompletion(_ suggestion: SQLAutoCompletionSuggestion, query: SQLAutoCompletionQuery) {
        if isStarExpansionSuggestion(suggestion) {
            let context = completionContext
            Task { [weak self] in
                guard let self else { return }
                let formatted = await self.prepareStarExpansionInsertion(for: suggestion,
                                                                         context: context)
                await MainActor.run {
                    if self.performCompletionInsertion(suggestion: suggestion,
                                                       query: query,
                                                       insertion: formatted) != nil {
                        self.undoManager?.setActionName("Expand Columns")
                        self.completionEngine.clearPostCommitSuppression()
                    }
                }
            }
            return
        }

        if let snippetSource = suggestion.snippetText {
            let (insertion, placeholders) = makeSnippetInsertion(from: snippetSource)
            _ = performCompletionInsertion(suggestion: suggestion,
                                           query: query,
                                           insertion: insertion,
                                           snippetPlaceholders: placeholders)
            return
        }

        clearSnippetPlaceholders()
        var insertionText = suggestion.insertText
        if suggestion.kind == .keyword && !insertionText.hasSuffix(" ") {
            insertionText += " "
        }

        let insertionResult = performCompletionInsertion(suggestion: suggestion,
                                                         query: query,
                                                         insertion: insertionText)

        // After inserting a schema (e.g. "public."), immediately trigger a
        // follow-up completion popover so table suggestions are shown without
        // requiring the user to type another character.
        if insertionResult != nil, suggestion.kind == .schema {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                _ = self.forcePresentImmediateCompletions()
            }
        }
    }

    private struct CompletionInsertionResult {
        let appliedRange: NSRange
        let originalText: String
    }

    @MainActor
    @discardableResult
    private func performCompletionInsertion(suggestion: SQLAutoCompletionSuggestion,
                                            query: SQLAutoCompletionQuery,
                                            insertion: String,
                                            snippetPlaceholders: [NSRange] = []) -> CompletionInsertionResult? {
        var range = query.replacementRange
        guard let textStorage else { return nil }
        let nsString = string as NSString

        if suggestion.kind != .column {
            var lowerBound = range.location
            let preserveQualifier = !query.pathComponents.isEmpty
            let period: unichar = 46 // "."
            while lowerBound > 0 {
                let character = nsString.character(at: lowerBound - 1)
                if preserveQualifier && character == period { break }
                if !isCompletionCharacter(character) { break }
                lowerBound -= 1
            }
            let upperBound = NSMaxRange(range)
            range = NSRange(location: lowerBound, length: upperBound - lowerBound)
        }

        let maxRange = nsString.length
        var upperBound = NSMaxRange(range)
        while upperBound < maxRange {
            let character = nsString.character(at: upperBound)
            if !isCompletionCharacter(character) { break }
            upperBound += 1
        }
        range.length = upperBound - range.location

        let originalText = nsString.substring(with: range)
        let finalInsertion: String
        if snippetPlaceholders.isEmpty {
            finalInsertion = adjustedInsertion(for: suggestion,
                                               originalText: originalText,
                                               proposedInsertion: insertion)
        } else {
            finalInsertion = insertion
        }

        guard shouldChangeText(in: range, replacementString: finalInsertion) else { return nil }

        isApplyingCompletion = true
        defer {
            isApplyingCompletion = false
            suppressNextCompletionRefresh = false
        }

        textStorage.replaceCharacters(in: range, with: finalInsertion)
        let insertionNSString = finalInsertion as NSString
        let insertionLength = insertionNSString.length
        let appliedRange = NSRange(location: range.location, length: insertionLength)
        finalizeAppliedCompletion(for: suggestion, appliedRange: appliedRange, insertion: insertionNSString)
        suppressNextCompletionRefresh = true

        if snippetPlaceholders.isEmpty {
            clearSnippetPlaceholders()
            let newLocation = NSMaxRange(appliedRange)
            setSelectedRange(NSRange(location: newLocation, length: 0))
        } else {
            let absolute = snippetPlaceholders.map { placeholder in
                NSRange(location: range.location + placeholder.location,
                        length: placeholder.length)
            }
            activateSnippetPlaceholders(absolute)
        }

        hideCompletions()
        didChangeText()
        completionEngine.recordSelection(suggestion, query: query)
        return CompletionInsertionResult(appliedRange: appliedRange, originalText: originalText)
    }

    private func isStarExpansionSuggestion(_ suggestion: SQLAutoCompletionSuggestion) -> Bool {
        suggestion.kind == .snippet && suggestion.id.hasPrefix("star|")
    }

    func expandSelectStarShorthandIfNeeded() -> Bool {
        guard displayOptions.autoCompletionEnabled else { return false }
        guard inlineInsertedRange == nil else { return false }
        guard let textStorage else { return false }
        let selection = selectedRange()
        guard selection.length == 0 else { return false }
        let nsString = string as NSString
        let tokenRange = tokenRange(at: selection.location, in: nsString)
        guard tokenRange.length > 0 else { return false }
        let token = nsString.substring(with: tokenRange)
        let trimmedToken = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedToken.caseInsensitiveCompare("s*") == .orderedSame else { return false }
        let replacement = "SELECT *\nFROM "
        guard shouldChangeText(in: tokenRange, replacementString: replacement) else { return false }

        isApplyingCompletion = true
        textStorage.replaceCharacters(in: tokenRange, with: replacement)
        isApplyingCompletion = false

        let replacementLength = (replacement as NSString).length
        let caretLocation = tokenRange.location + replacementLength
        setSelectedRange(NSRange(location: caretLocation, length: 0))
        hideCompletions()
        hideInlineKeywordSuggestion()
        didChangeText()
        return true
    }

    private func formatterDialect(for databaseType: EchoSenseDatabaseType) -> SQLFormatterService.Dialect? {
        switch databaseType {
        case .postgresql:
            return .postgres
        case .mysql:
            return .mysql
        case .sqlite:
            return .sqlite
        case .microsoftSQL:
            return nil
        }
    }

    private func extractFormattedColumns(from formatted: String) -> String? {
        let normalized = formatted.replacingOccurrences(of: "\r\n", with: "\n")
        let lines = normalized.components(separatedBy: "\n")

        var collecting = false
        var collected: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if !collecting {
                let lower = trimmed.lowercased()
                if lower.hasPrefix("select ") {
                    let remainder = line.replacingOccurrences(of: #"(?i)^\s*select\s*"#,
                                                              with: "",
                                                              options: .regularExpression)
                    if !remainder.trimmingCharacters(in: .whitespaces).isEmpty {
                        collected.append(remainder)
                    }
                    collecting = true
                } else if lower == "select" {
                    collecting = true
                }
                continue
            }

            if trimmed.lowercased().hasPrefix("from") {
                break
            }

            collected.append(line)
        }

        while let first = collected.first,
              first.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            collected.removeFirst()
        }
        while let last = collected.last,
              last.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            collected.removeLast()
        }

        guard !collected.isEmpty else { return nil }

        var result = collected.joined(separator: "\n")
        if collected.count > 1 || collected.first?.first?.isWhitespace == true {
            if !result.hasPrefix("\n") {
                result = "\n" + result
            }
        }

        return result
    }

    private func prepareStarExpansionInsertion(for suggestion: SQLAutoCompletionSuggestion,
                                               context: SQLEditorCompletionContext?) async -> String {
        let rawColumns = suggestion.insertText
        guard let context else { return rawColumns }

        guard let dialect = formatterDialect(for: context.databaseType) else {
            return rawColumns
        }
        let stub = "SELECT \(rawColumns)\nFROM sqruff_placeholder;"

        do {
            let formatted = try await SQLFormatterService.shared.format(sql: stub, dialect: dialect)
            if let extracted = extractFormattedColumns(from: formatted) {
                return extracted
            }
        } catch {
            // Sqruff formatting failed; fall back to the unformatted expansion.
        }

        return rawColumns
    }

    private func makeSnippetInsertion(from snippet: String) -> (String, [NSRange]) {
        var output = ""
        var placeholders: [NSRange] = []

        var searchStart = snippet.startIndex
        var currentLocation = 0

        while let startRange = snippet.range(of: "<#", range: searchStart..<snippet.endIndex) {
            let prefix = String(snippet[searchStart..<startRange.lowerBound])
            output.append(prefix)
            currentLocation += (prefix as NSString).length

            guard let endRange = snippet.range(of: "#>", range: startRange.upperBound..<snippet.endIndex) else {
                // No closing marker; append the rest and exit.
                let remainder = String(snippet[startRange.lowerBound..<snippet.endIndex])
                output.append(remainder)
                currentLocation += (remainder as NSString).length
                return (output, placeholders)
            }

            let placeholderContent = String(snippet[startRange.upperBound..<endRange.lowerBound])
            let placeholderText = placeholderContent
            let placeholderLength = (placeholderText as NSString).length
            let placeholderRange = NSRange(location: currentLocation, length: placeholderLength)
            placeholders.append(placeholderRange)

            output.append(placeholderText)
            currentLocation += placeholderLength
            searchStart = endRange.upperBound
        }

        if searchStart < snippet.endIndex {
            let remainder = String(snippet[searchStart..<snippet.endIndex])
            output.append(remainder)
        }

        return (output, placeholders)
    }

    func activateSnippetPlaceholders(_ ranges: [NSRange]) {
        let sorted = ranges.sorted { $0.location < $1.location }
        activeSnippetPlaceholders = sorted.map { SnippetPlaceholderPosition(range: $0) }
        if activeSnippetPlaceholders.isEmpty {
            currentSnippetPlaceholderIndex = -1
            return
        }
        currentSnippetPlaceholderIndex = 0
        isAdjustingSnippetSelection = true
        setSelectedRange(activeSnippetPlaceholders[0].range)
        isAdjustingSnippetSelection = false
    }

    func clearSnippetPlaceholders() {
        activeSnippetPlaceholders.removeAll()
        currentSnippetPlaceholderIndex = -1
    }

    private func selectSnippetPlaceholder(at index: Int) {
        guard index >= 0,
              index < activeSnippetPlaceholders.count else { return }
        currentSnippetPlaceholderIndex = index
        let range = activeSnippetPlaceholders[index].range
        isAdjustingSnippetSelection = true
        setSelectedRange(range)
        isAdjustingSnippetSelection = false
    }

    func adjustSnippetPlaceholders(forChange affectedRange: NSRange,
                                           replacementLength: Int) {
        guard !activeSnippetPlaceholders.isEmpty else { return }
        let delta = replacementLength - affectedRange.length
        if delta == 0 { return }

        for index in activeSnippetPlaceholders.indices {
            var placeholder = activeSnippetPlaceholders[index]
            let placeholderRange = placeholder.range

            if NSMaxRange(affectedRange) <= placeholderRange.location {
                placeholder.range.location = max(0, placeholderRange.location + delta)
            } else if NSIntersectionRange(placeholderRange, affectedRange).length > 0 ||
                        NSLocationInRange(affectedRange.location, placeholderRange) {
                let newLength = max(0, placeholderRange.length + delta)
                placeholder.range.length = newLength
                placeholder.range.location = min(placeholderRange.location, affectedRange.location)
            }

            activeSnippetPlaceholders[index] = placeholder
        }
    }

    func handleSnippetNavigation(_ event: NSEvent) -> Bool {
        guard !activeSnippetPlaceholders.isEmpty else { return false }

        if event.keyCode == 53 { // Escape
            clearSnippetPlaceholders()
            return true
        }

        guard let characters = event.charactersIgnoringModifiers,
              characters == "\t" else { return false }

        if currentSnippetPlaceholderIndex >= 0 &&
            currentSnippetPlaceholderIndex < activeSnippetPlaceholders.count {
            activeSnippetPlaceholders[currentSnippetPlaceholderIndex].range = selectedRange()
        }

        let isShiftHeld = event.modifierFlags.contains(.shift)

        if isShiftHeld {
            if currentSnippetPlaceholderIndex > 0 {
                selectSnippetPlaceholder(at: currentSnippetPlaceholderIndex - 1)
            } else {
#if os(macOS)
                NSSound.beep()
#endif
            }
        } else {
            if currentSnippetPlaceholderIndex < activeSnippetPlaceholders.count - 1 {
                selectSnippetPlaceholder(at: currentSnippetPlaceholderIndex + 1)
            } else {
                let endLocation = NSMaxRange(activeSnippetPlaceholders.last?.range ?? selectedRange())
                clearSnippetPlaceholders()
                setSelectedRange(NSRange(location: endLocation, length: 0))
            }
        }

        return true
    }
}
#endif
