import Foundation

/// Round 28.9: the text rules behind typing in the editor, kept apart from the text view so they
/// can be tested: Tab is 4 spaces (TB1), Return keeps the indent (RT1), brackets and quotes close
/// themselves and are stepped over (BQ1), ⌘/ toggles `--` (CM1).
nonisolated enum SQLEditorTyping {
    static let indentWidth = 4

    /// The spaces Tab inserts at `column` to reach the next stop.
    static func softTab(atColumn column: Int) -> String {
        String(repeating: " ", count: indentWidth - column % indentWidth)
    }

    /// The leading spaces and tabs of a line.
    static func leadingWhitespace(of line: String) -> String {
        String(line.prefix { $0 == " " || $0 == "\t" })
    }

    /// Every line moved right by one indent (empty lines stay empty).
    static func indented(_ lines: [String]) -> [String] {
        lines.map { $0.isEmpty ? $0 : String(repeating: " ", count: indentWidth) + $0 }
    }

    /// Every line moved left by up to one indent (or one tab).
    static func outdented(_ lines: [String]) -> [String] {
        lines.map { line in
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            let spaces = min(line.prefix { $0 == " " }.count, indentWidth)
            return String(line.dropFirst(spaces))
        }
    }

    /// `--` added at the block's smallest indent, or removed when every non-empty line has it.
    static func toggledComment(_ lines: [String]) -> [String] {
        let content = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !content.isEmpty else { return lines }
        let commented = content.allSatisfy { $0.trimmingCharacters(in: .whitespaces).hasPrefix("--") }
        if commented {
            return lines.map { line in
                guard let range = line.range(of: "--") else { return line }
                var rest = line[range.upperBound...]
                if rest.hasPrefix(" ") { rest = rest.dropFirst() }
                return String(line[..<range.lowerBound]) + rest
            }
        }
        let indent = content.map { leadingWhitespace(of: $0).count }.min() ?? 0
        return lines.map { line in
            guard !line.trimmingCharacters(in: .whitespaces).isEmpty else { return line }
            let index = line.index(line.startIndex, offsetBy: indent)
            return String(line[..<index]) + "-- " + line[index...]
        }
    }

    /// The closer typed for an opener, when it should be: `(` always closes before whitespace, a
    /// closer or the end; a quote only when it isn't touching a word on either side.
    static func autoCloser(for typed: String, before next: Character?, after previous: Character?) -> String? {
        let freeAhead = next.map { $0.isWhitespace || ")],;".contains($0) } ?? true
        switch typed {
        case "(": return freeAhead ? ")" : nil
        case "'", "\"":
            let wordBehind = previous.map { $0.isLetter || $0.isNumber || $0 == "_" || String($0) == typed } ?? false
            return freeAhead && !wordBehind ? typed : nil
        default: return nil
        }
    }

    /// Whether typing `typed` should just step over the same character after the caret.
    static func stepsOver(_ typed: String, next: Character?) -> Bool {
        guard let next, [")", "'", "\""].contains(typed) else { return false }
        return String(next) == typed
    }
}
