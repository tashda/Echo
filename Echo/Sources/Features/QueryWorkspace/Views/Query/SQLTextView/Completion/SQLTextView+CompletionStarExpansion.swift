#if os(macOS)
import AppKit
import EchoSense

extension SQLTextView {
    func expandSelectStarShorthandIfNeeded() -> Bool {
        guard displayOptions.autoCompletionEnabled else { return false }
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
        didChangeText()
        return true
    }

    internal func formatterDialect(for databaseType: EchoSenseDatabaseType) -> SQLFormatter.Dialect? {
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

    internal func extractFormattedColumns(from formatted: String) -> String? {
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

    internal func prepareStarExpansionInsertion(for suggestion: SQLAutoCompletionSuggestion,
                                               context: SQLEditorCompletionContext?) async -> String {
        let rawColumns = suggestion.insertText
        guard let context else { return rawColumns }

        guard let dialect = formatterDialect(for: context.databaseType) else {
            return rawColumns
        }
        let stub = "SELECT \(rawColumns)\nFROM formatter_placeholder;"

        do {
            let formatted = try await SQLFormatter.shared.format(sql: stub, dialect: dialect)
            if let extracted = extractFormattedColumns(from: formatted) {
                return extracted
            }
        } catch {
            // Formatting failed; fall back to the unformatted expansion.
        }

        return rawColumns
    }

    internal func makeSnippetInsertion(from snippet: String) -> (String, [NSRange]) {
        var output = ""
        var placeholders: [NSRange] = []

        var searchStart = snippet.startIndex
        var currentLocation = 0

        while let startRange = snippet.range(of: "<#", range: searchStart..<snippet.endIndex) {
            let prefix = String(snippet[searchStart..<startRange.lowerBound])
            output.append(prefix)
            currentLocation += (prefix as NSString).length

            guard let endRange = snippet.range(of: "#>", range: startRange.upperBound..<snippet.endIndex) else {
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
}
#endif
